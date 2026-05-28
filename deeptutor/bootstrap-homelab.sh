#!/usr/bin/env bash
# Seed homelab runtime settings via DeepTutor's settings API (same files as the
# Settings UI / official multi-user docs). One-shot Job — not part of Deployment.
#
# Writes:
#   - data/user/settings/system.json  (public API base + CORS)
#   - data/user/settings/auth.json    (multi-user auth, browser registration)
#   - default auth.json / integrations.json / model_catalog.json if missing
#
# Run after wipe-data.sh. Then restart the deployment so the frontend reinjects
# NEXT_PUBLIC_* values from JSON into the Next.js bundle.
#
# Usage:
#   ./bootstrap-homelab.sh
#   PUBLIC_URL=https://tutor.example.com ./bootstrap-homelab.sh
#   AUTH_ENABLED=false ./bootstrap-homelab.sh   # network only, single-user mode
#
# Requires: kubectl, image on cluster (docker.io/jetri/deeptutor:homelab)

set -euo pipefail

NAMESPACE="${NAMESPACE:-deeptutor}"
PVC="${PVC:-pvc-iscsi-deeptutor-data}"
IMAGE="${IMAGE:-docker.io/jetri/deeptutor:homelab}"
PUBLIC_URL="${PUBLIC_URL:-https://tutor.j3laserna.me}"
AUTH_ENABLED="${AUTH_ENABLED:-true}"
# Default secure cookies when using HTTPS (official multi-user guidance).
AUTH_COOKIE_SECURE="${AUTH_COOKIE_SECURE:-}"
if [[ -z "${AUTH_COOKIE_SECURE}" ]]; then
  case "${PUBLIC_URL}" in
    https://*) AUTH_COOKIE_SECURE=true ;;
    *) AUTH_COOKIE_SECURE=false ;;
  esac
fi
JOB_NAME="deeptutor-bootstrap-$(date +%s)"

kubectl get pvc "${PVC}" -n "${NAMESPACE}" >/dev/null

echo "Bootstrap via DeepTutor runtime API:"
echo "  public API base: ${PUBLIC_URL}"
echo "  auth enabled:    ${AUTH_ENABLED}"
echo "  cookie_secure:   ${AUTH_COOKIE_SECURE}"

kubectl create -f - -n "${NAMESPACE}" <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: bootstrap
          image: ${IMAGE}
          env:
            - name: DEEPTUTOR_HOME
              value: /app
            - name: PUBLIC_URL
              value: "${PUBLIC_URL}"
            - name: AUTH_ENABLED
              value: "${AUTH_ENABLED}"
            - name: AUTH_COOKIE_SECURE
              value: "${AUTH_COOKIE_SECURE}"
          command:
            - python
            - -c
            - |
              import os
              from pathlib import Path

              from deeptutor.services.setup import init_user_directories
              from deeptutor.services.config import get_runtime_settings_service
              from deeptutor.services.config.runtime_settings import ensure_runtime_settings_files

              def _bool(name: str, default: bool = False) -> bool:
                  return os.environ.get(name, str(default)).lower() in ("1", "true", "yes", "on")

              public = os.environ["PUBLIC_URL"].rstrip("/")
              auth_enabled = _bool("AUTH_ENABLED")
              cookie_secure = _bool("AUTH_COOKIE_SECURE")

              init_user_directories(Path("/app"))
              runtime = get_runtime_settings_service()
              runtime.save_system(
                  {
                      "backend_port": 8001,
                      "frontend_port": 3782,
                      "next_public_api_base_external": public,
                      "next_public_api_base": public,
                      "cors_origins": [public],
                  }
              )
              runtime.save_auth(
                  {
                      "enabled": auth_enabled,
                      "username": "",
                      "password_hash": "",
                      "token_expire_hours": 24,
                      "cookie_secure": cookie_secure,
                  }
              )
              ensure_runtime_settings_files()
              print("OK system:", runtime.path_for("system"))
              print("OK auth:", runtime.path_for("auth"), "enabled=", auth_enabled)
          volumeMounts:
            - name: data
              mountPath: /app/data/user
              subPath: user
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: ${PVC}
EOF

kubectl wait --for=condition=complete "job/${JOB_NAME}" -n "${NAMESPACE}" --timeout=120s
kubectl logs "job/${JOB_NAME}" -n "${NAMESPACE}"
kubectl delete job "${JOB_NAME}" -n "${NAMESPACE}" --ignore-not-found

echo ""
echo "Restarting deployment (required: frontend reinjects auth + API URL from JSON)..."
kubectl rollout restart "deployment/deeptutor" -n "${NAMESPACE}"
kubectl rollout status "deployment/deeptutor" -n "${NAMESPACE}" --timeout=300s

echo ""
echo "Verify auth.json on PVC:"
kubectl exec -n "${NAMESPACE}" deploy/deeptutor -- cat /app/data/user/settings/auth.json

echo ""
echo "Verify frontend saw auth at startup (should NOT show placeholder/false only):"
kubectl exec -n "${NAMESPACE}" deploy/deeptutor -- sh -c \
  'grep -r "NEXT_PUBLIC_AUTH_ENABLED" /app/web/.next/static/chunks 2>/dev/null | head -1 | cut -c1-120' || true

echo ""
if [[ "${AUTH_ENABLED}" == true ]]; then
  echo "Next:"
  echo "  1. Hard-refresh ${PUBLIC_URL} (Cmd+Shift+R) — stale JS hides Logout"
  echo "  2. Settings → Models"
  echo "  3. New users: ${PUBLIC_URL}/register (if not registered yet)"
  echo ""
  echo "Logout/Admin links only appear when the frontend bundle has AUTH=true after restart."
else
  echo "Open ${PUBLIC_URL} and configure Models (single-user mode)."
fi
