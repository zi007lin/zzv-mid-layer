# Services Setup Script

## Overview
The `run_serv_setup.sh` script automates the deployment of services for the ZZV Mid-Layer project. It handles the installation and configuration of applications, message queues, and monitoring tools on top of the established infrastructure.

## Prerequisites

- Completed infrastructure setup (`run_infra_setup.sh`)
- Running Kubernetes cluster (K3s)
- Initialized Helm
- Configured networking and firewall
- System requirements:
  - 4GB RAM minimum
  - 40GB free disk space
  - Network access to container registries

## Services Deployed

1. **Message Queue**
   - Kafka (KRaft mode)
   - Message broker configuration
   - Topic setup

2. **Applications**
   - Elixir Phoenix application
   - Future deployments:
     - Spring Boot (planned)
     - MongoDB (planned)

3. **Monitoring** (Planned)
   - Prometheus
   - Grafana
   - Metrics collection

## Usage

1. **Pre-deployment Check**
   ```bash
   # Verify Kubernetes is ready
   kubectl get nodes
   
   # Check Helm status
   helm list
   ```

2. **Running the Script**
   ```bash
   sudo ./run_serv_setup.sh
   ```

3. **Verification Steps**
   ```bash
   # Check Kafka
   kubectl get pods -l app=kafka
   
   # Verify Phoenix app
   kubectl get pods -l app=phoenix
   
   # Check services
   kubectl get services
   ```

## Service Details

### Kafka Setup
- KRaft mode configuration
- Default topics created
- Exposed ports: 9092 (internal)

### Elixir Phoenix
- Application deployment
- Environment configuration
- Service exposure

### Planned Services
- Spring Boot application
- MongoDB database
- Prometheus monitoring
- Grafana dashboards

## Monitoring and Maintenance

### Health Checks
```bash
# Check pod status
kubectl get pods --all-namespaces

# View service logs
kubectl logs -f deployment/[service-name]

# Monitor resources
kubectl top pods
```

### Common Operations
1. **Restart Service**
   ```bash
   kubectl rollout restart deployment [service-name]
   ```

2. **Scale Service**
   ```bash
   kubectl scale deployment [service-name] --replicas=3
   ```

3. **Update Configuration**
   ```bash
   kubectl edit configmap [config-name]
   ```

## Troubleshooting

### Common Issues

1. **Service Won't Start**
   - Check pod logs
   - Verify resource limits
   - Ensure ConfigMaps are present

2. **Connection Issues**
   - Verify service discovery
   - Check network policies
   - Confirm port configurations

3. **Resource Problems**
   - Monitor node resources
   - Check pod resource limits
   - Verify storage availability

### Debug Commands
```bash
# Get detailed pod info
kubectl describe pod [pod-name]

# Check events
kubectl get events --sort-by='.lastTimestamp'

# View logs
kubectl logs -f [pod-name]
```

## Next Steps

After deployment:
1. Verify all services are running
2. Configure monitoring alerts
3. Set up backup procedures
4. Document service endpoints

## Support

For deployment issues:
1. Check pod logs
2. Review events
3. Consult service documentation
4. Open support ticket

## License

This script is part of the ZZV Mid-Layer project and is licensed under the MIT License. 