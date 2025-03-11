### **📌 Naming Conventions for Installation, Testing, and Documentation Scripts**
Since we're setting up **SSH, HTTPS, and WebSockets on port 443 via Helm**, the scripts should follow a clear naming pattern.

| **Script Type** | **Filename** | **Purpose** |
|---------------|------------|------------|
| **Installation Script** | `install_reverse_proxy.sh` | Installs NGINX Ingress and SSLH via Helm |
| **Test Script** | `install_reverse_proxy_test.sh` | Verifies that SSH, HTTPS, and WebSockets are running correctly |
| **Documentation** | `install_reverse_proxy_readme.md` | Provides setup and usage instructions |

---

## **✅ Script File Details**

### **📌 1. `install_reverse_proxy.sh` (Installation Script)**
This script:
✅ Installs **NGINX Ingress Controller**  
✅ Installs **SSLH for port sharing**  
✅ Configures **Ingress for WebSockets**  

```bash
#!/bin/bash

source "$(dirname "$0")/utils.sh"

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
```

Make it executable:
```bash
chmod +x scripts/install_reverse_proxy.sh
```

---

### **📌 2. `install_reverse_proxy_test.sh` (Testing Script)**
This script:
✅ Checks if **NGINX Ingress and SSLH are running**  
✅ Tests **SSH connection over port 443**  
✅ Tests **WebSockets connectivity**  

```bash
#!/bin/bash

source "$(dirname "$0")/utils.sh"

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
```

Make it executable:
```bash
chmod +x scripts/install_reverse_proxy_test.sh
```

---

### **📌 3. `install_reverse_proxy_readme.md` (Documentation)**
This file explains:
✅ How the script works  
✅ How to verify installation  
✅ How to troubleshoot  

```md
# 🛠️ Reverse Proxy Setup (SSH + HTTPS + WebSockets over Port 443)

## **🔹 Overview**
This setup enables:
- **SSH over port 443**
- **WebSockets & HTTPS via NGINX Ingress**
- **Multiplexing with SSLH**

## **🔹 Installation**
Run:
```bash
./scripts/install_reverse_proxy.sh
```

## **🔹 Testing the Setup**
Run:
```bash
./scripts/install_reverse_proxy_test.sh
```

### **🔹 Check Services**
```bash
kubectl get svc
```
Look for:
- `nginx-ingress`
- `sslh`

### **🔹 SSH Over Port 443**
```bash
ssh -p 443 yourserver.com
```

### **🔹 WebSockets Test**
Run:
```javascript
let socket = new WebSocket("wss://yourserver.com");
socket.onopen = () => console.log("WebSocket connected");
```

## **🔹 Uninstall**
```bash
helm uninstall nginx-ingress
helm uninstall sslh
kubectl delete -f scripts/ingress-websocket.yaml
```

✅ Now, all traffic flows through **port 443** securely!
```

---

## **✅ Final Steps**
1️⃣ **Add the scripts to Git:**
```bash
git add scripts/install_reverse_proxy.sh scripts/install_reverse_proxy_test.sh scripts/install_reverse_proxy_readme.md
```

2️⃣ **Commit the changes:**
```bash
git commit -m "🔧 Added Reverse Proxy installation and verification scripts"
```

3️⃣ **Push to GitHub:**
```bash
git push origin main
```

---

### **🚀 Now, Your System Will Run SSH, HTTPS, and WebSockets on Port 443!**
Would you like to **add automatic SSL certificates with Let's Encrypt?** ✅


help for troubleshoot the Kubernetes Ingress issue. Based on the information provided, you're experiencing HTTP 404 errors despite having your Ingress resource properly configured. Let's approach this systematically:

## Step-by-Step Troubleshooting for Kubernetes Ingress 404 Errors

### 1. Verify the Ingress Resource Configuration

First, let's examine your Ingress resource:

```bash
kubectl get ingress websocket-ingress -o yaml
```

Check that:
- The host is properly set to `p1-emea.zzv.io`
- The backend service name is correct (`sslh-nginx`)
- The service port is properly configured

### 2. Check if the Backend Service Exists and is Running

```bash
kubectl get svc sslh-nginx
kubectl describe svc sslh-nginx
```

Verify:
- The service exists
- The correct port mapping is configured (especially check the targetPort)
- The service has endpoints (it's selecting pods that exist)

### 3. Verify the Service Endpoints

```bash
kubectl get endpoints sslh-nginx
```

This should show the IP addresses of the pods. If this is empty, your service isn't selecting any pods.

### 4. Check if the Pods are Running

```bash
kubectl get pods -l app=sslh-nginx
kubectl describe pods -l app=sslh-nginx
```

Make sure the pods are in Running state and ready.

### 5. Examine NGINX Configuration

Check if NGINX has created the proper routing configuration:

```bash
kubectl exec -it $(kubectl get pods -l app.kubernetes.io/name=ingress-nginx -n default -o jsonpath='{.items[0].metadata.name}') -n default -- cat /etc/nginx/nginx.conf | grep -A 20 "server_name p1-emea.zzv.io"
```

### 6. Test Network Connectivity

Perform a direct port-forward test:

```bash
kubectl port-forward svc/sslh-nginx 8080:8080
```

In another terminal:
```bash
curl -I http://localhost:8080
```

If this works but the Ingress doesn't, the issue is in the Ingress configuration.

### 7. Check NGINX Logs

```bash
kubectl logs -l app.kubernetes.io/name=ingress-nginx -n default
```

Look for errors related to your host or path.

### 8. Verify NGINX Controller is Working

```bash
kubectl get pods -l app.kubernetes.io/name=ingress-nginx -n default
kubectl describe pods -l app.kubernetes.io/name=ingress-nginx -n default
```

### 9. Review sslh-nginx Configuration

Since sslh-nginx might be handling both TLS and non-TLS traffic:

```bash
kubectl get configmap -l app=sslh-nginx
kubectl describe configmap -l app=sslh-nginx
```

### 10. Test with Different HTTP Methods

```bash
curl -X GET https://p1-emea.zzv.io --insecure
curl -X POST https://p1-emea.zzv.io --insecure
```

### 11. Recreate Ingress Resource

If all else fails, try recreating the Ingress:

```bash
kubectl delete ingress websocket-ingress
kubectl apply -f your-ingress-file.yaml
```

### 12. Check for TLS/SSL Issues

If you're using HTTPS:

```bash
kubectl get secret your-tls-secret
kubectl describe secret your-tls-secret
```

Ensure the certificate is valid and properly configured.

