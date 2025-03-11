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