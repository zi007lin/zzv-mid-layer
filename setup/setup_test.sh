#!/bin/bash

echo "===== Running Environment Verification ====="

# Function to check if a package is installed
check_package() {
    if dpkg -l | grep -q "^ii  $1 "; then
        echo "[✔] Package '$1' is installed."
    else
        echo "[✘] Package '$1' is MISSING!"
    fi
}

# Function to check if a service is active
check_service() {
    if systemctl is-active --quiet "$1"; then
        echo "[✔] Service '$1' is running."
    else
        echo "[✘] Service '$1' is NOT running!"
    fi
}

# Function to check if an environment variable is set
check_env_variable() {
    if printenv | grep -q "^$1="; then
        echo "[✔] Environment variable '$1' is set."
    else
        echo "[✘] Environment variable '$1' is MISSING!"
    fi
}

echo "Checking installed packages..."
check_package "yq"
check_package "curl"
check_package "wget"
check_package "git"
check_package "vim"
check_package "ufw"

echo ""
echo "Checking firewall status..."
sudo ufw status | grep -q "Status: active" && echo "[✔] Firewall is enabled." || echo "[✘] Firewall is NOT enabled!"

echo ""
echo "Checking network configuration..."
if ip a | grep -q "inet "; then
    echo "[✔] Network interfaces are configured."
else
    echo "[✘] No network interfaces detected!"
fi

echo ""
echo "Checking running services..."
check_service "ssh"
check_service "ufw"
check_service "docker"

echo ""
echo "Checking user permissions..."
if id | grep -q "sudo"; then
    echo "[✔] User is in the sudo group."
else
    echo "[✘] User is NOT in the sudo group!"
fi

echo ""
echo "Checking environment variables..."
check_env_variable "PATH"
check_env_variable "HOME"
check_env_variable "SHELL"

echo ""
echo "===== Environment Verification Complete ====="
