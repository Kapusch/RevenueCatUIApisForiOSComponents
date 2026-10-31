#!/usr/bin/env python3
"""Check that the core binding's RevenueCat.framework exports every RevenueCat symbol RevenueCatUI imports.

RevenueCatUI is built here against a RevenueCat.framework compiled from the locked purchases-ios tag,
but at run time it loads the RevenueCat.framework shipped by the Kebechet.Maui.RevenueCat.iOS package.
A missing symbol would crash at launch, so compare them slice by slice before packing.

Usage: verify-core-abi.py [path to the restored Kebechet.Maui.RevenueCat.iOS package folder]
The default is the NuGet global packages folder entry for the csproj's lower version bound.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "src/Kapusch.RevenueCatUIApisForiOSComponents"
UI_XCFRAMEWORK = PROJECT / "Native/iOS/build/RevenueCatUI.xcframework"
SLICES = ("ios-arm64", "ios-arm64_x86_64-simulator")
IMPORTED = re.compile(r"^(_\$s\S*10RevenueCat\S*|_OBJC_CLASS_\$_RC\S+|_OBJC_METACLASS_\$_RC\S+)$")


def symbols(binary: Path, arch: str, *flags: str) -> set[str]:
    output = subprocess.check_output(["nm", *flags, "-arch", arch, str(binary)], text=True)
    return {line.split()[-1] for line in output.splitlines() if line.strip()}


def archs(binary: Path) -> list[str]:
    return subprocess.check_output(["lipo", "-archs", str(binary)], text=True).split()


def core_package_dir() -> Path:
    if len(sys.argv) > 1:
        return Path(sys.argv[1])
    csproj = (PROJECT / "Kapusch.RevenueCatUIApisForiOSComponents.csproj").read_text(encoding="utf-8")
    version = re.search(r'Include="Kebechet\.Maui\.RevenueCat\.iOS" Version="\[([^,\]]+)', csproj).group(1)
    packages = Path(os.environ.get("NUGET_PACKAGES", Path.home() / ".nuget/packages"))
    candidates = sorted((packages / "kebechet.maui.revenuecat.ios").glob(f"{version}*"))
    if not candidates:
        sys.exit(f"Restore the project first: no Kebechet.Maui.RevenueCat.iOS {version} in {packages}")
    return candidates[-1]


def main() -> int:
    package = core_package_dir()
    resources = next(package.glob("lib/net*-ios*/Maui.RevenueCat.iOS.resources.zip"), None)
    if resources is None:
        sys.exit(f"No iOS resources archive in {package}")
    errors = []
    checked = 0
    with tempfile.TemporaryDirectory() as temp:
        with zipfile.ZipFile(resources) as archive:
            archive.extractall(temp)
        core_root = next(Path(temp).rglob("RevenueCat.xcframework"))
        for slice_name in SLICES:
            ui = UI_XCFRAMEWORK / slice_name / "RevenueCatUI.framework/RevenueCatUI"
            core = core_root / slice_name / "RevenueCat.framework/RevenueCat"
            for arch in archs(ui):
                needed = {s for s in symbols(ui, arch, "-u") if IMPORTED.match(s)}
                exported = symbols(core, arch, "-gU")
                missing = sorted(needed - exported)
                checked += len(needed)
                errors.extend(f"{slice_name}/{arch}: {name}" for name in missing[:20])
                if len(missing) > 20:
                    errors.append(f"{slice_name}/{arch}: ... {len(missing) - 20} more")
    if errors:
        print("Core ABI check failed, missing in the core binding:\n  " + "\n  ".join(errors), file=sys.stderr)
        return 1
    print(f"Core ABI check passed ({checked} imported symbols resolved against {package.name})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
