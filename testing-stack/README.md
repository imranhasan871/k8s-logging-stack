# Testing Stack - Kubernetes Observability Stack

## Overview

The testing-stack is a complete Kubernetes observability solution that provides log aggregation, collection, and visualization capabilities. It consists of four main components deployed in the `observability` namespace:

- **Loki** - Log aggregation system
- **Alloy** - Log collection agent (Grafana's replacement for Promtail)
- **Grafana Datasource** - Configuration for connecting Grafana to Loki
- **Namespace** - Dedicated namespace for all observability components

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Kubernetes    │    │      Alloy      │    │      Loki       │
│     Pods        │───▶│  (DaemonSet)    │───▶│  (Deployment)   │
│                 │    │  Log Collector  │    │ Log Aggregator  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                                              ┌─────────────────┐
                                              │     Grafana     │
                                              │ (via datasource)│
                                              │  Visualization  │
                                              └─────────────────┘
```

## Components

### 1. Namespace (`namespace.yaml`)
- **Purpose**: Creates the `observability` namespace to isolate all observability components
- **Resources**: 1 Namespace

### 2. Alloy (`alloy.yaml`)
- **Purpose**: Log collection agent that runs on every node to collect pod logs
- **Deployment**: DaemonSet (runs on all nodes)
- **Key Features**:
  - RBAC configuration with ClusterRole for accessing pods, nodes, services
  - ConfigMap with Alloy configuration for log processing
  - File discovery of pod logs at `/var/log/pods/*/*/*/*.log`
  - Log parsing and labeling with namespace, pod, and container information
  - Direct integration with Loki endpoint

**Resources**:
- ServiceAccount: `alloy`
- ClusterRole: `alloy` (read access to nodes, pods, services)
- ClusterRoleBinding: `alloy`
- ConfigMap: `alloy-config`
- DaemonSet: `alloy`
- Service: `alloy-metrics` (port 12345)

### 3. Loki (`loki.yaml`)
- **Purpose**: Log aggregation system that stores and indexes logs
- **Deployment**: Single replica Deployment
- **Storage**: Local filesystem storage (ephemeral)
- **Key Features**:
  - HTTP API on port 3100
  - gRPC API on port 9095
  - BoltDB shipper for index management
  - Filesystem storage for chunks
  - Ingestion rate limiting (10MB/min, 20MB burst)

**Resources**:
- ConfigMap: `loki-config`
- Deployment: `loki` (1 replica)
- Service: `loki` (ports 3100 HTTP, 9095 gRPC)

### 4. Grafana Datasource (`grafana-datasource.yaml`)
- **Purpose**: Provides Grafana datasource configuration for Loki
- **Configuration**: Points to Loki service at `http://loki:3100`
- **Features**: Configured with 1000 max lines per query

**Resources**:
- ConfigMap: `grafana-datasources`

## Deployment Instructions

### Prerequisites
- Kubernetes cluster (tested with standard K8s distributions)
- kubectl configured to access your cluster
- Sufficient cluster resources (minimum 1GB RAM, 1 CPU core)

### Step-by-Step Deployment

1. **Create the namespace**:
   ```bash
   kubectl apply -f namespace.yaml
   ```

2. **Deploy Loki (log storage)**:
   ```bash
   kubectl apply -f loki.yaml
   ```

3. **Deploy Alloy (log collection)**:
   ```bash
   kubectl apply -f alloy.yaml
   ```

4. **Configure Grafana datasource** (if Grafana is deployed):
   ```bash
   kubectl apply -f grafana-datasource.yaml
   ```

### All-in-One Deployment
```bash
kubectl apply -f testing-stack/
```

## Configuration Details

### Alloy Configuration
The Alloy agent is configured to:
- Discover log files using pattern `/var/log/pods/*/*/*/*.log`
- Extract metadata from file paths (namespace, pod name, container name)
- Add static labels: `job=kubernetes-pods`, `cluster=k8s-cluster`
- Forward processed logs to Loki at `http://loki:3100/loki/api/v1/push`

### Loki Configuration
Loki is configured with:
- **Authentication**: Disabled (`auth_enabled: false`)
- **Storage**: Local filesystem (`/var/loki/`)
- **Schema**: v11 with BoltDB shipper
- **Retention**: 168 hours for old samples
- **Limits**: 10MB/min ingestion rate, 20MB burst

### Security Considerations
- Alloy runs with privileged access to read host logs
- Loki uses ephemeral storage (data lost on pod restart)
- No authentication enabled (suitable for testing environments only)

## Monitoring and Troubleshooting

### Check Component Status
```bash
# Check all observability pods
kubectl get pods -n observability

# Check Alloy DaemonSet
kubectl get daemonset alloy -n observability

# Check Loki deployment
kubectl get deployment loki -n observability
```

### View Logs
```bash
# Alloy logs
kubectl logs -l app=alloy -n observability

# Loki logs
kubectl logs -l app=loki -n observability
```

### Test Connectivity
```bash
# Port forward to Loki
kubectl port-forward svc/loki 3100:3100 -n observability

# Query Loki API
curl http://localhost:3100/ready
curl http://localhost:3100/api/v1/label
```

### Access Alloy Metrics
```bash
# Port forward to Alloy metrics
kubectl port-forward svc/alloy-metrics 12345:12345 -n observability

# View metrics
curl http://localhost:12345/metrics
```

## Resource Requirements

### Minimum Resources
- **Alloy**: 128Mi RAM, 100m CPU (per node)
- **Loki**: 256Mi RAM, 200m CPU
- **Total cluster**: ~1GB RAM, ~500m CPU (3-node cluster)

### Recommended Resources
- **Alloy**: 512Mi RAM, 500m CPU (per node)
- **Loki**: 1Gi RAM, 1 CPU
- **Storage**: 10Gi+ for Loki data persistence (if using persistent volumes)

## Limitations

1. **Ephemeral Storage**: Loki uses emptyDir volumes - logs are lost on pod restart
2. **Single Replica**: No high availability for Loki
3. **No Authentication**: Security disabled for testing purposes
4. **Local Storage**: Not suitable for production multi-node clusters
5. **No Retention Policy**: Logs accumulate indefinitely until storage limit

## Integration with Grafana

If you have Grafana deployed, the datasource configuration will automatically configure Loki as a data source. You can then:

1. Import log dashboard templates
2. Create custom log queries using LogQL
3. Set up alerting based on log patterns
4. Correlate logs with metrics (if Prometheus is also deployed)

## Next Steps

For production deployment, consider:
- Implementing persistent storage for Loki
- Enabling authentication and authorization
- Setting up log retention policies
- Deploying Loki in high-availability mode
- Adding monitoring and alerting for the observability stack itself