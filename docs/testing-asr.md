# Testing the ASR NIM

How to check that `nemotron-asr-streaming` works, with `./test-asr.sh`. The same ideas apply to the TTS model.

## What an ASR model does

ASR (automatic speech recognition) turns audio into text. You send it a WAV file (or live microphone audio) and it returns the words. There is no "chat" here: it is a speech server, not an LLM.

This NIM is **streaming only**: it is designed for live audio, so the client sends the audio in small chunks and gets partial results while the person is still talking. For a test we send a short file and the client streams it chunk by chunk, as a microphone would.

## The three ways to reach it

The NIM listens on two ports. Both are exposed by the Service `nemotron-asr-streaming-predictor` of the models namespace.

| Port | Protocol | Use |
|---|---|---|
| `9000` (Service port `80`) | HTTP | `GET /v1/health/ready`, and the **Realtime API** (WebSocket, streaming) |
| `50051` | gRPC | The Riva API: `--list-models` and streaming transcription. It is what the Pipecat voice agent uses |

There is no simple "upload a file with `curl`" endpoint for this model, because it is streaming only. That is why the test uses NVIDIA's client scripts instead of `curl`.

## Exposing it outside the cluster (optional)

By default the model is only reachable from inside the cluster, which is all the voice agent needs: Pipecat runs in the cluster and calls the Service. The chart can add an OpenShift **Route** for the HTTP port (health and the WebSocket Realtime API), for example to test from your laptop without a port-forward:

```bash
helm template ... --set route.enabled=true      # or route.enabled: true in the model values file
```

- **No authentication:** with `auth.enabled: false` anyone who has the URL can use the model and the GPU. Keep it off, or turn it on only for a test.
- **HTTP only:** gRPC (50051) is not exposed, because the router would need an HTTP/2 route. `test-asr.sh` therefore keeps using a port-forward.
- **Long sessions:** the Route sets the router timeout to `1h` (`route.timeout`), as streaming sessions are long WebSockets.
- **Not tested with auth on:** with `auth.enabled: true` the Service port changes (the model sits behind `kube-rbac-proxy`), so the Route would need to be adapted.

## Run the test

```bash
oc login ...                  # you need access to the models namespace
./test-asr.sh                 # uses the sample WAV that ships inside the NIM image
./test-asr.sh my-audio.wav    # or your own audio: 16 kHz, mono, 16-bit PCM WAV works best
```

The script does this:

1. **Port-forwards** the Service to `localhost:9000` and `localhost:50051`, and closes it when it ends.
2. **Check 1, ready?** `GET /v1/health/ready` must return `200`. If not, it tells you to follow the logs.
3. Prepares a Python venv with `nvidia-riva-client`, clones NVIDIA's [python-clients](https://github.com/nvidia-riva/python-clients) and copies the sample audio out of the pod. All of it is kept in `/tmp/test-asr`, so the next runs are faster.
4. **Check 2, which models?** `transcribe_file.py --list-models`, over gRPC.
5. **Check 3, transcribe.** `transcribe_file.py --automatic-punctuation --input-file <audio>`: it streams the audio and prints the text.

Variables you can change: `NIM_NAMESPACE`, `MODEL_NAME`, `LANGUAGE_CODE`, `WORKDIR`, `HTTP_PORT`, `GRPC_PORT`.

### Result

Output of a run on the cluster (Nemotron ASR Streaming, `type=multi`, on the L4 with the prebuilt L40S profile, see [engine profiles](riva-based-inferencing.md#engine-profiles-and-the-gpu)):

```
🩺 === Check 1: is the NIM ready? ===
✅ GET /v1/health/ready returned 200

📋 === Check 2: which models does the server offer? (gRPC) ===
Available ASR models
{'bg-BG,cs-CZ,da-DK,de-DE,...,en-US,es-ES,...,zh-CN,vi-VN,auto': [{'model': ['cache-aware-parakeet-rnnt-multi-asr-streaming-sortformer']}]}

📝 === Check 3: transcribe the audio, streamed in chunks (gRPC) ===
## What is natural language processing?
```

The model list shows the 40 locales plus `auto` (language detection) served by one model. The sentence is the content of the sample WAV, so the model works.

### Language

The deployed profile is `type=multi` (multilingual, see `nim-model/values-nemotron-asr-streaming.yaml`). With no `LANGUAGE_CODE` the model **detects the language** by itself. To force one, for example `LANGUAGE_CODE=fr-FR ./test-asr.sh fr.wav`. With the English profile (`type=en-US`) you must pass `en-US`.

## Test with your own voice (microphone)

`./test-asr-live.sh` streams your microphone to the NIM and prints the text **while you speak**, which is how the voice agent uses it. Stop it with Ctrl+C.

```bash
./test-asr-live.sh                        # default microphone, automatic language detection
./test-asr-live.sh --list-devices         # list the audio inputs and their numbers
INPUT_DEVICE=3 ./test-asr-live.sh         # another microphone
LANGUAGE_CODE=es-ES ./test-asr-live.sh    # force a language
```

It uses `transcribe_mic.py` from the same `python-clients` as `test-asr.sh` (and the same `/tmp/test-asr` folder), over gRPC through a port-forward to the pod. It shows partial results first and then the final text of each sentence.

- **PyAudio:** the microphone needs it, and it needs the PortAudio library and headers on your machine, for example `sudo dnf install portaudio-devel python3-devel gcc` on Fedora. The script tells you if the install fails.
- **Latency:** the audio travels from your laptop to the cluster, so the delay includes your network. The real voice agent runs in the cluster next to the model, so it will feel faster.
- **Status:** this script has **not been run** yet, it was written from the client's options. If something fails, `--list-devices` is the first thing to check.

## First start

The first start of the pod is slow: the NIM downloads the model and the TensorRT engine. With a prebuilt profile, as we use on the L4, it took about 4 minutes. Without one it **compiles the engine on the GPU**, which takes far longer. The pod stays `1/3` Running and the probe fails with `connection refused` until it is done. Follow it with:

```bash
oc logs -f -n rhoai-nim-models deploy/nemotron-asr-streaming-predictor -c kserve-container
```

Problems we found on the way, already fixed in the chart:

| Symptom | Cause | Fix |
|---|---|---|
| `HTTP 402 Payment Required` downloading the model | The NGC org lacks the entitlement of that model (Magpie TTS needs `nim-dev`) | Use a model with public weights, or get the entitlement. ASR is public. |
| `Permission denied: '/opt/nim/workspace'` | The directory is root-owned and OpenShift runs the pod as a random user | `workspace` emptyDir volume in the chart |
| `OOMKilled`, exit code 137 | No prebuilt engine exists for the L4, so the NIM compiled one and ran out of memory (even at 24Gi) | `NIM_MODEL_PROFILE` set to the prebuilt L40S profile in the ASR values. See [engine profiles](riva-based-inferencing.md#engine-profiles-and-the-gpu) |

## Realtime API (optional)

The HTTP port also offers the WebSocket Realtime API. With the same venv:

```bash
python python-clients/scripts/asr/realtime_asr_client.py --server localhost:9000 \
  --language-code en-US --automatic-punctuation --input-file en-US_sample.wav
```

This path is not part of `test-asr.sh` and has not been tested here.

## Sources

- [Nemotron ASR Streaming deployment and run inference](https://docs.nvidia.com/nim/speech/latest/asr/deploy-asr-models/nemotron-asr-streaming.html)
- [nvidia-riva/python-clients](https://github.com/nvidia-riva/python-clients)
