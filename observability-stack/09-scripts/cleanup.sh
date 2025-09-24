#!/bin/bash
# cleanup.sh - Complete cleanup of observability stack

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

echo "🗑️  Cleaning up Observability Stack"
echo "====================================="
echo ""
print_warning "This will delete ALL observability stack resources!"
echo ""
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Cleanup cancelled"
    exit 0
fi

echo ""
print_status "Starting cleanup process..."

# Delete in reverse order of deployment
print_status "Removing security policies..."
kubectl delete -f 08-security/ --ignore-not-found=true

print_status "Removing monitoring components..."
kubectl delete -f 07-monitoring/ --ignore-not-found=true

print_status "Removing Grafana..."
kubectl delete -f 06-grafana/ --ignore-not-found=true

print_status "Removing Grafana Alloy..."
kubectl delete -f 05-alloy/ --ignore-not-found=true

print_status "Removing Loki..."
kubectl delete -f 04-loki/ --ignore-not-found=true

print_status "Removing MinIO storage..."
kubectl delete -f 03-storage/ --ignore-not-found=true

print_status "Removing RBAC..."
kubectl delete -f 02-rbac/ --ignore-not-found=true

# Option to delete namespaces
echo ""
read -p "Do you want to delete the namespaces (this will force delete any remaining resources)? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Deleting namespaces..."
    kubectl delete namespace observability --ignore-not-found=true
    kubectl delete namespace storage --ignore-not-found=true
    print_success "Namespaces deleted"
else
    print_warning "Namespaces preserved"
fi

echo ""
print_success "✅ Cleanup completed!"
echo ""
print_status "Remaining resources (if any):"
kubectl get pods -n observability 2>/dev/null || echo "No pods in observability namespace"
kubectl get pods -n storage 2>/dev/null || echo "No pods in storage namespace"