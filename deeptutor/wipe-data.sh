#!/usr/bin/env bash
# Wipe all DeepTutor data on the TrueNAS-backed PVC (clean slate).
# Keeps PV/PVC/LUN; deletes user settings, KBs, memory, and multi-user state.
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
  echo "This will DELETE all DeepTutor data on ${PVC} in namespace ${NAMESPACE}:"
  echo "  - user/ (settings, chat, workspace)"
  echo "  - memory/"
  echo "  - knowledge_bases/"
  echo "  - multi-user/"
  echo ""
  echo "The TrueNAS iSCSI volume is kept; only filesystem contents are removed."
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
              for dir in user memory knowledge_bases multi-user; do
                if [ -d "\${mount}/\${dir}" ]; then
                  echo "Removing \${mount}/\${dir}/*"
                  rm -rf "\${mount}/\${dir}"/*
                fi
              done
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
echo "  1. ./bootstrap-homelab.sh   # writes system.json (official settings API)"
echo "  2. kubectl rollout restart deployment/${DEPLOYMENT} -n ${NAMESPACE}"
echo "  3. Register at PUBLIC_URL/register after restart — see BOOTSTRAP.md"
echo "  4. Configure Models in Settings UI"
echo "  4. Clear browser cookies for tutor.j3laserna.me (old dt_token)"
