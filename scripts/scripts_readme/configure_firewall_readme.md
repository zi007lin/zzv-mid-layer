title: "Kubernetes and Kafka Firewall Configuration"
filename: "configure_firewall_readme.md"
content: |
  # 🔒 Kubernetes and Kafka Firewall Configuration

  This guide explains how to use the `configure_firewall.sh` script to secure your Kubernetes cluster and Kafka (KRaft mode) deployment while ensuring REST and WebSocket services remain accessible.

  ## 📋 Overview

  The `configure_firewall.sh` script configures UFW (Uncomplicated Firewall) with rules optimized for:
  - Kubernetes clusters
  - Kafka in KRaft mode
  - WebSocket and REST API access
  - Restricted access to cluster management ports

  By default, it allows public access only to HTTPS (port 443) and HTTP (port 80) for redirects, while restricting Kubernetes and Kafka ports to specified IP ranges or internal networks.

  ## 🔧 Prerequisites

  - Ubuntu-based Linux system
  - UFW installed (`apt install ufw`)
  - Root/sudo privileges
  - (Optional) List of Cloudflare or ZZV server IPs in a text file

  ## 📝 Configuration Options

  The script can be customized using the following environment variables:

  | Variable | Default | Purpose |
  |----------|---------|---------|
  | `ENVIRONMENT` | `production` | Mode of operation (development/production) |
  | `USE_CLOUDFLARE` | `true` | Whether to use Cloudflare IP allowlist |
  | `USE_ZZV_SERVERS` | `false` | Whether to use ZZV servers IP allowlist |
  | `CLOUDFLARE_IPS_FILE` | `/opt/cloudflare/ips.txt` | Path to Cloudflare IPs file |
  | `ZZV_SERVERS_FILE` | `/opt/zzv/allowed-servers.txt` | Path to ZZV servers IPs file |
  | `SSH_PORT` | `22` | SSH port to keep accessible |

  ### 📂 IP Allowlist Files

  Create text files with one IP address or CIDR range per line:

  **Example Cloudflare IPs file:**