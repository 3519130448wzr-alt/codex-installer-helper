[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$sourceRoots = @(
    (Join-Path $root "windows\src"),
    (Join-Path $root "windows\tests")
)

$forbidden = @(
    "auth\.json",
    "base_url",
    "OPENAI_API_KEY",
    "telemetry",
    "curl\s+.*\|",
    "irm\s+.*\|\s*iex"
)

$files = Get-ChildItem -Path $sourceRoots -Recurse -File | Where-Object {
    $_.FullName -notmatch "[\\/](bin|obj)[\\/]" -and
    $_.Extension -in ".cs", ".csproj", ".xml", ".manifest"
}
foreach ($pattern in $forbidden) {
    $matches = $files | Select-String -Pattern $pattern -CaseSensitive:$false
    if ($matches) {
        $matches | ForEach-Object { Write-Error "$($_.Path):$($_.LineNumber): forbidden pattern" }
        exit 1
    }
}

$packages = $files | Select-String -Pattern "<PackageReference"
if ($packages) {
    Write-Error "Windows projects must not add third-party runtime packages."
    exit 1
}

$bundled = Get-ChildItem -Path (Join-Path $root "windows") -Recurse -File | Where-Object {
    $_.Name -match "^codex(\.exe|\.cmd|\.zip)$"
}
if ($bundled) {
    Write-Error "A Codex binary or archive appears to be bundled in the Windows source tree."
    exit 1
}

Write-Host "Windows security check passed."
