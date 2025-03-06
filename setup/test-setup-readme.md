# Testing Your Distributed System Setup

This guide explains how to test your distributed system to ensure that port 443 is correctly shared between SSH and HTTPS traffic, and that all components are functioning properly.

## Using the Test Script

The `test_setup.sh` script performs comprehensive tests of your system configuration to validate that everything is working correctly.

### Prerequisites

- Ubuntu 22.04.5 LTS (or compatible system)
- Root or sudo access
- Distributed system already set up using `setup.sh`

### Running the Test

1. Make the script executable:
   ```bash
   chmod +x test_setup.sh
   ```

2. Run the script with sudo:
   ```bash
   sudo ./test_setup.sh
   ```

3. Review the output for any errors or warnings.

The script will generate a timestamped log file containing all test results for future reference.

## What the Test Script Checks

### 1. Core Services

#### SSLH Configuration
- Verifies SSLH service is running
- Confirms SSLH is configured to listen on port 443
- Checks if SSH traffic is properly forwarded to port 22
- Validates HTTPS traffic forwarding to NGINX on port 4443

#### NGINX Configuration
- Confirms NGINX service is running
- Verifies NGINX is listening on port 4443 for SSL traffic
- Checks SSL certificate configuration and expiration
- Validates WebSocket configuration

### 2. Network Configuration

#### Port Usage
- Checks if port 443 is in use by SSLH
- Confirms port 4443 is in use by NGINX
- Identifies any port conflicts

#### Firewall Rules
- Verifies firewall status
- Confirms port 443 (SSH/HTTPS) is allowed
- Checks if port 80 (HTTP for Let's Encrypt) is open

### 3. Application Components

#### Docker and Containers
- Confirms Docker service is running
- Verifies Docker Compose installation
- Lists running containers
- Checks specifically for Kafka container

#### Kubernetes
- Verifies kubectl and kubelet are installed and running
- Lists Kubernetes nodes and pods
- Checks for specific deployments:
  - Spring Boot application
  - Phoenix LiveView application
  - MongoDB

#### Monitoring Services
- Confirms Prometheus is running and configured
- Verifies Grafana service and datasource configuration

### 4. Connection Tests

#### HTTP and HTTPS
- Tests HTTP to HTTPS redirection
- Verifies HTTPS connection is working
- Checks WebSocket endpoint availability

#### SSH on Port 443
- Provides instructions for testing SSH access on port 443

## Manual Testing

In addition to the automated script, you should perform these manual tests:

### Testing SSH on Port 443

From a different machine, attempt to connect via SSH using port 443:

```bash
ssh -p 443 username@yourdomain.com
```

You should be able to connect normally as if you were using the standard SSH port.

### Testing HTTPS on Port 443

Open a web browser and navigate to:

```
https://yourdomain.com
```

The website should load securely with a valid SSL certificate.

### Testing WebSockets

To test WebSocket connections, you can use a tool like websocat:

```bash
websocat wss://yourdomain.com/ws
```

Or use a web-based WebSocket client and connect to:

```
wss://yourdomain.com/ws
```

### Testing Application Endpoints

Test each of your application endpoints:

- Frontend: `https://yourdomain.com/`
- API: `https://yourdomain.com/api/`
- Grafana: `https://yourdomain.com/grafana/`
- Prometheus: `https://yourdomain.com/prometheus/`
- Kafka UI: `https://yourdomain.com/kafka/`
- MongoDB Admin: `https://yourdomain.com/mongo/`

## Troubleshooting Common Issues

### SSLH Not Starting

**Symptom:** SSLH service fails to start or port 443 is already in use.

**Solution:**
1. Check what's using port 443:
   ```bash
   sudo netstat -tulnp | grep :443
   ```
2. Stop the conflicting service or reconfigure SSLH to use a different port.

### SSL Certificate Issues

**Symptom:** HTTPS works but shows certificate warnings or errors.

**Solution:**
1. Check certificate expiration:
   ```bash
   sudo openssl x509 -enddate -noout -in /etc/letsencrypt/live/yourdomain.com/fullchain.pem
   ```
2. Renew if needed:
   ```bash
   sudo certbot renew
   ```

### SSH Connection Refused

**Symptom:** Cannot connect via SSH on port 443.

**Solution:**
1. Verify SSLH is running:
   ```bash
   systemctl status sslh
   ```
2. Check SSLH configuration in `/etc/default/sslh` to ensure it's forwarding to the correct SSH port.
3. Confirm SSH service is running:
   ```bash
   systemctl status ssh
   ```

### NGINX Not Receiving HTTPS Traffic

**Symptom:** HTTPS connections fail or timeout.

**Solution:**
1. Verify NGINX is running:
   ```bash
   systemctl status nginx
   ```
2. Check NGINX is listening on port 4443:
   ```bash
   sudo netstat -tulnp | grep :4443
   ```
3. Test NGINX configuration:
   ```bash
   sudo nginx -t
   ```

### Kubernetes Issues

**Symptom:** Kubernetes pods not starting or applications unavailable.

**Solution:**
1. Check node status:
   ```bash
   kubectl get nodes
   ```
2. Look for pod errors:
   ```bash
   kubectl get pods --all-namespaces
   kubectl describe pod <pod-name>
   ```
3. Check pod logs:
   ```bash
   kubectl logs <pod-name>
   ```

## Advanced Diagnostics

For more detailed system information, run the `get_setup_info.sh` script:

```bash
./get_setup_info.sh
```

This will generate a comprehensive report of your system configuration, including:
- System details
- Running services
- Network configuration
- Docker and Kubernetes status
- Configuration files

## After Testing

If all tests pass, your distributed system is correctly configured with:
- Port 443 properly shared between SSH and HTTPS traffic
- NGINX correctly configured as a reverse proxy
- All application components running normally
- Kubernetes properly managing your containerized applications
- Monitoring systems correctly set up

If you encounter any issues, review the test results and log files to identify and fix the specific problems.
