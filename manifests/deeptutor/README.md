# DeepTutor (Kubernetes)

Official image: [`ghcr.io/hkuds/deeptutor:1.4.2`](https://github.com/HKUDS/DeepTutor) (pinned; same Dockerfile as `docker-compose.ghcr.yml`).

v1.4.2 includes the multi-user workspace routing fix ([#485](https://github.com/HKUDS/DeepTutor/issues/485)) — use this tag or newer for multi-user.

## Architecture

| Path | Service port | Purpose |
|------|--------------|---------|
| `https://tutor.j3laserna.me/` | 3782 | Next.js UI |
| `https://tutor.j3laserna.me/api/...` | 8001 | FastAPI + WebSockets |

Browser API base in `system.json`: `https://tutor.j3laserna.me` (no `:8001`, no `/api` suffix).

## What the manifest provides (OOTB)

- Official GHCR image, no custom build
- PVC mounts: `user`, `memory`, `knowledge_bases`, **`multi-user`** (required for multi-user persistence; upstream GHCR compose omits this)
- Ingress path split matching upstream’s Caddy example
- `replicas: 1` + `Recreate` (single-process; required for first-admin registration)
- Init container: seeds `system.json` network settings on **empty PVC only** (idempotent)
- TEI embeddings sidecar (`http://embeddings-svc/v1`, model `BAAI/bge-m3`)

## First boot (fresh PVC)

1. Deploy and wait for the pod. The init container writes network settings if missing; the main container reinjects them into the Next.js bundle at start.
2. Open `https://tutor.j3laserna.me` and configure **Settings → Models** (LLM + embedding provider).
3. Hard-refresh if the UI was opened before the pod became ready.

## Multi-user

Auth is **off by default** (upstream). Enable when ready:

```bash
kubectl exec -n deeptutor deploy/deeptutor -- python -c "
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

Then:

1. Hard-refresh the browser.
2. Register at `https://tutor.j3laserna.me/register` (first user = admin).
3. As admin: **Settings → Models**, `/admin/users`, per-user grants.
4. Confirm sidebar shows **Logout** / **Admin** (frontend reads `auth.json` at container start).

`cookie_secure: true` is required for HTTPS. Keep `integrations.pocketbase_url` blank (PocketBase is single-user only).

## Change public URL

Edit `DEEPTUTOR_SEED_PUBLIC_URL` in `deeptutor.yaml` (init container) **before** first deploy, or update **Settings → Network** on an existing install and restart.

## Wipe PVC data

```bash
cd gitops/deeptutor
./wipe-data.sh
```

Network settings are re-seeded on next pod start; repeat Models + multi-user steps above.

## Local GPU stack (vLLM)

Not part of this manifest. See `gitops/deeptutor/README.md` and `docker-compose.yml` on the gaming PC.
