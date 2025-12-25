#!/bin/bash

# Build script for Claude development container

set -e

IMAGE_NAME="ghcr.io/dahanhouse/claude-dev:latest"

echo "Building Claude development container..."
docker build -t ${IMAGE_NAME} .

echo ""
echo "Build complete!"
echo "Image: ${IMAGE_NAME}"
echo ""
echo "To push to GitHub Container Registry:"
echo "  1. Login: echo \$GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin"
echo "  2. Push: docker push ${IMAGE_NAME}"
echo ""
echo "To deploy to k3s:"
echo "  kubectl apply -f manifests/claude/"
