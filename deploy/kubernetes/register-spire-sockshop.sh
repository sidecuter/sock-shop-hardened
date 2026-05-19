#!/bin/bash

NAMESPACE="sock-shop-hardened"
TRUST_DOMAIN="example.org"
CLUSTER_NAME="demo-cluster"

SERVICES=("front-end" "carts" "catalogue" "orders" "payment" "shipping" "user" "queue-master")

NODE_UID=$(kubectl get nodes -o jsonpath='{.items[0].metadata.uid}')
PARENT_ID="spiffe://${TRUST_DOMAIN}/spire/agent/k8s_psat/${CLUSTER_NAME}/${NODE_UID}"

echo "🔐 Регистрация рабочих нагрузок в SPIRE..."
echo "📡 Parent ID: ${PARENT_ID}"
echo "------------------------------------------------"

for SA in "${SERVICES[@]}"; do
  SPIFFE_ID="spiffe://${TRUST_DOMAIN}/ns/${NAMESPACE}/sa/${SA}"
  
  OUTPUT=$(kubectl exec -n spire spire-server-0 -- \
    /opt/spire/bin/spire-server entry create \
    -spiffeID "${SPIFFE_ID}" \
    -parentID "${PARENT_ID}" \
    -selector k8s:ns:${NAMESPACE} \
    -selector k8s:sa:${SA} \
    -x509SVIDTTL 3600 \
    -jwtSVIDTTL 3600 2>&1)

  if echo "$OUTPUT" | grep -qE "(Entry ID|already exists)"; then
    echo "✅ ${SA}"
  else
    echo "❌ ${SA}: $OUTPUT"
  fi
done

echo "------------------------------------------------"
echo "📋 Проверка зарегистрированных записей:"
kubectl exec -n spire spire-server-0 -- \
  /opt/spire/bin/spire-server entry show \
  -selector k8s:ns:${NAMESPACE}