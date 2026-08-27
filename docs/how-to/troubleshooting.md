# Troubleshooting

Real problems this project has hit in this repo, and how to check them.

## A newly installed gateway pod sits in `ImagePullBackOff` pulling `auto`

**Symptom:** `kubectl get pods -n istio-system` shows `istio-ingress-...`
stuck in `ImagePullBackOff`, and `kubectl describe pod` shows it trying to
pull an image literally named `auto`.

**Cause:** the Istio gateway chart ships with `image: auto` as a
placeholder on purpose — istiod's own mutating admission webhook is
supposed to intercept pod creation and rewrite that placeholder to a real
image before the pod starts. That rewrite only fires for namespaces
carrying the label `istio.io/rev: default`, set in this repo via
`syncPolicy.automated.managedNamespaceMetadata` on each of the three Istio
`Application` objects (`environments/base/istio-helm.yaml`).

**Check first:** confirm the namespace actually has the label:

```console
$ kubectl get namespace istio-system --show-labels
```

If `istio.io/rev=default` is missing, the namespace was likely created
outside this repo's `Application` objects (for example, manually, before
`CreateNamespace=true` had a chance to run) — deleting and letting Argo CD
recreate it should apply the label correctly.

**If the label is present and the pod is still stuck:** this project hit
that exact situation once, and the label was not the actual fix — see
[why the auto-image incident's first explanation was wrong](../explanation/architecture-and-design-choices.md#postmortem-the-auto-image-incident)
before spending time re-checking the label further. The more likely cause
is a timing race: istiod needs a short window after starting up before it
can correctly perform this rewrite. Deleting and recreating the stuck pod
after confirming `istiod` itself is `Running` usually resolves it.

## Applications show `OutOfSync` while still `Healthy`

**Symptom:** `kubectl get applications -n argocd` shows `istio-base` and
`istiod` as `OutOfSync` / `Healthy`, while `istio-ingress` shows `Synced` /
whatever its current health is.

**Cause:** this is expected in this project's current state, not a fault to
fix. `OutOfSync` means the live object's fields don't byte-for-byte match
the last-applied manifest — commonly because a controller (a webhook, an
operator, Kubernetes itself defaulting a field) mutates the object after
Argo CD applies it. `Healthy` means the resource is actually working
correctly regardless. The two statuses answer different questions and
either can be true independently of the other.

**When to actually worry:** if `HEALTH STATUS` itself goes to `Degraded` or
`Missing`, not just `OutOfSync`. Chasing `OutOfSync` to zero on a resource
a webhook actively mutates is usually a losing, unnecessary battle.

## The gateway smoke test fails to connect

**Symptom:**

```console
$ kubectl -n istio-system logs job/smoke-gateway
curl: (7) Failed to connect to istio-ingress.istio-system.svc.cluster.local port 80 after 13 ms: Could not connect to server
```

**Cause:** as of this writing, this is expected — no `VirtualService` or
`Gateway` routing has been configured through the mesh yet, so there's
nothing listening for the smoke test's request to reach. This isn't a bug
in the smoke test itself; it's an honest signal that routing hasn't been
wired up.

**If you believe routing has been configured and this still fails:**
confirm `istio-ingress`'s pod is actually `Running` first (see the
`ImagePullBackOff` entry above) — a smoke test failure with no gateway pod
running at all looks identical to one with a pod running but no route
configured.

## A policy check passes, but you expected it to catch something

**Symptom:** `conftest test -p policy <file>` reports all tests passing,
even though you believe the manifest being checked has a real problem a
rule should have caught.

**Cause:** check what `kind` is actually in the file you tested. Both
existing rules guard on `input.kind == "Deployment"` — if you ran `conftest`
against this repo's own `kubectl kustomize` output (which only ever
produces Argo `Application` objects), neither rule has anything to match
against, and "passed" means "nothing here for the rule to check," not
"checked and found compliant." See
[why a passing policy check here doesn't mean what it looks like it means](../explanation/architecture-and-design-choices.md#why-a-passing-policy-check-here-doesnt-mean-what-it-looks-like-it-means)
for the full explanation. To actually check a real Deployment, pull it
from the live cluster first (`kubectl get deploy ... -o yaml`) and run
`conftest` against that output instead.

## `argocd app sync --core` fails with an authentication or context error

**Cause:** `--core` mode reads the target cluster and namespace from your
current `kubectl` context, not from a login session — there is no
`argocd login` step anywhere in this repo's pipeline or scripts. If this
fails, check `kubectl config current-context` and
`kubectl config view --minify | grep namespace` before assuming a
credentials problem; the actual cause is almost always pointing at the
wrong cluster or the wrong namespace, not a missing login.
