export KUBECONFIG=/Users/cffs/.kube/config
kubectl create namespace argocd --dry-run=client --kubeconfig $KUBECONFIG -o yaml | kubectl apply --kubeconfig $KUBECONFIG -f -

helm repo add argo-cd https://argoproj.github.io/argo-helm
helm dependency build ./charts/argo-cd

helm upgrade --install --atomic argocd ./charts/argo-cd -n argocd --kubeconfig $KUBECONFIG

kubectl apply -f repo.yaml -n argocd --kubeconfig $KUBECONFIG

# After argocd is up and running, we should apply the image pull secret
# with dremio quay credentials and license secret.
# On the other hand, if you are using an EKS, GKE, or AKS,
# you can leverage external-secrets to manage the pull secret seemlessly.
kubectl apply -f dremio-secrets.yaml -n dremio --server-side --kubeconfig $KUBECONFIG
