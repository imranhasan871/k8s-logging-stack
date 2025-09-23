#!/bin/bash
# status-check.sh - Check status of observability stack

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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🔍 Observability Stack Status Check"
echo "===================================="
echo ""

# Check if namespaces exist
print_status "Checking namespaces..."
if kubectl get namespace observability >/dev/null 2>&1; then
    print_success "observability namespace exists"
else
    print_error "observability namespace not found"
fi

if kubectl get namespace storage >/dev/null 2>&1; then
    print_success "storage namespace exists"
else
    print_error "storage namespace not found"
fi

echo ""

# Check pods in observability namespace
print_status "Pods in observability namespace:"
kubectl get pods -n observability -o wide 2>/dev/null || print_error "Failed to get pods in observability namespace"

echo ""

# Check pods in storage namespace
print_status "Pods in storage namespace:"
kubectl get pods -n storage -o wide 2>/dev/null || print_error "Failed to get pods in storage namespace"

echo ""

# Check services
print_status "Services in observability namespace:"
kubectl get svc -n observability 2>/dev/null || print_error "Failed to get services in observability namespace"

echo ""

print_status "Services in storage namespace:"
kubectl get svc -n storage 2>/dev/null || print_error "Failed to get services in storage namespace"

echo ""

# Check persistent volumes
print_status "Persistent Volume Claims:"
kubectl get pvc -n observability 2>/dev/null || print_warning "No PVCs in observability namespace"
kubectl get pvc -n storage 2>/dev/null || print_warning "No PVCs in storage namespace"

echo ""

# Check ingress
print_status "Ingress resources:"
kubectl get ingress -n observability 2>/dev/null || print_warning "No ingress resources found"

echo ""

# Health checks
print_status "Health checks:"

# Check Loki
if kubectl get pod -n observability -l app=loki >/dev/null 2>&1; then
    LOKI_POD=$(kubectl get pod -n observability -l app=loki -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ ! -z "$LOKI_POD" ]; then
        if kubectl exec -n observability $LOKI_POD -- wget -qO- http://localhost:3100/ready >/dev/null 2>&1; then
            print_success "Loki is healthy"
        else
            print_error "Loki health check failed"
        fi
    fi
fi

# Check Grafana
if kubectl get pod -n observability -l app=grafana >/dev/null 2>&1; then
    GRAFANA_POD=$(kubectl get pod -n observability -l app=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ ! -z "$GRAFANA_POD" ]; then
        if kubectl exec -n observability $GRAFANA_POD -- wget -qO- http://localhost:3000/api/health >/dev/null 2>&1; then
            print_success "Grafana is healthy"
        else
            print_error "Grafana health check failed"
        fi
    fi
fi

# Check MinIO
if kubectl get pod -n storage -l app=minio >/dev/null 2>&1; then
    MINIO_POD=$(kubectl get pod -n storage -l app=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ ! -z "$MINIO_POD" ]; then
        if kubectl exec -n storage $MINIO_POD -- wget -qO- http://localhost:9000/minio/health/live >/dev/null 2>&1; then
            print_success "MinIO is healthy"
        else
            print_error "MinIO health check failed"
        fi
    fi
fi

echo ""

# Resource usage
print_status "Resource usage:"
echo "CPU and Memory usage by namespace:"
kubectl top pods -n observability 2>/dev/null || print_warning "Metrics server not available for resource usage"
kubectl top pods -n storage 2>/dev/null || print_warning "Metrics server not available for resource usage"

echo ""

# Recent events
print_status "Recent events (last 10):"
kubectl get events -n observability --sort-by=.metadata.creationTimestamp | tail -10 2>/dev/null || print_warning "No events found"

echo ""
print_status "Status check completed!"
echo ""
print_status "Quick access commands:"
echo "📊 Port forward Grafana:    kubectl port-forward -n observability svc/grafana 3000:3000"
echo "💾 Port forward MinIO:      kubectl port-forward -n storage svc/minio 9001:9001"
echo "📋 Check Loki logs:         kubectl logs -n observability deployment/loki"
echo "🔍 Check Alloy logs:        kubectl logs -n observability daemonset/alloy"