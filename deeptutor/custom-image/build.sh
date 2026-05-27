#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./build.sh [tag]
#
# Example:
#   ./build.sh auth-ui-v1
#
# Prereqs:
#   docker login
#
# Builds and pushes to Docker Hub: jetri/deeptutor:<tag>

TAG="${1:-auth-ui-v1}"
IMAGE="jetri/deeptutor:${TAG}"

echo "Building ${IMAGE}"
docker build \
  --platform linux/amd64 \
  -t "${IMAGE}" \
  .

echo "Pushing ${IMAGE}"
docker push "${IMAGE}"

echo "Done: docker.io/${IMAGE}"
