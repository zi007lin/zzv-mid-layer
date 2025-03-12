#!/usr/bin/env bash

echo "Creating Cloudflare IP ranges and allowed servers list..."

# Ensure directories exist
sudo mkdir -p /opt/cloudflare
sudo mkdir -p /opt/zzv

# Save Cloudflare IP list
sudo tee /opt/cloudflare/ips.txt > /dev/null << 'EOF'
# Cloudflare IPv4 Ranges
# Source: Cloudflare IP Ranges Documentation
# Last Updated: 2025-03-11

# Large blocks
104.16.0.0/12
172.64.0.0/13
162.158.0.0/15
198.41.128.0/17

# Medium blocks
141.101.64.0/18
108.162.192.0/18
188.114.96.0/20
173.245.48.0/20
103.22.200.0/22
103.31.4.0/22
38.135.186.0/23

# Smaller blocks
197.234.240.0/22
185.122.0.0/22
185.212.144.0/22
102.177.189.0/24

# Cloudflare 8.* ranges
8.6.112.0/24
8.6.144.0/24
EOF

# Set appropriate permissions
sudo chmod 644 /opt/cloudflare/ips.txt
sudo chown root:root /opt/cloudflare/ips.txt

# Create a placeholder for ZZV servers
sudo tee /opt/zzv/allowed-servers.txt > /dev/null << 'EOF'
# ZZV Servers IP Allowlist
# Last Updated: 2025-03-11

# Add your ZZV server IPs below (one per line)
# Example:
# 192.168.1.100
EOF

# Set appropriate permissions
sudo chmod 644 /opt/zzv/allowed-servers.txt
sudo chown root:root /opt/zzv/allowed-servers.txt

echo "Cloudflare IP ranges and ZZV allowed servers list have been created."
