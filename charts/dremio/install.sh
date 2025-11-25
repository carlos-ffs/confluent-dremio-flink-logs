# First, update the ./templates/pull-secret.yaml file with the latest quay robot credentials.
if [ ! -f "./templates/pull-secret.yaml" ]; then
    echo "Error: ./templates/pull-secret.yaml not found"
    exit 1
fi

# Verify and decode the pull secret
if ! DOCKER_CONFIG_JSON=$(cat ./templates/pull-secret.yaml \
    | grep dockerconfigjson \
    | awk '{print $2}' \
    | head -1 \
    | base64 -d); then
    echo "Error: Failed to decode pull secret from ./templates/pull-secret.yaml"
    exit 1
fi

echo "$DOCKER_CONFIG_JSON" > ./config.json
export DOCKER_CONFIG=./config.json

# Verify the config.json is valid JSON
if ! jq empty ./config.json 2>/dev/null; then
    echo "Error: Invalid JSON in decoded pull secret"
    rm -f ./config.json
    exit 1
fi

helm repo add minio https://charts.min.io/
# Update dependencies if they exist, build if they don't
if [ -f "Chart.lock" ]; then
    echo "Updating helm dependencies..."
    helm dependency update .
else
    echo "Building helm dependencies..."
    helm dependency build .
fi

kubectl create namespace dremio --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install --atomic --timeout 15m dremio . -n dremio
