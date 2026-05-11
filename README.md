# llm-gateway-app Helm Chart

Helm chart for deploying the Cognigy LLM Gateway service.

## Prerequisites

- Kubernetes cluster >= 1.21
- Helm 3.x
- kubectl configured to access your cluster
- Required secrets (see configuration options below):
  - TLS certificate — provide `ingress.tls.secretName` for an existing secret, OR provide `ingress.tls.crt` + `ingress.tls.key` values (chart will create the `llm-gateway-traefik` secret automatically)

## Subchart Deployment (cognigy-ai namespace)

When deploying as a subchart inside `cognigy-ai`, the required defaults (`imageCredentials.existingSecret`, `rabbitmq.existingSecret`, TLS secret name, etc.) are already configured. Enable the ingress and provide a hostname:

```yaml
ingress:
  enabled: true
  host: "llm-gateway.test"
```

Install into the `cognigy-ai` namespace:

```bash
helm upgrade --install service-llm-gateway ./charts/llm-gateway-app \
  -f ./charts/llm-gateway-app/values-local.yaml \
  --namespace cognigy-ai
```

## Installation

### 1. Configure Your Values

Create a `values-local.yaml` file (this file is gitignored).

**Required configurations:**
- Image registry credentials (or reference an existing pull secret)
- `ingress.host`
- TLS secret or certificate values

**Example for local development:**

See [`values-local-template.yaml`](./values-local-template.yaml) for a ready-to-use starting point. Copy it to `values-local.yaml` and fill in the required fields:

```bash
cp charts/llm-gateway-app/values-local-template.yaml charts/llm-gateway-app/values-local.yaml
```

**Example for production / Flux (using an existing pull secret):**

```yaml
imageCredentials:
  existingSecret: "my-registry-secret"   # override the subchart default

serviceLlmGateway:
  rabbitmq:
    existingSecret: "my-rabbitmq-secret"  # override the subchart default

ingress:
  enabled: true
  host: "llm-gateway.yourdomain.com"
  tls:
    secretName: "my-tls-secret"           # override the subchart default
```

### 2. Install the Chart

```bash
# From the repository root — for standalone deployment
helm upgrade --install llm-gateway ./charts/llm-gateway-app \
  -f ./charts/llm-gateway-app/values.yaml \
  -f ./charts/llm-gateway-app/values-local.yaml \
  --namespace <release-namespace> \
  --create-namespace
```

### 3. Verify Installation

```bash
# Check the release status
helm status llm-gateway -n <release-namespace>

# Check pods
kubectl get pods -n <release-namespace> -l app.kubernetes.io/name=llm-gateway-app

# Check logs
kubectl logs -n <release-namespace> -l app.kubernetes.io/name=llm-gateway-app --tail=100 -f
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.imageRegistry` | Docker registry for all images | `cognigy.azurecr.io` |
| `ownerTeam` | Team label applied to all pods and services | `"carbon"` |
| `imageCredentials.registry` | Registry for auto-created pull secret | `cognigy.azurecr.io` |
| `imageCredentials.username` | Registry username (creates pull secret when set) | `""` |
| `imageCredentials.password` | Registry password (creates pull secret when set) | `""` |
| `imageCredentials.existingSecret` | Name of a pre-existing pull secret (e.g. managed by Flux). When set, no Secret is created and username/password are ignored. | `"cognigy-registry-token"` |
| `serviceLlmGateway.replicaCount` | Number of pod replicas | `3` |
| `serviceLlmGateway.image.name` | Container image name | `service-llm-gateway` |
| `serviceLlmGateway.image.tag` | Container image tag. Stamped to `v<version>` at release time by the CI pipeline — do not override in production. | `latest` (repo placeholder) |
| `serviceLlmGateway.resources.limits.cpu` | CPU limit | `500m` |
| `serviceLlmGateway.resources.limits.memory` | Memory limit | `512Mi` |
| `serviceLlmGateway.priorityClassName` | PriorityClass name for the pod | `""` |
| `serviceLlmGateway.service.annotations` | Additional Service annotations | `{}` |
| `serviceLlmGateway.autoscaling.enabled` | Enable HPA | `false` |
| `serviceLlmGateway.podDisruptionBudget.enabled` | Enable PDB | `false` |
| `serviceLlmGateway.podDisruptionBudget.minAvailable` | Min available pods (used when enabled) | `1` |
| `serviceLlmGateway.podDisruptionBudget.maxUnavailable` | Max unavailable pods (used when enabled) | `""` |
| `serviceLlmGateway.networkPolicy.enabled` | Enable network policy | `true` |
| `serviceLlmGateway.networkPolicy.allowedLLMProviderCIDRs` | CIDRs allowed for LLM provider egress | `["0.0.0.0/0"]` |
| `serviceLlmGateway.encryptionKey.existingSecret` | Pre-existing Secret containing the encryption key (Flux/sealed-secrets). When set, chart skips creation. | `""` |
| `serviceLlmGateway.encryptionKey.value` | Literal encryption key for local dev. Empty = auto-generated on first install. | `""` |
| `serviceLlmGateway.jwtSecret.existingSecret` | Pre-existing Secret containing the JWT secret (Flux/sealed-secrets). When set, chart skips creation. | `""` |
| `serviceLlmGateway.jwtSecret.value` | Literal JWT secret for local dev. Empty = auto-generated on first install. | `""` |
| `serviceLlmGateway.callerSecrets` | List of `{serviceId, existingSecret?, existingSecretKey?}` entries authorized to call the API. By default each entry auto-creates a Secret `llm-gateway-caller-<id>` and injects `SERVICE_SECRET_<ID>` into the deployment. | `[]` |
| `database.type` | Database backend — only `"mongodb"` is currently supported | `"mongodb"` |
| `mongodb.scheme` | Connection scheme: `"mongodb"` for self-hosted, `"mongodb+srv"` for Atlas | `"mongodb"` |
| `mongodb.hosts` | Replica-set members (self-hosted) or Atlas SRV hostname (Atlas). Required when `dbinit.enabled` is true. | `""` |
| `mongodb.params` | Optional connection string parameters appended after the database name. Leading char must be `&` for self-hosted (appended after `?authSource=…`) or `?` for Atlas (appended directly after `/<dbName>`). | `""` |
| `mongodb.dbinit.enabled` | Enable standalone DB initialisation (auto-creates service user via Helm hooks) | `false` |
| `mongodb.dbinit.image` | Image used by the db-init Job. Must include `mongosh` for `scheme: mongodb` and the `atlas` CLI for `scheme: mongodb+srv`. The Cognigy image at `cognigy.azurecr.io/mongodb:<tag>` bundles both. | `""` |
| `mongodb.auth.existingSecret` | Pre-existing Secret with MongoDB root credentials (self-hosted only). When empty the chart auto-copies root creds from `mongodb.auth.lookup`. | `""` |
| `mongodb.auth.atlas.existingSecret` | Pre-existing Secret with Atlas API credentials (Atlas only). Required keys: `apikeypublic`, `apikeyprivate`, `projectid`, `clustername`. | `""` |
| `mongodb.auth.atlas.projectId` | Atlas project ID (used when `atlas.existingSecret` is empty) | `""` |
| `mongodb.auth.atlas.clusterName` | Atlas cluster name (used when `atlas.existingSecret` is empty) | `""` |
| `mongodb.auth.atlas.publicAPIKey` | Atlas public API key with Project Owner permissions (used when `atlas.existingSecret` is empty) | `""` |
| `mongodb.auth.atlas.privateAPIKey` | Atlas private API key (used when `atlas.existingSecret` is empty) | `""` |
| `mongodb.connectionString` | Literal MongoDB connection string for local dev/testing (skipped when `dbinit.enabled` is true) | `""` |
| `serviceLlmGateway.rabbitmq.existingSecret` | Name of a pre-existing Secret containing the RabbitMQ connection string (preferred in Flux-managed environments). When set, `connectionString` is ignored. | `"cognigy-rabbitmq"` |
| `serviceLlmGateway.rabbitmq.connectionString` | Literal RabbitMQ connection string (`amqp://user:pass@host:port`). The chart creates a Secret and mounts the value as a file. | `""` |
| `serviceLlmGateway.podMonitor.enabled` | Enable Prometheus PodMonitor | `false` |
| `serviceLlmGateway.podMonitor.metricsPort` | Prometheus metrics port | `8002` |
| `serviceLlmGateway.podMonitor.namespace` | Namespace for the PodMonitor resource | `""` (release namespace) |
| `serviceAccount.create` | Create a ServiceAccount | `false` |
| `serviceAccount.name` | Override the ServiceAccount name | `""` |
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `traefik` |
| `ingress.host` | Ingress hostname (required when ingress is enabled) | `""` |
| `ingress.annotations` | Additional ingress annotations (entrypoints and middlewares are pre-filled) | see values.yaml |
| `ingress.tls.enabled` | Enable TLS | `true` |
| `ingress.tls.secretName` | Existing TLS secret name | `llm-gateway-traefik` |
| `ingress.tls.crt` | TLS certificate in plaintext (creates secret when secretName is empty) | `""` |
| `ingress.tls.key` | TLS private key in plaintext (creates secret when secretName is empty) | `""` |

### MongoDB Connection

Two modes are supported — pick one per deployment:

**Mode A — Standalone dbinit (production / Flux / dedicated namespace):**
The chart auto-generates the service user password, creates the MongoDB user via a Helm pre-install/pre-upgrade Job, and builds the connection secret — no manual secret management required.

#### Self-hosted (scheme: mongodb)

Hook execution order:
1. **weight -3** `mongodb-root-credentials` — copies or references the MongoDB root credential Secret
2. **weight -2** `service-llm-gateway-mongodb` — generates a random 64-char service user password (preserved across upgrades)
3. **weight -1** db-init Job — connects via `mongosh` as root and creates/updates the `service-llm-gateway` user with `readWrite` access

```yaml
database:
  type: mongodb
mongodb:
  scheme: "mongodb"
  hosts: "mongodb-0.mongodb-headless.mongodb.svc.cluster.local:27017"
  dbinit:
    enabled: true
    image: "cognigy.azurecr.io/mongodb:<tag>"
  # Optional — reference an existing root credentials Secret directly.
  # When empty the chart auto-copies from mongodb.auth.lookup (requires cluster read-access to the mongodb namespace).
  # auth:
  #   existingSecret: "cognigy-mongodb-root-credentials"
```

#### MongoDB Atlas (scheme: mongodb+srv)

The db-init Job uses the `atlas` CLI (via the Atlas Admin API) instead of `mongosh`.
No root user credentials are needed — only Atlas API keys.

Hook execution order:
1. **weight -3** `service-llm-gateway-mongodb-atlas-creds` — creates the Atlas API key Secret (skipped when `auth.atlas.existingSecret` is set)
2. **weight -2** `service-llm-gateway-mongodb` — generates a random 64-char service user password (preserved across upgrades)
3. **weight -1** db-init Job — calls `atlas dbusers create/update` to create/update the `service-llm-gateway` user with `readWrite@service-llm-gateway`

> **Note:** The connection string uses `mongodb+srv://`, which relies on Atlas's SRV TXT
> record to set `authSource=admin` automatically. Explicit `authSource` in the URI is
> not needed (and matches the pattern used by the parent `cognigy-ai-app` chart in
> production).

Production (pre-existing SealedSecret for Atlas credentials):
```yaml
database:
  type: mongodb
mongodb:
  scheme: "mongodb+srv"
  hosts: "cluster0.abc.mongodb.net"
  params: "?retryWrites=true&w=majority"
  dbinit:
    enabled: true
    image: "cognigy.azurecr.io/mongodb:<tag>"
  auth:
    atlas:
      existingSecret: "my-atlas-api-secret"   # keys: apikeypublic, apikeyprivate, projectid, clustername
```

Local dev (literal Atlas credentials — chart creates the Secret):
```yaml
mongodb:
  scheme: "mongodb+srv"
  hosts: "cluster0.abc.mongodb.net"
  params: "?retryWrites=true&w=majority"
  dbinit:
    enabled: true
    image: "cognigy.azurecr.io/mongodb:<tag>"
  auth:
    atlas:
      projectId: "abc123"
      clusterName: "cluster0"
      publicAPIKey: "mypublickey"
      privateAPIKey: "myprivatekey"
```

**Mode B — Connection string fallback (local dev / testing):**
Provide the URI directly; the chart creates the `service-llm-gateway-mongodb` Secret from it. `dbinit` is skipped.

```yaml
mongodb:
  connectionString: "mongodb://localhost:27017/service-llm-gateway?replicaSet=rs0&directConnection=true"
```

> **Local docker-compose dev:** Set `MONGODB_URI` directly as an environment variable. The Helm chart is not involved.

### Encryption Key & JWT Secret

Both are **auto-generated on first install** and preserved across upgrades (`helm.sh/resource-policy: keep`).
No configuration is required for a standard deployment.

Two override patterns are supported if you need to supply a specific value:

1. **`existingSecret`** — reference a pre-existing Secret (Flux/sealed-secrets environments).
   When set, the chart skips creating its own Secret and references this one directly:

```yaml
serviceLlmGateway:
  encryptionKey:
    existingSecret: "llm-gateway-sealed-secrets"
  jwtSecret:
    existingSecret: "llm-gateway-sealed-secrets"
```

2. **`value`** — provide the literal value (local dev / chart testing). The chart creates a Secret from it:

```yaml
serviceLlmGateway:
  encryptionKey:
    value: "0000000000000000000000000000000000000000000000000000000000000000"
  jwtSecret:
    value: "change-me-in-local-dev-minimum-32-characters"
```

> `ENCRYPTION_KEY` must be exactly 64 hex characters (32 bytes). Generate with `openssl rand -hex 32`.
> **Warning:** changing the encryption key after data has been written will make existing provider credentials unreadable.

### Service Authentication (`callerSecrets`)

llm-gateway uses a two-step auth flow for service-to-service calls:

1. The calling service calls `POST /api/v1/auth/token` with its `serviceId` and pre-shared secret
2. llm-gateway returns a short-lived JWT
3. The calling service presents the JWT as `Authorization: Bearer <token>` on every request

The gateway owns caller secrets by default. Each entry is a dict with `serviceId`
plus optional pre-shared overrides. The chart auto-creates one Kubernetes Secret per
entry, named `llm-gateway-caller-<serviceId>`, with a random 48-character password
preserved across upgrades (`helm.sh/resource-policy: keep`). The deployment receives a
`SERVICE_SECRET_<NORMALIZED_ID>` env var sourced from that Secret (non-alphanumeric
characters replaced with `_`, uppercased).

```yaml
serviceLlmGateway:
  callerSecrets:
    - serviceId: service-api    # → Secret "llm-gateway-caller-service-api", env SERVICE_SECRET_SERVICE_API
    - serviceId: service-ai
```

**Pre-shared secret (escape hatch).** When a caller's password is managed elsewhere
— e.g. supplied by an external party via sealed-secret — set `existingSecret` on the
entry to reference that Secret instead of having the chart create one:

```yaml
serviceLlmGateway:
  callerSecrets:
    - serviceId: service-api
    - serviceId: cxone
      existingSecret: cxone-llm-gateway-caller
      existingSecretKey: secret    # default: "secret"
```

Consuming products (e.g. cognigy-ai-app) read the same Secret by name from the same
namespace — no parallel generation in the product chart. To inspect a generated secret:

```bash
kubectl get secret llm-gateway-caller-service-api \
  -o jsonpath='{.data.secret}' | base64 -d
```

To list all caller secrets in the namespace:

```bash
kubectl get secret -l app.kubernetes.io/component=llm-gateway-caller
```

To rotate, delete the Secret and re-run `helm upgrade` (the chart regenerates a new
random password). Calling services automatically re-exchange for a new JWT on the next
call; existing JWTs remain valid until expiry.

### RabbitMQ Connection String

The connection string is mounted as a file at `/var/run/secrets/rabbitmqConnectionString` inside the container. Two patterns are supported (first match wins):

1. **`existingSecret`** — reference a pre-existing Kubernetes Secret (preferred in Flux / sealed-secrets environments):

```yaml
serviceLlmGateway:
  rabbitmq:
    existingSecret: "service-llm-gateway-rabbitmq"
```

2. **`connectionString`** — provide the value directly; the chart creates a Secret automatically:

```yaml
serviceLlmGateway:
  rabbitmq:
    connectionString: "amqp://user:pass@rabbit.cognigy-ai.svc:5672"
```

> **Subchart mode:** `existingSecret` defaults to `"cognigy-rabbitmq"` — no action required when deploying into the same namespace as the parent chart.

**Standalone mode only (cross-namespace):** To extract the connection string from the existing `cognigy-rabbitmq` secret in the `cognigy-ai` namespace and create a matching Secret in your release namespace (replacing the host with the in-cluster service DNS):

```bash
kubectl create secret generic service-llm-gateway-rabbitmq \
  --namespace <release-namespace> \
  --from-literal=connection-string="$(
    kubectl get secret cognigy-rabbitmq \
      --namespace cognigy-ai \
      --output jsonpath='{.data.connection-string}' \
      | base64 --decode \
      | sed 's|@[^:/]*|@rabbitmq.cognigy-ai.svc.cluster.local|'
  )"
```

Then reference it in your values:

```yaml
serviceLlmGateway:
  rabbitmq:
    existingSecret: "service-llm-gateway-rabbitmq"
```

### Pull Secret Priority

The chart resolves `imagePullSecrets` in this order (first match wins, renders nothing if none configured):

1. `imageCredentials.existingSecret` — explicit existing secret name (default: `cognigy-registry-token`)
2. `imageCredentials.username` + `imageCredentials.password` — chart creates a `<fullname>-registry` Secret. Only triggered when `existingSecret` is empty.

### Environment-Specific Values

- **values.yaml** — Base configuration with safe defaults
- **values-local.yaml** — Local development overrides (gitignored)

## Upgrading

```bash
helm upgrade llm-gateway ./charts/llm-gateway-app \
  -f charts/llm-gateway-app/values.yaml \
  -f charts/llm-gateway-app/values-local.yaml \
  --namespace <release-namespace>
```

## Uninstalling

```bash
helm uninstall llm-gateway --namespace <release-namespace>
```

## Testing

### Dry Run

```bash
# Test template rendering without installing
helm template llm-gateway ./charts/llm-gateway-app \
  -f charts/llm-gateway-app/values.yaml \
  -f charts/llm-gateway-app/values-local.yaml \
  --namespace <release-namespace>

# Validate with dry-run
helm install llm-gateway ./charts/llm-gateway-app \
  -f charts/llm-gateway-app/values.yaml \
  -f charts/llm-gateway-app/values-local.yaml \
  --namespace <release-namespace> \
  --dry-run --debug
```

### Validate Chart

```bash
# Lint the chart
helm lint ./charts/llm-gateway-app

# Check for issues
helm template llm-gateway ./charts/llm-gateway-app \
  -f charts/llm-gateway-app/values-local.yaml \
  --validate
```

## Local development troubleshooting

> **Namespace note:** The namespace used depends on your deployment mode. In subchart mode (default), use `-n cognigy-ai`. In standalone mode, use the namespace you deployed into. The examples below use `-n <release-namespace>` as a placeholder — replace it with the actual namespace.

### Image Pull Errors

```bash
# Check image pull secret
kubectl get secret -n <release-namespace> service-llm-gateway-registry -o yaml

# Verify credentials in values-local.yaml and upgrade
helm upgrade llm-gateway ./charts/llm-gateway-app \
  -f charts/llm-gateway-app/values-local.yaml
```

### Pod Not Starting

```bash
# Describe the pod
kubectl describe pod -n <release-namespace> -l app.kubernetes.io/name=llm-gateway-app

# Check events
kubectl get events -n <release-namespace> --sort-by='.lastTimestamp'
```

### Ingress Not Working

```bash
# Check ingress
kubectl get ingress -n <release-namespace> -o yaml

# Verify Traefik is routing correctly
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
```

### RabbitMQ Connection Issues

```bash
# Verify the secret exists and contains the expected key
kubectl get secret service-llm-gateway-rabbitmq -n <release-namespace> -o jsonpath='{.data}' | jq 'keys'

# Confirm the mounted file is present inside a running pod
kubectl exec -n <release-namespace> \
  $(kubectl get pod -n <release-namespace> -l app.kubernetes.io/name=llm-gateway-app -o name | head -1) \
  -- cat /var/run/secrets/rabbitmqConnectionString

# Re-extract from the cognigy-ai namespace if the secret is missing or stale
kubectl create secret generic service-llm-gateway-rabbitmq \
  --namespace <release-namespace> \
  --from-literal=connection-string="$(
    kubectl get secret cognigy-rabbitmq \
      --namespace cognigy-ai \
      --output jsonpath='{.data.connection-string}' \
      | base64 --decode \
      | sed 's|@[^:/]*|@rabbitmq.cognigy-ai.svc.cluster.local|'
  )" \
  --save-config --dry-run=client -o yaml | kubectl apply -f -
```

### RabbitMQ Queue Declaration Conflict (`406 PRECONDITION-FAILED`)

If the service logs show:

```
Channel closed by server: 406 (PRECONDITION-FAILED) with message
"PRECONDITION_FAILED - inequivalent arg 'x-message-ttl' for queue 'llm-gateway-rpc-queue'"
```

This means the queue already exists in the broker with different arguments (e.g. a `x-message-ttl` set by a previous deployment). Delete the queue so it is recreated cleanly on the next connection:

```bash
kubectl port-forward -n cognigy-ai svc/rabbitmq 15672:15672
```

You can then navigate to http://localhost:15672, login with your local cluster's rabbitmq user and password, then search for the service-llm-gateway queue and delete it.

After deletion the service will redeclare the queue on reconnect without the stale arguments.

## Support

For issues or questions:
1. Check the [troubleshooting section](#troubleshooting)
2. Review Helm logs: `helm history llm-gateway -n <release-namespace>`
3. Contact the Cognigy SRE Team
