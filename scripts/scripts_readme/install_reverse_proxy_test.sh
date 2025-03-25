#!/usr/bin/env bash

# Source utility functions
SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/utils.sh"

# Default configuration
DOMAIN="p1-emea.zzv.io"
NAMESPACE="default"
BACKEND_NAME="sslh"
CHECK_METRICS="false"
CHECK_MULTIPLE_BACKENDS="false"
SECONDARY_BACKEND=""
TLS_SECRET_NAME="sslh-nginx-tls"
EXTENDED_TESTS="false"
REQUEST_COUNT=10
CONCURRENT_USERS=5
TEST_TIMEOUT=5

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain=*)
            DOMAIN="${1#*=}"
            shift
            ;;
        --namespace=*)
            NAMESPACE="${1#*=}"
            shift
            ;;
        --backend-name=*)
            BACKEND_NAME="${1#*=}"
            shift
            ;;
        --check-metrics)
            CHECK_METRICS="true"
            shift
            ;;
        --check-multiple-backends)
            CHECK_MULTIPLE_BACKENDS="true"
            shift
            ;;
        --secondary-backend=*)
            SECONDARY_BACKEND="${1#*=}"
            CHECK_MULTIPLE_BACKENDS="true"
            shift
            ;;
        --tls-secret=*)
            TLS_SECRET_NAME="${1#*=}"
            shift
            ;;
        --extended-tests)
            EXTENDED_TESTS="true"
            shift
            ;;
        --request-count=*)
            REQUEST_COUNT="${1#*=}"
            shift
            ;;
        --concurrent-users=*)
            CONCURRENT_USERS="${1#*=}"
            shift
            ;;
        --test-timeout=*)
            TEST_TIMEOUT="${1#*=}"
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --domain=DOMAIN                Domain name to test (default: p1-emea.zzv.io)"
            echo "  --namespace=NAMESPACE          Kubernetes namespace (default: default)"
            echo "  --backend-name=NAME            Name for the backend service (default: sslh)"
            echo "  --check-metrics                Test metrics endpoint if metrics are enabled"
            echo "  --check-multiple-backends      Test multiple backend configuration"
            echo "  --secondary-backend=NAME       Name of secondary backend service to test"
            echo "  --tls-secret=NAME              Name of the TLS secret (default: sslh-nginx-tls)"
            echo "  --extended-tests               Run additional load and performance tests"
            echo "  --request-count=COUNT          Number of requests for load tests (default: 10)"
            echo "  --concurrent-users=COUNT       Number of concurrent users for load tests (default: 5)"
            echo "  --test-timeout=SECONDS         Timeout for tests in seconds (default: 5)"
            echo "  --help                         Display this help message"
            exit 0
            ;;
        *)
            log_warning "Unknown option: $1"
            shift
            ;;
    esac
done

log_info "Testing Reverse Proxy Setup for domain: $DOMAIN in namespace: $NAMESPACE"

# Check NGINX Ingress Controller
log_info "Checking NGINX Ingress Controller..."
if kubectl get deployment nginx-ingress-ingress-nginx-controller -n "$NAMESPACE" &>/dev/null; then
    READY=$(kubectl get deployment nginx-ingress-ingress-nginx-controller -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
    if [[ "$READY" -gt 0 ]]; then
        log_info "✅ NGINX Ingress Controller is running with $READY ready replicas"
        
        # Check Ingress Controller version
        INGRESS_VERSION=$(kubectl get deployment nginx-ingress-ingress-nginx-controller -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -o 'v[0-9.]*' || echo "unknown")
        log_info "   Ingress Controller version: $INGRESS_VERSION"
    else
        log_error "❌ NGINX Ingress Controller pods are not ready"
        exit 1
    fi
else
    log_error "❌ NGINX Ingress Controller is not installed in namespace $NAMESPACE"
    exit 1
fi

# Check Backend NGINX Service
SERVICE_NAME="${BACKEND_NAME}-nginx"
log_info "Checking Backend NGINX Service..."
if kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" &>/dev/null; then
    ENDPOINTS=$(kubectl get endpoints "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
    if [[ -n "$ENDPOINTS" ]]; then
        log_info "✅ Backend NGINX Service has endpoints: $ENDPOINTS"
        
        # Check service type
        SERVICE_TYPE=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.type}')
        log_info "   Service type: $SERVICE_TYPE"
        if [[ "$SERVICE_TYPE" != "ClusterIP" ]]; then
            log_warning "⚠️ Service type is $SERVICE_TYPE, but should be ClusterIP for optimal setup"
        fi
    else
        log_error "❌ Backend NGINX Service has no endpoints"
        exit 1
    fi
else
    log_error "❌ Backend NGINX Service is not installed in namespace $NAMESPACE"
    exit 1
fi

# Check Secondary Backend if configured
if [[ "$CHECK_MULTIPLE_BACKENDS" == "true" && -n "$SECONDARY_BACKEND" ]]; then
    log_info "Checking Secondary Backend Service..."
    if kubectl get svc "$SECONDARY_BACKEND" -n "$NAMESPACE" &>/dev/null; then
        SECONDARY_ENDPOINTS=$(kubectl get endpoints "$SECONDARY_BACKEND" -n "$NAMESPACE" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
        if [[ -n "$SECONDARY_ENDPOINTS" ]]; then
            log_info "✅ Secondary Backend Service has endpoints: $SECONDARY_ENDPOINTS"
        else
            log_warning "⚠️ Secondary Backend Service has no endpoints"
        fi
    else
        log_warning "⚠️ Secondary Backend Service is not installed in namespace $NAMESPACE"
    fi
fi

# Check Ingress Resource
log_info "Checking Ingress Resource..."
if kubectl get ingress websocket-ingress -n "$NAMESPACE" &>/dev/null; then
    INGRESS_IP=$(kubectl get ingress websocket-ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [[ -n "$INGRESS_IP" ]]; then
        log_info "✅ Ingress is configured with IP: $INGRESS_IP"
        
        # Verify Ingress rules for main backend
        BACKEND_RULE=$(kubectl get ingress websocket-ingress -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].http.paths[?(@.path=="/")].backend.service.name}')
        if [[ "$BACKEND_RULE" == "$SERVICE_NAME" ]]; then
            log_info "✅ Ingress rule correctly points to $SERVICE_NAME"
        else
            log_warning "⚠️ Ingress rule points to $BACKEND_RULE instead of $SERVICE_NAME"
        fi
        
        # Check port configuration
        PORT=$(kubectl get ingress websocket-ingress -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].http.paths[?(@.path=="/")].backend.service.port.number}')
        if [[ "$PORT" == "80" ]]; then
            log_info "✅ Ingress port is correctly set to 80"
        else
            log_warning "⚠️ Ingress port is set to $PORT instead of 80"
        fi
        
        # Check Ingress annotations
        if kubectl get ingress websocket-ingress -n "$NAMESPACE" -o yaml | grep -q "websocket-services"; then
            log_info "✅ WebSocket annotations are configured"
        else
            log_warning "⚠️ WebSocket annotations are missing"
        fi
        
        # Check secondary backend rule if configured
        if [[ "$CHECK_MULTIPLE_BACKENDS" == "true" && -n "$SECONDARY_BACKEND" ]]; then
            SECONDARY_RULE=$(kubectl get ingress websocket-ingress -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].http.paths[?(@.path=="/api")].backend.service.name}')
            if [[ "$SECONDARY_RULE" == "$SECONDARY_BACKEND" ]]; then
                log_info "✅ Secondary backend route is correctly configured"
            else
                log_warning "⚠️ Secondary backend route is not configured or incorrect"
            fi
        fi
    else
        log_warning "⚠️ Ingress does not have an IP address yet"
    fi
else
    log_error "❌ Ingress resource is not installed in namespace $NAMESPACE"
    exit 1
fi

# Check TLS Secret
log_info "Checking TLS Secret..."
if kubectl get secret "$TLS_SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    log_info "✅ TLS Secret exists"
    
    # Validate TLS certificate
    CERT_CN=$(kubectl get secret "$TLS_SECRET_NAME" -n "$NAMESPACE" -o json | jq -r '.data."tls.crt"' | base64 -d | openssl x509 -noout -subject 2>/dev/null | grep -o "CN=[^,]*" | cut -d= -f2)
    if [[ -n "$CERT_CN" ]]; then
        log_info "   Certificate Common Name: $CERT_CN"
        
        # Check if CN matches domain
        if [[ "$CERT_CN" == "$DOMAIN" || "$CERT_CN" == "*.$DOMAIN" || "$CERT_CN" == "*" ]]; then
            log_info "✅ Certificate CN matches domain"
        else
            log_warning "⚠️ Certificate CN ($CERT_CN) does not match domain ($DOMAIN)"
        fi
        
        # Check certificate expiration
        EXPIRY=$(kubectl get secret "$TLS_SECRET_NAME" -n "$NAMESPACE" -o json | jq -r '.data."tls.crt"' | base64 -d | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
        if [[ -n "$EXPIRY" ]]; then
            EXPIRY_SECONDS=$(date -d "$EXPIRY" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$EXPIRY" +%s 2>/dev/null)
            NOW_SECONDS=$(date +%s)
            DAYS_LEFT=$(( (EXPIRY_SECONDS - NOW_SECONDS) / 86400 ))
            
            if [[ $DAYS_LEFT -gt 30 ]]; then
                log_info "✅ Certificate is valid for $DAYS_LEFT more days"
            elif [[ $DAYS_LEFT -gt 0 ]]; then
                log_warning "⚠️ Certificate expires in $DAYS_LEFT days"
            else
                log_error "❌ Certificate has expired"
            fi
        fi
    else
        log_warning "⚠️ Could not extract certificate information"
    fi
else
    log_error "❌ TLS Secret does not exist in namespace $NAMESPACE"
    exit 1
fi

# Check metrics if enabled
if [[ "$CHECK_METRICS" == "true" ]]; then
    log_info "Checking metrics endpoints..."
    if kubectl get svc nginx-ingress-ingress-nginx-controller-metrics -n "$NAMESPACE" &>/dev/null; then
        log_info "✅ Metrics service exists"
        
        # Port-forward to metrics service
        log_info "Testing metrics endpoint..."
        METRICS_PID=""
        kubectl port-forward svc/nginx-ingress-ingress-nginx-controller-metrics -n "$NAMESPACE" 9913:9913 &>/dev/null &
        METRICS_PID=$!
        sleep 2
        
        # Check if metrics endpoint is accessible
        if curl -s http://localhost:9913/metrics | grep -q "nginx_ingress_controller"; then
            log_info "✅ Metrics endpoint is accessible and returning data"
        else
            log_warning "⚠️ Metrics endpoint is not returning expected data"
        fi
        
        # Clean up port-forwarding
        if [[ -n "$METRICS_PID" ]]; then
            kill $METRICS_PID &>/dev/null
        fi
    else
        log_warning "⚠️ Metrics service not found. Is metrics collection enabled?"
    fi
fi

# Test HTTP to HTTPS Redirect
log_info "Testing HTTP to HTTPS Redirect..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m "$TEST_TIMEOUT" "http://$DOMAIN")
if [[ "$HTTP_CODE" == "308" ]]; then
    log_info "✅ HTTP to HTTPS redirect is working (Status: $HTTP_CODE)"
else
    log_warning "⚠️ HTTP to HTTPS redirect returned unexpected status: $HTTP_CODE"
fi

# Test HTTPS Connection
log_info "Testing HTTPS Connection..."
HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k -m "$TEST_TIMEOUT" "https://$DOMAIN")
if [[ "$HTTPS_CODE" == "200" ]]; then
    log_info "✅ HTTPS connection is working (Status: $HTTPS_CODE)"
    
    # Check HTTPS response time
    RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" -k -m "$TEST_TIMEOUT" "https://$DOMAIN")
    log_info "   HTTPS response time: ${RESPONSE_TIME}s"
else
    log_error "❌ HTTPS connection failed with status: $HTTPS_CODE"
    exit 1
fi

# Test WebSocket Connection (Basic Check)
log_info "Testing WebSocket Handshake (Basic Check)..."
WS_HEADERS=$(curl -s -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" -H "Sec-WebSocket-Version: 13" -k -m "$TEST_TIMEOUT" "https://$DOMAIN")
if echo "$WS_HEADERS" | grep -q "101 Switching Protocols"; then
    log_info "✅ WebSocket handshake successful"
else
    log_warning "⚠️ WebSocket handshake unsuccessful (this may be normal if your application doesn't support WebSockets yet)"
fi

# Test Secondary Backend if configured
if [[ "$CHECK_MULTIPLE_BACKENDS" == "true" && -n "$SECONDARY_BACKEND" ]]; then
    log_info "Testing Secondary Backend..."
    SECONDARY_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k -m "$TEST_TIMEOUT" "https://$DOMAIN/api")
    log_info "   Secondary backend response code: $SECONDARY_CODE"
    if [[ "$SECONDARY_CODE" == "200" || "$SECONDARY_CODE" == "404" ]]; then
        log_info "✅ Secondary backend is accessible"
    else
        log_warning "⚠️ Secondary backend returned unexpected status: $SECONDARY_CODE"
    fi
fi

# Run extended tests if requested
if [[ "$EXTENDED_TESTS" == "true" ]]; then
    log_info "Running extended tests..."
    
    # Check if ab (Apache Benchmark) is available
    if command -v ab &>/dev/null; then
        log_info "Running load test with $REQUEST_COUNT requests, $CONCURRENT_USERS concurrent users..."
        AB_RESULT=$(ab -n "$REQUEST_COUNT" -c "$CONCURRENT_USERS" -k -s "$TEST_TIMEOUT" "https://$DOMAIN/" 2>&1)
        
        # Extract key metrics
        REQUESTS_PER_SECOND=$(echo "$AB_RESULT" | grep "Requests per second" | awk '{print $4}')
        TIME_PER_REQUEST=$(echo "$AB_RESULT" | grep "Time per request" | head -1 | awk '{print $4}')
        
        if [[ -n "$REQUESTS_PER_SECOND" && -n "$TIME_PER_REQUEST" ]]; then
            log_info "✅ Load test results:"
            log_info "   Requests per second: $REQUESTS_PER_SECOND"
            log_info "   Time per request: $TIME_PER_REQUEST ms"
        else
            log_warning "⚠️ Could not parse load test results"
        fi
    else
        log_warning "⚠️ ab (Apache Benchmark) not found. Skipping load tests."
    fi
    
    # Check NGINX configuration
    log_info "Checking NGINX configuration..."
    if kubectl exec -it "$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=nginx-ingress -o jsonpath='{.items[0].metadata.name}')" -n "$NAMESPACE" -- nginx -t &>/dev/null; then
        log_info "✅ NGINX configuration syntax is valid"
    else
        log_warning "⚠️ Could not verify NGINX configuration"
    fi
fi

# Summarize test results
log_info "✅ Reverse Proxy Test Completed!"
log_info "Your application should be accessible at https://$DOMAIN"

# Check for connectivity from current location
FINAL_TEST=$(curl -s -o /dev/null -w "%{http_code}" -k -m "$TEST_TIMEOUT" "https://$DOMAIN")
if [[ "$FINAL_TEST" == "200" ]]; then
    log_info "✅ Connectivity from this location to https://$DOMAIN is confirmed"
else
    log_warning "⚠️ Final connectivity test returned status: $FINAL_TEST"
    log_info "   If you're testing from a different network, ensure DNS is properly configured"
    log_info "   You may need to add an entry in your hosts file pointing $DOMAIN to $INGRESS_IP"
fi