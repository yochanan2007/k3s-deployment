#!/bin/bash
# Add a new MCP server to MetaMCP
# Usage: ./add-mcp-server.sh <service-name> <namespace> <port> [type]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ "$#" -lt 3 ]; then
    echo -e "${RED}Error: Missing arguments${NC}"
    echo "Usage: $0 <service-name> <namespace> <port> [type]"
    echo ""
    echo "Examples:"
    echo "  $0 authentik authentik 9000 SSE"
    echo "  $0 home-assistant home-assistant 8123 SSE"
    echo "  $0 grafana monitoring 3000 HTTP"
    echo ""
    echo "Parameters:"
    echo "  service-name: Name of the service (e.g., authentik, grafana)"
    echo "  namespace:    Kubernetes namespace where service runs"
    echo "  port:         Service port number"
    echo "  type:         MCP transport type (SSE, STDIO, HTTP) - default: SSE"
    exit 1
fi

SERVICE_NAME="$1"
NAMESPACE="$2"
PORT="$3"
TYPE="${4:-SSE}"

echo -e "${GREEN}Adding MCP server for ${SERVICE_NAME}${NC}"
echo ""

# Generate server configuration
SERVER_CONFIG_DIR="mcp-config/servers"
SERVER_CONFIG_FILE="${SERVER_CONFIG_DIR}/${SERVICE_NAME}-mcp.json"

mkdir -p "$SERVER_CONFIG_DIR"

# Create server configuration
cat > "$SERVER_CONFIG_FILE" <<EOF
{
  "name": "${SERVICE_NAME}",
  "type": "${TYPE}",
  "url": "http://${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:${PORT}/mcp",
  "description": "${SERVICE_NAME} MCP server",
  "enabled": true,
  "metadata": {
    "service": "${SERVICE_NAME}",
    "namespace": "${NAMESPACE}",
    "port": ${PORT},
    "added": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF

echo -e "${GREEN}✓${NC} Created server configuration: ${SERVER_CONFIG_FILE}"

# Ask if user wants to update MetaMCP now
read -p "Do you want to update MetaMCP ConfigMap now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}Updating MetaMCP ConfigMap...${NC}"

    # Run update script
    if [ -f "scripts/update-metamcp-servers.sh" ]; then
        bash scripts/update-metamcp-servers.sh
    else
        echo -e "${YELLOW}Warning: update-metamcp-servers.sh not found${NC}"
        echo "You can manually update by running:"
        echo "  kubectl edit configmap metamcp-config -n metamcp"
    fi
else
    echo ""
    echo -e "${YELLOW}Skipping MetaMCP update${NC}"
    echo ""
    echo "To update later, run:"
    echo "  ./scripts/update-metamcp-servers.sh"
    echo ""
    echo "Or update manually:"
    echo "  kubectl edit configmap metamcp-config -n metamcp"
fi

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "Next steps:"
echo "1. Commit the configuration:"
echo "   git add ${SERVER_CONFIG_FILE}"
echo "   git commit -m 'feat: Add ${SERVICE_NAME} MCP server'"
echo "   git push origin main"
echo ""
echo "2. Verify in MetaMCP UI:"
echo "   https://metamcp.k3s.dahan.house"
echo ""
echo "3. Test the server:"
echo "   kubectl exec -n metamcp deployment/metamcp -- wget -O- http://${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:${PORT}/health"
