# Contributing

## Prerequisites

- macOS with Xcode 26.3
- .NET SDK and iOS workload 10.0.203 (`dotnet workload install ios --version 10.0.203`)
- Python 3

## Local build

```sh
bash src/Kapusch.RevenueCatUIApisForiOSComponents/Native/iOS/build.sh
dotnet pack src/Kapusch.RevenueCatUIApisForiOSComponents/Kapusch.RevenueCatUIApisForiOSComponents.csproj -c Release -o artifacts/nuget
python3 scripts/verify-package.py
python3 scripts/verify-core-abi.py
```

Then build the packed-package sample (`samples/Smoke`). See [Docs/SourceMode.md](Docs/SourceMode.md).

## Pull requests

- Branch from `main` and target `main`.
- Keep the wrapper thin: expose what RevenueCatUI exposes, without app policy.
- Never commit API keys, logs or customer data.
- Run `python3 scripts/verify-public.py` before publishing. The scan rejects
  real-looking RevenueCat API keys and, case-insensitively, any private term read at
  run time from the `KAPUSCH_PRIVATE_TERMS` environment variable (CI: the repository
  secret of the same name) or the untracked `.git/info/private-terms` file (one term
  per line or comma-separated). Private terms are never tracked; failures name the
  file and the term's position only.

## License

Contributions are licensed under the [MIT License](LICENSE).
