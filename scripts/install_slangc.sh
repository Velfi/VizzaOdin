#!/usr/bin/env sh
set -eu

REPO="shader-slang/slang"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)
INSTALL_DIR=${SLANG_INSTALL_DIR:-"${REPO_ROOT}/.tools/slang"}

need_tool() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "error: required tool '$1' was not found on PATH" >&2
		exit 1
	fi
}

need_tool curl
need_tool sed
need_tool find
need_tool grep

OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH_NAME=$(uname -m | tr '[:upper:]' '[:lower:]')

case "$OS_NAME" in
	darwin)
		OS_PATTERN="macos|darwin|osx"
		;;
	linux)
		OS_PATTERN="linux"
		;;
	*)
		echo "error: unsupported OS '$OS_NAME'; download slangc manually from https://github.com/${REPO}/releases" >&2
		exit 1
		;;
esac

case "$ARCH_NAME" in
	arm64|aarch64)
		ARCH_PATTERN="aarch64|arm64"
		;;
	x86_64|amd64)
		ARCH_PATTERN="x86_64|amd64"
		;;
	*)
		echo "error: unsupported architecture '$ARCH_NAME'; download slangc manually from https://github.com/${REPO}/releases" >&2
		exit 1
		;;
esac

echo "Fetching latest Slang release metadata..."
URLS=$(curl -fsSL "$API_URL" | sed -n 's/.*"browser_download_url": "\(.*\)".*/\1/p')

ASSET_URL=""
for URL in $URLS; do
	NAME=$(basename "$URL" | tr '[:upper:]' '[:lower:]')
	case "$NAME" in
		*debug-info*|*source*)
			continue
			;;
	esac

	if printf '%s\n' "$NAME" | grep -Eq "$OS_PATTERN" &&
	   printf '%s\n' "$NAME" | grep -Eq "$ARCH_PATTERN" &&
	   printf '%s\n' "$NAME" | grep -Eq '\.(zip|tar\.gz)$'; then
		ASSET_URL=$URL
		break
	fi
done

if [ -z "$ASSET_URL" ]; then
	echo "error: could not find a Slang release asset for ${OS_NAME}/${ARCH_NAME}" >&2
	echo "Open https://github.com/${REPO}/releases and install the matching archive manually." >&2
	exit 1
fi

ASSET_NAME=$(basename "$ASSET_URL")
TMP_DIR=$(mktemp -d)
ARCHIVE="${TMP_DIR}/${ASSET_NAME}"
EXTRACT_DIR="${TMP_DIR}/extract"
mkdir -p "$EXTRACT_DIR"

cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

echo "Downloading ${ASSET_NAME}..."
curl -fL "$ASSET_URL" -o "$ARCHIVE"

case "$ASSET_NAME" in
	*.zip)
		need_tool unzip
		unzip -q "$ARCHIVE" -d "$EXTRACT_DIR"
		;;
	*.tar.gz)
		tar -xzf "$ARCHIVE" -C "$EXTRACT_DIR"
		;;
	*)
		echo "error: unsupported archive type: $ASSET_NAME" >&2
		exit 1
		;;
esac

SLANGC_PATH=$(find "$EXTRACT_DIR" -type f -name slangc -perm -111 | head -n 1)
if [ -z "$SLANGC_PATH" ]; then
	SLANGC_PATH=$(find "$EXTRACT_DIR" -type f -name slangc | head -n 1)
fi
if [ -z "$SLANGC_PATH" ]; then
	echo "error: downloaded archive did not contain a slangc executable" >&2
	exit 1
fi

PACKAGE_ROOT=$(CDPATH= cd -- "$(dirname -- "$SLANGC_PATH")/.." && pwd)

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -R "${PACKAGE_ROOT}/." "$INSTALL_DIR/"

INSTALLED_SLANGC=$(find "$INSTALL_DIR" -type f -name slangc | head -n 1)
if [ -z "$INSTALLED_SLANGC" ]; then
	echo "error: install copy did not contain slangc" >&2
	exit 1
fi

mkdir -p "${INSTALL_DIR}/bin"
chmod +x "$INSTALLED_SLANGC"
if [ "$INSTALLED_SLANGC" != "${INSTALL_DIR}/bin/slangc" ]; then
	ln -sf "$INSTALLED_SLANGC" "${INSTALL_DIR}/bin/slangc"
fi

echo
echo "Installed slangc to ${INSTALL_DIR}/bin/slangc"
"${INSTALL_DIR}/bin/slangc" -version
echo
echo "For this repo, Make already searches ${INSTALL_DIR}/bin."
echo "For your shell, add this when needed:"
echo "  export PATH=\"${INSTALL_DIR}/bin:\$PATH\""
