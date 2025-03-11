### **🚀 Setting Up Helm in Your K3s Cluster**  
I'll provide:
1. **`install_helm.sh`** – Installs Helm on your system  
2. **`install_helm_test.sh`** – Verifies Helm installation  
3. **`install_helm_readme.md`** – Explains usage  

---

## **✅ Step 1: Create `install_helm.sh`**
This script will:
- Install Helm  
- Add the official Helm repository  
- Verify installation  

Save this in `scripts/install_helm.sh`:
```bash
#!/bin/bash

# Include logging functions (if you have utils.sh)
source "$(dirname "$0")/utils.sh"

log_info "Installing Helm..."

# Check if Helm is already installed
if command -v helm &> /dev/null; then
    log_info "✅ Helm is already installed."
else
    log_info "🔄 Downloading and installing Helm..."
    
    # Install Helm for Linux
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    check_status "Helm installation failed"

    log_info "✅ Helm installed successfully!"
fi

# Verify Helm version
helm version

# Add Bitnami Helm repo (optional, commonly used)
log_info "Adding Helm repository..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
check_status "Helm repo addition failed"

log_info "✅ Helm installation complete!"
```

Make it executable:
```bash
chmod +x scripts/install_helm.sh
```

---

## **✅ Step 2: Create `install_helm_test.sh`**
This script verifies that:
- Helm is installed  
- Helm repositories are available  

Save this in `scripts/install_helm_test.sh`:
```bash
#!/bin/bash

source "$(dirname "$0")/utils.sh"

log_info "Testing Helm installation..."

# Check if Helm is installed
if command -v helm &> /dev/null; then
    log_info "✅ Helm is installed."
else
    log_error "❌ Helm is NOT installed."
    exit 1
fi

# Check if Helm repositories exist
helm repo list | grep "bitnami" &> /dev/null
if [ $? -eq 0 ]; then
    log_info "✅ Helm repository is configured correctly."
else
    log_warning "⚠️ Helm repository not found. Try running install_helm.sh again."
fi

log_info "✅ Helm test completed successfully!"
```

Make it executable:
```bash
chmod +x scripts/install_helm_test.sh
```

---

## **✅ Step 3: Create `install_helm_readme.md`**
Save this in `scripts/install_helm_readme.md`:
```md
# 📦 Helm Installation Guide

## **🔹 About Helm**
Helm is a package manager for Kubernetes that simplifies deploying applications.

## **🔹 How to Install Helm**
Run the following command:
```bash
./scripts/install_helm.sh
```

This will:
- Install Helm
- Add the Bitnami repository
- Verify installation

## **🔹 How to Verify Helm**
Run:
```bash
./scripts/install_helm_test.sh
```
This will:
- Check if Helm is installed
- Validate Helm repositories

## **🔹 Example: Installing NGINX with Helm**
```bash
helm install my-nginx bitnami/nginx
```

## **🔹 Updating Helm Charts**
To update the repositories:
```bash
helm repo update
```

## **🔹 Uninstalling Helm**
If you need to remove Helm:
```bash
rm -rf /usr/local/bin/helm
```
```

---

## **✅ Step 4: Commit and Push to GitHub**
After creating these files, track them in Git:
```bash
git add scripts/install_helm.sh scripts/install_helm_test.sh scripts/install_helm_readme.md
git commit -m "Added Helm installation and test scripts"
git push origin main
```

---

## **🚀 Final Summary**
| File | Description |
|------|-------------|
| `install_helm.sh` | Installs Helm and sets up repositories |
| `install_helm_test.sh` | Verifies Helm installation |
| `install_helm_readme.md` | Provides usage instructions |

Now, **Helm is fully integrated into your Kubernetes setup!** 🚀 Would you like to automate any Helm chart deployments next?