#!/bin/bash
# port-forward.sh - Easy port forwarding for observability services

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

# Function to check if service exists
check_service() {
    local namespace=$1
    local service=$2
    if kubectl get svc "$service" -n "$namespace" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to start port forward in background
start_port_forward() {
    local namespace=$1
    local service=$2
    local local_port=$3
    local remote_port=$4
    local name=$5
    
    if check_service "$namespace" "$service"; then
        print_status "Starting port forward for $name..."
        kubectl port-forward -n "$namespace" svc/"$service" "$local_port:$remote_port" >/dev/null 2>&1 &
        local pid=$!
        echo "$pid" > "/tmp/port-forward-$name.pid"
        sleep 2
        if kill -0 "$pid" 2>/dev/null; then
            print_success "$name available at http://localhost:$local_port (PID: $pid)"
        else
            print_error "Failed to start port forward for $name"
        fi
    else
        print_warning "Service $service not found in namespace $namespace"
    fi
}

# Function to stop all port forwards
stop_all() {
    print_status "Stopping all port forwards..."
    for pidfile in /tmp/port-forward-*.pid; do
        if [ -f "$pidfile" ]; then
            local pid=$(cat "$pidfile")
            local name=$(basename "$pidfile" .pid | sed 's/port-forward-//')
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid"
                print_success "Stopped port forward for $name"
            fi
            rm -f "$pidfile"
        fi
    done
}

# Function to show status
show_status() {
    print_status "Active port forwards:"
    local found=false
    for pidfile in /tmp/port-forward-*.pid; do
        if [ -f "$pidfile" ]; then
            local pid=$(cat "$pidfile")
            local name=$(basename "$pidfile" .pid | sed 's/port-forward-//')
            if kill -0 "$pid" 2>/dev/null; then
                echo "  $name (PID: $pid)"
                found=true
            else
                rm -f "$pidfile"
            fi
        fi
    done
    if [ "$found" = false ]; then
        echo "  No active port forwards"
    fi
}

# Main script
echo "🔗 Observability Stack Port Forwarding"
echo "======================================="
echo ""

case "${1:-start}" in
    "start")
        print_status "Starting port forwards for all services..."
        echo ""
        
        # Grafana
        start_port_forward "observability" "grafana" "3000" "3000" "grafana"
        
        # MinIO Console
        start_port_forward "storage" "minio" "9001" "9001" "minio-console"
        
        # MinIO API
        start_port_forward "storage" "minio" "9000" "9000" "minio-api"
        
        # Prometheus (if exists)
        start_port_forward "observability" "prometheus" "9090" "9090" "prometheus"
        
        # AlertManager (if exists)
        start_port_forward "observability" "alertmanager" "9093" "9093" "alertmanager"
        
        # Loki (for direct access)
        start_port_forward "observability" "loki" "3100" "3100" "loki"
        
        # Alloy (for metrics)
        start_port_forward "observability" "alloy" "12345" "12345" "alloy"
        
        echo ""
        print_success "Port forwarding setup complete!"
        echo ""
        print_status "Available services:"
        echo "📊 Grafana:           http://localhost:3000 (admin/admin123)"
        echo "💾 MinIO Console:     http://localhost:9001 (minioadmin/minioadmin123)"
        echo "💾 MinIO API:         http://localhost:9000"
        echo "🔍 Prometheus:        http://localhost:9090"
        echo "🚨 AlertManager:      http://localhost:9093"
        echo "📊 Loki:              http://localhost:3100"
        echo "🔍 Alloy:             http://localhost:12345"
        echo ""
        print_warning "Port forwards are running in the background."
        print_status "Use '$0 stop' to stop all port forwards."
        print_status "Use '$0 status' to check active port forwards."
        ;;
        
    "stop")
        stop_all
        ;;
        
    "status")
        show_status
        ;;
        
    "restart")
        print_status "Restarting all port forwards..."
        stop_all
        sleep 2
        "$0" start
        ;;
        
    "grafana")
        start_port_forward "observability" "grafana" "3000" "3000" "grafana"
        print_status "Grafana available at http://localhost:3000"
        ;;
        
    "minio")
        start_port_forward "storage" "minio" "9001" "9001" "minio-console"
        start_port_forward "storage" "minio" "9000" "9000" "minio-api"
        print_status "MinIO Console available at http://localhost:9001"
        print_status "MinIO API available at http://localhost:9000"
        ;;
        
    "prometheus")
        start_port_forward "observability" "prometheus" "9090" "9090" "prometheus"
        print_status "Prometheus available at http://localhost:9090"
        ;;
        
    "help"|"-h"|"--help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  start       Start port forwards for all services (default)"
        echo "  stop        Stop all port forwards"
        echo "  status      Show active port forwards"
        echo "  restart     Restart all port forwards"
        echo "  grafana     Start only Grafana port forward"
        echo "  minio       Start only MinIO port forwards"
        echo "  prometheus  Start only Prometheus port forward"
        echo "  help        Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                 # Start all port forwards"
        echo "  $0 grafana         # Start only Grafana"
        echo "  $0 stop            # Stop all port forwards"
        ;;
        
    *)
        print_error "Unknown command: $1"
        print_status "Use '$0 help' for usage information."
        exit 1
        ;;
esac