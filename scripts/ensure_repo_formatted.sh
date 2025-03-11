#!/bin/bash

# Define the repository file path
REPO_FILE="/etc/apt/sources.list.d/kubernetes.list"

# Define the correct repository entry
CORRECT_ENTRY="deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /"

# Function to log information
log_info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

# Function to log errors
log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

# Check if the repository file exists
if [ ! -f "$REPO_FILE" ]; then
    log_error "Kubernetes repository file not found at $REPO_FILE"
    exit 1
fi

# Backup the existing repository file
log_info "Backing up existing repository file..."
sudo cp "$REPO_FILE" "${REPO_FILE}.bak"

# Check and correct the repository file content
log_info "Checking and correcting repository file format..."
if grep -qxF "$CORRECT_ENTRY" "$REPO_FILE"; then
    log_info "Repository file is correctly formatted."
else
    log_info "Updating repository file with the correct entry..."
    echo "$CORRECT_ENTRY" | sudo tee "$REPO_FILE" > /dev/null
    log_info "Repository file updated successfully."
fi

# Update the package list
log_info "Updating package list..."
sudo apt-get update

log_info "Repository check and update completed successfully."
