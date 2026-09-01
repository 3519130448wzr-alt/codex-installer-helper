[CmdletBinding()]
param(
    [string]$SourcePath = (Join-Path $PSScriptRoot "..\src\CodexInstaller.Windows\assets\AppIcon-256.png"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\src\CodexInstaller.Windows\assets\CodexInstaller.ico")
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$directory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $directory | Out-Null

$source = [System.Drawing.Image]::FromFile($SourcePath)
$bitmap = [System.Drawing.Bitmap]::new($source, 256, 256)

$png = New-Object System.IO.MemoryStream
$bitmap.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
$bytes = $png.ToArray()
$stream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Create)
$writer = New-Object System.IO.BinaryWriter $stream
$writer.Write([uint16]0)
$writer.Write([uint16]1)
$writer.Write([uint16]1)
$writer.Write([byte]0)
$writer.Write([byte]0)
$writer.Write([byte]0)
$writer.Write([byte]0)
$writer.Write([uint16]1)
$writer.Write([uint16]32)
$writer.Write([uint32]$bytes.Length)
$writer.Write([uint32]22)
$writer.Write($bytes)
$writer.Dispose()
$stream.Dispose()
$png.Dispose()
$bitmap.Dispose()
$source.Dispose()

Write-Host "Generated $OutputPath"
