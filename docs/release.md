# Release Pipeline

VizzaOdin releases are currently macOS-only.

Pushing a tag that starts with `v` runs `.github/workflows/release.yml`. That
workflow calls the reusable macOS package workflow, uploads the signed and
notarized `VizzaOdin.app` zip, then creates a GitHub Release.

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

For stable releases, compile fragments before tagging:

```sh
python3 scripts/compile_changelog.py 0.1.0
git add CHANGELOG.md .changes
git commit -m "Release v0.1.0"
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin main
git push origin v0.1.0
```

For pre-releases, skip changelog compilation and tag the current commit:

```sh
git tag -a v0.2.0-0 -m "Release v0.2.0-0"
git push origin v0.2.0-0
```

Pre-release GitHub notes use a compare link. Stable release notes come from
`CHANGELOG.md`; if the matching section is missing, the workflow falls back to
GitHub's generated release notes.

