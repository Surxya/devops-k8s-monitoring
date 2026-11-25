#!/usr/bin/env bash
set -euo pipefail
NS=devops-app
DEPLOY=devops-app

kubectl rollout status deployment/"$DEPLOY" -n "$NS" --timeout=120s

for i in $(seq 1 10); do
  code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:30080/health || true)
  if [ "$code" = "200" ]; then
    echo "PASS: /health returned 200"
    exit 0
  fi
  echo "attempt ${i}/10: HTTP ${code}"
  sleep 2
done

echo "FAIL: /health never returned 200"
exit 1
