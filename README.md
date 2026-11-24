# RHOAI NIM

## Goal

Deploy models with the **NVIDIA NIM** inference server on **Red Hat OpenShift AI** (RHOAI 3.5, OpenShift 4.22), using GitOps-friendly Helm charts.

This repository is the NIM companion of [rhoai-serving](https://github.com/alvarolop/rhoai-serving) (vLLM deployments). Cluster infrastructure (GPU operators, Kueue, DRA, the RHOAI installation itself) lives in [rhoai-gitops](https://github.com/alvarolop/rhoai-gitops). Enabling NIM in the cluster (for example the NGC credentials) is considered a platform task and is out of scope here, unless stated otherwise.

## Deployment options

There are three ways to run NIM on OpenShift. This repository explores them in order, starting with the one supported by RHOAI.

| # | Option | How it works | Pros | Cons |
|---|--------|--------------|------|------|
| 1 | **RHOAI native NIM** (starting point) | RHOAI's *NVIDIA NIM model serving platform*: an `Account` CR holds the NGC credentials and RHOAI creates the runtime template. Models are served as KServe `ServingRuntime` + `InferenceService`. | Supported by RHOAI, dashboard integration (deploy, NIM metrics), hardware profiles | Legacy KServe path, no `LLMInferenceService`, so llm-d and MaaS integration is to be confirmed |
| 2 | **Direct `ServingRuntime` + `InferenceService`** | The chart renders its own NIM runtime, NGC secrets, image pull secret and cache PVC, without the `Account` CR. | Full control, simple GitOps, no dependency on the `Account` flow | Not the supported path, the chart owns details that RHOAI would manage, less dashboard integration |
| 3 | **NVIDIA NIM Operator** | NVIDIA's operator with `NIMCache` and `NIMService` CRs, independent of KServe. | Native NVIDIA lifecycle (caching, scaling, upgrades) | Outside RHOAI serving: no KServe, MaaS or Kueue integration out of the box |

## Status

Work in progress. Next step: explore option 1, RHOAI native NIM.

## License

[MIT](LICENSE)
