# Policy rules reference

Full reference for the Rego rules in `policy/`, run via `conftest test -p
policy <file>`. Every `.rego` file uses `package main` and
`import rego.v1`, and all files are evaluated together against one input —
any `deny` rule matching in any file rejects the input.

## `deny-latest-tag.rego`

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

| Condition | Rejects when |
|---|---|
| `input.kind == "Deployment"` | Only evaluates `Deployment` objects. Never matches an Argo `Application`, a `StatefulSet`, a `Job`, or anything else. |
| `endswith(... image, ":latest")` | Any container in the Deployment's pod template uses an image tag ending in `:latest`. |

**Message format:** `Deployment <name> uses :latest tag in container <container-name>`

## `deny-unauthorized-namespace.rego`

```rego
allowed_namespaces := {"istio-system", "platform-services", "argocd"}

deny contains msg if {
	input.kind == "Deployment"
	not allowed_namespaces[input.metadata.namespace]
	msg := sprintf(
		"Deployment %s targets unauthorized namespace: %s",
		[input.metadata.name, input.metadata.namespace],
	)
}
```

| Condition | Rejects when |
|---|---|
| `input.kind == "Deployment"` | Same scope restriction as above. |
| `not allowed_namespaces[input.metadata.namespace]` | `metadata.namespace` isn't one of the three allowed values. |

**Allowed namespaces:** `istio-system`, `platform-services`, `argocd`. Add a
new namespace here before onboarding a service that needs one, or the rule
will reject it.

**Message format:** `Deployment <name> targets unauthorized namespace: <namespace>`

## Where these rules are actually invoked

| Context | What gets checked | See |
|---|---|---|
| CI (`validate-manifests` job) | `kubectl kustomize` output for each environment — always `Application` objects, never `Deployment` | [CI/CD pipeline reference](cicd-pipeline.md) |
| Manual, against real resources | Whatever you pull with `kubectl get ... -o yaml` | [Write and test a policy rule](../how-to/write-and-test-a-policy-rule.md) |

Both rules guard on `input.kind == "Deployment"`, so CI's invocation never
gives them anything to actually check. See
[why a passing policy check here doesn't mean what it looks like it means](../explanation/architecture-and-design-choices.md#why-a-passing-policy-check-here-doesnt-mean-what-it-looks-like-it-means)
for the full explanation.
