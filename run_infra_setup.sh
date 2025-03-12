#!/usr/bin/env bash

# Add error handling and script termination on failure
set -euo pipefail

# Check if running as root/sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo"
    exit 1
fi

# Add script directory resolution
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Add logging functions
source "${SCRIPT_DIR}/scripts/utils.sh"

# Execute each script in order
log_info "Starting infrastructure setup..."

# Function to run script with error handling
run_script() {
    local script=$1
    local description=$2
    
    log_info "$description"
    if [ -f "scripts/$script" ]; then
        # Preserve environment variables and run with sudo
        sudo -E bash "scripts/$script" || {
            log_error "Failed to execute $script"
            exit 1
        }
    else
        log_error "Script not found: scripts/$script"
        exit 1
    fi
}

# Core infrastructure setup
run_script "install_core_dependencies.sh" "Installing core dependencies..."  # ✅
run_script "install_helm.sh" "Installing Helm (including SSLH)..."  # ✅
run_script "install_helm_test.sh" "Verifying Helm installation..."  # ✅
run_script "install_kubernetes.sh" "Installing Kubernetes..."  # ✅
run_script "install_kubernetes_test.sh" "Verifying Kubernetes installation..."  # ✅
run_script "ensure_repo_formatted.sh" "Ensuring repository is formatted..."  # ✅

# Network and security setup
run_script "install_reverse_proxy.sh" "Setting up Reverse Proxy (NGINX)..."  # ✅
run_script "install_reverse_proxy_test.sh" "Verifying Reverse Proxy setup..."  # ✅
run_script "create_cloudflare_ip_ranges.sh" "Configuring firewall (Cloudflare IPs)..."  # ✅
run_script "configure_firewall.sh" "Configuring firewall rules..."  # ✅

# Add final status check
if [ $? -eq 0 ]; then
    log_info "🎉 Infrastructure setup completed successfully!"
    exit 0
else
    log_error "❌ Infrastructure setup failed. Please check the logs above for errors."
    exit 1
fi 