# Observability Stack for Kubernetes

## 📁 Folder Structure

```
observability-stack/
├── 01-namespaces/          # Namespace definitions
├── 02-rbac/               # Role-based access control
├── 03-storage/            # MinIO object storage
├── 04-loki/               # Loki log aggregation
├── 05-alloy/              # Grafana Alloy agent
├── 06-grafana/            # Grafana dashboards and config
├── 07-monitoring/         # Prometheus and AlertManager
├── 08-security/           # Security policies and configs
├── 09-scripts/            # Deployment and utility scripts
├── 10-docs/               # Documentation and guides
└── README.md              # This file
```

## 🚀 Quick Start

### 1. Prerequisites
- Kubernetes cluster (v1.20+)
- kubectl configured
- Helm (optional)
- At least 8GB RAM and 4 CPU cores available

### 2. Deploy the Stack

```bash
# Make scripts executable
chmod +x 09-scripts/*.sh

# Deploy everything
./09-scripts/deploy-all.sh

# Or deploy step by step
./09-scripts/deploy-step-by-step.sh
```

### 3. Access URLs
- **Grafana**: http://grafana.local (admin/admin123)
- **MinIO Console**: http://minio.local:9001 (minioadmin/minioadmin123)

### 4. Add to /etc/hosts
```bash
echo '127.0.0.1 grafana.local minio.local' | sudo tee -a /etc/hosts
```

## 📋 Deployment Order

1. **Namespaces** (`01-namespaces/`)
2. **RBAC** (`02-rbac/`)
3. **Storage** (`03-storage/`)
4. **Loki** (`04-loki/`)
5. **Alloy** (`05-alloy/`)
6. **Grafana** (`06-grafana/`)
7. **Monitoring** (`07-monitoring/`) - Optional
8. **Security** (`08-security/`)

## 🔧 Configuration

### Storage Requirements
- **Grafana**: 10Gi
- **Loki**: 20Gi local + 50Gi object storage
- **MinIO**: 50Gi
- **Prometheus**: 20Gi (if enabled)

### Resource Requirements
- **Grafana**: 512Mi RAM, 500m CPU
- **Loki**: 2Gi RAM, 1000m CPU
- **Alloy**: 512Mi RAM, 200m CPU per node
- **MinIO**: 1Gi RAM, 500m CPU

## 🛠️ Management Commands

```bash
# Check status
kubectl get pods -n observability
kubectl get pods -n storage

# View logs
kubectl logs -n observability deployment/loki
kubectl logs -n observability daemonset/alloy
kubectl logs -n observability deployment/grafana

# Port forward for local access
kubectl port-forward -n observability svc/grafana 3000:3000
kubectl port-forward -n storage svc/minio 9001:9001

# Scale components
kubectl scale -n observability deployment/loki --replicas=2
kubectl scale -n observability deployment/grafana --replicas=2
```

## 🚨 Troubleshooting

### Common Issues

1. **Pods stuck in Pending**
   ```bash
   kubectl describe pod -n observability <pod-name>
   # Check resource quotas and storage classes
   ```

2. **Loki not receiving logs**
   ```bash
   # Check Alloy configuration
   kubectl logs -n observability daemonset/alloy
   # Test connectivity
   kubectl exec -n observability deploy/alloy -- wget -qO- http://loki:3100/ready
   ```

3. **Grafana can't connect to Loki**
   ```bash
   # Check service endpoints
   kubectl get endpoints -n observability loki
   # Test from Grafana pod
   kubectl exec -n observability deploy/grafana -- curl http://loki:3100/ready
   ```

### Log Collection

```bash
# Collect all logs for debugging
./09-scripts/collect-logs.sh
```

## 🔒 Security Features

- Network policies for traffic isolation
- Pod security policies
- RBAC with minimal permissions
- Secret management for credentials
- Resource quotas and limits

## 📊 Monitoring

- **Loki Metrics**: Log ingestion rate, error rate, storage usage
- **Grafana Metrics**: Dashboard usage, user sessions
- **Alloy Metrics**: Collection rate, processing errors
- **Cluster Metrics**: CPU, memory, disk usage

## 🔄 Backup and Recovery

- Automated Grafana dashboard backup
- Configuration backup scripts
- Disaster recovery procedures
- Data retention policies

## 📚 Documentation

See `10-docs/` folder for:
- Architecture diagrams
- Configuration guides
- Best practices
- Troubleshooting guides

## 🤝 Support

- Check logs: `kubectl logs -n observability <pod-name>`
- Describe resources: `kubectl describe <resource> -n observability`
- Review configuration: `kubectl get configmap -n observability -o yaml`

## 📄 License

This configuration is provided as-is for educational and production use.