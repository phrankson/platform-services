package main

import rego.v1

# Adapted from the book's illustrative app-dev/app-qa/app-prod example,
# which assumes one shared cluster with an environment-per-namespace
# layout. Ours is environment-per-cluster instead (platform-sandbox,
# app-dev, app-prod are separate Kind clusters, each with its own Argo
# CD) -- so the namespace boundary that actually matters here is "which
# platform-owned namespace is this landing in, within whichever cluster
# it's deployed to."
allowed_namespaces := {"istio-system", "platform-services", "argocd"}

# deny deployments to unauthorized namespaces
# (book's original used `no allowed_namespaces[...]` -- not valid Rego;
# negation is `not`.)
deny contains msg if {
	input.kind == "Deployment"
	not allowed_namespaces[input.metadata.namespace]
	msg := sprintf(
		"Deployment %s targets unauthorized namespace: %s",
		[input.metadata.name, input.metadata.namespace],
	)
}
