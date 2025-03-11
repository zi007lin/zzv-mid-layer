#!/bin/bash
source scripts/utils.sh

install_grafana() {
    log_info "Installing Grafana..."
    sudo apt install -y grafana
    sudo systemctl enable grafana-server
    sudo systemctl start grafana-server
    check_status "Starting Grafana"
}

install_grafana
