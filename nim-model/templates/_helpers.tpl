{{/*
GPU through DRA (true) or through the NVIDIA device plugin, nvidia.com/gpu limits (false).
*/}}
{{- define "nim-model.useDra" -}}
{{- if (.Values.dra).enabled -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{/* Name of the pod-level claim (spec.predictor.resourceClaims[].name) and of the container reference (resources.claims[].name). */}}
{{- define "nim-model.draClaimName" -}}gpu{{- end -}}

{{/* Platform-defined ResourceClaimTemplate in the models namespace (rhoai-gitops 06-dra). */}}
{{- define "nim-model.draClaimTemplateName" -}}
{{- required "dra.claimTemplate is required when dra.enabled is true (e.g. gpu-m-x1), or set dra.enabled=false" .Values.dra.claimTemplate -}}
{{- end -}}

{{/*
Container resources. Device plugin: rendered as is. DRA: nvidia.com/gpu is removed from limits/requests and replaced by
resources.claims -> the pod-level claim, so the GPU is not requested twice.
*/}}
{{- define "nim-model.resources" -}}
{{- $res := .Values.resources | default dict -}}
{{- if eq (include "nim-model.useDra" . | trim) "true" -}}
{{- $r := deepCopy $res -}}
{{- range $side := list "limits" "requests" -}}
{{- if hasKey $r $side -}}
{{- $o := omit (index $r $side | default dict) "nvidia.com/gpu" -}}
{{- if $o }}{{- $_ := set $r $side $o -}}{{- else }}{{- $_ := unset $r $side -}}{{- end -}}
{{- end -}}
{{- end -}}
{{- $_ := set $r "claims" (list (dict "name" (include "nim-model.draClaimName" .))) -}}
{{- toYaml $r -}}
{{- else -}}
{{- toYaml $res -}}
{{- end -}}
{{- end -}}

{{/*
HardwareProfile name. With DRA, gpu-profile is swapped for dra.hardwareProfile (gpu-dra-profile: same queue, but NO
nvidia.com/gpu identifier): with gpu-profile the RHOAI webhook adds nvidia.com/gpu on top of the claim and Kueue counts 2 GPUs.
*/}}
{{- define "nim-model.hardwareProfileName" -}}
{{- $n := .Values.hardwareProfile.name | default "" -}}
{{- if and (eq (include "nim-model.useDra" . | trim) "true") (eq $n "gpu-profile") .Values.dra.hardwareProfile -}}{{ .Values.dra.hardwareProfile }}{{- else -}}{{ $n }}{{- end -}}
{{- end -}}

{{/*
Write the opendatahub.io/hardware-profile-* annotations? Always without DRA. With DRA only when the effective profile is the
DRA one: any other GPU profile would make the webhook inject nvidia.com/gpu next to the claim. When the annotation is
written, the RHOAI admission adds the Kueue queue-name label from the profile, so the chart only writes it when this is false.
*/}}
{{- define "nim-model.hasHardwareProfile" -}}
{{- if and .Values.hardwareProfile.name (or (ne (include "nim-model.useDra" . | trim) "true") (and .Values.dra.hardwareProfile (eq (include "nim-model.hardwareProfileName" . | trim) .Values.dra.hardwareProfile))) -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{/* Kueue LocalQueue, only used when the hardware-profile annotation is NOT written (rhoai-gitops reserved-spot queues). */}}
{{- define "nim-model.kueueLocalQueue" -}}
{{- $hp := .Values.hardwareProfile.name | default "" -}}
{{- if or (eq $hp "gpu-profile") (eq $hp "gpu-dra-profile") -}}serving-lq
{{- else if or (eq $hp "gpu-batch-profile") (eq $hp "gpu-dra-batch-profile") -}}batch-lq
{{- else -}}default
{{- end -}}
{{- end -}}

{{/* Kueue WorkloadPriorityClass: always written by the chart (the HardwareProfile priority is not applied to the workload). */}}
{{- define "nim-model.kueuePriorityClass" -}}
{{- $hp := .Values.hardwareProfile.name | default "" -}}
{{- if or (eq $hp "gpu-profile") (eq $hp "gpu-dra-profile") -}}model-critical
{{- else if or (eq $hp "gpu-batch-profile") (eq $hp "gpu-dra-batch-profile") -}}batch-nightly
{{- end -}}
{{- end -}}
