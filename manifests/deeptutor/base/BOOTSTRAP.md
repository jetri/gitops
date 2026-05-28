# DeepTutor on Kubernetes

Deployment manifest: image, PVC, ingress only (no init containers).

## Two layers of “auth”

| Layer | Config | What it controls |
|-------|--------|------------------|
| Backend | `auth.json` on PVC | Login API, JWT cookies, `/register`, multi-user |
| Frontend UI | **Baked at `npm run build`** | Logout, Admin link, middleware redirects |

Upstream Docker uses placeholders in `.env.local` and `start-frontend.sh` sed at container start. That works for the **API URL**, but Next.js **constant-folds** `__NEXT_PUBLIC_AUTH_ENABLED_PLACEHOLDER__ === "true"` to **false** in client bundles, so **Logout never appears** even when `auth.json` has `"enabled": true` and restart/sed cannot fix it.

**Homelab fix:** `build-image.sh` bakes `NEXT_PUBLIC_AUTH_ENABLED=true` (and your public URL) at image build time. Still set `auth.json` via `bootstrap-homelab.sh` for the backend.

## Clean slate workflow

```bash
cd homelab/gitops/deeptutor

# 1. Rebuild image (required for Logout UI — not just rollout restart)
./build-image.sh homelab --push

# 2. Wipe PVC
./wipe-data.sh

# 3. system.json + auth.json on PVC
./bootstrap-homelab.sh

# 4. Pod restarts automatically; hard-refresh browser
```

## Homelab ingress

- UI: `https://tutor.j3laserna.me/`
- API: `https://tutor.j3laserna.me/api/...`
- API base in `system.json`: `https://tutor.j3laserna.me` (no `:8001`, no `/api` suffix)

Change host: `HOMELAB_PUBLIC_URL=https://your.host ./build-image.sh homelab --push`

## After deploy

1. Hard-refresh https://tutor.j3laserna.me
2. **Settings → Models** — OpenAI + `http://embeddings-svc/v1` (BGE-M3)
3. **/register** if needed — first user is admin
4. Logout / Admin at **bottom of left sidebar**

Single-user image (no Logout UI): `BAKE_AUTH_ENABLED=false ./build-image.sh homelab-singleuser --push`

## Build notes

- `--target production` (required)
- `imagePullPolicy: Always` on cluster
