#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# export KUBECONFIG=/path/to/your/.kube/config

IS_PRIVATE_GITHUB=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --private-repository)
      IS_PRIVATE_GITHUB=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--private-repository]"
      exit 1
      ;;
  esac
done

echo "Private repository mode: $IS_PRIVATE_GITHUB"

mkdir -p $SCRIPT_DIR/../charts/confluent-resources/tls
if [ ! -f $SCRIPT_DIR/../charts/confluent-resources/tls/ca-key.pem ]; then
  echo "Generating CA key for Confluent Platform"
  openssl genrsa -out $SCRIPT_DIR/../charts/confluent-resources/tls/ca-key.pem 2048
else
  echo "CA key for Confluent Platform already exists"
fi

if [ ! -f $SCRIPT_DIR/../charts/confluent-resources/tls/ca.pem ]; then
  echo "Generating CA cert for Confluent Platform"
  openssl req -new -key $SCRIPT_DIR/../charts/confluent-resources/tls/ca-key.pem -x509 \
    -days 1000 \
    -out $SCRIPT_DIR/../charts/confluent-resources/tls/ca.pem \
    -subj "/C=US/ST=CA/L=MountainView/O=Confluent/OU=Operator/CN=TestCA"
else
  echo "CA cert for Confluent Platform already exists"
fi

kubectl create namespace argocd --dry-run=client --kubeconfig $KUBECONFIG -o yaml | kubectl apply --kubeconfig $KUBECONFIG -f -

if [ "$IS_PRIVATE_GITHUB" = true ]; then
  kubectl apply -f $SCRIPT_DIR/../init-resources/argocd-git-repository.yaml -n argocd --kubeconfig $KUBECONFIG
fi

helm repo add argo-cd https://argoproj.github.io/argo-helm
helm dependency build $SCRIPT_DIR/../charts/argo-cd

helm upgrade --install --atomic argocd $SCRIPT_DIR/../charts/argo-cd -n argocd --kubeconfig $KUBECONFIG

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

echo "Waiting for dremio-license secret to be created..."
ELAPSED=0
while ! kubectl get secret dremio-license -n dremio --kubeconfig $KUBECONFIG >/dev/null 2>&1; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "ERROR: Timeout waiting for dremio-license secret to be created after ${TIMEOUT} seconds"
    echo "Please check if the dremio-secrets.yaml was applied correctly"
    exit 1
  fi
  echo "Waiting for dremio-license secret... (${ELAPSED}s/${TIMEOUT}s)"
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done
echo "dremio-license secret found! Applying secrets..."

kubectl apply -f $SCRIPT_DIR/../init-resources/dremio-secrets.yaml -n dremio --server-side --force-conflicts --kubeconfig $KUBECONFIG
echo "Secrets applied successfully!"

