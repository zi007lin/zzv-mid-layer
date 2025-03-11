#!/usr/bin/env bash

# Source utility functions
SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/utils.sh"

# Set default domain or use the one provided as an argument
DOMAIN=${1:-"p1-emea.zzv.io"}

log_info "Testing Reverse Proxy Setup for domain: $DOMAIN"

# Check NGINX Ingress Controller
log_info "Checking NGINX Ingress Controller..."
if kubectl get deployment nginx-ingress-ingress-nginx-controller &>/dev/null; then
    READY=$(kubectl get deployment nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.readyReplicas}')
    if [[ "$READY" -gt 0 ]]; then
        log_info "✅ NGINX Ingress Controller is running with $READY ready replicas"
    else
        log_error "❌ NGINX Ingress Controller pods are not ready"
        exit 1
    fi
else
    log_error "❌ NGINX Ingress Controller is not installed"
    exit 1
fi

# Check Backend NGINX Service
log_info "Checking Backend NGINX Service..."
if kubectl get svc sslh-nginx &>/dev/null; then
    ENDPOINTS=$(kubectl get endpoints sslh-nginx -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
    if [[ -n "$ENDPOINTS" ]]; then
        log_info "✅ Backend NGINX Service has endpoints: $ENDPOINTS"
    else
        log_error "❌ Backend NGINX Service has no endpoints"
        exit 1
    fi
else
    log_error "❌ Backend NGINX Service is not installed"
    exit 1
fi

# Check Ingress Resource
log_info "Checking Ingress Resource..."
if kubectl get ingress websocket-ingress &>/dev/null; then
    INGRESS_IP=$(kubectl get ingress websocket-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [[ -n "$INGRESS_IP" ]]; then
        log_info "✅ Ingress is configured with IP: $INGRESS_IP"
    else
        log_warning "⚠️ Ingress does not have an IP address yet"
    fi
else
    log_error "❌ Ingress resource is not installed"
    exit 1
fi

# Check TLS Secret
log_info "Checking TLS Secret..."
if kubectl get secret sslh-nginx-tls &>/dev/null; then
    log_info "✅ TLS Secret exists"
else
    log_error "❌ TLS Secret does not exist"
    exit 1
fi

# Test HTTP to HTTPS Redirect
log_info "Testing HTTP to HTTPS Redirect..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$DOMAIN)
if [[ "$HTTP_CODE" == "308" ]]; then
    log_info "✅ HTTP to HTTPS redirect is working (Status: $HTTP_CODE)"
else
    log_warning "⚠️ HTTP to HTTPS redirect returned unexpected status: $HTTP_CODE"
fi

# Test HTTPS Connection
log_info "Testing HTTPS Connection..."
HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k https://$DOMAIN)
if [[ "$HTTPS_CODE" == "200" ]]; then
    log_info "✅ HTTPS connection is working (Status: $HTTPS_CODE)"
else
    log_error "❌ HTTPS connection failed with status: $HTTPS_CODE"
    exit 1
fi

# Test WebSocket Connection (Basic Check)
log_info "Testing WebSocket Handshake (Basic Check)..."
WS_HEADERS=$(curl -s -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" -H "Sec-WebSocket-Version: 13" -k https://$DOMAIN)
if echo "$WS_HEADERS" | grep -q "101 Switching Protocols"; then
    log_info "✅ WebSocket handshake successful"
else
    log_warning "⚠️ WebSocket handshake unsuccessful (this may be normal if your application doesn't support WebSockets yet)"
fi

log_info "✅ Reverse Proxy Test Completed!"
log_info "Your application should be accessible at https://$DOMAIN"