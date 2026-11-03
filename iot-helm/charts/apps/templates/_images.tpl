{{/*
Application images are mutable lab ImageStreamTags only in lab mode.
A release requires an explicit immutable OCI digest for every service.
*/}}
{{- define "iot.image" -}}
{{- $name := .name -}}
{{- $values := .values -}}
{{- if eq $values.imageMode "release" -}}
  {{- $image := index $values.images $name -}}
  {{- if not $image -}}
    {{- fail (printf "release image missing for %s" $name) -}}
  {{- end -}}
  {{- if not (regexMatch "@sha256:[0-9a-f]{64}$" $image) -}}
    {{- fail (printf "release image must use a sha256 digest: %s" $name) -}}
  {{- end -}}
  {{- $image -}}
{{- else if eq $values.imageMode "lab" -}}
  {{- printf "image-registry.openshift-image-registry.svc:5000/atakangul-dev/%s:latest" $name -}}
{{- else -}}
  {{- fail (printf "unsupported imageMode: %s" $values.imageMode) -}}
{{- end -}}
{{- end -}}
