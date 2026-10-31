# Source builds

Run `bash src/Kapusch.RevenueCatUIApisForiOSComponents/Native/iOS/build.sh`, then pack. The script
clones the purchases-ios tag from `DependencyLocks/purchases-ios.json` into `Native/iOS/.cache`,
checks the commit, archives the `RevenueCatUIDev` scheme for device and simulator, creates
`RevenueCatUI.xcframework` and compiles the C facade against it. All downloads happen here, never in
the consumer target.

Source mode uses `UseKapuschRevenueCatUIiOSInteropFromSource=true` and imports the matching
buildTransitive target explicitly when using a ProjectReference.

Qualification toolchain: .NET SDK and workload set **10.0.203**
(`dotnet workload install ios --version 10.0.203`) and Xcode 26.3.

## Updating purchases-ios

RevenueCatUI must match the core binding's RevenueCat.framework exactly.

1. Wait for (or contribute) a `Kebechet.Maui.RevenueCat.iOS` release built from the new tag.
2. Update `DependencyLocks/purchases-ios.json` (version and the tag's commit), the
   `Kebechet.Maui.RevenueCat.iOS` version range in the csproj, `THIRD_PARTY_NOTICES.md`,
   `nuget-readme.md` and `CHANGELOG.md`.
3. Rebuild, then run `scripts/verify-dependency-lock.py` and `scripts/verify-core-abi.py`.
4. Read the upstream changelog for `PaywallViewController` and delegate changes.
