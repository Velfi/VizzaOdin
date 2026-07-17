#!/usr/bin/env bash
#
# Stage Vizza release artifacts and upload them to Steam via steamcmd.
#
# Usage:
#   scripts/steam-upload.sh [flags] <version>
#
# Flags:
#   --local        Stage from local dist/Vizza.app and dist/Vizza-windows/
#                  (or its ZIP) instead of downloading the GitHub release.
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
#   STEAM_PLAYTEST_BRANCH Branch to set live on the Playtest app. Default:
#                         empty (upload without promoting).
#   packaging/steam/targets.env — default AppID / depot IDs.

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
		-h|--help)     sed -n '3,38p' "$0"; exit 0 ;;
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
STEAM_DEPOT_WINDOWS="${STEAM_DEPOT_WINDOWS:-4945921}"
STEAM_DEPOT_MACOS="${STEAM_DEPOT_MACOS:-4945922}"
STEAM_PLAYTEST_APP_ID="${STEAM_PLAYTEST_APP_ID:-4946320}"
STEAM_PLAYTEST_DEPOT="${STEAM_PLAYTEST_DEPOT:-4946321}"
STEAM_PLAYTEST_BRANCH="${STEAM_PLAYTEST_BRANCH:-}"

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
validate_depot_id "Windows" "$STEAM_DEPOT_WINDOWS"
validate_depot_id "macOS" "$STEAM_DEPOT_MACOS"
validate_app_id "Playtest" "$STEAM_PLAYTEST_APP_ID"
validate_depot_id "Playtest" "$STEAM_PLAYTEST_DEPOT"

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
	MINGW*|MSYS*|CYGWIN*) STEAMCMD="$STEAM_SDK_ROOT/tools/ContentBuilder/builder/steamcmd.exe" ;;
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
mkdir -p "$CONTENT/macos" "$CONTENT/windows" "$OUTPUT" "$SCRIPTS" "$DOWNLOADS"

stage_windows_archive () {
	local archive="$1"
	local unpack="$DOWNLOADS/windows-unpacked"
	rm -rf "$unpack"
	mkdir -p "$unpack"
	unzip -q "$archive" -d "$unpack"
	if [[ -f "$unpack/Vizza-windows/Vizza.exe" ]]; then
		cp -R "$unpack/Vizza-windows/." "$CONTENT/windows/"
	elif [[ -f "$unpack/Vizza.exe" ]]; then
		cp -R "$unpack/." "$CONTENT/windows/"
	else
		echo "error: Windows artifact does not contain Vizza.exe: $archive" >&2
		exit 1
	fi
}

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

	local windows_dir="$REPO_ROOT/dist/Vizza-windows"
	local windows_zip="$REPO_ROOT/dist/Vizza-windows.zip"
	if [[ -f "$windows_dir/Vizza.exe" ]]; then
		cp -R "$windows_dir/." "$CONTENT/windows/"
		echo "staged: windows/Vizza.exe (from $windows_dir)"
	elif [[ -f "$windows_zip" ]]; then
		stage_windows_archive "$windows_zip"
		echo "staged: windows/Vizza.exe (from $windows_zip)"
	else
		echo "error: --local expects dist/Vizza-windows/Vizza.exe or dist/Vizza-windows.zip." >&2
		exit 1
	fi
}

stage_release () {
	if ! command -v gh >/dev/null 2>&1; then
		echo "error: gh CLI is required to download release artifacts." >&2
		exit 1
	fi

	echo "Downloading $TAG release artifact..."
	if ! gh release download "$TAG" \
		--pattern "vizza-${TAG}-*.zip" \
		--dir "$DOWNLOADS"
	then
		gh release download "$TAG" \
			--pattern "vizza-${VERSION}-*.zip" \
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

	local windows_archive
	windows_archive="$(find "$DOWNLOADS" -maxdepth 1 -type f -name 'vizza-*-windows-x64.zip' | head -1)"
	if [[ -z "$windows_archive" ]]; then
		echo "error: no vizza-*-windows-x64.zip artifact downloaded for $TAG" >&2
		exit 1
	fi
	stage_windows_archive "$windows_archive"
	echo "staged: windows/Vizza.exe (from $(basename "$windows_archive"))"
}

if [[ $LOCAL -eq 1 ]]; then
	stage_local
else
	stage_release
fi

verify_staged_app () {
	local app="$CONTENT/macos/Vizza.app"
	local launcher="$app/Contents/MacOS/Vizza"
	local binary="$app/Contents/MacOS/vizzaodin"
	local file_count

	if [[ ! -d "$app" ]]; then
		echo "error: staged Steam content is missing Vizza.app at $app" >&2
		exit 1
	fi
	if [[ ! -x "$launcher" ]]; then
		echo "error: staged Steam app is missing executable launcher: $launcher" >&2
		exit 1
	fi
	if [[ ! -x "$binary" ]]; then
		echo "error: staged Steam app is missing game binary: $binary" >&2
		exit 1
	fi

	file_count="$(find "$app" -type f | wc -l | tr -d '[:space:]')"
	if [[ "$file_count" -lt 10 ]]; then
		echo "error: staged Steam app looks incomplete: $app has only $file_count files" >&2
		exit 1
	fi

	if command -v otool >/dev/null 2>&1; then
		local bad_dylib_ref=0
		local macho
		local ref
		while IFS= read -r -d '' macho; do
			while IFS= read -r ref; do
				[[ -n "$ref" ]] || continue
				case "$ref" in
					/usr/lib/*|/System/Library/*)
						;;
					@rpath/*)
						local rel="${ref#@rpath/}"
						if [[ ! -f "$app/Contents/Frameworks/$rel" && ! -f "$app/Contents/Frameworks/$(basename "$rel")" ]]; then
							echo "error: unresolved @rpath dylib reference in staged app: $macho -> $ref" >&2
							bad_dylib_ref=1
						fi
						;;
					@loader_path/*)
						local rel="${ref#@loader_path/}"
						if [[ ! -f "$(dirname "$macho")/$rel" ]]; then
							echo "error: unresolved @loader_path dylib reference in staged app: $macho -> $ref" >&2
							bad_dylib_ref=1
						fi
						;;
					@executable_path/*)
						local rel="${ref#@executable_path/}"
						if [[ ! -f "$app/Contents/MacOS/$rel" ]]; then
							echo "error: unresolved @executable_path dylib reference in staged app: $macho -> $ref" >&2
							bad_dylib_ref=1
						fi
						;;
					/*)
						echo "error: staged app references external dylib: $macho -> $ref" >&2
						echo "       Rebuild the macOS package so Homebrew dylibs are bundled in Contents/Frameworks." >&2
						bad_dylib_ref=1
						;;
				esac
			done < <(otool -L "$macho" 2>/dev/null | awk 'NR > 1 && $0 !~ /:$/ {print $1}')
		done < <(find "$app/Contents/MacOS" "$app/Contents/Frameworks" -type f \( -perm -111 -o -name '*.dylib' \) -print0)
		if ! otool -l "$binary" | awk '$1 == "path" && $2 == "@executable_path/../Frameworks" { found = 1 } END { exit(found ? 0 : 1) }'; then
			echo "error: staged app binary is missing LC_RPATH @executable_path/../Frameworks: $binary" >&2
			bad_dylib_ref=1
		fi
		if [[ "$bad_dylib_ref" -ne 0 ]]; then
			exit 1
		fi
	else
		echo "warning: otool not found; skipping staged app dylib validation" >&2
	fi

	echo "Verified staged Steam app: macos/Vizza.app ($file_count files)"
}

verify_staged_app

verify_staged_windows () {
	local exe="$CONTENT/windows/Vizza.exe"
	local file_count
	if [[ ! -f "$exe" ]]; then
		echo "error: staged Windows content is missing Vizza.exe at $exe" >&2
		exit 1
	fi
	file_count="$(find "$CONTENT/windows" -type f | wc -l | tr -d '[:space:]')"
	if [[ "$file_count" -lt 10 ]]; then
		echo "error: staged Windows build looks incomplete: $CONTENT/windows has only $file_count files" >&2
		exit 1
	fi
	echo "Verified staged Steam build: windows/Vizza.exe ($file_count files)"
}

verify_staged_windows

# ─────────────────────────── Render VDFs ───────────────────────────
render_target_vdfs () {
	local target_label="$1"
	local app_id="$2"
	local depot_windows="$3"
	local depot_macos="$4"
	local setlive="$5"
	local desc="$6"
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
			-e "s|__DEPOT_WINDOWS__|${depot_windows}|g" \
			-e "s|__DEPOT_MACOS__|${depot_macos}|g" \
			"$src" > "$dst"
	}

	render_one "packaging/steam/app_build.vdf.template"         "$target_scripts/app_build.vdf"
	render_one "packaging/steam/depot_build_windows.vdf.template" "$target_scripts/depot_build_windows.vdf"
	render_one "packaging/steam/depot_build_macos.vdf.template" "$target_scripts/depot_build_macos.vdf"

	echo "Rendered $target_label VDFs (AppID $app_id, setlive=${setlive:-<none>}) in $target_scripts"
}

render_target_vdfs "main" \
	"$STEAM_APP_ID" \
	"$STEAM_DEPOT_WINDOWS" \
	"$STEAM_DEPOT_MACOS" \
	"$BRANCH" \
	"Vizza ${TAG}"

render_playtest_vdfs () {
	local target_scripts="$SCRIPTS/playtest"
	local target_output="$OUTPUT/playtest"

	mkdir -p "$target_scripts" "$target_output"

	sed \
		-e "s|__APPID__|${STEAM_PLAYTEST_APP_ID}|g" \
		-e "s|__DESC__|Vizza Playtest ${TAG}|g" \
		-e "s|__PREVIEW__|${PREVIEW}|g" \
		-e "s|__SETLIVE__|${STEAM_PLAYTEST_BRANCH}|g" \
		-e "s|__CONTENT_ROOT__|${CONTENT}|g" \
		-e "s|__BUILD_OUTPUT__|${target_output}|g" \
		-e "s|__DEPOT_PLAYTEST__|${STEAM_PLAYTEST_DEPOT}|g" \
		"packaging/steam/app_build_playtest.vdf.template" > "$target_scripts/app_build.vdf"

	sed \
		-e "s|__DEPOT_PLAYTEST__|${STEAM_PLAYTEST_DEPOT}|g" \
		"packaging/steam/depot_build_playtest.vdf.template" > "$target_scripts/depot_build_playtest.vdf"

	echo "Rendered Playtest VDFs (AppID $STEAM_PLAYTEST_APP_ID, setlive=${STEAM_PLAYTEST_BRANCH:-<none>}) in $target_scripts"
}

render_playtest_vdfs

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
	+run_app_build "$SCRIPTS/playtest/app_build.vdf"
	+quit
)

echo
if [[ $PREVIEW -eq 1 ]]; then
	echo "── PREVIEW BUILD (no upload) ──"
else
	echo "── REAL BUILD ──"
	echo "  main:     AppID $STEAM_APP_ID → branch ${BRANCH:-<none — promote in partner UI>}"
	echo "  playtest: AppID $STEAM_PLAYTEST_APP_ID → branch ${STEAM_PLAYTEST_BRANCH:-<none — promote in partner UI>}"
fi
echo "  macOS depot: $STEAM_DEPOT_MACOS"
echo "  Windows depot: $STEAM_DEPOT_WINDOWS"
echo "  Playtest depot: $STEAM_PLAYTEST_DEPOT (Windows + macOS)"
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

validate_steam_output () {
	local target_label="$1"
	local app_id="$2"
	local target_output="$OUTPUT/$target_label"
	shift 2
	local depot_ids=("$@")
	local app_log="$target_output/app_build_${app_id}.log"
	local error_lines
	local depot_files
	local build_id
	local depot_manifest

	if [[ ! -d "$target_output" ]]; then
		echo "error: SteamPipe did not write expected output directory: $target_output" >&2
		exit 1
	fi

	local depot_id depot_label depot_log
	for depot_id in "${depot_ids[@]}"; do
		if [[ "$target_label" == "playtest" ]]; then
			depot_label="playtest"
		elif [[ "$depot_id" == "$STEAM_DEPOT_WINDOWS" ]]; then
			depot_label="windows"
		else
			depot_label="macos"
		fi
		depot_log="$target_output/depot_build_${depot_id}.log"
		if [[ -f "$depot_log" ]]; then
			depot_files="$(sed -n 's/.*Found \([0-9][0-9]*\) files (.*) for depot.*/\1/p' "$depot_log" | tail -1)"
			if [[ -n "$depot_files" && "$depot_files" -eq 0 ]]; then
				echo "error: SteamPipe found zero files for depot $depot_id." >&2
				echo "       Check ContentRoot/FileMapping in $SCRIPTS/$target_label/depot_build_${depot_label}.vdf." >&2
				exit 1
			fi
		fi
	done

	if error_lines="$(grep -R -n 'ERROR!' "$target_output" 2>/dev/null)"; then
		echo "error: SteamPipe reported errors:" >&2
		printf '%s\n' "$error_lines" >&2
		if [[ -f "$app_log" ]] && grep -q 'Failed to commit build' "$app_log"; then
			echo >&2
			echo "Steam built the depot manifest but failed to commit the app build." >&2
			echo "That leaves Steam with an installable app but no mounted depots, so it reports Vizza.app as missing." >&2
			echo "Check Steamworks: the target branch exists, depots ${depot_ids[*]} are attached to the app packages, and the build account can set builds live for AppID $app_id." >&2
		fi
		exit 1
	fi

	if [[ -f "$app_log" ]]; then
		build_id="$(sed -n 's/.*Successfully finished AppID .* build (BuildID \([0-9][0-9]*\)).*/\1/p' "$app_log" | tail -1)"
		if [[ -n "$build_id" ]]; then
			echo "Steam build created: $build_id"
		fi
	fi
	for depot_id in "${depot_ids[@]}"; do
		if [[ -f "$target_output/depot_build_${depot_id}.vdf" ]]; then
			depot_manifest="$(awk '/"manifest"/ { gsub(/"/, "", $2); print $2 }' "$target_output/depot_build_${depot_id}.vdf" | tail -1)"
			if [[ -n "$depot_manifest" ]]; then
				echo "Steam depot manifest created: $depot_id / $depot_manifest"
			fi
		fi
	done
}

validate_steam_output "main" "$STEAM_APP_ID" "$STEAM_DEPOT_WINDOWS" "$STEAM_DEPOT_MACOS"
validate_steam_output "playtest" "$STEAM_PLAYTEST_APP_ID" "$STEAM_PLAYTEST_DEPOT"

echo
echo "Done. Logs in: $OUTPUT"
if [[ $PREVIEW -eq 0 ]]; then
	echo "View builds:"
	echo "  main: https://partner.steamgames.com/apps/builds/${STEAM_APP_ID}"
	echo "  playtest: https://partner.steamgames.com/apps/builds/${STEAM_PLAYTEST_APP_ID}"
	echo
	echo "If Steam installs this build with 0 mounted depots, fix Steamworks packages:"
	echo "  add depots ${STEAM_DEPOT_WINDOWS} and ${STEAM_DEPOT_MACOS} to the developer comp and release/store packages, then publish Steamworks changes."
	echo "  add depot ${STEAM_PLAYTEST_DEPOT} to the Playtest package and developer comp package, then publish Steamworks changes."
fi
