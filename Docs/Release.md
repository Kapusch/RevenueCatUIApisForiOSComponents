# Release workflow

`main` is the only long-lived branch. Feature work uses short-lived branches and pull requests targeting `main`; this repository does not create `release/*` branches.

## Channels

- Manual workflow run without `manual_version`: build a preview package and publish it to GitHub Packages.
- `vX.Y.Z-rc.N` tag reachable from `origin/main`: publish that prerelease to NuGet.org.
- `vX.Y.Z` tag reachable from `origin/main`: publish that stable version to NuGet.org.
- Manual workflow run with `manual_version`: publish to NuGet.org only when the workflow runs from `main`.

NuGet versions and Git tags are immutable. Query the official NuGet index before publishing and never move or recreate an existing tag.

## Release sequence

1. Fetch `origin`, start a short-lived branch from `origin/main`, and verify the worktree is clean.
2. Build the native artifacts, pack the NuGet, then run the package, dependency lock and core ABI checks.
3. Open a PR to `main` and require CI to pass.
4. Merge and fetch the resulting `origin/main` commit.
5. Create the RC or stable tag on that exact commit and push only the new tag.
6. Verify the publish workflow and the resulting NuGet package before updating consumers.

Do not delete historical tags. Delete a temporary branch only after every retained commit is reachable from `origin/main`.

One-time setup: a NuGet.org Trusted Publishing policy for this repository and `publish.yml`, and the `NUGET_USER` repository secret.
