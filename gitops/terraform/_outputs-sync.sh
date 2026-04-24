#!/usr/bin/env sh
# _outputs-sync.sh — Export Terraform outputs to a Kubernetes ConfigMap
# Called by the terraform-runner Job after `terraform apply`.
set -euo pipefail

NAMESPACE="${TF_OUTPUT_NAMESPACE:-gitops-system}"
CONFIGMAP_NAME="${TF_OUTPUT_CONFIGMAP:-gitops-tf-outputs}"

echo "==> Reading Terraform outputs..."
OUTPUTS=$(terraform output -json)

# Build --from-literal args from TF output keys
LITERAL_ARGS=""
for key in $(echo "$OUTPUTS" | jq -r 'keys[]'); do
  value=$(echo "$OUTPUTS" | jq -r --arg k "$key" '.[$k].value // empty')
  if [ -n "$value" ]; then
    LITERAL_ARGS="$LITERAL_ARGS --from-literal=$key=$value"
  fi
done

if [ -z "$LITERAL_ARGS" ]; then
  echo "==> No outputs to sync"
  exit 0
fi

echo "==> Syncing outputs to ConfigMap ${NAMESPACE}/${CONFIGMAP_NAME}..."
eval kubectl create configmap "$CONFIGMAP_NAME" \
  --namespace "$NAMESPACE" \
  $LITERAL_ARGS \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Done. Outputs synced to ConfigMap."
