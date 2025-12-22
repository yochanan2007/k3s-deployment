FROM node:18-alpine

# Install Python and pip
RUN apk add --no-cache python3 py3-pip

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY requirements.txt ./

# Install Node.js dependencies
RUN npm ci --only=production

# Install Python dependencies (using Alpine packages where available)
RUN apk add --no-cache py3-requests

# Copy application files
COPY server.js ./
COPY portainer_client.py ./

# Create non-root user
RUN addgroup -g 1001 -S codeexec && \
    adduser -u 1001 -S codeexec -G codeexec && \
    chown -R codeexec:codeexec /app

USER codeexec

# Expose HTTP port
EXPOSE 3020

# Set environment variables
ENV PORT=3020 \
    TRANSPORT_MODE=http \
    NODE_ENV=production \
    PYTHONUNBUFFERED=1

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3020/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1) })"

# Start server
CMD ["npm", "start"]
