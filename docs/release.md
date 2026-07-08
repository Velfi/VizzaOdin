# Release Pipeline

VizzaOdin releases are currently macOS-only.

Use `scripts/release.sh` to cut releases from `main`:

```sh
scripts/release.sh 0.1.0
scripts/release.sh 0.2.0-0
```

The script mirrors the Mahjuro release flow. It verifies that `main` is clean
and up to date, checks that `v<version>` does not already exist, compiles
`.changes/*.md` into `CHANGELOG.md` for stable releases, updates
`packages/engine/version.odin`, commits `Release v<version>`, creates an
annotated tag, then asks before pushing the commit and tag.

Pre-releases, such as `0.2.0-0`, skip changelog compilation so fragments can
accumulate until the stable release.

Pushing a tag that starts with `v` runs `.github/workflows/release.yml`. That
workflow calls the reusable macOS package workflow, uploads the signed and
notarized `Vizza.app` zip, then creates a GitHub Release.

## Required GitHub Secrets

Configure these repository secrets before running the release workflow:

- `APPLE_CERTIFICATE`: base64-encoded Developer ID Application `.p12`
- `APPLE_CERTIFICATE_PASSWORD`: password for the `.p12`
- `APPLE_ID`: Apple ID used for notarization
- `APPLE_TEAM_ID`: Apple Developer Team ID
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for notarization

The repository also needs GitHub Actions workflow permissions that allow
`contents: write`, because the release workflow creates GitHub Releases.

## Changelog Fragments

Add one `.changes/*.md` fragment for each user-visible change:

```md
---
category: fixed
---
Fixed the macOS package launcher environment.
```

Supported categories are `added`, `changed`, `fixed`, and `removed`.

For stable releases, add fragments during normal development, then run the
release script:

```sh
scripts/release.sh 0.1.0
```

For pre-releases, use a semver pre-release suffix:

```sh
scripts/release.sh 0.2.0-0
```

Pre-release GitHub notes use a compare link. Stable release notes come from
`CHANGELOG.md`; if the matching section is missing, the workflow falls back to
GitHub's generated release notes.

If you need to rebuild a release from the current `HEAD` without creating a new
version, update `packages/engine/version.odin` if needed, then run:

```sh
scripts/retag-head.sh
```

That helper moves `v<APP_VERSION>` to `HEAD` and force-pushes only that tag.
Use it only when intentionally replacing a release tag.

## SteamPipe Uploads

The Steam upload script mirrors the Mahjuro workflow: it stages the macOS app,
renders SteamPipe VDF files from `packaging/steam/*.template`, then runs the
Steamworks SDK `steamcmd` Content Builder. See
[`docs/steam-uploads.md`](steam-uploads.md) for the full setup and upload flow.

The checked-in Steam targets are:

- App ID: `4945920`
- macOS depot: `4945922`

Install the Steamworks SDK at `~/steam_sdk`, or set `STEAM_SDK_ROOT` or
`STEAM_SDK_LOCATION` to the SDK root.

For a local preview build:

```sh
SKIP_SIGN=1 SKIP_NOTARIZE=1 scripts/package_macos.sh --steam
STEAM_BUILD_USER=vizza_ci scripts/steam-upload.sh --preview --local 0.1.0
```

For a preview from the GitHub Release artifact for tag `v0.1.0`:

```sh
STEAM_BUILD_USER=vizza_ci scripts/steam-upload.sh --preview 0.1.0
```

For a real upload and promotion to a beta branch:

```sh
STEAM_BUILD_USER=vizza_ci scripts/steam-upload.sh --beta 0.1.0
```

`--beta` promotes to the Steam branch named `beta`; override that with
`STEAM_BETA_BRANCH=...` if the partner-site branch has a different name. Omit
`--beta` and `--branch` to upload the build without setting it live; promote it
later in the Steamworks partner UI. Use `STEAM_BUILD_PASSWORD` only in private
CI or a secure local shell; otherwise let `steamcmd` prompt interactively.
