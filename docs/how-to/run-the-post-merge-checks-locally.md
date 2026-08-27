# Run the post-merge checks locally

Use this to run the same reconcile-and-smoke-test flow CI runs after a
merge to `main`, without waiting for a real PR — useful when you're
debugging a sync or smoke-test failure and want a fast local loop.

## Prerequisites

- `kubectl` and the `argocd` CLI installed locally
- `kind` access to the target cluster (this walkthrough uses
  `platform-sandbox`, whose Kind cluster is named `pe-sandbox`, not
  `platform-sandbox` — a real naming mismatch worth double-checking, since
  `kind get kubeconfig --name platform-sandbox` will fail with "no cluster
  found")

## Steps

1. Point `kubectl` and `argocd` at the target cluster:

   ```console
   $ kind get kubeconfig --name pe-sandbox > kubeconfig.yaml
   $ export KUBECONFIG="$(pwd)/kubeconfig.yaml"
   $ kubectl config set-context --current --namespace=argocd
   ```

   The namespace step matters: `argocd`'s `--core` mode (used throughout
   this script) reads the control-plane namespace from the kubeconfig
   context's current namespace, not from a flag.

2. Run the reconcile-and-smoke-test script directly:

   ```console
   $ SMOKE_HOST=platform-sandbox.local bash scripts/argocd_reconcile.sh
   ```

   This does exactly what the post-merge CI job does: force-syncs
   `platform-services` and all three Istio `Application` objects, waits up
   to 120 seconds for all of them to report `Healthy`, then runs the
   gateway smoke test job and fails loudly if it doesn't complete.

3. Clean up the kubeconfig file when you're done, so it doesn't get
   committed by accident:

   ```console
   $ rm -f kubeconfig.yaml
   ```

## Running just the smoke test

If reconciliation already succeeded and you only want to re-check
connectivity through the gateway:

```console
$ kubectl -n istio-system apply -f smoke/http-gateway.yaml
$ kubectl -n istio-system wait --for=condition=complete job/smoke-gateway --timeout=30s
$ kubectl -n istio-system logs job/smoke-gateway
$ kubectl -n istio-system delete -f smoke/http-gateway.yaml
```

As of this writing, this genuinely fails — there's no `VirtualService` or
routing configured through the mesh yet, so a connection failure here is
expected, not a sign anything is broken. See
[Troubleshooting](troubleshooting.md#the-gateway-smoke-test-fails-to-connect)
for the real, current failure output.
