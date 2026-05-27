# Windows 下为 Kimi Code / Claude Code 增加截图粘贴能力的通用方案

## 1. 需求概述

用户希望在 Windows 环境中，为 **Kimi Code** 和 **Claude Code** 提供更顺畅的截图输入能力。

当前期望是：

- 在 Windows 中使用截图工具 截图。
- 截图进入剪贴板后，切换到 Kimi Code 或 Claude Code 所在的 PowerShell 终端。
- 直接按 `Ctrl + V`。
- 如果剪贴板中是图片，则自动保存图片，并将图片路径以提示词形式粘贴到终端中。
- 如果剪贴板中是普通文本，则保持正常 `Ctrl + V` 粘贴行为。

目标是实现一种 **通用、稳定、易操作、低侵入** 的方案，避免依赖 Kimi Code / Claude Code 原生图片粘贴在不同终端环境中的兼容性。

---

## 2. 使用背景

### 2.1 Kimi Code 的价值点

Kimi Code 支持多模态能力。如果不能方便地输入截图，实际会浪费它的视觉理解能力。

在编码场景中，截图输入非常常见，例如：

- 让 agent 根据报错截图定位问题。
- 让 agent 根据 UI 截图修改前端样式。
- 让 agent 根据浏览器截图分析布局、间距、颜色、交互问题。
- 让 agent 根据设计稿或运行结果截图反推代码改动。

因此，截图粘贴能力对 Kimi Code 尤其重要。

### 2.2 当前环境

用户环境为 Windows：

- Claude Code 运行在 PowerShell 5。
- Kimi Code 运行在 PowerShell 7。
- 两者都是 CLI / 终端式编码助手。

### 2.3 当前问题

虽然 Kimi Code 和 Claude Code 都具备或宣称具备图片输入能力，但在 Windows 的终端环境中，图片直接粘贴并不总是稳定。

常见问题包括：

- Windows Terminal 中图片剪贴板无法被 CLI 正确识别。
- VS Code 集成终端中 `Ctrl + V` 图片粘贴无反应。
- PowerShell 5 与 PowerShell 7 对剪贴板图片的处理方式不同。
- 终端、CLI、模型、多模态输入能力之间存在多层兼容性问题。

因此，与其依赖原生图片粘贴，不如在 Windows 层做一个稳定的桥接。

---

## 3. 方案核心思路

推荐方案是：

> 不直接把图片粘贴给 CLI，而是把剪贴板中的图片自动保存成文件，然后把图片文件路径作为文本粘贴给 Kimi Code / Claude Code。

即：

```text
截图复制到剪贴板
        ↓
按 Ctrl + V
        ↓
AutoHotkey 检测剪贴板内容
        ↓
如果是图片：调用 PowerShell 5.1 保存为 PNG
        ↓
生成提示词
        ↓
把提示词粘贴到当前终端
```

生成后的提示词示例：

```text
请读取并分析这张截图，然后结合当前项目给出修改方案："C:\Users\xxx\.ai-shots\shot-20260527-153000.png"
```

---

## 4. 为什么推荐这个方案

### 4.1 通用

该方案不依赖某个 agent 的内部实现。

它适用于：

- Kimi Code
- Claude Code
- 其他支持文件路径输入的 CLI agent
- Windows Terminal
- PowerShell 5
- PowerShell 7
- VS Code 集成终端

### 4.2 稳定

终端对图片粘贴的支持不稳定，但对文本粘贴支持非常稳定。

该方案把复杂的“图片粘贴”问题转化为简单的“文本路径粘贴”问题。

### 4.3 操作简单

配置完成后，日常使用只需要：

```text
Win + Shift + S 截图
Ctrl + V 粘贴到 Kimi Code / Claude Code
```

### 4.4 不影响普通文本粘贴

桥接脚本会判断剪贴板内容：

- 如果剪贴板中是图片，则保存图片并粘贴提示词。
- 如果剪贴板中是文本，则保持正常 `Ctrl + V`。

---

## 5. 推荐架构

整体架构如下：

```text
Windows 剪贴板
     │
     ├── 文本 → 正常 Ctrl + V
     │
     └── 图片 → AutoHotkey 拦截 Ctrl + V
                    │
                    └── 调用 PowerShell 5.1 -Sta
                              │
                              └── 保存图片到 ~/.ai-shots
                                        │
                                        └── 生成提示词并粘贴到终端
```

建议始终用 **Windows PowerShell 5.1** 保存剪贴板图片，即使 Kimi Code 运行在 PowerShell 7 中。

原因是：

- Windows PowerShell 5.1 对 `System.Windows.Forms.Clipboard` 支持更稳定。
- 剪贴板图片读取需要 STA 模式。
- PowerShell 7 不必承担处理 Windows 剪贴板图片的职责。

---

## 6. 安装 AutoHotkey v2

安装 AutoHotkey v2。

注意：请使用 **AutoHotkey v2**，不要使用 v1。下面脚本语法是 v2 版本。

---

## 7. 创建脚本目录

建议创建一个专门目录：

```powershell
mkdir $HOME\ai-paste
```

后续两个脚本都放在该目录下：

```text
C:\Users\<你>\ai-paste\Save-ClipboardImageForAI.ps1
C:\Users\<你>\ai-paste\ai-image-paste.ahk
```

---

## 8. PowerShell 脚本：保存剪贴板图片

新建文件：

```text
C:\Users\<你>\ai-paste\Save-ClipboardImageForAI.ps1
```

内容如下：

```powershell
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$promptFile = Join-Path $env:TEMP "ai-shot-prompt.txt"
$shotDir = Join-Path $HOME ".ai-shots"
New-Item -ItemType Directory -Force -Path $shotDir | Out-Null

function Write-Prompt($path) {
    $prompt = "请读取并分析这张截图，然后结合当前项目给出修改方案：`"$path`""
    [System.IO.File]::WriteAllText($promptFile, $prompt, [System.Text.Encoding]::UTF8)
}

# 1. 处理截图/位图剪贴板
if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
    $img = [System.Windows.Forms.Clipboard]::GetImage()
    $file = Join-Path $shotDir ("shot-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".png")
    $img.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Prompt $file
    exit 0
}

# 2. 处理从文件管理器复制的图片文件
if ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) {
    $files = [System.Windows.Forms.Clipboard]::GetFileDropList()
    foreach ($f in $files) {
        $ext = [System.IO.Path]::GetExtension($f).ToLowerInvariant()
        if ($ext -in @(".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif")) {
            Write-Prompt $f
            exit 0
        }
    }
}

exit 2
```

该脚本负责：

- 检查剪贴板中是否有图片。
- 如果有图片，则保存到：

```text
C:\Users\<你>\.ai-shots\
```

- 生成一段提示词。
- 将提示词写入临时文件：

```text
%TEMP%\ai-shot-prompt.txt
```

---

## 9. AutoHotkey 脚本：拦截 Ctrl + V

新建文件：

```text
C:\Users\<你>\ai-paste\ai-image-paste.ahk
```

内容如下：

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force

; 只在 Windows Terminal / VS Code / 普通 PowerShell 窗口里接管 Ctrl+V
#HotIf WinActive("ahk_exe WindowsTerminal.exe")
    || WinActive("ahk_exe Code.exe")
    || WinActive("ahk_exe powershell.exe")
    || WinActive("ahk_exe pwsh.exe")

^v::{
    if ClipboardHasImageOrImageFile() {
        script := A_ScriptDir "\Save-ClipboardImageForAI.ps1"
        promptFile := A_Temp "\ai-shot-prompt.txt"

        RunWait(
            'powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass -File "' script '"',
            ,
            "Hide"
        )

        if FileExist(promptFile) {
            prompt := FileRead(promptFile, "UTF-8")
            A_Clipboard := prompt
            ClipWait 1
            Send "^v"
        }
    } else {
        Send "^v"
    }
}

#HotIf

ClipboardHasImageOrImageFile() {
    ; CF_BITMAP = 2, CF_DIB = 8, CF_DIBV5 = 17
    if DllCall("IsClipboardFormatAvailable", "UInt", 2)
        || DllCall("IsClipboardFormatAvailable", "UInt", 8)
        || DllCall("IsClipboardFormatAvailable", "UInt", 17) {
        return true
    }

    ; CF_HDROP = 15，表示剪贴板里是文件列表
    if DllCall("IsClipboardFormatAvailable", "UInt", 15) {
        return true
    }

    return false
}
```

该脚本负责：

- 在 Windows Terminal、VS Code、PowerShell、PowerShell 7 中接管 `Ctrl + V`。
- 如果剪贴板中是图片，则调用 PowerShell 脚本保存图片。
- 读取生成的提示词。
- 把提示词粘贴到当前终端。
- 如果剪贴板中不是图片，则执行正常 `Ctrl + V`。

---

## 10. 启动方式

双击运行：

```text
C:\Users\<你>\ai-paste\ai-image-paste.ahk
```

启动后，AutoHotkey 会在后台运行。

---

## 11. 日常使用方式

完成配置后，日常操作如下：

```text
1. 使用 Win + Shift + S 截图
2. 切换到 Kimi Code 或 Claude Code 终端
3. 按 Ctrl + V
4. 终端中会自动粘贴图片路径提示词
5. 回车发送给 agent
```

示例粘贴结果：

```text
请读取并分析这张截图，然后结合当前项目给出修改方案："C:\Users\xxx\.ai-shots\shot-20260527-153000.png"
```

---

## 12. 针对 Kimi Code 的推荐提示词

Kimi Code 支持多模态，因此提示词可以更明确一些。

可以将 PowerShell 脚本中的提示词改成：

```powershell
$prompt = "请把这张截图作为视觉输入分析，结合当前项目代码定位问题，并直接给出需要修改的文件和补丁：`"$path`""
```

对应输出类似：

```text
请把这张截图作为视觉输入分析，结合当前项目代码定位问题，并直接给出需要修改的文件和补丁："C:\Users\xxx\.ai-shots\shot-20260527-153000.png"
```

这种写法更适合编码助手根据截图直接进入代码修改流程。

---

## 13. 可选方案：使用固定文件名 latest.png

如果不希望每次生成不同文件名，也可以采用固定文件名：

```text
C:\Users\<你>\.ai-shots\latest.png
```

这样每次截图都覆盖同一个文件。

优点：

- 提示词更短。
- agent 永远读取同一个路径。
- 适合频繁截图调试。

缺点：

- 历史截图会被覆盖。
- 不方便回溯之前的问题。

如果采用该方式，PowerShell 中的文件名生成逻辑可改为：

```powershell
$file = Join-Path $shotDir "latest.png"
```

提示词可以固定为：

```text
请读取并分析这张截图，然后结合当前项目给出修改方案："C:\Users\<你>\.ai-shots\latest.png"
```

---

## 14. 可选优化：缩小热键生效范围

当前 AutoHotkey 脚本会在以下窗口中接管 `Ctrl + V`：

- Windows Terminal
- VS Code
- powershell.exe
- pwsh.exe

也就是说，它只影响终端和编辑器环境，不影响浏览器、微信、文档软件等其他应用。

如果希望只在 Kimi Code 或 Claude Code 中触发，可以进一步判断窗口标题，但不建议一开始这样做。

原因是：

- Windows Terminal 标题经常变化。
- VS Code 集成终端标题也可能变化。
- 过度精确的判断容易导致漏触发。

推荐保持当前配置。

---

## 15. PowerShell 5 与 PowerShell 7 的处理原则

用户当前环境为：

```text
Claude Code：PowerShell 5
Kimi Code：PowerShell 7
```

推荐处理原则是：

```text
Claude Code / Kimi Code 继续运行在各自 shell 中
AutoHotkey 负责拦截 Ctrl + V
保存剪贴板图片时统一调用 powershell.exe 5.1 -Sta
最终把图片路径提示词粘贴回当前终端
```

这样做可以避免 PowerShell 7 与 Windows 剪贴板图片处理之间的兼容性问题。

---

## 16. 开机自启动

如果希望每次开机自动启用，可以将 `ai-image-paste.ahk` 的快捷方式放入启动目录。

按 `Win + R`，输入：

```text
shell:startup
```

然后把下面文件的快捷方式放进去：

```text
C:\Users\<你>\ai-paste\ai-image-paste.ahk
```

之后每次登录 Windows，脚本都会自动启动。

---

## 17. 最小落地版本总结

最终只需要两个文件：

```text
Save-ClipboardImageForAI.ps1
ai-image-paste.ahk
```

完成后日常使用流程是：

```text
Win + Shift + S 截图
Ctrl + V 粘贴到 Kimi Code / Claude Code
回车发送
```

这是一套适合 Windows + PowerShell + CLI 编码助手的通用截图输入桥接方案。

---

## 18. 推荐结论

不要优先尝试修改 Kimi Code 或 Claude Code 本身，也不要过度依赖终端原生图片粘贴能力。

更推荐的方式是：

> 用 AutoHotkey 拦截 `Ctrl + V`，用 PowerShell 5.1 保存剪贴板图片，然后把图片路径作为文本提示词粘贴给 Kimi Code / Claude Code。

该方案具有以下特点：

- 通用
- 稳定
- 易操作
- 可开机自启
- 不影响普通文本粘贴
- 同时适配 PowerShell 5 和 PowerShell 7
- 能充分释放 Kimi Code 的多模态能力
