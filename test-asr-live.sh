#!/bin/bash
# Live test of the ASR NIM (nemotron-asr-streaming) with YOUR MICROPHONE: you talk, the text appears while you speak.
# Usage: ./test-asr-live.sh                 start transcribing from the default microphone (stop with Ctrl+C)
#        ./test-asr-live.sh --list-devices  list the audio inputs and their numbers
#        INPUT_DEVICE=3 ./test-asr-live.sh  use another microphone
#        LANGUAGE_CODE=es-ES ./test-asr-live.sh   force a language (default: automatic language detection)
# The audio goes from your laptop to the cluster through a port-forward, so the latency includes your network.
# For a test without a microphone use ./test-asr.sh. More details in docs/testing-asr.md

set -e

NIM_NAMESPACE=${NIM_NAMESPACE:-rhoai-nim-models}
MODEL_NAME=${MODEL_NAME:-nemotron-asr-streaming}
GRPC_PORT=${GRPC_PORT:-50051}      # local port of the port-forward
LANGUAGE_CODE=${LANGUAGE_CODE:-}   # empty: automatic language detection (type=multi). Example: en-US, es-ES
INPUT_DEVICE=${INPUT_DEVICE:-}     # empty: the default microphone
WORKDIR=${WORKDIR:-/tmp/test-asr}  # same folder as test-asr.sh, so the venv and the client are shared

oc whoami > /dev/null || { echo "❌ You are not logged in to the cluster (oc login)"; exit 1; }
mkdir -p "$WORKDIR"

echo -e "🎤 === Preparing the client ==="
if [ ! -x "$WORKDIR/venv/bin/python" ]; then
    python3 -m venv "$WORKDIR/venv"
    "$WORKDIR/venv/bin/pip" install -q nvidia-riva-client
fi
if [ ! -d "$WORKDIR/python-clients" ]; then
    git clone -q --depth 1 https://github.com/nvidia-riva/python-clients.git "$WORKDIR/python-clients"
fi
PY="$WORKDIR/venv/bin/python"
MIC_CLIENT="$WORKDIR/python-clients/scripts/asr/transcribe_mic.py"

# The microphone needs PyAudio, which needs the PortAudio library and its headers on the system
if ! "$PY" -c "import pyaudio" 2> /dev/null; then
    echo "Installing PyAudio..."
    if ! "$WORKDIR/venv/bin/pip" install -q pyaudio; then
        echo "❌ PyAudio could not be built: it needs the PortAudio headers and a compiler. Install them and run this again:"
        echo "   Fedora/RHEL: sudo dnf install portaudio-devel python3-devel gcc"
        echo "   Debian/Ubuntu: sudo apt install portaudio19-dev python3-dev gcc"
        echo "   macOS: brew install portaudio"
        exit 1
    fi
fi

cd "$WORKDIR"

if [ "$1" = "--list-devices" ]; then
    "$PY" "$MIC_CLIENT" --list-devices
    exit 0
fi

# Port-forward to the pod (gRPC only), closed when the script ends. The Service is headless, so we use the pod.
POD=$(oc get pod -n "$NIM_NAMESPACE" -l "serving.kserve.io/inferenceservice=$MODEL_NAME" -o name | head -1)
[ -n "$POD" ] || { echo "❌ No pod found for $MODEL_NAME in $NIM_NAMESPACE"; exit 1; }
oc port-forward -n "$NIM_NAMESPACE" "$POD" "$GRPC_PORT:50051" > "$WORKDIR/port-forward-live.log" 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null' EXIT
sleep 3
kill -0 $PF_PID 2>/dev/null || { echo "❌ The port-forward failed:"; cat "$WORKDIR/port-forward-live.log"; exit 1; }

ARGS=(--server "localhost:$GRPC_PORT" --automatic-punctuation)
[ -n "$LANGUAGE_CODE" ] && ARGS+=(--language-code "$LANGUAGE_CODE")
[ -n "$INPUT_DEVICE" ] && ARGS+=(--input-device "$INPUT_DEVICE")

echo -e "\n🗣️  === Speak now. The text appears while you talk. Stop with Ctrl+C ===\n"
"$PY" "$MIC_CLIENT" "${ARGS[@]}"
