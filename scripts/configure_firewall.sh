#!/bin/bash
source scripts/utils.sh

configure_firewall() {
    log_info "Configuring firewall..."
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 443/tcp
    sudo ufw allow 80/tcp
    sudo ufw enable
    check_status "Configuring firewall"
}

configure_firewall
