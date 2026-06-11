#!/bin/bash

export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"

if [ ! -f "/home/frappe/frappe-bench/Procfile" ]; then
    echo "Creating new bench..."
    # bench refuses to init an existing directory (even empty), so init to a temp
    # path then copy into the volume-backed directory
    bench init --skip-redis-config-generation frappe-bench-init
    echo "Copying bench to persistent location..."
    cp -a /home/frappe/frappe-bench-init/. /home/frappe/frappe-bench/
    echo "Fixing virtualenv paths..."
    grep -rIl 'frappe-bench-init' /home/frappe/frappe-bench | xargs -r sed -i 's|frappe-bench-init|frappe-bench|g'
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

if [ ! -f "/home/frappe/frappe-bench/apps/lms/pyproject.toml" ]; then
    # Symlink repo root (has pyproject.toml + lms/ module), not the lms/ subdirectory
    ln -sf /workspace /home/frappe/frappe-bench/apps/lms
    /home/frappe/frappe-bench/env/bin/pip install -q -e /home/frappe/frappe-bench/apps/lms
    # Register lms in apps.txt so bench commands can find it
    grep -q "^lms$" sites/apps.txt || printf "\nlms" >> sites/apps.txt
fi

if [ ! -f "/home/frappe/frappe-bench/sites/lms.localhost/site_config.json" ]; then
    echo "Creating site lms.localhost..."
    bench new-site lms.localhost \
    --force \
    --mariadb-root-password 123 \
    --admin-password admin \
    --mariadb-user-host-login-scope='%'

    bench --site lms.localhost install-app payments
    bench --site lms.localhost install-app lms
    bench --site lms.localhost set-config developer_mode 1
    bench --site lms.localhost clear-cache
    bench use lms.localhost
else
    echo "Site lms.localhost already exists, skipping site creation"
fi

bench --site lms.localhost set-config host_name "https://lms.veraxity.dev"

# Prevent Frappe from appending the internal webserver_port (8000) to
# generated URLs (e.g. Connected App redirect_uri) - Caddy fronts the site
# on 443 without exposing 8000.
bench set-config -g restart_supervisor_on_update 1

# Build frontend assets (bench build triggers the Vue/vite build internally)
echo "Building LMS frontend..."
export NODE_OPTIONS="--max-old-space-size=2048"
cd /home/frappe/frappe-bench && bench build --app lms

bench start
