# Steam Build Uploads

Vizza publishes the macOS app bundle to Steam AppID `4945920` using
`steamcmd` and the VDF scripts in [`packaging/steam/`](../packaging/steam/).
The driver is [`scripts/steam-upload.sh`](../scripts/steam-upload.sh).

## One-Time Setup

### 1. Install the Steamworks SDK

The SDK is large and Valve restricts redistribution, so it is not checked in.
Install it at `~/steam_sdk`, or set `STEAM_SDK_ROOT` or
`STEAM_SDK_LOCATION` to the SDK root.

The uploader expects the Content Builder tools under:

```text
~/steam_sdk/tools/ContentBuilder/
```

### 2. Verify Steamworks Depots And Packages

The checked-in defaults are:

| Platform | Depot ID  | Env override        |
| -------- | --------- | ------------------- |
| macOS    | `4945922` | `STEAM_DEPOT_MACOS` |

In Steamworks for app `4945920`:

1. Open **SteamPipe -> Depots** and confirm depot `4945922` exists.
2. Name it something like `Vizza macOS`.
3. Set **Operating System** to **macOS**.
4. Leave **For DLC** as **Base App**.
5. Save changes.
6. Add depot `4945922` to every package that should install the game, at
   minimum the store/release package and your developer comp package.

After step 6, the depot should no longer show the warning that it is not
referenced by any packages.

### 3. Build Account And Steam Guard

Create or use a dedicated Steam account with publish-build permissions for
Vizza. Bootstrap Steam Guard once on the machine that will upload:

```sh
export STEAM_SDK_ROOT="${STEAM_SDK_ROOT:-$HOME/steam_sdk}"
cd "$STEAM_SDK_ROOT/tools/ContentBuilder/builder_osx"
./steamcmd.sh +login <build_account>
# enter password
# enter Steam Guard code
# wait for "Logged in OK"
quit
```

The cached sentry token is stored by Steam under the local user profile. Future
uploads can reuse it.

## Uploading

Always preview first when changing VDFs or staging logic:

```sh
export STEAM_BUILD_USER=vizza_ci
scripts/steam-upload.sh --preview 0.1.0
```

A preview validates the depot layout and writes logs to `build-staging/output/`
without uploading.

For a real upload from the GitHub Release artifact for tag `v0.1.0`:

```sh
export STEAM_BUILD_USER=vizza_ci
scripts/steam-upload.sh --beta 0.1.0
```

This downloads `vizza-v0.1.0-macos.zip`, stages `Vizza.app` under
`build-staging/content/macos/`, renders the VDFs, and runs
`steamcmd +run_app_build`.

`--beta` promotes the build to the branch named `beta`. If the branch has a
different name in Steamworks, set `STEAM_BETA_BRANCH=...`.

Create the branch from the app's **Builds** page in Steamworks before the first
upload that tries to set it live.

Use `--branch NAME` for a custom branch. Omit `--beta` and `--branch` to upload
without promoting. Promote later at:

```text
https://partner.steamgames.com/apps/builds/4945920
```

To stage a local package instead:

```sh
SKIP_SIGN=1 SKIP_NOTARIZE=1 scripts/package_macos.sh --steam
scripts/steam-upload.sh --local --preview 0.1.0
```

## Troubleshooting

- `Login Failure: Invalid Login Auth Code`: Steam Guard token expired or was
  rotated. Re-run the bootstrap login and enter the new code.
- `ERROR! Failed to get application info`: the build account is missing
  publish-build permissions for AppID `4945920`.
- `ERROR! Depot N not found in app M`: depot ID mismatch. Verify Steamworks
  depots and override `STEAM_DEPOT_MACOS` if needed.
- `ERROR! Failed to commit build for AppID 4945920 : Failure`: SteamPipe
  built the depot manifest but did not create an app build. Steam can then show
  the app as installed with `0 mounted depots` and fail to launch with missing
  `Vizza.app`. Check that the target branch exists before using `--beta` or
  `--branch`, that depot `4945922` is attached to the app's packages, and that
  the build account has permission to set builds live. You can omit `--beta`
  to upload a build without promoting it, then promote it manually in
  Steamworks after verifying the build.
- Depot says it is not referenced by any packages: add depot `4945922` to the
  store/release package and developer comp package, then save and publish the
  Steamworks change.
- Steam installs the new BuildID but still reports missing `Vizza.app`, while
  `content_log.txt` says `0 mounted depots` or `0 active: 0 target`: the build
  is live, but the installing account's license/package does not include depot
  `4945922`. Add depot `4945922` to the developer comp package used by your
  account and to the release/store packages, save, and publish the Steamworks
  package changes. Then uninstall/reinstall or verify files in Steam.
- macOS crash report says `Namespace DYLD, Code 1, Library missing` and names
  a `/opt/homebrew/.../*.dylib`: the app was built with a Homebrew dependency
  still linked outside the bundle. Rebuild with the current
  `scripts/package_macos.sh`; it copies non-system dylibs into
  `Contents/Frameworks` and rewrites the install names before signing.
