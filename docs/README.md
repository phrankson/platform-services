# platform-services documentation

Task and reference documentation for engineers working with this repo
directly — bumping a chart version, adding a new service or extension,
writing a policy rule, or debugging why something isn't syncing or isn't
actually enforcing what it looks like it enforces. It assumes general
Kubernetes, Helm, and GitOps familiarity, not prior context on this
project.

If you want the reasoning taught from the ground up with analogies and
real incidents narrated as teaching material, see the
[learning companion](../learning/README.md) instead — different audience,
different purpose, same repo.

## Structure

- **[Tutorials](tutorials/)** — start here if this is your first time in
  the repo.
- **[How-to guides](how-to/)** — task-oriented recipes.
- **[Reference](reference/)** — exact schema of every Application
  definition, policy rule, and pipeline job in this repo.
- **[Explanation](explanation/)** — why this repo is shaped the way it is,
  including two incidents worth understanding in depth before you change
  anything here.

## Start here

1. [Getting started](tutorials/getting-started.md)
2. [Deploy a sample service](tutorials/deploy-a-sample-service.md) — a
   hands-on walkthrough deploying the same service two ways, Helm and
   plain Kustomize, side by side
3. [Bump the Istio version](how-to/bump-the-istio-version.md) — the most
   common change made to this repo
4. [Troubleshooting](how-to/troubleshooting.md) when a sync, a policy
   check, or the smoke test doesn't behave the way you expect
