# Public native SDK working agreement

Produce a reproducible `Kapusch.RevenueCatUI.iOS` NuGet. Keep all documentation,
samples and artifacts generic. No application/company names, real API keys,
private diagnostics or customer data. Follow src/Native, buildTransitive, Docs
and samples conventions. Package native dependencies; consumer builds never
fetch them.

Keep the wrapper thin: mirror RevenueCatUI's own API and delegate, add no purchase,
entitlement or navigation policy. Never ship RevenueCat.framework: the core binding
package provides it, built from the same purchases-ios tag as
`DependencyLocks/purchases-ios.json`. Bump both together and re-run
`scripts/verify-core-abi.py`.

Native exports use the `krcui_` prefix and are consumed with
`LibraryImport("__Internal")`. Change a signature by adding a new symbol, never by
editing an existing one. Pin versions and dependency integrity, include third-party
licenses. Verify a clean packed-package consumer and device/runtime semantics before
claiming support.

`main` is the only long-lived branch and the source of every NuGet.org release.
Use short-lived branches and pull requests. Commits follow Conventional Commits.
