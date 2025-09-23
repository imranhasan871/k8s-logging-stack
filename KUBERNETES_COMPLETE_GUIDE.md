# Kubernetes Complete Guide: A to Z Documentation

## Table of Contents

### Part I: Fundamentals
1. [Introduction to Kubernetes](#1-introduction-to-kubernetes)
2. [Kubernetes Architecture](#2-kubernetes-architecture)
3. [Core Components](#3-core-components)
4. [Installation and Setup](#4-installation-and-setup)

### Part II: Core Concepts
5. [Pods](#5-pods)
6. [Services](#6-services)
7. [Deployments](#7-deployments)
8. [ReplicaSets](#8-replicasets)
9. [ConfigMaps and Secrets](#9-configmaps-and-secrets)
10. [Namespaces](#10-namespaces)

### Part III: Advanced Concepts
11. [Networking](#11-networking)
12. [Storage and Persistent Volumes](#12-storage-and-persistent-volumes)
13. [Security and RBAC](#13-security-and-rbac)
14. [Resource Management](#14-resource-management)
15. [Scheduling](#15-scheduling)

### Part IV: Production Operations
16. [Monitoring and Observability](#16-monitoring-and-observability)
17. [Logging](#17-logging)
18. [Backup and Disaster Recovery](#18-backup-and-disaster-recovery)
19. [CI/CD Integration](#19-cicd-integration)
20. [Production Best Practices](#20-production-best-practices)

### Part V: Troubleshooting and Maintenance
21. [Troubleshooting Guide](#21-troubleshooting-guide)
22. [Performance Tuning](#22-performance-tuning)
23. [Upgrades and Maintenance](#23-upgrades-and-maintenance)

### Part VI: Practical Examples
24. [Real-World Scenarios](#24-real-world-scenarios)
25. [Complete Application Deployment](#25-complete-application-deployment)
26. [Migration Strategies](#26-migration-strategies)

---

## 1. Introduction to Kubernetes

### What is Kubernetes?
Kubernetes (K8s) is an open-source container orchestration platform that automates the deployment, scaling, and management of containerized applications. Originally developed by Google, it's now maintained by the Cloud Native Computing Foundation (CNCF).

### Why Kubernetes?
- **Container Orchestration**: Manages containers across multiple hosts
- **Self-Healing**: Automatically restarts failed containers
- **Horizontal Scaling**: Scales applications up or down based on demand
- **Service Discovery**: Automatically discovers and routes traffic to services
- **Rolling Updates**: Deploy updates without downtime
- **Resource Management**: Efficiently allocates compute resources

### Key Benefits
1. **Portability**: Run anywhere (on-premises, cloud, hybrid)
2. **Scalability**: Handle millions of requests
3. **Reliability**: High availability and fault tolerance
4. **Efficiency**: Optimal resource utilization
5. **Developer Productivity**: Focus on code, not infrastructure

---

## 2. Kubernetes Architecture

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                       │
├─────────────────────────────────────────────────────────────┤
│  Control Plane (Master Node)                               │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐    │
│  │   API       │ │    etcd     │ │    Scheduler        │    │
│  │   Server    │ │  (Database) │ │                     │    │
│  └─────────────┘ └─────────────┘ └─────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │         Controller Manager                          │    │
│  └─────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────┤
│  Worker Nodes                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Node 1                                             │    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────────────────┐    │    │
│  │  │ kubelet │ │ kube-   │ │    Container        │    │    │
│  │  │         │ │ proxy   │ │    Runtime          │    │    │
│  │  └─────────┘ └─────────┘ └─────────────────────┘    │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │             Pods                            │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Node 2                                             │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Node N                                             │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Control Plane Components

#### API Server
- Entry point for all REST commands
- Validates and configures data for API objects
- Serves the Kubernetes API

#### etcd
- Distributed key-value store
- Stores all cluster data
- Backup and restore critical for disaster recovery

#### Scheduler
- Assigns pods to nodes
- Considers resource requirements, constraints, and policies

#### Controller Manager
- Runs controller processes
- Includes Node Controller, Replication Controller, etc.

### Worker Node Components

#### kubelet
- Primary node agent
- Communicates with API server
- Manages pod lifecycle

#### kube-proxy
- Network proxy
- Maintains network rules
- Enables communication between services

#### Container Runtime
- Runs containers (Docker, containerd, CRI-O)
- Pulls images and manages container lifecycle

---

## 3. Core Components

### Pod Lifecycle Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Pending   │───▶│   Running   │───▶│  Succeeded  │    │   Failed    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                  │                                      ▲
       │                  └──────────────────────────────────────┘
       │                            Failed
       └─────────────────────────────────────────────────────────┘
                            Failed
```

### Service Types Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Service Types                            │
├─────────────────────────────────────────────────────────────┤
│  ClusterIP (Default)                                        │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │    Pod 1    │    │    Pod 2    │    │    Pod 3    │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│         │                   │                   │           │
│         └───────────────────┼───────────────────┘           │
│                             │                               │
│                    ┌─────────────┐                          │
│                    │ ClusterIP   │                          │
│                    │ Service     │                          │
│                    └─────────────┘                          │
├─────────────────────────────────────────────────────────────┤
│  NodePort                                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                 Node                                │    │
│  │  ┌─────────────┐              ┌─────────────┐       │    │
│  │  │   NodePort  │──────────────│   Service   │       │    │
│  │  │  :30080     │              │             │       │    │
│  │  └─────────────┘              └─────────────┘       │    │
│  └─────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────┤
│  LoadBalancer                                               │
│  ┌─────────────┐                                            │
│  │   External  │                                            │
│  │   Load      │                                            │
│  │   Balancer  │                                            │
│  └─────────────┘                                            │
│         │                                                   │
│         ▼                                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                 Cluster                             │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Installation and Setup

### Prerequisites
- Linux/macOS/Windows machine
- 2 GB or more of RAM
- 2 CPUs or more
- Full network connectivity
- Unique hostname, MAC address, and product_uuid for every node

### Installation Options

#### Option 1: Minikube (Local Development)

```bash
# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start Minikube
minikube start

# Enable addons
minikube addons enable ingress
minikube addons enable dashboard
```

#### Option 2: kubeadm (Production Cluster)

```bash
# Install Docker
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

# Install kubeadm, kubelet, kubectl
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Initialize cluster (Master node)
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# Configure kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install network plugin (Calico)
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

#### Option 3: Managed Kubernetes Services

##### Amazon EKS
```bash
# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Create cluster
eksctl create cluster --name my-cluster --region us-west-2 --nodegroup-name my-nodes --node-type t3.medium --nodes 3
```

##### Google GKE
```bash
# Install gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Create cluster
gcloud container clusters create my-cluster --zone us-central1-a --num-nodes 3
gcloud container clusters get-credentials my-cluster --zone us-central1-a
```

##### Azure AKS
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Create cluster
az group create --name myResourceGroup --location eastus
az aks create --resource-group myResourceGroup --name myAKSCluster --node-count 3 --enable-addons monitoring --generate-ssh-keys
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

### Verification Commands

```bash
# Check cluster info
kubectl cluster-info

# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Check cluster components
kubectl get componentstatuses
```

---

## 5. Pods

### What is a Pod?
A Pod is the smallest deployable unit in Kubernetes that contains one or more containers sharing storage and network.

### Pod Anatomy Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         Pod                                 │
├─────────────────────────────────────────────────────────────┤
│  Shared Network (IP Address)                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                 Container 1                         │    │
│  │  ┌─────────────┐  ┌─────────────┐                  │    │
│  │  │   App       │  │   Volume    │                  │    │
│  │  │ Container   │  │   Mount     │                  │    │
│  │  └─────────────┘  └─────────────┘                  │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                 Container 2                         │    │
│  │  ┌─────────────┐  ┌─────────────┐                  │    │
│  │  │  Sidecar    │  │   Volume    │                  │    │
│  │  │ Container   │  │   Mount     │                  │    │
│  │  └─────────────┘  └─────────────┘                  │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Shared Volumes                         │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Basic Pod YAML

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
    environment: production
spec:
  containers:
  - name: nginx
    image: nginx:1.21
    ports:
    - containerPort: 80
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
    env:
    - name: ENVIRONMENT
      value: "production"
    volumeMounts:
    - name: html-volume
      mountPath: /usr/share/nginx/html
  volumes:
  - name: html-volume
    configMap:
      name: nginx-config
  restartPolicy: Always
  nodeSelector:
    disktype: ssd
```

### Multi-Container Pod Example

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
  - name: web-server
    image: nginx:1.21
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-data
      mountPath: /usr/share/nginx/html
  - name: content-puller
    image: alpine:latest
    command: ["/bin/sh"]
    args: ["-c", "while true; do wget -O /data/index.html http://example.com; sleep 3600; done"]
    volumeMounts:
    - name: shared-data
      mountPath: /data
  volumes:
  - name: shared-data
    emptyDir: {}
```

### Pod Commands

```bash
# Create pod
kubectl apply -f pod.yaml

# Get pods
kubectl get pods
kubectl get pods -o wide
kubectl get pods --show-labels

# Describe pod
kubectl describe pod nginx-pod

# Get pod logs
kubectl logs nginx-pod
kubectl logs nginx-pod -c container-name  # Multi-container pod

# Execute commands in pod
kubectl exec -it nginx-pod -- /bin/bash
kubectl exec -it nginx-pod -c container-name -- /bin/bash  # Multi-container pod

# Port forwarding
kubectl port-forward nginx-pod 8080:80

# Delete pod
kubectl delete pod nginx-pod
kubectl delete -f pod.yaml
```

### Pod Best Practices

1. **Single Responsibility**: One main process per pod
2. **Sidecar Pattern**: Use additional containers for supporting functionality
3. **Resource Limits**: Always set resource requests and limits
4. **Health Checks**: Implement liveness and readiness probes
5. **Security**: Run as non-root user when possible

### Liveness and Readiness Probes

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: probe-example
spec:
  containers:
  - name: app
    image: nginx:1.21
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /healthz
        port: 80
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /ready
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      successThreshold: 1
      failureThreshold: 3
    startupProbe:
      httpGet:
        path: /startup
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 1
      failureThreshold: 30
```

---

## 6. Services

### Service Types and Use Cases

#### ClusterIP (Default)
- Internal communication within cluster
- Database connections
- Inter-service communication

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: backend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: ClusterIP
```

#### NodePort
- External access via node IP
- Development and testing
- Simple external access

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-nodeport
spec:
  selector:
    app: frontend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
    nodePort: 30080
  type: NodePort
```

#### LoadBalancer
- Cloud provider integration
- Production external access
- Automatic load balancer provisioning

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-loadbalancer
spec:
  selector:
    app: web
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: LoadBalancer
```

#### ExternalName
- DNS-based service discovery
- External service integration
- Service aliasing

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: database.example.com
```

### Headless Services

```yaml
apiVersion: v1
kind: Service
metadata:
  name: headless-service
spec:
  clusterIP: None
  selector:
    app: stateful-app
  ports:
  - port: 80
    targetPort: 8080
```

### Service Discovery Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                Service Discovery                            │
├─────────────────────────────────────────────────────────────┤
│  DNS Resolution                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │    Pod A    │───▶│    DNS      │───▶│  Service    │      │
│  │             │    │             │    │   ClusterIP │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│                                               │             │
│                                               ▼             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Target Pods                            │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐             │    │
│  │  │  Pod 1  │  │  Pod 2  │  │  Pod 3  │             │    │
│  │  └─────────┘  └─────────┘  └─────────┘             │    │
│  └─────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────┤
│  Environment Variables                                      │
│  MY_SERVICE_SERVICE_HOST=10.96.0.1                         │
│  MY_SERVICE_SERVICE_PORT=80                                 │
└─────────────────────────────────────────────────────────────┘
```

### Service Commands

```bash
# Create service
kubectl apply -f service.yaml

# Get services
kubectl get services
kubectl get svc

# Describe service
kubectl describe service backend-service

# Get endpoints
kubectl get endpoints backend-service

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it -- /bin/sh
# Inside pod: wget -qO- http://backend-service

# Port forwarding to service
kubectl port-forward service/backend-service 8080:80
```

---

## 7. Deployments

### Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Deployment                               │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │                ReplicaSet v1                        │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐             │    │
│  │  │  Pod 1  │  │  Pod 2  │  │  Pod 3  │             │    │
│  │  └─────────┘  └─────────┘  └─────────┘             │    │
│  └─────────────────────────────────────────────────────┘    │
│                               │                             │
│                               ▼ (Rolling Update)            │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                ReplicaSet v2                        │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐             │    │
│  │  │  Pod 1  │  │  Pod 2  │  │  Pod 3  │             │    │
│  │  │   v2    │  │   v2    │  │   v2    │             │    │
│  │  └─────────┘  └─────────┘  └─────────┘             │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Basic Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Advanced Deployment Strategies

#### Rolling Update (Default)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-update-deployment
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: nginx:1.21
        ports:
        - containerPort: 80
```

#### Blue-Green Deployment
```yaml
# Blue Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
      version: blue
  template:
    metadata:
      labels:
        app: web
        version: blue
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80

---
# Green Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
      version: green
  template:
    metadata:
      labels:
        app: web
        version: green
    spec:
      containers:
      - name: web
        image: nginx:1.21
        ports:
        - containerPort: 80

---
# Service (switch between blue and green)
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: web
    version: blue  # Change to 'green' for green deployment
  ports:
  - port: 80
    targetPort: 80
```

#### Canary Deployment
```yaml
# Main Deployment (90% traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-main
spec:
  replicas: 9
  selector:
    matchLabels:
      app: web
      track: stable
  template:
    metadata:
      labels:
        app: web
        track: stable
    spec:
      containers:
      - name: web
        image: nginx:1.20

---
# Canary Deployment (10% traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
      track: canary
  template:
    metadata:
      labels:
        app: web
        track: canary
    spec:
      containers:
      - name: web
        image: nginx:1.21

---
# Service (targets both deployments)
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
```

### Deployment Commands

```bash
# Create deployment
kubectl apply -f deployment.yaml

# Get deployments
kubectl get deployments
kubectl get deploy

# Describe deployment
kubectl describe deployment nginx-deployment

# Scale deployment
kubectl scale deployment nginx-deployment --replicas=5

# Update deployment image
kubectl set image deployment/nginx-deployment nginx=nginx:1.22

# Check rollout status
kubectl rollout status deployment/nginx-deployment

# View rollout history
kubectl rollout history deployment/nginx-deployment

# Rollback to previous version
kubectl rollout undo deployment/nginx-deployment

# Rollback to specific revision
kubectl rollout undo deployment/nginx-deployment --to-revision=2

# Pause/Resume rollout
kubectl rollout pause deployment/nginx-deployment
kubectl rollout resume deployment/nginx-deployment

# Delete deployment
kubectl delete deployment nginx-deployment
```

### Deployment Best Practices

1. **Resource Limits**: Always set CPU and memory limits
2. **Health Checks**: Implement readiness and liveness probes
3. **Rolling Update Strategy**: Use maxUnavailable and maxSurge appropriately
4. **Image Tags**: Use specific image tags, avoid 'latest'
5. **Labels**: Use consistent labeling strategy
6. **Security Context**: Set security context for containers

---

## 8. ReplicaSets

### ReplicaSet vs Deployment

```
┌─────────────────────────────────────────────────────────────┐
│                    Deployment                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │               ReplicaSet v1                         │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐             │    │
│  │  │  Pod 1  │  │  Pod 2  │  │  Pod 3  │             │    │
│  │  └─────────┘  └─────────┘  └─────────┘             │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │               ReplicaSet v2                         │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐             │    │
│  │  │  Pod 1  │  │  Pod 2  │  │  Pod 3  │             │    │
│  │  │   new   │  │   new   │  │   new   │             │    │
│  │  └─────────┘  └─────────┘  └─────────┘             │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                 Standalone ReplicaSet                       │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                ReplicaSet                           │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐             │    │
│  │  │  Pod 1  │  │  Pod 2  │  │  Pod 3  │             │    │
│  │  └─────────┘  └─────────┘  └─────────┘             │    │
│  └─────────────────────────────────────────────────────┘    │
│  (Manual updates required)                                  │
└─────────────────────────────────────────────────────────────┘
```

### ReplicaSet YAML

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-replicaset
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
    matchExpressions:
    - key: environment
      operator: In
      values:
      - production
      - staging
  template:
    metadata:
      labels:
        app: nginx
        environment: production
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

### ReplicaSet Commands

```bash
# Get replicasets
kubectl get replicasets
kubectl get rs

# Describe replicaset
kubectl describe rs nginx-replicaset

# Scale replicaset
kubectl scale rs nginx-replicaset --replicas=5

# Delete replicaset
kubectl delete rs nginx-replicaset

# Delete replicaset but keep pods
kubectl delete rs nginx-replicaset --cascade=orphan
```

---

## 9. ConfigMaps and Secrets

### ConfigMaps

#### Creating ConfigMaps

##### From Literal Values
```bash
kubectl create configmap app-config \
  --from-literal=database_host=mysql.example.com \
  --from-literal=database_port=3306 \
  --from-literal=debug_mode=true
```

##### From Files
```bash
# Create config file
echo "database_host=mysql.example.com" > app.properties
echo "database_port=3306" >> app.properties

# Create configmap from file
kubectl create configmap app-config --from-file=app.properties
```

##### From Directory
```bash
# Create configmap from directory
kubectl create configmap app-config --from-file=config-dir/
```

#### ConfigMap YAML

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_host: "mysql.example.com"
  database_port: "3306"
  debug_mode: "true"
  app.properties: |
    database_host=mysql.example.com
    database_port=3306
    debug_mode=true
    max_connections=100
  nginx.conf: |
    server {
        listen 80;
        server_name example.com;
        location / {
            proxy_pass http://backend;
        }
    }
```

#### Using ConfigMaps in Pods

##### Environment Variables
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo $DATABASE_HOST && sleep 3600']
    env:
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_host
    envFrom:
    - configMapRef:
        name: app-config
```

##### Volume Mounts
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-volume-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/conf.d
    - name: app-config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: app-config
      items:
      - key: nginx.conf
        path: default.conf
  - name: app-config-volume
    configMap:
      name: app-config
```

### Secrets

#### Creating Secrets

##### Generic Secret
```bash
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=secretpassword
```

##### Docker Registry Secret
```bash
kubectl create secret docker-registry registry-secret \
  --docker-server=myregistry.com \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=myemail@example.com
```

##### TLS Secret
```bash
kubectl create secret tls tls-secret \
  --cert=tls.crt \
  --key=tls.key
```

#### Secret YAML

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  username: YWRtaW4=  # base64 encoded 'admin'
  password: c2VjcmV0cGFzc3dvcmQ=  # base64 encoded 'secretpassword'
---
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi... # base64 encoded certificate
  tls.key: LS0tLS1CRUdJTi... # base64 encoded private key
```

#### Using Secrets in Pods

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-pod
spec:
  containers:
  - name: app
    image: mysql:8.0
    env:
    - name: MYSQL_ROOT_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
    - name: MYSQL_USER
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: username
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secret
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: db-secret
  imagePullSecrets:
  - name: registry-secret
```

### Best Practices

1. **ConfigMaps**: Use for non-sensitive configuration data
2. **Secrets**: Use for sensitive data (passwords, tokens, keys)
3. **Immutable**: Consider making ConfigMaps and Secrets immutable
4. **RBAC**: Restrict access to secrets using RBAC
5. **External Secret Management**: Consider external secret management solutions

---

## 10. Namespaces

### Namespace Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                       │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │              default namespace                      │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐             │    │
│  │  │  Pod 1  │  │  Pod 2  │  │  Pod 3  │             │    │
│  │  └─────────┘  └─────────┘  └─────────┘             │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              production namespace                   │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐             │    │
│  │  │  Pod A  │  │  Pod B  │  │  Pod C  │             │    │
│  │  └─────────┘  └─────────┘  └─────────┘             │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              staging namespace                      │    │
│  │  ┌─────────┐  ┌─────────┐                          │    │
│  │  │  Pod X  │  │  Pod Y  │                          │    │
│  │  └─────────┘  └─────────┘                          │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              kube-system namespace                  │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐             │    │
│  │  │ kube-   │  │  etcd   │  │ kube-   │             │    │
│  │  │ proxy   │  │         │  │ dns     │             │    │
│  │  └─────────┘  └─────────┘  └─────────┘             │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Creating Namespaces

#### Imperative
```bash
kubectl create namespace production
kubectl create namespace staging
kubectl create namespace development
```

#### Declarative
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
    team: backend
---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging
    team: backend
---
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    environment: development
    team: backend
```

### Namespace with Resource Quotas

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
    pods: "10"
    services: "5"
    secrets: "10"
    configmaps: "10"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: production
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    type: Container
```

### Cross-Namespace Communication

```yaml
# Service in production namespace
apiVersion: v1
kind: Service
metadata:
  name: database
  namespace: production
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432

---
# Pod in staging namespace accessing production service
apiVersion: v1
kind: Pod
metadata:
  name: app
  namespace: staging
spec:
  containers:
  - name: app
    image: myapp:latest
    env:
    - name: DATABASE_HOST
      value: "database.production.svc.cluster.local"
    - name: DATABASE_PORT
      value: "5432"
```

### Namespace Commands

```bash
# Get namespaces
kubectl get namespaces
kubectl get ns

# Describe namespace
kubectl describe namespace production

# Set default namespace for current context
kubectl config set-context --current --namespace=production

# Get current namespace
kubectl config view --minify -o jsonpath='{..namespace}'

# Create resources in specific namespace
kubectl apply -f app.yaml -n production

# Get resources from specific namespace
kubectl get pods -n production
kubectl get all -n production

# Get resources from all namespaces
kubectl get pods --all-namespaces
kubectl get pods -A

# Delete namespace (deletes all resources in it)
kubectl delete namespace production
```

### Network Policies for Namespace Isolation

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: production

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

---

## 11. Networking

### Kubernetes Networking Model

```
┌─────────────────────────────────────────────────────────────┐
│                  Cluster Network                            │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   Node 1                            │    │
│  │  Pod Network: 10.244.1.0/24                        │    │
│  │  ┌─────────────┐  ┌─────────────┐                  │    │
│  │  │    Pod A    │  │    Pod B    │                  │    │
│  │  │ 10.244.1.10 │  │ 10.244.1.11 │                  │    │
│  │  └─────────────┘  └─────────────┘                  │    │
│  │              │                                      │    │
│  │              ▼                                      │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │            Node Network                     │    │    │
│  │  │          192.168.1.10                       │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   Node 2                            │    │
│  │  Pod Network: 10.244.2.0/24                        │    │
│  │  ┌─────────────┐  ┌─────────────┐                  │    │
│  │  │    Pod C    │  │    Pod D    │                  │    │
│  │  │ 10.244.2.10 │  │ 10.244.2.11 │                  │    │
│  │  └─────────────┘  └─────────────┘                  │    │
│  │              │                                      │    │
│  │              ▼                                      │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │            Node Network                     │    │    │
│  │  │          192.168.1.11                       │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────┘    │
│                            │                               │
│                            ▼                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              External Network                       │    │
│  │             Internet/LAN                            │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### CNI Plugins

#### Calico Installation
```bash
# Install Calico
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Check Calico status
kubectl get pods -n kube-system | grep calico
```

#### Flannel Installation
```bash
# Install Flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# Check Flannel status
kubectl get pods -n kube-system | grep flannel
```

#### Weave Net Installation
```bash
# Install Weave Net
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

# Check Weave status
kubectl get pods -n kube-system | grep weave
```

### Ingress Controllers

#### NGINX Ingress Controller

##### Installation
```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.3.0/deploy/static/provider/cloud/deploy.yaml

# Wait for deployment
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

##### Basic Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
```

##### TLS Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.example.com
    secretName: tls-secret
  rules:
  - host: secure.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

### Network Policies

#### Default Deny All
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

#### Allow Specific Traffic
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-app-netpol
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
  - to: []  # Allow DNS
    ports:
    - protocol: UDP
      port: 53
```

### Service Mesh - Istio

#### Installation
```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio
istioctl install --set values.defaultRevision=default

# Enable automatic sidecar injection
kubectl label namespace default istio-injection=enabled
```

#### Virtual Service
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: web-service
spec:
  hosts:
  - web-service
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: web-service
        subset: canary
      weight: 100
  - route:
    - destination:
        host: web-service
        subset: stable
      weight: 100
```

#### Destination Rule
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: web-service
spec:
  host: web-service
  subsets:
  - name: stable
    labels:
      version: stable
  - name: canary
    labels:
      version: canary
```

### DNS Resolution

#### Service DNS
```
# Service DNS format:
<service-name>.<namespace>.svc.cluster.local

# Examples:
web-service.default.svc.cluster.local
database.production.svc.cluster.local
```

#### Pod DNS
```
# Pod DNS format:
<pod-ip-with-dashes>.<namespace>.pod.cluster.local

# Example:
10-244-1-10.default.pod.cluster.local
```

### Troubleshooting Network Issues

```bash
# Check node network configuration
kubectl get nodes -o wide

# Check pod network
kubectl get pods -o wide

# Check services and endpoints
kubectl get svc
kubectl get endpoints

# Test connectivity from pod
kubectl exec -it test-pod -- nslookup kubernetes.default
kubectl exec -it test-pod -- wget -qO- http://web-service:80

# Check network policies
kubectl get networkpolicies

# Check ingress
kubectl get ingress
kubectl describe ingress web-ingress

# Check CNI plugin status
kubectl get pods -n kube-system

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

---

*This completes the first major section of the comprehensive Kubernetes documentation. The guide covers fundamentals, architecture, core components, and networking. Would you like me to continue with the remaining sections including storage, security, monitoring, and production best practices?*