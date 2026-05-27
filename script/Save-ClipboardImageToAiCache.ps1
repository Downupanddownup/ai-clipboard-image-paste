[CmdletBinding()]
param(
    [string]$CacheDir = "$env:USERPROFILE\.ai-clipboard-image-cache",
    [string]$OutputFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not [System.Windows.Forms.Clipboard]::ContainsImage()) {
    Write-Error "Clipboard does not contain an image."
}

$resolvedCacheDir = [System.IO.Path]::GetFullPath($CacheDir)
[System.IO.Directory]::CreateDirectory($resolvedCacheDir) | Out-Null

$image = [System.Windows.Forms.Clipboard]::GetImage()
if ($null -eq $image) {
    Write-Error "Failed to read image from clipboard."
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$fileName = "shot-$timestamp.png"
$filePath = Join-Path $resolvedCacheDir $fileName

try {
    $image.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $image.Dispose()
}

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
if ($OutputFile) {
    [System.IO.File]::WriteAllText($OutputFile, $filePath, [System.Text.UTF8Encoding]::new($false))
}
else {
    Write-Output $filePath
}
