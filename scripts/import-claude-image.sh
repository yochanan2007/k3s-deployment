#!/bin/bash
# Import Claude development container image into k3s containerd

set -e

IMAGE_TAR="/tmp/claude-dev.tar"

if [ ! -f "$IMAGE_TAR" ]; then
    echo "Error: Image tar file not found at $IMAGE_TAR"
    echo "Please ensure the image has been transferred to the k3s node"
    exit 1
fi

echo "Importing Claude development container image..."
sudo k3s ctr images import "$IMAGE_TAR"

echo "Verifying image import..."
sudo k3s ctr images list | grep claude-dev

echo ""
echo "Image imported successfully!"
echo "Restarting deployment to use local image..."
kubectl rollout restart deployment/claude -n claude

echo "Done! Check deployment status with: kubectl get pods -n claude"
