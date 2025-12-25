# Claude Development Container Deployment

This directory contains manifests for deploying a Claude development container with the following components:

## Components Installed
- **SHELLNGN**: Web-based shell with HTTPS support
- **curl**: HTTP client
- **Claude Code**: Anthropic's Claude Code CLI
- **VSCode Server (code-server)**: Browser-based VSCode

## Container Image
- **Image**: `ghcr.io/dahanhouse/claude-dev:latest`
- **Base**: Ubuntu 22.04
- **User**: claude (UID 1000)

## Deployment Structure

### Manifests (Apply in Order)
1. **00-namespace.yaml**: Creates `claude` namespace
2. **01-claude-pvc.yaml**: 10Gi persistent volume for /home/claude
3. **02-claude-deployment.yaml**: Main deployment with 3 exposed ports
4. **03-claude-service-ssh.yaml**: LoadBalancer on 10.0.0.241 for SSH
5. **04-claude-service-http.yaml**: ClusterIP for HTTP services
6. **05-claude-ingress.yaml**: Traefik ingress with TLS

### Build Files
- **Dockerfile**: Container image definition
- **entrypoint.sh**: Startup script for services

## Access Points

### HTTPS (SHELLNGN)
- **URL**: https://claude.k3s.dahan.house
- **Port**: 4200 (via Traefik)
- **Auth**: None (disabled)
- **Certificate**: Let's Encrypt via cert-manager

### SSH
- **DNS**: claude-ssh.k3s.dahan.house (recommended to create A record)
- **IP**: 10.0.0.241 (MetalLB LoadBalancer)
- **Port**: 22
- **User**: claude
- **Auth**: Password or SSH key

### VSCode Server
- **Port**: 8080 (internal only, not exposed via Ingress)
- **Auth**: None
- **Access**: Via port-forward or future Ingress rule

## Building the Container Image

To build and push the container image:

```bash
# Build the image
docker build -t ghcr.io/dahanhouse/claude-dev:latest .

# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Push the image
docker push ghcr.io/dahanhouse/claude-dev:latest
```

## Deployment

Following GitOps workflow:
```bash
# Apply all manifests
kubectl apply -f manifests/claude/

# Or apply in order
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-claude-pvc.yaml
kubectl apply -f 02-claude-deployment.yaml
kubectl apply -f 03-claude-service-ssh.yaml
kubectl apply -f 04-claude-service-http.yaml
kubectl apply -f 05-claude-ingress.yaml
```

## Verification

```bash
# Check deployment status
kubectl get all -n claude

# Check PVC status
kubectl get pvc -n claude

# Check ingress
kubectl get ingress -n claude

# Check certificate
kubectl get certificate -n claude

# View logs
kubectl logs -n claude -l app.kubernetes.io/name=claude

# Test SSH
ssh claude@10.0.0.241

# Test HTTPS
curl https://claude.k3s.dahan.house
```

## Security Notes

1. **User Permissions**: Container runs as root initially to set up /home/claude ownership, then services run as claude user
2. **No Authentication**: SHELLNGN and code-server have authentication disabled - suitable for private networks only
3. **SSH Access**: Consider setting up SSH key authentication for better security

## DNS Configuration

For SSH DNS access, add A record:
```
claude-ssh.k3s.dahan.house A 10.0.0.241
```

Or use the IP directly: `ssh claude@10.0.0.241`

## Resource Limits

- **CPU**: 250m request, 1000m limit
- **Memory**: 512Mi request, 2Gi limit
- **Storage**: 10Gi persistent volume

## Troubleshooting

### Pod not starting
```bash
kubectl describe pod -n claude -l app.kubernetes.io/name=claude
kubectl logs -n claude -l app.kubernetes.io/name=claude
```

### SSH connection refused
```bash
# Check SSH service
kubectl get svc -n claude claude-ssh

# Check LoadBalancer IP assignment
kubectl describe svc -n claude claude-ssh
```

### HTTPS not accessible
```bash
# Check ingress
kubectl describe ingress -n claude claude

# Check certificate
kubectl describe certificate -n claude claude-tls
```
