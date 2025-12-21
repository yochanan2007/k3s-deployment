FROM node:18-alpine

# Install kubectl for Kubernetes operations
RUN apk add --no-cache curl && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/ && \
    apk del curl

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application files
COPY mcp-proxy-server.js ./

# Create non-root user
RUN addgroup -g 1001 -S mcpproxy && \
    adduser -u 1001 -S mcpproxy -G mcpproxy && \
    chown -R mcpproxy:mcpproxy /app

USER mcpproxy

# Expose HTTP port
EXPOSE 3010

# Set environment variables
ENV PORT=3010 \
    TRANSPORT_MODE=http \
    NODE_ENV=production

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3010/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1) })"

# Start server
CMD ["npm", "start"]
