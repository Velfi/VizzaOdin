#!/usr/bin/env bash
#
# Move the release tag v<APP_VERSION> to the current HEAD and force-push only
# that tag to origin.
#
# Usage:
#   scripts/retag-head.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

VERSION="$(awk -F '"' '/^APP_VERSION ::/ {print $2; exit}' packages/app/version.odin)"
if [[ -z "${VERSION}" ]]; then
	echo "error: could not read APP_VERSION from packages/app/version.odin" >&2
	exit 1
fi
TAG="v${VERSION}"

if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
	git tag -d "${TAG}"
else
	echo "note: no local tag ${TAG} (creating fresh at HEAD)"
fi

git tag "${TAG}"
echo "Tagged ${TAG} at $(git rev-parse --short HEAD)"

git push origin "${TAG}" --force
