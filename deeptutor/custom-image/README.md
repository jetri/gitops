# DeepTutor Custom Image (Auth UI Enabled)

Builds a DeepTutor image with the prebuilt frontend patched so auth UI controls
(Logout/Admin links) work, then pushes to Docker Hub.

## Why this exists

The upstream `ghcr.io/hkuds/deeptutor:latest` image ships a compiled Next.js
frontend where `AUTH_ENABLED` is baked as `false`. Backend auth may work, but
sidebar auth/admin controls stay hidden.

## Build and push

```bash
cd deeptutor/custom-image
docker login
./build.sh auth-ui-v1
```

Publishes: `docker.io/jetri/deeptutor:auth-ui-v1`

Repository: https://hub.docker.com/repositories/jetri

## Kubernetes

`manifests/deeptutor/base/deeptutor.yaml` uses:

`docker.io/jetri/deeptutor:auth-ui-v1`

After push, sync ArgoCD so the cluster pulls the new image.
