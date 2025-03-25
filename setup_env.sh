#!/usr/bin/env bash
set -euo pipefail

# Setup Environment Script for ZZV VPS
# Auto-detects DOMAIN_NAME and REGION based on VPS IP and DNS entries

echo "🔍 Detecting public IP..."
PUBLIC_IP=$(curl -s https://api.ipify.org)
echo "🌐 Public IP: $PUBLIC_IP"

# Define base domain
BASE_DOMAIN="zzv.io"

# Attempt to resolve domain name by matching IP with known DNS records
echo "📡 Querying Cloudflare DNS for A records..."

MATCHED_DOMAIN=""
for SUB in p1-nam p1-emea p1-apac; do
  HOST="${SUB}.${BASE_DOMAIN}"
  IP=$(dig +short "$HOST" | tail -n1)
  if [[ "$IP" == "$PUBLIC_IP" ]]; then
    MATCHED_DOMAIN="$HOST"
    break
  fi
done

if [[ -z "$MATCHED_DOMAIN" ]]; then
  echo "⚠️  Could not auto-match VPS to known subdomain. Please enter manually."
  read -p "Enter your DOMAIN_NAME (e.g. p1-emea.zzv.io): " MATCHED_DOMAIN
fi

export DOMAIN_NAME="$MATCHED_DOMAIN"
export REGION=$(echo "$DOMAIN_NAME" | cut -d'.' -f1 | cut -d'-' -f2)
export VPS_NAME=$(echo "$DOMAIN_NAME" | cut -d'.' -f1)

# Save to file for sourcing in other scripts
cat <<EOF > ~/zzv.env
export DOMAIN_NAME="$DOMAIN_NAME"
export REGION="$REGION"
export VPS_NAME="$VPS_NAME"
EOF

echo "✅ Environment variables detected and saved:"
cat ~/zzv.env

# Optional: auto-source for current shell
source ~/zzv.env
