# API Token & User Setup Guide

**Purpose:** Complete guide for obtaining API tokens and setting up service accounts for MCP integration

**Last Updated:** 2025-12-21

---

## Table of Contents

1. [Authentik SSO](#1-authentik-sso)
2. [Portainer](#2-portainer)
3. [Rancher](#3-rancher)
4. [AdGuard Home](#4-adguard-home)
5. [Home Assistant](#5-home-assistant)
6. [Proxmox VE](#6-proxmox-ve)
7. [Environment Setup](#7-environment-setup)

---

## 1. Authentik SSO

**Service URL:** https://auth.k3s.dahan.house

### Option A: Create API Token (Recommended)

API tokens provide secure, scoped access without exposing user passwords.

#### Step 1: Login to Authentik Admin

```
URL: https://auth.k3s.dahan.house/if/admin/
```

1. Navigate to admin interface
2. Login with admin credentials

#### Step 2: Navigate to Tokens

```
Admin Panel → Tokens and App passwords → Create
```

Or direct URL:
```
https://auth.k3s.dahan.house/if/admin/#/core/tokens
```

#### Step 3: Create Token

**Click "Create" and configure:**

| Field | Value | Description |
|-------|-------|-------------|
| **Identifier** | `MCP Integration` | Descriptive name for token |
| **User** | Select admin user | User account the token authenticates as |
| **Intent** | `API` | Token purpose (API access) |
| **Expires** | 2026-12-31 or "Never" | Token expiration date |
| **Scopes** | Select all or specific | Permissions granted to token |

**Click "Create"**

#### Step 4: Copy Token

```
Token format: akp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**⚠️ IMPORTANT:** Copy the token immediately. It will only be shown once!

**Store in `.env` file:**
```bash
AUTHENTIK_API_TOKEN="akp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

### Option B: Use CLI to Create Token

If you have `kubectl` access to the cluster:

```bash
# Get shell in authentik-server pod
kubectl exec -n authentik -it deployment/authentik-server -- /bin/bash

# Create API token
ak create_token --identifier "MCP Integration" --expires 2026-12-31

# Output: akp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### API Token Verification

Test the token works:

```bash
TOKEN="akp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

curl -H "Authorization: Bearer $TOKEN" \
     https://auth.k3s.dahan.house/api/v3/core/users/ | jq

# Expected: JSON response with user list
```

### Required Scopes/Permissions

For full MCP functionality, ensure token has access to:
- ✅ **Core** - Users, Groups, Applications
- ✅ **Providers** - OAuth2, SAML, LDAP
- ✅ **Flows** - Authentication flows
- ✅ **Events** - Audit logs
- ✅ **Property Mappings** - Scope mappings
- ✅ **Policies** - Access policies

### API Documentation

- **Base URL:** `https://auth.k3s.dahan.house/api/v3`
- **Auth Header:** `Authorization: Bearer akp_xxx`
- **Docs:** https://docs.goauthentik.io/developer-docs/api/

---

## 2. Portainer

**Service URL:** https://portainer.k3s.dahan.house (assumed)

### Step 1: Login to Portainer

```
URL: https://portainer.k3s.dahan.house
```

1. Login with admin credentials

### Step 2: Navigate to User Settings

```
Click your username (top-right) → My account
```

Or:
```
Settings (left sidebar) → Users → [Your Username]
```

### Step 3: Create Access Token

**Scroll to "Access tokens" section:**

1. **Click "Add access token"**

2. **Configure token:**

| Field | Value | Description |
|-------|-------|-------------|
| **Description** | `MCP Integration` | Descriptive name |
| **Expiry** | 365 days or Custom | Token lifetime |

3. **Click "Add access token"**

### Step 4: Copy Token

```
Token format: ptr_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**⚠️ CRITICAL:** Copy immediately! Token shown only once.

**Store in `.env` file:**
```bash
PORTAINER_API_TOKEN="ptr_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

### Alternative: Create via API

If you already have admin credentials:

```bash
# Step 1: Get JWT token (valid for 8 hours)
curl -X POST https://portainer.k3s.dahan.house/api/auth \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "your-admin-password"
  }' | jq -r '.jwt'

# Output: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

JWT="<jwt-from-above>"

# Step 2: Create access token
curl -X POST https://portainer.k3s.dahan.house/api/users/1/tokens \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "description": "MCP Integration"
  }' | jq

# Output includes: "rawAPIKey": "ptr_xxx"
```

### API Token Verification

```bash
TOKEN="ptr_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

curl -H "X-API-Key: $TOKEN" \
     https://portainer.k3s.dahan.house/api/status | jq

# Expected: JSON with Portainer version info
```

### Required Permissions

- Token inherits permissions from user account
- For full MCP functionality, use admin user or user with:
  - ✅ **Endpoint management**
  - ✅ **Container operations**
  - ✅ **Stack management**
  - ✅ **Volume/Network management**

### API Documentation

- **Base URL:** `https://portainer.k3s.dahan.house/api`
- **Auth Header:** `X-API-Key: ptr_xxx`
- **Docs:** https://docs.portainer.io/api/access

---

## 3. Rancher

**Service URL:** https://rancher.k3s.dahan.house

### Step 1: Login to Rancher

```
URL: https://rancher.k3s.dahan.house
```

1. Login with admin credentials

### Step 2: Navigate to API Keys

**Option A: User Menu**
```
Click avatar (top-right) → Account & API Keys
```

**Option B: Direct Navigation**
```
https://rancher.k3s.dahan.house/dashboard/account
```

### Step 3: Create API Key

1. **Click "Create API Key"**

2. **Configure key:**

| Field | Value | Description |
|-------|-------|-------------|
| **Description** | `MCP Integration` | Descriptive name |
| **Expires** | No expiration / Custom | Token lifetime |
| **Scope** | No Scope (full access) | Permissions |

3. **Click "Create"**

### Step 4: Copy Credentials

Rancher provides **TWO values**:

```
Access Key (Username): token-xxxxx
Secret Key (Password):  xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**⚠️ IMPORTANT:** Copy both immediately! Secret shown only once.

**Combine into Bearer Token:**
```
Format: token-xxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Store in `.env` file:**
```bash
RANCHER_API_TOKEN="token-xxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

### API Token Verification

```bash
TOKEN="token-xxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

curl -H "Authorization: Bearer $TOKEN" \
     https://rancher.k3s.dahan.house/v3/clusters | jq

# Expected: JSON response with cluster list
```

### Alternative: Create via kubectl

If you have cluster access:

```bash
# Create API token using Rancher CLI
kubectl create -n cattle-system secret generic rancher-api-token \
  --from-literal=token="$(rancher login https://rancher.k3s.dahan.house --token auto)"

# Or create via API
curl -X POST https://rancher.k3s.dahan.house/v3/tokens \
  -u "admin:password" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "token",
    "description": "MCP Integration",
    "ttl": 0
  }' | jq
```

### Required Permissions

- Token inherits permissions from user account
- For full MCP functionality, use admin user or user with:
  - ✅ **Cluster management**
  - ✅ **Project/Namespace management**
  - ✅ **Workload management**
  - ✅ **Monitoring access**

### API Documentation

- **Base URL:** `https://rancher.k3s.dahan.house/v3`
- **Auth Header:** `Authorization: Bearer token-xxx:xxx`
- **Docs:** https://rancher.com/docs/rancher/v2.x/en/api/

---

## 4. AdGuard Home

**Service URL:** https://adguard.k3s.dahan.house

### Authentication Method: Basic Auth

AdGuard Home does **NOT** use API tokens. It uses **HTTP Basic Authentication**.

### Step 1: Get Admin Credentials

You should already have:
- **Username:** (e.g., `admin`)
- **Password:** (configured during AdGuard setup)

If you forgot the password, reset via config file:

```bash
# Get shell in AdGuard pod
kubectl exec -n adguard -it deployment/adguard-home -- /bin/sh

# Edit config (set password hash)
vi /opt/adguardhome/conf/AdGuardHome.yaml

# Or reset via kubectl
kubectl exec -n adguard deployment/adguard-home -- \
  /opt/adguardhome/AdGuardHome -s reset-password
```

### Step 2: Store Credentials

**Store in `.env` file:**
```bash
ADGUARD_USERNAME="admin"
ADGUARD_PASSWORD="your-admin-password"
```

### API Authentication

AdGuard uses **HTTP Basic Auth**:

```
Authorization: Basic <base64(username:password)>
```

**Example:**
```bash
USERNAME="admin"
PASSWORD="your-password"

# Create base64 encoded credentials
AUTH=$(echo -n "$USERNAME:$PASSWORD" | base64)

# Make API call
curl -H "Authorization: Basic $AUTH" \
     https://adguard.k3s.dahan.house/control/status | jq

# Expected: JSON with AdGuard status
```

### Simplified Using curl -u Flag

```bash
curl -u "admin:password" \
     https://adguard.k3s.dahan.house/control/status | jq
```

### API Endpoints Reference

Common endpoints:
- `/control/status` - Get AdGuard status
- `/control/stats` - Get DNS statistics
- `/control/querylog` - Query DNS log
- `/control/filtering/status` - Get filtering status
- `/control/clients` - List configured clients
- `/control/rewrite/list` - List DNS rewrites

### API Documentation

- **Base URL:** `https://adguard.k3s.dahan.house/control`
- **Auth:** Basic Auth (username:password)
- **Docs:** https://github.com/AdguardTeam/AdGuardHome/wiki/API

---

## 5. Home Assistant

**Service URL:** https://homeassistant.k3s.dahan.house (assumed)

### Step 1: Login to Home Assistant

```
URL: https://homeassistant.k3s.dahan.house
```

1. Login with your user account

### Step 2: Navigate to Profile

```
Click your username (bottom-left) → Profile
```

Or access directly:
```
https://homeassistant.k3s.dahan.house/profile
```

### Step 3: Create Long-Lived Access Token

**Scroll down to "Long-Lived Access Tokens" section:**

1. **Click "Create Token"**

2. **Configure token:**

| Field | Value |
|-------|-------|
| **Name** | `MCP Integration` |

3. **Click "OK"**

### Step 4: Copy Token

```
Token format: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**⚠️ IMPORTANT:** Copy immediately! Token shown only once.

**Store in `.env` file:**
```bash
HOMEASSISTANT_API_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

### API Token Verification

```bash
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxx"

curl -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     https://homeassistant.k3s.dahan.house/api/ | jq

# Expected: {"message": "API running."}
```

### Test Getting States

```bash
# Get all entity states
curl -H "Authorization: Bearer $TOKEN" \
     https://homeassistant.k3s.dahan.house/api/states | jq

# Get specific entity
curl -H "Authorization: Bearer $TOKEN" \
     https://homeassistant.k3s.dahan.house/api/states/light.living_room | jq
```

### Token Management

**View/Revoke tokens:**
1. Go to Profile → Long-Lived Access Tokens
2. See list of all tokens with creation dates
3. Click delete icon to revoke

**Security Note:** Tokens inherit permissions from the user. Use dedicated service account for MCP if you want limited permissions.

### API Documentation

- **Base URL:** `https://homeassistant.k3s.dahan.house/api`
- **Auth Header:** `Authorization: Bearer eyJ...`
- **Docs:** https://developers.home-assistant.io/docs/api/rest/

---

## 6. Proxmox VE

**Service URL:** https://proxmox.dahan.house:8006

### Step 1: Login to Proxmox Web UI

```
URL: https://proxmox.dahan.house:8006
```

1. Login with root or admin user

### Step 2: Navigate to API Tokens

**Option A: Via Datacenter**
```
Datacenter → Permissions → API Tokens → Add
```

**Option B: Via User**
```
Datacenter → Permissions → Users → [Select User] → API Tokens → Add
```

### Step 3: Create API Token

**Click "Add" and configure:**

| Field | Value | Description |
|-------|-------|-------------|
| **User** | `root@pam` | User account (or dedicated user) |
| **Token ID** | `mcp-integration` | Identifier (lowercase, no spaces) |
| **Privilege Separation** | ☐ Unchecked | Token inherits user permissions |
| **Expire** | Never / Custom | Token expiration |
| **Comment** | `MCP Integration` | Description |

**Click "Add"**

### Step 4: Copy Token Secret

Proxmox shows:

```
Token ID: root@pam!mcp-integration
Secret:   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**⚠️ CRITICAL:** Copy secret immediately! Cannot be retrieved later.

**Store in `.env` file:**
```bash
PROXMOX_API_TOKEN="root@pam!mcp-integration"
PROXMOX_API_SECRET="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Alternative: Create API Token via CLI

SSH to Proxmox host:

```bash
ssh root@proxmox.dahan.house

# Create API token
pveum user token add root@pam mcp-integration --privsep 0

# Output:
# ┌──────────────┬──────────────────────────────────────┐
# │ key          │ value                                │
# ╞══════════════╪══════════════════════════════════════╡
# │ full-tokenid │ root@pam!mcp-integration             │
# ├──────────────┼──────────────────────────────────────┤
# │ info         │ {"privsep":"0"}                      │
# ├──────────────┼──────────────────────────────────────┤
# │ value        │ xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx │
# └──────────────┴──────────────────────────────────────┘
```

### API Authentication

Proxmox API uses **combined token authentication**:

```
Authorization: PVEAPIToken=root@pam!mcp-integration=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**Example API Call:**
```bash
TOKEN_ID="root@pam!mcp-integration"
SECRET="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

curl -k -H "Authorization: PVEAPIToken=${TOKEN_ID}=${SECRET}" \
     https://proxmox.dahan.house:8006/api2/json/version | jq

# Expected: Proxmox version info
```

**Note:** `-k` flag disables SSL verification (common for self-signed certs)

### List All VMs

```bash
curl -k -H "Authorization: PVEAPIToken=${TOKEN_ID}=${SECRET}" \
     https://proxmox.dahan.house:8006/api2/json/nodes/pve/qemu | jq
```

### Required Permissions

For API token without privilege separation (`privsep=0`):
- Token inherits ALL permissions from user
- Use `root@pam` for full access

For restricted token (`privsep=1`), grant specific permissions:
```bash
# Grant VM.Audit permission to token
pveum acl modify / --tokens 'root@pam!mcp-integration' --roles PVEVMAdmin
```

### API Documentation

- **Base URL:** `https://proxmox.dahan.house:8006/api2/json`
- **Auth Header:** `Authorization: PVEAPIToken=USER@REALM!TOKENID=SECRET`
- **Docs:** https://pve.proxmox.com/pve-docs/api-viewer/

---

## 7. Environment Setup

### Create `.env` File

In your project root (`D:\claude\k3s-deployment\`), create `.env`:

```bash
# Authentik SSO
AUTHENTIK_API_TOKEN="akp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Portainer Container Management
PORTAINER_API_TOKEN="ptr_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Rancher Cluster Management
RANCHER_API_TOKEN="token-xxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# AdGuard Home DNS
ADGUARD_USERNAME="admin"
ADGUARD_PASSWORD="your-admin-password"

# Home Assistant
HOMEASSISTANT_API_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Proxmox VE
PROXMOX_API_TOKEN="root@pam!mcp-integration"
PROXMOX_API_SECRET="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Secure `.env` File

**CRITICAL:** Never commit `.env` to git!

```bash
# Add to .gitignore
echo ".env" >> .gitignore

# Verify it's ignored
git status

# Set restrictive permissions (Linux/Mac)
chmod 600 .env
```

### Load Environment Variables

**In your MCP server or scripts:**

**Node.js:**
```javascript
require('dotenv').config();

const authentikToken = process.env.AUTHENTIK_API_TOKEN;
```

**Python:**
```python
from dotenv import load_dotenv
import os

load_dotenv()

authentik_token = os.getenv('AUTHENTIK_API_TOKEN')
```

**Bash:**
```bash
# Source .env file
set -a
source .env
set +a

# Use variables
echo $AUTHENTIK_API_TOKEN
```

---

## Security Best Practices

### 1. Token Storage
- ✅ Store in `.env` file
- ✅ Add `.env` to `.gitignore`
- ✅ Use environment variables in production
- ❌ Never hardcode tokens in source code
- ❌ Never commit tokens to Git

### 2. Token Rotation
- 🔄 Rotate tokens every **90 days**
- 🔄 Rotate immediately if compromised
- 🔄 Rotate when team members leave

### 3. Principle of Least Privilege
- 👤 Create dedicated service accounts
- 🔐 Grant only required permissions
- 📊 Audit token usage regularly

### 4. Monitoring & Auditing
- 📝 Log all API calls
- 🔍 Monitor for unusual activity
- 🚨 Set up alerts for failed auth attempts

### 5. Network Security
- 🔒 Always use HTTPS
- 🛡️ Restrict API access to trusted IPs
- 🔐 Use VPN for remote access

---

## Token Verification Checklist

After creating all tokens, verify each one works:

### Authentik
```bash
curl -H "Authorization: Bearer $AUTHENTIK_API_TOKEN" \
     https://auth.k3s.dahan.house/api/v3/core/users/ | jq -e '.results' && echo "✅ Authentik OK"
```

### Portainer
```bash
curl -H "X-API-Key: $PORTAINER_API_TOKEN" \
     https://portainer.k3s.dahan.house/api/status | jq -e '.Version' && echo "✅ Portainer OK"
```

### Rancher
```bash
curl -H "Authorization: Bearer $RANCHER_API_TOKEN" \
     https://rancher.k3s.dahan.house/v3/clusters | jq -e '.data' && echo "✅ Rancher OK"
```

### AdGuard
```bash
curl -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
     https://adguard.k3s.dahan.house/control/status | jq -e '.version' && echo "✅ AdGuard OK"
```

### Home Assistant
```bash
curl -H "Authorization: Bearer $HOMEASSISTANT_API_TOKEN" \
     https://homeassistant.k3s.dahan.house/api/ | jq -e '.message' && echo "✅ Home Assistant OK"
```

### Proxmox
```bash
curl -k -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}=${PROXMOX_API_SECRET}" \
     https://proxmox.dahan.house:8006/api2/json/version | jq -e '.data' && echo "✅ Proxmox OK"
```

### Run All Checks

Create `verify-tokens.sh`:

```bash
#!/bin/bash

set -a
source .env
set +a

echo "🔍 Verifying API tokens..."
echo ""

# Authentik
if curl -sf -H "Authorization: Bearer $AUTHENTIK_API_TOKEN" \
        https://auth.k3s.dahan.house/api/v3/core/users/ > /dev/null; then
    echo "✅ Authentik: OK"
else
    echo "❌ Authentik: FAILED"
fi

# Portainer
if curl -sf -H "X-API-Key: $PORTAINER_API_TOKEN" \
        https://portainer.k3s.dahan.house/api/status > /dev/null; then
    echo "✅ Portainer: OK"
else
    echo "❌ Portainer: FAILED"
fi

# Rancher
if curl -sf -H "Authorization: Bearer $RANCHER_API_TOKEN" \
        https://rancher.k3s.dahan.house/v3/clusters > /dev/null; then
    echo "✅ Rancher: OK"
else
    echo "❌ Rancher: FAILED"
fi

# AdGuard
if curl -sf -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
        https://adguard.k3s.dahan.house/control/status > /dev/null; then
    echo "✅ AdGuard: OK"
else
    echo "❌ AdGuard: FAILED"
fi

# Home Assistant
if curl -sf -H "Authorization: Bearer $HOMEASSISTANT_API_TOKEN" \
        https://homeassistant.k3s.dahan.house/api/ > /dev/null; then
    echo "✅ Home Assistant: OK"
else
    echo "❌ Home Assistant: FAILED"
fi

# Proxmox
if curl -kfs -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}=${PROXMOX_API_SECRET}" \
        https://proxmox.dahan.house:8006/api2/json/version > /dev/null; then
    echo "✅ Proxmox: OK"
else
    echo "❌ Proxmox: FAILED"
fi

echo ""
echo "✅ Verification complete!"
```

**Make executable and run:**
```bash
chmod +x verify-tokens.sh
./verify-tokens.sh
```

---

## Troubleshooting

### Issue: "401 Unauthorized"

**Causes:**
- Token expired
- Token invalid/revoked
- Wrong token format

**Solutions:**
1. Verify token in `.env` matches created token
2. Check token hasn't expired
3. Recreate token if needed
4. Verify auth header format correct

### Issue: "403 Forbidden"

**Causes:**
- Insufficient permissions
- Token lacks required scopes

**Solutions:**
1. Check token permissions/scopes
2. Use admin user token for testing
3. Grant additional permissions to service account

### Issue: "SSL Certificate Verification Failed"

**Causes:**
- Self-signed certificate (Proxmox)
- Expired certificate
- Certificate mismatch

**Solutions:**
1. For Proxmox: Use `-k` flag or `verify_ssl: false`
2. For others: Check cert-manager certificate status
3. Update certificates if expired

### Issue: Token Works in Browser, Fails in API

**Causes:**
- Different auth methods (cookie vs token)
- CORS issues
- Missing headers

**Solutions:**
1. Verify using correct auth header format
2. Add `Content-Type: application/json` header
3. Check API endpoint path is correct

---

## Summary

After completing this guide, you should have:

- ✅ API tokens for all 6 services
- ✅ `.env` file with all credentials
- ✅ Verified all tokens work
- ✅ `.env` added to `.gitignore`
- ✅ Token security best practices implemented

**Next Steps:**
1. Integrate tokens into MCP server (use `mcp-localproxy-config-extended.json`)
2. Implement MCP tools for each service
3. Test tools via Claude Code
4. Set up token rotation reminders (90 days)

---

**Token Expiration Tracking:**

Create a reminder file `token-expiration.md`:

```markdown
# Token Expiration Tracking

| Service | Created | Expires | Rotate By |
|---------|---------|---------|-----------|
| Authentik | 2025-12-21 | 2026-12-31 | 2026-09-30 |
| Portainer | 2025-12-21 | 2026-12-21 | 2026-09-21 |
| Rancher | 2025-12-21 | Never | 2026-03-21 |
| AdGuard | N/A (password) | N/A | 2026-03-21 |
| Home Assistant | 2025-12-21 | Never | 2026-03-21 |
| Proxmox | 2025-12-21 | Never | 2026-03-21 |

**Rotation Schedule:** Rotate all tokens every 90 days (quarterly)
**Next Rotation:** 2026-03-21
```

---

**Documentation Complete!** 🎉
