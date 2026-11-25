# RHOAI NIM

## Goal

Deploy models with the **NVIDIA NIM** inference server on **Red Hat OpenShift AI** (RHOAI 3.5, OpenShift 4.22), using GitOps-friendly Helm charts.

This repository is the NIM companion of [rhoai-serving](https://github.com/alvarolop/rhoai-serving) (vLLM deployments). Cluster infrastructure (GPU operators, Kueue, DRA, the RHOAI installation itself) lives in [rhoai-gitops](https://github.com/alvarolop/rhoai-gitops). Enabling NIM in the cluster (for example the NGC credentials) is considered a platform task and is out of scope here, unless stated otherwise.

## Use case: Nemotron voice agent

The models deployed from this repository are the building blocks of the [Nemotron Voice Agent](https://github.com/NVIDIA-AI-Blueprints/nemotron-voice-agent) NVIDIA blueprint: a real-time voice assistant that you talk to from the browser. The blueprint is a cascaded streaming pipeline, orchestrated by [Pipecat](https://github.com/pipecat-ai/pipecat) and reached over WebRTC. Each stage is an independent model server, so each one is a model deployment of this repository:

```
 microphone ──▶ ASR (speech to text) ──▶ LLM (understands and answers) ──▶ TTS (text to speech) ──▶ speaker
                                  (Pipecat orchestrates the three, with VAD and turn-taking)
```

| Stage | Model | Purpose | NIM image in the NGC catalog |
|---|---|---|---|
| **ASR** | [nemotron-3.5-asr-streaming-0.6b](https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b) | Turns the user's speech into text while they are still talking (cache-aware streaming, 80 ms to 1.12 s chunks, 40 locales) | [`nvcr.io/nim/nvidia/nemotron-asr-streaming`](https://catalog.ngc.nvidia.com/orgs/nim/nvidia/containers/nemotron-asr-streaming) (live audio; `nemotron-transcribe` is for offline use) |
| **LLM** | Out of scope: the reasoning model is not deployed in this cluster | The "brain": understands the text and writes the answer. The blueprint accepts any OpenAI-compatible endpoint, so it is provided from outside | None |
| **TTS** | [magpie_tts_multilingual_357m](https://huggingface.co/nvidia/magpie_tts_multilingual_357m) | Speaks the answer with a natural voice (12 languages, 5 English voices) | [`nvcr.io/nim/nvidia/magpie-tts-multilingual`](https://catalog.ngc.nvidia.com/orgs/nim/nvidia/containers/magpie-tts-multilingual) |
| *Optional* | [Nemotron-3-Diarization](https://huggingface.co/nvidia/Nemotron-3-Diarization) | Answers "who spoke when" (up to 8 speakers). It does not transcribe: it only adds speaker labels next to the ASR. It is not a stage of the default pipeline, only needed for multi-speaker conversations | None in the catalog of our cluster |

> [!NOTE]
> The speech models are Riva-based NIMs, GPU only, and they do not fit the generic runtime that RHOAI generates for LLM NIMs. See [docs/riva-based-inferencing.md](docs/riva-based-inferencing.md).

## Deployment options

There are three ways to run NIM on OpenShift, plus vLLM as the non-NIM reference. This repository explores them in order, starting with the one supported by RHOAI.

| # | Option | How it works | Pros | Cons |
|---|--------|--------------|------|------|
| 1 | **RHOAI native NIM** (starting point) | RHOAI's *NVIDIA NIM model serving platform*: an `Account` CR holds the NGC credentials and RHOAI creates the runtime template. Models are served as KServe `ServingRuntime` + `InferenceService`. | Supported by RHOAI, dashboard integration (deploy, NIM metrics), hardware profiles | Legacy KServe path, no `LLMInferenceService`, so llm-d and MaaS integration is to be confirmed |
| 2 | **Direct `ServingRuntime` + `InferenceService`** | The chart renders its own NIM runtime, NGC secrets, image pull secret and cache PVC, without the `Account` CR. | Full control, simple GitOps, no dependency on the `Account` flow | Not the supported path, the chart owns details that RHOAI would manage, less dashboard integration |
| 3 | **NVIDIA NIM Operator** | NVIDIA's operator with `NIMCache` and `NIMService` CRs, independent of KServe. | Native NVIDIA lifecycle (caching, scaling, upgrades) | Outside RHOAI serving: no KServe, MaaS or Kueue integration out of the box |
| 4 | **vLLM** (alternative engine, not NIM) | `LLMInferenceService` with the vLLM image shipped in RHOAI, routed by llm-d and optionally exposed through MaaS. This is what [rhoai-serving](https://github.com/alvarolop/rhoai-serving) already does. | Fully supported by RHOAI, llm-d routing, MaaS, Kueue and DRA, no NGC account or NVIDIA licence, runs on non-NVIDIA hardware | Not NIM: no NVIDIA-tuned model profiles |

## NIM vs TensorRT-LLM vs vLLM

NIM is a packaged product, while TensorRT-LLM and vLLM are inference engines. NIM can use TensorRT-LLM or vLLM internally depending on the model, so they are not always exclusive.

| | **NIM** | **TensorRT-LLM** | **vLLM** |
|---|---|---|---|
| What it is | Container (microservice) with engine, runtime and model profiles | NVIDIA open-source engine, with its own server (`trtllm-serve`) or Triton | Open-source engine and OpenAI-compatible server |
| License | NVIDIA AI Enterprise for production (free tier for development) | Apache 2.0 | Apache 2.0 |
| Hardware | NVIDIA GPUs only | NVIDIA GPUs only | NVIDIA, AMD, Intel, CPU and others |
| Model preparation | Automatic: pre-built profile per model and GPU, weights from NGC | You build and tune the engine per model and GPU (the PyTorch backend reduces this) | Loads Hugging Face checkpoints directly |
| API | OpenAI-compatible | OpenAI-compatible (`trtllm-serve`) | OpenAI-compatible |
| Performance on NVIDIA | Very good, tuned by NVIDIA | Usually the highest, with tuning effort | Close, more flexible |
| RHOAI integration | Native NIM platform (KServe `ServingRuntime` + `InferenceService`) | None supported: needs a custom runtime | Native and supported (`LLMInferenceService`, llm-d, MaaS) |
| llm-d | Not applicable (own stack) | Supported as engine type `trtllm-serve` in the **community** llm-d (needs TensorRT-LLM v1.3.0rc12+ and the perf stats enabled for the EPP metrics) | Default engine of llm-d, including the one shipped in RHOAI |
| Effort | Low | High | Low |

> [!NOTE]
> The performance and licensing rows are general statements to be validated on our own cluster. TensorRT-LLM support in the llm-d shipped with RHOAI (as opposed to the community project) is to be confirmed before treating it as a deployment path.

## Prerequisites

The cluster side of NIM is owned by [rhoai-gitops](https://github.com/alvarolop/rhoai-gitops), like the namespaces of the other model repositories: it enables the NIM component of OpenShift AI and creates the models namespace, `rhoai-nim-models` by default, with its labels, the `opendatahub.io/nim-support` annotation, the Kueue LocalQueues and the DRA claim templates. This repository only needs its **name**, which must be the same in both: `namespace.name` in `nim-platform/values.yaml` and `NIM_NAMESPACE` in `auto-install.sh`. `auto-install.sh` stops if the namespace does not exist.

What this repository creates:

| Chart | What it creates |
|---|---|
| `nim-platform` | The NIM `Account` (in `redhat-ods-applications`, where the dashboard looks for it) and the NGC secrets |
| `nim-model` | One model: `ServingRuntime`, `InferenceService` and the cache PVC |

### GPUs: DRA or device plugin

Models request their GPU in one of two ways, selected per model with `dra.enabled` (default `true`) in `nim-model/values.yaml`:

- **DRA:** the pod references a `ResourceClaimTemplate` of the models namespace (`dra.claimTemplate`, `gpu-m-x1` by default, an L4-class GPU). The templates are defined by rhoai-gitops (`06-dra`). The `nvidia.com/gpu` limit is removed and the HardwareProfile becomes `gpu-dra-profile`: with the plain `gpu-profile` the GPU would be counted twice.
- **Device plugin:** `--set dra.enabled=false` requests `nvidia.com/gpu` and keeps `gpu-profile`.

The Kueue queue does not need to be set: the chart writes the HardwareProfile annotation and the RHOAI admission adds the `queue-name` label from the profile. The chart only writes it when there is no profile annotation, and it always writes the priority class.

## NGC API key

The RHOAI `Account` CR needs an NVIDIA NGC API key to validate your access and to pull NIM images and models.
Save it in the git-ignored file `ngc-api-key` (see `ngc-api-key.example`), which `auto-install.sh` reads.

> [!IMPORTANT]
> Get the key at <https://org.ngc.nvidia.com/account/api-keys>. You first need to create an NGC organization for yourself using your personal email, and then an account in that organization.
>
> When generating the key, under **Services Included** select **NGC Catalog**: it is the permission that lets the key pull NIM images and models from NGC. Leave **Secrets Manager** unselected, nothing in this repo uses it. Copy the key right away, it is shown only once.

## Status

Work in progress. Next step: explore option 1, RHOAI native NIM.

## License

[MIT](LICENSE)
