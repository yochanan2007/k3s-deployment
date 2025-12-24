# Claude Code Development Home

A comprehensive development environment deployed on k3s for Claude Code with all necessary development tools.

## Overview

This deployment creates a full-featured development container with:
- Ubuntu 22.04 base system
- SSH server for remote access
- Complete development toolchain (Python, Node.js, Docker CLI, kubectl)
- Build tools and utilities
- Persistent 20Gi workspace
- Web status interface
- HTTPS ingress via Traefik

## Deployment Architecture

### Resources Created

1. **Namespace**: `claude-code-home`
2. **PersistentVolumeClaim**: 20Gi workspace storage
3. **ConfigMap**: Initialization script with marker-based optimization
4. **Deployment**: Ubuntu container with auto-installation
5. **Services**:
   - ClusterIP: Internal cluster access (SSH:22, HTTP:8080)
   - LoadBalancer: External SSH access at `10.0.200.14:22`
6. **IngressRoute**: HTTPS access at `https://claude.k3s.dahan.house`

### Network Access

- **SSH**: `ssh claude@10.0.200.14` (password: `claude123`)
- **HTTPS**: `https://claude.k3s.dahan.house` (status web interface)
- **ClusterIP**: Internal cluster services

## Installed Tools

### Development Tools
- **Python 3.10** with pip and venv
- **Node.js 20.x** with npm
- **Docker CLI** (29.1.3)
- **kubectl** (latest stable)
- **Git** (2.34.1)

### Utilities
- **Editors**: vim, nano
- **Build**: build-essential (gcc, make, g++)
- **Networking**: curl, wget, net-tools, dnsutils
- **Monitoring**: htop
- **Compression**: zip, unzip, bzip2, xz-utils
- **Others**: jq, yq, tmux, screen, tree, rsync

### Package Managers
- **apt**: Ubuntu package manager
- **pip**: Python package installer
- **npm**: Node.js package manager

## Initialization Process

The deployment uses an intelligent initialization system:

### First Run (Initial Installation)
1. Container starts and checks for marker file `/home/claude/workspace/.initialized`
2. If not found, runs complete package installation (~5-10 minutes)
3. Installs all development tools and dependencies
4. Creates `claude` user with sudo access
5. Configures SSH server
6. Starts web status server on port 8080
7. Creates marker file to prevent re-initialization
8. Starts SSH daemon

### Subsequent Runs (Fast Restart)
1. Detects marker file exists
2. Skips package installation
3. Directly starts SSH server (~5 seconds)

This approach ensures:
- First deployment takes time but installs everything
- Container restarts are nearly instant
- No repeated package downloads

## Health Probes

### Readiness Probe
- **Type**: TCP Socket (port 22)
- **Initial Delay**: 30 seconds
- **Period**: 10 seconds
- **Failure Threshold**: 30 (allows 5 minutes for initialization)

### Liveness Probe
- **Type**: TCP Socket (port 22)
- **Initial Delay**: 60 seconds
- **Period**: 20 seconds
- **Failure Threshold**: 3

## User Configuration

### Default User
- **Username**: `claude`
- **Password**: `claude123` (change after first login!)
- **UID/GID**: 1000/1000
- **Home**: `/home/claude`
- **Workspace**: `/home/claude/workspace` (persistent)
- **Sudo**: Passwordless sudo access

### SSH Configuration
- Password authentication: Enabled
- Public key authentication: Enabled
- Root login: Disabled
- Allowed users: `claude` only

## Web Interface

A simple status web server runs on port 8080, accessible via:
- Internally: `http://claude-code-home.claude-code-home.svc.cluster.local:8080`
- Externally: `https://claude.k3s.dahan.house`

The interface shows:
- System status
- Installed tool versions
- Connection information

## Persistent Storage

The `/home/claude/workspace` directory is backed by a 20Gi PersistentVolume using the `local-path` storage class. This ensures:
- All files in workspace survive pod restarts
- Code, projects, and data persist across deployments
- Initialization marker file persists (enabling fast restarts)

## Resource Limits

### Requests
- CPU: 250m (0.25 cores)
- Memory: 512Mi

### Limits
- CPU: 2000m (2 cores)
- Memory: 2Gi

## Usage Examples

### Connect via SSH
```bash
ssh claude@10.0.200.14
# Password: claude123
```

### Access from within cluster
```bash
kubectl exec -it <your-pod> -- ssh claude@claude-code-home.claude-code-home.svc.cluster.local
```

### Upload files
```bash
scp myfile.py claude@10.0.200.14:/home/claude/workspace/
```

### Download files
```bash
scp claude@10.0.200.14:/home/claude/workspace/myfile.py ./
```

## Environment Variables

The user environment includes helpful aliases:
- `ll`: `ls -alF`
- `k`: `kubectl`
- `kgp`: `kubectl get pods`
- `kgs`: `kubectl get svc`
- `kgn`: `kubectl get nodes`

## Customization

### Adding More Tools

Edit `D:\claude\k3s-deployment\manifests\claude-code-home\01a-claude-home-configmap.yaml` and add apt packages or npm/pip installations to the initialization script.

### Changing User Password

After first login:
```bash
ssh claude@10.0.200.14
passwd
# Enter new password
```

### Installing Additional Software

As the claude user with sudo:
```bash
sudo apt update
sudo apt install <package-name>
```

Or use pip/npm:
```bash
pip install <package>
npm install -g <package>
```

## Troubleshooting

### Pod not becoming ready
Check initialization logs:
```bash
kubectl logs -n claude-code-home -l app.kubernetes.io/name=claude-code-home --follow
```

### SSH connection refused
Wait for initialization to complete. First run takes 5-10 minutes.

### Forgot password
Reset by executing into the pod:
```bash
kubectl exec -n claude-code-home -it <pod-name> -- passwd claude
```

### Need to re-initialize
Delete the marker file:
```bash
kubectl exec -n claude-code-home <pod-name> -- rm /home/claude/workspace/.initialized
kubectl delete pod -n claude-code-home -l app.kubernetes.io/name=claude-code-home
```

## Maintenance

### Update manifests
```bash
# Edit manifests in manifests/claude-code-home/
git add manifests/claude-code-home/
git commit -m "Update claude-code-home configuration"
git push origin main
# Fleet will auto-deploy changes
```

### Force re-deployment
```bash
kubectl rollout restart deployment claude-code-home -n claude-code-home
```

### View all resources
```bash
kubectl get all,pvc,ingressroute -n claude-code-home
```

## Security Considerations

1. **Change default password** immediately after first login
2. **Set up SSH keys** for passwordless authentication
3. **Disable password auth** after SSH keys are configured
4. **Review sudo permissions** based on your security requirements
5. **Monitor container** for unauthorized access

## Files

- `00-namespace.yaml`: Namespace definition
- `01-claude-home-pvc.yaml`: Persistent volume claim (20Gi)
- `01a-claude-home-configmap.yaml`: Initialization script
- `02-claude-home-deployment.yaml`: Main deployment with health probes
- `03-claude-home-service.yaml`: ClusterIP service
- `04-claude-home-service-lb.yaml`: LoadBalancer for SSH (10.0.200.14)
- `05-claude-home-ingress.yaml`: Traefik IngressRoute (HTTPS)

## Support

For issues or improvements, update the manifests and commit to the repository. The GitOps workflow will automatically sync changes to the cluster.
