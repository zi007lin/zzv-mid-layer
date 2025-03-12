# Infrastructure Setup Script

## Overview
The `run_infra_setup.sh` script automates the infrastructure setup for the ZZV Mid-Layer project. It handles the installation and configuration of core components, Kubernetes cluster, networking, and security settings.

## Prerequisites

- Ubuntu 22.04.5 LTS
- Root access or sudo privileges
- Active internet connection
- Minimum system requirements:
  - 2 CPU cores
  - 2GB RAM
  - 20GB free disk space
  - Open ports: 80, 443, 6443

## Components Installed

1. **Core Dependencies**
   - Essential system packages
   - Build tools
   - Network utilities

2. **Helm Package Manager**
   - Helm CLI
   - SSLH for port sharing
   - Repository configuration

3. **Kubernetes (K3s)**
   - Lightweight Kubernetes distribution
   - kubectl command-line tool
   - Basic cluster configuration

4. **Network Setup**
   - NGINX reverse proxy
   - SSL/TLS configuration
   - Port forwarding rules

5. **Security Configuration**
   - Firewall rules
   - Cloudflare IP ranges
   - Basic security policies

## Usage

1. **Running the Script**
   ```bash
   sudo ./run_infra_setup.sh
   ```

2. **Verification**
   ```bash
   # Check Kubernetes status
   kubectl get nodes
   
   # Verify NGINX
   systemctl status nginx
   
   # Check Helm
   helm version
   ```

3. **Expected Output**
   - Success messages for each component
   - Node status "Ready"
   - All services running

## Troubleshooting

### Common Issues

1. **Script Fails to Start**
   - Ensure execute permissions: `chmod +x run_infra_setup.sh`
   - Check utils.sh exists in scripts directory

2. **Kubernetes Installation Fails**
   - Check system resources
   - Verify network connectivity
   - Review logs: `journalctl -u k3s`

3. **NGINX Configuration Issues**
   - Check port availability
   - Verify SSL certificates
   - Review logs: `nginx -t`

### Log Locations
- Kubernetes: `/var/log/k3s.log`
- NGINX: `/var/log/nginx/`
- Script logs: Check terminal output

## Next Steps

After successful infrastructure setup:
1. Verify all components are running
2. Run the services setup script: `./run_serv_setup.sh`
3. Configure application-specific settings

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review script logs
3. Open an issue in the repository
4. Contact system administrator

## License

This script is part of the ZZV Mid-Layer project and is licensed under the MIT License. 