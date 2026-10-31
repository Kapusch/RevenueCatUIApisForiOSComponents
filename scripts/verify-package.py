#!/usr/bin/env python3
"""Check the packed nupkg layout, its core binding dependency and the facade's exported entry points."""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "src/Kapusch.RevenueCatUIApisForiOSComponents"
PACKAGE_ID = "Kapusch.RevenueCatUI.iOS"

REQUIRED = [
    "buildTransitive/Kapusch.RevenueCatUI.iOS.targets",
    "native/krcui.xcframework/Info.plist",
    "native/RevenueCatUI.xcframework/Info.plist",
    "native/RevenueCatUI.xcframework/ios-arm64/RevenueCatUI.framework/RevenueCatUI",
    "native/RevenueCatUI.xcframework/ios-arm64_x86_64-simulator/RevenueCatUI.framework/RevenueCatUI",
    "THIRD_PARTY_NOTICES.md",
    "licenses/purchases-ios/LICENSE",
    "nuget-readme.md",
]


def main() -> int:
    packages = sorted((ROOT / "artifacts/nuget").glob(f"{PACKAGE_ID}.*.nupkg"))
    if not packages:
        sys.exit("No package in artifacts/nuget; run dotnet pack first.")
    package = packages[-1]
    version = package.name[len(PACKAGE_ID) + 1 : -len(".nupkg")]
    errors = []
    with zipfile.ZipFile(package) as archive:
        names = set(archive.namelist())
        for required in REQUIRED:
            if required not in names:
                errors.append(f"missing {required}")
        if not any(re.fullmatch(r"lib/net10\.0-ios[\d.]*/Kapusch\.RevenueCatUI\.iOS\.dll", n) for n in names):
            errors.append("missing lib/net10.0-ios*/Kapusch.RevenueCatUI.iOS.dll")
        if any("RevenueCat.framework/" in n for n in names):
            errors.append("RevenueCat.framework must come from the core binding, not this package")
        nuspec = archive.read(next(n for n in names if n.endswith(".nuspec"))).decode("utf-8")
        if not re.search(r'id="Kebechet\.Maui\.RevenueCat\.iOS" version="\[[^"]+\)"', nuspec):
            errors.append("nuspec must depend on a bounded Kebechet.Maui.RevenueCat.iOS range")
        with tempfile.TemporaryDirectory() as temp:
            archive.extractall(temp, [n for n in names if n.startswith("native/krcui.xcframework/")])
            libraries = list(Path(temp).rglob("*.a"))
            sources = "\n".join(p.read_text(encoding="utf-8") for p in PROJECT.rglob("*.cs") if "/obj/" not in str(p))
            entry_points = set(re.findall(r'EntryPoint = "(krcui_\w+)"', sources))
            for library in libraries:
                exported = subprocess.check_output(["nm", "-gU", str(library)], text=True)
                for entry_point in sorted(entry_points):
                    if f"_{entry_point}" not in exported:
                        errors.append(f"{library.parent.name}: missing export {entry_point}")
            if not libraries:
                errors.append("no static library in native/krcui.xcframework")

    # Release and preview runs override the version; the sample tracks the csproj version.
    csproj = (PROJECT / "Kapusch.RevenueCatUIApisForiOSComponents.csproj").read_text(encoding="utf-8")
    project_version = re.search(r"<Version>([^<]+)</Version>", csproj).group(1)
    sample = (ROOT / "samples/Smoke/Smoke.csproj").read_text(encoding="utf-8")
    if f'Include="{PACKAGE_ID}" Version="{project_version}"' not in sample:
        errors.append(f"samples/Smoke/Smoke.csproj must reference {PACKAGE_ID} {project_version}")

    if errors:
        print(f"Package check failed for {package.name}:\n  " + "\n  ".join(errors), file=sys.stderr)
        return 1
    print(f"Package check passed ({package.name}, {len(entry_points)} entry points)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
