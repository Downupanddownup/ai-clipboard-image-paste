#Requires AutoHotkey v2.0
#SingleInstance Force

Persistent

global CacheDir := EnvGet("USERPROFILE") "\.ai-clipboard-image-cache"
global PowerShellScript := A_ScriptDir "\Save-ClipboardImageToAiCache.ps1"
global PowerShellExe := A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe"

A_IconTip := "AI Clipboard Image Paste"

^+v::HandleEnhancedPaste()

HandleEnhancedPaste() {
    global CacheDir
    global PowerShellScript
    global PowerShellExe

    if !ClipboardHasImage() {
        KeyWait("Ctrl")
        KeyWait("Shift")
        Send("^v")
        return
    }

    if !FileExist(PowerShellScript) {
        SoundBeep(750, 120)
        MsgBox("Missing script:`n" PowerShellScript, "AI Clipboard Image Paste", "Iconx")
        return
    }

    outputFile := A_Temp "\ai-clipboard-image-path.txt"
    if FileExist(outputFile) {
        FileDelete(outputFile)
    }

    command := '"' PowerShellExe '" -NoProfile -Sta -WindowStyle Hidden -ExecutionPolicy Bypass -File "' PowerShellScript '" -CacheDir "' CacheDir '" -OutputFile "' outputFile '"'
    RunWait(command, , "Hide")

    path := ""
    if FileExist(outputFile) {
        path := Trim(FileRead(outputFile, "UTF-8"), "`r`n`t ")
        FileDelete(outputFile)
    }

    if (path = "") {
        SoundBeep(750, 120)
        MsgBox("Failed to save clipboard image.", "AI Clipboard Image Paste", "Iconx")
        return
    }

    KeyWait("Ctrl")
    KeyWait("Shift")
    SendText('image: "' path '";')
}

ClipboardHasImage() {
    static CF_BITMAP := 2
    static CF_DIB := 8
    static CF_DIBV5 := 17

    return DllCall("IsClipboardFormatAvailable", "UInt", CF_BITMAP, "Int")
        || DllCall("IsClipboardFormatAvailable", "UInt", CF_DIB, "Int")
        || DllCall("IsClipboardFormatAvailable", "UInt", CF_DIBV5, "Int")
}
