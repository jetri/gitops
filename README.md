# GitOps

[![Update Manifest](https://github.com/jetri/gitops/actions/workflows/update-manifest.yaml/badge.svg)](https://github.com/jetri/gitops/actions/workflows/update-manifest.yaml)
![GitHub repo size](https://img.shields.io/github/repo-size/x-real-ip/gitops?logo=Github)
![GitHub commit activity](https://img.shields.io/github/commit-activity/y/x-real-ip/gitops?logo=github)
![GitHub last commit (branch)](https://img.shields.io/github/last-commit/x-real-ip/gitops/main?logo=github)

- [GitOps](#gitops)
  - [Start ArgoCD WebUI](#start-argocd-webui)
  - [Uptime Kuma](#uptime-kuma)

## Install ArgoCD
https://argo-cd.readthedocs.io/en/stable/getting_started/
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Install SealedSecret
https://github.com/bitnami-labs/sealed-secrets/releases
```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.31.0/controller.yaml
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
