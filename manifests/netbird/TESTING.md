# Netbird Deployment Testing Guide

This guide provides step-by-step testing procedures for the Netbird VPN client deployment.

## Prerequisites

1. SSH access to k3s cluster: `ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210`
2. Valid Netbird setup key (from Netbird management console)
3. DNS resolution for `netbird.k3s.dahan.house`

## Quick Start Testing

### 1. Configure Setup Key

Before deployment will work, configure the setup key:

```bash
# SSH to cluster
ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210

# Create secret with your setup key
kubectl create secret generic netbird-setup-key \
  --from-literal=setup-key=YOUR_ACTUAL_SETUP_KEY \
  -n netbird

# Update deployment to use secret
kubectl set env deployment/netbird-client \
  -n netbird \
  NB_SETUP_KEY- \
  --keys NB_SETUP_KEY

kubectl set env deployment/netbird-client \
  -n netbird \
  --from=secret/netbird-setup-key
```

Or edit the deployment directly:

```bash
kubectl edit deployment netbird-client -n netbird
```

Change the env section to:

```yaml
env:
  - name: TZ
    value: "America/New_York"
  - name: NB_SETUP_KEY
    valueFrom:
      secretKeyRef:
        name: netbird-setup-key
        key: setup-key
  - name: NB_HOSTNAME
    value: "k3s-netbird-client"
```

### 2. Wait for Fleet Deployment

Fleet should auto-deploy within 1-2 minutes after merge to main.

```bash
# Check Fleet status
kubectl get bundles -A

# Check if netbird namespace exists
kubectl get ns netbird
```

### 3. Verify Pod Running

```bash
# Check pod status
kubectl get pods -n netbird -w

# Expected output:
# NAME                             READY   STATUS    RESTARTS   AGE
# netbird-client-xxxxxxxxxx-xxxxx  1/1     Running   0          1m
```

### 4. Check Pod Logs

```bash
# View logs
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-client -f

# Look for success messages:
# - "Connected to Management Service"
# - "Peer connection established"
# - No error messages about setup key
```

### 5. Verify Netbird Connection

```bash
# Get pod name
POD=$(kubectl get pod -n netbird -l app.kubernetes.io/name=netbird-client -o jsonpath='{.items[0].metadata.name}')

# Check Netbird status
kubectl exec -n netbird -it $POD -- netbird status
```

**Expected output**:
```
Daemon status: Connected
Management: Connected
Signal: Connected
NetBird IP: 100.x.x.x/16
Peers count: X/X Connected
```

### 6. Test LoadBalancer IP

```bash
# Get LoadBalancer IP
LB_IP=$(kubectl get svc netbird-lb -n netbird -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "LoadBalancer IP: $LB_IP"

# Test from cluster (or local network)
curl -I http://$LB_IP
```

### 7. Test HTTPS Ingress

```bash
# From any machine with DNS resolution
curl -I https://netbird.k3s.dahan.house

# Or test DNS resolution first
nslookup netbird.k3s.dahan.house

# Expected: Should resolve to Traefik LoadBalancer IP (10.0.200.2 or similar)
```

### 8. Check Certificate

```bash
# Check certificate status
kubectl get certificate -n netbird

# Should show:
# NAME          READY   SECRET        AGE
# netbird-tls   True    netbird-tls   Xm

# Describe certificate for details
kubectl describe certificate netbird-tls -n netbird
```

### 9. Test from Browser

Open in browser: `https://netbird.k3s.dahan.house`

- Certificate should be valid (Let's Encrypt)
- No security warnings
- Page should load (may show default page if no web interface)

## Detailed Testing Checklist

### Infrastructure Tests

- [ ] Namespace `netbird` exists
- [ ] PVC `netbird-config` is bound
- [ ] Deployment `netbird-client` has 1/1 ready replicas
- [ ] Pod is in `Running` state
- [ ] ClusterIP service `netbird` exists
- [ ] LoadBalancer service `netbird-lb` has external IP
- [ ] Ingress `netbird-ingress` exists
- [ ] TLS secret `netbird-tls` exists

### Network Tests

- [ ] LoadBalancer IP is assigned from MetalLB pool (10.0.200.x)
- [ ] Can curl LoadBalancer IP from local network
- [ ] DNS resolves `netbird.k3s.dahan.house`
- [ ] HTTPS ingress responds without certificate errors
- [ ] Certificate is valid and from Let's Encrypt

### Netbird Functionality Tests

- [ ] Pod logs show successful connection to management
- [ ] `netbird status` shows daemon connected
- [ ] `netbird status` shows management connected
- [ ] `netbird status` shows signal connected
- [ ] NetBird IP is assigned (100.x.x.x/16)
- [ ] Client appears in Netbird management console
- [ ] Peers can be listed from pod
- [ ] Can ping other Netbird peers from pod (if any)

### Security Tests

- [ ] Pod has required capabilities (NET_ADMIN, SYS_ADMIN, SYS_RESOURCE)
- [ ] Setup key is stored in Secret (not plaintext)
- [ ] TLS certificate is valid
- [ ] HTTPS redirects working (if configured)

## Testing Commands Reference

### Quick Status Check

```bash
# One-liner to check everything
kubectl get all,ingress,certificate,pvc -n netbird
```

### Resource Details

```bash
# Detailed pod info
kubectl describe pod -n netbird -l app.kubernetes.io/name=netbird-client

# Detailed service info
kubectl describe svc netbird-lb -n netbird

# Detailed ingress info
kubectl describe ingress netbird-ingress -n netbird

# Detailed certificate info
kubectl describe certificate netbird-tls -n netbird
```

### Logs and Events

```bash
# Pod logs (follow)
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-client -f

# Previous logs (if pod restarted)
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-client --previous

# Events
kubectl get events -n netbird --sort-by='.lastTimestamp'
```

### Netbird-Specific Commands

```bash
# Get pod name
POD=$(kubectl get pod -n netbird -l app.kubernetes.io/name=netbird-client -o jsonpath='{.items[0].metadata.name}')

# Netbird status
kubectl exec -n netbird -it $POD -- netbird status

# List peers
kubectl exec -n netbird -it $POD -- netbird peers list

# Show version
kubectl exec -n netbird -it $POD -- netbird version

# Get logs from inside pod
kubectl exec -n netbird -it $POD -- netbird logs
```

### Network Connectivity Tests

```bash
# Test from pod to internet
kubectl exec -n netbird -it $POD -- ping -c 3 8.8.8.8

# Test DNS from pod
kubectl exec -n netbird -it $POD -- nslookup google.com

# Test to another Netbird peer (replace with actual peer IP)
kubectl exec -n netbird -it $POD -- ping -c 3 100.x.x.x
```

## Troubleshooting Commands

### Pod Issues

```bash
# If pod is crashing
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-client --previous

# Check pod events
kubectl describe pod -n netbird -l app.kubernetes.io/name=netbird-client | grep -A 10 Events

# Force pod restart
kubectl delete pod -n netbird -l app.kubernetes.io/name=netbird-client
```

### Setup Key Issues

```bash
# Check if secret exists
kubectl get secret netbird-setup-key -n netbird

# View secret (base64 encoded)
kubectl get secret netbird-setup-key -n netbird -o yaml

# Update secret
kubectl delete secret netbird-setup-key -n netbird
kubectl create secret generic netbird-setup-key \
  --from-literal=setup-key=NEW_KEY \
  -n netbird

# Restart pod to use new secret
kubectl rollout restart deployment netbird-client -n netbird
```

### LoadBalancer Issues

```bash
# Check MetalLB status
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l app=metallb

# Check service events
kubectl describe svc netbird-lb -n netbird

# Check MetalLB address pools
kubectl get ipaddresspool -n metallb-system
```

### Ingress/Certificate Issues

```bash
# Check Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate request
kubectl get certificaterequest -n netbird
kubectl describe certificaterequest -n netbird

# Force certificate renewal
kubectl delete certificate netbird-tls -n netbird
# Will be auto-recreated by ingress annotation
```

## Success Criteria

Deployment is successful when:

1. ✅ Pod is running without restarts
2. ✅ Pod logs show successful Netbird connection
3. ✅ `netbird status` shows all services connected
4. ✅ LoadBalancer IP is assigned and accessible
5. ✅ HTTPS ingress works with valid certificate
6. ✅ Client appears in Netbird management console
7. ✅ Can reach other Netbird peers from pod

## Common Issues and Solutions

### Issue: Pod in CrashLoopBackOff

**Cause**: Usually missing or invalid setup key

**Solution**:
```bash
# Check logs for error
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-client

# Configure valid setup key (see step 1)
```

### Issue: LoadBalancer IP Pending

**Cause**: MetalLB not running or pool exhausted

**Solution**:
```bash
# Check MetalLB
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system

# Check available IPs in pool (10.0.200.1-250)
kubectl get svc -A | grep LoadBalancer
```

### Issue: Certificate Not Ready

**Cause**: DNS not resolving or cert-manager issues

**Solution**:
```bash
# Check DNS
nslookup netbird.k3s.dahan.house

# Check cert-manager
kubectl get pods -n cert-manager
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate details
kubectl describe certificate netbird-tls -n netbird
```

### Issue: Cannot Access via HTTPS

**Cause**: DNS, certificate, or Traefik issues

**Solution**:
```bash
# Check all components
kubectl get ingress -n netbird
kubectl get certificate -n netbird
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

# Test with curl
curl -v https://netbird.k3s.dahan.house
```

## Performance Testing

### Resource Usage

```bash
# Check pod resource usage
kubectl top pod -n netbird

# Should be well within limits:
# CPU: < 500m
# Memory: < 512Mi
```

### Connection Speed

```bash
# From another Netbird peer, test speed to k3s cluster
# Use iperf3 or similar tools

# Example (if iperf3 available):
kubectl exec -n netbird -it $POD -- iperf3 -s  # In one terminal
iperf3 -c <netbird-ip>  # From peer
```

## Cleanup (If Needed)

```bash
# Delete entire deployment
kubectl delete namespace netbird

# Or delete individual components
kubectl delete -f manifests/netbird/
```

## Next Steps After Successful Testing

1. Configure Netbird routes in management console
2. Set up access control policies
3. Add more peers to the network
4. Configure routing peers for subnet access
5. Monitor performance and connectivity
6. Set up alerts for connection issues

## References

- Deployment README: `manifests/netbird/README.md`
- Deployment Report: `NETBIRD_DEPLOYMENT_REPORT.md`
- Netbird Docs: https://docs.netbird.io/
