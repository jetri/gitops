#!/usr/bin/env bash
set -euo pipefail

# Build a homelab DeepTutor image from source.
#
# Homelab build differs from upstream Dockerfile defaults:
#   - --target production (last stage is "development")
#   - NEXT_PUBLIC_AUTH_ENABLED=true at `npm run build` time
#
# Next.js inlines NEXT_PUBLIC_* at build time. The upstream placeholder
#   __NEXT_PUBLIC_AUTH_ENABLED_PLACEHOLDER__ !== "true"
# is constant-folded to false, so Logout/Admin UI is stripped from client
# bundles. Runtime sed in start-frontend.sh cannot fix that. Backend auth
# (auth.json) and frontend auth UI must be aligned via this build flag + PVC.
#
# API URL is still updated at container start from system.json (sed).
#
# Usage:
#   ./build-image.sh homelab [--push]
#
# Environment:
#   DEEPTUTOR_SRC       DeepTutor checkout (default: ../../DeepTutor)
#   IMAGE_REPO          default jetri/deeptutor
#   PLATFORM            default linux/amd64
#   HOMELAB_PUBLIC_URL  baked into .env.local for first boot (default tutor host)
#   BAKE_AUTH_ENABLED   default true — set false for a single-user image only
#
# Examples:
#   ./build-image.sh homelab --push
#   BAKE_AUTH_ENABLED=false ./build-image.sh homelab-singleuser --push

TAG="${1:-homelab}"
PUSH=false
if [[ "${2:-}" == "--push" ]]; then
  PUSH=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEEPTUTOR_SRC="${DEEPTUTOR_SRC:-$(cd "${SCRIPT_DIR}/../../DeepTutor" 2>/dev/null && pwd || true)}"
IMAGE_REPO="${IMAGE_REPO:-jetri/deeptutor}"
PLATFORM="${PLATFORM:-linux/amd64}"
HOMELAB_PUBLIC_URL="${HOMELAB_PUBLIC_URL:-https://tutor.j3laserna.me}"
BAKE_AUTH_ENABLED="${BAKE_AUTH_ENABLED:-true}"
IMAGE="${IMAGE_REPO}:${TAG}"

if [[ -z "${DEEPTUTOR_SRC}" || ! -f "${DEEPTUTOR_SRC}/Dockerfile" ]]; then
  echo "Set DEEPTUTOR_SRC to a DeepTutor checkout containing Dockerfile." >&2
  exit 1
fi

AUTH_ENV_VALUE="true"
if [[ "${BAKE_AUTH_ENABLED}" != true ]]; then
  AUTH_ENV_VALUE="__NEXT_PUBLIC_AUTH_ENABLED_PLACEHOLDER__"
fi

DOCKERFILE_TMP="$(mktemp)"
trap 'rm -f "${DOCKERFILE_TMP}"' EXIT
sed \
  -e "s|NEXT_PUBLIC_API_BASE=__NEXT_PUBLIC_API_BASE_PLACEHOLDER__|NEXT_PUBLIC_API_BASE=${HOMELAB_PUBLIC_URL}|" \
  -e "s|NEXT_PUBLIC_AUTH_ENABLED=__NEXT_PUBLIC_AUTH_ENABLED_PLACEHOLDER__|NEXT_PUBLIC_AUTH_ENABLED=${AUTH_ENV_VALUE}|" \
  "${DEEPTUTOR_SRC}/Dockerfile" > "${DOCKERFILE_TMP}"

echo "Building ${IMAGE} (${PLATFORM}, target=production)"
echo "  HOMELAB_PUBLIC_URL=${HOMELAB_PUBLIC_URL}"
echo "  NEXT_PUBLIC_AUTH_ENABLED=${AUTH_ENV_VALUE} (baked at npm run build)"
docker build \
  --platform "${PLATFORM}" \
  --target production \
  -t "docker.io/${IMAGE}" \
  -f "${DOCKERFILE_TMP}" \
  "${DEEPTUTOR_SRC}"

echo "Verifying production image..."
IMG="docker.io/${IMAGE}"
docker run --rm --entrypoint test "${IMG}" -f /app/web/server.js
docker run --rm --entrypoint grep "${IMG}" -q start-frontend.sh /etc/supervisor/conf.d/deeptutor.conf
if docker run --rm --entrypoint grep "${IMG}" -q 'next dev' /etc/supervisor/conf.d/deeptutor.conf; then
  echo "ERROR: development stage image (next dev)." >&2
  exit 1
fi

if [[ "${BAKE_AUTH_ENABLED}" == true ]]; then
  echo "Checking client bundle for compile-time auth flag..."
  if docker run --rm --entrypoint grep "${IMG}" -q '__NEXT_PUBLIC_AUTH_ENABLED_PLACEHOLDER__' /app/web/.next 2>/dev/null; then
    echo "WARN: placeholder still in .next — Logout may be missing; check Next.js version." >&2
  fi
fi
echo "OK: production image"

if [[ "${PUSH}" == true ]]; then
  docker push "docker.io/${IMAGE}"
fi

echo "Done: docker.io/${IMAGE}"
echo "Deploy with imagePullPolicy Always, then ./bootstrap-homelab.sh if PVC is fresh."
