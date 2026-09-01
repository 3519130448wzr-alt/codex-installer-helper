[CmdletBinding()]
param(
    [ValidateSet("win-x64", "win-arm64")]
    [string]$Runtime = "win-x64",
    [string]$Version = "0.1.0",
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $root "build\windows"
}

& (Join-Path $PSScriptRoot "generate-icon.ps1")

$publishDirectory = Join-Path $OutputRoot "$Runtime\publish"
dotnet publish (Join-Path $root "windows\src\CodexInstaller.Windows\CodexInstaller.Windows.csproj") `
    --configuration Release `
    --runtime $Runtime `
    --self-contained true `
    --output $publishDirectory `
    -p:Version=$Version `
    -p:PublishSingleFile=true `
    -p:PublishTrimmed=false `
    -p:DebugType=None `
    -p:DebugSymbols=false
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$architecture = if ($Runtime -eq "win-arm64") { "arm64" } else { "x64" }
$artifact = Join-Path $OutputRoot "Codex-Installer-Helper-$Version-windows-$architecture.exe"
Copy-Item -Force (Join-Path $publishDirectory "Codex-Installer-Helper.exe") $artifact
Write-Host "Built $artifact"
