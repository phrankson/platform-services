package main

import rego.v1

# Deny :latest images: an unpinned tag means the exact running version is
# unknown, and can change unexpectedly on the next unrelated redeploy --
# the same "which chart version actually took effect" problem the
# environments/base + per-environment overlay split exists to prevent for
# our own Applications, applied here to what teams deploy through us.
deny contains msg if {
	input.kind == "Deployment"
	some i
	endswith(input.spec.template.spec.containers[i].image, ":latest")
	msg := sprintf(
		"Deployment %s uses :latest tag in container %s",
		[input.metadata.name, input.spec.template.spec.containers[i].name],
	)
}
