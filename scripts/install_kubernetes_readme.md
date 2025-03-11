
```markdown
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

### 3. Verify the Installation

After installation completes, you can verify that K3s is running correctly:

```bash
kubectl get nodes
```

You should see your node listed with STATUS "Ready".

For a more thorough verification, you can run the test script:

```bash
chmod +x scripts/install_kubernetes_test.sh
./scripts/install_kubernetes_test.sh
```

## Understanding the Verification Results

When the installation is successful, you'll see:
- ✅ K3s service is running
- ✅ Node is Ready
- ✅ kubectl can access the cluster
- ✅ Test pod is running
- 🎉 K3s installation verified successfully!

## Troubleshooting

If you encounter issues:

1. **Check system requirements**
   - Ensure your system meets the minimum requirements for running K3s

2. **Network connectivity issues**
   - Verify that your system can access the internet
   - Check if any firewalls might be blocking necessary connections

3. **Permission problems**
   - Try running the scripts with sudo: `sudo ./scripts/install_kubernetes.sh`

4. **Installation timeout**
   - The node might take longer to become ready on slower systems
   - Try increasing the timeout values in the test script

5. **View logs for more details**
   - Check K3s logs: `sudo journalctl -u k3s`

## Using K3s with ZZV Mid-Layer

Once K3s is successfully installed, you can deploy the ZZV Mid-Layer application:

```bash
kubectl apply -f deploy/zzv-mid-layer.yaml
```

Monitor the deployment:

```bash
kubectl get pods
kubectl get services
```

## Additional Resources

- [K3s Documentation](https://docs.k3s.io/)
- [ZZV Mid-Layer Documentation](https://github.com/zi007lin/zzv-mid-layer/docs)
- [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)

Congratulations! You now have K3s running on your Ubuntu system, ready to host the ZZV Mid-Layer application.
```
