#!/bin/bash
# Smoke test of the ASR NIM (nemotron-asr-streaming): is it ready? does it transcribe a sample audio?
# Usage: ./test-asr.sh [audio.wav]     (without an argument it uses the sample WAV that ships inside the NIM image)
# More details in docs/testing-asr.md

set -e

NIM_NAMESPACE=${NIM_NAMESPACE:-rhoai-nim-models}
MODEL_NAME=${MODEL_NAME:-nemotron-asr-streaming}
HTTP_PORT=${HTTP_PORT:-9000}       # local ports of the port-forward
GRPC_PORT=${GRPC_PORT:-50051}
LANGUAGE_CODE=${LANGUAGE_CODE:-}   # empty: automatic language detection (type=multi). Example: en-US, fr-FR
WORKDIR=${WORKDIR:-/tmp/test-asr}  # venv, python-clients and the audio are kept here, so the next runs are fast
SAMPLE_IN_POD=/opt/riva/wav/en-US_sample.wav

SVC="${MODEL_NAME}-predictor"

oc whoami > /dev/null || { echo "❌ You are not logged in to the cluster (oc login)"; exit 1; }
mkdir -p "$WORKDIR"

# Port-forward to the pod, closed when the script ends. The Service is headless and has no port 9000, so we use the
# container ports (9000 HTTP, 50051 gRPC) of the pod.
POD=$(oc get pod -n "$NIM_NAMESPACE" -l "serving.kserve.io/inferenceservice=$MODEL_NAME" -o name | head -1)
[ -n "$POD" ] || { echo "❌ No pod found for $MODEL_NAME in $NIM_NAMESPACE"; exit 1; }
oc port-forward -n "$NIM_NAMESPACE" "$POD" "$HTTP_PORT:9000" "$GRPC_PORT:50051" > "$WORKDIR/port-forward.log" 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null' EXIT
sleep 3
kill -0 $PF_PID 2>/dev/null || { echo "❌ The port-forward failed:"; cat "$WORKDIR/port-forward.log"; exit 1; }

echo -e "\n🩺 === Check 1: is the NIM ready? ==="
CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$HTTP_PORT/v1/health/ready" || true)
if [ "$CODE" != "200" ]; then
    echo "❌ GET /v1/health/ready returned '$CODE' (200 expected). The first start builds the model and can take up to 30 minutes."
    echo "   Follow it with: oc logs -f -n $NIM_NAMESPACE deploy/$SVC -c kserve-container"
    exit 1
fi
echo "✅ GET /v1/health/ready returned 200"

echo -e "\n🎤 === Preparing the client and the audio ==="
if [ ! -x "$WORKDIR/venv/bin/python" ]; then
    python3 -m venv "$WORKDIR/venv"
    "$WORKDIR/venv/bin/pip" install -q nvidia-riva-client
fi
if [ ! -d "$WORKDIR/python-clients" ]; then
    git clone -q --depth 1 https://github.com/nvidia-riva/python-clients.git "$WORKDIR/python-clients"
fi
TRANSCRIBE="$WORKDIR/python-clients/scripts/asr/transcribe_file.py"

if [ -n "$1" ]; then
    AUDIO=$(realpath "$1")
else
    AUDIO="$WORKDIR/en-US_sample.wav"
    oc exec -n "$NIM_NAMESPACE" "$POD" -c kserve-container -- cat "$SAMPLE_IN_POD" > "$AUDIO"
fi
echo "Audio: $AUDIO"

cd "$WORKDIR"
PY="$WORKDIR/venv/bin/python"

echo -e "\n📋 === Check 2: which models does the server offer? (gRPC) ==="
"$PY" "$TRANSCRIBE" --server "localhost:$GRPC_PORT" --list-models

echo -e "\n📝 === Check 3: transcribe the audio, streamed in chunks (gRPC) ==="
LANG_ARG=()
[ -n "$LANGUAGE_CODE" ] && LANG_ARG=(--language-code "$LANGUAGE_CODE")
"$PY" "$TRANSCRIBE" --server "localhost:$GRPC_PORT" "${LANG_ARG[@]}" --automatic-punctuation --input-file "$AUDIO"

echo -e "\n🎉 Done. If you saw a sentence above, the ASR NIM works."
