#!/bin/bash
source scripts/utils.sh

configure_nginx() {
    log_info "Configuring NGINX..."
    sudo apt install -y nginx
    sudo systemctl enable nginx
    sudo systemctl restart nginx
    check_status "Restarting NGINX"
}

configure_nginx
