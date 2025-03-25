#!/bin/bash

# Add script directory resolution
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Source utils.sh using absolute path
source "${SCRIPT_DIR}/utils.sh"

# Ensure bc is installed
if ! command -v bc &> /dev/null; then
    log_info "Installing bc package..."
    sudo apt-get update && sudo apt-get install -y bc
fi

# Function to compare versions
version_compare() {
    if [ "$(echo "$1 >= $2" | bc)" -eq 1 ]; then
        return 0
    else
        return 1
    fi
}

# Verify Helm installation
verify_helm() {
    # Check if Helm is installed
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed"
        return 1
    fi

    # Get Helm version
    HELM_VERSION=$(helm version --short | cut -d'v' -f2 | cut -d'.' -f1,2)
    log_info "Detected Helm version: ${HELM_VERSION}"

    # Check if version meets minimum requirement
    MIN_VERSION="3.0"
    if ! version_compare "$HELM_VERSION" "$MIN_VERSION"; then
        log_warning "⚠️ Helm version is below recommended version (3.0+)."
    else
        log_info "✅ Helm version meets minimum requirement"
    fi

    # Test Helm functionality
    log_info "Testing Helm functionality..."
    if ! helm repo list &>/dev/null; then
        log_error "Unable to list Helm repositories"
        return 1
    fi

    log_info "✅ Helm installation verified successfully!"
    return 0
}

# Run verification
verify_helm
exit $?