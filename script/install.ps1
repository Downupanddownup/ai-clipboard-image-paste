$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ahkScript = Join-Path $scriptDir "ai-clipboard-image-paste.ahk"

# 1. 检查配套 .ahk 是否存在
if (-not (Test-Path $ahkScript)) {
    Write-Error "未找到配套脚本: ai-clipboard-image-paste.ahk"
    exit 1
}

Write-Host "正在查找 AutoHotkey v2 ..."

# 2. 动态查找 AHK v2
$ahkExe = $null
$regPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\AutoHotkey.exe',
    'HKLM:\SOFTWARE\AutoHotkey\v2',
    'HKLM:\SOFTWARE\AutoHotkey'
)

foreach ($rp in $regPaths) {
    if (Test-Path $rp) {
        $prop = Get-ItemProperty $rp -ErrorAction SilentlyContinue
        $p = if ($prop.'(default)') { $prop.'(default)' } else { $prop.InstallDir }
        if ($p) {
            $candidates = @()
            if (Test-Path $p -PathType Leaf) {
                $candidates += $p
            } else {
                $candidates += Join-Path $p "AutoHotkey.exe"
                $candidates += Join-Path $p "v2\AutoHotkey.exe"
            }
            foreach ($c in $candidates) {
                if (Test-Path $c) { $ahkExe = $c; break }
            }
            if ($ahkExe) { break }
        }
    }
}

if (-not $ahkExe) {
    $cmd = Get-Command "AutoHotkey.exe" -ErrorAction SilentlyContinue
    if ($cmd) { $ahkExe = $cmd.Source }
}

if (-not $ahkExe -or -not (Test-Path $ahkExe)) {
    Write-Error "未找到 AutoHotkey v2，请先安装。"
    exit 1
}

$version = (Get-ItemProperty $ahkExe).VersionInfo.FileVersion
if ($version -notlike "2.*") {
    Write-Error "找到的 AutoHotkey 不是 v2 版本。当前版本: $version"
    exit 1
}

# 3. 创建快捷方式
$startMenu = [Environment]::GetFolderPath('StartMenu')
$programs = Join-Path $startMenu "Programs"
$shortcut = Join-Path $programs "AI Clipboard Image Paste.lnk"

$WshShell = New-Object -ComObject WScript.Shell
$s = $WshShell.CreateShortcut($shortcut)
$s.TargetPath = $ahkExe
$s.Arguments = '"' + $ahkScript + '"'
$s.WorkingDirectory = $scriptDir
$s.Save()

# 4. 校验结果
if (-not (Test-Path $shortcut)) {
    Write-Error "快捷方式创建失败。"
    exit 1
}

Write-Host "已创建: $shortcut"
Write-Host "安装完成。按 Win 键输入 `"AI`" 即可搜索启动。"
