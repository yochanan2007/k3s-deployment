# GEMINI.md

## Project Overview

This repository serves as a **verified backup and documentation** for a production K3s Kubernetes cluster located at **10.0.0.210**. The manifests herein are intended to be a mirror of the actual running state of the cluster.

**The primary philosophy of this repository is that the live cluster is the source of truth.** This repository tracks the cluster's state, it does not dictate it.

The following applications are deployed:

*   **AdGuard Home**: A network-wide ad-blocking and privacy protection solution.
*   **Traefik**: A modern reverse proxy and load balancer.
*   **cert-manager**: A tool to automate the management of TLS certificates.
*   **Authentik**: An open-source Identity & Access Management solution.
*   **Rancher**: A complete software stack for teams adopting containers.
*   **MetalLB**: A load-balancer implementation for bare metal Kubernetes clusters.

## Workflow and Development Conventions

### 1. Verification First Workflow
When making changes, they should be applied and tested on the cluster first. The local manifests in this repository must then be updated to match the cluster's state.

1.  **Read Cluster State**: Get the live resource definition from the cluster (`kubectl get <resource> -n <namespace> -o yaml`).
2.  **Compare**: Diff the live YAML against the corresponding local manifest file.
3.  **Update Locally**: Modify the local manifest to mirror the changes from the live cluster.
4.  **Commit**: Commit the updated and verified manifests.

### 2. Branching Strategy
**All edits must be pushed to the `claude-edits` branch.** Merges to the `main` branch are handled manually.

### 3. Secrets Management
Secrets require careful handling and are managed as follows:

*   **Cloudflare API Token**: This token is used by both Traefik (in `kube-system` namespace) and cert-manager (in `cert-manager` namespace). The `cert-manager/01-cloudflare-secret.yaml` is intentionally redacted and must be updated with a real token for a fresh deployment.
*   **Traefik Dashboard Auth**: A BasicAuth secret (`traefik-dashboard-auth` in `kube-system`) is used. A new password hash can be generated with `htpasswd -nb admin <your-password>`.

## Discrepancies Noted
There is a significant conflict between the workflow described above (from `CLAUDE.md`) and the technical setup found in the repository:

*   **Contradictory Tooling**: Files like `GITOPS_SETUP.md` and `flux-config/` describe a fully functional **Flux CD GitOps** setup. In a standard GitOps model, the repository is the source of truth, and changes pushed to `main` are automatically applied to the cluster.
*   **Conflicting Philosophy**: The "cluster-is-truth" workflow is incompatible with the active Flux CD "repo-is-truth" automation. Pushing changes as per the GitOps setup would overwrite manual cluster changes.

**Conclusion:** While the repository is technically configured for a "push-to-deploy" GitOps workflow via Flux CD, the user's explicit instructions state to treat it as a "pull-from-cluster" backup. The instructions in this `GEMINI.md` file reflect the user's stated preference.
