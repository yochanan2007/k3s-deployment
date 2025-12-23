#!/bin/bash
# Update MetaMCP ConfigMap with all servers from mcp-config/servers/
# This script merges all *.json files in mcp-config/servers/ and updates the ConfigMap

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SERVER_CONFIG_DIR="mcp-config/servers"
TEMP_FILE="/tmp/metamcp-servers-merged.json"

echo -e "${GREEN}Updating MetaMCP server configuration${NC}"
echo ""

# Check if directory exists
if [ ! -d "$SERVER_CONFIG_DIR" ]; then
    echo -e "${YELLOW}Creating ${SERVER_CONFIG_DIR}${NC}"
    mkdir -p "$SERVER_CONFIG_DIR"
fi

# Count server files
SERVER_COUNT=$(find "$SERVER_CONFIG_DIR" -name "*.json" -type f 2>/dev/null | wc -l)

if [ "$SERVER_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No server configuration files found in ${SERVER_CONFIG_DIR}${NC}"
    echo ""
    echo "To add a server, run:"
    echo "  ./scripts/add-mcp-server.sh <service-name> <namespace> <port>"
    exit 0
fi

echo -e "Found ${GREEN}${SERVER_COUNT}${NC} server configuration(s)"
echo ""

# Merge all JSON files
echo "{" > "$TEMP_FILE"

FIRST=true
for file in "$SERVER_CONFIG_DIR"/*.json; do
    if [ -f "$file" ]; then
        SERVER_NAME=$(jq -r '.name' "$file")

        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo "," >> "$TEMP_FILE"
        fi

        echo -n "  \"${SERVER_NAME}\": " >> "$TEMP_FILE"
        jq -c 'del(.name)' "$file" >> "$TEMP_FILE"

        echo -e "  ${GREEN}✓${NC} Added: ${SERVER_NAME}"
    fi
done

echo "" >> "$TEMP_FILE"
echo "}" >> "$TEMP_FILE"

echo ""
echo -e "${YELLOW}Merged configuration:${NC}"
jq . "$TEMP_FILE"
echo ""

# Ask for confirmation
read -p "Update MetaMCP ConfigMap with this configuration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Cancelled${NC}"
    rm "$TEMP_FILE"
    exit 0
fi

# Get current ConfigMap
echo ""
echo -e "${YELLOW}Fetching current ConfigMap...${NC}"

kubectl get configmap metamcp-config -n metamcp -o json > /tmp/metamcp-config-backup.json

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to fetch ConfigMap${NC}"
    echo "Make sure you have kubectl access to the cluster"
    rm "$TEMP_FILE"
    exit 1
fi

echo -e "${GREEN}✓${NC} ConfigMap backed up to: /tmp/metamcp-config-backup.json"

# Update ConfigMap
echo -e "${YELLOW}Updating ConfigMap...${NC}"

# Create patch with the new servers.json
SERVERS_JSON=$(cat "$TEMP_FILE" | jq -c .)

kubectl patch configmap metamcp-config -n metamcp --type merge -p "{\"data\":{\"servers.json\":\"$SERVERS_JSON\"}}"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to update ConfigMap${NC}"
    echo ""
    echo "To restore from backup:"
    echo "  kubectl apply -f /tmp/metamcp-config-backup.json"
    rm "$TEMP_FILE"
    exit 1
fi

# Cleanup
rm "$TEMP_FILE"

echo ""
echo -e "${GREEN}✓ ConfigMap updated successfully!${NC}"
echo ""
echo "MetaMCP will auto-reload the configuration (no restart needed)"
echo ""
echo "Verify in MetaMCP UI:"
echo "  https://metamcp.k3s.dahan.house"
echo ""
echo "Check logs:"
echo "  kubectl logs -n metamcp -l app.kubernetes.io/component=server --tail=50"
