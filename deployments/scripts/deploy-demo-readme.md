# Demo Deployment for `zzv.io`

## Overview
This repository provides Kubernetes manifests and deployment scripts to deploy a **demo environment** based on Cloudflare’s DNS setup for `zzv.io`.

## DNS Mappings
The deployment is designed to integrate with Cloudflare's DNS records:

| Domain | Purpose |
|--------|---------|
| `api.zzv.io` | Routes to Spring Boot API via Ingress Controller |
| `www.zzv.io` | Frontend Web UI Service |
| `p1-apac.zzv.io` | Kafka Cluster (APAC Node) |
| `p1-emea.zzv.io` | Kafka Cluster (EMEA Node) |
| `p1-nam.zzv.io` | Kafka Cluster (NAM Node) |

## Project Structure
```plaintext
zzv-mid-layer/
│── deployments/
│   ├── demo/
│   │   ├── ingress-demo.yaml
│   │   ├── kafka-demo-statefulset.yaml
│   │   ├── mongodb-demo-statefulset.yaml
│   │   ├── spring-boot-demo-deployment.yaml
│── scripts/
│   ├── deploy-demo.sh
│   ├── delete-demo.sh
│   ├── status-demo.sh
│── README.md
```

## Deployment Instructions

### 1. Deploy the Demo Environment
Run the following command to deploy all services:
```bash
./scripts/deploy-demo.sh
```

### 2. Verify the Deployment
Check the status of all pods, services, and ingress:
```bash
./scripts/status-demo.sh
```

### 3. Access Services
- **API Endpoint:** `https://api.zzv.io`
- **Frontend UI:** `https://www.zzv.io`

### 4. Delete the Demo Environment
To remove all demo services, run:
```bash
./scripts/delete-demo.sh
```

## Notes
- Make sure Cloudflare is correctly routing `api.zzv.io` and `www.zzv.io`.
- Ensure Kubernetes Ingress Controller is correctly set up.
- Modify YAML files as needed for production-like settings.

## Next Steps
- Add **TLS Certificates** via Let's Encrypt
- Integrate **Prometheus & Grafana** for monitoring
- Implement **CI/CD** with GitHub Actions or ArgoCD

---
🚀 **This demo is built to showcase the scalable deployment of microservices under Cloudflare’s DNS routing.**
