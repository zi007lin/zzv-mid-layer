#!/bin/bash
source scripts/utils.sh

install_kubernetes() {
    log_info "Installing Kubernetes..."
    sudo apt install -y kubeadm kubectl kubelet
    sudo systemctl enable kubelet
    check_status "Installing Kubernetes components"
}

install_kubernetes
