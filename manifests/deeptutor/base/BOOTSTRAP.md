# DeepTutor on Kubernetes — bootstrap

Configuration lives on the PVC (`user/`, `memory/`, `knowledge_bases/`, `multi-user/`), not in Kubernetes env vars. The container entrypoint loads `data/user/settings/*.json` on start.

## Clean slate (wipe existing data)

**You do not need to delete the TrueNAS PV, PVC, or iSCSI LUN.** Wipe filesystem contents only:

```bash
cd homelab/gitops/deeptutor
./wipe-data.sh
```

This scales DeepTutor down, deletes everything under the four PVC subdirectories, and scales back up. The embeddings deployment is unchanged (it uses `emptyDir` for the model cache).

After wipe:

1. Clear browser cookies for `tutor.j3laserna.me` (stale `dt_token`).
2. Follow **First boot** below.

To destroy the volume entirely (rare): delete the PVC, clear the PV `claimRef` if stuck in `Released`, and optionally reformat the LUN on TrueNAS — only if you want a new block device, not just empty app data.

## Build the image

```bash
cd homelab/gitops/deeptutor
./build-image.sh homelab --push   # after docker login
```

`build-image.sh` passes `--target production` (required: the Dockerfile’s default final stage is `development`, which runs `next dev` without `web/app/` and crashes). After pushing, restart the pod; the manifest uses `imagePullPolicy: Always` so nodes do not keep a cached dev image tagged `:homelab`.

**Wrong image on cluster?** Pod logs show `Turbopack` or `WatchFiles` reloader → still the dev image. Rebuild, push, then `kubectl rollout restart deployment/deeptutor -n deeptutor`. Confirm with:

```bash
kubectl exec -n deeptutor deploy/deeptutor -- grep -E 'start-frontend|next dev' /etc/supervisor/conf.d/deeptutor.conf
```

You want `start-frontend.sh`, not `next dev`.

ArgoCD uses `docker.io/jetri/deeptutor:homelab` in `deeptutor.yaml`. No source-file edits are required before build.

## First boot

1. Sync the `deeptutor` ArgoCD app (image must exist on Docker Hub).
2. Open https://tutor.j3laserna.me — default settings are created on first start.
3. **Settings → Network**: public API base `https://tutor.j3laserna.me` (no `/api` suffix, **no `:8001`**).

   If API calls go to `http://tutor.j3laserna.me:8001/...`, `system.json` still has an empty public API base. The UI swaps `localhost` → your hostname but keeps port `8001`, which Traefik does not expose. Fix on the PVC, then restart the pod:

   ```bash
   kubectl exec -n deeptutor deploy/deeptutor -- python -c "
   import json
   from pathlib import Path
   p = Path('/app/data/user/settings/system.json')
   d = json.loads(p.read_text())
   d['next_public_api_base_external'] = 'https://tutor.j3laserna.me'
   d['next_public_api_base'] = 'https://tutor.j3laserna.me'
   d['cors_origins'] = ['https://tutor.j3laserna.me']
   p.write_text(json.dumps(d, indent=2) + '\n')
   "
   kubectl rollout restart deployment/deeptutor -n deeptutor
   ```
4. **Settings → Models**:
   - **LLM**: OpenAI, `https://api.openai.com/v1`, `gpt-4o-mini`, your API key.
   - **Embeddings**: OpenAI-compatible, `http://embeddings-svc/v1`, `BAAI/bge-m3`, dimension `1024`, API key `sk-no-key-required`.
5. **Settings**: enable authentication; for HTTPS set **cookie secure** on.
6. Restart the pod once after enabling auth.
7. **Settings → Network**: add CORS origin `https://tutor.j3laserna.me`.
8. https://tutor.j3laserna.me/register — first account is admin.

Paste the OpenAI key in Settings (not from K8s env). The sealed secret `openai-api-key-secret` is optional reference only.

## Multi-user

- User data: PVC `multi-user/` (JWT secret auto-created under `multi-user/_system/auth/`).
- Admin: `/admin/users` after first registration.
- Do **not** set `integrations.pocketbase_url` (single-user only).

## Ingress

UI on `/`, API on `/api` at `https://tutor.j3laserna.me`. API base in settings must be the site origin, not `:8001`.
