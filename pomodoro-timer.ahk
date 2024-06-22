; Help: Start BSB Pomodoro Timer
#Requires AutoHotkey v2
#SingleInstance Force
#Warn All, Off
#ErrorStdOut
Persistent
InstallKeybdHook
InstallMouseHook

WINDOW_TITLE := "BSB Pomodoro Timer"
FINISH_WORK_COUNT := 16
TIME_TO_FOCUS := 25 * 60
TIME_TO_REST := 5 * 60
TIME_TO_STOP_AUTO := 1 * 60 * 1000 ; 1 min
GUI_MIN_WIDTH := 64
GUI_MAX_WIDTH := 186

positionX := GetIniValue("Position", "X", -1)
positionY := GetIniValue("Position", "Y", -1)
startTimerAtStartup := GetIniValue("General", "StartTimerAtStartup", true)
autoStopWhenAway := GetIniValue("General", "AutoStopWhenAway", true)
skipBreakTimes := GetIniValue("General", "SkipBreakTimes", 0)

if (positionX < 0 || positionX > (A_ScreenWidth - 100)) {
    positionX := 0
}
if (positionY < 0 || positionY > (A_ScreenHeight - 100)) {
    positionY := 0
}

pomodoroCount := LoadPomodoroCount()
timerStatus := ""
elapsedTime := 0

; Tray Settings
trayMenu := A_TrayMenu ; For convenience.
trayMenu.Delete()
trayMenu.Add("Start Timer", HandleStartOrStopOption)
trayMenu.Add()
trayMenu.Add("+1 Pomodoro", HandleAddPomodoroOption)
trayMenu.Add("-1 Pomodoro", HandleAddPomodoroOption)
trayMenu.Add()
trayMenu.Add("Start Timer at Startup", HandleStartupTimerOption)
trayMenu.Add("Auto-stop when away", HandleAutoStopOption)
trayMenu.Add()
trayMenu.Add("Skip 16 break times", HandleSkipBreakTimesOption)
trayMenu.Add("Skip 14 break times", HandleSkipBreakTimesOption)
trayMenu.Add("Skip 12 break times", HandleSkipBreakTimesOption)
trayMenu.Add("Skip 10 break times", HandleSkipBreakTimesOption)
trayMenu.Add("Skip 8 break times", HandleSkipBreakTimesOption)
trayMenu.Add("Skip 6 break times", HandleSkipBreakTimesOption)
trayMenu.Add("Skip 4 break times", HandleSkipBreakTimesOption)
trayMenu.Add("Skip 2 break times", HandleSkipBreakTimesOption)
trayMenu.Add("Skip 0 break times", HandleSkipBreakTimesOption)
trayMenu.Add()
trayMenu.Add("Edit Settings File", (*) => Run("notepad.exe pomodoro-timer.ini"))
trayMenu.Add()
trayMenu.Add("About", (*) => MsgBox("verlane/pomodoro-timer v0.0.2"))
trayMenu.Add("&Reload", (*) => Reload())
trayMenu.Add("E&xit", (*) => ExitApp())

trayMenu.Check("Skip " skipBreakTimes " break times")

; GUI Settings
if (!A_IsCompiled) {
    TraySeticon(A_ScriptDir . "\pomodoro-timer.ico")
}
MyGui := Gui("-Caption -Border +ToolWindow +AlwaysOnTop +OwnDialogs", WINDOW_TITLE)
MyGui.SetFont("s10", "Consolas")
MyGui.OnEvent("Escape", (*) => StopTimer())
OnMessage(0x204, OnWM_RBUTTONDOWN)
OnWM_RBUTTONDOWN(*) {
    trayMenu.Show()
}

workCountLabel := Format("{:02d}:00 {:02d}", Floor(TIME_TO_FOCUS / 60), pomodoroCount)
ElapsedTimeText := MyGui.Add("Text", "x2 y3 w140 h20", workCountLabel)

StartTimerButton := MyGui.Add("Button", "x66 y0 w50 h20 Default", "&Start")
StartTimerButton.OnEvent("Click", (*) => StartTimer())

StopTimerButton := MyGui.Add("Button", "x116 y0 w50 h20", "S&top")
StopTimerButton.OnEvent("Click", (*) => StopTimer())

QuitButton := MyGui.Add("Button", "x166 y0 w20 h20", "&X")
QuitButton.OnEvent("Click", (*) => Quit())

WorkCountProgress := MyGui.Add("Progress", "x-1 y0 w" . (GUI_MIN_WIDTH + 2) . " h3 -Smooth", (pomodoroCount * 100 / FINISH_WORK_COUNT))
MyGui.Show("x" . positionX . " y" . positionY . " w" . GUI_MAX_WIDTH . " h20")

OnMessage(0x200, PomoWmMouseMove)

if (startTimerAtStartup) {
    trayMenu.Check("Start Timer at Startup")
    IniWrite(true, "pomodoro-timer.ini", "General", "StartTimerAtStartup")
    StartTimer()
}

if (autoStopWhenAway) {
    trayMenu.Check("Auto-stop when away")
    IniWrite(true, "pomodoro-timer.ini", "General", "AutoStopWhenAway")
}

HandleStartOrStopOption(menuItemName, callbackOrSubmenu, options) {
    if (menuItemName == "Start Timer") {
        StartTimer()
    } else {
        StopTimer()
    }
}

HandleAddPomodoroOption(menuItemName, callbackOrSubmenu, options) {
    if (RegExMatch(menuItemName, "i)^([`+`-][0-9]+) Pomodoro$", &SubPat)) {
        global pomodoroCount := pomodoroCount + SubPat[1]
        TimerHandler()
        WritePomodoroCount(pomodoroCount)
    }
}

HandleStartupTimerOption(menuItemName, callbackOrSubmenu, options) {
    trayMenu.ToggleCheck("Start Timer at Startup")
    IniWrite(!startTimerAtStartup, "pomodoro-timer.ini", "General", "StartTimerAtStartup")
}

HandleAutoStopOption(menuItemName, callbackOrSubmenu, options) {
    trayMenu.ToggleCheck("Auto-stop when away")
    IniWrite(!autoStopWhenAway, "pomodoro-timer.ini", "General", "AutoStopWhenAway")
}

HandleSkipBreakTimesOption(menuItemName, callbackOrSubmenu, options) {
    trayMenu.Uncheck("Skip 14 break times")
    trayMenu.Uncheck("Skip 12 break times")
    trayMenu.Uncheck("Skip 10 break times")
    trayMenu.Uncheck("Skip 8 break times")
    trayMenu.Uncheck("Skip 6 break times")
    trayMenu.Uncheck("Skip 4 break times")
    trayMenu.Uncheck("Skip 0 break times")
    if (RegExMatch(menuItemName, "i)^Skip ([0-9]+) break times$", &SubPat)) {
        trayMenu.Check("Skip " SubPat[1] " break times")
        IniWrite(SubPat[1], "pomodoro-timer.ini", "General", "SkipBreakTimes")
        global skipBreakTimes := SubPat[1]
    }
}

; Start timer function
StartTimer() {
    global
    if (elapsedTime <= 0) {
        currentTime := TIME_TO_FOCUS
        timerStatus := "W"
        elapsedTime := 0
    }
    try {
        trayMenu.Rename("Start Timer", "Stop Timer")
    } catch TargetError as err {
    }
    MyGui.Submit(false)
    ShowGui(false)
    SetTimer(TimerHandler, 1000)
}

; Stop timer function
StopTimer() {
    try {
        trayMenu.Rename("Stop Timer", "Start Timer")
    } catch TargetError as err {
    }
    ShowGui()
    MyGui.BackColor := GetDefaultGuiColor()
    SetTimer(TimerHandler, 0)
}

; Timer handler function
TimerHandler() {
    global
    MyGui.Opt("+AlwaysOnTop")
    if (timerStatus == "W" && A_TimeIdlePhysical >= TIME_TO_STOP_AUTO) {
        MyGui.BackColor := 0x555555
        ElapsedTimeText.Opt("+cWhite")
        Return
    }

    ElapsedTimeText.Opt("+c" . GetDefaultGuiColor(8))
    if (timerStatus == "W") {
        MyGui.BackColor := 0xFFFFFF
    } else {
        MyGui.BackColor := 0xFACF2C ; yellow
    }

    elapsedTime := elapsedTime + 1
    timeLeft := currentTime - elapsedTime

    progressValue := (pomodoroCount * TIME_TO_FOCUS + elapsedTime) * 100 / (FINISH_WORK_COUNT * TIME_TO_FOCUS)
    WorkCountProgress.Value := progressValue
    if (progressValue >= 100) {
        WorkCountProgress.Opt("+cBlue")
    }

    if (timeLeft < 1) {
        elapsedTime := 0
        if (timerStatus == "W") {
            SoundPlay A_ScriptDir . "\audio\Sound1.mp3"
            pomodoroCount := pomodoroCount + 1
            WritePomodoroCount(pomodoroCount)
            ShowLabel(timeLeft, timerStatus, pomodoroCount)
            if (pomodoroCount < skipBreakTimes || MsgBoxEx("To keep working?") == "Yes") {
                currentTime := TIME_TO_FOCUS
                timerStatus := "W"
            } else {
                currentTime := TIME_TO_REST
                timerStatus := "B"
            }
        } else {
            SoundPlay A_ScriptDir . "\audio\Sound2.mp3"
            ShowLabel(timeLeft, timerStatus, pomodoroCount)
            if (MsgBoxEx("Start working?") == "Yes") {
                currentTime := TIME_TO_FOCUS
                timerStatus := "W"
            } else {
                currentTime := TIME_TO_REST
                timerStatus := "B"
                StopTimer()
            }
        }
    }
    ShowLabel(timeLeft, timerStatus, pomodoroCount)
}

Quit() {
    ExitApp
}

ShowGui(fullFlag := true) {
    global
    if (fullFlag) {
        MyGui.Show("x" . positionX . " y" . positionY . " w" . GUI_MAX_WIDTH . " h20")
    } else {
        MyGui.Show("x" . positionX . " y" . positionY . " w" . GUI_MIN_WIDTH . " h20")
    }
}

ShowLabel(timeLeft, timerStatus, pomodoroCount) {
    minutesLeft := floor(timeLeft / 60)
    secondsLeft := mod(timeLeft, 60)
    ElapsedTimeText.Text := Format("{:02d}:{:02d} {:02d}", minutesLeft, secondsleft, pomodoroCount)
}

WritePomodoroCount(count) {
    nDate := FormatTime(A_Now, "yyyyMMdd")
    IniWrite(count, "pomodoro-timer.ini", "Date", nDate)
}

LoadPomodoroCount() {
    nDate := FormatTime(A_Now, "yyyyMMdd")
    count := GetIniValue("Date", nDate, 0)
    if (count == "ERROR") {
        count := 0
        IniWrite(count, "pomodoro-timer.ini", "Date", nDate)
    }
    Return count
}

PomoWmMouseMove(wparam, lparam, msg, hwnd)
{
    if (wparam = 1) { ; LButton
        winClass := WinGetClass("A")
        winTitle := WinGetTitle("A")
        if (winClass != "AutoHotkeyGUI" || winTitle == "Pomodoro Timer Alert") { ; is MsgBox?
            return
        }
        PostMessage 0xA1, 2, , , "A" ; WM_NCLBUTTONDOWN
        Sleep 10
        SavePosition()
    }
}

GetDefaultGuiColor(elementIndex := 15) {
    ; http://msdn.microsoft.com/en-us/library/ms724371%28VS.85%29.aspx
    defaultGUIColor := DllCall("User32.dll\GetSysColor", "Int", elementIndex, "UInt")
    R := defaultGUIColor & 0xFF
    G := (defaultGUIColor >> 8) & 0xFF
    B := (defaultGUIColor >> 16) & 0xFF
    hex := Format("{:02X}{:02X}{:02X}", R, G, B)
    Return hex
}

SavePosition() {
    global
    WinGetPos(&positionX, &positionY, &width, &height)
    if ((positionX - 20) < 0) {
        positionX := 0
    }
    if ((positionY - 20) < 0) {
        positionY := 0
    }
    IniWrite(positionX, "pomodoro-timer.ini", "Position", "X")
    IniWrite(positionY, "pomodoro-timer.ini", "Position", "Y")
    WinMove positionX, positionY, , , "ahk_id " MyGui.Hwnd
}

GetIniValue(section, key, defaultValue := "") {
    return IniRead("pomodoro-timer.ini", section, key, defaultValue)
}

MsgBoxEx(message) {
    msgBoxGui := Gui("+AlwaysOnTop", "Pomodoro Timer Alert")
    msgBoxGui.SetFont("s10", "Consolas")
    msgBoxGui.Add("Text", "x0 y6 w250 h20 Center", message)
    okButton := msgBoxGui.Add("Button", "x20 y36 w100 h30 Default", "&Yes")
    cancelButton := msgBoxGui.Add("Button", "x130 y36 w100 h30", "&No")
    msgBoxGui.Show("w250 h80 NoActivate")

    result := ""
    msgBoxGui.OnEvent("Close", (*) => SetMsgBoxExResult("No", &result, msgBoxGui))
    okButton.OnEvent("Click", (*) => SetMsgBoxExResult("Yes", &result, msgBoxGui))
    cancelButton.OnEvent("Click", (*) => SetMsgBoxExResult("No", &result, msgBoxGui))
    msgBoxGui.OnEvent("Escape", (*) => SetMsgBoxExResult("No", &result, msgBoxGui))

    While (result == "") {
        Sleep(100)
    }

    return result
}

SetMsgBoxExResult(value, &result, msgBoxGui) {
    result := value
    msgBoxGui.Destroy()
}