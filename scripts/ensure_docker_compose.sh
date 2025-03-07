#!/bin/bash
source scripts/utils.sh

ensure_docker_compose() {
    log_info "Ensuring Docker Compose is installed..."
    if ! command -v docker-compose &>/dev/null; then
        sudo apt update
        sudo apt install -y docker-compose
        check_status "Installing Docker Compose"
    else
        log_info "Docker Compose is already installed"
    fi
}

ensure_docker_compose
