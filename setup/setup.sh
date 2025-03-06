#!/bin/bash

# Ensure yq is installed for parsing YAML
if ! command -v yq &> /dev/null; then
    echo "Installing yq for YAML parsing..."
    sudo apt update && sudo apt install -y yq
fi

# Function to execute a command safely
execute_cmd() {
    local cmd="$1"
    if [ -z "$cmd" ]; then
        echo "Error: No command provided"
        return 1
    fi
    echo "Executing: $cmd"
    if ! eval "$cmd"; then
        echo "Error executing command: $cmd"
        return 1
    fi
}

# Function to check if a package is installed before installing
install_package() {
    local package="$1"
    if ! dpkg -l | grep -q "^ii  $package "; then
        echo "Installing package: $package"
        sudo apt install -y "$package"
    else
        echo "Package $package is already installed."
    fi
}

# Function to check if a service is running before restarting
restart_service() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        echo "Restarting service: $service"
        sudo systemctl restart "$service"
    else
        echo "Service $service is not running, skipping restart."
    fi
}

# Read YAML and execute relevant sections
echo "Reading setup.yml..."

# Gather system info
echo "Gathering system information..."
yq e '.setup.system_info[]' setup.yml | while read -r cmd; do
    execute_cmd "$cmd"
done

# Install required packages
echo "Checking and installing required packages..."
yq e '.setup.installed_packages[]' setup.yml | while read -r package; do
    install_package "$package"
done

# Apply firewall settings
echo "Configuring firewall..."
yq e '.setup.firewall[]' setup.yml | while read -r cmd; do
    execute_cmd "$cmd"
done

# Apply network settings
echo "Applying network configurations..."
yq e '.setup.network[]' setup.yml | while read -r cmd; do
    execute_cmd "$cmd"
done

# Restore user permissions
echo "Restoring user permissions..."
yq e '.setup.user_permissions[]' setup.yml | while read -r cmd; do
    execute_cmd "$cmd"
done

# Restore environment variables
echo "Restoring environment variables..."
yq e '.setup.env_variables[]' setup.yml | while read -r cmd; do
    execute_cmd "$cmd"
done

# Restart necessary services if they exist
echo "Restarting necessary services..."
yq e '.setup.running_services[]' setup.yml | while read -r service; do
    restart_service "$service"
done

# Finalize setup
echo "Finalizing setup..."
yq e '.setup.finalize[]' setup.yml | while read -r cmd; do
    execute_cmd "$cmd"
done

echo "Ubuntu instance setup is complete."
