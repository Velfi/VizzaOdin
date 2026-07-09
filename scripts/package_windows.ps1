[CmdletBinding()]
param(
	[string]$AppName = $(if ($env:APP_NAME) { $env:APP_NAME } else { "Vizza" }),
	[string]$ExecutableName = $(if ($env:EXECUTABLE_NAME) { $env:EXECUTABLE_NAME } else { "vizzaodin" }),
	[string]$Version = $env:VERSION,
	[string]$BuildDir = $env:BUILD_DIR,
	[string]$DistDir = $env:DIST_DIR,
	[string]$VcpkgRoot = $env:VCPKG_ROOT,
	[string]$VcpkgTriplet = $(if ($env:VCPKG_DEFAULT_TRIPLET) { $env:VCPKG_DEFAULT_TRIPLET } else { "x64-windows" }),
	[string]$OdinFlags = $(if ($env:ODIN_FLAGS) { $env:ODIN_FLAGS } else { "-o:none" }),
	[switch]$Msix,
	[string]$PackageIdentityName = $(if ($env:WINDOWS_PACKAGE_IDENTITY_NAME) { $env:WINDOWS_PACKAGE_IDENTITY_NAME } else { "Velfi.VizzaOdin" }),
	[string]$PackagePublisher = $(if ($env:WINDOWS_PACKAGE_PUBLISHER) { $env:WINDOWS_PACKAGE_PUBLISHER } else { "CN=VizzaOdin" }),
	[string]$PackagePublisherDisplayName = $(if ($env:WINDOWS_PACKAGE_PUBLISHER_DISPLAY_NAME) { $env:WINDOWS_PACKAGE_PUBLISHER_DISPLAY_NAME } else { "Velfi" }),
	[string]$PackageVersion = $env:WINDOWS_PACKAGE_VERSION,
	[string]$PfxPath = $env:WINDOWS_PFX_PATH,
	[string]$PfxPassword = $env:WINDOWS_PFX_PASSWORD
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Resolve-Path (Join-Path $ScriptDir "..")
if (-not $BuildDir) {
	$BuildDir = Join-Path $RootDir "build"
}
if (-not $DistDir) {
	$DistDir = Join-Path $RootDir "dist"
}
if (-not $VcpkgRoot) {
	$VcpkgRoot = "C:\vcpkg"
}

$BuildDir = [System.IO.Path]::GetFullPath($BuildDir)
$DistDir = [System.IO.Path]::GetFullPath($DistDir)
$VcpkgInstalledDir = if ($env:VCPKG_INSTALLED_DIR) { $env:VCPKG_INSTALLED_DIR } else { Join-Path $VcpkgRoot "installed\$VcpkgTriplet" }
$VcpkgIncludeDir = Join-Path $VcpkgInstalledDir "include"
$VcpkgLibDir = Join-Path $VcpkgInstalledDir "lib"
$VcpkgBinDir = Join-Path $VcpkgInstalledDir "bin"

function Require-Command {
	param([string]$Name)
	if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
		throw "Missing required tool: $Name"
	}
}

function Invoke-Tool {
	param(
		[string]$FilePath,
		[string[]]$Arguments
	)
	Write-Host "$FilePath $($Arguments -join ' ')"
	& $FilePath @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "$FilePath failed with exit code $LASTEXITCODE"
	}
}

function Read-MakeVariable {
	param(
		[string]$Name,
		[string]$Default
	)
	$makefile = Join-Path $RootDir "Makefile"
	$pattern = "^\s*$([regex]::Escape($Name))\s*(?:\?=|:=)\s*(.+?)\s*$"
	foreach ($line in Get-Content -Path $makefile) {
		if ($line -match $pattern) {
			return $matches[1]
		}
	}
	return $Default
}

function Get-AppVersion {
	$versionFile = Join-Path $RootDir "packages/engine/version.odin"
	if (Test-Path $versionFile) {
		foreach ($line in Get-Content -Path $versionFile) {
			if ($line -match '^APP_VERSION :: "([^"]+)"') {
				return $matches[1]
			}
		}
	}
	return "0.1.0"
}

function Ensure-Tomlc17 {
	$repo = Read-MakeVariable "TOMLC17_REPO" "https://github.com/cktan/tomlc17.git"
	$rev = Read-MakeVariable "TOMLC17_REV" "91ba3cc1023364f6ff59afa87e10ecac7e9a1dce"
	$root = Join-Path $RootDir "third_party/tomlc17"
	$stamp = Join-Path $root ".vizzaodin-rev"

	New-Item -ItemType Directory -Force -Path (Join-Path $RootDir "third_party") | Out-Null
	if ((Test-Path $root) -and -not (Test-Path (Join-Path $root ".git"))) {
		throw "Remove $root or turn it into a git clone before packaging."
	}
	if (-not (Test-Path (Join-Path $root ".git"))) {
		Invoke-Tool "git" @("clone", $repo, $root)
	}
	Invoke-Tool "git" @("-C", $root, "fetch", "--depth", "1", "origin", $rev)
	Invoke-Tool "git" @("-C", $root, "checkout", "--detach", $rev)
	Set-Content -Path $stamp -Value $rev -Encoding UTF8
}

function Build-Tomlc17 {
	$objDir = Join-Path $BuildDir "windows-obj"
	$src = Join-Path $RootDir "third_party/tomlc17/src/tomlc17.c"
	$obj = Join-Path $objDir "tomlc17.obj"
	$lib = Join-Path $RootDir "third_party/tomlc17/src/libtomlc17.a"

	New-Item -ItemType Directory -Force -Path $objDir | Out-Null
	Invoke-Tool "cl" @("/nologo", "/O2", "/DNDEBUG", "/std:c17", "/c", $src, "/Fo$obj")
	Invoke-Tool "lib" @("/nologo", "/OUT:$lib", $obj)
}

function Build-Textshape {
	$objDir = Join-Path $BuildDir "windows-obj"
	$src = Join-Path $RootDir "third_party/textshape/textshape.c"
	$obj = Join-Path $objDir "textshape.obj"
	$lib = Join-Path $RootDir "third_party/textshape/libtextshape.a"
	$harfbuzzInclude = Join-Path $VcpkgIncludeDir "harfbuzz"
	$freetypeInclude = Join-Path $VcpkgIncludeDir "freetype2"

	New-Item -ItemType Directory -Force -Path $objDir | Out-Null
	Invoke-Tool "cl" @(
		"/nologo",
		"/O2",
		"/DNDEBUG",
		"/std:c17",
		"/I$VcpkgIncludeDir",
		"/I$harfbuzzInclude",
		"/I$freetypeInclude",
		"/c",
		$src,
		"/Fo$obj"
	)
	Invoke-Tool "lib" @("/nologo", "/OUT:$lib", $obj)
}

function Resolve-SlangcForBash {
	$wrapper = Join-Path $RootDir ".tools/slang/bin/slangc"
	$exe = Join-Path $RootDir ".tools/slang/bin/slangc.exe"
	if (Test-Path $wrapper) {
		return ".tools/slang/bin/slangc"
	}
	if (Test-Path $exe) {
		return ".tools/slang/bin/slangc.exe"
	}
	$path = (& bash -lc "command -v slangc" | Select-Object -First 1)
	if (-not $path) {
		throw "Missing required tool: slangc"
	}
	return $path.Trim()
}

function Build-Shaders {
	$slangc = Resolve-SlangcForBash
	Invoke-Tool "bash" @("scripts/build_shaders.sh", $slangc, "assets/shaders", "build/shaders")
}

function Split-Flags {
	param([string]$Flags)
	if (-not $Flags) {
		return @()
	}
	return @($Flags -split "\s+" | Where-Object { $_ })
}

function Build-App {
	$outExe = Join-Path $BuildDir "$ExecutableName.exe"
	$linkerFlags = "/LIBPATH:`"$VcpkgLibDir`" harfbuzz.lib freetype.lib"
	$args = @("build", "src")
	$args += Split-Flags $OdinFlags
	$args += "-extra-linker-flags:$linkerFlags"
	$args += "-out:$outExe"
	Invoke-Tool "odin" $args
	return $outExe
}

function Get-DllDependencies {
	param([string]$Binary)
	$output = & dumpbin /DEPENDENTS $Binary 2>&1
	if ($LASTEXITCODE -ne 0) {
		throw "dumpbin failed for $Binary"
	}

	$deps = New-Object System.Collections.Generic.List[string]
	foreach ($line in $output) {
		if ($line -match '^\s+([A-Za-z0-9_.+-]+\.dll)\s*$') {
			$deps.Add($matches[1])
		}
	}
	return $deps
}

function Copy-VcpkgDllClosure {
	param(
		[string[]]$StartBinaries,
		[string]$PackageDir
	)

	$queue = New-Object System.Collections.Generic.Queue[string]
	$seen = @{}
	foreach ($binary in $StartBinaries) {
		$queue.Enqueue($binary)
	}

	while ($queue.Count -gt 0) {
		$binary = $queue.Dequeue()
		$key = $binary.ToLowerInvariant()
		if ($seen.ContainsKey($key)) {
			continue
		}
		$seen[$key] = $true

		foreach ($dep in Get-DllDependencies $binary) {
			$candidate = Join-Path $VcpkgBinDir $dep
			if (-not (Test-Path $candidate)) {
				continue
			}

			$target = Join-Path $PackageDir $dep
			if (-not (Test-Path $target)) {
				Copy-Item -Path $candidate -Destination $target -Force
			}
			$queue.Enqueue($target)
		}
	}
}

function Copy-OptionalVulkanLoader {
	param([string]$PackageDir)
	$vulkanLoader = Join-Path $VcpkgBinDir "vulkan-1.dll"
	if (-not (Test-Path $vulkanLoader)) {
		return @()
	}
	$target = Join-Path $PackageDir "vulkan-1.dll"
	Copy-Item -Path $vulkanLoader -Destination $target -Force
	return @($target)
}

function ConvertTo-MsixVersion {
	if ($PackageVersion) {
		if ($PackageVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$') {
			throw "WINDOWS_PACKAGE_VERSION must be four numeric parts, e.g. 1.2.3.0"
		}
		return $PackageVersion
	}

	$core = ($Version -replace '^v', '').Split('-')[0]
	$parts = $core.Split('.')
	if ($parts.Count -ne 3) {
		throw "Cannot derive MSIX package version from '$Version'"
	}
	return "$($parts[0]).$($parts[1]).$($parts[2]).0"
}

function Escape-Xml {
	param([string]$Value)
	return [System.Security.SecurityElement]::Escape($Value)
}

function New-MsixImage {
	param(
		[string]$Source,
		[string]$Destination,
		[int]$Width,
		[int]$Height
	)

	Add-Type -AssemblyName System.Drawing
	$sourceImage = [System.Drawing.Image]::FromFile($Source)
	try {
		$bitmap = New-Object System.Drawing.Bitmap -ArgumentList $Width, $Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
		try {
			$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
			try {
				$graphics.Clear([System.Drawing.Color]::Transparent)
				$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
				$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
				$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

				$scale = [Math]::Min($Width / $sourceImage.Width, $Height / $sourceImage.Height)
				$drawWidth = [int][Math]::Round($sourceImage.Width * $scale)
				$drawHeight = [int][Math]::Round($sourceImage.Height * $scale)
				$x = [int][Math]::Floor(($Width - $drawWidth) / 2)
				$y = [int][Math]::Floor(($Height - $drawHeight) / 2)
				$graphics.DrawImage($sourceImage, $x, $y, $drawWidth, $drawHeight)
			} finally {
				$graphics.Dispose()
			}
			$bitmap.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
		} finally {
			$bitmap.Dispose()
		}
	} finally {
		$sourceImage.Dispose()
	}
}

function New-MsixAssets {
	param([string]$PackageDir)

	$sourceIcon = Join-Path $RootDir "icon.png"
	if (-not (Test-Path $sourceIcon)) {
		throw "Missing icon source for MSIX package: $sourceIcon"
	}

	$assetDir = Join-Path $PackageDir "msix-assets"
	New-Item -ItemType Directory -Force -Path $assetDir | Out-Null
	New-MsixImage $sourceIcon (Join-Path $assetDir "StoreLogo.png") 50 50
	New-MsixImage $sourceIcon (Join-Path $assetDir "Square44x44Logo.png") 44 44
	New-MsixImage $sourceIcon (Join-Path $assetDir "Square71x71Logo.png") 71 71
	New-MsixImage $sourceIcon (Join-Path $assetDir "Square150x150Logo.png") 150 150
	New-MsixImage $sourceIcon (Join-Path $assetDir "Square310x310Logo.png") 310 310
	New-MsixImage $sourceIcon (Join-Path $assetDir "Wide310x150Logo.png") 310 150
	New-MsixImage $sourceIcon (Join-Path $assetDir "SplashScreen.png") 620 300
}

function Write-MsixManifest {
	param([string]$PackageDir)

	$msixVersion = ConvertTo-MsixVersion
	$manifestPath = Join-Path $PackageDir "AppxManifest.xml"
	$identityName = Escape-Xml $PackageIdentityName
	$publisher = Escape-Xml $PackagePublisher
	$displayName = Escape-Xml $AppName
	$publisherDisplayName = Escape-Xml $PackagePublisherDisplayName

	$manifest = @"
<?xml version="1.0" encoding="utf-8"?>
<Package
  xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
  xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
  xmlns:uap10="http://schemas.microsoft.com/appx/manifest/uap/windows10/10"
  xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
  IgnorableNamespaces="uap uap10 rescap">
  <Identity Name="$identityName" Version="$msixVersion" Publisher="$publisher" ProcessorArchitecture="x64" />
  <Properties>
    <DisplayName>$displayName</DisplayName>
    <PublisherDisplayName>$publisherDisplayName</PublisherDisplayName>
    <Description>Interactive GPU-accelerated simulations.</Description>
    <Logo>msix-assets\StoreLogo.png</Logo>
  </Properties>
  <Resources>
    <Resource Language="en-us" />
  </Resources>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.19041.0" MaxVersionTested="10.0.26100.0" />
  </Dependencies>
  <Capabilities>
    <rescap:Capability Name="runFullTrust" />
  </Capabilities>
  <Applications>
    <Application Id="Vizza" Executable="$AppName.exe" uap10:RuntimeBehavior="packagedClassicApp" uap10:TrustLevel="mediumIL">
      <uap:VisualElements
        DisplayName="$displayName"
        Description="Interactive GPU-accelerated simulations."
        Square150x150Logo="msix-assets\Square150x150Logo.png"
        Square44x44Logo="msix-assets\Square44x44Logo.png"
        BackgroundColor="#101010">
        <uap:DefaultTile
          Square71x71Logo="msix-assets\Square71x71Logo.png"
          Wide310x150Logo="msix-assets\Wide310x150Logo.png"
          Square310x310Logo="msix-assets\Square310x310Logo.png" />
        <uap:SplashScreen Image="msix-assets\SplashScreen.png" BackgroundColor="#101010" />
      </uap:VisualElements>
    </Application>
  </Applications>
</Package>
"@

	[System.IO.File]::WriteAllText($manifestPath, $manifest.Replace("`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))
}

function Sign-MsixPackage {
	param([string]$MsixPath)
	if (-not $PfxPath) {
		Write-Host "Skipping MSIX signing. Microsoft Store submissions are re-signed by Store ingestion; sideloading needs WINDOWS_PFX_PATH."
		return
	}

	Require-Command "signtool"
	$args = @("sign", "/fd", "SHA256", "/f", $PfxPath)
	if ($PfxPassword) {
		$args += @("/p", $PfxPassword)
	}
	$args += $MsixPath
	Invoke-Tool "signtool" $args
}

function New-MsixPackage {
	param([string]$PackageDir)

	Require-Command "MakeAppx"
	$msixPath = Join-Path $DistDir "$AppName-windows.msix"
	if (Test-Path $msixPath) {
		Remove-Item -Force $msixPath
	}

	New-MsixAssets $PackageDir
	Write-MsixManifest $PackageDir
	Invoke-Tool "MakeAppx" @("pack", "/d", $PackageDir, "/p", $msixPath, "/o")
	Sign-MsixPackage $msixPath
	Write-Host "MSIX: $msixPath"
}

function Package-App {
	param([string]$BuiltExe)

	$packageDir = Join-Path $DistDir "$AppName-windows"
	$archivePath = Join-Path $DistDir "$AppName-windows.zip"
	$packageExe = Join-Path $packageDir "$AppName.exe"

	if (Test-Path $packageDir) {
		Remove-Item -Recurse -Force $packageDir
	}
	if (Test-Path $archivePath) {
		Remove-Item -Force $archivePath
	}
	New-Item -ItemType Directory -Force -Path $packageDir | Out-Null
	New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

	Copy-Item -Path $BuiltExe -Destination $packageExe -Force
	$pdb = [System.IO.Path]::ChangeExtension($BuiltExe, ".pdb")
	if (Test-Path $pdb) {
		Copy-Item -Path $pdb -Destination (Join-Path $packageDir "$AppName.pdb") -Force
	}

	Copy-Item -Path (Join-Path $RootDir "assets") -Destination (Join-Path $packageDir "assets") -Recurse -Force
	New-Item -ItemType Directory -Force -Path (Join-Path $packageDir "build") | Out-Null
	Copy-Item -Path (Join-Path $BuildDir "shaders") -Destination (Join-Path $packageDir "build/shaders") -Recurse -Force

	$startBinaries = @($packageExe)
	$startBinaries += Copy-OptionalVulkanLoader $packageDir
	Copy-VcpkgDllClosure $startBinaries $packageDir

	Compress-Archive -Path $packageDir -DestinationPath $archivePath -Force
	if ($Msix) {
		New-MsixPackage $packageDir
	}

	Write-Host "Packaged app: $packageDir"
	Write-Host "Archive: $archivePath"
}

Require-Command "git"
Require-Command "cl"
Require-Command "lib"
Require-Command "dumpbin"
Require-Command "odin"
Require-Command "bash"

if (-not $Version) {
	$Version = Get-AppVersion
}

foreach ($requiredPath in @(
	$VcpkgIncludeDir,
	$VcpkgLibDir,
	$VcpkgBinDir,
	(Join-Path $VcpkgLibDir "SDL3.lib"),
	(Join-Path $VcpkgLibDir "harfbuzz.lib"),
	(Join-Path $VcpkgLibDir "freetype.lib")
)) {
	if (-not (Test-Path $requiredPath)) {
		throw "Missing required vcpkg path: $requiredPath"
	}
}

Push-Location $RootDir
try {
	Write-Host "Packaging $AppName $Version for Windows..."
	Ensure-Tomlc17
	Build-Tomlc17
	Build-Textshape
	Build-Shaders
	$builtExe = Build-App
	Package-App $builtExe
} finally {
	Pop-Location
}
