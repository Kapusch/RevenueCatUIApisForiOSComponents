#!/usr/bin/env bash
# Builds the two native artifacts this package ships:
#   build/RevenueCatUI.xcframework   dynamic RevenueCatUI, built from the locked purchases-ios tag
#   build/krcui.xcframework          static C-ABI facade over RevenueCatUI
# RevenueCat.framework is compiled only to build against. It is not shipped: consumers get it from
# the core binding package, which must be built from the same purchases-ios tag.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$ROOT_DIR/../../../.." && pwd)"
LOCK_FILE="$REPO_DIR/DependencyLocks/purchases-ios.json"
BUILD_DIR="$ROOT_DIR/build"
CACHE_DIR="$ROOT_DIR/.cache"
FACADE_DIR="$ROOT_DIR/KapuschRevenueCatUIInterop"
DEPLOYMENT_TARGET="15.0"

mkdir -p "$REPO_DIR/artifacts/nuget"

VERSION="$(plutil -extract version raw -o - "$LOCK_FILE")"
REVISION="$(plutil -extract revision raw -o - "$LOCK_FILE")"
REPOSITORY="$(plutil -extract repository raw -o - "$LOCK_FILE")"
SOURCE_DIR="$CACHE_DIR/purchases-ios-$VERSION"
ARCHIVES_DIR="$CACHE_DIR/archives-$VERSION"

if [ ! -d "$SOURCE_DIR/.git" ]; then
	echo "[RevenueCatUI] Fetching purchases-ios $VERSION..."
	rm -rf "$SOURCE_DIR"
	git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$VERSION" "$REPOSITORY" "$SOURCE_DIR"
fi
CHECKOUT_REVISION="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
if [ "$CHECKOUT_REVISION" != "$REVISION" ]; then
	echo "purchases-ios checkout is $CHECKOUT_REVISION, lock requires $REVISION" >&2
	exit 1
fi
echo "[RevenueCatUI] purchases-ios checkout matches lock revision $REVISION"

archive() {
	local destination="$1" name="$2"
	if [ -d "$ARCHIVES_DIR/$name.xcarchive" ]; then
		return
	fi
	echo "[RevenueCatUI] Archiving for $destination..."
	# The xcodeproj RevenueCatUIDev scheme produces dynamic RevenueCat and RevenueCatUI frameworks.
	# SWIFT_INSTALL_OBJC_HEADER=YES emits RevenueCatUI-Swift.h, which the upstream release asset lacks.
	xcodebuild archive \
		-quiet \
		-project "$SOURCE_DIR/RevenueCat.xcodeproj" \
		-scheme RevenueCatUIDev \
		-configuration Release \
		-destination "$destination" \
		-archivePath "$ARCHIVES_DIR/$name.xcarchive" \
		-derivedDataPath "$CACHE_DIR/DerivedData" \
		SKIP_INSTALL=NO \
		BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
		SWIFT_INSTALL_OBJC_HEADER=YES
}
archive "generic/platform=iOS" iphoneos
archive "generic/platform=iOS Simulator" iphonesimulator

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/obj"

echo "[RevenueCatUI] Creating RevenueCatUI.xcframework..."
xcodebuild -create-xcframework \
	-framework "$ARCHIVES_DIR/iphoneos.xcarchive/Products/Library/Frameworks/RevenueCatUI.framework" \
	-framework "$ARCHIVES_DIR/iphonesimulator.xcarchive/Products/Library/Frameworks/RevenueCatUI.framework" \
	-output "$BUILD_DIR/RevenueCatUI.xcframework"
# Consumers link the binary and load its resources; Swift module files are only needed to compile
# Swift against it, and their long paths break packing on some hosts.
find "$BUILD_DIR/RevenueCatUI.xcframework" -type d -name "*.swiftmodule" -prune -exec rm -rf {} +

compile_facade() {
	local sdk="$1" target="$2" archive_name="$3" output="$4"
	xcrun --sdk "$sdk" swiftc \
		-parse-as-library \
		-emit-library -static \
		-module-name KapuschRevenueCatUIInterop \
		-O -whole-module-optimization \
		-target "$target" \
		-F "$ARCHIVES_DIR/$archive_name.xcarchive/Products/Library/Frameworks" \
		"$FACADE_DIR"/Sources/*.swift \
		-o "$output"
}

echo "[KapuschRevenueCatUIInterop] Building facade..."
compile_facade iphoneos "arm64-apple-ios$DEPLOYMENT_TARGET" iphoneos "$BUILD_DIR/obj/libkrcui-iphoneos.a"
compile_facade iphonesimulator "arm64-apple-ios$DEPLOYMENT_TARGET-simulator" iphonesimulator "$BUILD_DIR/obj/libkrcui-sim-arm64.a"
compile_facade iphonesimulator "x86_64-apple-ios$DEPLOYMENT_TARGET-simulator" iphonesimulator "$BUILD_DIR/obj/libkrcui-sim-x86_64.a"
lipo -create "$BUILD_DIR/obj/libkrcui-sim-arm64.a" "$BUILD_DIR/obj/libkrcui-sim-x86_64.a" \
	-output "$BUILD_DIR/obj/libkrcui-simulator.a"

xcodebuild -create-xcframework \
	-library "$BUILD_DIR/obj/libkrcui-iphoneos.a" -headers "$FACADE_DIR/include" \
	-library "$BUILD_DIR/obj/libkrcui-simulator.a" -headers "$FACADE_DIR/include" \
	-output "$BUILD_DIR/krcui.xcframework"
rm -rf "$BUILD_DIR/obj"

echo "[RevenueCatUI] Done: $BUILD_DIR"
