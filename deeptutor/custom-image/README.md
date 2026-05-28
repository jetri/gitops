# Deprecated

The patch-based image build in this directory is **deprecated**. It modified the upstream GHCR image to flip baked-in `AUTH_ENABLED=false` in compiled JS.

Build from the official [DeepTutor Dockerfile](https://github.com/HKUDS/DeepTutor/blob/main/Dockerfile) instead:

```bash
cd ../deeptutor
./build-image.sh homelab --push
```

The upstream image already replaces `__NEXT_PUBLIC_AUTH_ENABLED_PLACEHOLDER__` at container start from `data/user/settings/auth.json` (see `start-frontend.sh` in the DeepTutor repo). Enable auth in Settings or `auth.json`; no bundle patching required.

Kubernetes bootstrap: `manifests/deeptutor/base/BOOTSTRAP.md`.
