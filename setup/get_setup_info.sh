#!/bin/bash

# System details
echo "Gathering system information..."
uname -a >> system_info.txt
lsb_release -a >> system_info.txt

# Available resources
df -h >> system_info.txt
free -m >> system_info.txt

# Installed packages
dpkg --list > installed_packages.txt

# Running services
systemctl list-units --type=service > running_services.txt

# Network settings
ip a > network_info.txt
netstat -tulnp > network_ports.txt

# Firewall rules
ufw status > firewall_status.txt
iptables -L > iptables_rules.txt

# Environment variables
printenv > env_variables.txt

# User permissions
id > user_permissions.txt
groups > user_groups.txt

echo "Information gathered successfully."
