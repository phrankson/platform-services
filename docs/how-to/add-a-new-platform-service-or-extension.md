# Add a new platform service or extension

Use this to add a new Helm-deployed extension (something that changes
cluster behavior, like Istio) or platform service (something with an
address teams call directly, like a database or message queue) to this
repo. See
[Extensions vs. services](../explanation/architecture-and-design-choices.md#extensions-vs-services-why-both-live-in-one-repo)
if you're not sure which category what you're adding falls into — it
doesn't change these steps, but it changes how you should expect it to
fail later.

## Steps

1. Add a new base file under `environments/base/`, following the shape of
   `istio-helm.yaml`: one Argo `Application` object per Helm chart (or CRD
   set) the new service needs, each with `spec.source.repoURL` and
   `spec.source.chart` set, and **no** `spec.source.targetRevision` — the
   version goes in each environment's overlay, not here.

   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: <service-name>
     namespace: argocd
   spec:
     project: default
     source:
       repoURL: <helm repo URL>
       chart: <chart name>
     destination:
       server: https://kubernetes.default.svc
       namespace: <target namespace>
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
       syncOptions:
         - CreateNamespace=true
       retry:
         limit: 3
         backoff:
           duration: 10s
           maxDuration: 3m
   ```

2. If this service has more than one Application and installation order
   matters (as it does for Istio's three pieces), add
   `argocd.argoproj.io/sync-wave` annotations, lowest number first. If order
   doesn't matter, omit the annotation entirely rather than guessing a
   number.

3. Register the new file in `environments/base/kustomization.yaml`:

   ```yaml
   resources:
     - istio-helm.yaml
     - <new-service>-helm.yaml
   ```

4. Add a version-pin overlay for each environment that should run this
   service. For `platform-sandbox`, following `istio.yaml`'s shape:

   ```yaml
   # environments/platform-sandbox/<new-service>.yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: <service-name>
     namespace: argocd
   spec:
     source:
       targetRevision: <chart version>
   ```

   Then add it to that environment's patch list:

   ```yaml
   # environments/platform-sandbox/kustomization.yaml
   patches:
     - path: istio.yaml
     - path: <new-service>.yaml
   ```

5. Render and check before opening a PR:

   ```console
   $ kubectl kustomize environments/platform-sandbox | grep -A2 "name: <service-name>"
   ```

6. If you're adding something that should be checked by policy — most
   platform-owned workloads should be — see
   [Write and test a policy rule](write-and-test-a-policy-rule.md), and
   note the coverage caveat in
   [the policy-as-code explanation](../explanation/architecture-and-design-choices.md#why-a-passing-policy-check-here-doesnt-mean-what-it-looks-like-it-means)
   before assuming the existing rules will catch anything about your new
   service automatically — right now they only ever see `Application`
   wrapper objects in CI, not the real Deployments the charts render.

## Only `platform-sandbox` has real overlays today

`app-dev` and `app-prod`'s `kustomization.yaml` files currently have
`patches: []` — nothing pinned yet, for any service, Istio included.
Populating them for a new service works exactly like step 4 above, just
under a different environment folder.
