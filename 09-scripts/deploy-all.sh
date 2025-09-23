#!/bin/bash
# deploy-all.sh - Complete observability stack deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}
    
    print_status "Waiting for $deployment in namespace $namespace to be ready..."
    if kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $namespace; then
        print_success "$deployment is ready"
    else
        print_error "$deployment failed to become ready within ${timeout}s"
        return 1
    fi
}

# Function to wait for daemonset
wait_for_daemonset() {
    local namespace=$1
    local daemonset=$2
    local timeout=${3:-300}
    
    print_status "Waiting for $daemonset in namespace $namespace to be ready..."
    kubectl rollout status daemonset/$daemonset -n $namespace --timeout=${timeout}s
    if [ $? -eq 0 ]; then
        print_success "$daemonset is ready"
    else
        print_error "$daemonset failed to become ready within ${timeout}s"
        return 1
    fi
}

echo "🚀 Deploying Complete Observability Stack..."
echo "============================================="

# Step 1: Create namespaces
print_status "Creating namespaces..."
kubectl apply -f 01-namespaces/
print_success "Namespaces created"

# Step 2: Setup RBAC
print_status "Setting up RBAC..."
kubectl apply -f 02-rbac/
print_success "RBAC configured"

# Step 3: Deploy MinIO storage
print_status "Deploying MinIO storage..."
kubectl apply -f 03-storage/
wait_for_deployment "storage" "minio"

# Create MinIO bucket for Loki
print_status "Creating Loki bucket in MinIO..."
sleep 10  # Wait a bit for MinIO to fully start
if kubectl exec -n storage deployment/minio -- mc alias set local http://localhost:9000 minioadmin minioadmin123; then
    kubectl exec -n storage deployment/minio -- mc mb local/loki || print_warning "Bucket might already exist"
    print_success "MinIO bucket created"
else
    print_warning "Failed to create MinIO bucket - will retry later"
fi

# Step 4: Deploy Loki
print_status "Deploying Loki..."
kubectl apply -f 04-loki/
wait_for_deployment "observability" "loki"

# Step 5: Deploy Grafana Alloy
print_status "Deploying Grafana Alloy..."
kubectl apply -f 05-alloy/
wait_for_daemonset "observability" "alloy"

# Step 6: Deploy Grafana
print_status "Deploying Grafana..."
kubectl apply -f 06-grafana/
wait_for_deployment "observability" "grafana"

# Step 7: Deploy monitoring (optional)
print_status "Deploying monitoring components..."
kubectl apply -f 07-monitoring/
wait_for_deployment "observability" "prometheus"
wait_for_deployment "observability" "alertmanager"

# Step 8: Apply security policies
print_status "Applying security policies..."
kubectl apply -f 08-security/
print_success "Security policies applied"

# Final status check
echo ""
echo "🔍 Final Status Check..."
echo "========================"

print_status "Checking pod status in observability namespace:"
kubectl get pods -n observability

print_status "Checking pod status in storage namespace:"
kubectl get pods -n storage

print_status "Checking services:"
kubectl get svc -n observability
kubectl get svc -n storage

echo ""
print_success "✅ Observability stack deployed successfully!"
echo ""
echo "🌐 Access Information:"
echo "======================"
echo "📊 Grafana:           http://grafana.local (admin/admin123)"
echo "💾 MinIO Console:     http://minio.local:9001 (minioadmin/minioadmin123)"
echo "🔍 Prometheus:        http://prometheus.local:9090"
echo "🚨 AlertManager:      http://alertmanager.local:9093"
echo ""
echo "🔧 Add to /etc/hosts:"
echo "echo '127.0.0.1 grafana.local minio.local prometheus.local alertmanager.local' | sudo tee -a /etc/hosts"
echo ""
echo "📋 Useful commands:"
echo "kubectl get pods -n observability"
echo "kubectl logs -n observability deployment/loki"
echo "kubectl logs -n observability daemonset/alloy"
echo "kubectl port-forward -n observability svc/grafana 3000:3000"
echo ""
echo "📖 For troubleshooting, check the logs and documentation in 10-docs/"