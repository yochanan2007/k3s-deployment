# K3s Deployment Patterns

## Standard Deployment Requirements

Every application deployed to this k3s cluster should follow these patterns:

### 1. Service Configuration

Each deployment requires **two services**:

#### ClusterIP Service
- **Purpose**: Internal cluster communication
- **Type**: `ClusterIP`
- **Usage**: Used by pods within the cluster to communicate

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-name
  namespace: app-namespace
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: app-name
  ports:
    - name: http
      port: 80
      targetPort: 9000
```

#### LoadBalancer Service
- **Purpose**: External access via MetalLB
- **Type**: `LoadBalancer`
- **IP Pool**: Auto-assigned from `10.0.200.1-10.0.200.250`
- **Usage**: Provides external IP for accessing the service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-name-lb
  namespace: app-namespace
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: app-name
  ports:
    - name: http
      port: 80
      targetPort: 9000
      protocol: TCP
```

### 2. Traefik Ingress with HTTPS

Every service exposed externally must have:

#### Ingress Resource
- **Class**: `traefik`
- **Entrypoints**: `web,websecure` (HTTP + HTTPS)
- **TLS**: Enabled with Let's Encrypt certificate

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-name-ingress
  namespace: app-namespace
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
spec:
  ingressClassName: traefik
  rules:
    - host: app.k3s.dahan.house
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-name
                port:
                  number: 80
  tls:
    - hosts:
        - app.k3s.dahan.house
      secretName: app-name-tls
```

#### Certificate Resource
- **Issuer**: `letsencrypt-dns` (ClusterIssuer)
- **DNS Challenge**: Cloudflare DNS-01
- **Validation**: Automatic via cert-manager

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-name-certificate
  namespace: app-namespace
spec:
  secretName: app-name-tls
  issuerRef:
    name: letsencrypt-dns
    kind: ClusterIssuer
  dnsNames:
    - app.k3s.dahan.house
```

### 3. Namespace Requirements

Each application should have:
- Dedicated namespace
- Cloudflare API token secret (for DNS-01 challenges)

```bash
kubectl create namespace app-namespace
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=$CLOUDFLARE_API_TOKEN \
  -n app-namespace
```

## Deployment Checklist

For each new application:

- [ ] Create namespace
- [ ] Create Cloudflare API token secret in namespace
- [ ] Deploy application with ClusterIP service
- [ ] Create LoadBalancer service for external access
- [ ] Create Certificate resource for HTTPS
- [ ] Create Ingress resource with TLS configuration
- [ ] Verify certificate is issued (`kubectl get certificate -n namespace`)
- [ ] Test HTTP redirect to HTTPS
- [ ] Verify service is accessible via HTTPS

## Current Deployments

### AdGuard Home
- **Namespace**: `adguard`
- **ClusterIP**: Internal service on port 80
- **LoadBalancer IP**: `10.0.200.1`
- **Domain**: `adguard.k3s.dahan.house`
- **Certificate**: ✅ Valid (Let's Encrypt)

### Traefik
- **Namespace**: `kube-system`
- **LoadBalancer IP**: `10.0.200.2`
- **Ports**: 80 (HTTP), 443 (HTTPS)
- **Dashboard**: `traefik.k3s.dahan.house`

## Infrastructure Components

### MetalLB
- **IP Pool**: `10.0.200.1-10.0.200.250`
- **Mode**: Layer 2 (L2Advertisement)

### Cert-Manager
- **ClusterIssuer**: `letsencrypt-dns`
- **ACME Server**: Let's Encrypt Production
- **Challenge**: DNS-01 (Cloudflare)
- **Email**: `yochanan2007@gmail.com`

### Traefik
- **Version**: 3.5.1
- **Certificate Resolver**: `letsencrypt`
- **DNS Provider**: Cloudflare
- **Dashboard**: Protected with BasicAuth

## Best Practices

1. **Always use HTTPS** - No services should be exposed on HTTP only
2. **Dedicated namespaces** - Each application in its own namespace
3. **Secret management** - Secrets managed via `.env` file, not in Git
4. **Certificate automation** - Let cert-manager handle all certificates
5. **LoadBalancer IPs** - Let MetalLB auto-assign unless specific IP needed
6. **Health checks** - Always configure readiness and liveness probes
7. **Resource limits** - Set appropriate CPU and memory limits

## Troubleshooting

### Certificate Issues
```bash
# Check certificate status
kubectl get certificate -n namespace
kubectl describe certificate cert-name -n namespace

# Check challenge status
kubectl get challenges -n namespace
kubectl describe challenge challenge-name -n namespace
```

### LoadBalancer Issues
```bash
# Check service external IP
kubectl get svc -n namespace

# Check MetalLB configuration
kubectl get ipaddresspools -n metallb-system
kubectl get l2advertisements -n metallb-system
```

### Ingress Issues
```bash
# Check ingress status
kubectl get ingress -n namespace
kubectl describe ingress ingress-name -n namespace

# Check Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
```
