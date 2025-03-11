#!/usr/bin/env bash

. "$(dirname "$0")/utils.sh"

install_kubernetes() {
    log_info "Installing K3s (lightweight Kubernetes distribution)..."
    
    # Update system packages
    log_info "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    check_status "System update"
    
    # Install required dependencies
    log_info "Installing dependencies..."
    sudo apt install -y curl
    check_status "Installing dependencies"
    
    # Install K3s
    log_info "Installing K3s..."
    curl -sfL https://get.k3s.io | sh -
    check_status "Installing K3s"
    
    # Enable and check K3s service
    log_info "Enabling K3s service..."
    sudo systemctl enable k3s
    sudo systemctl status k3s --no-pager
    check_status "Enabling K3s service"
    
    # Configure kubectl
    log_info "Configuring kubectl..."
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    check_status "Configuring kubectl"
    
    # Verify installation
    log_info "Verifying K3s installation..."
    kubectl get nodes
    check_status "K3s installation verification"
    
    log_info "K3s installation completed successfully!"
}

install_kubernetes