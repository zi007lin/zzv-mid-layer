#!/usr/bin/env bash

# Add error handling and script termination on failure
set -euo pipefail

# Add script directory resolution
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Add logging functions
source "${SCRIPT_DIR}/scripts/utils.sh"

# Execute each script in order
log_info "Starting services setup..."

# Function to run script with error handling
run_script() {
    local script=$1
    local description=$2
    
    log_info "$description"
    if [ -f "scripts/$script" ]; then
        bash "scripts/$script" || {
            log_error "Failed to execute $script"
            exit 1
        }
    else
        log_error "Script not found: scripts/$script"
        exit 1
    fi
}

# Check if infrastructure is ready
log_info "Verifying infrastructure readiness..."
if ! kubectl get nodes &>/dev/null; then
    log_error "Kubernetes is not ready. Please run run_infra_setup.sh first"
    exit 1
fi

# Services deployment
log_info "Deploying services..."

# Message Queue
run_script "deploy_kafka.sh" "Deploying Kafka..."  # ✅

# Application Services
# run_script "ensure_docker_compose.sh" "Ensuring Docker Compose is installed..."  # ❌
# run_script "deploy_spring_boot.sh" "Deploying Spring Boot..."  # ❌
run_script "deploy_elixir_phoenix.sh" "Deploying Elixir Phoenix..."  # ✅

# Database
# run_script "deploy_mongodb.sh" "Deploying MongoDB..."  # ❌

# Monitoring
# run_script "install_prometheus.sh" "Installing Prometheus..."  # ❌
# run_script "install_grafana.sh" "Installing Grafana..."  # ❌

# Security and SSL
# run_script "setup_letsencrypt.sh" "Setting up Let's Encrypt..."  # ❌

# Testing
# run_script "test_setup.sh" "Testing services setup..."  # ❌

# Add final status check
if [ $? -eq 0 ]; then
    log_info "🎉 Services setup completed successfully!"
    exit 0
else
    log_error "❌ Services setup failed. Please check the logs above for errors."
    exit 1
fi 