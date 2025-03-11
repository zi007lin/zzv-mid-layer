#!/bin/bash

source "$(dirname "$0")/utils.sh"

log_info "Testing Helm installation..."

# Check if Helm is installed
if command -v helm &> /dev/null; then
    log_info "✅ Helm is installed."
else
    log_error "❌ Helm is NOT installed."
    exit 1
fi

# Check if Helm repositories exist
helm repo list | grep "bitnami" &> /dev/null
if [ $? -eq 0 ]; then
    log_info "✅ Helm repository is configured correctly."
else
    log_warning "⚠️ Helm repository not found. Try running install_helm.sh again."
fi

log_info "✅ Helm test completed successfully!"
