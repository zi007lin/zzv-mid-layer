#!/bin/bash

# Create a directory for output files
OUTPUT_DIR="system_info_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"
echo "Creating output directory: $OUTPUT_DIR"

# System details
echo "Gathering system information..."
echo "# System Information ($(date))" > "$OUTPUT_DIR/system_info.txt"
echo "## Kernel and OS Details" >> "$OUTPUT_DIR/system_info.txt"
uname -a >> "$OUTPUT_DIR/system_info.txt"
echo "" >> "$OUTPUT_DIR/system_info.txt"
echo "## OS Release Information" >> "$OUTPUT_DIR/system_info.txt"
lsb_release -a 2>/dev/null >> "$OUTPUT_DIR/system_info.txt" || cat /etc/os-release >> "$OUTPUT_DIR/system_info.txt"

# Available resources
echo "Checking disk usage..."
echo "## Disk Usage" >> "$OUTPUT_DIR/system_info.txt"
echo "" >> "$OUTPUT_DIR/system_info.txt"
df -h >> "$OUTPUT_DIR/system_info.txt"
echo "" >> "$OUTPUT_DIR/system_info.txt"

echo "Checking memory usage..."
echo "## Memory Information" >> "$OUTPUT_DIR/system_info.txt"
echo "" >> "$OUTPUT_DIR/system_info.txt"
free -m >> "$OUTPUT_DIR/system_info.txt"
echo "" >> "$OUTPUT_DIR/system_info.txt"
echo "## Memory Details" >> "$OUTPUT_DIR/system_info.txt"
cat /proc/meminfo >> "$OUTPUT_DIR/memory_details.txt"

# CPU information
echo "Gathering CPU information..."
echo "## CPU Information" >> "$OUTPUT_DIR/system_info.txt"
echo "" >> "$OUTPUT_DIR/system_info.txt"
lscpu >> "$OUTPUT_DIR/system_info.txt"
echo "" >> "$OUTPUT_DIR/system_info.txt"
cat /proc/cpuinfo > "$OUTPUT_DIR/cpu_details.txt"

# Installed packages
echo "Listing installed packages..."
if command -v dpkg &> /dev/null; then
  dpkg --list > "$OUTPUT_DIR/installed_packages.txt"
elif command -v rpm &> /dev/null; then
  rpm -qa > "$OUTPUT_DIR/installed_packages.txt"
elif command -v pacman &> /dev/null; then
  pacman -Q > "$OUTPUT_DIR/installed_packages.txt"
else
  echo "No package manager detected (dpkg, rpm, pacman)" > "$OUTPUT_DIR/installed_packages.txt"
fi

# Running services
echo "Checking running services..."
if command -v systemctl &> /dev/null; then
  systemctl list-units --type=service > "$OUTPUT_DIR/running_services.txt"
  # Additional check for specific services mentioned in setup.sh
  for service in sslh nginx docker kubelet prometheus grafana-server; do
    echo "## Status of $service:" >> "$OUTPUT_DIR/critical_services.txt"
    systemctl status $service 2>/dev/null >> "$OUTPUT_DIR/critical_services.txt" || echo "Service $service not found" >> "$OUTPUT_DIR/critical_services.txt"
    echo "" >> "$OUTPUT_DIR/critical_services.txt"
  done
else
  echo "Systemd not available" > "$OUTPUT_DIR/running_services.txt"
  service --status-all > "$OUTPUT_DIR/running_services.txt" 2>/dev/null || echo "Service command not available" >> "$OUTPUT_DIR/running_services.txt"
fi

# Network settings
echo "Collecting network information..."
echo "## Network Interfaces" > "$OUTPUT_DIR/network_info.txt"
ip a > "$OUTPUT_DIR/network_info.txt" 2>/dev/null || ifconfig > "$OUTPUT_DIR/network_info.txt" 2>/dev/null || echo "No network tools found" > "$OUTPUT_DIR/network_info.txt"

echo "## Routing Table" >> "$OUTPUT_DIR/network_info.txt"
ip route >> "$OUTPUT_DIR/network_info.txt" 2>/dev/null || route -n >> "$OUTPUT_DIR/network_info.txt" 2>/dev/null

echo "## Network Ports" > "$OUTPUT_DIR/network_ports.txt"
netstat -tulnp > "$OUTPUT_DIR/network_ports.txt" 2>/dev/null || ss -tulnp > "$OUTPUT_DIR/network_ports.txt" 2>/dev/null || echo "No netstat or ss command found" > "$OUTPUT_DIR/network_ports.txt"

# Check for port 443 specifically
echo "## Port 443 Usage Check" > "$OUTPUT_DIR/port_443_check.txt"
netstat -tulnp | grep :443 >> "$OUTPUT_DIR/port_443_check.txt" 2>/dev/null || ss -tulnp | grep :443 >> "$OUTPUT_DIR/port_443_check.txt" 2>/dev/null
lsof -i :443 >> "$OUTPUT_DIR/port_443_check.txt" 2>/dev/null

# Firewall rules
echo "Checking firewall configuration..."
if command -v ufw &> /dev/null; then
  echo "## UFW Status" > "$OUTPUT_DIR/firewall_status.txt"
  ufw status verbose > "$OUTPUT_DIR/firewall_status.txt" 2>/dev/null
else
  echo "UFW not installed" > "$OUTPUT_DIR/firewall_status.txt"
fi

echo "## IPTables Rules" > "$OUTPUT_DIR/iptables_rules.txt"
iptables -L -v -n > "$OUTPUT_DIR/iptables_rules.txt" 2>/dev/null || echo "Unable to get iptables rules, may require root privileges" > "$OUTPUT_DIR/iptables_rules.txt"

# Environment variables
echo "Saving environment variables..."
printenv | sort > "$OUTPUT_DIR/env_variables.txt"

# User permissions
echo "Checking user permissions..."
echo "## Current User ID Information" > "$OUTPUT_DIR/user_permissions.txt"
id >> "$OUTPUT_DIR/user_permissions.txt"
echo "" >> "$OUTPUT_DIR/user_permissions.txt"
echo "## Groups" >> "$OUTPUT_DIR/user_permissions.txt"
groups >> "$OUTPUT_DIR/user_permissions.txt"
echo "" >> "$OUTPUT_DIR/user_permissions.txt"
echo "## Docker Group Members (for Docker access)" >> "$OUTPUT_DIR/user_permissions.txt"
getent group docker >> "$OUTPUT_DIR/user_permissions.txt" 2>/dev/null || echo "Docker group not found" >> "$OUTPUT_DIR/user_permissions.txt"

# Check Docker and Kubernetes status
echo "Checking container systems..."
if command -v docker &> /dev/null; then
  echo "## Docker Info" > "$OUTPUT_DIR/docker_info.txt"
  docker info >> "$OUTPUT_DIR/docker_info.txt" 2>/dev/null || echo "Error running docker info, check permissions" >> "$OUTPUT_DIR/docker_info.txt"
  echo "" >> "$OUTPUT_DIR/docker_info.txt"
  echo "## Docker Containers" >> "$OUTPUT_DIR/docker_info.txt"
  docker ps -a >> "$OUTPUT_DIR/docker_info.txt" 2>/dev/null || echo "Error listing containers" >> "$OUTPUT_DIR/docker_info.txt"
else
  echo "Docker not installed" > "$OUTPUT_DIR/docker_info.txt"
fi

if command -v kubectl &> /dev/null; then
  echo "## Kubernetes Nodes" > "$OUTPUT_DIR/kubernetes_info.txt"
  kubectl get nodes -o wide >> "$OUTPUT_DIR/kubernetes_info.txt" 2>/dev/null || echo "Error getting Kubernetes nodes" >> "$OUTPUT_DIR/kubernetes_info.txt"
  echo "" >> "$OUTPUT_DIR/kubernetes_info.txt"
  echo "## Kubernetes Pods" >> "$OUTPUT_DIR/kubernetes_info.txt"
  kubectl get pods --all-namespaces >> "$OUTPUT_DIR/kubernetes_info.txt" 2>/dev/null || echo "Error getting Kubernetes pods" >> "$OUTPUT_DIR/kubernetes_info.txt"
else
  echo "Kubectl not installed" > "$OUTPUT_DIR/kubernetes_info.txt"
fi

# Check SSLH and NGINX configs if they exist
echo "Checking server configurations..."
if [ -f /etc/default/sslh ]; then
  echo "## SSLH Configuration" > "$OUTPUT_DIR/sslh_config.txt"
  cat /etc/default/sslh > "$OUTPUT_DIR/sslh_config.txt"
else
  echo "SSLH configuration not found at /etc/default/sslh" > "$OUTPUT_DIR/sslh_config.txt"
fi

if [ -f /etc/nginx/sites-available/default ]; then
  echo "## NGINX Default Site Configuration" > "$OUTPUT_DIR/nginx_config.txt"
  cat /etc/nginx/sites-available/default > "$OUTPUT_DIR/nginx_config.txt"
else
  echo "NGINX configuration not found at /etc/nginx/sites-available/default" > "$OUTPUT_DIR/nginx_config.txt"
  # Try to find any nginx configs
  find /etc/nginx -type f -name "*.conf" | xargs cat > "$OUTPUT_DIR/nginx_configs_found.txt" 2>/dev/null
fi

# Create a summary file
echo "Creating summary report..."
{
  echo "# System Information Summary"
  echo "Generated on: $(date)"
  echo ""
  echo "## System Overview"
  echo "- Hostname: $(hostname)"
  echo "- Kernel: $(uname -r)"
  echo "- OS: $(lsb_release -d 2>/dev/null | cut -f2- || cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f2)"
  echo ""
  echo "## Key Services Status"
  echo "- SSH: $(systemctl is-active ssh 2>/dev/null || echo 'unknown')"
  echo "- SSLH: $(systemctl is-active sslh 2>/dev/null || echo 'unknown')"
  echo "- NGINX: $(systemctl is-active nginx 2>/dev/null || echo 'unknown')"
  echo "- Docker: $(systemctl is-active docker 2>/dev/null || echo 'unknown')"
  echo "- Kubernetes: $(systemctl is-active kubelet 2>/dev/null || echo 'unknown')"
  echo ""
  echo "## Key Ports"
  if netstat -tulnp 2>/dev/null | grep -q ":443 "; then
    echo "- Port 443: IN USE"
  else
    echo "- Port 443: NOT IN USE"
  fi
  if netstat -tulnp 2>/dev/null | grep -q ":4443 "; then
    echo "- Port 4443: IN USE"
  else
    echo "- Port 4443: NOT IN USE"
  fi
  echo ""
  echo "## Disk Usage"
  df -h / | tail -n 1 | awk '{print "- Root: " $5 " used (" $3 " of " $2 ")"}'
  echo ""
  echo "## Memory Usage"
  free -h | grep Mem | awk '{print "- Memory: " $3 " used out of " $2 " (" int($3/$2*100) "%)"}'
  echo ""
} > "$OUTPUT_DIR/summary.txt"

# Create a tar.gz archive
echo "Creating archive of all collected information..."
tar -czf "system_info_$(date +%Y%m%d_%H%M%S).tar.gz" "$OUTPUT_DIR"

echo "Information gathered successfully. Results saved in $OUTPUT_DIR and archived."
echo "To view the summary: cat $OUTPUT_DIR/summary.txt"
