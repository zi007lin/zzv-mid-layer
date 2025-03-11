#!/usr/bin/env bash

# Source utility functions
SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/utils.sh"

# Ensure Helm Repos Are Up-to-Date
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install NGINX Ingress Controller (Only If Not Installed)
if helm list -A | grep -q "nginx-ingress"; then
    log_info "✅ NGINX Ingress is already installed. Skipping installation."
else
    log_info "Installing NGINX Ingress Controller..."
    helm install nginx-ingress ingress-nginx/ingress-nginx \
      --set controller.service.type=LoadBalancer \
      --set controller.service.externalTrafficPolicy=Local
    check_status "❌ NGINX Ingress installation failed"
fi

# Install SSLH for SSH and HTTPS multiplexing (Only If Not Installed)
if helm list -A | grep -q "sslh"; then
    log_info "✅ SSLH is already installed. Skipping installation."
else
    log_info "Installing SSLH for SSH and HTTPS multiplexing..."
    helm install sslh bitnami/nginx \
      --set service.type=LoadBalancer \
      --set service.ports.http=80 \
      --set service.ports.https=443
    check_status "❌ SSLH installation failed"
fi

# Apply WebSockets Ingress Configuration
if [ -f "$SCRIPT_DIR/ingress-websocket.yaml" ]; then
    log_info "Applying WebSockets Ingress configuration..."
    kubectl apply -f "$SCRIPT_DIR/ingress-websocket.yaml"
    check_status "❌ WebSocket Ingress setup failed"
else
    log_warning "⚠️  WebSockets Ingress configuration file missing. Skipping."
fi

log_info "✅ Reverse Proxy Installation Complete!"
