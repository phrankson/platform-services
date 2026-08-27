# Learning: platform-services

A teaching companion for this repo, continuing from
[`platform-gitops`'s learning companion](../../platform-gitops/learning/README.md).
That repo's filing cabinet has exactly one instruction filed in it so far,
pointing here. This repo is where the chain of "also look here" files
finally stops, and something real gets installed.

1. **[Service Mesh Deployment](service-mesh.md)** — installing a shared
   communication system across every pod, and an incident where the
   pieces existed but never actually talked to each other.
2. **[Policy as Code](policy-as-code.md)** — rules that reject a bad
   deployment automatically, and how that rule gets proven correct.
3. **[Verification and CI/CD](verification-and-cicd.md)** — forcing an
   immediate check instead of waiting, and a test that lied about passing.

---

## What actually gets delivered

Picture the account platform-gitops represents as a work order sent to a
vendor: "install a shared intercom and security system across every room
in this house." This repo is that vendor. It's the first (and so far only)
thing platform-gitops points at that isn't just another pointer — it's
where Helm charts actually get installed onto the cluster `platform-core`
built.

```
environments/
  base/               # the shared install, common to every house
  platform-sandbox/   # this house's version pin and settings
  app-dev/
  app-prod/
```

This is the same base-plus-overlay shape used everywhere else in this
project, applied here to something with real, running consequences instead
of pointer files. `base/` holds what's identical across every house — which
chart, which vendor to order it from. Each house's own folder holds only
what has to differ: which version of the install that house is running
right now. Bumping a version means editing one house's folder, watching it
work, then editing the next — never touching `base/` for a routine
version change.

## Extensions and services are two different kinds of vendor work

Not everything a vendor installs behaves the same way, and the difference
matters for how you think about what's in this repo:

- An **extension** changes how the house's systems behave, without being
  something anyone directly interacts with. A rule that automatically
  wires a security camera into every new room built, with no separate
  request needed, is an extension. It has no address you can call.
- A **service** runs continuously and has an address someone actually
  uses — a phone line, a water line. Residents call it directly, whenever
  they need it.

The service mesh installed in this repo is mostly the first kind: it
changes how pods talk to each other, automatically, without any pod having
to ask for it. A shared database or message queue, if this project had
one, would be the second kind. Both categories end up living in this one
repo for simplicity, but they're worth telling apart, because they fail
differently — a broken extension is often invisible until something
downstream quietly stops working right; a broken service is usually loud
and immediate, because someone's call just failed.

Continue to [**Service Mesh Deployment**](service-mesh.md) for what
actually gets installed, and an incident where every piece existed and
was running, and it still didn't work.
