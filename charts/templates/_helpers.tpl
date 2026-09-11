{{- define "fastapiapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "fastapiapp.fullname" -}}
{{- if .Values.fullnameOverride }}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}{{ printf "%s-%s" .Release.Name (include "fastapiapp.name" .) | trunc 63 | trimSuffix "-" }}{{- end }}
{{- end }}
{{- define "fastapiapp.serviceName" -}}
{{- printf "%s-%s" (include "fastapiapp.fullname" .root) .name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "fastapiapp.databaseServiceName" -}}
{{- printf "%s-%s-db" (include "fastapiapp.fullname" .root) .name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "fastapiapp.databaseSecretName" -}}
{{- printf "%s-%s-db" (include "fastapiapp.fullname" .root) .name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "fastapiapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "fastapiapp.labels" -}}
helm.sh/chart: {{ include "fastapiapp.chart" . }}
{{ include "fastapiapp.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
environment: {{ .Values.environment | quote }}
{{- end }}
{{- define "fastapiapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fastapiapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "fastapiapp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}{{ default (include "fastapiapp.fullname" .) .Values.serviceAccount.name }}
{{- else }}{{ default "default" .Values.serviceAccount.name }}{{- end }}
{{- end }}
