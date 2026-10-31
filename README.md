# RevenueCatUIApisForiOSComponents

Thin .NET 10 iOS interop for [RevenueCat Paywalls](https://www.revenuecat.com/docs/tools/paywalls)
(RevenueCatUI). NuGet ID: **Kapusch.RevenueCatUI.iOS**.

Paywalls are designed in the RevenueCat dashboard and rendered natively by RevenueCatUI. This
package exposes RevenueCatUI's `PaywallViewController` and its delegate to .NET, nothing more: it
creates the controller, forwards every delegate call (including the purchase and restore hooks
that wait for an answer) and supports offering updates and custom variables. Purchases are
performed by the RevenueCat SDK; entitlement, navigation and analytics decisions stay in the app.

| Package | Ships | Depends on |
|---|---|---|
| `Kapusch.RevenueCatUI.iOS` | `RevenueCatUI.xcframework` (purchases-ios 5.83.1) and a static C facade | [`Kebechet.Maui.RevenueCat.iOS`](https://www.nuget.org/packages/Kebechet.Maui.RevenueCat.iOS) 5.83.1.x, which ships `RevenueCat.framework` |

RevenueCatUI links the core `RevenueCat.framework` at run time, so both must come from the same
purchases-ios tag. The package pins that range and `scripts/verify-core-abi.py` checks that every
symbol RevenueCatUI needs is exported by the core binding.

See [integration](Docs/Integration.md), [source builds](Docs/SourceMode.md),
[releases](Docs/Release.md), [samples](samples/README.md), [changelog](CHANGELOG.md) and
[third-party licenses](THIRD_PARTY_NOTICES.md).

## Build

```sh
bash src/Kapusch.RevenueCatUIApisForiOSComponents/Native/iOS/build.sh
dotnet pack src/Kapusch.RevenueCatUIApisForiOSComponents/Kapusch.RevenueCatUIApisForiOSComponents.csproj -c Release -o artifacts/nuget
```

The native build fetches the locked purchases-ios source once and builds RevenueCatUI with Xcode.
Consumer builds do not download native SDKs.

## CI

| Trigger | Result |
|---|---|
| Pull request, push to `main` | Build, verify and pack (`ci.yml`) |
| Manual `publish` run without a version | Preview package on GitHub Packages |
| `vX.Y.Z` / `vX.Y.Z-rc.N` tag reachable from `main` | Package on NuGet.org |

Required GitHub secret: `NUGET_USER` (NuGet.org Trusted Publishing).
