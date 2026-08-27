# Service Mesh Deployment

Part of the [platform-services learning companion](README.md). Read the
[index](README.md) first for the vendor analogy this builds on.

---

## Three deliveries, in a specific order

A shared intercom-and-security system for a whole house doesn't get
installed in one delivery. The wiring goes in first. Then the central
control panel that everything else reports to. Then the front-door
intercom panel that lets visitors talk into the house at all. Install them
out of order and the later pieces have nothing to plug into yet.

[`environments/base/istio-helm.yaml`](../environments/base/istio-helm.yaml)
installs Istio, the service mesh used here, as exactly three pieces, in
exactly that order:

- **istio-base** — the wiring. Custom resource definitions and core
  cluster-level pieces nothing else can function without.
- **istiod** — the control panel. The mesh's control plane, the thing
  every other piece reports to and takes instructions from.
- **istio-ingress** — the front-door intercom. The gateway that lets
  traffic from outside the mesh in through one controlled entrance.

Each is its own Argo Application, and the order is enforced with a
sync-wave number:

```yaml
metadata:
  name: istio-base
  annotations:
    argocd.argoproj.io/sync-wave: "0"
---
metadata:
  name: istiod
  annotations:
    argocd.argoproj.io/sync-wave: "1"
---
metadata:
  name: istio-ingress
  annotations:
    argocd.argoproj.io/sync-wave: "2"
```

Argo CD applies wave 0 first, waits for it to be healthy, then moves to
wave 1, then wave 2. Installing the front-door intercom before the control
panel exists would leave it with nothing to report to.

Notice what's missing from that file: a version number for any of the
three. That's on purpose, and it's the same base-plus-overlay idea covered
in `platform-core`'s companion, applied here to a real install instead of
infrastructure. `environments/platform-sandbox/istio.yaml` is the one file
that actually pins a version, patched in per house:

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

Bumping the mesh's version means editing this file, watching sandbox run
on it for a while, then copying the same edit into `app-dev`'s file, then
`app-prod`'s — never touching `base/`.

## Running, but not actually wired in

<details>
<summary><strong>Predict before reading on:</strong> after the first real install, <code>istio-ingress</code>'s pod sat in <code>ImagePullBackOff</code> — stuck trying to pull an image literally named <code>auto</code>. That's not a typo in this project's config; <code>auto</code> is the chart's own placeholder value, meant to be swapped for a real image automatically. What has to happen for that swap to actually occur, and what happens if it doesn't?</summary>

Istio's gateway chart ships with `image: auto` on purpose. The idea is
that istiod's own control panel intercepts the request to create that pod
and rewrites the placeholder into a real image before the pod ever starts
— nobody has to know the exact image tag by hand.

That rewrite is done by a Kubernetes feature called an admission webhook —
code that gets a chance to inspect or modify an object the moment it's
created, before it's stored. This project's first real install found a
webhook rule that looked like the obvious explanation: it only fires on
namespaces carrying a specific label the project's `istio-system`
namespace didn't have. A fix went out adding that label.

Here's the honest part worth sitting with: after digging further, that
label turned out not to be the actual explanation. A different webhook
rule in the same chart matched regardless of the label, and the pod
eventually came up fine on a simple delete-and-recreate, with the label
never actually applied. The real cause looks like istiod needing a short
window after starting up before it can correctly perform this exact
rewrite — a timing issue, not a missing setting. The label fix stayed in
place because it's harmless and a reasonable practice anyway, but the
first explanation for *why* it worked was wrong.

This is worth knowing as a general shape of investigation, not just a fact
about Istio: **the first plausible-sounding explanation for an incident is
not automatically the correct one, and a fix that happens to make the
symptom go away is not proof the reasoning behind it was right.** A good
investigation keeps checking evidence against the story even after
something starts working again, and says so plainly when the evidence
stops supporting the original explanation.
</details>

**Try it yourself** — the real, currently-running mesh:

```console
$ kubectl get pods -n istio-system
NAME                             READY   STATUS    RESTARTS   AGE
istio-ingress-567bc595f7-jqz8f   1/1     Running   0          11h
istiod-7ff49bfb66-xg5hx          1/1     Running   0          11h

$ kubectl get applications -n argocd
NAME            SYNC STATUS   HEALTH STATUS
istio-base      OutOfSync     Healthy
istiod          OutOfSync     Healthy
istio-ingress   Synced        Progressing
```

Continue to [**Policy as Code**](policy-as-code.md) for the rules that
check what gets deployed here, automatically, before anyone has to notice
a problem by hand.
