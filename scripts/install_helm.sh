#!/usr/bin/env bash

# Include logging functions (if you have utils.sh)
. "$(dirname "$0")/utils.sh"

log_info "Installing Helm..."

# Check for prerequisites
if ! command -v curl &> /dev/null; then
    log_error "❌ curl is required but not installed. Please install curl first."
    exit 1
fi

# Check if Helm is already installed
if command -v helm &> /dev/null; then
    log_info "✅ Helm is already installed."
    helm version
else
    log_info "🔄 Downloading and installing Helm..."
    
    # Install Helm for Linux
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    check_status "Helm installation"
    
    # Verify Helm is in PATH
    if ! command -v helm &> /dev/null; then
        log_error "❌ Helm installation completed but helm command not found in PATH"
        exit 1
    fi
    
    log_info "✅ Helm installed successfully!"
    helm version
fi

# Add common Helm repositories
log_info "Adding Helm repositories..."

# Add Bitnami repo (only once)
if ! helm repo list | grep -q "bitnami"; then
    helm repo add bitnami https://charts.bitnami.com/bitnami
    check_status "Adding Bitnami repository"
    log_info "✅ Bitnami repo added successfully!"
else
    log_info "✅ Bitnami repo already exists."
fi

# Add stable repo
if ! helm repo list | grep -q "stable"; then
    helm repo add stable https://charts.helm.sh/stable
    check_status "Adding Stable repository"
    log_info "✅ Stable repo added successfully!"
else
    log_info "✅ Stable repo already exists."
fi

# Add jetstack repo (for cert-manager)
if ! helm repo list | grep -q "jetstack"; then
    helm repo add jetstack https://charts.jetstack.io
    check_status "Adding Jetstack repository"
    log_info "✅ Jetstack repo added successfully!"
else
    log_info "✅ Jetstack repo already exists."
fi

# Update all repos
log_info "Updating Helm repositories..."
helm repo update
check_status "Updating Helm repositories"

log_info "✅ Helm installation and setup complete!"