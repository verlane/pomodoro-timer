; Help: Start BSB Pomodoro Timer
#Requires AutoHotkey v2
#SingleInstance Force
#Warn All, Off
#ErrorStdOut
Persistent
InstallKeybdHook
InstallMouseHook

#Include src\ClassMain.ahk
#Include src\ClassSetting.ahk
#Include src\ClassTimer.ahk
#Include src\LV_TV_WantReturnSC.ahk

; GUI Settings
if (!A_IsCompiled) {
  TraySeticon(A_ScriptDir . "\pomodoro-timer.ico")
}

main := ClassMain()