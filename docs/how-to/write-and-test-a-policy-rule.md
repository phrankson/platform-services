# Write and test a policy rule

Use this to add a new Rego rule that rejects a deployment automatically,
following the pattern of the two existing rules in `policy/`.

## Steps

1. Add a new `.rego` file under `policy/`. Every rule in this repo follows
   the same shape — `package main`, `import rego.v1`, and a `deny contains
   msg if { ... }` block:

   ```rego
   package main

   import rego.v1

   deny contains msg if {
       input.kind == "Deployment"
       # your condition here
       msg := sprintf("<message naming the specific object and problem>", [input.metadata.name])
   }
   ```

   All `.rego` files in `policy/` are evaluated together against a single
   input — any `deny` rule matching, in any file, is enough to reject it.

2. Test it locally against a deliberately bad manifest first, to confirm
   the rule actually fires:

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
   ```

   You should see a `FAIL` line naming your new rule's message. If nothing
   fails, check `input.kind` actually matches what you're testing against —
   a rule guarding on `input.kind == "Deployment"` never fires against
   anything else, including an Argo `Application` object.

3. Test it against a manifest that should pass, to confirm you haven't
   over-matched:

   ```console
   $ cat <<'EOF' > /tmp/good.yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: good-app
     namespace: istio-system
   spec:
     template:
       spec:
         containers:
           - name: web
             image: nginx:1.27.0
   EOF

   $ conftest test -p policy /tmp/good.yaml
   ```

4. Test it against something real, not just synthetic examples — pull an
   actual live Deployment and check it:

   ```console
   $ kubectl get deploy istiod istio-ingress -n istio-system -o yaml > /tmp/real.yaml
   $ conftest test -p policy /tmp/real.yaml
   ```

## What this rule will and won't catch once it's merged

The CI pipeline's `validate-manifests` job runs your rule against
`kubectl kustomize`'s output for each environment — which, in this repo, is
always Argo `Application` objects, never a real `Deployment`. If your rule
guards on `input.kind == "Deployment"` like both existing rules do, it will
never fire in CI, no matter what it would catch against a real cluster. It
will only ever fire when someone runs `conftest` by hand against real
rendered resources, the way steps 2–4 above do.

This is not a bug in your new rule — it's a real, structural gap in what
this pipeline currently checks. See
[why a passing policy check here doesn't mean what it looks like it means](../explanation/architecture-and-design-choices.md#why-a-passing-policy-check-here-doesnt-mean-what-it-looks-like-it-means)
for the full explanation before assuming CI will enforce your new rule
automatically.
