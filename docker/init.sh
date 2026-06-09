#!/bin/bash

export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"

if [ ! -d "/home/frappe/frappe-bench" ]; then
    echo "Creating new bench..."
    bench init --skip-redis-config-generation frappe-bench
fi

cd frappe-bench

# Use containers instead of localhost
bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379

# Remove redis, watch from Procfile
sed -i '/redis/d' ./Procfile
sed -i '/^watch:/d' ./Procfile

if [ ! -d "/home/frappe/frappe-bench/apps/payments" ]; then
    bench get-app payments
fi

if [ ! -d "/home/frappe/frappe-bench/apps/lms" ]; then
    ln -sf /workspace/lms /home/frappe/frappe-bench/apps/lms
    /home/frappe/frappe-bench/env/bin/pip install -q -e /home/frappe/frappe-bench/apps/lms
fi

if [ ! -d "/home/frappe/frappe-bench/sites/lms.localhost" ]; then
    echo "Creating site lms.localhost..."
    bench new-site lms.localhost \
    --force \
    --mariadb-root-password 123 \
    --admin-password admin \
    --no-mariadb-socket

    bench --site lms.localhost install-app payments
    bench --site lms.localhost install-app lms
    bench --site lms.localhost set-config developer_mode 1
    bench --site lms.localhost clear-cache
    bench use lms.localhost
else
    echo "Site lms.localhost already exists, skipping site creation"
fi

# Always build the frontend — dist is ephemeral and lost on container restart
echo "Building LMS frontend..."
NODE_OPTIONS="--max-old-space-size=3072" bench build --app lms

bench start
