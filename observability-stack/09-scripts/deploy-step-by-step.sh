#!/bin/bash
# deploy-step-by-step.sh - Interactive step-by-step deployment

set -e

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

# Function to wait for user confirmation
wait_for_user() {
    echo ""
    read -p "Press [Enter] to continue or [Ctrl+C] to exit..."
    echo ""
}

# Function to show pod status
show_status() {
    local namespace=$1
    echo ""
    print_status "Current status in namespace $namespace:"
    kubectl get pods -n $namespace 2>/dev/null || echo "Namespace not found or no pods"
    echo ""
}

echo "🚀 Step-by-Step Observability Stack Deployment"
echo "==============================================="
echo ""
echo "This script will deploy the observability stack step by step."
echo "You can review each step before proceeding."
echo ""

# Step 1: Namespaces
echo "📁 Step 1: Creating Namespaces"
echo "================================"
echo "This will create the 'observability' and 'storage' namespaces."
wait_for_user

kubectl apply -f 01-namespaces/
print_success "Namespaces created"
kubectl get namespaces | grep -E "(observability|storage)"

# Step 2: RBAC
echo ""
echo "🔐 Step 2: Setting up RBAC"
echo "==========================="
echo "This will create service accounts, roles, and role bindings."
wait_for_user

kubectl apply -f 02-rbac/
print_success "RBAC configured"
kubectl get serviceaccount -n observability

# Step 3: Storage
echo ""
echo "💾 Step 3: Deploying MinIO Storage"
echo "==================================="
echo "This will deploy MinIO for object storage used by Loki."
wait_for_user

kubectl apply -f 03-storage/
print_status "Waiting for MinIO to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/minio -n storage
print_success "MinIO deployed successfully"
show_status "storage"

# Create bucket
print_status "Creating Loki bucket in MinIO..."
sleep 10
kubectl exec -n storage deployment/minio -- mc alias set local http://localhost:9000 minioadmin minioadmin123
kubectl exec -n storage deployment/minio -- mc mb local/loki || print_warning "Bucket might already exist"

# Step 4: Loki
echo ""
echo "📊 Step 4: Deploying Loki"
echo "=========================="
echo "This will deploy Loki for log aggregation."
wait_for_user

kubectl apply -f 04-loki/
print_status "Waiting for Loki to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/loki -n observability
print_success "Loki deployed successfully"
show_status "observability"

# Step 5: Alloy
echo ""
echo "🔍 Step 5: Deploying Grafana Alloy"
echo "==================================="
echo "This will deploy Grafana Alloy as a DaemonSet for log collection."
wait_for_user

kubectl apply -f 05-alloy/
print_status "Waiting for Alloy to be ready..."
kubectl rollout status daemonset/alloy -n observability --timeout=300s
print_success "Grafana Alloy deployed successfully"
show_status "observability"

# Step 6: Grafana
echo ""
echo "📈 Step 6: Deploying Grafana"
echo "============================="
echo "This will deploy Grafana with pre-configured dashboards and data sources."
wait_for_user

kubectl apply -f 06-grafana/
print_status "Waiting for Grafana to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n observability
print_success "Grafana deployed successfully"
show_status "observability"

# Step 7: Monitoring (Optional)
echo ""
echo "🚨 Step 7: Deploying Monitoring (Optional)"
echo "==========================================="
echo "This will deploy Prometheus and AlertManager for metrics and alerting."
echo "This step is optional but recommended for production."
read -p "Do you want to deploy monitoring components? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl apply -f 07-monitoring/
    print_status "Waiting for Prometheus to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n observability
    print_status "Waiting for AlertManager to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/alertmanager -n observability
    print_success "Monitoring components deployed successfully"
else
    print_warning "Skipping monitoring components"
fi

# Step 8: Security
echo ""
echo "🔒 Step 8: Applying Security Policies"
echo "======================================"
echo "This will apply network policies, resource quotas, and security policies."
wait_for_user

kubectl apply -f 08-security/
print_success "Security policies applied"

# Final status
echo ""
echo "🔍 Final Deployment Status"
echo "==========================="
show_status "observability"
show_status "storage"

echo ""
print_success "✅ Step-by-step deployment completed!"
echo ""
echo "🌐 Access Information:"
echo "======================"
echo "📊 Grafana:           http://grafana.local (admin/admin123)"
echo "💾 MinIO Console:     http://minio.local:9001 (minioadmin/minioadmin123)"
echo "🔍 Prometheus:        http://prometheus.local:9090 (if deployed)"
echo "🚨 AlertManager:      http://alertmanager.local:9093 (if deployed)"
echo ""
echo "🔧 Port forwarding commands:"
echo "kubectl port-forward -n observability svc/grafana 3000:3000"
echo "kubectl port-forward -n storage svc/minio 9001:9001"
echo ""
echo "📖 Check the documentation in 10-docs/ for more information."