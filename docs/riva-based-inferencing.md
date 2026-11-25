# Riva-based inferencing (speech NIMs)

The speech models of the [voice agent use case](../README.md#use-case-nemotron-voice-agent) (ASR and TTS) are served by **NVIDIA Speech NIMs**, which are built on the Riva stack (CUDA, TensorRT and Triton). They are not LLM NIMs, and they do not behave like the NIM that the RHOAI native NIM platform is designed for.

## Why this matters

When the `Account` CR is healthy, RHOAI generates a runtime Template (`odh-nim-account-template`) with a `ServingRuntime` named `nvidia-nim-runtime`. We inspected it on the cluster, and it is written for **LLM NIMs**:

| | RHOAI generated runtime (LLM NIM) | Speech NIM (ASR, TTS) |
|---|---|---|
| Container port | `8000` | `9000` (HTTP) and `50051` (gRPC) |
| Protocols | `v2` and `grpc-v2` (KServe) | gRPC, HTTP and WebSocket (realtime) |
| Model selection | Model baked into the image | `NIM_TAGS_SELECTOR` (for example `name=magpie-tts-multilingual`) |
| Env | `NIM_CACHE_PATH`, `NGC_API_KEY` | `NGC_API_KEY`, `NIM_HTTP_API_PORT`, `NIM_GRPC_API_PORT`, `NIM_TAGS_SELECTOR` |
| Metrics | Prometheus on `8000`, path `/v1/metrics` | Not verified |
| Readiness | Not set | `GET /v1/health/ready` on `9000` |
| Shared memory | `/dev/shm` emptyDir | `--shm-size=8GB` |

The runtime Template cannot be used as is: it exposes the wrong port and has no way to choose the speech model.

## Differences that affect the deployment

- **Two ports.** ASR and TTS expose HTTP on `9000` and gRPC on `50051`. The voice agent (Pipecat) talks to them from inside the cluster, so Services are enough. Exposing gRPC outside the cluster would need an HTTP/2-capable route, which is out of scope here.
- **Model selection by environment.** `NIM_TAGS_SELECTOR` picks the model and the profile:
  - ASR: `name=nemotron-asr-streaming,type=multi` (multilingual) or `type=en-US`. Default `batch_size` is `128`; `32` and `512` are available.
  - TTS: `name=magpie-tts-multilingual`. Default `batch_size=8`.
- **Long first start.** The first startup downloads the model and may build a TensorRT engine for the GPU: it can take **up to 30 minutes**. The probes need generous `startupProbe` settings, and the cache must be a PVC so that the next starts are fast.
- **ASR: streaming, not transcribe.** The catalog has two ASR images. `nemotron-asr-streaming` is for **live audio** and supports streaming mode only: it is the one the voice agent needs. `nemotron-transcribe` is for offline transcription, serves only an HTTP OpenAI-compatible API and does not use Triton.

## Engine profiles and the GPU

A speech NIM serves a TensorRT engine, and an engine is built for a GPU. The NIM image carries a manifest of **profiles**, and on start it picks the one that matches the GPU (or the one you force with `NIM_MODEL_PROFILE`). There are two kinds:

| Profile kind | What the NIM does | Start |
|---|---|---|
| **Prebuilt** (`model_type:prebuilt`, tagged with a GPU such as `NVIDIA-L40S`) | Downloads the finished engine from NGC | Fast: minutes, mostly download time |
| **`rmir`** (generic, no GPU in the tags) | Downloads the model and **compiles the engine on the GPU** (ONNX export, INT8 quantization, TensorRT build) | Slow, and it needs a lot of memory |

The `nemotron-asr-streaming` 1.5 manifest has prebuilt profiles for **L40S, A100, H100 and GB10** (and DGX Spark). **There is none for the L4.** List them with `list-model-profiles` inside the container: it shows the profiles compatible with the GPU of the node and the ones that are not.

What we saw on the L4 of this cluster:

- With the default selector the NIM chose the generic `rmir` profile (`batch_size=128`, `precision=int8`, `type=multi`) and compiled the engine. At the 16Gi memory limit it was **OOMKilled** (exit 137), and at 24Gi it was OOMKilled again during the INT8 quantization step. Each OOM restart began the build again, because the output goes to `/data/models`, which is not on a volume.
- The NIM lists the prebuilt **L40S** profiles as *compatible with system* on the L4, because both GPUs are compute capability 8.9 (Ada). Forcing one with `NIM_MODEL_PROFILE` skipped the build, and the pod went Ready in about 4 minutes.

`nim-model/values-nemotron-asr-streaming.yaml` sets `NIM_MODEL_PROFILE` to the prebuilt L40S profile (`batch_size=32`, multilingual). Remove the variable to go back to the engine build.

> [!NOTE]
> Not verified: whether NVIDIA supports an L40S engine on an L4 (it is a compatibility match, not a certified one), whether it transcribes with the same quality, and whether a GPU with its own prebuilt profile selects it automatically. We only ran the NIM on the L4. Whether later restarts re-unpack files into `/data/models` is open too.

## CPU or GPU?

**GPU only, through NIM.** The Speech NIM documentation describes the containers as GPU-accelerated (CUDA, TensorRT, Triton), and every `docker run` example uses `--runtime=nvidia --gpus`. No page mentions CPU support.

The models themselves are small (Magpie TTS 357M, ASR 0.6B), and their Hugging Face cards list community runtimes such as NeMo-Speech.cpp (GGUF) that can run on CPU. That is a different server, not a NIM, so it is out of scope for this repository.

Requirements found in a web search of the NVIDIA documentation, to be confirmed in the [ASR](https://docs.nvidia.com/nim/speech/latest/reference/support-matrix/asr.html) support matrix and the TTS one: compute capability 8.0 or higher (an L4 qualifies) and about 11 GB of VRAM for Magpie at `batch_size=8`.

## Decision

1. **Keep the `Account`** for what it does well: it validates the NGC key, creates the pull secret and publishes the model catalog.
2. **Do not use the generated runtime Template for speech models.** The `nim-model` chart renders its own `ServingRuntime` and `InferenceService`, with ports, environment and cache mount set per model type (LLM or speech) through values.
3. **Validate first with Magpie TTS**, the smallest model: it is the quickest test of whether a speech NIM runs under KServe with our runtime.

> [!NOTE]
> Status: this is the plan, not yet verified on the cluster. Open points to test: whether KServe routes to port `9000` when the container also declares `50051`, where the speech NIMs expect the model cache (the chart must mount a PVC there), and whether the NIM runs as the non-root user that OpenShift assigns.

## Sources

- [NVIDIA Speech NIM overview](https://docs.nvidia.com/nim/riva/tts/latest/getting-started.html)
- [Nemotron ASR Streaming deployment](https://docs.nvidia.com/nim/speech/latest/asr/deploy-asr-models/nemotron-asr-streaming.html)
- [Deploy and run the TTS NIM](https://docs.nvidia.com/nim/speech/26.02.0/tts/deploy-tts-model.html)
- [Magpie TTS Multilingual in the NGC catalog](https://catalog.ngc.nvidia.com/orgs/nim/nvidia/containers/magpie-tts-multilingual)
- [Nemotron ASR Streaming in the NGC catalog](https://catalog.ngc.nvidia.com/orgs/nim/nvidia/containers/nemotron-asr-streaming)
- [Magpie TTS Multilingual 357M model card](https://huggingface.co/nvidia/magpie_tts_multilingual_357m)
- [Nemotron 3.5 ASR Streaming model card](https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b)
