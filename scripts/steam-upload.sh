#!/usr/bin/env bash
#
# Stage Vizza release artifacts and upload them to Steam via steamcmd.
#
# Usage:
#   scripts/steam-upload.sh [flags] <version>
#
# Flags:
#   --local        Stage from local dist/Vizza.app instead of downloading the
#                  GitHub release. Useful for smoke testing.
#   --preview      Build the depot and validate, but do NOT upload to Steam.
#                  Always run this first when changing the VDFs.
#   --branch NAME  Set the build live on this beta branch after upload.
#                  Default: empty (build is uploaded but not promoted; use the
#                  Steamworks partner UI to promote).
#   --beta         Set the build live on the "beta" branch after upload.
#                  Override the branch name with STEAM_BETA_BRANCH.
#   --skip-login   Don't pass +login to steamcmd; assume an existing cached
#                  session. Useful when re-running after a successful login.
#
# Example:
#   STEAM_BUILD_USER=vizza_ci scripts/steam-upload.sh --preview --local 0.1.0
#   STEAM_BUILD_USER=vizza_ci scripts/steam-upload.sh --preview 0.1.0
#   STEAM_BUILD_USER=vizza_ci scripts/steam-upload.sh --beta 0.1.0
#
# Environment:
#   STEAM_SDK_ROOT       Path to the Steamworks SDK root.
#                        Default: STEAM_SDK_LOCATION, then ~/steam_sdk.
#   STEAM_SDK_LOCATION   Also accepted for consistency with package_macos.sh.
#   STEAM_BUILD_USER     Steam account with "Publish Builds" partner permission.
#                        Required unless --skip-login.
#   STEAM_BUILD_PASSWORD If set, passed to steamcmd on stdin; otherwise
#                        steamcmd prompts interactively.
#   STEAM_BETA_BRANCH    Used with --beta. Default: beta.
#   packaging/steam/targets.env — default AppID / depot ID.

set -euo pipefail

# ─────────────────────────── Arg parsing ───────────────────────────
LOCAL=0
PREVIEW=0
SKIP_LOGIN=0
BETA=0
BRANCH=""
VERSION=""

while [[ $# -gt 0 ]]; do
	case "$1" in
		--local)       LOCAL=1; shift ;;
		--preview)     PREVIEW=1; shift ;;
		--skip-login)  SKIP_LOGIN=1; shift ;;
		--beta)        BETA=1; shift ;;
		--branch)
			if [[ $# -lt 2 || "$2" == -* ]]; then
				echo "error: --branch requires a branch name" >&2
				exit 1
			fi
			BRANCH="$2"; shift 2 ;;
		-h|--help)     sed -n '3,35p' "$0"; exit 0 ;;
		-*)            echo "unknown flag: $1" >&2; exit 1 ;;
		*)
			if [[ -n "$VERSION" ]]; then
				echo "error: version specified twice ('$VERSION' and '$1')" >&2
				exit 1
			fi
			VERSION="$1"; shift ;;
	esac
done

if [[ $BETA -eq 1 ]]; then
	if [[ -n "$BRANCH" ]]; then
		echo "error: use either --beta or --branch, not both" >&2
		exit 1
	fi
	BRANCH="${STEAM_BETA_BRANCH:-beta}"
fi

if [[ -z "$VERSION" ]]; then
	echo "error: version is required (e.g. 0.1.0)" >&2
	exit 1
fi
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
	echo "error: '$VERSION' is not a valid semver version" >&2
	exit 1
fi
TAG="v${VERSION}"

# ─────────────────────────── Resolve config ───────────────────────────
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

STEAM_SDK_ROOT="${STEAM_SDK_ROOT:-${STEAM_SDK_LOCATION:-${HOME}/steam_sdk}}"
TARGETS_ENV="${REPO_ROOT}/packaging/steam/targets.env"
if [[ -f "$TARGETS_ENV" ]]; then
	# shellcheck source=/dev/null
	source "$TARGETS_ENV"
fi
STEAM_APP_ID="${STEAM_APP_ID:-4945920}"
STEAM_DEPOT_MACOS="${STEAM_DEPOT_MACOS:-4945922}"

validate_app_id () {
	local label="$1"
	local value="$2"
	if ! [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" -eq 0 ]]; then
		echo "error: invalid $label AppID: '$value'" >&2
		return 1
	fi
}

validate_depot_id () {
	local label="$1"
	local value="$2"
	if ! [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" -eq 0 ]]; then
		echo "error: invalid $label depot ID: '$value'" >&2
		return 1
	fi
}

validate_app_id "main" "$STEAM_APP_ID"
validate_depot_id "macOS" "$STEAM_DEPOT_MACOS"

if [[ ! -d "$STEAM_SDK_ROOT" ]]; then
	echo "error: STEAM_SDK_ROOT does not exist: $STEAM_SDK_ROOT" >&2
	echo "       Install the Steamworks SDK there, or set STEAM_SDK_ROOT." >&2
	exit 1
fi

case "$(uname)" in
	Darwin)
		_osx_cb="$STEAM_SDK_ROOT/tools/ContentBuilder/builder_osx"
		# Newer Content Builder ships steamcmd beside steamcmd.sh; the .sh
		# wrapper may still expect Steam.AppBundle. Prefer the direct binary.
		if [[ -f "$_osx_cb/steamcmd" ]]; then
			[[ -x "$_osx_cb/steamcmd" ]] || chmod u+x "$_osx_cb/steamcmd"
			STEAMCMD="$_osx_cb/steamcmd"
		else
			STEAMCMD="$_osx_cb/steamcmd.sh"
		fi
		unset _osx_cb
		;;
	Linux)  STEAMCMD="$STEAM_SDK_ROOT/tools/ContentBuilder/builder_linux/steamcmd.sh" ;;
	*) echo "error: unsupported host OS: $(uname)" >&2; exit 1 ;;
esac
if [[ ! -x "$STEAMCMD" ]]; then
	echo "error: steamcmd not found or not executable: $STEAMCMD" >&2
	exit 1
fi

# Valve's builder_osx/steamcmd.sh execs Steam.AppBundle/.../steamcmd. A partial
# SDK copy fails at runtime with "No such file or directory" from the wrapper.
if [[ "$(uname)" == "Darwin" && "$STEAMCMD" == *.sh ]]; then
	_steamcmd_embedded="$(dirname "$STEAMCMD")/Steam.AppBundle/Steam/Contents/MacOS/steamcmd"
	if [[ ! -x "$_steamcmd_embedded" ]]; then
		echo "error: Content Builder steamcmd binary missing: $_steamcmd_embedded" >&2
		echo "       Re-download the Steamworks SDK from the partner site and ensure" >&2
		echo "       tools/ContentBuilder/builder_osx/Steam.AppBundle is fully present," >&2
		echo "       or use a layout that includes builder_osx/steamcmd (executable)." >&2
		exit 1
	fi
	unset _steamcmd_embedded
fi

# ─────────────────────────── Staging tree ───────────────────────────
STAGING="$REPO_ROOT/build-staging"
CONTENT="$STAGING/content"
OUTPUT="$STAGING/output"
SCRIPTS="$STAGING/scripts"
DOWNLOADS="$STAGING/dl"

rm -rf "$STAGING"
mkdir -p "$CONTENT/macos" "$OUTPUT" "$SCRIPTS" "$DOWNLOADS"

# ─────────────────────────── Stage content ───────────────────────────
stage_local () {
	local app="$REPO_ROOT/dist/Vizza.app"
	if [[ ! -d "$app" && -d "$REPO_ROOT/Vizza.app" ]]; then
		app="$REPO_ROOT/Vizza.app"
	fi
	if [[ ! -d "$app" ]]; then
		echo "error: --local expects Vizza.app at dist/Vizza.app." >&2
		echo "       Run: SKIP_SIGN=1 SKIP_NOTARIZE=1 scripts/package_macos.sh --steam" >&2
		exit 1
	fi
	cp -R "$app" "$CONTENT/macos/"
	echo "staged: macos/Vizza.app (from $app)"
}

stage_release () {
	if ! command -v gh >/dev/null 2>&1; then
		echo "error: gh CLI is required to download release artifacts." >&2
		exit 1
	fi

	echo "Downloading $TAG release artifact..."
	if ! gh release download "$TAG" \
		--pattern "vizza-${TAG}-macos.zip" \
		--dir "$DOWNLOADS"
	then
		gh release download "$TAG" \
			--pattern "vizza-${VERSION}-macos.zip" \
			--dir "$DOWNLOADS"
	fi

	local archive
	archive="$(find "$DOWNLOADS" -maxdepth 1 -type f -name 'vizza-*-macos.zip' | head -1)"
	if [[ -z "$archive" ]]; then
		echo "error: no vizza-*-macos.zip artifact downloaded for $TAG" >&2
		exit 1
	fi

	unzip -q "$archive" -d "$CONTENT/macos/"
	if [[ ! -d "$CONTENT/macos/Vizza.app" ]]; then
		echo "error: release artifact did not contain Vizza.app at archive root: $archive" >&2
		exit 1
	fi
	echo "staged: macos/Vizza.app (from $(basename "$archive"))"
}

if [[ $LOCAL -eq 1 ]]; then
	stage_local
else
	stage_release
fi

# ─────────────────────────── Render VDFs ───────────────────────────
render_target_vdfs () {
	local target_label="$1"
	local app_id="$2"
	local depot_macos="$3"
	local setlive="$4"
	local desc="$5"
	local target_scripts="$SCRIPTS/$target_label"
	local target_output="$OUTPUT/$target_label"

	mkdir -p "$target_scripts" "$target_output"

	render_one () {
		local src="$1"
		local dst="$2"
		sed \
			-e "s|__APPID__|${app_id}|g" \
			-e "s|__DESC__|${desc}|g" \
			-e "s|__PREVIEW__|${PREVIEW}|g" \
			-e "s|__SETLIVE__|${setlive}|g" \
			-e "s|__CONTENT_ROOT__|${CONTENT}|g" \
			-e "s|__BUILD_OUTPUT__|${target_output}|g" \
			-e "s|__DEPOT_MACOS__|${depot_macos}|g" \
			"$src" > "$dst"
	}

	render_one "packaging/steam/app_build.vdf.template"         "$target_scripts/app_build.vdf"
	render_one "packaging/steam/depot_build_macos.vdf.template" "$target_scripts/depot_build_macos.vdf"

	echo "Rendered $target_label VDFs (AppID $app_id, setlive=${setlive:-<none>}) in $target_scripts"
}

render_target_vdfs "main" \
	"$STEAM_APP_ID" \
	"$STEAM_DEPOT_MACOS" \
	"$BRANCH" \
	"Vizza ${TAG}"

# ─────────────────────────── steamcmd ───────────────────────────
LOGIN_ARGS=()
PIPE_PASSWORD=0
if [[ $SKIP_LOGIN -eq 0 ]]; then
	: "${STEAM_BUILD_USER:?STEAM_BUILD_USER is required (or pass --skip-login)}"
	LOGIN_ARGS=(+login "$STEAM_BUILD_USER")
	# If a password is in the environment, feed it on stdin rather than as a
	# command-line arg. argv is visible to other processes via ps.
	if [[ -n "${STEAM_BUILD_PASSWORD:-}" ]]; then
		PIPE_PASSWORD=1
	fi
fi

STEAMCMD_ARGS=(
	+run_app_build "$SCRIPTS/main/app_build.vdf"
	+quit
)

echo
if [[ $PREVIEW -eq 1 ]]; then
	echo "── PREVIEW BUILD (no upload) ──"
else
	echo "── REAL BUILD ──"
	echo "  main:     AppID $STEAM_APP_ID → branch ${BRANCH:-<none — promote in partner UI>}"
fi
echo "  macOS depot: $STEAM_DEPOT_MACOS"
echo "  staging:     $STAGING"
echo "  steamcmd:    $STEAMCMD"
echo

if [[ $PIPE_PASSWORD -eq 1 ]]; then
	printf '%s\n' "$STEAM_BUILD_PASSWORD" | "$STEAMCMD" \
		"${LOGIN_ARGS[@]}" \
		"${STEAMCMD_ARGS[@]}"
else
	"$STEAMCMD" \
		"${LOGIN_ARGS[@]}" \
		"${STEAMCMD_ARGS[@]}"
fi

echo
echo "Done. Logs in: $OUTPUT"
if [[ $PREVIEW -eq 0 ]]; then
	echo "View builds:"
	echo "  main: https://partner.steamgames.com/apps/builds/${STEAM_APP_ID}"
fi
