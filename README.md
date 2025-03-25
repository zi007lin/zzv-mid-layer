# ZZV Mid-Layer Observability Setup

## 🚀 Overview

This project provides a cloud-portable, Kubernetes-native deployment framework for real-time service observability, including:

- ✅ OpenTelemetry Collector
- ✅ Prometheus (metrics backend)
- ✅ Tempo (distributed tracing backend)
- ✅ Grafana (unified dashboarding)
- ✅ Secure NGINX reverse proxy with TLS
- ✅ Dynamic environment detection per VPS

---

## 📦 Directory Structure

```
scripts/
  setup_env.sh            # Detects DOMAIN_NAME, REGION, VPS_NAME from DNS
  require_env.sh          # Validates environment in all setup scripts
  run_infra_setup.sh      # Sets up Docker, K8s, SSLH, firewall, reverse proxy
  run_serv_setup.sh       # Deploys Kafka, Phoenix, OTEL, Prometheus, Grafana
  configure_nginx.sh      # Adds NGINX reverse proxy routes (/grafana, /tempo, etc)
  deploy_otel_collector.sh
  deploy_tempo.sh
  install_prometheus.sh
  install_grafana.sh
```

---

## ✅ Setup Instructions

### Step 1: Detect and Export VPS Identity

```bash
chmod +x scripts/setup_env.sh
./scripts/setup_env.sh
source ~/zzv.env
```

### Step 2: Provision Infrastructure

```bash
./run_infra_setup.sh
```

### Step 3: Deploy Services & Observability

```bash
./run_serv_setup.sh
```

---

## 🌐 Secure Access via NGINX

Once deployed, access the observability stack at:

- Grafana: `https://<DOMAIN_NAME>/grafana/`
- Prometheus: `https://<DOMAIN_NAME>/prometheus/`
- Tempo: `https://<DOMAIN_NAME>/tempo/`

---

## 🛠️ Validated with:

- Ubuntu 24.04 LTS (Contabo VPS)
- K3s and kubeadm
- Cloudflare DNS for zone: `zzv.io`

---

## 🧪 Troubleshooting

Make sure you have:

- A valid TLS cert (via Let's Encrypt or manual)
- Your `DOMAIN_NAME` matches DNS for your VPS IP
- `ufw` does **not expose** raw ports (3000, 9090, etc) — only port `443`

---

## 📄 License

MIT — built for internal cloud observability at scale.
