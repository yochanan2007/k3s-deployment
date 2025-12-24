# Netbird Client Deployment

This directory contains Kubernetes manifests for deploying a Netbird VPN client to the k3s cluster.

## Overview

Netbird is a zero-config VPN that uses WireGuard to create secure peer-to-peer connections. This deployment runs a Netbird client that can connect your k3s cluster to your Netbird network.

## Components

- **Namespace**: `netbird`
- **Storage**: 1Gi PersistentVolumeClaim for Netbird configuration
- **Image**: `netbirdio/netbird:latest`
- **Services**:
  - ClusterIP service for internal access
  - LoadBalancer service (MetalLB auto-assigned IP from 10.0.200.1-250)
- **Ingress**: `netbird.k3s.dahan.house` with HTTPS via cert-manager

## Required Configuration

### Setup Key

Before deploying, you need to configure a Netbird setup key:

1. Log into your Netbird management console (or use Netbird cloud)
2. Create a new setup key for this client
3. Update the deployment with the setup key:

```yaml
env:
  - name: NB_SETUP_KEY
    value: "YOUR_SETUP_KEY_HERE"
```

Alternatively, use a Kubernetes Secret:

```bash
kubectl create secret generic netbird-setup-key \
  --from-literal=setup-key=YOUR_SETUP_KEY_HERE \
  -n netbird

# Then update deployment to use:
env:
  - name: NB_SETUP_KEY
    valueFrom:
      secretKeyRef:
        name: netbird-setup-key
        key: setup-key
```

## Deployment

### Apply Manifests

```bash
# Apply all manifests in order
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-netbird-pvc.yaml
kubectl apply -f 02-netbird-deployment.yaml
kubectl apply -f 03-netbird-service.yaml
kubectl apply -f 04-netbird-service-lb.yaml
kubectl apply -f 05-netbird-ingress.yaml

# Or apply all at once
kubectl apply -f manifests/netbird/
```

### Verify Deployment

```bash
# Check pod status
kubectl get pods -n netbird

# Check services
kubectl get svc -n netbird

# Get LoadBalancer IP
kubectl get svc netbird-lb -n netbird

# Check ingress
kubectl get ingress -n netbird

# View logs
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-client
```

## Network Architecture

- **ClusterIP Service**: Internal cluster access on port 80
- **LoadBalancer Service**: External access via MetalLB-assigned IP
- **Ingress**: HTTPS access at `netbird.k3s.dahan.house`
  - Certificate: Auto-generated via cert-manager (letsencrypt-dns)
  - Router entrypoints: web (80), websecure (443)

## Security Context

The Netbird container requires elevated capabilities for VPN functionality:
- `NET_ADMIN`: Network configuration
- `SYS_ADMIN`: System administration (for eBPF)
- `SYS_RESOURCE`: Resource limits management

## Resource Limits

- **Requests**: 128Mi memory, 100m CPU
- **Limits**: 512Mi memory, 500m CPU

## Troubleshooting

### Pod Not Starting

Check logs for setup key issues:
```bash
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-client
```

### Connection Issues

Verify the Netbird client has registered:
```bash
# Exec into pod
kubectl exec -n netbird -it <pod-name> -- /bin/sh

# Check Netbird status
netbird status
```

### Certificate Issues

Check cert-manager certificate status:
```bash
kubectl describe certificate netbird-tls -n netbird
kubectl get certificaterequest -n netbird
```

## Notes

- The deployment uses `imagePullPolicy: Always` to ensure latest client version
- Hostname is set to `k3s-netbird-client` for easy identification
- Timezone is set to `America/New_York` (adjust as needed)
- PVC uses `local-path` storage class (k3s default)

## References

- [Netbird Documentation](https://docs.netbird.io/)
- [Docker Installation](https://docs.netbird.io/how-to/installation/docker)
- [Kubernetes Deployment](https://docs.netbird.io/how-to/routing-peers-and-kubernetes)
