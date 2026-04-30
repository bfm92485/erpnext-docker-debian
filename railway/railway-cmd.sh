#!/bin/sh
set -e

# Check if a site has been created yet
# The site is created by running railway-setup.sh via SSH after first deploy
SITE_DIR=$(find /home/frappe/bench/sites -maxdepth 1 -mindepth 1 -type d ! -name assets ! -name .cache 2>/dev/null | head -1)

if [ -z "$SITE_DIR" ]; then
    echo "-> No site found. Waiting for setup..."
    echo "-> SSH into this container and run: bash /home/frappe/bench/railway-setup.sh"
    echo "-> Then restart the service from the Railway dashboard."
    # Keep container alive so SSH works
    tail -f /dev/null
else
    SITE_NAME=$(basename "$SITE_DIR")
    echo "-> Found site: $SITE_NAME"

    echo "-> Clearing cache"
    su frappe -c "bench --site $SITE_NAME execute frappe.cache_manager.clear_global_cache" || echo "-> Cache clear failed (non-fatal), continuing..."

    echo "-> Bursting env into config"
    envsubst '$RFP_DOMAIN_NAME' < /home/$systemUser/temp_nginx.conf > /etc/nginx/conf.d/default.conf
    envsubst '$PATH,$HOME,$NVM_DIR,$NODE_VERSION' < /home/$systemUser/temp_supervisor.conf > /home/$systemUser/supervisor.conf

    echo "-> Starting nginx"
    nginx

    echo "-> Starting supervisor"
    /usr/bin/supervisord -c /home/$systemUser/supervisor.conf
fi
