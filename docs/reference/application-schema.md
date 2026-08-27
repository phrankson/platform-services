# Application object reference

Full field reference for the Argo `Application` objects defined in this
repo, split across `environments/base/istio-helm.yaml` (shared) and each
environment's own patch file (`istio.yaml`).

## Shared fields — `environments/base/istio-helm.yaml`

Three `Application` objects, one per Istio component:

| Component | `metadata.name` | `spec.source.chart` | `sync-wave` | `spec.destination.namespace` |
|---|---|---|---|---|
| Wiring / CRDs | `istio-base` | `base` | `"0"` | `istio-system` |
| Control plane | `istiod` | `istiod` | `"1"` | `istio-system` |
| Ingress gateway | `istio-ingress` | `gateway` | `"2"` | `istio-system` |

All three share:

| Field | Value | Effect |
|---|---|---|
| `metadata.namespace` | `argocd` | Every Application lives in `argocd`, regardless of where it deploys to. |
| `spec.source.repoURL` | `https://istio-release.storage.googleapis.com/charts` | The Istio Helm chart repo. |
| `spec.source.targetRevision` | *(unset here)* | Deliberately omitted — set per environment instead. See [why](../explanation/architecture-and-design-choices.md#why-the-chart-version-lives-in-the-overlay-not-in-base). |
| `spec.destination.server` | `https://kubernetes.default.svc` | Same cluster Argo CD runs on. |
| `spec.syncPolicy.automated.prune` | `true` | Remove resources no longer in the chart's output. |
| `spec.syncPolicy.automated.selfHeal` | `true` | Revert manual changes to match the chart automatically. |
| `spec.syncPolicy.syncOptions` | `[CreateNamespace=true]` | Create `istio-system` if it doesn't exist. |
| `spec.syncPolicy.managedNamespaceMetadata.labels` | `{istio.io/rev: default}` | Labels `istio-system` as part of creating it — required for istiod's mutating webhook to rewrite the gateway's placeholder `auto` image. See [Troubleshooting](../how-to/troubleshooting.md#a-newly-installed-gateway-pod-sits-in-imagepullbackoff-pulling-auto). |
| `spec.syncPolicy.retry.limit` | `3` | Retry attempts on sync failure. |
| `spec.syncPolicy.retry.backoff` | `10s` initial, `3m` max | Exponential backoff between retries. |
| `metadata.annotations["argocd.argoproj.io/sync-wave"]` | `"0"` / `"1"` / `"2"` | Install order — Argo CD applies lower waves first and waits for health before advancing. See [Why sync-waves](../explanation/architecture-and-design-choices.md#why-installation-order-is-enforced-with-sync-waves). |

## Per-environment overlay — `environments/<env>/istio.yaml`

Each environment's overlay patches only `spec.source.targetRevision` on all
three Application objects:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-base
  namespace: argocd
spec:
  source:
    targetRevision: 1.30.3
```

## Current values in use

| Environment | `istio.yaml` overlay | `targetRevision` | `env` label applied |
|---|---|---|---|
| `platform-sandbox` | present, patches all 3 Applications | `1.30.3` | yes (`env: platform-sandbox`) |
| `app-dev` | `patches: []` — no overlay file yet | unset | no |
| `app-prod` | `patches: []` — no overlay file yet | unset | no |

An `Application` with no `targetRevision` set still renders as valid YAML
(`kubectl kustomize` doesn't resolve Helm charts, so it can't catch a
missing version) — but it hasn't actually been synced against a real
cluster in this project, so what Argo CD would do with it is untested.
Don't rely on `app-dev` or `app-prod` behaving correctly until they have
their own populated overlay — see
[Bump the Istio version](../how-to/bump-the-istio-version.md).
