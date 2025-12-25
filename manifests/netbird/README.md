# NetBird Self-Hosted Deployment

This directory contains a complete self-hosted NetBird deployment for the k3s cluster. NetBird is a WireGuard-based mesh VPN that allows secure peer-to-peer networking.

## Architecture Overview

The deployment consists of four main components:

1. **Management Server** - Core control plane that manages the network state, peer registration, and configuration
2. **Signal Server** - WebRTC signaling server for peer discovery and connection coordination
3. **Dashboard** - Web UI for managing the NetBird network
4. **Coturn** - TURN/STUN server for NAT traversal and relay when direct P2P connections fail

## Deployment Components

### Management Server
- **Image**: netbirdio/management:latest
- **Ports**: 33073 (gRPC API), 80 (HTTP API)
- **Storage**: 5Gi persistent volume
- **Domain**: netbird-api.k3s.dahan.house
- **Purpose**: Central management and authentication

### Signal Server
- **Image**: netbirdio/signal:latest
- **Ports**: 10000 (gRPC), 80 (HTTP)
- **Storage**: 1Gi persistent volume
- **Domain**: netbird-signal.k3s.dahan.house
- **Purpose**: Peer-to-peer connection signaling

### Dashboard
- **Image**: netbirdio/dashboard:latest
- **Ports**: 80 (HTTP), 443 (HTTPS)
- **Domain**: netbird.k3s.dahan.house
- **Purpose**: Web UI for network management

### Coturn (TURN/STUN)
- **Image**: coturn/coturn:latest
- **Ports**: 3478 (UDP/TCP - TURN), 5349 (TCP - TURN over TLS)
- **LoadBalancer IP**: 10.0.200.17
- **Purpose**: NAT traversal and relay service

## Network Configuration

### Domains
- **Dashboard**: https://netbird.k3s.dahan.house
- **Management API**: https://netbird-api.k3s.dahan.house
- **Signal Server**: https://netbird-signal.k3s.dahan.house
- **TURN Server**: 10.0.200.17:3478 (UDP/TCP)

### DNS Requirements
All domains must resolve to the Traefik LoadBalancer IP (10.0.200.2)

### Certificates
TLS certificates are automatically provisioned via cert-manager using the letsencrypt-dns ClusterIssuer.

## Initial Setup

1. Access the dashboard at: https://netbird.k3s.dahan.house
2. Create an initial admin account
3. Generate setup keys for peer registration

## Adding Peers

To add devices to your NetBird network:

```bash
netbird up --management-url https://netbird-api.k3s.dahan.house:443 --setup-key YOUR_SETUP_KEY
```

## References

- NetBird Documentation: https://docs.netbird.io/
- Self-Hosted Setup Guide: https://docs.netbird.io/selfhosted/selfhosted-quickstart
- NetBird GitHub: https://github.com/netbirdio/netbird
