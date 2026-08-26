#!/bin/bash
set -eux

# Argo CD's --core mode talks directly to the cluster via the current
# kubeconfig context, skipping the argocd-server login flow entirely --
# the right mode for a CI script that already has cluster access.
#
# Force an immediate sync instead of waiting on Argo's normal
# reconciliation interval, same reasoning as the book's
# `flux reconcile --with-source`: skip the wait, accelerate the CI
# feedback loop. Sync platform-services first (pulls the latest Istio
# Application definitions from the platform-services repo), then each
# Istio component -- their own automated sync policy would eventually
# pick these up on its own, but "eventually" is exactly the delay we're
# trying to avoid here.
argocd app sync platform-services --core
argocd app sync istio-base istiod istio-ingress --core

# argocd app wait blocks until Healthy + Synced (or the timeout), exiting
# non-zero on failure. This replaces the book's hand-rolled polling loop
# entirely -- Argo's CLI already reads the same kind of structured status
# condition the book calls out (not a human-readable table), so there's
# nothing left to hand-roll.
argocd app wait platform-services istio-base istiod istio-ingress \
  --core --health --timeout 120

# Gateway smoke test: deploy, wait for completion, print logs on
# failure, then clean up either way.
kubectl -n istio-system apply -f smoke/http-gateway.yaml
kubectl -n istio-system wait --for=condition=complete \
  job/smoke-gateway --timeout=120s || \
  (kubectl -n istio-system logs job/smoke-gateway; exit 1)
kubectl -n istio-system delete -f smoke/http-gateway.yaml
