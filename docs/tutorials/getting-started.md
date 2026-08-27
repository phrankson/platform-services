# Getting started

This tutorial takes you from a fresh clone to seeing this repo's actual
effect on a real cluster: the Istio service mesh it installs, running and
verified two different ways. No changes to anything — just observation.

## Prerequisites

- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [conftest](https://www.conftest.dev/install/) — used to run this repo's
  policy checks locally
- `kubectl` access to a cluster this repo is actually deployed to (this
  project's `platform-sandbox` Kind cluster, context `kind-pe-sandbox`)

## Step 1: Clone the repository

```console
$ git clone https://github.com/phrankson/platform-services.git
$ cd platform-services
```

## Step 2: Render an environment's Application definitions

Every environment folder is a Kustomize overlay on top of `environments/base`.
Rendering `platform-sandbox` resolves the shared chart definitions plus that
environment's version pins into three Argo `Application` objects:

```console
$ kubectl kustomize environments/platform-sandbox
```

You should see three `Application` objects — `istio-base`, `istiod`, and
`istio-ingress` — each labeled `env: platform-sandbox`, each pinned to
`targetRevision: 1.30.3`, each with a different `argocd.argoproj.io/sync-wave`
annotation (`"0"`, `"1"`, `"2"`). That annotation is what makes Argo CD
install them in order instead of all at once — see
[Why sync-waves](../explanation/architecture-and-design-choices.md#why-installation-order-is-enforced-with-sync-waves)
for why that ordering matters.

Compare against `app-dev`:

```console
$ kubectl kustomize environments/app-dev
```

The same three `Application` objects render, but without a `targetRevision`
and without the `env` label — `app-dev`'s overlay has no patches applied yet
(`patches: []` in its `kustomization.yaml`). This is a real, current gap,
not a mistake in this tutorial: only `platform-sandbox` has a populated
version-pin overlay so far.

## Step 3: Confirm the mesh is actually running

If you have access to the `platform-sandbox` cluster:

```console
$ kubectl get pods -n istio-system
NAME                             READY   STATUS    RESTARTS   AGE
istio-ingress-567bc595f7-jqz8f   1/1     Running   0          21h
istiod-7ff49bfb66-xg5hx          1/1     Running   0          21h

$ kubectl get applications -n argocd
NAME                SYNC STATUS   HEALTH STATUS
istio-base          OutOfSync     Healthy
istio-ingress       Synced        Progressing
istiod              OutOfSync     Healthy
platform-gitops     Synced        Healthy
platform-services   Synced        Healthy
```

Notice `istio-base` and `istiod` show `OutOfSync` while still `Healthy` —
that's expected here, not a bug. See
[Troubleshooting](../how-to/troubleshooting.md#applications-show-outofsync-while-still-healthy)
before assuming something needs fixing.

## Step 4: Run this repo's policy checks against what you just rendered

```console
$ kubectl kustomize environments/platform-sandbox > /tmp/sandbox.yaml
$ conftest test -p policy /tmp/sandbox.yaml
2 tests, 2 passed, 0 warnings, 0 failures, 0 exceptions
```

This passes — but read
[the policy-as-code explanation](../explanation/architecture-and-design-choices.md#why-a-passing-policy-check-here-doesnt-mean-what-it-looks-like-it-means)
before trusting what that pass actually proves. It's more subtle than it
looks, and it's the single most important thing to understand before
relying on this repo's policy checks for anything real.

## What you've done

You've rendered this repo's real output, confirmed it matches what's
actually running on a live cluster, and run its policy checks against your
own rendered output. From here:

- To make the most common real change to this repo, see
  [Bump the Istio version](../how-to/bump-the-istio-version.md).
- To add something new — another extension or a platform service — see
  [Add a new platform service or extension](../how-to/add-a-new-platform-service-or-extension.md).
