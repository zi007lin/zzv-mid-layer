# 🛠️ Reverse Proxy Setup for Kubernetes

This guide explains how to install, configure, and test a reverse proxy setup in Kubernetes using NGINX Ingress Controller.

## 📋 Overview

This setup enables:
- HTTPS connections with TLS termination
- WebSocket support for real-time applications
- Customizable backend service routing
- Production-ready configuration options

## 🚀 Installation

### Basic Installation

For a standard installation with default settings:

```bash
./scripts/install_reverse_proxy.sh
```

### Advanced Installation Options

The installation script supports several customization options:

```bash
# Install with a custom domain
./scripts/install_reverse_proxy.sh --domain=example.com

# Install in a specific namespace
./scripts/install_reverse_proxy.sh --namespace=my-namespace

# Configure for production environment (more replicas, resource limits)
./scripts/install_reverse_proxy.sh --environment=prod

# Use a custom backend service name
./scripts/install_reverse_proxy.sh --backend-name=my-backend

# Enable Prometheus metrics
./scripts/install_reverse_proxy.sh --enable-metrics

# Use your own TLS certificate
./scripts/install_reverse_proxy.sh --custom-tls-cert=/path/to/cert.pem --custom-tls-key=/path/to/key.pem

# Set up multiple backend services
./scripts/install_reverse_proxy.sh --multiple-backends --secondary-backend=api-service

# Clean up on installation failure
./scripts/install_reverse_proxy.sh --cleanup-on-failure
```

For a full list of options:

```bash
./scripts/install_reverse_proxy.sh --help
```

## 🔍 Testing the Setup

### Basic Testing

Verify your installation with the test script:

```bash
./scripts/install_reverse_proxy_test.sh
```

### Advanced Testing Options

The test script supports the same customization options as the installation script:

```bash
# Test a custom domain
./scripts/install_reverse_proxy_test.sh --domain=example.com

# Test in a specific namespace
./scripts/install_reverse_proxy_test.sh --namespace=my-namespace

# Test metrics endpoints
./scripts/install_reverse_proxy_test.sh --check-metrics

# Test multiple backend configuration
./scripts/install_reverse_proxy_test.sh --check-multiple-backends --secondary-backend=api-service

# Run extended performance tests
./scripts/install_reverse_proxy_test.sh --extended-tests --request-count=100 --concurrent-users=10
```

For a full list of testing options:

```bash
./scripts/install_reverse_proxy_test.sh --help
```

## 🔧 Configuration Details

### Ingress Controller

The NGINX Ingress Controller is configured with:
- LoadBalancer service type for external access
- Local external traffic policy for preserving client IP addresses
- Optional metrics for monitoring
- Configurable replica count for high availability

### Backend Service

The backend NGINX service is configured with:
- ClusterIP service type (accessed through the Ingress)
- Standard HTTP (80) and HTTPS (443) ports
- Configurable replica count

### TLS Configuration

By default, the setup creates a self-signed TLS certificate. For production use, you can:
- Provide your own certificate with `--custom-tls-cert` and `--custom-tls-key`
- Set up cert-manager for automatic Let's Encrypt certificates (see Advanced Topics)

### WebSocket Support

The Ingress is configured with specific annotations for WebSocket support:
- Extended timeouts for long-lived connections
- Buffer size adjustments
- WebSocket service identification

## 📊 Monitoring Your Setup

### Check Services

```bash
kubectl get svc
```

Look for:
- `nginx-ingress-ingress-nginx-controller` (LoadBalancer type)
- `[backend-name]-nginx` (ClusterIP type)

### Check Ingress

```bash
kubectl get ingress
kubectl describe ingress websocket-ingress
```

### Check Pods

```bash
kubectl get pods
```

### WebSocket Test

To test WebSocket connectivity:

```javascript
let socket = new WebSocket("wss://your-domain.com");
socket.onopen = () => console.log("WebSocket connected");
socket.onmessage = (event) => console.log("Received data:", event.data);
socket.onerror = (error) => console.error("WebSocket error:", error);
```

## 🔥 Troubleshooting

### Common Issues

#### 1. Ingress Has No IP Address

**Symptoms:** The `kubectl get ingress` command shows no IP address.

**Solution:**
```bash
# Check the ingress-controller service
kubectl get svc nginx-ingress-ingress-nginx-controller

# If using MetalLB, check its configuration
kubectl get configmap -n metallb-system
```

#### 2. 404 Not Found Errors

**Symptoms:** Browser shows 404 when accessing the domain.

**Solution:**
```bash
# Verify service endpoints
kubectl get endpoints [backend-name]-nginx

# Check if service selector matches pod labels
kubectl get pods --show-labels
kubectl describe svc [backend-name]-nginx

# Fix service selector
kubectl patch svc [backend-name]-nginx -p '{"spec":{"selector":{"app.kubernetes.io/instance":"[backend-name]", "app.kubernetes.io/name":"nginx"}}}'
```

#### 3. TLS Certificate Issues

**Symptoms:** Browser shows certificate warnings.

**Solution:**
```bash
# Check the TLS secret
kubectl describe secret [backend-name]-nginx-tls

# Recreate the TLS secret
kubectl delete secret [backend-name]-nginx-tls
./scripts/install_reverse_proxy.sh --domain=your-domain.com
```

#### 4. WebSocket Connection Failures

**Symptoms:** WebSocket connections fail to establish.

**Solution:**
```bash
# Verify ingress annotations
kubectl get ingress websocket-ingress -o yaml | grep timeout

# Check NGINX logs
kubectl logs -l app.kubernetes.io/name=ingress-nginx-controller

# Adjust timeouts if needed
kubectl patch ingress websocket-ingress -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/proxy-read-timeout":"3600"}}}'
```

#### 5. Backend Service Not Found

**Symptoms:** Browser shows 503 Service Unavailable.

**Solution:**
```bash
# Check if backend pods are running
kubectl get pods -l app.kubernetes.io/instance=[backend-name]

# Get events for the pod
kubectl describe pod [pod-name]

# Restart the backend deployment
kubectl rollout restart deployment [backend-name]-nginx
```

## 🧹 Uninstallation

To completely remove the reverse proxy setup:

```bash
# Basic uninstallation
kubectl delete ingress websocket-ingress
kubectl delete secret [backend-name]-nginx-tls
helm uninstall [backend-name]
helm uninstall nginx-ingress

# Or use the domain option if you customized it
./scripts/install_reverse_proxy.sh --domain=your-domain.com --cleanup-on-failure
```

## 🚀 Advanced Topics

### Setting Up Let's Encrypt for Automatic SSL

1. Install cert-manager:
   ```bash
   helm repo add jetstack https://charts.jetstack.io
   helm install cert-manager jetstack/cert-manager --set installCRDs=true
   ```

2. Create an Issuer:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: your-email@example.com
       privateKeySecretRef:
         name: letsencrypt-prod
       solvers:
       - http01:
           ingress:
             class: nginx
   ```

3. Update your Ingress annotations:
   ```bash
   kubectl patch ingress websocket-ingress -p '{"metadata":{"annotations":{"cert-manager.io/cluster-issuer":"letsencrypt-prod"}}}'
   ```

### Multiple Backends Example

To set up routing to different backend services:

```bash
./scripts/install_reverse_proxy.sh --multiple-backends --secondary-backend=api-service
```

This will create an Ingress with the following routes:
- `/` → Main backend service
- `/api` → Secondary backend service

### High Availability Setup

For production environments with high availability:

```bash
./scripts/install_reverse_proxy.sh --environment=prod --enable-metrics
```

This configures:
- Multiple replicas for the Ingress Controller
- Resource requests and limits
- Prometheus metrics for monitoring

---

## 📊 Reference

| Component | Default Name | Purpose |
|-----------|--------------|---------|
| Ingress Controller | nginx-ingress | Manages external access to services |
| Backend Service | sslh-nginx | Serves your application content |
| Ingress Resource | websocket-ingress | Routes traffic to backend services |
| TLS Secret | [backend-name]-nginx-tls | Stores TLS certificate |

Happy reverse proxying! 🚀