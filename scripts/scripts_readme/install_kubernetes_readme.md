# Installing K3s for ZZV Mid-Layer

This guide will help you install K3s, a lightweight version of Kubernetes, on your Ubuntu 22.04 system to run the ZZV Mid-Layer application.

## What is K3s?

K3s is a lightweight, certified Kubernetes distribution designed for edge computing, IoT, and environments with limited resources. It's perfect for running applications like ZZV Mid-Layer efficiently.

## Prerequisites

You will need:
- Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-25-generic x86_64)
- Internet connection
- Administrator (sudo) access
- At least 2GB of RAM and 20GB of disk space

## Installation Steps

### 1. Clone the Repository

First, open a Terminal by pressing `Ctrl+Alt+T` and clone the ZZV Mid-Layer repository:

```bash
git clone https://github.com/zi007lin/zzv-mid-layer.git
cd zzv-mid-layer
```

### 2. Run the Installation Script

The repository includes scripts to install K3s. Make them executable and run the installation:

```bash
chmod +x scripts/install_kubernetes.sh
./scripts/install_kubernetes.sh
```

This script will:
- Update your system packages
- Install necessary dependencies
- Set up K3s
- Configure kubectl for ease of use
- Verify the installation

The installation typically takes 5-10 minutes depending on your system and internet speed.

### 3. Installation Options

The installation script supports several options to customize your setup:

```bash
# Install a specific K3s version
./scripts/install_kubernetes.sh --version=v1.25.0+k3s1

# Install in agent (worker) mode
./scripts/install_kubernetes.sh --mode=agent --server-url=https://master-ip:6443 --token=YOUR_TOKEN

# Disable Traefik ingress controller
./scripts/install_kubernetes.sh --disable-traefik

# Skip backing up existing configuration
./scripts/install_kubernetes.sh --no-backup
```

### 4. Setting Up a Multi-Node Cluster

#### Master Node Setup
First, install K3s on your master node:
```bash
./scripts/install_kubernetes.sh
```

After installation, get the node token:
```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

#### Worker Node Setup
On each worker node, run:
```bash
./scripts/install_kubernetes.sh --mode=agent --server-url=https://MASTER_IP:6443 --token=NODE_TOKEN
```

Replace `MASTER_IP` with your master node's IP address and `NODE_TOKEN` with the token from the previous step.

### 5. Verify the Installation

After installation completes, you can verify that K3s is running correctly:

```bash
kubectl get nodes
```

You should see your node listed with STATUS "Ready".

For a more thorough verification, you can run the test script:

```bash
chmod +x scripts/install_kubernetes_test.sh
sudo ./scripts/install_kubernetes_test.sh
```

The test script also supports customization options:

```bash
# Skip the test pod deployment for a quicker test
sudo ./scripts/install_kubernetes_test.sh --skip-test-pod

# Specify a custom test image
sudo ./scripts/install_kubernetes_test.sh --test-image=nginx:alpine

# Disable specific checks
sudo ./scripts/install_kubernetes_test.sh --no-storage-check --no-network-check
```

## Understanding the Verification Results

When the installation is successful, the verification script checks:

- ✅ K3s service is running
- ✅ Node is Ready
- ✅ kubectl can access the cluster
- ✅ CoreDNS and kube-proxy are running
- ✅ DNS resolution is working
- ✅ Network connectivity between pods
- ✅ Storage provisioning (if applicable)
- ✅ Test pod deployment and execution

## Troubleshooting

If you encounter issues:

1. **Check system requirements**
   - Ensure your system meets the minimum requirements for running K3s
   - Run `free -m` to check available memory
   - Run `df -h` to check available disk space

2. **Network connectivity issues**
   - Verify that your system can access the internet: `ping -c 3 google.com`
   - Check if any firewalls might be blocking necessary connections
   - For multi-node clusters, ensure nodes can communicate with each other

3. **Permission problems**
   - Try running the scripts with sudo: `sudo ./scripts/install_kubernetes.sh`
   - Check if ~/.kube directory permissions are correct: `ls -la ~/.kube`

4. **Installation timeout**
   - The node might take longer to become ready on slower systems
   - Try increasing the timeout values: `TIMEOUT=300 sudo ./scripts/install_kubernetes_test.sh`

5. **Pod scheduling issues**
   - Check for taints on nodes: `kubectl describe node | grep Taints`
   - Check pod events: `kubectl describe pod <pod-name>`

6. **View logs for more details**
   - Check K3s logs: `sudo journalctl -u k3s`
   - For agent nodes: `sudo journalctl -u k3s-agent`

## Uninstalling K3s

If you need to uninstall K3s, use the appropriate script:

```bash
# On server nodes
/usr/local/bin/k3s-uninstall.sh

# On agent nodes
/usr/local/bin/k3s-agent-uninstall.sh
```

This will remove K3s but preserve any data in /var/lib/rancher/k3s.

## Using K3s with ZZV Mid-Layer

Once K3s is successfully installed, you can deploy the ZZV Mid-Layer application:

```bash
kubectl apply -f deploy/zzv-mid-layer.yaml
```

Monitor the deployment:

```bash
# Check pods status
kubectl get pods -w

# Check services
kubectl get services

# View logs
kubectl logs -f deployment/zzv-mid-layer

# Access the dashboard (if enabled)
kubectl port-forward svc/zzv-mid-layer-dashboard 8080:80
```

Then open your browser to http://localhost:8080 to access the dashboard.

## Additional Resources

- [K3s Documentation](https://docs.k3s.io/)
- [ZZV Mid-Layer Documentation](https://github.com/zi007lin/zzv-mid-layer/docs)
- [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [Troubleshooting K3s](https://rancher.com/docs/k3s/latest/en/troubleshooting/)
- [Helm Charts for K3s](https://github.com/k3s-io/helm-controller)

Congratulations! You now have K3s running on your Ubuntu system, ready to host the ZZV Mid-Layer application.