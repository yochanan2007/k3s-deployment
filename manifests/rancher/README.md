# Rancher Deployment

This directory contains the Kubernetes manifests for deploying Rancher Server on the k3s cluster following standard deployment patterns.

## Service Information

- **Namespace**: `cattle-system`
- **Domain**: `rancher.k3s.dahan.house`
- **ClusterIP Service**: `rancher` (internal cluster communication)
- **LoadBalancer IP**: Auto-assigned from MetalLB pool (10.0.200.1-250)
- **TLS Certificate**: Let's Encrypt (via cert-manager with Cloudflare DNS-01)

## Deployment Files

The manifests are ordered for sequential application:

1. **00-namespace.yaml** - Creates the `cattle-system` namespace
2. **01-rancher-deployment.yaml** - Main Rancher server deployment
3. **02-rancher-service-cluster.yaml** - ClusterIP service for internal access
4. **03-rancher-service-lb.yaml** - LoadBalancer service for external access
5. **04-rancher-ingress.yaml** - Traefik ingress configuration
6. **05-rancher-certificate.yaml** - Let's Encrypt certificate via cert-manager

## Initial Setup

### Prerequisites

- K3s cluster running
- MetalLB configured with IP pool 10.0.200.1-250
- Cert-manager installed with `letsencrypt-dns` ClusterIssuer
- Traefik ingress controller running
- Cloudflare API token configured in `.env` file

### Deploy Rancher

1. Apply the Cloudflare secret to the namespace:
   ```bash
   ./apply-secrets.sh
   ```

2. The manifests will be automatically deployed by Flux CD from the main branch.

## Access Information

### Web Interface

- **URL**: https://rancher.k3s.dahan.house
- **Initial Bootstrap Password**: `admin` (should be changed on first login)

### First Login

1. Navigate to https://rancher.k3s.dahan.house
2. Use the bootstrap password: `admin`
3. Set a new admin password when prompted
4. Configure the server URL if needed

## Configuration

### Bootstrap Password

The bootstrap password is stored in a Kubernetes secret:
```bash
kubectl get secret bootstrap-secret -n cattle-system -o jsonpath='{.data.bootstrapPassword}' | base64 -d
```

To change the bootstrap password before deployment:
```bash
kubectl create secret generic bootstrap-secret \
  --from-literal=bootstrapPassword=YOUR_NEW_PASSWORD \
  -n cattle-system \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Server URL

Rancher will auto-configure the server URL based on the ingress configuration. The URL will be:
- https://rancher.k3s.dahan.house

## Verification

### Check Deployment Status

```bash
# Check all Rancher resources
kubectl get all -n cattle-system

# Check ingress
kubectl get ingress -n cattle-system

# Check certificate status
kubectl get certificate -n cattle-system
kubectl describe certificate rancher-k3s-dahan-house -n cattle-system

# Check LoadBalancer IP assignment
kubectl get svc rancher-lb -n cattle-system
```

### Expected Output

All resources should show as Running/Ready:
```
NAME                           READY   STATUS    RESTARTS   AGE
pod/rancher-xxxxxxxxxx-xxxxx   1/1     Running   0          Xm

NAME                  TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)
service/rancher       ClusterIP      10.43.x.x       <none>         80/TCP,443/TCP
service/rancher-lb    LoadBalancer   10.43.x.x       10.0.200.x     80:xxxxx/TCP,443:xxxxx/TCP

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/rancher   1/1     1            1           Xm
```

Certificate should be Ready:
```
NAME                       READY   SECRET        AGE
rancher-k3s-dahan-house    True    rancher-tls   Xm
```

## Troubleshooting

### Certificate Not Issuing

Check the certificate and challenge status:
```bash
kubectl describe certificate rancher-k3s-dahan-house -n cattle-system
kubectl get challenges -n cattle-system
kubectl describe challenge <challenge-name> -n cattle-system
```

Ensure the Cloudflare API token secret exists:
```bash
kubectl get secret cloudflare-api-token -n cattle-system
```

### Ingress Not Working

Check the ingress status:
```bash
kubectl describe ingress rancher-ingress -n cattle-system
```

Check Traefik logs:
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
```

### LoadBalancer No External IP

Check MetalLB status:
```bash
kubectl get ipaddresspools -n metallb-system
kubectl get l2advertisements -n metallb-system
kubectl logs -n metallb-system -l app=metallb
```

### Rancher Pod Not Starting

Check pod logs:
```bash
kubectl logs -n cattle-system -l app=rancher
kubectl describe pod -n cattle-system -l app=rancher
```

Common issues:
- Bootstrap secret not found
- Insufficient permissions (check service account)
- Resource constraints

## Important Notes

### RBAC Requirements

Rancher requires cluster-admin permissions. The ServiceAccount `rancher` in the `cattle-system` namespace must have the appropriate ClusterRoleBinding:

```bash
kubectl get clusterrolebinding rancher -o yaml
```

This should already exist from the initial Helm deployment.

### Data Persistence

Rancher stores its data in an embedded etcd database within the pod. For production deployments, consider:

1. Using external database (MySQL, PostgreSQL)
2. Implementing proper backup strategies
3. Configuring high availability with multiple replicas

### Security Considerations

1. **Change the bootstrap password** immediately after first login
2. **Enable authentication provider** (LDAP, SAML, OAuth)
3. **Configure RBAC** for user access control
4. **Enable audit logging** for compliance
5. **Regularly update** Rancher to latest stable version

## Upgrading Rancher

To upgrade Rancher to a newer version:

1. Update the image tag in `01-rancher-deployment.yaml`
2. Commit and push to trigger Flux sync
3. Monitor the rollout:
   ```bash
   kubectl rollout status deployment/rancher -n cattle-system
   ```

Always check the Rancher upgrade documentation for version-specific requirements.

## Integration with K3s

Rancher is configured to manage the local K3s cluster. After login:

1. The local cluster should appear automatically
2. You can import additional clusters
3. Use Rancher for centralized management, monitoring, and GitOps

## Related Documentation

- [Rancher Documentation](https://rancher.com/docs/)
- [K3s with Rancher](https://rancher.com/docs/k3s/latest/en/)
- [Deployment Patterns](../../DEPLOYMENT_PATTERNS.md)
- [Secrets Management](../../SECRETS_MANAGEMENT.md)
