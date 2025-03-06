# Setup Script README

## Overview

This script automates the deployment of a distributed system with SSH and HTTPS traffic sharing port 443. The setup includes Kubernetes, Kafka in KRaft mode, Spring Boot, Phoenix LiveView, and monitoring tools.

## Prerequisites

- Ubuntu 22.04.5 LTS or compatible
- Root or sudo access
- Ports 80 and 443 open on your firewall
- Valid domain name pointing to your server

## Quick Start

1. **Set environment variables (optional)**:
   ```bash
   export NAM_IP="your_nam_ip"
   export EMEA_IP="your_emea_ip"
   export APAC_IP="your_apac_ip"
   export DOMAIN="yourdomain.com"
   ```

2. **Make the script executable**:
   ```bash
   chmod +x setup_script.sh
   ```

3. **Run the script**:
   ```bash
   ./setup_script.sh
   ```

4. **Follow the prompts** if you didn't set environment variables.

## What It Does

The script performs the following actions:

1. **Core Dependencies**: Installs Docker, Docker Compose, NGINX, and SSLH
2. **Port 443 Sharing**: Configures SSLH to share port 443 between SSH and HTTPS
3. **Web Server**: Sets up NGINX as a reverse proxy for multiple applications
4. **SSL**: Creates self-signed certificates initially, with Let's Encrypt integration
5. **Orchestration**: Installs Kubernetes for container orchestration
6. **Messaging**: Deploys Kafka in KRaft mode for distributed messaging
7. **Applications**:
   - Configures Java Spring Boot with GraalVM
   - Sets up Elixir Phoenix LiveView with WebSocket support
   - Deploys MongoDB for data storage
8. **Monitoring**: Installs Prometheus and Grafana
9. **Security**: Configures UFW firewall

## Port 443 Sharing Architecture

The script implements a solution for sharing port 443 between SSH and HTTPS:

```
Client Request (Port 443)
       │
       ▼
      SSLH
       │
       ├─────► SSH (Port 22)
       │
       ▼
    NGINX (Port 4443)
       │
       ├─────► Spring Boot API (Port 8080)
       │
       ├─────► Phoenix LiveView (Port 4000)
       │
       ├─────► WebSockets (/ws)
       │
       └─────► Other Services
```

## Components

### SSLH Configuration

SSLH listens on port 443 and routes traffic:
- SSH traffic → local SSH daemon (port 22)
- HTTPS traffic → NGINX (port 4443)

### NGINX Configuration

NGINX listens on port 4443 for SSL traffic and routes to:
- `/` → Phoenix LiveView (port 4000)
- `/api` → Spring Boot (port 8080)
- `/ws` → WebSocket endpoint
- `/mongo` → MongoDB (port 27017)
- `/kafka` → Kafka management UI (port 9092)
- `/grafana` → Grafana (port 3000)
- `/prometheus` → Prometheus (port 9090)

### Kubernetes

The script sets up a Kubernetes cluster with:
- NAM node as the control plane
- EMEA and APAC nodes as worker nodes
- Calico network plugin

### Kafka

A Kafka cluster in KRaft mode is set up with:
- NAM, EMEA, and APAC nodes forming a quorum
- Advertised listeners configured for cross-node communication

## Troubleshooting

### SSLH Issues

If SSLH fails to start:
```bash
systemctl status sslh
journalctl -u sslh
```

Check if port 443 is already in use:
```bash
netstat -tulnp | grep :443
```

### NGINX Issues

If NGINX fails to start:
```bash
systemctl status nginx
journalctl -u nginx
nginx -t
```

### Let's Encrypt Issues

If Let's Encrypt certification fails:
1. Ensure your domain resolves to your server's IP
2. Check that ports 80 and 443 are open
3. Manually run: `sudo certbot --nginx -d yourdomain.com`

### Kubernetes Issues

If Kubernetes fails to initialize:
```bash
journalctl -u kubelet
kubectl get nodes
```

For node join issues:
```bash
kubeadm token create --print-join-command
```

## Post-Installation

After running the script:

1. **SSH Access**: Connect via `ssh -p 443 user@yourdomain.com`
2. **Web Access**: Visit `https://yourdomain.com`
3. **Deploy Applications**:
   - Build and deploy Spring Boot: `kubectl apply -f ~/spring-app/spring-app.yaml`
   - Build and deploy Phoenix LiveView: `kubectl apply -f ~/phoenix-app/elixir-liveview.yaml`
4. **Check Monitoring**:
   - Grafana: `https://yourdomain.com/grafana` (default: admin/admin)
   - Prometheus: `https://yourdomain.com/prometheus`

## Security Considerations

- Only ports 80 and 443 need to be exposed
- UFW is configured to block unnecessary ports
- All traffic is encrypted with TLS
- Let's Encrypt provides automatic certificate renewal

## Maintenance

### Certificate Renewal

Certificates will auto-renew via the certbot timer service. To manually renew:
```bash
sudo certbot renew
```

### Checking Services

To check the status of all services:
```bash
systemctl status sslh nginx docker kubelet prometheus grafana-server
```

### Logs

Check logs for troubleshooting:
```bash
# SSLH logs
journalctl -u sslh

# NGINX logs
sudo tail -f /var/log/nginx/error.log

# Kubernetes logs
kubectl logs -n kube-system <pod-name>

# Docker logs
docker logs <container-name>
```

## Additional Resources

- [SSLH Documentation](https://github.com/yrutschle/sslh)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
