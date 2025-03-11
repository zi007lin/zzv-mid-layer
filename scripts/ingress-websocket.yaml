#!/usr/bin/env bash

# Source utility functions
SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/utils.sh"

# Ensure Helm Repos Are Up-to-Date
log_info "Adding Helm repositories..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
check_status "Helm repo update"

# Install NGINX Ingress Controller (Only If Not Installed)
if helm list -A | grep -q "nginx-ingress"; then
    log_info "✅ NGINX Ingress is already installed. Skipping installation."
else
    log_info "Installing NGINX Ingress Controller..."
    helm install nginx-ingress ingress-nginx/ingress-nginx \
      --set controller.service.type=LoadBalancer \
      --set controller.service.externalTrafficPolicy=Local
    check_status "❌ NGINX Ingress installation failed"
    
    # Wait for NGINX Ingress to be ready
    log_info "Waiting for NGINX Ingress to be ready..."
    kubectl wait --for=condition=available --timeout=120s deployment/nginx-ingress-ingress-nginx-controller
    check_status "❌ NGINX Ingress did not become ready in time"
fi

# Install NGINX for Backend (Only If Not Installed)
if helm list -A | grep -q "sslh"; then
    log_info "✅ Backend NGINX is already installed. Skipping installation."
else
    log_info "Installing backend NGINX..."
    helm install sslh bitnami/nginx \
      --set service.type=ClusterIP \
      --set service.ports.http=80 \
      --set service.ports.https=443
    check_status "❌ Backend NGINX installation failed"
    
    # Wait for NGINX to be ready
    log_info "Waiting for backend NGINX to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=sslh --timeout=120s
    check_status "❌ Backend NGINX pod did not become ready in time"
fi

# Create or update a self-signed TLS certificate if it doesn't exist
if ! kubectl get secret sslh-nginx-tls &>/dev/null; then
    log_info "Creating self-signed TLS certificate..."
    mkdir -p "$SCRIPT_DIR/temp-certs"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SCRIPT_DIR/temp-certs/tls.key" \
        -out "$SCRIPT_DIR/temp-certs/tls.crt" \
        -subj "/CN=p1-emea.zzv.io" \
        -addext "subjectAltName = DNS:p1-emea.zzv.io"
    
    kubectl create secret tls sslh-nginx-tls \
        --key "$SCRIPT_DIR/temp-certs/tls.key" \
        --cert "$SCRIPT_DIR/temp-certs/tls.crt"
    
    rm -rf "$SCRIPT_DIR/temp-certs"
    check_status "❌ TLS certificate creation failed"
fi

# Ensure service selector matches pod labels
log_info "Updating service selector to match pod labels..."
kubectl patch svc sslh-nginx -p '{"spec":{"selector":{"app.kubernetes.io/instance":"sslh", "app.kubernetes.io/name":"nginx"}}}'
check_status "❌ Service selector update failed"

# Ensure service is ClusterIP
log_info "Ensuring service type is ClusterIP..."
kubectl patch svc sslh-nginx -p '{"spec":{"type":"ClusterIP"}}'
check_status "❌ Service type update failed"

# Create WebSockets Ingress Configuration file if it doesn't exist
if [ ! -f "$SCRIPT_DIR/ingress-websocket.yaml" ]; then
    log_info "Creating WebSockets Ingress configuration file..."
    cat > "$SCRIPT_DIR/ingress-websocket.yaml" << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: websocket-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "3600"
    nginx.ingress.kubernetes.io/websocket-services: "sslh-nginx"
    nginx.ingress.kubernetes.io/proxy-buffer-size: "8k"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - p1-emea.zzv.io
    secretName: sslh-nginx-tls
  rules:
  - host: p1-emea.zzv.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: sslh-nginx
            port:
              number: 80
EOF
    check_status "❌ Failed to create Ingress YAML file"
fi

# Apply WebSockets Ingress Configuration
log_info "Applying WebSockets Ingress configuration..."
kubectl apply -f "$SCRIPT_DIR/ingress-websocket.yaml"
check_status "❌ WebSocket Ingress setup failed"

# Verify installation
log_info "Verifying installation..."
sleep 5  # Give a little time for things to reconcile

# Check if the Ingress is properly configured
IP=$(kubectl get ingress websocket-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -n "$IP" ]; then
    log_info "✅ Ingress is properly configured with IP: $IP"
else
    log_warning "⚠️ Ingress does not have an IP address yet. It may take a few minutes."
fi

# Check if the service has endpoints
ENDPOINTS=$(kubectl get endpoints sslh-nginx -o jsonpath='{.subsets[0].addresses[0].ip}')
if [ -n "$ENDPOINTS" ]; then
    log_info "✅ Service has endpoints: $ENDPOINTS"
else
    log_warning "⚠️ Service does not have endpoints. Check selector and pod labels."
fi

# Added step to explicitly patch the Ingress port if needed
log_info "Ensuring Ingress is configured for port 80..."
kubectl patch ingress websocket-ingress --type=json -p='[{"op": "replace", "path": "/spec/rules/0/http/paths/0/backend/service/port/number", "value": 80}]'
check_status "❌ Ingress port update failed"

log_info "✅ Reverse Proxy Installation Complete!"
log_info "Your application should be accessible at https://p1-emea.zzv.io"
log_info "NOTE: If you see the default NGINX welcome page, you'll need to configure your application content."
log_info "To replace the default content, add your files to the NGINX pod or reconfigure the deployment."