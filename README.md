# GitOps

[![Update Manifest](https://github.com/jetri/gitops/actions/workflows/update-manifest.yaml/badge.svg)](https://github.com/jetri/gitops/actions/workflows/update-manifest.yaml)
![GitHub repo size](https://img.shields.io/github/repo-size/x-real-ip/gitops?logo=Github)
![GitHub commit activity](https://img.shields.io/github/commit-activity/y/x-real-ip/gitops?logo=github)
![GitHub last commit (branch)](https://img.shields.io/github/last-commit/x-real-ip/gitops/main?logo=github)

- [GitOps](#gitops)
  - [Start ArgoCD WebUI](#start-argocd-webui)
  - [Uptime Kuma](#uptime-kuma)

## Deploy NVIDIA K8s Device Plugin**
```bash
#label the gpu node
kubectl label node gpu-node-1 nvidia.com/gpu.present=true

# On your admin machine (not in cluster)
# https://github.com/NVIDIA/k8s-device-plugin
# kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.2/deployments/static/nvidia-device-plugin.yml
helm repo add nvidia https://nvidia.github.io/k8s-device-plugin
helm repo update

helm upgrade --install nvidia-device-plugin nvidia/nvidia-device-plugin \
  --namespace nvidia-device-plugin \
  --create-namespace \
  --set runtimeClassName=nvidia
```

## Install Cert Manager
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml
```
## Install SealedSecret
https://github.com/bitnami-labs/sealed-secrets/releases
```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.31.0/controller.yaml
```

## Create Secret for Cloudflare TLS
```bash
#sample
kubectl create secret generic cloudflare-api-token-secret \
  --namespace cert-manager \
  --from-literal=api-token='TOKEN_HERE' \
  --dry-run=client -o yaml | \
kubeseal --format yaml --controller-namespace kube-system > /Users/j3/Documents/homelab/gitops/manifests/cloudflare/base/cloudflare-api-token-secret.yaml
```

## Install ArgoCD
https://argo-cd.readthedocs.io/en/stable/getting_started/
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

#Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```



## Set democratic-csi secrets
```bash
❯ kubectl create secret generic smbcredentials-coen \
  --namespace democratic-csi \
  --from-literal=mount_flags='username=,password=' \
  --dry-run=client -o yaml | \
  kubeseal --format yaml --controller-namespace kube-system > manifests/democratic-csi/overlay/sealedsecret.yaml
```

## Democratic CSI Mounting Issue
https://github.com/democratic-csi/democratic-csi/issues/85

With persistentVolumeReclaimPolicy: Retain, here's what happens to your data:

  When You Delete Pod and PV:

  1. Pod Deletion: Only removes the running container, volume remains mounted
  2. PV Deletion: Kubernetes removes the PV object but does NOT delete the underlying storage

  Data Location During Deletion:

  Data Remains On TrueNAS:
  - Your iSCSI target iqn.2005-10.org.freenas.ctl:jellyfin-config stays active
  - The backing zvol/dataset on TrueNAS is untouched
  - All Jellyfin config files remain intact in the TrueNAS storage

  When You Recreate PV and Pod:

  Data Restoration Process:
  1. New PV: Points to the same iSCSI target (iqn.2005-10.org.freenas.ctl:jellyfin-config)
  2. Democratic-CSI: Detects existing XFS filesystem on the iSCSI volume
  3. Mount: Mounts the existing filesystem (no formatting needed)
  4. Data Access: Jellyfin pod sees all previous configuration data

  Key Points:

  - Data Source: TrueNAS iSCSI extent/zvol (never deleted)
  - Automatic Recovery: Democratic-CSI recognizes existing filesystem
  - No Data Loss: All Jellyfin settings, databases, metadata preserved

  Example Flow:

  Delete PV/Pod → Data stays on TrueNAS zvol
  Create PV/Pod → CSI mounts existing filesystem → Jellyfin reads old config

  The Retain policy ensures your Jellyfin configuration survives Kubernetes resource deletions, making it safe for
   maintenance and upgrades.

> where does the actual data stored in truenas? I go to truenas shell and go to the pool and dataset but the dataset
   is empty or when I do ls command there is nothing there?

⏺ You're looking in the wrong place! For iSCSI volumes on TrueNAS, the data isn't stored as files you can browse
  with ls. Here's where to find it:

  iSCSI Storage Types on TrueNAS:

  1. Zvol (Block Device) - Most Common:

  # On TrueNAS shell:
  zfs list -t volume | grep jellyfin
  # Shows: pool/jellyfin-config  10G  used_space  -

  # Data is stored as raw blocks in the zvol, not browsable files
  # You can't ls into a zvol - it's a block device

  2. File-based Extent:

  # If using file extent, look for the actual file:
  find /mnt -name "*jellyfin*" -type f
  # Should show: /mnt/pool/dataset/jellyfin-config.img or similar

  Why You Can't See Data:

  Zvol = Block Device:
  - Acts like a raw hard drive
  - Contains XFS filesystem inside
  - Not browsable from TrueNAS shell
  - Data only accessible when mounted by client (Kubernetes)

  To Check Your iSCSI Configuration:

  1. TrueNAS Web UI: Sharing > Block Shares (iSCSI) > Extents
  2. Look for: jellyfin-config extent
  3. Check Type: "Device" (zvol) or "File"

  Access Data Properly:

  The data is there, but stored inside the XFS filesystem within the zvol. You'd need to:
  1. Mount the iSCSI target on a Linux machine
  2. Mount the XFS filesystem
  3. Then browse the Jellyfin config files

  The empty dataset you're seeing is probably the parent dataset, not the actual zvol storage.


## Start ArgoCD WebUI

```bash
argocd admin dashboard -n argocd
```

## Uptime Kuma

A sqlite query to find and replace a part in the monitor url.

```
UPDATE monitor SET url = REPLACE(url, 'old', 'new') WHERE url LIKE '%old%';
```

## Democratic-csi
https://jonathangazeley.com/2021/01/05/using-truenas-to-provide-persistent-storage-for-kubernetes/

## Media

### Transmission

Might need to do this for the transmission folders
```bash
sudo chown 1000:2000 completed watch
```

```bash
# Create the secret with your ProtonVPN credentials
kubectl create secret generic transmission-vpn-cred \
  --namespace=media \
  --from-literal=OPENVPN_USERNAME='' \
  --from-literal=OPENVPN_PASSWORD='' \
  --dry-run=client -o yaml | \
kubectl label --local -f - app=transmission --dry-run=client -o yaml | \
kubeseal --format yaml
```

```bash
 #Prepare Truenas
mkdir -p /mnt/home-lab/media/transmission/{downloads/complete,downloads/incomplete,watch}
sudo chown -R 1000:2000 /mnt/home-lab/media/transmission
sudo chmod -R 775 /mnt/home-lab/media/transmission
```

```bash
echo '
# One-liner to create and seal your ProtonVPN config secret:

kubectl create secret generic protonvpn-config \
  --namespace=media \
  --from-file=node-nl.protonvpn.udp.ovpn=../../../Documents/homelab/sg-19.protonvpn.udp.ovpn \
  --dry-run=client -o yaml | \
kubeseal --format yaml

# Replace "/path/to/your/vpn-config.ovpn" with the actual path to your ProtonVPN config file

# The output will be the complete sealed secret that you can directly use in your YAML file
'
```

## Deploy
### Deploy Core Apps

```bash
# need to create media namespace for cert
# maybe create wildcard during media creating and not during core
kubectl create namespace argocd
k apply -f argocd/app-of-core-apps.yaml
```

### Deploy Media
```bash

```

## Deleting Applications

Deleting Kubernetes Resources in Order
When deleting resources from your Kubernetes cluster, following the proper order helps prevent issues like orphaned resources or unexpected behavior. Based on your ArgoCD app-of-apps setup, here's the recommended deletion order:

Deletion Order for Kubernetes Resources
Workloads/Applications first:

Deployments, StatefulSets, DaemonSets
Jobs, CronJobs
Pods (usually handled by removing their controllers)
Network resources:

Ingresses
Services
Configuration resources:

ConfigMaps
Secrets
Storage resources:

PersistentVolumeClaims (PVCs)
PersistentVolumes (PVs) - if you're managing these directly
RBAC and security resources:

ServiceAccounts
Roles, ClusterRoles
RoleBindings, ClusterRoleBindings
Custom resources and controllers:

ArgoCD Applications
Any other custom resources
Namespaces (only after all resources within them are removed)

For Your ArgoCD Setup
Since you're using ArgoCD with an app-of-apps pattern:

Delete the child applications first:

1. Delete the child applications first:
```bash
# List all applications managed by your app-of-apps
kubectl get applications -n argocd

# Delete each child application
kubectl delete application -n argocd media-entertainment

# Delete manifests
k delete -k manifests/media-entertainment/overlay
```

2. Then delete the app-of-apps application:
```bash
kubectl delete -f /Users/j3/Documents/homelab/gitops/argocd/app-of-apps.yaml
```

3. Alternatively, use the ArgoCD CLI:
```bash
# Delete all applications, which cascades to managed resources
argocd app delete --all

# Or delete app-of-apps specifically
argocd app delete app-of-apps
```