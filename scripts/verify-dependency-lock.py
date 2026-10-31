#!/usr/bin/env python3
"""Check that the purchases-ios lock, the core binding range and the docs name the same version."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "src/Kapusch.RevenueCatUIApisForiOSComponents"


def main() -> int:
    lock = json.loads((ROOT / "DependencyLocks/purchases-ios.json").read_text(encoding="utf-8"))
    errors = []
    version = lock.get("version", "")
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        errors.append(f"lock version is not X.Y.Z: {version!r}")
    if not re.fullmatch(r"[0-9a-f]{40}", lock.get("revision", "")):
        errors.append("lock revision is not a 40-character commit hash")
    if lock.get("repository") != "https://github.com/RevenueCat/purchases-ios.git":
        errors.append("lock repository is not the upstream purchases-ios repository")

    major, minor, patch = (int(part) for part in version.split(".")) if not errors else (0, 0, 0)
    expected_range = f"[{version},{major}.{minor}.{patch + 1})"
    csproj = (PROJECT / "Kapusch.RevenueCatUIApisForiOSComponents.csproj").read_text(encoding="utf-8")
    match = re.search(r'Include="Kebechet\.Maui\.RevenueCat\.iOS" Version="([^"]+)"', csproj)
    if not match or match.group(1) != expected_range:
        errors.append(f"core binding range must be {expected_range}, found {match.group(1) if match else 'none'}")

    for name in ("THIRD_PARTY_NOTICES.md", "README.md", "CHANGELOG.md", "src/Kapusch.RevenueCatUIApisForiOSComponents/nuget-readme.md"):
        if version not in (ROOT / name).read_text(encoding="utf-8"):
            errors.append(f"{name} does not mention purchases-ios {version}")
    if f"RevenueCatUI {version}" not in csproj:
        errors.append(f"PackageReleaseNotes does not mention RevenueCatUI {version}")

    if errors:
        print("Dependency lock check failed:\n  " + "\n  ".join(errors), file=sys.stderr)
        return 1
    print(f"Dependency lock check passed (purchases-ios {version} @ {lock['revision'][:12]})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
