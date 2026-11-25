# Kubernetes Microservices Deployment & Observability Stack (`devops-k8s-monitoring`)

Production-style deployment of a containerized Java web microservice (`devops-app`) on Kubernetes, packaged with **Helm 3**, monitored with **kube-prometheus-stack (Prometheus & Grafana)**, validated via automated health/smoke Bash scripts, and demonstrated live on **AWS EC2 (k3s)**.

---

## Architecture Overview
```text
+-----------------------------------------------------------------------+
|                         Kubernetes Cluster                            |
|                  (Multi-Node kind & Single-Node k3s)                  |
|                                                                       |
|  +-----------------------------+   +-------------------------------+  |
|  |   Namespace: devops-app     |   |    Namespace: monitoring      |  |
|  |                             |   |                               |  |
|  |  +-----------------------+  |   |  +-------------------------+  |  |
|  |  | Deployment:devops-app |  |   |  | Prometheus Operator     |  |  |
|  |  |  - Replicas: 2        |  |   |  |  - ServiceMonitor /     |  |  |
|  |  |  - Probes: /health    |<-+---+--|    cAdvisor / kube-state|  |  |
|  |  |  - Limits: 250m / 256M|  |   |  |  - PrometheusRule alerts|  |  |
|  |  +-----------+-----------+  |   |  +------------+------------+  |  |
|  |              |              |   |               |               |  |
|  |  +-----------v-----------+  |   |  +------------v------------+  |  |
|  |  | Service: NodePort     |  |   |  | Grafana Dashboards      |  |  |
|  |  |  - Port 80 -> 30080   |  |   |  |  - DevOps App Overview  |  |  |
|  |  +-----------------------+  |   |  +-------------------------+  |  |
|  +-----------------------------+   +-------------------------------+  |
+-----------------------------------------------------------------------+
```
---

## Repository Structure


```text
devops-k8s-monitoring/
├── aws-k3s-demo/
│   └── deploy-k3s.sh                 # Automated k3s + Helm 3 bootstrap script for AWS EC2
├── docs/
│   └── screenshots/                  # Verification screenshots & PromQL query export
├── helm/
│   └── devops-app/                   # Parameterized Helm 3 chart (Deployment, Service, ConfigMap, Probes)
├── k8s-manifests/                    # Baseline Kubernetes YAML manifests (Namespace, Deployment, Service)
├── kind/
│   └── kind-config.yaml              # 3-node kind cluster topology (1 control-plane, 2 workers, port 30080)
├── monitoring/
│   ├── alert-rules.yaml              # Custom PrometheusRule (CrashLoopBackOff, NotReady, HighMemory)
│   └── dashboards/
│       └── devops-app.json           # Exported Grafana dashboard JSON model
└── scripts/
    ├── cluster_health.sh             # Node readiness, pod status, and restart audit script
    └── k8s_smoke_test.sh             # Rollout wait and HTTP /health verification script
```
---

## Key Engineering Highlights

- **Multi-Node Kubernetes Topology (kind):** Provisioned a 3-node local cluster (1 control-plane, 2 workers) with `extraPortMappings` exposing NodePort `30080` directly to the host.
- **Parameterized Helm 3 Packaging:** Converted raw manifests into a reusable chart (`helm/devops-app`) supporting configurable replica counts, image tags, resource requests/limits (100m/128Mi requests, 250m/256Mi limits), ConfigMap environment injection, liveness/readiness probes on `/health`, zero-downtime `helm upgrade`, and instant `helm rollback`.
- **Prometheus & Grafana Observability:** Deployed `kube-prometheus-stack` in the `monitoring` namespace, built a custom **DevOps App Overview** Grafana dashboard tracking pod CPU, working-set memory, and available replicas, validated CPU quota spikes under synthetic load, and authored a `PrometheusRule` (`devops-app-alerts`) verified live by inducing a CrashLoopBackOff pod (`DevOpsAppPodCrashLooping` firing state).
- **Live Cloud Deployment on AWS EC2 (k3s):** Automated single-node k3s and Helm 3 provisioning (`aws-k3s-demo/deploy-k3s.sh`) on Ubuntu EC2, exposing `/health` and `/hello` publicly via NodePort `30080`.

---
## Quickstart & Verification

### 1. Deploy Application via Helm

```bash
helm upgrade --install devops-app ./helm/devops-app -n devops-app --create-namespace
./scripts/cluster_health.sh
./scripts/k8s_smoke_test.sh
```

### 2. Apply Custom Prometheus Alert Rules

```bash
kubectl apply -f monitoring/alert-rules.yaml
kubectl get prometheusrules -n monitoring
```
### 3. Deploy Live on AWS EC2 with k3s

```bash
./aws-k3s-demo/deploy-k3s.sh
curl -i http://<EC2_PUBLIC_IP>:30080/health
curl -i "http://<EC2_PUBLIC_IP>:30080/hello?name=AWS-k3s"
```

---
## Screenshots & Proof of Execution

| Milestone | Evidence File |
|---|---|
| Baseline Grafana Kubernetes pod CPU & memory utilization | [baseline-grafana-view.png](docs/screenshots/baseline-grafana-view.png) |
| Grafana CPU utilization surge under synthetic load testing | [grafana-load-test-cpu-spike.png](docs/screenshots/grafana-load-test-cpu-spike.png) |
| Prometheus PromQL CPU, working-set memory, and restart graphs | [PromQL-Queries.pdf](docs/screenshots/PromQL-Queries.pdf) |
| Firing `DevOpsAppPodCrashLooping` alert in Prometheus UI | [DevOpsAppPodCrashLooping.png](docs/screenshots/DevOpsAppPodCrashLooping.png) |
| Live AWS EC2 k3s public NodePort application endpoint | [aws-k3s-live-demo.png](docs/screenshots/aws-k3s-live-demo.png) |
