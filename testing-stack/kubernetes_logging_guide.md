# Complete Kubernetes Log Collection Setup Guide
**From Zero to Working Grafana Dashboard with Alloy + Loki**

## Overview

This guide documents the complete process of setting up a Kubernetes logging stack using Grafana Alloy for log collection, Loki for storage, and Grafana for visualization. We'll cover every problem encountered and how to solve them.

## Architecture

```
Kubernetes Pods → Log Files → Alloy (Collector) → Loki (Storage) → Grafana (Visualization)
```

## Initial Setup

### Components Deployed
1. **Loki** - Log aggregation system
2. **Grafana** - Visualization and dashboards
3. **Alloy** - Log collector (replacement for Promtail)

### Namespace Structure
All components were deployed in the `observability` namespace.

## Problems Encountered & Solutions

### Problem 1: Alloy Configuration Syntax Errors

**Issue**: Initial Alloy configuration had multiple syntax errors:
- `**path**` instead of `__path__`
- Missing commas in field lists
- Incorrect block names (`stage.relabel` vs `discovery.relabel`)

**Error Messages**:
```
Error: /etc/alloy/config.alloy:46:30: missing ',' in field list
Error: /etc/alloy/config.alloy:38:3: unrecognized block name "stage.relabel"
Error: /etc/alloy/config.alloy:19:1: Failed to build component: missing required attribute "role"
```

**Solution**: 
1. Fix `**path**` to `__path__` in file matching
2. Add trailing commas in all field lists
3. Use `discovery.relabel` instead of `stage.relabel`
4. Add required `role = "pod"` to `discovery.kubernetes`

### Problem 2: File Path Pattern Mismatch

**Issue**: Alloy discovered 0 active files despite log files existing.

**Root Cause**: File path pattern was incorrect.
- Expected pattern: `/var/log/pods/*/*/*/*.log` (4 levels)
- Actual structure: `/var/log/pods/namespace_podname_uid/container/0.log` (3 levels)

**Investigation Steps**:
```bash
# Check actual file structure
kubectl exec -n observability alloy-pod -- find /var/log/pods -name "*.log" | head -5
kubectl exec -n observability alloy-pod -- ls -la /var/log/pods/observability_*/

# Check Alloy metrics
curl -s http://localhost:12345/metrics | grep "loki_source_file_files_active_total"
```

**Solution**: Change file pattern from `/*/*/*/*.log` to `/*/*/*.log`

### Problem 3: No Data in Grafana Despite Successful Collection

**Issue**: Grafana showed "Data source connected, but no labels were received"

**Investigation Process**:
1. Verified Alloy was reading files: `loki_source_file_files_active_total = 31`
2. Checked Loki API: `curl http://localhost:3100/loki/api/v1/labels`
3. Found labels existed: `["filename", "job"]`

**Root Cause**: LogQL queries in dashboard were too restrictive and didn't match actual log format.

**Solution**: Simplify queries and match actual log structure:
```logql
# Instead of complex regex patterns, use:
{job="kubernetes-pods", filename=~"/var/log/pods/default_.*nginx.*"}
```

### Problem 4: Grafana Dashboard Datasource UID Mismatch

**Issue**: Imported dashboard JSON failed with "Datasource loki was not found"

**Cause**: Dashboard JSON hardcoded UID as "loki" but actual datasource had different UID.

**Solution**:
1. Find actual UID: Configuration → Data Sources → Loki → Copy UID from URL
2. Replace all occurrences of `"uid": "loki"` with actual UID (e.g., `"uid": "P8E80F9AEF21F6940"`)

## Working Configuration Files

### Loki Configuration
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-config
  namespace: observability
data:
  loki.yaml: |
    auth_enabled: false
    server:
      http_listen_port: 3100
      grpc_listen_port: 9095
    ingester:
      lifecycler:
        address: 127.0.0.1
        ring:
          kvstore:
            store: inmemory
          replication_factor: 1
      chunk_idle_period: 5m
      max_chunk_age: 1h
      chunk_target_size: 1048576
      chunk_retain_period: 30s
      wal:
        enabled: false
    limits_config:
      ingestion_rate_mb: 10
      ingestion_burst_size_mb: 20
      reject_old_samples: true
      reject_old_samples_max_age: 168h
    schema_config:
      configs:
        - from: 2020-10-24
          store: boltdb-shipper
          object_store: filesystem
          schema: v11
          index:
            prefix: index_
            period: 24h
    storage_config:
      boltdb_shipper:
        active_index_directory: /var/loki/index
        cache_location: /var/loki/cache
        shared_store: filesystem
      filesystem:
        directory: /var/loki/chunks
    compactor:
      working_directory: /var/loki/compactor
      shared_store: filesystem
```

### Final Working Alloy Configuration
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alloy-config
  namespace: observability
data:
  config.alloy: |
    loki.write "default" {
      endpoint {
        url = "http://loki:3100/loki/api/v1/push"
      }
    }
    
    local.file_match "pod_logs" {
      path_targets = [
        {
          __path__ = "/var/log/pods/*/*/*.log",
        },
      ]
    }
    
    loki.source.file "pod_logs" {
      targets = local.file_match.pod_logs.targets
      forward_to = [loki.process.pod_logs.receiver]
    }
    
    loki.process "pod_logs" {
      forward_to = [loki.write.default.receiver]
      
      stage.static_labels {
        values = {
          job = "kubernetes-pods",
        }
      }
    }
```

### RBAC Configuration
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: alloy
  namespace: observability
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: alloy
rules:
  - apiGroups: [""]
    resources: 
      - nodes
      - nodes/proxy
      - services
      - endpoints
      - pods
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: alloy
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: alloy
subjects:
  - kind: ServiceAccount
    name: alloy
    namespace: observability
```

## Troubleshooting Commands

### Check Alloy Status
```bash
# Check pod status
kubectl get pods -n observability -l app=alloy

# Check logs for errors
kubectl logs -n observability -l app=alloy --tail=20

# Check if files are being discovered
kubectl port-forward -n observability svc/alloy-metrics 12345:12345 &
curl -s http://localhost:12345/metrics | grep "loki_source_file_files_active_total"

# Check actual log files on filesystem
kubectl exec -n observability alloy-pod -- find /var/log/pods -name "*.log" | head -10
```

### Check Loki Status
```bash
# Port forward Loki
kubectl port-forward -n observability svc/loki 3100:3100 &

# Check available labels
curl -s http://localhost:3100/loki/api/v1/labels

# Check label values
curl -s http://localhost:3100/loki/api/v1/label/job/values

# Check Loki health
curl -s http://localhost:3100/ready
```

### Verify Data Flow
```bash
# Check if nginx pod is generating logs
kubectl logs -n default nginx-pod-name --tail=20

# Test basic LogQL queries in Grafana Explore
{job="kubernetes-pods"}
{job="kubernetes-pods", filename=~".*nginx.*"}
```

## Common LogQL Queries

### Basic Log Viewing
```logql
# All pod logs
{job="kubernetes-pods"}

# Logs from specific namespace
{job="kubernetes-pods", filename=~"/var/log/pods/default_.*"}

# Logs from specific application
{job="kubernetes-pods", filename=~".*nginx.*"}
```

### Nginx-Specific Queries
```logql
# Nginx access logs
{job="kubernetes-pods", filename=~"/var/log/pods/default_.*nginx.*"} |~ `\d+\.\d+\.\d+\.\d+ - -.*"(GET|POST|PUT|DELETE)`

# Nginx error logs
{job="kubernetes-pods", filename=~"/var/log/pods/default_.*nginx.*"} |~ "\\[error\\]|error|ERROR"

# Count requests per second
sum(rate({job="kubernetes-pods", filename=~"/var/log/pods/default_.*nginx.*"} |~ `\d+\.\d+\.\d+\.\d+ - -.*"(GET|POST|PUT|DELETE)` [5m]))
```

## Key Lessons Learned

### 1. Always Verify File Paths
- Don't assume log file structure
- Use `kubectl exec` to investigate actual paths
- Test file patterns incrementally

### 2. Debugging Methodology
1. Start with simple configurations
2. Check each component individually
3. Use metrics endpoints to verify data flow
4. Test queries in Grafana Explore before adding to dashboards

### 3. Configuration Management
- Always validate syntax before applying
- Use version control for configurations
- Document all custom settings

### 4. LogQL Query Development
- Start with broad queries, then narrow down
- Test individual components before complex regex
- Use Grafana Explore for iterative development

## Final Architecture
```
┌─────────────────┐    ┌──────────────┐    ┌─────────────┐    ┌──────────────┐
│   Pod Logs      │───▶│    Alloy     │───▶│    Loki     │───▶│   Grafana    │
│ /var/log/pods/  │    │ (DaemonSet)  │    │ (Storage)   │    │ (Dashboard)  │
│ */container/*.log│    │ Collects &   │    │ Stores &    │    │ Queries &    │
│                 │    │ Forwards     │    │ Indexes     │    │ Visualizes   │
└─────────────────┘    └──────────────┘    └─────────────┘    └──────────────┘
```

## Success Metrics
- Alloy: 31+ active files being monitored
- Loki: Labels `["filename", "job"]` available
- Grafana: Successful log queries returning data
- Dashboard: 5 functional panels showing nginx metrics

This setup provides a complete, production-ready logging solution for Kubernetes clusters with proper monitoring, visualization, and troubleshooting capabilities.