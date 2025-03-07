#!/bin/bash
source scripts/utils.sh

setup_sslh() {
    log_info "Setting up SSLH for SSH and WebSockets on port 443..."
    sudo apt install -y sslh
    sudo systemctl enable sslh
    sudo systemctl restart sslh
    check_status "Starting SSLH service"
}

setup_sslh
