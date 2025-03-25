#!/usr/bin/env bash

source "$(dirname "$0")/require_env.sh"

set -euo pipefail

source scripts/utils.sh

DOMAIN_NAME="${DOMAIN_NAME:-zzv.local}"
NGINX_CONF_DIR="/etc/nginx"
BACKUP_DIR="/etc/nginx/backups"
OBS_CONF="$NGINX_CONF_DIR/sites-available/zzv_observability"

configure_nginx() {
    log_info "📦 Installing and configuring NGINX..."

    sudo apt install -y nginx
    sudo systemctl enable nginx
    sudo systemctl restart nginx
    check_status "Restarting NGINX"

    log_info "🔐 Setting up reverse proxy for observability tools..."

    sudo mkdir -p "$BACKUP_DIR"
    sudo cp "$NGINX_CONF_DIR/nginx.conf" "$BACKUP_DIR/nginx.conf.bak.$(date +%s)"

    sudo tee "$OBS_CONF" > /dev/null <<EOF
server {
    listen 443 ssl;
    server_name $DOMAIN_NAME;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;

    location /grafana/ {
        proxy_pass http://localhost:3000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /prometheus/ {
        proxy_pass http://localhost:9090/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /tempo/ {
        proxy_pass http://localhost:3200/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    sudo ln -sf "$OBS_CONF" "$NGINX_CONF_DIR/sites-enabled/zzv_observability"
    sudo nginx -t && sudo systemctl reload nginx

    log_info "✅ NGINX reverse proxy ready at:"
    log_info "   - https://$DOMAIN_NAME/grafana/"
    log_info "   - https://$DOMAIN_NAME/prometheus/"
    log_info "   - https://$DOMAIN_NAME/tempo/"
}

configure_nginx
