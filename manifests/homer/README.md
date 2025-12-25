# Homer Dashboard Deployment

Homer is a simple static homepage for services, acting as a dashboard for the k3s cluster.

## Architecture

**Container Image:** `b4bz/homer:latest`
**Port:** 8080 (container) -> 80 (service)
**Ingress:** homer.k3s.dahan.house
**TLS:** Uses wildcard certificate `k3s-dahan-house-tls`

## Resources

1. **00-namespace.yaml** - Creates `homer` namespace
2. **01-homer-pvc.yaml** - 1Gi PVC for persistent assets and config
3. **02-homer-configmap.yaml** - Initial config.yml with service links
4. **03-homer-deployment.yaml** - Homer deployment with init container
5. **04-homer-service.yaml** - ClusterIP service on port 80
6. **05-homer-ingress.yaml** - Traefik ingress with TLS

## Configuration

The deployment uses an init container pattern to copy the initial config.yml from the ConfigMap to the persistent volume. This allows:
- Initial configuration via ConfigMap
- User customization persists in the PVC
- Config survives pod restarts

### Pre-configured Services

The default config.yml includes links to:

**Infrastructure:**
- Traefik Dashboard (traefik.k3s.dahan.house)
- AdGuard Home (adguard.k3s.dahan.house)
- Rancher (rancher.k3s.dahan.house)

**Applications:**
- Homer (homer.k3s.dahan.house) - self-reference

## Resource Limits

- **CPU Request:** 50m
- **CPU Limit:** 200m
- **Memory Request:** 64Mi
- **Memory Limit:** 128Mi

## Health Checks

- **Liveness Probe:** HTTP GET / on port 8080 (30s initial, 10s period)
- **Readiness Probe:** HTTP GET / on port 8080 (20s initial, 5s period)

## Volume Mounts

- **/www/assets** -> homer-config PVC (stores config.yml and assets)

## Updating Configuration

To update the Homer configuration after deployment:

1. Edit the config.yml in the PVC directly via kubectl:
   ```bash
   kubectl exec -n homer deployment/homer -- vi /www/assets/config.yml
   ```

2. Or update via the web UI (if Homer supports it)

3. Or update the ConfigMap and delete the pod to force recreation:
   ```bash
   kubectl edit configmap homer-config -n homer
   kubectl delete pod -n homer -l app.kubernetes.io/name=homer
   ```

Note: The init container only copies config.yml if it doesn't exist, so updating the ConfigMap won't overwrite existing PVC content unless you delete the pod and the config file.

## Access

Once deployed, access Homer at: **https://homer.k3s.dahan.house**

## Labels

All resources use consistent labeling:
- `app.kubernetes.io/name: homer`

Service selector matches deployment labels for proper routing.
