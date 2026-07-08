#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
APP_NAME="${APP_NAME:-Vizza}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-vizzaodin}"
BUNDLE_ID="${BUNDLE_ID:-com.zelda-built-this.Vizza.store}"
APP_VERSION_FILE="$ROOT_DIR/packages/engine/version.odin"
DEFAULT_VERSION="0.1.0"
if [[ -f "$APP_VERSION_FILE" ]]; then
	DEFAULT_VERSION="$(awk -F '"' '/^APP_VERSION ::/ {print $2; exit}' "$APP_VERSION_FILE")"
fi
VERSION="${VERSION:-$DEFAULT_VERSION}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
ARCHIVE_PATH="$DIST_DIR/$APP_NAME-macos.zip"

SIGN_IDENTITY="${MACOS_CODESIGN_IDENTITY:-${CODESIGN_IDENTITY:-}}"
ENTITLEMENTS="${MACOS_ENTITLEMENTS:-}"
NOTARY_PROFILE="${NOTARYTOOL_PROFILE:-${MACOS_NOTARY_PROFILE:-}}"
APPLE_API_KEY_PATH="${APPLE_API_KEY_PATH:-}"
APPLE_API_KEY="${APPLE_API_KEY:-}"
APPLE_API_ISSUER="${APPLE_API_ISSUER:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-${TEAM_ID:-}}"
APPLE_APP_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-${APP_SPECIFIC_PASSWORD:-}}"
SKIP_SIGN="${SKIP_SIGN:-0}"
SKIP_NOTARIZE="${SKIP_NOTARIZE:-0}"
ODIN_FLAGS="${ODIN_FLAGS:--o:none}"
STEAM_ENABLED="${STEAM_ENABLED:-0}"
STEAM_APP_ID="${STEAM_APP_ID:-4945920}"
STEAM_SDK_LOCATION="${STEAM_SDK_LOCATION:-$HOME/steam_sdk}"

usage() {
	cat <<USAGE
Usage: scripts/package_macos.sh [options]

Builds a signed macOS .app bundle and, unless disabled, notarizes a zip archive.

Options:
  --app-name NAME          App bundle name. Default: $APP_NAME
  --bundle-id ID           CFBundleIdentifier. Default: $BUNDLE_ID
  --version VERSION        CFBundleShortVersionString. Default: $VERSION
  --identity IDENTITY      codesign identity. Default: env or first Developer ID Application identity
  --entitlements PATH      Optional entitlements plist.
  --steam                  Build with SteamAPI support and bundle libsteam_api.dylib.
  --steam-app-id ID        Steam App ID passed to the Odin build. Default: $STEAM_APP_ID
  --steam-sdk PATH         Steamworks SDK root. Default: $STEAM_SDK_LOCATION
  --skip-sign              Build the app bundle without codesigning.
  --skip-notarize          Skip notarytool submission and stapling.
  -h, --help               Show this help.

Environment:
  MACOS_CODESIGN_IDENTITY or CODESIGN_IDENTITY
  MACOS_ENTITLEMENTS
  NOTARYTOOL_PROFILE or MACOS_NOTARY_PROFILE
  APPLE_API_KEY_PATH, APPLE_API_KEY, APPLE_API_ISSUER
  APPLE_ID, APPLE_TEAM_ID, APPLE_APP_SPECIFIC_PASSWORD
  ODIN_FLAGS              Default: -o:none
  STEAM_ENABLED           Set to 1 to match --steam.
  STEAM_APP_ID
  STEAM_SDK_LOCATION

Outputs:
  $APP_DIR
  $ARCHIVE_PATH
USAGE
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--app-name)
			APP_NAME="$2"
			shift 2
			;;
		--bundle-id)
			BUNDLE_ID="$2"
			shift 2
			;;
		--version)
			VERSION="$2"
			shift 2
			;;
		--identity)
			SIGN_IDENTITY="$2"
			shift 2
			;;
		--entitlements)
			ENTITLEMENTS="$2"
			shift 2
			;;
		--steam)
			STEAM_ENABLED=1
			shift
			;;
		--steam-app-id)
			STEAM_APP_ID="$2"
			shift 2
			;;
		--steam-sdk)
			STEAM_SDK_LOCATION="$2"
			shift 2
			;;
		--skip-sign)
			SKIP_SIGN=1
			shift
			;;
		--skip-notarize)
			SKIP_NOTARIZE=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			printf 'Unknown option: %s\n\n' "$1" >&2
			usage >&2
			exit 2
			;;
	esac
done

APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
ARCHIVE_PATH="$DIST_DIR/$APP_NAME-macos.zip"

require_tool() {
	if ! command -v "$1" >/dev/null 2>&1; then
		printf 'Missing required tool: %s\n' "$1" >&2
		exit 1
	fi
}

copy_dylib() {
	local source="$1"
	local name
	name="$(basename "$source")"
	if [[ -f "$source" && ! -f "$FRAMEWORKS_DIR/$name" ]]; then
		cp "$source" "$FRAMEWORKS_DIR/$name"
		chmod 755 "$FRAMEWORKS_DIR/$name"
	fi
}

copy_homebrew_dylib() {
	local formula="$1"
	local relative_path="$2"
	local prefix
	if prefix="$(brew --prefix "$formula" 2>/dev/null)" && [[ -n "$prefix" ]]; then
		copy_dylib "$prefix/$relative_path"
	fi
}

sign_path() {
	local path="$1"
	local args=(--force --timestamp --options runtime --sign "$SIGN_IDENTITY")
	if [[ -n "$ENTITLEMENTS" ]]; then
		args+=(--entitlements "$ENTITLEMENTS")
	fi
	codesign "${args[@]}" "$path"
}

resolve_sign_identity() {
	if [[ -n "$SIGN_IDENTITY" ]]; then
		return
	fi

	SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Developer ID Application/ {print $2; exit}')"
	if [[ -z "$SIGN_IDENTITY" ]]; then
		printf 'No codesign identity configured. Set MACOS_CODESIGN_IDENTITY or CODESIGN_IDENTITY.\n' >&2
		exit 1
	fi
}

create_icon() {
	local icon_source="$ROOT_DIR/icon.png"
	local iconset="$BUILD_DIR/macos-package/AppIcon.iconset"
	local icns="$RESOURCES_DIR/AppIcon.icns"

	if [[ ! -f "$icon_source" ]]; then
		printf 'No icon.png found; continuing without an app icon.\n'
		return
	fi

	if command -v magick >/dev/null 2>&1; then
		magick "$icon_source" -resize 1024x1024 -background none -gravity center -extent 1024x1024 -define icon:auto-resize=1024,512,256,128,64,32,16 "$icns"
		return
	fi

	rm -rf "$iconset"
	mkdir -p "$iconset"
	sips -z 16 16 "$icon_source" --out "$iconset/icon_16x16.png" >/dev/null
	sips -z 32 32 "$icon_source" --out "$iconset/icon_16x16@2x.png" >/dev/null
	sips -z 32 32 "$icon_source" --out "$iconset/icon_32x32.png" >/dev/null
	sips -z 64 64 "$icon_source" --out "$iconset/icon_32x32@2x.png" >/dev/null
	sips -z 128 128 "$icon_source" --out "$iconset/icon_128x128.png" >/dev/null
	sips -z 256 256 "$icon_source" --out "$iconset/icon_128x128@2x.png" >/dev/null
	sips -z 256 256 "$icon_source" --out "$iconset/icon_256x256.png" >/dev/null
	sips -z 512 512 "$icon_source" --out "$iconset/icon_256x256@2x.png" >/dev/null
	sips -z 512 512 "$icon_source" --out "$iconset/icon_512x512.png" >/dev/null
	sips -z 1024 1024 "$icon_source" --out "$iconset/icon_512x512@2x.png" >/dev/null
	xattr -cr "$iconset" 2>/dev/null || true
	iconutil -c icns "$iconset" -o "$icns"
}

write_info_plist() {
	cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>$APP_NAME</string>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$VERSION</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
PLIST
}

build_launcher() {
	local source="$BUILD_DIR/macos-package/launcher.c"
	cat > "$source" <<LAUNCHER
#include <errno.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void join2(char *out, size_t out_size, const char *a, const char *b) {
	snprintf(out, out_size, "%s/%s", a, b);
}

int main(int argc, char **argv) {
	char executable[PATH_MAX];
	char resolved[PATH_MAX];
	uint32_t executable_size = sizeof(executable);

	if (_NSGetExecutablePath(executable, &executable_size) != 0 || realpath(executable, resolved) == NULL) {
		fprintf(stderr, "Unable to resolve app launcher path.\\n");
		return 1;
	}

	char contents[PATH_MAX];
	strncpy(contents, resolved, sizeof(contents) - 1);
	contents[sizeof(contents) - 1] = '\\0';

	char *slash = strrchr(contents, '/');
	if (slash == NULL) return 1;
	*slash = '\\0';
	slash = strrchr(contents, '/');
	if (slash == NULL) return 1;
	*slash = '\\0';

	char resources[PATH_MAX];
	char frameworks[PATH_MAX];
	char icd[PATH_MAX];
	char target[PATH_MAX];
	join2(resources, sizeof(resources), contents, "Resources");
	join2(frameworks, sizeof(frameworks), contents, "Frameworks");
	join2(icd, sizeof(icd), resources, "vulkan/icd.d/MoltenVK_icd.json");
	join2(target, sizeof(target), contents, "MacOS/$EXECUTABLE_NAME");

	const char *old_dyld = getenv("DYLD_LIBRARY_PATH");
	char dyld[PATH_MAX * 2];
	if (old_dyld != NULL && old_dyld[0] != '\\0') {
		snprintf(dyld, sizeof(dyld), "%s:%s", frameworks, old_dyld);
	} else {
		snprintf(dyld, sizeof(dyld), "%s", frameworks);
	}
	setenv("DYLD_LIBRARY_PATH", dyld, 1);

	if (access(icd, R_OK) == 0) {
		setenv("VK_ICD_FILENAMES", icd, 1);
	}

	if (chdir(resources) != 0) {
		fprintf(stderr, "Unable to change directory to %s: %s\\n", resources, strerror(errno));
		return 1;
	}

	char **child_argv = calloc((size_t)argc + 1, sizeof(char *));
	if (child_argv == NULL) {
		fprintf(stderr, "Unable to allocate launcher argv.\\n");
		return 1;
	}
	child_argv[0] = target;
	for (int i = 1; i < argc; i += 1) {
		child_argv[i] = argv[i];
	}

	execv(target, child_argv);
	fprintf(stderr, "Unable to launch %s: %s\\n", target, strerror(errno));
	return 1;
}
LAUNCHER
	cc "$source" -o "$MACOS_DIR/$APP_NAME"
	chmod 755 "$MACOS_DIR/$APP_NAME"
}

require_tool odin
require_tool make
require_tool cc
require_tool sips
if ! command -v magick >/dev/null 2>&1; then
	require_tool iconutil
fi
require_tool ditto
if [[ "$SKIP_SIGN" != "1" ]]; then
	require_tool codesign
	require_tool security
fi
if [[ "$SKIP_SIGN" != "1" && "$SKIP_NOTARIZE" != "1" ]]; then
	require_tool xcrun
fi

printf 'Building %s...\n' "$EXECUTABLE_NAME"
if [[ "$STEAM_ENABLED" == "1" ]]; then
	make -C "$ROOT_DIR" shaders build-steam ODIN_FLAGS="$ODIN_FLAGS" STEAM_APP_ID="$STEAM_APP_ID" STEAM_SDK_LOCATION="$STEAM_SDK_LOCATION"
else
	make -C "$ROOT_DIR" shaders build ODIN_FLAGS="$ODIN_FLAGS"
fi

rm -rf "$APP_DIR" "$ARCHIVE_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR" "$DIST_DIR" "$BUILD_DIR/macos-package"

cp "$BUILD_DIR/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod 755 "$MACOS_DIR/$EXECUTABLE_NAME"
cp -R "$ROOT_DIR/assets" "$RESOURCES_DIR/assets"
mkdir -p "$RESOURCES_DIR/build"
cp -R "$BUILD_DIR/shaders" "$RESOURCES_DIR/build/shaders"

write_info_plist
build_launcher
create_icon

copy_homebrew_dylib sdl3 lib/libSDL3.0.dylib
copy_homebrew_dylib vulkan-loader lib/libvulkan.1.dylib
copy_homebrew_dylib molten-vk lib/libMoltenVK.dylib
if [[ "$STEAM_ENABLED" == "1" ]]; then
	copy_dylib "$BUILD_DIR/libsteam_api.dylib"
	if [[ ! -f "$FRAMEWORKS_DIR/libsteam_api.dylib" ]]; then
		copy_dylib "$STEAM_SDK_LOCATION/redistributable_bin/osx/libsteam_api.dylib"
	fi
	if [[ ! -f "$FRAMEWORKS_DIR/libsteam_api.dylib" ]]; then
		printf 'Steam enabled but libsteam_api.dylib was not found. Set STEAM_SDK_LOCATION.\n' >&2
		exit 1
	fi
fi
if prefix="$(brew --prefix molten-vk 2>/dev/null)" && [[ -n "$prefix" && -f "$prefix/share/vulkan/icd.d/MoltenVK_icd.json" ]]; then
	mkdir -p "$RESOURCES_DIR/vulkan/icd.d"
	cp "$prefix/share/vulkan/icd.d/MoltenVK_icd.json" "$RESOURCES_DIR/vulkan/icd.d/MoltenVK_icd.json"
fi

if [[ -f "$FRAMEWORKS_DIR/libSDL3.0.dylib" ]]; then
	install_name_tool -change "$(otool -L "$MACOS_DIR/$EXECUTABLE_NAME" | awk '/libSDL3\.0\.dylib/ {print $1; exit}')" "@rpath/libSDL3.0.dylib" "$MACOS_DIR/$EXECUTABLE_NAME" 2>/dev/null || true
	install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$EXECUTABLE_NAME" 2>/dev/null || true
	install_name_tool -id "@rpath/libSDL3.0.dylib" "$FRAMEWORKS_DIR/libSDL3.0.dylib" 2>/dev/null || true
fi
if [[ -f "$FRAMEWORKS_DIR/libvulkan.1.dylib" ]]; then
	install_name_tool -id "@rpath/libvulkan.1.dylib" "$FRAMEWORKS_DIR/libvulkan.1.dylib" 2>/dev/null || true
fi
if [[ -f "$FRAMEWORKS_DIR/libMoltenVK.dylib" ]]; then
	install_name_tool -id "@rpath/libMoltenVK.dylib" "$FRAMEWORKS_DIR/libMoltenVK.dylib" 2>/dev/null || true
fi
if [[ -f "$FRAMEWORKS_DIR/libsteam_api.dylib" ]]; then
	install_name_tool -id "@rpath/libsteam_api.dylib" "$FRAMEWORKS_DIR/libsteam_api.dylib" 2>/dev/null || true
fi

if [[ "$SKIP_SIGN" != "1" ]]; then
	resolve_sign_identity
	printf 'Signing %s...\n' "$APP_NAME.app"
	while IFS= read -r -d '' dylib; do
		sign_path "$dylib"
	done < <(find "$FRAMEWORKS_DIR" -type f -name '*.dylib' -print0)
	sign_path "$MACOS_DIR/$EXECUTABLE_NAME"
	sign_path "$MACOS_DIR/$APP_NAME"
	sign_path "$APP_DIR"
	codesign --verify --deep --strict --verbose=2 "$APP_DIR"
else
	printf 'Skipping codesign.\n'
fi

ditto -c -k --keepParent "$APP_DIR" "$ARCHIVE_PATH"

if [[ "$SKIP_SIGN" != "1" && "$SKIP_NOTARIZE" != "1" ]]; then
	printf 'Submitting %s for notarization...\n' "$(basename "$ARCHIVE_PATH")"
	if [[ -n "$NOTARY_PROFILE" ]]; then
		xcrun notarytool submit "$ARCHIVE_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
	elif [[ -n "$APPLE_API_KEY_PATH" || -n "$APPLE_API_KEY" || -n "$APPLE_API_ISSUER" ]]; then
		if [[ -z "$APPLE_API_KEY_PATH" || -z "$APPLE_API_KEY" || -z "$APPLE_API_ISSUER" ]]; then
			printf 'Incomplete App Store Connect API notarization credentials. Set APPLE_API_KEY_PATH, APPLE_API_KEY, and APPLE_API_ISSUER.\n' >&2
			exit 1
		fi
		xcrun notarytool submit "$ARCHIVE_PATH" --key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY" --issuer "$APPLE_API_ISSUER" --wait
	elif [[ -n "$APPLE_ID" && -n "$APPLE_TEAM_ID" && -n "$APPLE_APP_PASSWORD" ]]; then
		xcrun notarytool submit "$ARCHIVE_PATH" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --wait
	else
		printf 'No notarization credentials found. Set NOTARYTOOL_PROFILE, APPLE_API_KEY_PATH/APPLE_API_KEY/APPLE_API_ISSUER, or APPLE_ID/APPLE_TEAM_ID/APPLE_APP_SPECIFIC_PASSWORD.\n' >&2
		exit 1
	fi
	xcrun stapler staple "$APP_DIR"
	xcrun stapler validate "$APP_DIR"
	ditto -c -k --keepParent "$APP_DIR" "$ARCHIVE_PATH"
else
	printf 'Skipping notarization.\n'
fi

printf 'Packaged app: %s\n' "$APP_DIR"
printf 'Archive: %s\n' "$ARCHIVE_PATH"
