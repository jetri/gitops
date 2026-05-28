# DeepTutor on Kubernetes — bootstrap

This deployment follows the upstream [Docker](https://github.com/HKUDS/DeepTutor#option-3--docker) and [multi-user](https://github.com/HKUDS/DeepTutor#-multi-user--shared-deployments-with-per-user-workspaces) guides. Configuration lives on the PVC under `data/user/settings/*.json`, not in Kubernetes env vars (the container entrypoint ignores process env overrides and loads JSON on start).

## Build the image

From the gitops repo (`homelab/gitops/deeptutor`; DeepTutor checkout at `homelab/DeepTutor`):

```bash
cd deeptutor
./build-image.sh homelab
docker login
docker push docker.io/jetri/deeptutor:homelab
```

Or build directly from the DeepTutor repo:

```bash
docker build -t docker.io/jetri/deeptutor:homelab /path/to/DeepTutor
docker push docker.io/jetri/deeptutor:homelab
```

ArgoCD uses `docker.io/jetri/deeptutor:homelab` in `deeptutor.yaml`.

## First boot (fresh PVC)

1. Sync the `deeptutor` ArgoCD app.
2. Open https://tutor.j3laserna.me — the pod creates default settings under `/app/data/user/settings/` on first start.
3. In **Settings → Network**, set the public API base to `https://tutor.j3laserna.me` (no `/api` suffix; the app adds `/api` itself).
4. With auth enabled later, add CORS origin `https://tutor.j3laserna.me` in the same panel (or `system.json` → `cors_origins`).
5. In **Settings → Models**, configure:
   - **LLM**: OpenAI, `https://api.openai.com/v1`, model `gpt-4o-mini`, API key from your OpenAI account.
   - **Embeddings**: OpenAI-compatible, `http://embeddings-svc/v1`, model `BAAI/bge-m3`, dimension `1024`, API key `sk-no-key-required`.
6. Optional: web search profile in the same catalog if you use Brave/etc.

The sealed secret `openai-api-key-secret` is kept for reference or future automation; paste the key into the model catalog via Settings (official path).

## Multi-user

1. In **Settings**, enable authentication (`auth.json` → `enabled: true`). For HTTPS, set **cookie secure** to true (same-site UI + API on `tutor.j3laserna.me`).
2. Restart the pod once if the UI does not pick up auth immediately.
3. Visit https://tutor.j3laserna.me/register — the first account becomes admin; `/register` closes afterward.
4. Admin: `/admin/users` to invite users; assign models/KBs per user.

User data persists under `/app/multi-user/` on the PVC (`subPath: multi-user`). JWT secret is auto-created at `multi-user/_system/auth/auth_secret` on first authenticated boot.

Do **not** set `integrations.pocketbase_url` for multi-user (upstream: PocketBase mode is single-user only).

## Migrating from the old init-container setup

If the PVC was seeded by the previous `seed-settings` init container:

- It may have overwritten `system.json` / `auth.json` on every pod start — fix those files once via Settings or edit on the volume, then rely on the UI going forward.
- Remove stale `model_catalog.json` only if profiles are wrong; otherwise adjust profiles in Settings.
- Pull the new image tag and delete the old pod so it does not use `jetri/deeptutor:auth-ui-v1`.

## Ingress

Traefik serves the UI on `/` and the API on `/api` on one host. The browser must use `next_public_api_base_external` = `https://tutor.j3laserna.me`, not port `8001` on the cluster.
