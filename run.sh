#!/usr/bin/env bash
set -euo pipefail

# export KUBECONFIG=/path/to/your/.kube/config

mkdir -p ./charts/confluent-resources/tls
if [ ! -f ./charts/confluent-resources/tls/ca-key.pem ]; then
  echo "Generating CA key for Confluent Platform"
  openssl genrsa -out ./charts/confluent-resources/tls/ca-key.pem 2048
else
  echo "CA key for Confluent Platform already exists"
fi

if [ ! -f ./charts/confluent-resources/tls/ca.pem ]; then
  echo "Generating CA cert for Confluent Platform"
  openssl req -new -key ./charts/confluent-resources/tls/ca-key.pem -x509 \
    -days 1000 \
    -out ./charts/confluent-resources/tls/ca.pem \
    -subj "/C=US/ST=CA/L=MountainView/O=Confluent/OU=Operator/CN=TestCA"
else
  echo "CA cert for Confluent Platform already exists"
fi

kubectl create namespace argocd --dry-run=client --kubeconfig $KUBECONFIG -o yaml | kubectl apply --kubeconfig $KUBECONFIG -f -

helm repo add argo-cd https://argoproj.github.io/argo-helm
helm dependency build ./charts/argo-cd

helm upgrade --install --atomic argocd ./charts/argo-cd -n argocd --kubeconfig $KUBECONFIG

# After argocd is up and running, we should apply the image pull secret
# with dremio quay credentials and license secret.
# On the other hand, if you are using an EKS, GKE, or AKS,
# you can leverage external-secrets to manage the pull secret seemlessly.
echo "Waiting for dremio namespace to be created..."
TIMEOUT=300  # 5 minutes timeout
ELAPSED=0
INTERVAL=5

while ! kubectl get namespace dremio --kubeconfig $KUBECONFIG >/dev/null 2>&1; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "ERROR: Timeout waiting for dremio namespace to be created after ${TIMEOUT} seconds"
    echo "Please check ArgoCD applications and ensure the dremio ApplicationSet is deployed"
    exit 1
  fi
  echo "Waiting for dremio namespace... (${ELAPSED}s/${TIMEOUT}s)"
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "Dremio namespace found! Applying secrets..."
kubectl apply -f dremio-secrets.yaml -n dremio --server-side --force-conflicts --kubeconfig $KUBECONFIG
echo "Secrets applied successfully!"
