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
kubeseal --format yaml --controller-namespace kube-system > /Users/j3/Documents/homelab/gitops/manifests/cert-manager/base/cloudflare-api-token-secret.yaml
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

```bash
# Create the secret with your ProtonVPN credentials
kubectl create secret generic transmission-protonvpn-cred \
  --namespace=media \
  --from-literal=PROTONVPN_USERNAME='your-username' \
  --from-literal=PROTONVPN_PASSWORD='your-password' \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > transmission-protonvpn-secret.yaml
  ```