# Distributed System Setup Guide

This guide explains how to set up a distributed system with multiple components sharing port 443 for both SSH and HTTPS traffic.

## System Overview

This setup creates a distributed system with the following components:

- **Port 443 Sharing**: SSH and HTTPS traffic both use the same port (443) using SSLH
- **Web Server**: NGINX as a reverse proxy for multiple applications
- **Container Runtime**: Docker and Docker Compose
- **Orchestration**: Kubernetes for container orchestration
- **Messaging**: Kafka in KRaft mode for distributed messaging
- **Applications**:
  - Java Spring Boot with GraalVM for backend services
  - Elixir Phoenix LiveView for real-time web UI
  - WebSocket support for real-time communication
- **Database**: MongoDB for data storage
- **Monitoring**: Prometheus and Grafana for monitoring
- **Security**: Let's Encrypt for SSL certificates, UFW firewall

## Prerequisites

- Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-25-generic x86_64)
- Root or sudo access
- Three servers with public IP addresses (NAM, EMEA, APAC)
- A domain name pointing to your server's IP address
- Open ports 80 and 443 (for initial setup and operation)

## Installation

### 1. Set Environment Variables

Before running the setup script, set the following environment variables:

```bash
export NAM_IP="your_nam_ip"
export EMEA_IP="your_emea_ip"
export APAC_IP="your_apac_ip"
export DOMAIN="yourdomain.com"
```

### 2. Run the Setup Script

```bash
chmod +x setup.sh
./setup.sh
```

The script will:
- Install all necessary dependencies
- Configure SSLH to share port 443
- Set up NGINX as a reverse proxy
- Configure SSL certificates
- Deploy Kafka, Spring Boot, Phoenix LiveView, and MongoDB
- Set up monitoring with Prometheus and Grafana
- Configure the firewall

## Architecture

### Port 443 Sharing

The system uses SSLH to multiplex SSH and HTTPS traffic on port 443:

1. SSLH listens on port 443 and examines incoming traffic
2. SSH traffic is forwarded to the local SSH daemon on port 22
3. HTTPS traffic is forwarded to NGINX on port 4443
4. NGINX then routes traffic to the appropriate backend services

```
Client Request (Port 443)
       ↓
     SSLH
      / \
     /   \
SSH (22)  NGINX (4443)
           / | \
          /  |  \
   Spring   Phoenix  Other
    Boot    LiveView Services
```

### Application Architecture

- **Frontend**: Elixir Phoenix LiveView (port 4000)
- **API**: Spring Boot with GraalVM (port 8080)
- **WebSockets**: Dedicated endpoint via /ws
- **Database**: MongoDB (port 27017)
- **Messaging**: Kafka (ports 9092, 9093)
- **Monitoring**:
  - Prometheus (port 9090)
  - Grafana (port 3000)

## Post-Installation

After installation, check that all services are running:

```bash
# Check SSLH
systemctl status sslh

# Check NGINX
systemctl status nginx

# Check Docker
docker ps

# Check Kubernetes
kubectl get nodes
kubectl get pods --all-namespaces

# Check Kafka
docker logs kafka_kraft

# Check Monitoring
systemctl status prometheus
systemctl status grafana-server
```

## Accessing Services

- **SSH**: `ssh -p 443 user@yourdomain.com`
- **Web UI**: `https://yourdomain.com/`
- **API**: `https://yourdomain.com/api/`
- **WebSockets**: `wss://yourdomain.com/ws`
- **Grafana**: `https://yourdomain.com/grafana/`
- **Prometheus**: `https://yourdomain.com/prometheus/`
- **Kafka UI**: `https://yourdomain.com/kafka/`
- **MongoDB Admin**: `https://yourdomain.com/mongo/`

## Troubleshooting

### Port 443 Issues

If SSLH fails to start, check if port 443 is already in use:

```bash
netstat -tulnp | grep :443
```

### SSL Certificate Issues

If Let's Encrypt fails, try manually obtaining certificates:

```bash
sudo certbot --nginx -d yourdomain.com
```

### Checking Logs

```bash
# SSLH logs
journalctl -u sslh

# NGINX logs
sudo tail -f /var/log/nginx/error.log

# Kubernetes logs
kubectl logs -n kube-system <pod-name>

# Kafka logs
docker logs kafka_kraft
```

### Gathering System Information

To collect system information for troubleshooting:

```bash
chmod +x get_setup_info.sh
./get_setup_info.sh
```

This will create a directory with detailed system information including:
- System details
- Installed packages
- Running services
- Network configuration
- Firewall rules
- Docker and Kubernetes status

## Security Considerations

This setup includes several security features:

1. **Single Port Exposure**: Only ports 80 and 443 need to be exposed
2. **TLS Encryption**: All traffic is encrypted with TLS
3. **Firewall**: UFW is configured to block unnecessary ports
4. **Certificate Management**: Automatic certificate renewal with Let's Encrypt

## Maintenance

### Updating Certificates

Certificates will auto-renew via the certbot timer service. To manually renew:

```bash
sudo certbot renew
```

### Updating Kubernetes

```bash
sudo apt update
sudo apt upgrade -y kubeadm kubectl kubelet
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply <version>
```

### Backing Up MongoDB

```bash
kubectl exec -it $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- mongodump --out=/tmp/backup
kubectl cp $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}'):/tmp/backup ./mongodb-backup
```

## Additional Resources

- [SSLH Documentation](https://github.com/yrutschle/sslh)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Spring Boot Documentation](https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/)
- [Phoenix LiveView Documentation](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
- [MongoDB Documentation](https://docs.mongodb.com/)
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Grafana Documentation](https://grafana.com/docs/)
