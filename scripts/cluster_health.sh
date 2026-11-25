#!/usr/bin/env bash
set -uop pipefail
NS="${1:-devops-app}"
echo "=== Nodes ==="
kubectl get nodes
not_ready=$(kubectl get nodes --no-headers | awk '$2!="Ready" {c++} END{print c+0}')
echo "--- Problem pods (if any) ---"
kubectl get pods -n "$NS" --no-headers | awk '$3!="Running" || $4!="0" {print}'

echo "--- Restart counts ---"
kubectl get pods -n "$NS" --output=custom-columns=NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[*].restartCount
echo "--- Resource usage ---"
kubectl top nodes 2>/dev/null || echo "metrics-server not installed on kind - ok"

if [ "$not_ready" -eq 0 ]; then
  echo "RESULT: cluster OK"
else
  echo "RESULT: $not_ready node(s) not Ready"; exit 1
fi
