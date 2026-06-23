#!/usr/bin/env bash
# Wipe the entire DeepTutor PVC (clean slate). Keeps PV/PVC/LUN.
#
# Usage:
#   ./wipe-data.sh              # interactive confirm
#   ./wipe-data.sh --yes        # skip confirm
#
# Requires: kubectl, namespace deeptutor, PVC pvc-iscsi-deeptutor-data

set -euo pipefail

NAMESPACE="${NAMESPACE:-deeptutor}"
PVC="${PVC:-pvc-iscsi-deeptutor-data}"
DEPLOYMENT="${DEPLOYMENT:-deeptutor}"
JOB_NAME="deeptutor-wipe-data-$(date +%s)"
SKIP_CONFIRM=false

if [[ "${1:-}" == "--yes" ]]; then
  SKIP_CONFIRM=true
fi

if [[ "${SKIP_CONFIRM}" != true ]]; then
  echo "This will DELETE ALL files on ${PVC} in namespace ${NAMESPACE}."
  echo "The TrueNAS iSCSI volume is kept; the filesystem is emptied."
  read -r -p "Type WIPE to continue: " confirm
  if [[ "${confirm}" != "WIPE" ]]; then
    echo "Cancelled."
    exit 1
  fi
fi

kubectl get pvc "${PVC}" -n "${NAMESPACE}" >/dev/null 2>&1 || {
  echo "PVC ${PVC} not found in ${NAMESPACE}" >&2
  exit 1
}

echo "Scaling ${DEPLOYMENT} to 0..."
kubectl scale deployment "${DEPLOYMENT}" -n "${NAMESPACE}" --replicas=0
kubectl wait --for=delete pod -l app="${DEPLOYMENT}" -n "${NAMESPACE}" --timeout=120s 2>/dev/null || true

echo "Running wipe job ${JOB_NAME}..."
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
        - name: wipe
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              set -eu
              mount=/data
              echo "Removing everything under \${mount}"
              find "\${mount}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
              echo "Done."
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: ${PVC}
EOF

kubectl wait --for=condition=complete "job/${JOB_NAME}" -n "${NAMESPACE}" --timeout=120s
kubectl logs "job/${JOB_NAME}" -n "${NAMESPACE}"
kubectl delete job "${JOB_NAME}" -n "${NAMESPACE}" --ignore-not-found

echo "Scaling ${DEPLOYMENT} back to 1..."
kubectl scale deployment "${DEPLOYMENT}" -n "${NAMESPACE}" --replicas=1

echo ""
echo "Clean slate complete. Next:"
echo "  1. Wait for the pod (backend + frontend containers) to become Ready"
echo "  2. Open https://tutor.j3laserna.me → Settings → Network"
echo "     Set public API base to https://tutor.j3laserna.me and add CORS origin"
echo "  3. kubectl rollout restart deployment/${DEPLOYMENT} -n ${NAMESPACE}"
echo "  4. Settings → Models (embeddings: http://embeddings-svc/v1, BAAI/bge-m3)"
echo "  5. Optional multi-user: see manifests/deeptutor/README.md"
echo "  6. Clear browser cookies for tutor.j3laserna.me"
echo ""
