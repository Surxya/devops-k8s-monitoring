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

## Components

| Component | Purpose |
|---|---|
| `devops-app` (Java) | Sample microservice exposing `/health` and `/hello` |
| Helm chart (`helm/devops-app`) | Parameterized Deployment, Service, ConfigMap, probes |
| kind | 3-node local cluster (1 control-plane, 2 workers) |
| k3s on AWS EC2 | Single-node cloud demo |
| kube-prometheus-stack | Prometheus, Alertmanager, Grafana, kube-state-metrics |
| `scripts/` | Health audit and smoke test automation |

## Probes & Rollout Strategy

- **Readiness probe (`/health`):** a pod only receives Service traffic once it responds, so a rolling update never routes requests to a pod that isn't ready.
- **Liveness probe (`/health`):** the kubelet restarts a container that stops responding.
- **Rolling update:** `helm upgrade` replaces pods gradually, keeping the old replicas serving until the new ones are ready (zero downtime).
- **Rollback:** `helm history devops-app -n devops-app` lists revisions, and `helm rollback devops-app <REVISION> -n devops-app` restores a previous one.

## Monitoring

- `kube-prometheus-stack` runs in the `monitoring` namespace.
- The **DevOps App Overview** Grafana dashboard (`monitoring/dashboards/devops-app.json`) tracks pod CPU, working-set memory, and available replicas.
- `monitoring/alert-rules.yaml` defines CrashLoopBackOff, NotReady, and HighMemory alerts. `DevOpsAppPodCrashLooping` was verified firing by deliberately inducing a crash loop.

## Lessons Learned

- Probes and resource limits are what make rollouts and alerts meaningful; without them Kubernetes can't tell a healthy pod from a broken one.
- Validating alerts by inducing a real failure is more convincing than just applying the rule.
- Packaging manifests as a Helm chart made the same app deployable on both kind and k3s with minimal changes.
- Keeping cloud demos scripted (`deploy-k3s.sh`) makes them cheap to recreate and cheap to tear down.

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
| Baseline Grafana Kubernetes pod CPU & memory utilization | <img width="959" height="576" alt="baseline Grafana view" src="https://github.com/user-attachments/assets/3580aea2-57a0-4a94-bd4f-08ea39288a84" />


| Grafana CPU utilization surge under synthetic load testing | <img width="953" height="571" alt="grafana-load-test-cpu-spike" src="https://github.com/user-attachments/assets/e4411daf-c255-457a-9a64-bc36014939b2" />


| Prometheus PromQL CPU, working-set memory, and restart graphs | [PromQL Queries.pdf](https://github.com/user-attachments/files/35410232/PromQL.Queries.pdf)


| Firing `DevOpsAppPodCrashLooping` alert in Prometheus UI | <img width="956" height="567" alt="DevOpsAppPodCrashLooping" src="https://github.com/user-attachments/assets/fa5b0df0-4db2-41dd-a83d-9fa645b1bec0" />


| Live AWS EC2 k3s public NodePort application endpoint | <img width="956" height="572" alt="aws-k3s-live-demo" src="https://github.com/user-attachments/assets/095a0394-2128-4a89-8e51-b9caee38e51d" />


