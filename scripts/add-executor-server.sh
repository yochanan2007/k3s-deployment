#!/bin/bash
# Script to add a new MCP server to the executor orchestrator
# Usage: ./add-executor-server.sh <name> <package> <port>

set -e

NAME=$1
PACKAGE=$2
PORT=$3

if [ -z "$NAME" ] || [ -z "$PACKAGE" ] || [ -z "$PORT" ]; then
    echo "Usage: ./add-executor-server.sh <name> <package> <port>"
    echo ""
    echo "Examples:"
    echo "  ./add-executor-server.sh authentik-mcp @cdmx/authentik-mcp 3001"
    echo "  ./add-executor-server.sh my-server @myorg/my-mcp 3002"
    exit 1
fi

CONFIG_FILE="mcp-config/executor/${NAME}.json"

if [ -f "$CONFIG_FILE" ]; then
    echo "Error: Config file already exists: $CONFIG_FILE"
    exit 1
fi

echo "Creating config file: $CONFIG_FILE"

cat > "$CONFIG_FILE" << EOF
{
  "name": "${NAME}",
  "enabled": true,
  "description": "MCP server for ${PACKAGE}",
  "command": "npx",
  "args": [
    "-y",
    "${PACKAGE}"
  ],
  "env": {},
  "port": ${PORT},
  "metadata": {
    "package": "${PACKAGE}",
    "added": "$(date +%Y-%m-%d)",
    "tools": []
  }
}
EOF

echo "✅ Created: $CONFIG_FILE"
echo ""
echo "Next steps:"
echo "1. Edit $CONFIG_FILE to add arguments and environment variables"
echo "2. Add to MetaMCP servers:"
echo "   - Create: mcp-config/servers/${NAME}.json"
echo "   - URL: http://mcp-orchestrator.mcp-executor.svc.cluster.local:${PORT}"
echo "3. Commit and push to GitHub:"
echo "   git add $CONFIG_FILE"
echo "   git commit -m 'feat: Add ${NAME} MCP server'"
echo "   git push origin main"
echo "4. Wait ~5 minutes for auto-deployment"
