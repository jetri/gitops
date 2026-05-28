#!/usr/bin/env bash
set -euo pipefail

# Build DeepTutor from source (official Dockerfile) and optionally push.
#
# Usage:
#   ./build-image.sh [tag] [--push]
#
# Environment:
#   DEEPTUTOR_SRC  Path to DeepTutor checkout (default: sibling ../DeepTutor)
#   IMAGE_REPO     Docker repository (default: jetri/deeptutor)
#   PLATFORM       docker build --platform (default: linux/amd64)
#
# Examples:
#   ./build-image.sh homelab
#   ./build-image.sh homelab --push

TAG="${1:-homelab}"
PUSH=false
if [[ "${2:-}" == "--push" ]]; then
  PUSH=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEEPTUTOR_SRC="${DEEPTUTOR_SRC:-$(cd "${SCRIPT_DIR}/../../DeepTutor" 2>/dev/null && pwd || true)}"
IMAGE_REPO="${IMAGE_REPO:-jetri/deeptutor}"
PLATFORM="${PLATFORM:-linux/amd64}"
IMAGE="${IMAGE_REPO}:${TAG}"

if [[ -z "${DEEPTUTOR_SRC}" || ! -f "${DEEPTUTOR_SRC}/Dockerfile" ]]; then
  echo "Set DEEPTUTOR_SRC to a DeepTutor checkout containing Dockerfile." >&2
  echo "  export DEEPTUTOR_SRC=/path/to/DeepTutor" >&2
  exit 1
fi

echo "Building ${IMAGE} from ${DEEPTUTOR_SRC} (${PLATFORM})"
docker build \
  --platform "${PLATFORM}" \
  -t "docker.io/${IMAGE}" \
  -f "${DEEPTUTOR_SRC}/Dockerfile" \
  "${DEEPTUTOR_SRC}"

if [[ "${PUSH}" == true ]]; then
  echo "Pushing docker.io/${IMAGE}"
  docker push "docker.io/${IMAGE}"
fi

echo "Done: docker.io/${IMAGE}"
