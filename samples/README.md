# Packed-package smoke sample

Build the native artifacts and pack the package into `artifacts/nuget` first, then build
`samples/Smoke/Smoke.csproj`. The sample uses **PackageReference**, not project references.

It configures the core SDK with a placeholder key, creates a paywall view controller with a
delegate and shows it. With the placeholder key RevenueCat cannot load offerings, so the run checks
packaging, native linking and startup (RevenueCatUI and RevenueCat.framework load, the facade
creates the controller and delegate events reach .NET), not a real paywall. To see a real paywall,
set the `REVENUECAT_API_KEY` environment variable at launch to a public SDK key of a test project.
