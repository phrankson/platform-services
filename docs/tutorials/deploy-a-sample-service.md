# Deploy a sample service (Helm and Kustomize)

This tutorial walks through the two ways an Argo `Application` in this repo
can source a real workload: a local Helm chart, and plain Kustomize
manifests. Both deploy the identical service — [`traefik/whoami`](https://hub.docker.com/r/traefik/whoami),
a tiny container that echoes back whatever request it receives — so the
only variable is *how the manifests are sourced*, not what gets deployed.

## Prerequisites

- [Helm](https://helm.sh/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [conftest](https://www.conftest.dev/install/)
- `kubectl` access to `platform-sandbox`

## Step 1: Look at both sources side by side

```console
$ cat charts/whoami/Chart.yaml
$ cat manifests/whoami-kustomize/kustomization.yaml
```

`charts/whoami` is a real, minimal Helm chart — `Chart.yaml`, `values.yaml`,
and templates that use `{{ .Release.Name }}` and `.Values`.
`manifests/whoami-kustomize` is plain YAML — no templating, no values file,
just a `Deployment` and a `Service` listed in a `kustomization.yaml`.

## Step 2: Render both locally, without touching a cluster

```console
$ helm template whoami-helm charts/whoami
$ kubectl kustomize manifests/whoami-kustomize
```

Both produce a `Deployment` and a `Service`. The Helm version's object
names come from the release name you pass on the command line
(`whoami-helm`); the Kustomize version's names are hardcoded directly in
the YAML (`whoami-kustomize`) since there's no templating layer to
parameterize them.

## Step 3: Compare how each is wired into Argo CD

```console
$ cat environments/platform-sandbox/whoami-helm.yaml
$ cat environments/platform-sandbox/whoami-kustomize.yaml
```

Notice the one field that differs in `spec.source` beyond the path:
`whoami-helm.yaml` has a `helm.releaseName` field (there's no separate name
for Argo to use otherwise, since a chart's object names come from the
release name); `whoami-kustomize.yaml` doesn't need one, because a plain
Kustomize target's object names are just whatever's written in the YAML.
Everything else — `repoURL`, `targetRevision: main`, `destination`,
`syncPolicy` — is identical. See
[the Application schema reference](../reference/application-schema.md#three-ways-to-source-a-workload-all-in-this-one-repo)
for the full field-by-field comparison, including how both differ from how
Istio's `Application` objects source a chart from an *external* Helm repo
rather than from this repo itself.

## Step 4: Confirm both are running for real

```console
$ kubectl get applications whoami-helm whoami-kustomize -n argocd
NAME               SYNC STATUS   HEALTH STATUS
whoami-helm        Synced        Healthy
whoami-kustomize   Synced        Healthy

$ kubectl get pods,svc -n platform-services
NAME                                    READY   STATUS    RESTARTS   AGE
pod/whoami-helm-569fd9f768-4v87s        1/1     Running   0          2m
pod/whoami-kustomize-678bd6b79-t98bp    1/1     Running   0          2m

NAME                        TYPE        CLUSTER-IP       PORT(S)
service/whoami-helm         ClusterIP   10.104.1.189     80/TCP
service/whoami-kustomize    ClusterIP   10.109.253.80    80/TCP
```

## Step 5: Talk to both, and see they're genuinely different pods

```console
$ kubectl -n platform-services port-forward svc/whoami-helm 18080:80 &
$ curl localhost:18080
Hostname: whoami-helm-569fd9f768-4v87s
...

$ kubectl -n platform-services port-forward svc/whoami-kustomize 18081:80 &
$ curl localhost:18081
Hostname: whoami-kustomize-678bd6b79-t98bp
...
```

Each response's `Hostname` line names the actual pod that answered —
proof these are two independently running services, not one service
reached two different ways.

## Step 6 (bonus): watch a policy rule catch something real for the first time

Every policy check documented elsewhere in this repo has technically
passed only because there was nothing for the rule to check —
[the explanation doc covers why](../explanation/architecture-and-design-choices.md#why-a-passing-policy-check-here-doesnt-mean-what-it-looks-like-it-means)
in detail. `charts/whoami` is the first thing in this repo you can render
into an actual `Deployment` locally, which means it's also the first thing
you can use to see `deny-latest-tag.rego` fire against something real:

```console
$ helm template whoami-helm charts/whoami > /tmp/whoami.yaml
$ conftest test -p policy /tmp/whoami.yaml
4 tests, 4 passed, 0 warnings, 0 failures, 0 exceptions
```

Now deliberately break it — bump the pinned tag to `:latest` — and run the
same check again:

```console
$ sed 's/traefik\/whoami:v1.10.3/traefik\/whoami:latest/' /tmp/whoami.yaml > /tmp/whoami-bad.yaml
$ conftest test -p policy /tmp/whoami-bad.yaml
FAIL - /tmp/whoami-bad.yaml - main - Deployment whoami-helm uses :latest tag in container whoami

4 tests, 3 passed, 0 warnings, 1 failure, 0 exceptions
```

This is the same rule, the same command, that has been passing throughout
every other example in this repo's docs — the difference is that this time
there was an actual `Deployment` in the input for it to inspect.

## What you've done

You've deployed the same service two different ways, confirmed both are
genuinely running as separate pods, and used one of them to prove this
repo's policy rules work correctly once they're given something real to
check. From here, see
[Add a new platform service or extension](../how-to/add-a-new-platform-service-or-extension.md)
to build your own, using whichever of these two patterns fits what you're
adding.
