# platform-services

The actual Helm-deployed platform services and extensions — service mesh
first — that `platform-gitops`' `platform-services.yaml` Application
resources point at.

## Layout

```
environments/
  base/               # shared chart reference(s) + defaults for every environment
  platform-sandbox/   # overlay: patches on top of base
  app-dev/            # overlay: patches on top of base
  app-prod/           # overlay: patches on top of base
```

Same base + overlay pattern as `platform-gitops`, applied to real workloads
instead of GitOps pointer files — DRY shared config in `base/`, only the
per-environment differences (versions, resource limits, replica counts) live
in each overlay.

## Extensions vs. services

Both categories live in this one repo for simplicity:

- **Extensions** modify cluster behavior without serving requests
  themselves — CRDs, admission webhooks, policy engines.
- **Platform services** run persistent pods with an address teams actually
  call at runtime — databases, message queues, monitoring.

Currently empty, pending the first platform service (a service mesh).
