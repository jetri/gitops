# DeepTutor (Kubernetes)

Custom image: [`docker.io/jetri/deeptutor:1.4.10`](https://hub.docker.com/r/jetri/deeptutor) (built from `fix/deeptutor-ui-improvements` — auth logo fix + per-type quiz retry toggle).

## Architecture

| Path | Service port | Purpose |
|------|--------------|---------|
| `https://tutor.j3laserna.me/` | 3782 | Next.js UI (frontend container) |
| `https://tutor.j3laserna.me/api/...` | 8001 | FastAPI + WebSockets (backend container) |

One pod runs **two containers** (backend + frontend) sharing the `/app/data` PVC. No supervisord — each container runs the upstream start scripts directly.

Browser API base in `system.json`: `https://tutor.j3laserna.me` (no `:8001`, no `/api` suffix).

## What the manifest provides

- Official GHCR image, no custom build
- PVC: full `/app/data` tree (`user`, `system`, `users`, `memory`, `knowledge_bases`, …)
- `fsGroup: 1000`; containers run as UID 1000
- Ingress path split (`/api` → backend, `/` → frontend)
- `replicas: 1` + `Recreate`
- TEI embeddings sidecar (`http://embeddings-svc/v1`, model `BAAI/bge-m3`)

## Fresh install

```bash
cd gitops/deeptutor
./wipe-data.sh --yes
```

Commit/sync the latest manifest, then wait for the pod to become Ready.

### First boot

1. Open `https://tutor.j3laserna.me`
2. **Settings → Network** — set public API base to `https://tutor.j3laserna.me`, add the same URL under CORS origins
3. `kubectl rollout restart deployment/deeptutor -n deeptutor`
4. **Settings → Models** — configure LLM + embedding (`http://embeddings-svc/v1`, `BAAI/bge-m3`)

Auth is **off by default** (upstream). The app opens directly — there is no registration page until you enable auth.

## Multi-user (optional)

```bash
kubectl exec -n deeptutor deploy/deeptutor -c backend -- python -c "
from deeptutor.services.config import get_runtime_settings_service
r = get_runtime_settings_service()
r.save_auth({
    'enabled': True,
    'username': '',
    'password_hash': '',
    'token_expire_hours': 24,
    'cookie_secure': True,
})
print('auth.json updated')
"

kubectl rollout restart deployment/deeptutor -n deeptutor
```

Then hard-refresh, visit `/register` (first user = admin), configure models and users.

`cookie_secure: true` is required for HTTPS.

## Change public URL

Update **Settings → Network** on a running install and restart the deployment.

## Wipe PVC data

```bash
cd gitops/deeptutor
./wipe-data.sh
```

Removes **all** top-level directories on the PVC. Repeat the first-boot steps above.

## Local GPU stack (vLLM)

Not part of this manifest. See `gitops/deeptutor/README.md` and `docker-compose.yml` on the gaming PC.
