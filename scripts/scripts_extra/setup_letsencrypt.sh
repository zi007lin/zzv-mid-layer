#!/bin/bash
source scripts/utils.sh

source "$(dirname "$0")/require_env.sh"

setup_letsencrypt() {
    log_info "Setting up Let's Encrypt SSL..."
    sudo apt install -y certbot python3-certbot-nginx
    sudo certbot --nginx -d zzv.io
    check_status "Setting up Let's Encrypt"
}

setup_letsencrypt
