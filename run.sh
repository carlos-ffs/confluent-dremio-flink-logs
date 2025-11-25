export KUBECONFIG=/Users/cffs/.kube/config
kubectl create namespace argocd --dry-run=client --kubeconfig $KUBECONFIG -o yaml | kubectl apply --kubeconfig $KUBECONFIG -f -

helm repo add argo-cd https://argoproj.github.io/argo-helm
helm dependency build ./charts/argo-cd

helm upgrade --install --atomic argocd ./charts/argo-cd -n argocd --kubeconfig $KUBECONFIG

kubectl apply -f repo.yaml -n argocd --kubeconfig $KUBECONFIG
kubectl apply -f argocd-init.yaml -n argocd --kubeconfig $KUBECONFIG
