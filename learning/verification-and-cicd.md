# Verification and CI/CD

Part of the [platform-services learning companion](README.md). Read
[Policy as Code](policy-as-code.md) first — this covers what happens after
a change passes those checks and actually reaches `main`.

---

## Forcing the check instead of waiting for it

Argo CD checks this repo for changes on its own schedule, every few
minutes by default. That's fine most of the time, and genuinely annoying
during CI, where waiting several minutes just to find out whether a change
worked turns a two-minute pipeline into a ten-minute one for no real
reason.

[`scripts/argocd_reconcile.sh`](../scripts/argocd_reconcile.sh) exists to
skip that wait. Site Reliability Engineering has a name for the kind of
work this script replaces: toil — manual, repetitive work that doesn't get
any easier no matter how many times you do it by hand. Watching a
dashboard until a sync finishes, then manually curling a URL to see if the
result actually works, is exactly that kind of task. Automating it doesn't
just save time once; it saves the same small chunk of tedious, error-prone
attention every single time a change ships.

```bash
argocd app sync platform-services --core
argocd app sync istio-base istiod istio-ingress --core
argocd app wait platform-services istio-base istiod istio-ingress \
  --core --health --timeout 120
```

`argocd app wait` blocks until everything named is healthy or the timeout
is hit, and fails loudly if it isn't — a deterministic yes-or-no answer, not
something a person has to interpret by eye.

## A test that said yes when the real answer was no

The script's last job is a smoke test: push one real request through the
mesh's gateway and confirm it actually gets a response, not just that the
gateway's pod exists and is running.

<details>
<summary><strong>Predict before reading on:</strong> the very first version of this smoke test reported success — the job showed "Completed" — even though the gateway had no working route configured yet and every request to it was actually failing. How does a test end up reporting success on a real failure?</summary>

The test's script piped curl's output into `head`:

```bash
curl -sS -H "Host: $H" --max-time 10 http://... | head -n 3
```

Under `set -e`, a pipeline's exit status is the exit status of its *last*
command, not any command earlier in the pipe. `head` succeeds even when it
receives no input at all — it just prints nothing and exits cleanly. So no
matter how badly curl failed, `head`'s success was the only exit code
anyone was watching. The job reported "Completed" while quietly proving
nothing at all.

The fix removes the pipe entirely, so there's nothing left to hide behind:

```bash
curl -sS -H "Host: $H" --max-time 10 http://... -o /tmp/resp.txt
head -n 3 /tmp/resp.txt
```

Now curl's own exit code is the one `set -e` actually sees. This is worth
remembering as a general habit, not just a fix for this one script: a test
is only as trustworthy as the exit code it actually reports on, and a pipe
can quietly swap which command that exit code belongs to.
</details>

**Try it yourself** — the corrected test, run against the real gateway,
correctly reporting a real failure (nothing has configured actual routing
through the mesh yet, so this failure is expected):

```console
$ kubectl -n istio-system apply -f smoke/http-gateway.yaml
$ kubectl -n istio-system wait --for=condition=complete job/smoke-gateway --timeout=30s
error: timed out waiting for the condition on jobs/smoke-gateway
$ kubectl logs -n istio-system job/smoke-gateway
curl: (7) Failed to connect to istio-ingress.istio-system.svc.cluster.local port 80 after 10 ms: Could not connect to server
```

## Two workflows, same split as everywhere else in this project

[`.circleci/config.yml`](../.circleci/config.yml) draws the same
push-vs-merge line covered in `platform-team-administration`'s companion,
adjusted for a repo with no container image and no infrastructure to
provision: pre-merge checks that every environment's configuration still
builds and passes policy, using no real cluster at all. Post-merge forces
the reconcile-and-smoke-test script above, against the real
`platform-sandbox` cluster, on the same self-hosted runner
`platform-core`'s pipeline uses — required because these Kind clusters
only exist on one physical machine, not in CircleCI's own infrastructure.

Only `platform-sandbox` is wired into the post-merge job today.
`app-dev` and `app-prod` don't have their own `istio.yaml` version pin
yet, so there's nothing real to reconcile there — the same honest gap
`service-mesh.md` already covers.

---

This is the last file in this project's four learning companions. Together
they trace one continuous chain: a permit gets issued, a house gets built
on it, a hub gets paired to an account, and that account finally points at
something real running inside the house it started from.
