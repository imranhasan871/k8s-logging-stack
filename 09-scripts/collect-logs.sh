#!/bin/bash
# collect-logs.sh - Collect logs for troubleshooting

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create logs directory with timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_DIR="observability-logs-$TIMESTAMP"
mkdir -p $LOG_DIR

echo "📋 Collecting Observability Stack Logs"
echo "======================================="
echo "Logs will be saved to: $LOG_DIR"
echo ""

# System information
print_status "Collecting system information..."
{
    echo "=== Kubernetes Version ==="
    kubectl version --short
    echo ""
    echo "=== Cluster Info ==="
    kubectl cluster-info
    echo ""
    echo "=== Nodes ==="
    kubectl get nodes -o wide
} > "$LOG_DIR/system-info.txt"

# Namespace information
print_status "Collecting namespace information..."
{
    echo "=== All Namespaces ==="
    kubectl get namespaces
    echo ""
    echo "=== Observability Namespace Details ==="
    kubectl describe namespace observability
    echo ""
    echo "=== Storage Namespace Details ==="
    kubectl describe namespace storage
} > "$LOG_DIR/namespace-info.txt"

# Pod information
print_status "Collecting pod information..."
{
    echo "=== Pods in observability namespace ==="
    kubectl get pods -n observability -o wide
    echo ""
    echo "=== Pods in storage namespace ==="
    kubectl get pods -n storage -o wide
    echo ""
    echo "=== Pod descriptions - observability ==="
    kubectl describe pods -n observability
    echo ""
    echo "=== Pod descriptions - storage ==="
    kubectl describe pods -n storage
} > "$LOG_DIR/pod-info.txt"

# Service information
print_status "Collecting service information..."
{
    echo "=== Services in observability namespace ==="
    kubectl get svc -n observability -o wide
    echo ""
    echo "=== Services in storage namespace ==="
    kubectl get svc -n storage -o wide
    echo ""
    echo "=== Endpoints in observability namespace ==="
    kubectl get endpoints -n observability
    echo ""
    echo "=== Endpoints in storage namespace ==="
    kubectl get endpoints -n storage
} > "$LOG_DIR/service-info.txt"

# ConfigMap and Secret information
print_status "Collecting configuration information..."
{
    echo "=== ConfigMaps in observability namespace ==="
    kubectl get configmaps -n observability
    echo ""
    echo "=== Secrets in observability namespace ==="
    kubectl get secrets -n observability
    echo ""
    echo "=== PersistentVolumeClaims ==="
    kubectl get pvc -n observability
    kubectl get pvc -n storage
} > "$LOG_DIR/config-info.txt"

# Events
print_status "Collecting events..."
{
    echo "=== Events in observability namespace ==="
    kubectl get events -n observability --sort-by=.metadata.creationTimestamp
    echo ""
    echo "=== Events in storage namespace ==="
    kubectl get events -n storage --sort-by=.metadata.creationTimestamp
} > "$LOG_DIR/events.txt"

# Pod logs
print_status "Collecting pod logs..."

# Loki logs
if kubectl get pods -n observability -l app=loki >/dev/null 2>&1; then
    print_status "Collecting Loki logs..."
    kubectl logs -n observability deployment/loki --tail=1000 > "$LOG_DIR/loki-logs.txt" 2>&1
fi

# Grafana logs
if kubectl get pods -n observability -l app=grafana >/dev/null 2>&1; then
    print_status "Collecting Grafana logs..."
    kubectl logs -n observability deployment/grafana --tail=1000 > "$LOG_DIR/grafana-logs.txt" 2>&1
fi

# Alloy logs
if kubectl get pods -n observability -l app=alloy >/dev/null 2>&1; then
    print_status "Collecting Alloy logs..."
    kubectl logs -n observability daemonset/alloy --tail=1000 > "$LOG_DIR/alloy-logs.txt" 2>&1
fi

# MinIO logs
if kubectl get pods -n storage -l app=minio >/dev/null 2>&1; then
    print_status "Collecting MinIO logs..."
    kubectl logs -n storage deployment/minio --tail=1000 > "$LOG_DIR/minio-logs.txt" 2>&1
fi

# Prometheus logs (if exists)
if kubectl get pods -n observability -l app=prometheus >/dev/null 2>&1; then
    print_status "Collecting Prometheus logs..."
    kubectl logs -n observability deployment/prometheus --tail=1000 > "$LOG_DIR/prometheus-logs.txt" 2>&1
fi

# AlertManager logs (if exists)
if kubectl get pods -n observability -l app=alertmanager >/dev/null 2>&1; then
    print_status "Collecting AlertManager logs..."
    kubectl logs -n observability deployment/alertmanager --tail=1000 > "$LOG_DIR/alertmanager-logs.txt" 2>&1
fi

# Resource usage (if metrics server is available)
print_status "Collecting resource usage..."
{
    echo "=== Node resource usage ==="
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo ""
    echo "=== Pod resource usage - observability ==="
    kubectl top pods -n observability 2>/dev/null || echo "Metrics server not available"
    echo ""
    echo "=== Pod resource usage - storage ==="
    kubectl top pods -n storage 2>/dev/null || echo "Metrics server not available"
} > "$LOG_DIR/resource-usage.txt"

# Network policies
print_status "Collecting network policies..."
{
    echo "=== Network Policies ==="
    kubectl get networkpolicies -n observability -o yaml
} > "$LOG_DIR/network-policies.txt" 2>&1

# Create summary
print_status "Creating summary..."
{
    echo "=== Observability Stack Log Collection Summary ==="
    echo "Collection Date: $(date)"
    echo "Kubernetes Version: $(kubectl version --short --client)"
    echo ""
    echo "=== Quick Status ==="
    echo "Observability Pods:"
    kubectl get pods -n observability --no-headers 2>/dev/null | awk '{print $1 ": " $3}' || echo "Failed to get pods"
    echo ""
    echo "Storage Pods:"
    kubectl get pods -n storage --no-headers 2>/dev/null | awk '{print $1 ": " $3}' || echo "Failed to get pods"
    echo ""
    echo "=== Files Collected ==="
    ls -la "$LOG_DIR"
} > "$LOG_DIR/README.txt"

# Create archive
print_status "Creating archive..."
tar -czf "${LOG_DIR}.tar.gz" "$LOG_DIR"

echo ""
print_success "✅ Log collection completed!"
echo ""
print_status "Files created:"
echo "📁 Directory: $LOG_DIR"
echo "📦 Archive:   ${LOG_DIR}.tar.gz"
echo ""
print_status "Contents:"
ls -la "$LOG_DIR"
echo ""
print_status "You can share the ${LOG_DIR}.tar.gz file for troubleshooting."