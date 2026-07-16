{{- define "demo-app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "demo-app.labels" -}}
app.kubernetes.io/name: {{ include "demo-app.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: nginx-kind
{{- end -}}

{{- define "demo-app.selectorLabels" -}}
app: {{ include "demo-app.fullname" . }}
{{- end -}}
