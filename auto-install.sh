#!/bin/bash

set -e

#####################################
# Set your environment variables here
#####################################

INSTALL_NIM_PLATFORM=true   # Account, NGC secrets and the models namespace (needs kserve.nim enabled in rhoai-gitops)
INSTALL_NIM_MODELS=false    # Deploy the NIM models of the block "NIM models" below
NIM_NAMESPACE=rhoai-nim-models
ARGOCD_NAMESPACE=openshift-gitops

#####################################
## Do not modify anything from this line
#####################################

is_true() { [[ "$1" =~ ^([Tt]rue|[Yy]es|[1])$ ]]; }

# Countdown that can be skipped by pressing 'q'. Usage: countdown_with_skip <seconds>
countdown_with_skip() {
  local secs=$1
  local i=$secs key
  while [[ $i -gt 0 ]]; do
    echo -ne "\t⏰ Time left: $i seconds. Press q to skip.\r"
    read -t 1 -n 1 key 2>/dev/null || true
    [[ "${key,,}" == "q" ]] && { echo -ne "\n\t⏭️  Skipped.\n"; return; }
    sleep 1
    i=$((i - 1))
  done
  echo -ne "\n"
}

# Wait up to N seconds; return 0 if user presses 'q' (skip), 1 when full wait completed. Usage: wait_with_skip <seconds>
wait_with_skip() {
  local n=$1
  local i=0 key
  while [[ $i -lt $n ]]; do
    read -t 1 -n 1 key 2>/dev/null || true
    [[ "${key,,}" == "q" ]] && return 0
    sleep 1
    i=$((i + 1))
  done
  return 1
}

# Wait until an Argo CD Application is Synced and Healthy. Usage: wait_for_application <name>
wait_for_application() {
  local app=$1
  echo -e "⏳ Waiting until the application $app is Synced and Healthy"
  while true; do
    local sync health
    sync=$(oc get application "$app" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)
    health=$(oc get application "$app" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.status.health.status}' 2>/dev/null || true)
    [[ "$sync" == "Synced" && "$health" == "Healthy" ]] && break
    echo "⏳ $app: sync=${sync:-unknown} health=${health:-unknown}... (press q to skip)"
    wait_with_skip 10 && break
  done
}

# Print feature toggles
echo -e "\n===================="
echo -e "FEATURE TOGGLES & CONFIG:"
echo -e " * INSTALL_NIM_PLATFORM: $INSTALL_NIM_PLATFORM"
echo -e " * INSTALL_NIM_MODELS: $INSTALL_NIM_MODELS"
echo -e " * NIM_NAMESPACE: $NIM_NAMESPACE"
echo -e "====================\n"

# Check if the user is logged in
if ! oc whoami &> /dev/null; then
    echo -e "❌ Check. You are not logged in. Please log in and run the script again."
    exit 1
else
    echo -e "✅ Check. You are correctly logged in. Continue..."
fi

# Check that NIM is enabled in the cluster (rhoai-gitops: nim.enabled)
if [[ "$(oc get datasciencecluster -o jsonpath='{.items[0].spec.components.kserve.nim.managementState}' 2>/dev/null)" != "Managed" ]]; then
    echo -e "⚠️  kserve.nim is not Managed in the DataScienceCluster. Enable it in rhoai-gitops (nim.enabled) first."
    read -p "🤔 Proceed? (y/n): " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || { echo "🚪 Exiting."; exit 1; }
fi

echo -e "\n🟩 ======================"
echo -e "🟩 =   NIM platform     ="
echo -e "🟩 ======================\n"

if is_true "$INSTALL_NIM_PLATFORM"; then
    # NGC API key: from the environment or from the git-ignored file ngc-api-key (see ngc-api-key.example)
    if [[ -z "$NGC_API_KEY" && -f ./ngc-api-key ]]; then source ./ngc-api-key; fi
    if [[ -z "$NGC_API_KEY" ]]; then
        echo -e "❌ NGC_API_KEY is empty. Export it or fill the file ngc-api-key."
        exit 1
    fi

    echo -e "🚀 Trigger the ArgoCD application of the NIM platform (Account, NGC secrets, namespace $NIM_NAMESPACE)"
    cat application-nim-platform.yaml | \
    NIM_NAMESPACE=$NIM_NAMESPACE NGC_API_KEY=$NGC_API_KEY \
    envsubst | oc apply -f -

    wait_for_application nim-platform
else
    echo "⏭️  Skip installation of the NIM platform..."
fi

echo -e "\n🧠 ======================"
echo -e "🧠 =      NIM models     ="
echo -e "🧠 ======================\n"

if is_true "$INSTALL_NIM_MODELS"; then
    # Copy and paste this block once per model. MODEL_NAME is the suffix of nim-model/values-<MODEL_NAME>.yaml
    MODEL_NAME=magpie-tts-multilingual
    echo -e "🚀 Trigger the ArgoCD application of the model $MODEL_NAME"
    cat application-nim-model.yaml | \
    MODEL_NAME=$MODEL_NAME NIM_NAMESPACE=$NIM_NAMESPACE \
    envsubst | oc apply -f -
else
    echo "⏭️  Skip deployment of the NIM models..."
fi

echo "🎊 That's all!! NIM should be ready to serve models!! :)"
