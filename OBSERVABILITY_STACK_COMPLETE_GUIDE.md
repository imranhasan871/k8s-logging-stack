# Complete Observability Stack: Grafana Alloy + Loki + Grafana on Kubernetes

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites](#2-prerequisites)
3. [Namespace and RBAC Setup](#3-namespace-and-rbac-setup)
4. [Grafana Deployment](#4-grafana-deployment)
5. [Loki Deployment](#5-loki-deployment)
6. [Grafana Alloy Deployment](#6-grafana-alloy-deployment)
7. [Configuration and Integration](#7-configuration-and-integration)
8. [Monitoring and Alerting](#8-monitoring-and-alerting)
9. [Production Best Practices](#9-production-best-practices)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Architecture Overview

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           Kubernetes Cluster                                       │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                          Observability Namespace                            │    │
│  │                                                                             │    │
│  │  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐          │    │
│  │  │    Grafana      │    │      Loki       │    │  Grafana Alloy  │          │    │
│  │  │                 │    │                 │    │                 │          │    │
│  │  │  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │          │    │
│  │  │  │Dashboard  │  │    │  │Distributor│  │    │  │Metrics    │  │          │    │
│  │  │  │Engine     │  │    │  └───────────┘  │    │  │Collector  │  │          │    │
│  │  │  └───────────┘  │    │  ┌───────────┐  │    │  └───────────┘  │          │    │
│  │  │  ┌───────────┐  │    │  │Ingester   │  │    │  ┌───────────┐  │          │    │
│  │  │  │Data       │◄─┼────┼──┤           │  │    │  │Logs       │  │          │    │
│  │  │  │Sources    │  │    │  └───────────┘  │    │  │Collector  │  │          │    │
│  │  │  └───────────┘  │    │  ┌───────────┐  │    │  └───────────┘  │          │    │
│  │  │  ┌───────────┐  │    │  │Querier    │  │    │  ┌───────────┐  │          │    │
│  │  │  │Alerting   │  │    │  └───────────┘  │    │  │Discovery  │  │          │    │
│  │  │  │Engine     │  │    │  ┌───────────┐  │    │  │Engine     │  │          │    │
│  │  │  └───────────┘  │    │  │Query      │  │    │  └───────────┘  │          │    │
│  │  └─────────────────┘    │  │Frontend   │  │    └─────────────────┘          │    │
│  │           ▲              │  └───────────┘  │             │                   │    │
│  │           │              └─────────────────┘             │                   │    │
│  │           │                       ▲                     │                   │    │
│  │           │                       │                     ▼                   │    │
│  │           └───────────────────────┼─────────────────────────────────────────┘    │
│  │                                   │                                              │
│  ├───────────────────────────────────┼──────────────────────────────────────────────┤
│  │                                   │                                              │
│  │  ┌─────────────────────────────────▼──────────────────────────────────────┐      │
│  │  │                        Storage Layer                                   │      │
│  │  │                                                                        │      │
│  │  │  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐     │      │
│  │  │  │   Grafana PVC   │    │    Loki PVC     │    │   Object Store  │     │      │
│  │  │  │   (Dashboards   │    │   (WAL/Index)   │    │   (MinIO/S3)    │     │      │
│  │  │  │    & Config)    │    │                 │    │   (Log Chunks)  │     │      │
│  │  │  └─────────────────┘    └─────────────────┘    └─────────────────┘     │      │
│  │  └────────────────────────────────────────────────────────────────────────┘      │
│  │                                                                                   │
│  ├───────────────────────────────────────────────────────────────────────────────────┤
│  │                                                                                   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐  │
│  │  │                          Application Namespaces                            │  │
│  │  │                                                                             │  │
│  │  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                     │  │
│  │  │  │   App Pod   │    │   App Pod   │    │   App Pod   │                     │  │
│  │  │  │             │    │             │    │             │                     │  │
│  │  │  │ ┌─────────┐ │    │ ┌─────────┐ │    │ ┌─────────┐ │                     │  │
│  │  │  │ │App      │ │    │ │App      │ │    │ │App      │ │                     │  │
│  │  │  │ │Container│ │    │ │Container│ │    │ │Container│ │                     │  │
│  │  │  │ └─────────┘ │    │ └─────────┘ │    │ └─────────┘ │                     │  │
│  │  │  │ ┌─────────┐ │    │ ┌─────────┐ │    │ ┌─────────┐ │                     │  │
│  │  │  │ │Alloy    │ │    │ │Alloy    │ │    │ │Alloy    │ │                     │  │
│  │  │  │ │Sidecar  │ │    │ │Sidecar  │ │    │ │Sidecar  │ │                     │  │
│  │  │  │ └─────────┘ │    │ └─────────┘ │    │ └─────────┘ │                     │  │
│  │  │  └─────────────┘    └─────────────┘    └─────────────┘                     │  │
│  │  │         │                  │                  │                           │  │
│  │  │         └──────────────────┼──────────────────┘                           │  │
│  │  │                            │                                              │  │
│  │  │                            ▼                                              │  │
│  │  │                   ┌─────────────────┐                                     │  │
│  │  │                   │  Alloy DaemonSet│                                     │  │
│  │  │                   │  (Node-level    │                                     │  │
│  │  │                   │   Collection)   │                                     │  │
│  │  │                   └─────────────────┘                                     │  │
│  │  └─────────────────────────────────────────────────────────────────────────────┘  │
│  │                                                                                   │
│  └───────────────────────────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              Data Flow Architecture                                 │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────┐                                                                    │
│  │Application  │                                                                    │
│  │Logs         │                                                                    │
│  └──────┬──────┘                                                                    │
│         │                                                                           │
│         ▼                                                                           │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐       │
│  │   Grafana   │────▶│    Loki     │────▶│   Object    │────▶│   Grafana   │       │
│  │    Alloy    │     │ Distributor │     │   Storage   │     │   Querier   │       │
│  │(Log Shipper)│     └─────────────┘     │  (MinIO/S3) │     └─────────────┘       │
│  └─────────────┘             │           └─────────────┘             │             │
│         │                    ▼                   ▲                   │             │
│         │             ┌─────────────┐             │                   ▼             │
│         │             │    Loki     │             │            ┌─────────────┐     │
│         │             │  Ingester   │─────────────┘            │   Grafana   │     │
│         │             └─────────────┘                          │  Dashboard  │     │
│         │                    │                                 └─────────────┘     │
│         │                    ▼                                         ▲           │
│         │             ┌─────────────┐                                   │           │
│         │             │Local Storage│                                   │           │
│         │             │(WAL & Index)│                                   │           │
│         │             └─────────────┘                                   │           │
│         │                                                               │           │
│         ▼                                                               │           │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                │           │
│  │  Metrics    │────▶│  Prometheus │────▶│   Grafana   │────────────────┘           │
│  │ Collection  │     │  (Optional) │     │Data Source  │                            │
│  └─────────────┘     └─────────────┘     └─────────────┘                            │
│                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                              Query Flow                                             │
│                                                                                     │
│  User Query ──▶ Grafana ──▶ Loki Query Frontend ──▶ Loki Querier ──▶ Object Store │
│       ▲                                                    │                       │
│       │                                                    ▼                       │
│       └────────────────── Query Results ◄─────────── Local Index                 │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

#### Grafana Alloy
- **Log Collection**: Collects logs from containers and system components
- **Metrics Collection**: Scrapes Prometheus-compatible metrics
- **Service Discovery**: Automatically discovers targets in Kubernetes
- **Processing**: Filters, transforms, and enriches data
- **Forwarding**: Sends data to Loki and other destinations

#### Loki
- **Log Aggregation**: Receives and stores log streams
- **Indexing**: Creates efficient indexes for log queries
- **Querying**: Provides LogQL interface for log queries
- **Storage**: Manages log retention and storage lifecycle

#### Grafana
- **Visualization**: Creates dashboards and panels
- **Alerting**: Manages alert rules and notifications
- **Data Source Management**: Connects to Loki and other data sources
- **User Management**: Handles authentication and authorization

---

## 2. Prerequisites

### System Requirements

```yaml
# Minimum Resource Requirements
resources:
  grafana:
    cpu: "500m"
    memory: "1Gi"
    storage: "10Gi"
  loki:
    cpu: "1000m"
    memory: "2Gi"
    storage: "50Gi"
  alloy:
    cpu: "200m"
    memory: "512Mi"
    storage: "5Gi"
```

### Required Tools

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update && sudo apt-get install helm

# Verify installations
kubectl version --client
helm version
```

---

## 3. Namespace and RBAC Setup

### Create Namespace

```yaml
# observability-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: observability
  labels:
    name: observability
    purpose: monitoring-logging
---
apiVersion: v1
kind: Namespace
metadata:
  name: storage
  labels:
    name: storage
    purpose: persistent-storage
```

### RBAC Configuration

```yaml
# rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: observability-stack
  namespace: observability
automountServiceAccountToken: true

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: observability-stack
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/proxy", "services", "endpoints", "pods", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions", "apps"]
  resources: ["deployments", "replicasets", "daemonsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: observability-stack
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: observability-stack
subjects:
- kind: ServiceAccount
  name: observability-stack
  namespace: observability

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: observability
  name: observability-config
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: observability-config
  namespace: observability
subjects:
- kind: ServiceAccount
  name: observability-stack
  namespace: observability
roleRef:
  kind: Role
  name: observability-config
  apiGroup: rbac.authorization.k8s.io
```

---

## 4. Grafana Deployment

### Grafana ConfigMap

```yaml
# grafana-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-config
  namespace: observability
data:
  grafana.ini: |
    [analytics]
    check_for_updates = true
    
    [grafana_net]
    url = https://grafana.net
    
    [log]
    mode = console
    level = info
    
    [paths]
    data = /var/lib/grafana/
    logs = /var/log/grafana
    plugins = /var/lib/grafana/plugins
    provisioning = /etc/grafana/provisioning
    
    [server]
    protocol = http
    http_port = 3000
    domain = localhost
    enforce_domain = false
    root_url = %(protocol)s://%(domain)s:%(http_port)s/
    router_logging = false
    static_root_path = public
    enable_gzip = false
    cert_file =
    cert_key =
    socket = /tmp/grafana.sock
    
    [security]
    admin_user = admin
    admin_password = admin123
    secret_key = SW2YcwTIb9zpOOhoPsMm
    login_remember_days = 7
    cookie_username = grafana_user
    cookie_remember_name = grafana_remember
    disable_gravatar = false
    
    [users]
    allow_sign_up = false
    allow_org_create = false
    auto_assign_org = true
    auto_assign_org_role = Viewer
    
    [auth.anonymous]
    enabled = false
    
    [auth.basic]
    enabled = true
    
    [database]
    type = sqlite3
    path = grafana.db
    
    [session]
    provider = file
    
    [dataproxy]
    logging = false
    
    [snapshots]
    external_enabled = true
    external_snapshot_url = https://snapshots-origin.raintank.io
    external_snapshot_name = Publish to snapshot.raintank.io
    
    [dashboards]
    versions_to_keep = 20
    
    [alerting]
    enabled = true
    execute_alerts = true
    
    [metrics]
    enabled = true
    interval_seconds = 10
    
    [tracing.jaeger]
    address = localhost:6831
    always_included_tag = tag1:value1
    sampler_type = const
    sampler_param = 1
    
    [explore]
    enabled = true

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: observability
data:
  datasource.yaml: |
    apiVersion: 1
    datasources:
    - name: Loki
      type: loki
      access: proxy
      url: http://loki:3100
      isDefault: true
      jsonData:
        maxLines: 1000
        derivedFields:
          - datasourceUid: prometheus
            matcherRegex: "trace_id=(\\w+)"
            name: TraceID
            url: "$${__value.raw}"
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://prometheus:9090
      isDefault: false
      jsonData:
        httpMethod: POST
        exemplarTraceIdDestinations:
          - datasourceUid: jaeger
            name: trace_id

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards-config
  namespace: observability
data:
  dashboards.yaml: |
    apiVersion: 1
    providers:
    - name: 'default'
      orgId: 1
      folder: ''
      type: file
      disableDeletion: false
      editable: true
      options:
        path: /var/lib/grafana/dashboards
```

### Grafana Deployment

```yaml
# grafana-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: observability
  labels:
    app: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      serviceAccountName: observability-stack
      securityContext:
        runAsUser: 472
        runAsGroup: 472
        fsGroup: 472
      containers:
      - name: grafana
        image: grafana/grafana:10.2.0
        ports:
        - containerPort: 3000
          name: http-grafana
          protocol: TCP
        env:
        - name: GF_SECURITY_ADMIN_USER
          value: admin
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-admin-credentials
              key: admin-password
        - name: GF_INSTALL_PLUGINS
          value: "grafana-clock-panel,grafana-simple-json-datasource,grafana-worldmap-panel"
        volumeMounts:
        - name: grafana-config
          mountPath: /etc/grafana/grafana.ini
          subPath: grafana.ini
        - name: grafana-datasources
          mountPath: /etc/grafana/provisioning/datasources
        - name: grafana-dashboards-config
          mountPath: /etc/grafana/provisioning/dashboards
        - name: grafana-storage
          mountPath: /var/lib/grafana
        - name: grafana-dashboards
          mountPath: /var/lib/grafana/dashboards
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3
      volumes:
      - name: grafana-config
        configMap:
          name: grafana-config
      - name: grafana-datasources
        configMap:
          name: grafana-datasources
      - name: grafana-dashboards-config
        configMap:
          name: grafana-dashboards-config
      - name: grafana-storage
        persistentVolumeClaim:
          claimName: grafana-pvc
      - name: grafana-dashboards
        configMap:
          name: grafana-dashboards

---
apiVersion: v1
kind: Secret
metadata:
  name: grafana-admin-credentials
  namespace: observability
type: Opaque
data:
  admin-password: YWRtaW4xMjM=  # base64 encoded 'admin123'

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-pvc
  namespace: observability
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard

---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: observability
  labels:
    app: grafana
spec:
  type: ClusterIP
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
    name: http
  selector:
    app: grafana

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: observability
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: grafana.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
```

---

## 5. Loki Deployment

### MinIO for Object Storage

```yaml
# minio-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: storage
  labels:
    app: minio
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: minio/minio:RELEASE.2023-10-25T06-33-25Z
        args:
        - server
        - /data
        - --console-address
        - ":9001"
        env:
        - name: MINIO_ROOT_USER
          value: minioadmin
        - name: MINIO_ROOT_PASSWORD
          value: minioadmin123
        - name: MINIO_PROMETHEUS_AUTH_TYPE
          value: public
        ports:
        - containerPort: 9000
          name: api
        - containerPort: 9001
          name: console
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /minio/health/live
            port: 9000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /minio/health/ready
            port: 9000
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: minio-pvc

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-pvc
  namespace: storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: standard

---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: storage
  labels:
    app: minio
spec:
  type: ClusterIP
  ports:
  - port: 9000
    targetPort: 9000
    protocol: TCP
    name: api
  - port: 9001
    targetPort: 9001
    protocol: TCP
    name: console
  selector:
    app: minio
```

### Loki Configuration

```yaml
# loki-config.yaml
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
      grpc_listen_port: 9096
      grpc_server_max_recv_msg_size: 104857600
      grpc_server_max_send_msg_size: 104857600
      log_level: info
    
    common:
      instance_addr: 127.0.0.1
      path_prefix: /tmp/loki
      storage:
        filesystem:
          chunks_directory: /tmp/loki/chunks
          rules_directory: /tmp/loki/rules
      replication_factor: 1
      ring:
        kvstore:
          store: inmemory
    
    query_range:
      results_cache:
        cache:
          embedded_cache:
            enabled: true
            max_size_mb: 100
    
    schema_config:
      configs:
        - from: 2020-10-24
          store: boltdb-shipper
          object_store: s3
          schema: v11
          index:
            prefix: index_
            period: 24h
    
    storage_config:
      boltdb_shipper:
        active_index_directory: /tmp/loki/boltdb-shipper-active
        cache_location: /tmp/loki/boltdb-shipper-cache
        cache_ttl: 24h
        shared_store: s3
      aws:
        s3: http://minio.storage.svc.cluster.local:9000/loki
        access_key_id: minioadmin
        secret_access_key: minioadmin123
        s3forcepathstyle: true
        insecure: true
    
    compactor:
      working_directory: /tmp/loki/boltdb-shipper-compactor
      shared_store: s3
    
    limits_config:
      reject_old_samples: true
      reject_old_samples_max_age: 168h
      ingestion_rate_mb: 16
      ingestion_burst_size_mb: 32
      max_concurrent_tail_requests: 20
      max_cache_freshness_per_query: 10m
      split_queries_by_interval: 15m
      max_query_parallelism: 32
      max_query_series: 10000
      cardinality_limit: 100000
      max_streams_matchers_per_query: 1000
      max_entries_limit_per_query: 5000
      retention_period: 744h  # 31 days
    
    chunk_store_config:
      max_look_back_period: 0s
    
    table_manager:
      retention_deletes_enabled: true
      retention_period: 744h  # 31 days
    
    ruler:
      storage:
        type: local
        local:
          directory: /tmp/loki/rules
      rule_path: /tmp/loki/rules-temp
      alertmanager_url: http://alertmanager:9093
      ring:
        kvstore:
          store: inmemory
      enable_api: true
      enable_alertmanager_v2: true
    
    analytics:
      reporting_enabled: false
```

### Loki Deployment

```yaml
# loki-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loki
  namespace: observability
  labels:
    app: loki
spec:
  replicas: 1
  selector:
    matchLabels:
      app: loki
  template:
    metadata:
      labels:
        app: loki
    spec:
      serviceAccountName: observability-stack
      securityContext:
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
      containers:
      - name: loki
        image: grafana/loki:2.9.0
        args:
        - -config.file=/etc/loki/loki.yaml
        - -target=all
        ports:
        - containerPort: 3100
          name: http-metrics
        - containerPort: 9096
          name: grpc
        env:
        - name: JAEGER_AGENT_HOST
          value: jaeger
        - name: JAEGER_AGENT_PORT
          value: "6831"
        - name: JAEGER_SAMPLER_TYPE
          value: const
        - name: JAEGER_SAMPLER_PARAM
          value: "1"
        volumeMounts:
        - name: config
          mountPath: /etc/loki
        - name: storage
          mountPath: /tmp/loki
        resources:
          requests:
            memory: "1Gi"
            cpu: "1000m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /ready
            port: 3100
          initialDelaySeconds: 45
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 3100
          initialDelaySeconds: 15
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3
      volumes:
      - name: config
        configMap:
          name: loki-config
      - name: storage
        persistentVolumeClaim:
          claimName: loki-pvc

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: loki-pvc
  namespace: observability
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: standard

---
apiVersion: v1
kind: Service
metadata:
  name: loki
  namespace: observability
  labels:
    app: loki
spec:
  type: ClusterIP
  ports:
  - port: 3100
    targetPort: 3100
    protocol: TCP
    name: http-metrics
  - port: 9096
    targetPort: 9096
    protocol: TCP
    name: grpc
  selector:
    app: loki

---
apiVersion: v1
kind: Service
metadata:
  name: loki-headless
  namespace: observability
  labels:
    app: loki
spec:
  clusterIP: None
  ports:
  - port: 3100
    targetPort: 3100
    protocol: TCP
    name: http-metrics
  selector:
    app: loki
```

---

## 6. Grafana Alloy Deployment

### Alloy Configuration

```yaml
# alloy-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alloy-config
  namespace: observability
data:
  config.alloy: |
    // Logging configuration
    logging {
      level  = "info"
      format = "logfmt"
    }
    
    // Kubernetes service discovery for logs
    discovery.kubernetes "pods" {
      role = "pod"
    }
    
    // Process discovered pods for log collection
    discovery.relabel "logs" {
      targets = discovery.kubernetes.pods.targets
      
      // Keep only running pods
      rule {
        source_labels = ["__meta_kubernetes_pod_phase"]
        action        = "keep"
        regex         = "Running"
      }
      
      // Drop system namespaces (optional)
      rule {
        source_labels = ["__meta_kubernetes_namespace"]
        action        = "drop"
        regex         = "(kube-system|kube-public|kube-node-lease)"
      }
      
      // Set job label
      rule {
        source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_pod_name"]
        target_label  = "job"
        separator     = "/"
        action        = "replace"
      }
      
      // Set namespace label
      rule {
        source_labels = ["__meta_kubernetes_namespace"]
        target_label  = "namespace"
        action        = "replace"
      }
      
      // Set pod label
      rule {
        source_labels = ["__meta_kubernetes_pod_name"]
        target_label  = "pod"
        action        = "replace"
      }
      
      // Set container label
      rule {
        source_labels = ["__meta_kubernetes_pod_container_name"]
        target_label  = "container"
        action        = "replace"
      }
      
      // Set node label
      rule {
        source_labels = ["__meta_kubernetes_pod_node_name"]
        target_label  = "node"
        action        = "replace"
      }
      
      // Set filename based on container log path
      rule {
        source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
        target_label  = "__path__"
        separator     = "/"
        action        = "replace"
        replacement   = "/var/log/pods/*$1*/*$2*/*.log"
      }
    }
    
    // Log file discovery and reading
    loki.source.file "pods" {
      targets    = discovery.relabel.logs.output
      forward_to = [loki.process.logs.receiver]
    }
    
    // Log processing pipeline
    loki.process "logs" {
      forward_to = [loki.write.loki.receiver]
      
      stage.cri {}
      
      // Parse JSON logs
      stage.json {
        expressions = {
          level = "level",
          msg   = "msg",
          time  = "time",
        }
      }
      
      // Extract log level
      stage.labels {
        values = {
          level = "level",
        }
      }
      
      // Drop empty log levels
      stage.drop {
        source      = "level"
        expression  = "^$"
      }
      
      // Rate limiting
      stage.limit {
        rate = 1000
      }
    }
    
    // Loki write configuration
    loki.write "loki" {
      endpoint {
        url = "http://loki.observability.svc.cluster.local:3100/loki/api/v1/push"
        
        // Retry configuration
        max_backoff_period = "5m"
        max_retries        = 10
        min_backoff_period = "500ms"
      }
      
      external_labels = {
        cluster = "production",
      }
    }
    
    // Prometheus metrics discovery
    discovery.kubernetes "services" {
      role = "service"
    }
    
    discovery.kubernetes "endpoints" {
      role = "endpoints"
    }
    
    // Process services for metrics scraping
    discovery.relabel "metrics" {
      targets = discovery.kubernetes.endpoints.targets
      
      // Keep only services with prometheus.io/scrape annotation
      rule {
        source_labels = ["__meta_kubernetes_service_annotation_prometheus_io_scrape"]
        action        = "keep"
        regex         = "true"
      }
      
      // Use custom metrics path if specified
      rule {
        source_labels = ["__meta_kubernetes_service_annotation_prometheus_io_path"]
        action        = "replace"
        target_label  = "__metrics_path__"
        regex         = "(.+)"
      }
      
      // Use custom port if specified
      rule {
        source_labels = ["__address__", "__meta_kubernetes_service_annotation_prometheus_io_port"]
        action        = "replace"
        regex         = "([^:]+)(?::\\d+)?;(\\d+)"
        replacement   = "$1:$2"
        target_label  = "__address__"
      }
      
      // Set job label
      rule {
        source_labels = ["__meta_kubernetes_service_name"]
        target_label  = "job"
        action        = "replace"
      }
      
      // Set namespace label
      rule {
        source_labels = ["__meta_kubernetes_namespace"]
        target_label  = "namespace"
        action        = "replace"
      }
      
      // Set service label
      rule {
        source_labels = ["__meta_kubernetes_service_name"]
        target_label  = "service"
        action        = "replace"
      }
    }
    
    // Prometheus metrics scraping
    prometheus.scrape "metrics" {
      targets         = discovery.relabel.metrics.output
      forward_to      = [prometheus.remote_write.prometheus.receiver]
      scrape_interval = "30s"
      scrape_timeout  = "10s"
    }
    
    // Prometheus remote write (optional - if you have Prometheus)
    prometheus.remote_write "prometheus" {
      endpoint {
        url = "http://prometheus.observability.svc.cluster.local:9090/api/v1/write"
        
        queue_config {
          max_samples_per_send = 1000
          batch_send_deadline  = "5s"
        }
      }
      
      external_labels = {
        cluster = "production",
      }
    }
    
    // Node exporter metrics (if available)
    prometheus.scrape "node_exporter" {
      targets = [{
        __address__ = "localhost:9100",
        job         = "node-exporter",
      }]
      forward_to = [prometheus.remote_write.prometheus.receiver]
      scrape_interval = "30s"
    }
    
    // Kubernetes API server metrics
    prometheus.scrape "kubernetes_apiservers" {
      targets = [{
        __address__ = "kubernetes.default.svc:443",
        __scheme__  = "https",
        job         = "kubernetes-apiservers",
      }]
      forward_to = [prometheus.remote_write.prometheus.receiver]
      bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
      tls_config {
        ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
        insecure_skip_verify = true
      }
      scrape_interval = "30s"
    }
    
    // Alloy self-monitoring
    prometheus.exporter.self "alloy" {}
    
    prometheus.scrape "self" {
      targets    = prometheus.exporter.self.alloy.targets
      forward_to = [prometheus.remote_write.prometheus.receiver]
      job_name   = "alloy"
    }
```

### Alloy DaemonSet

```yaml
# alloy-daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: alloy
  namespace: observability
  labels:
    app: alloy
spec:
  selector:
    matchLabels:
      app: alloy
  template:
    metadata:
      labels:
        app: alloy
    spec:
      serviceAccountName: observability-stack
      hostNetwork: true
      hostPID: true
      securityContext:
        runAsUser: 0
      tolerations:
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: alloy
        image: grafana/alloy:v1.0.0
        args:
        - run
        - /etc/alloy/config.alloy
        - --storage.path=/tmp/alloy
        - --server.http.listen-addr=0.0.0.0:12345
        - --cluster.enabled=true
        - --cluster.join-addresses=alloy-cluster:12345
        - --disable-reporting
        env:
        - name: HOSTNAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: ALLOY_DEPLOY_MODE
          value: "helm"
        ports:
        - containerPort: 12345
          name: http-metrics
          protocol: TCP
        - containerPort: 4317
          name: otlp-grpc
          protocol: TCP
        - containerPort: 4318
          name: otlp-http
          protocol: TCP
        - containerPort: 14268
          name: jaeger-thrift
          protocol: TCP
        - containerPort: 9411
          name: zipkin
          protocol: TCP
        volumeMounts:
        - name: config
          mountPath: /etc/alloy
        - name: storage
          mountPath: /tmp/alloy
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: etcmachineinfo
          mountPath: /etc/machine-info
          readOnly: true
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 12345
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 12345
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3
      volumes:
      - name: config
        configMap:
          name: alloy-config
      - name: storage
        emptyDir: {}
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: etcmachineinfo
        hostPath:
          path: /etc/machine-info

---
apiVersion: v1
kind: Service
metadata:
  name: alloy
  namespace: observability
  labels:
    app: alloy
spec:
  type: ClusterIP
  ports:
  - port: 12345
    targetPort: 12345
    protocol: TCP
    name: http-metrics
  - port: 4317
    targetPort: 4317
    protocol: TCP
    name: otlp-grpc
  - port: 4318
    targetPort: 4318
    protocol: TCP
    name: otlp-http
  selector:
    app: alloy

---
apiVersion: v1
kind: Service
metadata:
  name: alloy-cluster
  namespace: observability
  labels:
    app: alloy
spec:
  clusterIP: None
  ports:
  - port: 12345
    targetPort: 12345
    protocol: TCP
    name: http-metrics
  selector:
    app: alloy
```

---

## 7. Configuration and Integration

### Default Grafana Dashboards

```yaml
# grafana-dashboards.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
  namespace: observability
data:
  loki-logs-dashboard.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Loki Logs Dashboard",
        "tags": ["loki", "logs"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Log Volume",
            "type": "stat",
            "targets": [
              {
                "expr": "sum(rate(loki_distributor_lines_received_total[5m]))",
                "legendFormat": "Lines/sec"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "palette-classic"
                },
                "unit": "short"
              }
            },
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
          },
          {
            "id": 2,
            "title": "Application Logs",
            "type": "logs",
            "targets": [
              {
                "expr": "{namespace!=\"kube-system\",namespace!=\"observability\"} |= \"\"",
                "refId": "A"
              }
            ],
            "gridPos": {"h": 16, "w": 24, "x": 0, "y": 8}
          },
          {
            "id": 3,
            "title": "Error Logs",
            "type": "logs",
            "targets": [
              {
                "expr": "{level=\"error\"} |= \"\"",
                "refId": "A"
              }
            ],
            "gridPos": {"h": 16, "w": 24, "x": 0, "y": 24}
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "10s"
      }
    }
  
  kubernetes-cluster-dashboard.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Kubernetes Cluster Overview",
        "tags": ["kubernetes", "cluster"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Cluster CPU Usage",
            "type": "stat",
            "targets": [
              {
                "expr": "100 - (avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
                "legendFormat": "CPU Usage %"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "thresholds"
                },
                "thresholds": {
                  "steps": [
                    {"color": "green", "value": null},
                    {"color": "yellow", "value": 70},
                    {"color": "red", "value": 90}
                  ]
                },
                "unit": "percent"
              }
            },
            "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0}
          },
          {
            "id": 2,
            "title": "Cluster Memory Usage",
            "type": "stat",
            "targets": [
              {
                "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
                "legendFormat": "Memory Usage %"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "thresholds"
                },
                "thresholds": {
                  "steps": [
                    {"color": "green", "value": null},
                    {"color": "yellow", "value": 70},
                    {"color": "red", "value": 90}
                  ]
                },
                "unit": "percent"
              }
            },
            "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0}
          },
          {
            "id": 3,
            "title": "Pod Count by Namespace",
            "type": "bargauge",
            "targets": [
              {
                "expr": "count by (namespace) (kube_pod_info)",
                "legendFormat": "{{namespace}}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "30s"
      }
    }
```

### Alerting Rules

```yaml
# loki-alerting-rules.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-alerting-rules
  namespace: observability
data:
  loki_rules.yml: |
    groups:
    - name: loki_alerts
      rules:
      - alert: LokiHighErrorRate
        expr: |
          (
            sum(rate(loki_request_duration_seconds_count{status_code=~"5.."}[5m]))
            /
            sum(rate(loki_request_duration_seconds_count[5m]))
          ) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Loki high error rate"
          description: "Loki is experiencing a high error rate: {{ $value | humanizePercentage }}"
      
      - alert: LokiHighIngestionRate
        expr: rate(loki_distributor_lines_received_total[5m]) > 10000
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Loki high ingestion rate"
          description: "Loki is ingesting logs at a high rate: {{ $value }} lines/sec"
      
      - alert: LokiDown
        expr: up{job="loki"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Loki is down"
          description: "Loki has been down for more than 5 minutes"

    - name: application_alerts
      rules:
      - alert: HighErrorLogRate
        expr: |
          sum(rate({level="error"}[5m])) by (namespace, pod) > 10
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High error log rate detected"
          description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is generating error logs at a high rate"
      
      - alert: ApplicationDown
        expr: |
          absent_over_time({job=~".+"}[5m])
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Application stopped logging"
          description: "No logs received from {{ $labels.job }} for 5 minutes"

    - name: infrastructure_alerts
      rules:
      - alert: KubernetesPodCrashLooping
        expr: |
          sum(rate({namespace!="kube-system"} |= "CrashLoopBackOff"[5m])) by (namespace, pod) > 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Pod crash looping detected"
          description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is crash looping"
      
      - alert: KubernetesNodeNotReady
        expr: |
          sum(rate({} |= "NodeNotReady"[5m])) by (node) > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Kubernetes node not ready"
          description: "Node {{ $labels.node }} is not ready"
```

### Grafana Alert Rules Configuration

```yaml
# grafana-alerting-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-alerting-config
  namespace: observability
data:
  alerting.yml: |
    apiVersion: 1
    groups:
      - name: loki-alerts
        folder: Loki
        interval: 1m
        rules:
          - uid: loki-error-rate
            title: Loki High Error Rate
            condition: C
            data:
              - refId: A
                queryType: ""
                relativeTimeRange:
                  from: 300
                  to: 0
                model:
                  expr: |
                    (
                      sum(rate(loki_request_duration_seconds_count{status_code=~"5.."}[5m]))
                      /
                      sum(rate(loki_request_duration_seconds_count[5m]))
                    )
                  legendFormat: ""
                  refId: A
              - refId: C
                queryType: ""
                relativeTimeRange:
                  from: 0
                  to: 0
                model:
                  conditions:
                    - evaluator:
                        params:
                          - 0.1
                        type: gt
                      operator:
                        type: and
                      query:
                        params:
                          - A
                      reducer:
                        params: []
                        type: last
                      type: query
                  refId: C
            noDataState: NoData
            execErrState: Alerting
            for: 5m
            annotations:
              summary: "Loki error rate is above 10%"
              description: "Loki is experiencing a high error rate of {{ $value | humanizePercentage }}"
            labels:
              severity: warning

          - uid: application-error-logs
            title: High Application Error Logs
            condition: C
            data:
              - refId: A
                queryType: ""
                relativeTimeRange:
                  from: 300
                  to: 0
                model:
                  expr: 'sum(rate({level="error"}[5m])) by (namespace, pod)'
                  legendFormat: "{{ namespace }}/{{ pod }}"
                  refId: A
              - refId: C
                queryType: ""
                relativeTimeRange:
                  from: 0
                  to: 0
                model:
                  conditions:
                    - evaluator:
                        params:
                          - 5
                        type: gt
                      operator:
                        type: and
                      query:
                        params:
                          - A
                      reducer:
                        params: []
                        type: last
                      type: query
                  refId: C
            noDataState: NoData
            execErrState: Alerting
            for: 2m
            annotations:
              summary: "High error log rate detected"
              description: "{{ $labels.namespace }}/{{ $labels.pod }} is generating {{ $value }} error logs per second"
            labels:
              severity: warning

  notification-policies.yml: |
    apiVersion: 1
    policies:
      - orgId: 1
        receiver: web.hook
        group_by:
          - grafana_folder
          - alertname
        routes:
          - receiver: critical-alerts
            group_by:
              - alertname
            matchers:
              - severity = critical
            group_wait: 30s
            group_interval: 5m
            repeat_interval: 12h
          - receiver: warning-alerts
            group_by:
              - alertname
            matchers:
              - severity = warning
            group_wait: 30s
            group_interval: 10m
            repeat_interval: 24h

  contact-points.yml: |
    apiVersion: 1
    contactPoints:
      - orgId: 1
        name: web.hook
        receivers:
          - uid: webhook-uid
            type: webhook
            settings:
              url: http://alertmanager:9093/api/v1/alerts
              httpMethod: POST
              
      - orgId: 1
        name: critical-alerts
        receivers:
          - uid: slack-critical
            type: slack
            settings:
              url: "${SLACK_WEBHOOK_URL}"
              channel: "#alerts-critical"
              title: "🚨 Critical Alert"
              text: |
                {{ range .Alerts }}
                **Alert:** {{ .Annotations.summary }}
                **Description:** {{ .Annotations.description }}
                **Severity:** {{ .Labels.severity }}
                **Time:** {{ .StartsAt.Format "2006-01-02 15:04:05" }}
                {{ end }}
              
      - orgId: 1
        name: warning-alerts
        receivers:
          - uid: slack-warning
            type: slack
            settings:
              url: "${SLACK_WEBHOOK_URL}"
              channel: "#alerts-warning"
              title: "⚠️ Warning Alert"
              text: |
                {{ range .Alerts }}
                **Alert:** {{ .Annotations.summary }}
                **Description:** {{ .Annotations.description }}
                **Severity:** {{ .Labels.severity }}
                **Time:** {{ .StartsAt.Format "2006-01-02 15:04:05" }}
                {{ end }}
```

## 8. Monitoring and Alerting

### Prometheus Integration (Optional)

```yaml
# prometheus-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: observability
  labels:
    app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: observability-stack
      containers:
      - name: prometheus
        image: prom/prometheus:v2.45.0
        args:
        - --config.file=/etc/prometheus/prometheus.yml
        - --storage.tsdb.path=/prometheus/data
        - --web.console.libraries=/etc/prometheus/console_libraries
        - --web.console.templates=/etc/prometheus/consoles
        - --web.enable-lifecycle
        - --web.enable-admin-api
        - --storage.tsdb.retention.time=15d
        ports:
        - containerPort: 9090
          name: web
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: storage
          mountPath: /prometheus/data
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 9090
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 9090
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: storage
        persistentVolumeClaim:
          claimName: prometheus-pvc

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: observability
data:
  prometheus.yml: |
    global:
      scrape_interval: 30s
      evaluation_interval: 30s
      external_labels:
        cluster: 'production'

    rule_files:
      - "/etc/prometheus/rules/*.yml"

    alerting:
      alertmanagers:
      - static_configs:
        - targets:
          - alertmanager:9093

    scrape_configs:
    - job_name: 'prometheus'
      static_configs:
      - targets: ['localhost:9090']

    - job_name: 'loki'
      static_configs:
      - targets: ['loki:3100']

    - job_name: 'alloy'
      static_configs:
      - targets: ['alloy:12345']

    - job_name: 'grafana'
      static_configs:
      - targets: ['grafana:3000']

    - job_name: 'kubernetes-apiservers'
      kubernetes_sd_configs:
      - role: endpoints
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        insecure_skip_verify: true
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https

    - job_name: 'kubernetes-nodes'
      kubernetes_sd_configs:
      - role: node
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        insecure_skip_verify: true
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)

    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\\d+)?;(\\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-pvc
  namespace: observability
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: standard

---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: observability
  labels:
    app: prometheus
spec:
  type: ClusterIP
  ports:
  - port: 9090
    targetPort: 9090
    protocol: TCP
    name: web
  selector:
    app: prometheus
```

### AlertManager Deployment

```yaml
# alertmanager-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: observability
  labels:
    app: alertmanager
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager
  template:
    metadata:
      labels:
        app: alertmanager
    spec:
      serviceAccountName: observability-stack
      containers:
      - name: alertmanager
        image: prom/alertmanager:v0.25.0
        args:
        - --config.file=/etc/alertmanager/alertmanager.yml
        - --storage.path=/alertmanager/data
        - --web.external-url=http://alertmanager:9093
        - --cluster.listen-address=0.0.0.0:9094
        ports:
        - containerPort: 9093
          name: web
        - containerPort: 9094
          name: cluster
        volumeMounts:
        - name: config
          mountPath: /etc/alertmanager
        - name: storage
          mountPath: /alertmanager/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 9093
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 9093
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config
        configMap:
          name: alertmanager-config
      - name: storage
        emptyDir: {}

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: observability
data:
  alertmanager.yml: |
    global:
      smtp_smarthost: 'localhost:587'
      smtp_from: 'alertmanager@example.com'
      slack_api_url: 'YOUR_SLACK_WEBHOOK_URL'

    route:
      group_by: ['alertname', 'severity']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h
      receiver: 'web.hook'
      routes:
      - match:
          severity: critical
        receiver: 'critical-alerts'
        group_wait: 10s
        repeat_interval: 1h
      - match:
          severity: warning
        receiver: 'warning-alerts'
        group_wait: 30s
        repeat_interval: 4h

    receivers:
    - name: 'web.hook'
      webhook_configs:
      - url: 'http://example.com/webhook'
        send_resolved: true

    - name: 'critical-alerts'
      slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts-critical'
        title: '🚨 Critical Alert'
        text: |
          {{ range .Alerts }}
          *Alert:* {{ .Annotations.summary }}
          *Description:* {{ .Annotations.description }}
          *Severity:* {{ .Labels.severity }}
          *Time:* {{ .StartsAt.Format "2006-01-02 15:04:05" }}
          {{ end }}
        send_resolved: true

    - name: 'warning-alerts'
      slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts-warning'
        title: '⚠️ Warning Alert'
        text: |
          {{ range .Alerts }}
          *Alert:* {{ .Annotations.summary }}
          *Description:* {{ .Annotations.description }}
          *Severity:* {{ .Labels.severity }}
          *Time:* {{ .StartsAt.Format "2006-01-02 15:04:05" }}
          {{ end }}
        send_resolved: true

    inhibit_rules:
    - source_match:
        severity: 'critical'
      target_match:
        severity: 'warning'
      equal: ['alertname', 'dev', 'instance']

---
apiVersion: v1
kind: Service
metadata:
  name: alertmanager
  namespace: observability
  labels:
    app: alertmanager
spec:
  type: ClusterIP
  ports:
  - port: 9093
    targetPort: 9093
    protocol: TCP
    name: web
  selector:
    app: alertmanager
```

## 9. Production Best Practices

### Security Hardening

#### Network Policies

```yaml
# network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: observability-network-policy
  namespace: observability
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    - namespaceSelector:
        matchLabels:
          name: observability
    - podSelector: {}
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: storage
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 443

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-default
  namespace: observability
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

#### Pod Security Policies

```yaml
# pod-security-policies.yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: observability-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
    - 'hostPath'
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: observability
  name: psp-user
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  verbs: ['use']
  resourceNames:
  - observability-psp

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: psp-user
  namespace: observability
roleRef:
  kind: Role
  name: psp-user
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: observability-stack
  namespace: observability
```

### Resource Management

#### Resource Quotas

```yaml
# resource-quotas.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: observability-quota
  namespace: observability
spec:
  hard:
    requests.cpu: "8"
    requests.memory: "16Gi"
    limits.cpu: "16"
    limits.memory: "32Gi"
    persistentvolumeclaims: "10"
    pods: "20"
    services: "10"
    secrets: "20"
    configmaps: "20"

---
apiVersion: v1
kind: LimitRange
metadata:
  name: observability-limits
  namespace: observability
spec:
  limits:
  - default:
      cpu: "1000m"
      memory: "1Gi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    type: Container
  - max:
      cpu: "4000m"
      memory: "8Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
    type: Container
```

### High Availability Configuration

#### Loki Multi-Replica Setup

```yaml
# loki-ha-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loki-read
  namespace: observability
  labels:
    app: loki
    component: read
spec:
  replicas: 2
  selector:
    matchLabels:
      app: loki
      component: read
  template:
    metadata:
      labels:
        app: loki
        component: read
    spec:
      serviceAccountName: observability-stack
      containers:
      - name: loki
        image: grafana/loki:2.9.0
        args:
        - -config.file=/etc/loki/loki.yaml
        - -target=querier,query-frontend
        ports:
        - containerPort: 3100
          name: http-metrics
        - containerPort: 9096
          name: grpc
        volumeMounts:
        - name: config
          mountPath: /etc/loki
        - name: storage
          mountPath: /tmp/loki
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
      volumes:
      - name: config
        configMap:
          name: loki-config
      - name: storage
        emptyDir: {}

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loki-write
  namespace: observability
  labels:
    app: loki
    component: write
spec:
  replicas: 2
  selector:
    matchLabels:
      app: loki
      component: write
  template:
    metadata:
      labels:
        app: loki
        component: write
    spec:
      serviceAccountName: observability-stack
      containers:
      - name: loki
        image: grafana/loki:2.9.0
        args:
        - -config.file=/etc/loki/loki.yaml
        - -target=ingester,distributor
        ports:
        - containerPort: 3100
          name: http-metrics
        - containerPort: 9096
          name: grpc
        volumeMounts:
        - name: config
          mountPath: /etc/loki
        - name: storage
          mountPath: /tmp/loki
        resources:
          requests:
            memory: "1Gi"
            cpu: "1000m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
      volumes:
      - name: config
        configMap:
          name: loki-config
      - name: storage
        persistentVolumeClaim:
          claimName: loki-write-pvc

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: loki-write-pvc
  namespace: observability
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: fast-ssd
```

### Backup and Disaster Recovery

#### Grafana Backup Script

```yaml
# grafana-backup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: grafana-backup
  namespace: observability
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: observability-stack
          containers:
          - name: backup
            image: alpine/curl:latest
            command:
            - /bin/sh
            - -c
            - |
              # Backup Grafana dashboards
              curl -u admin:$GRAFANA_PASSWORD \
                http://grafana:3000/api/search?query=& \
                -o /backup/dashboards-$(date +%Y%m%d).json
              
              # Backup Grafana datasources
              curl -u admin:$GRAFANA_PASSWORD \
                http://grafana:3000/api/datasources \
                -o /backup/datasources-$(date +%Y%m%d).json
              
              # Upload to S3 or other backup storage
              echo "Backup completed at $(date)"
            env:
            - name: GRAFANA_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: grafana-admin-credentials
                  key: admin-password
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
          restartPolicy: OnFailure

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-pvc
  namespace: observability
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard
```

## 10. Troubleshooting

### Common Issues and Solutions

#### Loki Not Receiving Logs

**Symptoms:**
- No logs appearing in Grafana
- Alloy shows connection errors
- Empty log queries

**Debugging Steps:**

```bash
# Check Alloy logs
kubectl logs -n observability daemonset/alloy

# Check Loki logs
kubectl logs -n observability deployment/loki

# Check Alloy configuration
kubectl get configmap alloy-config -n observability -o yaml

# Test connectivity from Alloy to Loki
kubectl exec -n observability -it daemonset/alloy -- wget -qO- http://loki:3100/ready

# Check Loki ingestion endpoint
kubectl exec -n observability -it deployment/loki -- curl http://localhost:3100/loki/api/v1/push
```

**Common Solutions:**

1. **Network Connectivity Issues:**
```yaml
# Add network policy allowing traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-alloy-to-loki
  namespace: observability
spec:
  podSelector:
    matchLabels:
      app: loki
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: alloy
    ports:
    - protocol: TCP
      port: 3100
```

2. **Configuration Issues:**
```bash
# Validate Alloy configuration
kubectl exec -n observability -it daemonset/alloy -- /bin/alloy fmt --config.file=/etc/alloy/config.alloy
```

#### High Memory Usage

**Symptoms:**
- OOMKilled pods
- High memory consumption
- Slow query performance

**Debugging Steps:**

```bash
# Check resource usage
kubectl top pods -n observability

# Check resource limits
kubectl describe pod -n observability -l app=loki

# Monitor memory usage over time
kubectl exec -n observability deployment/prometheus -- promtool query instant 'container_memory_usage_bytes{namespace="observability"}'
```

**Solutions:**

```yaml
# Increase memory limits
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"

# Tune Loki configuration for memory usage
limits_config:
  ingestion_rate_mb: 8  # Reduce from 16
  ingestion_burst_size_mb: 16  # Reduce from 32
  max_cache_freshness_per_query: 5m  # Reduce from 10m
```

#### Storage Issues

**Symptoms:**
- Disk full errors
- Cannot write to object storage
- Index corruption

**Debugging Steps:**

```bash
# Check storage usage
kubectl exec -n observability deployment/loki -- df -h

# Check MinIO connectivity
kubectl exec -n observability deployment/loki -- wget -qO- http://minio.storage.svc.cluster.local:9000/minio/health/live

# Check PVC status
kubectl get pvc -n observability
kubectl describe pvc loki-pvc -n observability
```

**Solutions:**

```yaml
# Implement retention policies
limits_config:
  retention_period: 168h  # 7 days instead of 31

# Add storage monitoring
compactor:
  working_directory: /tmp/loki/boltdb-shipper-compactor
  shared_store: s3
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
```

### Monitoring Health Checks

```yaml
# health-check-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: health-check-dashboard
  namespace: observability
data:
  health-dashboard.json: |
    {
      "dashboard": {
        "title": "Observability Stack Health",
        "panels": [
          {
            "title": "Component Status",
            "type": "stat",
            "targets": [
              {
                "expr": "up{job=~\"loki|grafana|alloy\"}",
                "legendFormat": "{{ job }}"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "mappings": [
                  {"value": 0, "text": "Down", "color": "red"},
                  {"value": 1, "text": "Up", "color": "green"}
                ]
              }
            }
          },
          {
            "title": "Log Ingestion Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(loki_distributor_lines_received_total[5m])",
                "legendFormat": "Lines/sec"
              }
            ]
          },
          {
            "title": "Error Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(loki_request_duration_seconds_count{status_code=~\"5..\"}[5m])",
                "legendFormat": "5xx errors/sec"
              }
            ]
          }
        ]
      }
    }
```

### Deployment Scripts

#### Complete Deployment Script

```bash
#!/bin/bash
# deploy-observability-stack.sh

set -e

echo "🚀 Deploying Observability Stack..."

# Create namespaces
echo "📁 Creating namespaces..."
kubectl apply -f observability-namespace.yaml
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: storage
  labels:
    name: storage
EOF

# Deploy RBAC
echo "🔐 Setting up RBAC..."
kubectl apply -f rbac.yaml

# Deploy MinIO
echo "💾 Deploying MinIO..."
kubectl apply -f minio-deployment.yaml

# Wait for MinIO to be ready
echo "⏳ Waiting for MinIO to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/minio -n storage

# Create MinIO bucket for Loki
echo "🪣 Creating Loki bucket in MinIO..."
kubectl exec -n storage deployment/minio -- mc alias set local http://localhost:9000 minioadmin minioadmin123
kubectl exec -n storage deployment/minio -- mc mb local/loki

# Deploy Loki
echo "📊 Deploying Loki..."
kubectl apply -f loki-config.yaml
kubectl apply -f loki-deployment.yaml

# Wait for Loki to be ready
echo "⏳ Waiting for Loki to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/loki -n observability

# Deploy Alloy
echo "🔍 Deploying Grafana Alloy..."
kubectl apply -f alloy-config.yaml
kubectl apply -f alloy-daemonset.yaml

# Deploy Grafana
echo "📈 Deploying Grafana..."
kubectl apply -f grafana-config.yaml
kubectl apply -f grafana-dashboards.yaml
kubectl apply -f grafana-deployment.yaml

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n observability

# Deploy monitoring components (optional)
echo "🚨 Deploying monitoring components..."
kubectl apply -f prometheus-deployment.yaml
kubectl apply -f alertmanager-deployment.yaml

# Apply network policies
echo "🔒 Applying network policies..."
kubectl apply -f network-policies.yaml

echo "✅ Observability stack deployed successfully!"
echo ""
echo "🌐 Access URLs:"
echo "   Grafana: http://grafana.local (admin/admin123)"
echo "   MinIO Console: http://minio.local:9001 (minioadmin/minioadmin123)"
echo ""
echo "📋 Useful commands:"
echo "   kubectl get pods -n observability"
echo "   kubectl logs -n observability deployment/loki"
echo "   kubectl logs -n observability daemonset/alloy"
echo ""
echo "🔧 To update /etc/hosts for local access:"
echo "   echo '127.0.0.1 grafana.local minio.local' | sudo tee -a /etc/hosts"
```

#### Cleanup Script

```bash
#!/bin/bash
# cleanup-observability-stack.sh

echo "🗑️ Cleaning up observability stack..."

# Delete deployments
kubectl delete -f grafana-deployment.yaml --ignore-not-found=true
kubectl delete -f alloy-daemonset.yaml --ignore-not-found=true
kubectl delete -f loki-deployment.yaml --ignore-not-found=true
kubectl delete -f prometheus-deployment.yaml --ignore-not-found=true
kubectl delete -f alertmanager-deployment.yaml --ignore-not-found=true
kubectl delete -f minio-deployment.yaml --ignore-not-found=true

# Delete configs
kubectl delete -f grafana-config.yaml --ignore-not-found=true
kubectl delete -f alloy-config.yaml --ignore-not-found=true
kubectl delete -f loki-config.yaml --ignore-not-found=true
kubectl delete -f prometheus-config.yaml --ignore-not-found=true

# Delete RBAC
kubectl delete -f rbac.yaml --ignore-not-found=true

# Delete namespaces (this will delete all resources in them)
kubectl delete namespace observability --ignore-not-found=true
kubectl delete namespace storage --ignore-not-found=true

echo "✅ Cleanup completed!"
```

This comprehensive guide provides everything needed to deploy and manage a production-ready observability stack with Grafana Alloy, Loki, and Grafana on Kubernetes. The configuration includes monitoring, alerting, security, and troubleshooting guidance that any junior engineer can follow for production deployment.