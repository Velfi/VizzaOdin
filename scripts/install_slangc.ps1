[CmdletBinding()]
param(
	[string]$ReleaseTag = $env:SLANG_RELEASE_TAG,
	[int]$ReleaseScanLimit = $(if ($env:SLANG_RELEASE_SCAN_LIMIT) { [int]$env:SLANG_RELEASE_SCAN_LIMIT } else { 20 }),
	[string]$InstallDir = $env:SLANG_INSTALL_DIR
)

$ErrorActionPreference = "Stop"

$Repo = "shader-slang/slang"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
if (-not $InstallDir) {
	$InstallDir = Join-Path $RepoRoot ".tools/slang"
}

function Get-GitHubHeaders {
	$headers = @{
		"Accept" = "application/vnd.github+json"
		"X-GitHub-Api-Version" = "2022-11-28"
	}
	$token = $env:GITHUB_TOKEN
	if (-not $token) {
		$token = $env:GH_TOKEN
	}
	if ($token) {
		$headers["Authorization"] = "Bearer $token"
	}
	return $headers
}

function Get-ArchitecturePattern {
	$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
	switch ($arch) {
		"X64" { return "x86_64|amd64|x64" }
		"Arm64" { return "aarch64|arm64" }
		default {
			throw "unsupported architecture '$arch'; download slangc manually from https://github.com/$Repo/releases"
		}
	}
}

$headers = Get-GitHubHeaders
$archPattern = Get-ArchitecturePattern

if ($ReleaseTag) {
	$apiUrl = "https://api.github.com/repos/$Repo/releases/tags/$ReleaseTag"
	Write-Host "Fetching Slang release metadata for $ReleaseTag..."
} else {
	$apiUrl = "https://api.github.com/repos/$Repo/releases?per_page=$ReleaseScanLimit"
	Write-Host "Fetching recent Slang release metadata..."
}

try {
	$metadata = Invoke-RestMethod -Uri $apiUrl -Headers $headers
} catch {
	if (-not $env:GITHUB_TOKEN -and -not $env:GH_TOKEN) {
		Write-Error "failed to fetch Slang release metadata from $apiUrl. Set GITHUB_TOKEN or GH_TOKEN to avoid unauthenticated GitHub API rate limits."
	}
	throw
}

$assets = @()
if ($metadata -is [array]) {
	foreach ($release in $metadata) {
		$assets += @($release.assets)
	}
} else {
	$assets += @($metadata.assets)
}

$asset = $null
foreach ($candidate in $assets) {
	$name = [string]$candidate.name
	$lower = $name.ToLowerInvariant()
	if ($lower -match "debug-info|source") {
		continue
	}
	if ($lower -match "windows|win" -and $lower -match $archPattern -and $lower -match "\.zip$") {
		$asset = $candidate
		break
	}
}

if (-not $asset) {
	if ($ReleaseTag) {
		throw "could not find a Slang release asset for Windows/$archPattern in release $ReleaseTag"
	}
	throw "could not find a Slang release asset for Windows/$archPattern in the $ReleaseScanLimit most recent releases"
}

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vizzaodin-slang-" + [System.Guid]::NewGuid().ToString("N"))
$extractDir = Join-Path $tmpDir "extract"
$archive = Join-Path $tmpDir ([string]$asset.name)

New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

try {
	Write-Host "Downloading $($asset.name)..."
	Invoke-WebRequest -Uri $asset.browser_download_url -Headers $headers -OutFile $archive
	Expand-Archive -LiteralPath $archive -DestinationPath $extractDir -Force

	$slangc = Get-ChildItem -Path $extractDir -Recurse -File -Filter "slangc.exe" | Select-Object -First 1
	if (-not $slangc) {
		throw "downloaded archive did not contain slangc.exe"
	}

	$slangcDir = Split-Path -Parent $slangc.FullName
	if ((Split-Path -Leaf $slangcDir).ToLowerInvariant() -eq "bin") {
		$packageRoot = Split-Path -Parent $slangcDir
	} else {
		$packageRoot = $slangcDir
	}

	if (Test-Path $InstallDir) {
		Remove-Item -Recurse -Force $InstallDir
	}
	New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
	Copy-Item -Path (Join-Path $packageRoot "*") -Destination $InstallDir -Recurse -Force

	$binDir = Join-Path $InstallDir "bin"
	New-Item -ItemType Directory -Force -Path $binDir | Out-Null

	$installedSlangc = Get-ChildItem -Path $InstallDir -Recurse -File -Filter "slangc.exe" | Select-Object -First 1
	if (-not $installedSlangc) {
		throw "install copy did not contain slangc.exe"
	}

	$binSlangc = Join-Path $binDir "slangc.exe"
	if ($installedSlangc.FullName -ne $binSlangc) {
		Copy-Item -Path $installedSlangc.FullName -Destination $binSlangc -Force
	}

	$wrapper = Join-Path $binDir "slangc"
	$wrapperText = @'
#!/usr/bin/env sh
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "${SCRIPT_DIR}/slangc.exe" "$@"
'@
	[System.IO.File]::WriteAllText($wrapper, $wrapperText.Replace("`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))
	$bash = Get-Command bash -ErrorAction SilentlyContinue
	if ($bash) {
		$wrapperForBash = $wrapper.Replace("\", "/")
		& $bash.Source -lc "chmod +x '$wrapperForBash'"
	}

	Write-Host ""
	Write-Host "Installed slangc to $binSlangc"
	& $binSlangc -version
	Write-Host ""
	Write-Host "For this repo, use $binSlangc or add $binDir to PATH."
} finally {
	if (Test-Path $tmpDir) {
		Remove-Item -Recurse -Force $tmpDir
	}
}
