#!/bin/bash
source scripts/utils.sh

install_prometheus() {
    log_info "Installing Prometheus..."
    sudo apt install -y prometheus
    sudo systemctl enable prometheus
    sudo systemctl start prometheus
    check_status "Starting Prometheus"
}

install_prometheus
