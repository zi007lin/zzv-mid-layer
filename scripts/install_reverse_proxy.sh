#!/usr/bin/env bash

# Source utility functions
SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/utils.sh"

# Default configuration
DOMAIN="p1-emea.zzv.io"
ENVIRONMENT="dev"
INGRESS_NAMESPACE="default"
BACKEND_NAME="sslh"
ENABLE_METRICS="false"
CUSTOM_TLS_CERT=""
CUSTOM_TLS_KEY=""
CLEANUP_ON_FAILURE="false"
MULTIPLE_BACKENDS="false"
SECONDARY_BACKEND=""
TIMEOUT=120

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain=*)
            DOMAIN="${1#*=}"
            shift
            ;;
        --environment=*)
            ENVIRONMENT="${1#*=}"
            shift
            ;;
        --namespace=*)
            INGRESS_NAMESPACE="${1#*=}"
            shift
            ;;
        --backend-name=*)
            BACKEND_NAME="${1#*=}"
            shift
            ;;
        --enable-metrics)
            ENABLE_METRICS="true"
            shift
            ;;
        --custom-tls-cert=*)
            CUSTOM_TLS_CERT="${1#*=}"
            shift
            ;;
        --custom-tls-key=*)
            CUSTOM_TLS_KEY="${1#*=}"
            shift
            ;;
        --cleanup-on-failure)
            CLEANUP_ON_FAILURE="true"
            shift
            ;;
        --multiple-backends)
            MULTIPLE_BACKENDS="true"
            shift
            ;;
        --secondary-backend=*)
            SECONDARY_BACKEND="${1#*=}"
            shift
            ;;
        --timeout=*)
            TIMEOUT="${1#*=}"
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --domain=DOMAIN                Domain name for the Ingress (default: p1-emea.zzv.io)"
            echo "  --environment=ENV              Environment type: dev or prod (default: dev)"
            echo "  --namespace=NAMESPACE          Kubernetes namespace (default: default)"
            echo "  --backend-name=NAME            Name for the backend service (default: sslh)"
            echo "  --enable-metrics               Enable Prometheus metrics"
            echo "  --custom-tls-cert=PATH         Path to custom TLS certificate"
            echo "  --custom-tls-key=PATH          Path to custom TLS key"
            echo "  --cleanup-on-failure           Clean up resources if installation fails"
            echo "  --multiple-backends            Configure for multiple backend services"
            echo "  --secondary-backend=NAME       Name of secondary backend service"
            echo "  --timeout=SECONDS              Timeout for wait operations (default: 120)"
            echo "  --help                         Display this help message"
            exit 0
            ;;
        *)
            log_warning "Unknown option: $1"
            shift
            ;;
    esac
done

# Function to clean up resources
cleanup_resources() {
    if [ "$CLEANUP_ON_FAILURE" = "true" ]; then
        log_info "Cleaning up installed resources..."
        
        # Delete Ingress
        kubectl delete ingress websocket-ingress -n "$INGRESS_NAMESPACE" --ignore-not-found
        
        # Delete TLS secret
        kubectl delete secret "${BACKEND_NAME}-nginx-tls" -n "$INGRESS_NAMESPACE" --ignore-not-found
        
        # Uninstall Helm releases
        if helm list -n "$INGRESS_NAMESPACE" | grep -q "$BACKEND_NAME"; then
            helm uninstall "$BACKEND_NAME" -n "$INGRESS_NAMESPACE"
        fi
        
        if helm list -n "$INGRESS_NAMESPACE" | grep -q "nginx-ingress"; then
            helm uninstall nginx-ingress -n "$INGRESS_NAMESPACE"
        fi
        
        log_info "Cleanup completed."
    fi
}

# Set trap for cleanup on failure
if [ "$CLEANUP_ON_FAILURE" = "true" ]; then
    trap 'log_error "Installation failed. Running cleanup..."; cleanup_resources; exit 1' ERR
fi

# Create namespace if it doesn't exist
if ! kubectl get namespace "$INGRESS_NAMESPACE" &>/dev/null; then
    log_info "Creating namespace $INGRESS_NAMESPACE..."
    kubectl create namespace "$INGRESS_NAMESPACE"
    check_status "Namespace creation"
fi

# Ensure Helm Repos Are Up-to-Date
log_info "Adding Helm repositories..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
check_status "Helm repo update"

# Prepare values for environment
if [ "$ENVIRONMENT" = "prod" ]; then
    REPLICAS=2
    RESOURCES="--set controller.resources.requests.cpu=100m --set controller.resources.requests.memory=128Mi"
    if [ "$ENABLE_METRICS" = "true" ]; then
        METRICS="--set controller.metrics.enabled=true --set controller.metrics.serviceMonitor.enabled=true"
    else
        METRICS=""
    fi
else
    REPLICAS=1
    RESOURCES=""
    METRICS=""
fi

# Install NGINX Ingress Controller (Only If Not Installed)
if helm list -n "$INGRESS_NAMESPACE" | grep -q "nginx-ingress"; then
    log_info "✅ NGINX Ingress is already installed. Skipping installation."
else
    log_info "Installing NGINX Ingress Controller..."
    helm install nginx-ingress ingress-nginx/ingress-nginx \
      --namespace "$INGRESS_NAMESPACE" \
      --set controller.service.type=LoadBalancer \
      --set controller.service.externalTrafficPolicy=Local \
      --set controller.replicaCount=$REPLICAS \
      $RESOURCES $METRICS
    check_status "NGINX Ingress installation"
    
    # Wait for NGINX Ingress to be ready
    log_info "Waiting for NGINX Ingress to be ready..."
    kubectl wait --namespace "$INGRESS_NAMESPACE" --for=condition=available --timeout="${TIMEOUT}s" \
        deployment/nginx-ingress-ingress-nginx-controller
    check_status "NGINX Ingress readiness timeout"
fi

# Install NGINX for Backend (Only If Not Installed)
if helm list -n "$INGRESS_NAMESPACE" | grep -q "$BACKEND_NAME"; then
    log_info "✅ Backend NGINX is already installed. Skipping installation."
else
    log_info "Installing backend NGINX..."
    helm install "$BACKEND_NAME" bitnami/nginx \
      --namespace "$INGRESS_NAMESPACE" \
      --set service.type=ClusterIP \
      --set service.ports.http=80 \
      --set service.ports.https=443 \
      --set replicaCount=$REPLICAS
    check_status "Backend NGINX installation"
    
    # Wait for NGINX to be ready
    log_info "Waiting for backend NGINX to be ready..."
    kubectl wait --namespace "$INGRESS_NAMESPACE" --for=condition=ready --timeout="${TIMEOUT}s" \
        pod -l app.kubernetes.io/instance="$BACKEND_NAME"
    check_status "Backend NGINX readiness timeout"
fi

# Handle TLS certificate
TLS_SECRET_NAME="${BACKEND_NAME}-nginx-tls"

if ! kubectl get secret "$TLS_SECRET_NAME" -n "$INGRESS_NAMESPACE" &>/dev/null; then
    if [ -n "$CUSTOM_TLS_CERT" ] && [ -n "$CUSTOM_TLS_KEY" ]; then
        # Use custom certificates
        log_info "Creating TLS secret from provided certificate and key..."
        if [ -f "$CUSTOM_TLS_CERT" ] && [ -f "$CUSTOM_TLS_KEY" ]; then
            kubectl create secret tls "$TLS_SECRET_NAME" \
                --namespace "$INGRESS_NAMESPACE" \
                --key "$CUSTOM_TLS_KEY" \
                --cert "$CUSTOM_TLS_CERT"
            check_status "TLS secret creation from custom certificates"
        else
            log_error "Custom certificate or key file not found. Falling back to self-signed certificate."
            # Fall through to self-signed certificate creation
        fi
    fi
    
    # Create self-signed certificate if no custom cert or if custom cert failed
    if ! kubectl get secret "$TLS_SECRET_NAME" -n "$INGRESS_NAMESPACE" &>/dev/null; then
        log_info "Creating self-signed TLS certificate..."
        mkdir -p "$SCRIPT_DIR/temp-certs"
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$SCRIPT_DIR/temp-certs/tls.key" \
            -out "$SCRIPT_DIR/temp-certs/tls.crt" \
            -subj "/CN=$DOMAIN" \
            -addext "subjectAltName = DNS:$DOMAIN"
        
        kubectl create secret tls "$TLS_SECRET_NAME" \
            --namespace "$INGRESS_NAMESPACE" \
            --key "$SCRIPT_DIR/temp-certs/tls.key" \
            --cert "$SCRIPT_DIR/temp-certs/tls.crt"
        
        rm -rf "$SCRIPT_DIR/temp-certs"
        check_status "TLS certificate creation"
    fi
fi

# Ensure service selector matches pod labels
log_info "Updating service selector to match pod labels..."
kubectl patch svc "$BACKEND_NAME-nginx" -n "$INGRESS_NAMESPACE" \
    -p '{"spec":{"selector":{"app.kubernetes.io/instance":"'$BACKEND_NAME'", "app.kubernetes.io/name":"nginx"}}}'
check_status "Service selector update"

# Ensure service is ClusterIP
log_info "Ensuring service type is ClusterIP..."
kubectl patch svc "$BACKEND_NAME-nginx" -n "$INGRESS_NAMESPACE" -p '{"spec":{"type":"ClusterIP"}}'
check_status "Service type update"

# Create Ingress Configuration
INGRESS_FILE="$SCRIPT_DIR/ingress-websocket.yaml"
log_info "Creating WebSockets Ingress configuration file..."

# Handle multiple backends if requested
if [ "$MULTIPLE_BACKENDS" = "true" ] && [ -n "$SECONDARY_BACKEND" ]; then
    SECONDARY_PATH='
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: '$SECONDARY_BACKEND'
            port:
              number: 80'
else
    SECONDARY_PATH=""
fi

cat > "$INGRESS_FILE" << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: websocket-ingress
  namespace: $INGRESS_NAMESPACE
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "3600"
    nginx.ingress.kubernetes.io/websocket-services: "$BACKEND_NAME-nginx"
    nginx.ingress.kubernetes.io/proxy-buffer-size: "8k"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - $DOMAIN
    secretName: $TLS_SECRET_NAME
  rules:
  - host: $DOMAIN
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $BACKEND_NAME-nginx
            port:
              number: 80$SECONDARY_PATH
EOF
check_status "Ingress configuration file creation"

# Apply Ingress Configuration
log_info "Applying WebSockets Ingress configuration..."
kubectl apply -f "$INGRESS_FILE"
check_status "WebSocket Ingress setup"

# Verify installation
log_info "Verifying installation..."
sleep 5  # Give a little time for things to reconcile

# Check if the Ingress is properly configured
IP=$(kubectl get ingress websocket-ingress -n "$INGRESS_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -n "$IP" ]; then
    log_info "✅ Ingress is properly configured with IP: $IP"
else
    log_warning "⚠️ Ingress does not have an IP address yet. It may take a few minutes."
fi

# Check if the service has endpoints
ENDPOINTS=$(kubectl get endpoints "$BACKEND_NAME-nginx" -n "$INGRESS_NAMESPACE" -o jsonpath='{.subsets[0].addresses[0].ip}')
if [ -n "$ENDPOINTS" ]; then
    log_info "✅ Service has endpoints: $ENDPOINTS"
else
    log_warning "⚠️ Service does not have endpoints. Check selector and pod labels."
fi

# Added step to explicitly patch the Ingress port if needed
log_info "Ensuring Ingress is configured for port 80..."
kubectl patch ingress websocket-ingress -n "$INGRESS_NAMESPACE" \
    --type=json -p='[{"op": "replace", "path": "/spec/rules/0/http/paths/0/backend/service/port/number", "value": 80}]'
check_status "Ingress port update"

log_info "✅ Reverse Proxy Installation Complete!"
log_info "Your application should be accessible at https://$DOMAIN"

if [ "$ENVIRONMENT" = "dev" ]; then
    log_info "NOTE: You are running in development mode. For production, use --environment=prod"
fi

log_info "NOTE: If you see the default NGINX welcome page, you'll need to configure your application content."
log_info "To replace the default content, add your files to the NGINX pod or reconfigure the deployment:"
log_info "  kubectl exec -it deployment/$BACKEND_NAME-nginx -n $INGRESS_NAMESPACE -- bash"
log_info "  # Then edit /app/html/index.html or add your content"