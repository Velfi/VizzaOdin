#!/usr/bin/env bash
#
# Tag and start a VizzaOdin release.
#
# Usage:
#   scripts/release.sh <version>
#
# Example:
#   scripts/release.sh 0.2.0
#   scripts/release.sh 0.3.0-0
#
# This will:
#   1. Verify the working tree is clean and on main.
#   2. For stable releases only: compile .changes/*.md into CHANGELOG.md
#      (pre-releases skip this; fragments accumulate until the stable release).
#   3. Update the runtime version constants in packages/engine/version.odin.
#   4. Commit the version bump and changelog changes.
#   5. Create an annotated v<version> tag.
#   6. Push the commit and tag to origin, which triggers .github/workflows/release.yml.

set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "usage: $0 <version>   (e.g. $0 0.2.0)" >&2
	exit 1
fi

VERSION="$1"
TAG="v${VERSION}"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
	echo "error: '$VERSION' is not a valid semver version (expected MAJOR.MINOR.PATCH[-pre])" >&2
	exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
	echo "error: must be on 'main' branch (currently on '$BRANCH')" >&2
	exit 1
fi

if ! git diff-index --quiet HEAD --; then
	echo "error: working tree has uncommitted changes" >&2
	git status --short >&2
	exit 1
fi

if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
	echo "error: tag ${TAG} already exists locally" >&2
	exit 1
fi
git fetch --tags origin >/dev/null
if git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null 2>&1; then
	echo "error: tag ${TAG} already exists on origin" >&2
	exit 1
fi

git fetch origin main >/dev/null
LOCAL="$(git rev-parse @)"
REMOTE="$(git rev-parse @{u})"
if [[ "$LOCAL" != "$REMOTE" ]]; then
	echo "error: local main is not in sync with origin/main" >&2
	echo "  local:  $LOCAL" >&2
	echo "  remote: $REMOTE" >&2
	exit 1
fi

IS_PRERELEASE=false
if [[ "$VERSION" == *-* ]]; then
	IS_PRERELEASE=true
fi

if [[ "$IS_PRERELEASE" == true ]]; then
	echo "Pre-release: skipping changelog compile (.changes/ kept for stable release)"
else
	python3 scripts/compile_changelog.py "$VERSION"
fi

VERSION_CORE="${VERSION%%-*}"
IFS=. read -r VERSION_MAJOR VERSION_MINOR VERSION_PATCH <<< "$VERSION_CORE"

python3 - "$VERSION" "$VERSION_MAJOR" "$VERSION_MINOR" "$VERSION_PATCH" <<'PY'
import pathlib
import sys

version, major, minor, patch = sys.argv[1:5]
path = pathlib.Path("packages/engine/version.odin")
text = (
    "package engine\n\n"
    f'APP_VERSION :: "{version}"\n'
    f"APP_VERSION_MAJOR :: u32({major})\n"
    f"APP_VERSION_MINOR :: u32({minor})\n"
    f"APP_VERSION_PATCH :: u32({patch})\n"
)
path.write_text(text, encoding="utf-8")
PY

git add packages/engine/version.odin
if [[ "$IS_PRERELEASE" != true ]]; then
	git add CHANGELOG.md
	git add -u .changes
fi

if git diff --cached --quiet; then
	echo "error: release produced no staged changes; is ${VERSION} already current?" >&2
	exit 1
fi

git commit -m "Release ${TAG}"
git tag -a "${TAG}" -m "Release ${TAG}"

echo
echo "About to push the following to origin:"
echo "  - commit: $(git rev-parse --short HEAD)  Release ${TAG}"
echo "  - tag:    ${TAG}"
echo
read -r -p "Push now? [y/N] " reply
case "$reply" in
	[yY]|[yY][eE][sS])
		git push origin main
		git push origin "${TAG}"
		echo
		echo "Pushed. The release workflow should now be running:"
		echo "  https://github.com/Velfi/VizzaOdin/actions/workflows/release.yml"
		;;
	*)
		echo "Skipped push. To finish the release later, run:"
		echo "  git push origin main && git push origin ${TAG}"
		echo "To undo locally, delete ${TAG} and then revert or reset the release commit."
		;;
esac
