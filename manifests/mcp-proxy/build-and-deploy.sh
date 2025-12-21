#!/bin/bash
set -e

# Build and deploy MCP Proxy to k3s cluster
# Usage: ./build-and-deploy.sh [push|deploy|all]

DOCKER_REGISTRY="localhost:5000"  # Change to your registry
IMAGE_NAME="mcp-proxy"
IMAGE_TAG="1.0.0"
FULL_IMAGE="${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K3S_HOST="johnd@10.0.0.210"
SSH_KEY="${HOME}/.ssh/docker_key"

function build_image() {
    echo "Building Docker image..."
    cd "${SCRIPT_DIR}"
    docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .
    docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${FULL_IMAGE}"
    echo "Image built: ${FULL_IMAGE}"
}

function push_image() {
    echo "Pushing image to registry..."
    docker push "${FULL_IMAGE}"
    echo "Image pushed: ${FULL_IMAGE}"
}

function deploy_k8s() {
    echo "Deploying to k3s cluster..."

    # Update deployment image
    sed -i "s|image: mcp-proxy:.*|image: ${FULL_IMAGE}|g" "${SCRIPT_DIR}/04-deployment.yaml"

    # Apply manifests in order
    for file in "${SCRIPT_DIR}"/*.yaml; do
        if [[ -f "$file" ]]; then
            echo "Applying $(basename "$file")..."
            ssh -i "${SSH_KEY}" "${K3S_HOST}" "cat > /tmp/mcp-proxy-manifest.yaml" < "$file"
            ssh -i "${SSH_KEY}" "${K3S_HOST}" "kubectl apply -f /tmp/mcp-proxy-manifest.yaml"
        fi
    done

    echo "Waiting for deployment to be ready..."
    ssh -i "${SSH_KEY}" "${K3S_HOST}" "kubectl wait --for=condition=available --timeout=120s deployment/mcp-proxy-server -n mcp-proxy"

    echo "Deployment complete!"
    echo ""
    echo "MCP Proxy is now accessible at: https://mcp.k3s.dahan.house/mcp"
    echo "Health check: https://mcp.k3s.dahan.house/health"
}

function show_status() {
    echo "Checking deployment status..."
    ssh -i "${SSH_KEY}" "${K3S_HOST}" "kubectl get all -n mcp-proxy"
    echo ""
    echo "Checking certificate status..."
    ssh -i "${SSH_KEY}" "${K3S_HOST}" "kubectl get certificate -n mcp-proxy"
    echo ""
    echo "Recent logs:"
    ssh -i "${SSH_KEY}" "${K3S_HOST}" "kubectl logs -n mcp-proxy deployment/mcp-proxy-server --tail=20"
}

# Main execution
case "${1:-all}" in
    build)
        build_image
        ;;
    push)
        push_image
        ;;
    deploy)
        deploy_k8s
        ;;
    status)
        show_status
        ;;
    all)
        build_image
        push_image
        deploy_k8s
        show_status
        ;;
    *)
        echo "Usage: $0 [build|push|deploy|status|all]"
        exit 1
        ;;
esac
