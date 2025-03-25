# 📦 Helm Installation Guide

## **🔹 About Helm**
Helm is a package manager for Kubernetes that simplifies deploying applications. It uses charts - packaged collections of resources that define a Kubernetes application.

## **🔹 How to Install Helm**
Run the following command:
```bash
./scripts/install_helm.sh
```

This will:
- Check for prerequisites (curl)
- Install Helm if not present
- Add common repositories (Bitnami, Stable, Jetstack)
- Verify installation

## **🔹 How to Verify Helm**
Run:
```bash
./scripts/install_helm_test.sh
```
This will:
- Check if Helm is installed
- Verify Helm version meets minimum requirements
- Validate Helm repositories are configured correctly
- Test basic Helm functionality
- Check configuration permissions

## **🔹 Example: Installing NGINX with Helm**
```bash
helm install my-nginx bitnami/nginx
```

To check the status of your installation:
```bash
helm status my-nginx
```

## **🔹 Managing Helm Charts**

### Updating Repositories
```bash
helm repo update
```

### Listing Installed Charts
```bash
helm list
```

### Upgrading a Chart
```bash
helm upgrade my-nginx bitnami/nginx --set replicaCount=2
```

### Uninstalling a Chart
```bash
helm uninstall my-nginx
```

## **🔹 Creating Your Own Helm Chart**
To create a basic chart structure:
```bash
helm create my-application
```

This generates a chart template with:
- Chart.yaml - Metadata about your chart
- values.yaml - Default configuration values
- templates/ - Directory containing template files
- charts/ - Directory for dependent charts

## **🔹 Troubleshooting**

### Common Issues

1. **Repository not found**
```bash
# Re-add the repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

2. **Permission denied errors**
```bash
# Fix Helm configuration permissions
sudo chown -R $(id -u):$(id -g) ~/.config/helm
sudo chown -R $(id -u):$(id -g) ~/.cache/helm
```

3. **Tiller errors (Helm 2 only)**
If you see references to Tiller, you're using an outdated version of Helm. Our scripts install Helm 3, which doesn't use Tiller.

4. **Chart installation timeouts**
```bash
# Increase timeout (default is 5m0s)
helm install my-nginx bitnami/nginx --timeout 10m0s
```

## **🔹 Best Practices**

1. **Version your charts** - Always specify version in Chart.yaml
2. **Use values.yaml** - Keep default configuration in values.yaml
3. **Document your charts** - Add detailed README.md to your charts
4. **Validate before deploy** - Use `helm lint` and `helm template`
5. **Use namespaces** - Install charts in appropriate namespaces

## **🔹 Uninstalling Helm**
If you need to remove Helm:
```bash
# Remove Helm binary
sudo rm -rf /usr/local/bin/helm

# Remove Helm configuration
rm -rf ~/.config/helm
rm -rf ~/.cache/helm
```

## **🔹 Additional Resources**
- [Official Helm Documentation](https://helm.sh/docs/)
- [Artifact Hub (find charts)](https://artifacthub.io/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)

---

This installation guide is part of our K3s cluster setup. Also see:
- `install_kubernetes.sh` - Installs K3s
- `install_reverse_proxy.sh` - Sets up ingress and TLS