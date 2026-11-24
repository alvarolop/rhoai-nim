# RHOAI NIM

## Goal

Deploy models with the **NVIDIA NIM** inference server on **Red Hat OpenShift AI** (RHOAI 3.5, OpenShift 4.22), using GitOps-friendly Helm charts.

This repository is the NIM companion of [rhoai-serving](https://github.com/alvarolop/rhoai-serving) (vLLM deployments). Cluster infrastructure (GPU operators, Kueue, DRA, the RHOAI installation itself) lives in [rhoai-gitops](https://github.com/alvarolop/rhoai-gitops). Enabling NIM in the cluster (for example the NGC credentials) is considered a platform task and is out of scope here, unless stated otherwise.

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
