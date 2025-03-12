#!/bin/bash

# Source utility functions if available
SCRIPT_DIR="$(dirname "$0")"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
    . "$SCRIPT_DIR/utils.sh"
else
    # Define simplified logging functions if utils.sh is not available
    log_info() {
        echo -e "\e[32m[INFO]\e[0m $1"
    }
    
    log_error() {
        echo -e "\e[31m[ERROR]\e[0m $1"
    }
    
    log_warning() {
        echo -e "\e[33m[WARNING]\e[0m $1"
    }
    
    check_status() {
        if [ $? -ne 0 ]; then
            log_error "❌ $1"
            exit 1
        fi
    }
fi

# Default configurations
REPO_DIR="/etc/apt/sources.list.d"
REPO_FILE="$REPO_DIR/kubernetes.list"
KEYRING_DIR="/etc/apt/keyrings"
K8S_VERSION="v1.28"
GPG_KEY_URL="https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/Release.key"
GPG_KEY_FILE="$KEYRING_DIR/kubernetes-apt-keyring.gpg"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version=*)
            K8S_VERSION="${1#*=}"
            GPG_KEY_URL="https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/Release.key"
            shift
            ;;
        --repo-file=*)
            REPO_FILE="${1#*=}"
            shift
            ;;
        *)
            log_warning "Unknown option: $1"
            shift
            ;;
    esac
done

# Define the correct repository entry based on version
CORRECT_ENTRY="deb [signed-by=$GPG_KEY_FILE] https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/ /"

# Check if running with sufficient privileges
if [ "$EUID" -ne 0 ]; then
    log_warning "This script requires administrative privileges."
    log_info "Attempting to use sudo for privileged operations..."
fi

# Create required directories if they don't exist
if [ ! -d "$REPO_DIR" ]; then
    log_info "Creating repository directory $REPO_DIR..."
    sudo mkdir -p "$REPO_DIR"
    check_status "Failed to create repository directory"
fi

if [ ! -d "$KEYRING_DIR" ]; then
    log_info "Creating keyring directory $KEYRING_DIR..."
    sudo mkdir -p "$KEYRING_DIR"
    check_status "Failed to create keyring directory"
fi

# Download and install GPG key if not present
if [ ! -f "$GPG_KEY_FILE" ]; then
    log_info "Downloading Kubernetes GPG key..."
    sudo curl -fsSL "$GPG_KEY_URL" | sudo gpg --dearmor -o "$GPG_KEY_FILE"
    check_status "Failed to download and install GPG key"
    sudo chmod 644 "$GPG_KEY_FILE"
    check_status "Failed to set permissions on GPG key file"
else
    log_info "Kubernetes GPG key already exists at $GPG_KEY_FILE"
fi

# Create or backup the repository file
if [ -f "$REPO_FILE" ]; then
    log_info "Backing up existing repository file..."
    sudo cp "$REPO_FILE" "${REPO_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    check_status "Failed to backup repository file"
else
    log_info "Repository file does not exist, creating it..."
    sudo touch "$REPO_FILE"
    check_status "Failed to create repository file"
fi

# Check and correct the repository file content
log_info "Checking and correcting repository file format..."
if grep -qxF "$CORRECT_ENTRY" "$REPO_FILE"; then
    log_info "✅ Repository file is correctly formatted."
else
    log_info "Updating repository file with the correct entry..."
    
    # Check if we should modify or replace
    REPO_CONTENTS=$(cat "$REPO_FILE" 2>/dev/null)
    if [ -z "$REPO_CONTENTS" ]; then
        # File is empty, just add the entry
        echo "$CORRECT_ENTRY" | sudo tee "$REPO_FILE" > /dev/null
    else
        # File has content, try to update the Kubernetes repository line
        if grep -q "pkgs.k8s.io" "$REPO_FILE"; then
            # Replace existing Kubernetes repository line
            sudo sed -i "s|deb \[.*\] https://pkgs.k8s.io.*|$CORRECT_ENTRY|g" "$REPO_FILE"
        else
            # Add as a new line
            echo "$CORRECT_ENTRY" | sudo tee -a "$REPO_FILE" > /dev/null
        fi
    fi
    check_status "Failed to update repository file"
    log_info "✅ Repository file updated successfully."
fi

# Update the package list
log_info "Updating package list..."
if sudo apt-get update; then
    log_info "✅ Package list updated successfully."
else
    log_warning "⚠️ Failed to update package list. Please check your network connection and repository configuration."
fi

# Verify the repository is accessible
if apt-cache policy | grep -q "pkgs.k8s.io"; then
    log_info "✅ Kubernetes repository is accessible."
else
    log_warning "⚠️ Kubernetes repository appears to be inaccessible. Please check your network connection."
fi

log_info "✅ Repository check and update completed successfully."