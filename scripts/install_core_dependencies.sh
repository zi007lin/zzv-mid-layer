#!/bin/bash
source scripts/utils.sh

install_core_dependencies() {
    log_info "Installing core dependencies..."
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    check_status "Installing essential packages"
}

install_core_dependencies
