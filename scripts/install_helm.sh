#!/bin/bash

# Include logging functions (if you have utils.sh)
source "$(dirname "$0")/utils.sh"

log_info "Installing Helm..."

# Check if Helm is already installed
if command -v helm &> /dev/null; then
    log_info "✅ Helm is already installed."
else
    log_info "🔄 Downloading and installing Helm..."
    
    # Install Helm for Linux
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    check_status "❌ Helm installation failed"
    log_info "✅ Helm installed successfully!"
fi

# Verify Helm version
helm version

# Add Bitnami Helm repo (optional, commonly used)
log_info "Adding Helm repository..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
check_status "❌ Helm repo addition failed"
log_info "✅ Helm repo added successfully!"

log_info "✅ Helm installation complete!"
