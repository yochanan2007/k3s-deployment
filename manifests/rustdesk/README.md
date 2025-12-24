# RustDesk Server Deployment

RustDesk is an open-source remote desktop software, an alternative to TeamViewer.

## Architecture

**Components:**
- **hbbs** (ID/Rendezvous Server): Handles client registration and peer discovery
- **hbbr** (Relay Server): Relays traffic when direct P2P connection fails

**Namespace:** `rustdesk`

## Deployment Files

- `00-namespace.yaml` - RustDesk namespace
- `01-pvc.yaml` - PersistentVolumeClaim (1Gi for data storage)
- `02-hbbs-deployment.yaml` - hbbs deployment
- `03-hbbr-deployment.yaml` - hbbr relay deployment
- `04-service.yaml` - LoadBalancer services for direct protocol access
- `06-ingressroute.yaml` - Traefik IngressRoute for HTTPS access (web client + WebSocket)
- `07-certificate.yaml` - (Optional) Namespace-specific TLS certificate
- `08-webclient-deployment.yaml` - RustDesk web client deployment
- `09-webclient-service.yaml` - ClusterIP service for web client

## Access Methods

### Web Client (HTTPS) - Internet Access
- **URL:** https://rustdesk.k3s.dahan.house
- **Port:** 443 (HTTPS via Traefik)
- **Certificate:** Let's Encrypt (via wildcard or dedicated cert)
- **Purpose:** Web-based RustDesk client for remote desktop connections
- **Features:**
  - Access RustDesk from any browser
  - No client installation required
  - WebSocket connection to hbbs server on port 21118

### Direct Protocol Access (LoadBalancer) - RustDesk Clients
- **hbbs Service:** `rustdesk-lb`
  - Ports: 21114-21118 (TCP/UDP)
  - LoadBalancer IP: (check with `kubectl get svc -n rustdesk`)
- **hbbr Service:** `rustdesk-relay-lb`
  - Ports: 21117 (relay), 21119 (websockets)
  - LoadBalancer IP: (check with `kubectl get svc -n rustdesk`)

**Purpose:** Direct client connections for RustDesk applications

## Port Reference

| Port  | Protocol | Service | Purpose                          | Access Method |
|-------|----------|---------|----------------------------------|---------------|
| 8000  | TCP      | webclient | Web client UI                 | Ingress (HTTPS) |
| 21115 | TCP      | hbbs    | NAT type test                    | LoadBalancer |
| 21116 | TCP/UDP  | hbbs    | ID registration & heartbeat      | LoadBalancer |
| 21117 | TCP      | hbbr    | Relay server                     | LoadBalancer |
| 21118 | TCP      | hbbs    | WebSocket for web client         | Ingress (HTTPS `/ws`) |
| 21119 | TCP      | hbbr    | WebSocket (relay)                | LoadBalancer |

## Deployment

### Initial Deployment
```bash
kubectl apply -f manifests/rustdesk/
```

### Update Ingress and Web Client
```bash
kubectl apply -f manifests/rustdesk/08-webclient-deployment.yaml
kubectl apply -f manifests/rustdesk/09-webclient-service.yaml
kubectl apply -f manifests/rustdesk/06-ingressroute.yaml
```

### Use Namespace-Specific Certificate (if needed)
If the wildcard certificate from `kube-system` namespace doesn't work:

1. Apply the certificate resource:
   ```bash
   kubectl apply -f manifests/rustdesk/07-certificate.yaml
   ```

2. Update the IngressRoute to use the new secret:
   ```bash
   # Edit 06-ingressroute.yaml
   # Change: secretName: k3s-dahan-house-tls
   # To: secretName: rustdesk-tls
   kubectl apply -f manifests/rustdesk/06-ingressroute.yaml
   ```

## Verification

### Check Services
```bash
kubectl get svc -n rustdesk
```

Expected output:
- `rustdesk-lb` (LoadBalancer with external IP)
- `rustdesk-relay-lb` (LoadBalancer with external IP)
- `rustdesk-webclient` (ClusterIP)

### Check Ingress
```bash
kubectl get ingressroute -n rustdesk
```

### Check Certificate (if using namespace-specific)
```bash
kubectl get certificate -n rustdesk
kubectl describe certificate rustdesk-tls -n rustdesk
```

### Test Web Client Access
```bash
curl -I https://rustdesk.k3s.dahan.house
```

Should return HTTP 200 or redirect with valid TLS certificate.

### Check Pods
```bash
kubectl get pods -n rustdesk
kubectl logs -n rustdesk deployment/rustdesk-hbbs
kubectl logs -n rustdesk deployment/rustdesk-hbbr
kubectl logs -n rustdesk deployment/rustdesk-webclient
```

Expected pods:
- `rustdesk-hbbs-*` (Running)
- `rustdesk-hbbr-*` (Running)
- `rustdesk-webclient-*` (Running)

## Client Configuration

### For RustDesk Clients
When configuring RustDesk client applications, use the **LoadBalancer IP addresses**:

1. Get the LoadBalancer IPs:
   ```bash
   kubectl get svc -n rustdesk
   ```

2. Configure RustDesk client:
   - **ID Server:** `<rustdesk-lb-ip>:21116`
   - **Relay Server:** `<rustdesk-relay-lb-ip>:21117`
   - **Key:** Get from server logs or web console

### For Web Access
Simply navigate to: https://rustdesk.k3s.dahan.house

## DNS Configuration

Ensure DNS record exists:
```
rustdesk.k3s.dahan.house  →  10.0.0.241 (Traefik LoadBalancer IP)
```

Add to Cloudflare DNS or local DNS server.

## Security Notes

1. **Firewall Rules:** Ensure ports 21114-21119 are accessible from the internet if using RustDesk over the internet
2. **TLS Certificate:** Web console uses Let's Encrypt certificate for HTTPS
3. **Authentication:** Configure RustDesk authentication in the web console
4. **Network Access:** LoadBalancer services expose RustDesk to the network

## Troubleshooting

### Web Console Not Accessible
1. Check ingress route: `kubectl get ingressroute -n rustdesk`
2. Check DNS resolution: `nslookup rustdesk.k3s.dahan.house`
3. Check certificate: `kubectl get certificate -n rustdesk` (if using namespace-specific)
4. Check Traefik logs: `kubectl logs -n kube-system deployment/traefik`

### Clients Cannot Connect
1. Verify LoadBalancer IPs: `kubectl get svc -n rustdesk`
2. Check hbbs logs: `kubectl logs -n rustdesk deployment/rustdesk-hbbs`
3. Check hbbr logs: `kubectl logs -n rustdesk deployment/rustdesk-hbbr`
4. Verify firewall allows ports 21114-21119

### Certificate Errors
If you see certificate errors when accessing the web console:

1. Check if wildcard certificate exists:
   ```bash
   kubectl get secret k3s-dahan-house-tls -n kube-system
   ```

2. If it doesn't work, use namespace-specific certificate:
   ```bash
   kubectl apply -f manifests/rustdesk/07-certificate.yaml
   ```

3. Update IngressRoute to use `rustdesk-tls` secret

## References

- [RustDesk Server Documentation](https://rustdesk.com/docs/en/self-host/)
- [Traefik IngressRoute Documentation](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
