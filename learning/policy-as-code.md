# Policy as Code

Part of the [platform-services learning companion](README.md). Read
[Service Mesh Deployment](service-mesh.md) first — this covers how what
gets deployed here is actually checked.

---

## The same rule, one layer further down

`platform-team-administration`'s companion covers governance at scale —
rules enforced by the platform itself, uniformly, once no single person
can hold every rule in their head. Branch protection is that pattern
applied to how code gets merged. This repo applies the identical idea one
layer further down the pipeline: to what actually gets deployed, after the
merge already happened.

[`policy/deny-latest-tag.rego`](../policy/deny-latest-tag.rego) is one such
rule, written in Rego, the language a tool called Open Policy Agent (and
its command-line counterpart, `conftest`) uses to evaluate structured
files like Kubernetes manifests:

```rego
deny contains msg if {
	input.kind == "Deployment"
	some i
	endswith(input.spec.template.spec.containers[i].image, ":latest")
	msg := sprintf(
		"Deployment %s uses :latest tag in container %s",
		[input.metadata.name, input.spec.template.spec.containers[i].name],
	)
}
```

Read plainly: if the thing being checked is a Deployment, and any of its
containers uses an image tagged `:latest` instead of a specific version,
produce a message naming exactly which Deployment and which container.
`:latest` isn't a version — it's a moving target that can point to a
different actual image every time it's pulled, which means nobody can say
for certain what's actually running. This rule exists to catch that before
it ships, not after something breaks and nobody can reproduce it.

A second rule,
[`policy/deny-unauthorized-namespace.rego`](../policy/deny-unauthorized-namespace.rego),
checks something different: whether a Deployment is even allowed to land
in the namespace it's asking for. Both rules live in the same file
structure, and Rego lets them combine — a single manifest gets checked
against every `deny` rule across every file in the policy folder at once,
and any one of them failing is enough to reject it.

**Try it yourself** — this is a real policy check, run against a
deliberately broken manifest to see it actually catch something:

```console
$ cat <<'EOF' > /tmp/bad.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-app
  namespace: team-a-sandbox
spec:
  template:
    spec:
      containers:
        - name: web
          image: nginx:latest
EOF

$ conftest test -p policy /tmp/bad.yaml
FAIL - /tmp/bad.yaml - main - Deployment bad-app targets unauthorized namespace: team-a-sandbox
FAIL - /tmp/bad.yaml - main - Deployment bad-app uses :latest tag in container web

2 tests, 0 passed, 0 warnings, 2 failures, 0 exceptions
```

And against this repo's own real, live Istio deployment, which passes —
though for a reason worth understanding rather than taking at face value:

```console
$ kubectl get deploy istiod istio-ingress -n istio-system -o yaml > /tmp/real.yaml
$ conftest test -p policy /tmp/real.yaml
2 tests, 2 passed, 0 warnings, 0 failures, 0 exceptions
```

## A rule that's only checking one layer of the truth

It would be easy to read that second result as "this repo's policy checks
confirm everything here is compliant." That's not quite what it shows. The
`.circleci/config.yml` pipeline runs these checks against the *Kustomize*
output for each environment — the `Application` objects covered in the
last section — and an `Application` is never a Deployment. The rule that
guards against `:latest` tags never has anything to actually check at that
stage, because the object it's looking for doesn't show up until Argo CD
renders the Helm chart much later, inside the cluster itself.

This matters because a passing policy check can mean two very different
things: "we checked, and it's fine," or "we checked, and there was nothing
here for the rule to apply to." Confusing the second for the first is how
a governance program ends up with a false sense of coverage. Actually
verifying the deployed Deployments — the way the command above does by
hand — is closer to true coverage than the automated pipeline currently
provides.

Continue to [**Verification and CI/CD**](verification-and-cicd.md) for how
this repo forces an immediate check instead of waiting, and a test that
looked like it passed when it hadn't actually run at all.
