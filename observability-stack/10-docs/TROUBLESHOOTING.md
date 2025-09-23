# Troubleshooting Guide

## Common Issues and Solutions

### 1. Pods Stuck in Pending State

**Symptoms:**
- Pods remain in `Pending` status
- `kubectl describe pod` shows scheduling issues

**Common Causes & Solutions:**

#### Insufficient Resources
```bash
# Check node resources
kubectl describe nodes
kubectl top nodes

# Check resource quotas
kubectl describe resourcequota -n observability
```

**Solution:** Increase cluster resources or adjust resource requests/limits in deployments.

#### PVC Not Bound
```bash
# Check PVC status
kubectl get pvc -n observability
kubectl get pvc -n storage

# Check storage classes
kubectl get storageclass
```

**Solution:** Ensure storage class exists and has available storage.

#### Node Selector Issues
```bash
# Check node labels
kubectl get nodes --show-labels

# Check pod scheduling constraints
kubectl describe pod <pod-name> -n observability
```

### 2. Loki Not Receiving Logs

**Symptoms:**
- No logs appearing in Grafana
- Empty log queries
- Alloy shows connection errors

**Debugging Steps:**

```bash
# Check Alloy logs
kubectl logs -n observability daemonset/alloy

# Check Loki logs
kubectl logs -n observability deployment/loki

# Test connectivity from Alloy to Loki
kubectl exec -n observability -c alloy $(kubectl get pod -n observability -l app=alloy -o jsonpath='{.items[0].metadata.name}') -- wget -qO- http://loki:3100/ready

# Check Loki ingestion endpoint
kubectl exec -n observability deployment/loki -- curl http://localhost:3100/loki/api/v1/push
```

**Common Solutions:**

1. **Network Policy Issues:**
```bash
# Check network policies
kubectl get networkpolicies -n observability

# Temporarily disable network policies for testing
kubectl delete networkpolicy deny-all-default -n observability
```

2. **Service Discovery Issues:**
```bash
# Check service endpoints
kubectl get endpoints -n observability loki

# Check DNS resolution
kubectl exec -n observability deployment/alloy -- nslookup loki.observability.svc.cluster.local
```

3. **Configuration Issues:**
```bash
# Validate Alloy configuration
kubectl get configmap alloy-config -n observability -o yaml

# Check for syntax errors in Alloy config
kubectl exec -n observability -c alloy $(kubectl get pod -n observability -l app=alloy -o jsonpath='{.items[0].metadata.name}') -- /bin/alloy fmt --config.file=/etc/alloy/config.alloy
```

### 3. High Memory Usage / OOMKilled

**Symptoms:**
- Pods getting OOMKilled
- High memory consumption
- Slow query performance

**Debugging:**

```bash
# Check resource usage
kubectl top pods -n observability
kubectl top pods -n storage

# Check resource limits
kubectl describe pod -n observability -l app=loki

# Monitor memory usage over time
kubectl exec -n observability deployment/prometheus -- promtool query instant 'container_memory_usage_bytes{namespace="observability"}'
```

**Solutions:**

1. **Increase Memory Limits:**
```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

2. **Tune Loki Configuration:**
```yaml
limits_config:
  ingestion_rate_mb: 8  # Reduce from 16
  ingestion_burst_size_mb: 16  # Reduce from 32
  max_cache_freshness_per_query: 5m  # Reduce from 10m
  max_concurrent_tail_requests: 10  # Reduce from 20
```

3. **Enable Compression:**
```yaml
# In Loki config
chunk_store_config:
  chunk_cache_config:
    enable_fifocache: true
    fifocache:
      max_size_bytes: 1GB
```

### 4. Storage Issues

**Symptoms:**
- Disk full errors
- Cannot write to object storage
- Index corruption

**Debugging:**

```bash
# Check storage usage
kubectl exec -n observability deployment/loki -- df -h

# Check MinIO connectivity
kubectl exec -n observability deployment/loki -- wget -qO- http://minio.storage.svc.cluster.local:9000/minio/health/live

# Check PVC status
kubectl get pvc -n observability
kubectl get pvc -n storage
kubectl describe pvc loki-pvc -n observability
```

**Solutions:**

1. **Implement Retention Policies:**
```yaml
limits_config:
  retention_period: 168h  # 7 days instead of 31

table_manager:
  retention_deletes_enabled: true
  retention_period: 168h
```

2. **Add Storage Monitoring:**
```yaml
compactor:
  working_directory: /tmp/loki/boltdb-shipper-compactor
  shared_store: s3
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
```

3. **Expand Storage:**
```bash
# Increase PVC size (if storage class supports it)
kubectl patch pvc loki-pvc -n observability -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'
```

### 5. Grafana Connection Issues

**Symptoms:**
- Cannot connect to Loki data source
- "Bad Gateway" errors
- Slow dashboard loading

**Debugging:**

```bash
# Check Grafana logs
kubectl logs -n observability deployment/grafana

# Test connection from Grafana to Loki
kubectl exec -n observability deployment/grafana -- curl http://loki:3100/ready

# Check data source configuration
kubectl exec -n observability deployment/grafana -- cat /etc/grafana/provisioning/datasources/datasource.yaml
```

**Solutions:**

1. **Update Data Source URL:**
```yaml
# In grafana-datasources.yaml
datasources:
- name: Loki
  type: loki
  url: http://loki.observability.svc.cluster.local:3100  # Use FQDN
```

2. **Check Service Names:**
```bash
# Verify service exists and is accessible
kubectl get svc -n observability loki
kubectl describe svc -n observability loki
```

### 6. MinIO Connection Issues

**Symptoms:**
- Loki cannot write to object storage
- "connection refused" errors
- Index files not being uploaded

**Debugging:**

```bash
# Check MinIO status
kubectl logs -n storage deployment/minio

# Test MinIO connectivity
kubectl exec -n storage deployment/minio -- mc admin info local

# Check MinIO bucket
kubectl exec -n storage deployment/minio -- mc ls local/loki
```

**Solutions:**

1. **Recreate MinIO Bucket:**
```bash
kubectl exec -n storage deployment/minio -- mc alias set local http://localhost:9000 minioadmin minioadmin123
kubectl exec -n storage deployment/minio -- mc rb local/loki --force
kubectl exec -n storage deployment/minio -- mc mb local/loki
```

2. **Update MinIO Configuration:**
```yaml
# In loki-config.yaml
storage_config:
  aws:
    s3: http://minio.storage.svc.cluster.local:9000/loki  # Use FQDN
    access_key_id: minioadmin
    secret_access_key: minioadmin123
    s3forcepathstyle: true
    insecure: true
```

## Performance Tuning

### Loki Performance

1. **Query Performance:**
```yaml
limits_config:
  split_queries_by_interval: 15m
  max_query_parallelism: 32
  max_query_series: 10000
```

2. **Ingestion Performance:**
```yaml
limits_config:
  ingestion_rate_mb: 16
  ingestion_burst_size_mb: 32
  max_concurrent_tail_requests: 20
```

3. **Storage Performance:**
```yaml
storage_config:
  boltdb_shipper:
    cache_ttl: 24h
    cache_location: /tmp/loki/boltdb-shipper-cache
```

### Grafana Performance

1. **Query Caching:**
```ini
[caching]
enabled = true

[query_caching]
enabled = true
```

2. **Database Optimization:**
```ini
[database]
max_open_conn = 300
max_idle_conn = 16
conn_max_lifetime = 14400
```

## Health Checks

### Manual Health Checks

```bash
# Loki health
kubectl exec -n observability deployment/loki -- wget -qO- http://localhost:3100/ready

# Grafana health  
kubectl exec -n observability deployment/grafana -- wget -qO- http://localhost:3000/api/health

# MinIO health
kubectl exec -n storage deployment/minio -- wget -qO- http://localhost:9000/minio/health/live

# Alloy health
kubectl exec -n observability daemonset/alloy -- wget -qO- http://localhost:12345/-/ready
```

### Automated Health Monitoring

```yaml
# Add to monitoring/health-check-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: health-check
  namespace: observability
spec:
  schedule: "*/5 * * * *"  # Every 5 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: health-check
            image: curlimages/curl:latest
            command:
            - /bin/sh
            - -c
            - |
              # Check all services and report status
              curl -f http://loki:3100/ready || echo "Loki unhealthy"
              curl -f http://grafana:3000/api/health || echo "Grafana unhealthy"
          restartPolicy: OnFailure
```

## Log Analysis

### Useful Log Queries

1. **Find Error Logs:**
```logql
{level="error"} |= ""
```

2. **High Frequency Errors:**
```logql
sum(rate({level="error"}[5m])) by (namespace, pod)
```

3. **Container Restart Events:**
```logql
{namespace="observability"} |= "restarted"
```

4. **Network Issues:**
```logql
{} |~ "connection refused|timeout|network"
```

### Performance Queries

1. **Log Ingestion Rate:**
```promql
rate(loki_distributor_lines_received_total[5m])
```

2. **Query Performance:**
```promql
histogram_quantile(0.99, rate(loki_request_duration_seconds_bucket[5m]))
```

3. **Storage Usage:**
```promql
loki_store_index_entries_per_chunk
```

## Emergency Procedures

### Complete Stack Restart

```bash
# Scale down all deployments
kubectl scale deployment --all --replicas=0 -n observability
kubectl scale deployment --all --replicas=0 -n storage

# Wait for pods to terminate
kubectl wait --for=delete pod --all -n observability --timeout=300s
kubectl wait --for=delete pod --all -n storage --timeout=300s

# Scale back up
kubectl scale deployment loki --replicas=1 -n observability
kubectl scale deployment grafana --replicas=1 -n observability
kubectl scale deployment minio --replicas=1 -n storage

# Restart DaemonSet
kubectl rollout restart daemonset/alloy -n observability
```

### Data Recovery

1. **Backup Grafana Dashboards:**
```bash
kubectl exec -n observability deployment/grafana -- curl -u admin:admin123 http://localhost:3000/api/search > dashboards-backup.json
```

2. **Export Loki Index:**
```bash
kubectl exec -n observability deployment/loki -- ls -la /tmp/loki/boltdb-shipper-active/
```

3. **MinIO Data Backup:**
```bash
kubectl exec -n storage deployment/minio -- mc mirror local/loki /backup/loki-data/
```

## Getting Help

### Collect Diagnostic Information

Use the provided script:
```bash
./09-scripts/collect-logs.sh
```

### Community Resources

- Grafana Community Forum: https://community.grafana.com/
- Loki GitHub Issues: https://github.com/grafana/loki/issues
- Kubernetes Slack: #kubernetes-users

### Professional Support

- Grafana Enterprise Support
- Platform-specific support (EKS, GKE, AKS)
- Kubernetes vendor support