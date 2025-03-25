# 📦 ZZV Mid-Layer – Release Notes

## 🚀 Version: v1.0 — Unified Observability Infrastructure

**Release Date:** 2025-03-24  
**Maintainer:** Zeta.Zen

---

### ✅ Highlights

#### 🔧 Modernized `run_serv_setup.sh`
- Restructured to follow modular, traceable, and cloud-portable deployment style
- Inline observability pipeline validation added:
  - Prometheus
  - Grafana
  - OpenTelemetry Collector
  - Tempo

#### 📦 Kubernetes-Based Observability Stack Deployed
- **OpenTelemetry Collector** — Receives metrics/traces and exports to Prometheus + Tempo
- **Tempo** — Backend for distributed tracing
- **Prometheus** — Metrics collection and query engine
- **Grafana** — Visualization UI for metrics and traces

#### 🧹 Cleanup and Script Archiving
- Legacy scripts moved to `scripts_extra/`:
  - `deploy_mongodb.sh`
  - `setup_letsencrypt.sh`
  - `deploy_spring_boot.sh`
  - `ensure_docker_compose.sh`
  - `install_reverse_proxy_test.sh`

---

### 🧪 Validation

Run:
```bash
kubectl apply -f prometheus.yaml
kubectl apply -f tempo.yaml
kubectl apply -f grafana.yaml
kubectl apply -f otel-collector.yaml
./run_serv_setup.sh
```

Then test observability pipeline access:
- Prometheus: `http://<node-ip>:9090`
- Grafana: `http://<node-ip>:3000`
- Tempo: `http://<node-ip>:3200`

---

### 🏁 Next Steps

- Add Grafana dashboards and alerts
- Integrate Loki and Alertmanager
- Add TLS via cert-manager for public exposure (optional)
- Tag this release with: `git tag -a v1.0 -m "Initial observability release"` and push

---

## 🔖 Subrelease: `v1.0.1` — Environment-Aware Secure Deployment

**Release Date:** 2025-03-24  
**Maintainer:** Zeta.Zen

### ✅ Enhancements

- Introduced `setup_env.sh` to auto-detect VPS region and domain via DNS (Cloudflare `zzv.io`)
- Added `require_env.sh` to validate essential env variables in all scripts
- Updated all deploy scripts to:
  - Source `~/zzv.env` dynamically
  - Respect `$DOMAIN_NAME`, `$REGION`, `$VPS_NAME` across regions (NAM, EMEA, APAC)
- Hardened `run_serv_setup.sh` to include inline environment validation
- Enhanced `configure_nginx.sh` to reverse-proxy Grafana, Prometheus, and Tempo over TLS (port 443 only)
- Updated `README.md` with full dynamic setup instructions

### 🔐 Security

- Disabled raw port exposure for Grafana, Prometheus, Tempo
- TLS routing exclusively via NGINX with Let's Encrypt support

