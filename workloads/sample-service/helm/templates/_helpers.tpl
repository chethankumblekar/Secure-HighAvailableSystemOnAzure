{{- define "sample-service.name" -}}
sample-service
{{- end -}}

{{- define "sample-service.labels" -}}
app.kubernetes.io/name: {{ include "sample-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: tenantforge
{{- end -}}

{{- define "sample-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "sample-service.name" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}
