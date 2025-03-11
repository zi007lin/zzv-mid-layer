#!/usr/bin/env bash

. "$(dirname "$0")/utils.sh"

log_info "Installing NGINX Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --set controller.service.type=LoadBalancer \
  --set controller.service.externalTrafficPolicy=Local
check_status "❌ NGINX Ingress installation failed"

log_info "Installing SSLH for SSH and HTTPS multiplexing..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install sslh bitnami/nginx \
  --set service.type=LoadBalancer \
  --set service.ports.https=443 \
  --set service.ports.ssh=443
check_status "❌ SSLH installation failed"

log_info "Applying WebSockets Ingress configuration..."
kubectl apply -f "$(dirname "$0")/ingress-websocket.yaml"
check_status "❌ WebSocket Ingress setup failed"

log_info "✅ Reverse Proxy Installation Complete!"
