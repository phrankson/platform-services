# Bump the Istio version

Use this to move the mesh to a new chart version, one environment at a time.

## Before you start

Check the [live chart index](https://istio-release.storage.googleapis.com/charts/index.yaml)
for the version you want, and confirm it's an actual stable release, not a
release candidate (`-rc.0` suffix) — this project has already hit that
mix-up once, at the version currently pinned (`1.30.3`, chosen specifically
over a `1.31.0-rc.0` that showed as "latest").

## Steps

1. Edit `environments/platform-sandbox/istio.yaml`, changing
   `spec.source.targetRevision` on all three `Application` patches
   (`istio-base`, `istiod`, `istio-ingress`) to the new version:

   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: istio-base
     namespace: argocd
   spec:
     source:
       targetRevision: <new-version>
   ```

   Do **not** edit `environments/base/istio-helm.yaml` — that file
   deliberately has no version field, so a version bump only ever touches
   one environment's overlay at a time. See
   [why the version isn't pinned in base](../explanation/architecture-and-design-choices.md#why-the-chart-version-lives-in-the-overlay-not-in-base).

2. Verify the change renders correctly before opening a PR:

   ```console
   $ kubectl kustomize environments/platform-sandbox | grep targetRevision
   ```

   All three `Application` objects should show the new version.

3. Open a PR, merge, then confirm the new version actually synced and came
   up healthy:

   ```console
   $ kubectl get applications -n argocd
   ```

   All three Istio `Application` objects should reach `Healthy` again. If
   one doesn't, see [Troubleshooting](troubleshooting.md) before proceeding
   — do not copy the change into the next environment while sandbox itself
   isn't healthy.

4. Once sandbox has run on the new version long enough to trust it, repeat
   step 1 for `environments/app-dev/istio.yaml`. If that file doesn't exist
   yet, see [Add a new platform service or extension](add-a-new-platform-service-or-extension.md)
   for how to add a version-pin overlay to an environment that doesn't have
   one — `app-dev` and `app-prod` currently have empty overlays
   (`patches: []`), so this file has to be created, not just edited.

5. Repeat for `app-prod` last.

## Why one environment at a time

This is the same progressive-rollout reasoning used everywhere else in this
project: a bad version shows up in `platform-sandbox` first, where nobody's
production traffic depends on it, before it ever reaches `app-prod`.
Bumping all three overlays in one PR defeats the entire point of having
separate overlays — you'd be betting production on an untested version
with no chance to catch a problem in between.
