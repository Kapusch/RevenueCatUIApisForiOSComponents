## Summary

- What does this change do?

## Checklist

- [ ] No secrets committed
- [ ] Built native artifacts: `bash src/Kapusch.RevenueCatUIApisForiOSComponents/Native/iOS/build.sh`
- [ ] Packed NuGet: `dotnet pack src/Kapusch.RevenueCatUIApisForiOSComponents/Kapusch.RevenueCatUIApisForiOSComponents.csproj -c Release -o artifacts/nuget`
- [ ] Validated package: `python3 scripts/verify-package.py`
- [ ] Core ABI check: `python3 scripts/verify-core-abi.py`
- [ ] Dependency lock check: `python3 scripts/verify-dependency-lock.py`
- [ ] Public tree scan: `python3 scripts/verify-public.py`
- [ ] Sample built: `dotnet build samples/Smoke/Smoke.csproj -c Release -p:RuntimeIdentifier=iossimulator-arm64`
- [ ] Updated docs if behavior/integration changed
