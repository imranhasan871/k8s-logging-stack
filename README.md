# Kubernetes Logging Stack with Alloy, Loki, and Grafana

This repository provides a **complete Kubernetes logging stack** using:

- **Alloy** – collects logs from Kubernetes pods and nodes
- **Loki** – stores logs efficiently
- **Grafana** – visualizes logs with dashboards

This setup helps you centralize, store, and analyze logs from your cluster.

---

## Table of Contents

- [Kubernetes Logging Stack with Alloy, Loki, and Grafana](#kubernetes-logging-stack-with-alloy-loki-and-grafana)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
    - [1. Create Monitoring Namespace](#1-create-monitoring-namespace)
    - [2. Install Loki](#2-install-loki)
    - [3. Install Grafana](#3-install-grafana)
    - [4. Install Alloy](#4-install-alloy)
  - [Verify Logs](#verify-logs)
  - [Access Grafana](#access-grafana)
  - [Collect System Logs (Optional)](#collect-system-logs-optional)
  - [Repository Structure](#repository-structure)
  - [References](#references)

---

## Prerequisites

- Kubernetes cluster (v1.24+)
- `kubectl` configured
- `helm` installed
- Optional: `git` for version control

---

## Installation

### 1. Create Monitoring Namespace

```bash
kubectl create namespace monitoring
````

### 2. Install Loki

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false,prometheus.enabled=false
```

### 3. Install Grafana

```bash
helm install grafana grafana/grafana \
  --namespace monitoring \
  --set adminUser=admin,adminPassword=admin \
  --set service.type=LoadBalancer
```

### 4. Install Alloy

```bash
helm install alloy grafana/alloy \
  --namespace monitoring \
  --set pipelines.logs.discovery.kubernetes=true \
  --set pipelines.logs.outputs.loki.endpoint="http://loki:3100/loki/api/v1/push"
```

---

## Verify Logs

Create a test pod:

```bash
kubectl run test-pod --image=busybox --restart=Never --command -- sh -c "while true; do echo Hello Kubernetes; sleep 5; done"
```

Check Alloy pod logs:

```bash
kubectl logs -n monitoring <alloy-pod-name>
```

In Grafana → Explore → Loki → Query:

```logql
{namespace="default",pod="test-pod"}
```

You should see the logs from the test pod.

---

## Access Grafana

* If using Minikube:

```bash
kubectl port-forward svc/grafana 3000:80 -n monitoring
```

* Open browser: `http://localhost:3000`
* Login: `admin/admin`
* Add **Loki** as a data source: `http://loki:3100`

---

## Collect System Logs (Optional)

To collect host system logs (like `/var/log/syslog`):

1. Update Alloy DaemonSet to mount `/var/log`:

```yaml
volumeMounts:
  - name: varlog
    mountPath: /var/log
volumes:
  - name: varlog
    hostPath:
      path: /var/log
```

2. Reapply Alloy deployment.

---

## Repository Structure

```
k8s-logging-stack/
│
├─ README.md
├─ helm-values/
│   ├─ alloy-values.yaml
│   ├─ loki-values.yaml
│   └─ grafana-values.yaml
└─ manifests/
    └─ namespace.yaml
```

* `helm-values/` – Helm values files for Alloy, Loki, Grafana
* `manifests/` – Kubernetes manifests like namespaces or RBAC
* `README.md` – This file

---

## References

* [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
* [Loki Documentation](https://grafana.com/docs/loki/latest/)
* [Grafana Documentation](https://grafana.com/docs/grafana/latest/)