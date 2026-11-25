#!/usr/bin/env bash
set -euo pipefail
curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config
export KUBECONFIG=~/.kube/config
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm upgrade --install devops-app ./helm/devops-app -n devops-app --create-namespace
kubectl rollout status deployment/devops-app -n devops-app --timeout=120s
kubectl get nodes,pods,svc -n devops-app
