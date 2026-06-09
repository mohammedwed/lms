#!/bin/bash

export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"

if [ ! -f "/home/frappe/frappe-bench/Procfile" ]; then
    echo "Creating new bench..."
    # bench refuses to init an existing directory (even empty), so init to a temp
    # path then copy into the volume-backed directory
    bench init --skip-redis-config-generation frappe-bench-init
    cp -a /home/frappe/frappe-bench-init/. /home/frappe/frappe-bench/
    rm -rf /home/frappe/frappe-bench-init
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

if [ ! -f "/home/frappe/frappe-bench/apps/payments/setup.py" ] && [ ! -f "/home/frappe/frappe-bench/apps/payments/pyproject.toml" ]; then
    bench get-app payments
fi

if [ ! -f "/home/frappe/frappe-bench/apps/lms/hooks.py" ]; then
    ln -sf /workspace/lms /home/frappe/frappe-bench/apps/lms
    /home/frappe/frappe-bench/env/bin/pip install -q -e /home/frappe/frappe-bench/apps/lms
fi

if [ ! -f "/home/frappe/frappe-bench/sites/lms.localhost/site_config.json" ]; then
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
