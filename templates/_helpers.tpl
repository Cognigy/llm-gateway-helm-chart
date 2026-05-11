{{/*
-------------------------------------------------------------------------------
Chart name, truncated to 63 chars.
-------------------------------------------------------------------------------
*/}}
{{- define "llm-gateway-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
-------------------------------------------------------------------------------
Full release name: honours fullnameOverride, otherwise <release>-<chart>,
truncated to 63 chars.
-------------------------------------------------------------------------------
*/}}
{{- define "llm-gateway-app.fullname" -}}
{{- if .Values.fullnameOverride }}
  {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
  {{- $name := default .Chart.Name .Values.nameOverride }}
  {{- if contains $name .Release.Name }}
    {{- .Release.Name | trunc 63 | trimSuffix "-" }}
  {{- else }}
    {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
  {{- end }}
{{- end }}
{{- end }}


{{/*
-------------------------------------------------------------------------------
Create chart name + version label value.
Example: llm-gateway-app-0.1.0
-------------------------------------------------------------------------------
*/}}
{{- define "llm-gateway-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
-------------------------------------------------------------------------------
Common Kubernetes recommended labels applied to every resource.
-------------------------------------------------------------------------------
*/}}
{{- define "llm-gateway-app.labels" -}}
helm.sh/chart: {{ include "llm-gateway-app.chart" . }}
{{ include "llm-gateway-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}


{{/*
-------------------------------------------------------------------------------
Selector labels — the minimal set used in matchLabels and Service selectors.
These must remain stable across upgrades; changing them requires recreating
the Deployment.
-------------------------------------------------------------------------------
*/}}
{{- define "llm-gateway-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "llm-gateway-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}


{{/*
-------------------------------------------------------------------------------
Resolve the ServiceAccount name.
Uses serviceAccount.name from values if set, otherwise falls back to the
chart fullname so that the SA and Deployment reference the same name.
-------------------------------------------------------------------------------
*/}}
{{- define "llm-gateway-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
  {{- default (include "llm-gateway-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
  {{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
-------------------------------------------------------------------------------
Render the TLS section for the Ingress spec.
Precedence:
  1. ingress.tls.secretName — explicit reference to a pre-existing secret.
  2. ingress.tls.crt + ingress.tls.key — chart creates the "llm-gateway-traefik"
     secret via templates/secrets/llm-gateway-traefik.yaml.
  3. "llm-gateway-traefik" already exists in the release namespace — uses it
     without creating a new one.
  4. None of the above → Helm fails with a descriptive error.

Usage in ingress.yaml:
  {{- include "llm-gateway-app.tlsCertificate.secretName.render" $ | nindent 2 }}
-------------------------------------------------------------------------------
*/}}
{{- define "llm-gateway-app.tlsCertificate.secretName.render" -}}
{{- $tlsCertificateSecretName := "" -}}
{{- if (.Values.ingress.tls.enabled) -}}
  {{- if .Values.ingress.tls.secretName -}}
    {{- $tlsCertificateSecretName = .Values.ingress.tls.secretName -}}
  {{- else if and (.Values.ingress.tls.crt) (.Values.ingress.tls.key) -}}
    {{- $tlsCertificateSecretName = "llm-gateway-traefik" -}}
  {{- else if lookup "v1" "Secret" $.Release.Namespace "llm-gateway-traefik" -}}
    {{- $tlsCertificateSecretName = "llm-gateway-traefik" -}}
  {{- else -}}
    {{ required "ingress.tls is enabled but no TLS secret is available. Provide ingress.tls.secretName, ingress.tls.crt+key, or ensure a \"llm-gateway-traefik\" secret exists in the release namespace." .Values.ingress.tls.secretName }}
  {{- end -}}
{{- end -}}
{{- if (not (empty $tlsCertificateSecretName)) -}}
tls:
  - secretName: {{- printf "%s" (tpl $tlsCertificateSecretName $) | indent 1 -}}
{{- end -}}
{{- end -}}

{{/*
-------------------------------------------------------------------------------
Pod labels — extends common labels with app and owner-team labels required by
Cognigy guidelines.
-------------------------------------------------------------------------------
*/}}
{{- define "llm-gateway-app.podLabels" -}}
{{ include "llm-gateway-app.labels" . }}
app: service-llm-gateway
app.kubernetes.io/component: service-llm-gateway
owner-team: {{ .Values.ownerTeam }}
{{- end }}


{{/*
-------------------------------------------------------------------------------
Return the proper Docker Image Registry Secret Names.
Precedence:
  1. imageCredentials.existingSecret — reference a pre-existing secret
     (preferred when managed externally by Flux/sealed-secrets).
  2. imageCredentials.registry + username + password — the chart creates the
     "<fullname>-registry" secret via templates/secrets/.
  3. None configured → renders nothing.
-------------------------------------------------------------------------------
*/}}
{{/*
-------------------------------------------------------------------------------
Resolve the MongoDB Atlas credentials Secret name.
Returns existingSecret when set, otherwise "<fullname>-mongodb-atlas-creds"
(created by templates/secrets/mongodb-atlas-credentials.yaml).
-------------------------------------------------------------------------------
*/}}
{{- define "llm-gateway-app.mongodbAtlas.secretName" -}}
{{- if .Values.mongodb.auth.atlas.existingSecret -}}
{{- .Values.mongodb.auth.atlas.existingSecret -}}
{{- else -}}
{{- printf "%s-mongodb-atlas-creds" (include "llm-gateway-app.fullname" .) -}}
{{- end -}}
{{- end -}}


{{- define "image.pullSecretsLlmGateway" -}}
  {{- $pullSecrets := list -}}

  {{- if .Values.imageCredentials.existingSecret -}}
    {{- $pullSecrets = append $pullSecrets .Values.imageCredentials.existingSecret -}}
  {{- else if and (.Values.imageCredentials.registry) (.Values.imageCredentials.username) (.Values.imageCredentials.password) -}}
    {{- $pullSecrets = append $pullSecrets (printf "%s-registry" (include "llm-gateway-app.fullname" .)) -}}
  {{- end -}}

  {{- if (not (empty $pullSecrets)) -}}
imagePullSecrets:
    {{- range $pullSecrets }}
  - name: {{ . }}
    {{- end -}}
  {{- end -}}
{{- end -}}


{{/*
-------------------------------------------------------------------------------
Caller secret resolution.

Each `callerSecrets` entry is a dict { serviceId, existingSecret?, existingSecretKey? }.
By default the chart auto-creates Secret "llm-gateway-caller-<serviceId>".
When existingSecret is set, the chart references that pre-shared Secret instead
(no auto-creation). existingSecretKey defaults to "secret".
-------------------------------------------------------------------------------
*/}}
{{- define "llm-gateway-app.caller.secretName" -}}
{{- if .existingSecret -}}{{ .existingSecret }}{{- else -}}llm-gateway-caller-{{ .serviceId }}{{- end -}}
{{- end -}}

{{- define "llm-gateway-app.caller.secretKey" -}}
{{- default "secret" .existingSecretKey -}}
{{- end -}}
