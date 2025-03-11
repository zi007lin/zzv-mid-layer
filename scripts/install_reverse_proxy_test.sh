#!/usr/bin/env bash

. "$(dirname "$0")/utils.sh"

log_info "Testing Reverse Proxy Setup..."

log_info "Checking NGINX Ingress Controller..."
kubectl get svc | grep nginx-ingress
check_status "❌ NGINX Ingress is not running!"

log_info "Checking SSLH Service..."
kubectl get svc | grep sslh
check_status "❌ SSLH is not running!"

log_info "Testing SSH over port 443..."
ssh -o "StrictHostKeyChecking=no" -p 443 yourserver.com exit
check_status "❌ SSH over port 443 failed!"

log_info "Testing WebSocket connectivity..."
if curl -s -o /dev/null -w "%{http_code}" https://yourserver.com | grep -q "101"; then
    log_info "✅ WebSocket handshake successful!"
else
    log_error "❌ WebSocket handshake failed!"
fi

log_info "✅ Reverse Proxy Test Completed Successfully!"
