<#
.SYNOPSIS
    Builds and packages the Audio Spectrum plugin into an InfoPanel registry-compliant release ZIP.

.DESCRIPTION
    Publishes the plugin (Release, win-x64, framework-dependent), stages the output into a
    top-level folder named after the plugin, and compresses that folder into a release ZIP.

    The resulting archive matches the InfoPanel plugin registry layout, where every DLL lives
    inside a single top-level folder matching the installed plugin folder name:

        InfoPanel.AudioSpectrum-v<version>.zip
        └── InfoPanel.AudioSpectrum/
            ├── InfoPanel.AudioSpectrum.dll
            ├── PluginInfo.ini
            └── ... (dependencies)

    The version is read from PluginInfo.ini unless overridden with -Version.

.PARAMETER Version
    Override the version string used in the ZIP file name. Defaults to the Version field in PluginInfo.ini.

.PARAMETER InfoPanelPluginsPath
    Optional path to InfoPanel.Plugins.csproj when the InfoPanel source is not alongside this project.

.EXAMPLE
    .\build-release.ps1

.EXAMPLE
    .\build-release.ps1 -Version 2.1.0
#>
[CmdletBinding()]
param(
    [string]$Version,
    [string]$InfoPanelPluginsPath
)

$ErrorActionPreference = 'Stop'

$PluginName = 'InfoPanel.AudioSpectrum'
$root       = $PSScriptRoot
$publishDir = Join-Path $root "bin\Release\net8.0-windows\win-x64\publish"
$stageRoot  = Join-Path $root "release-staging"
$stageDir   = Join-Path $stageRoot $PluginName

# Resolve version from PluginInfo.ini when not supplied.
if (-not $Version) {
    $iniLine = Get-Content (Join-Path $root 'PluginInfo.ini') | Where-Object { $_ -match '^\s*Version\s*=' }
    if (-not $iniLine) { throw "Could not find Version in PluginInfo.ini; pass -Version explicitly." }
    $Version = ($iniLine -split '=', 2)[1].Trim()
}

$zipName = "$PluginName-v$Version.zip"
$zipPath = Join-Path $root $zipName

Write-Host "Building $PluginName v$Version" -ForegroundColor Cyan

# Publish (framework-dependent, win-x64).
$publishArgs = @('publish', '-c', 'Release', '-r', 'win-x64', '--self-contained', 'false')
if ($InfoPanelPluginsPath) {
    $publishArgs += "-p:InfoPanelPluginsPath=$InfoPanelPluginsPath"
}
dotnet @publishArgs
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed with exit code $LASTEXITCODE." }

if (-not (Test-Path $publishDir)) { throw "Publish output not found at $publishDir." }

# Stage publish output inside a folder named after the plugin.
if (Test-Path $stageRoot) { Remove-Item $stageRoot -Recurse -Force }
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
Copy-Item -Path (Join-Path $publishDir '*') -Destination $stageDir -Recurse -Force

# Drop the large native SkiaSharp debug symbols (~80 MB) — not needed in a release.
Get-ChildItem -Path $stageDir -Filter 'libSkiaSharp.pdb' -ErrorAction SilentlyContinue | Remove-Item -Force

# Compress the FOLDER (not its contents) so the ZIP has the required top-level folder.
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $stageDir -DestinationPath $zipPath -CompressionLevel Optimal

Remove-Item $stageRoot -Recurse -Force

Write-Host "Created $zipName" -ForegroundColor Green
Write-Host "Top-level folder in archive: $PluginName/" -ForegroundColor Green
