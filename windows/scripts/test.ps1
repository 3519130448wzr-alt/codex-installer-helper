[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
dotnet run --project (Join-Path $root "windows\tests\CodexInstaller.CoreTests\CodexInstaller.CoreTests.csproj") --configuration Release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
