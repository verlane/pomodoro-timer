; Help: Start BSB Pomodoro Timer
#Requires AutoHotkey v2.0
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
TIME_TO_STOP_AUTO := 1 * 60 * 1000
GUI_MIN_WIDTH := 64 
GUI_MAX_WIDTH := 186

positionX := GetIniValue("Position", "X", -1)
positionY := GetIniValue("Position", "Y", -1)

if (positionX < 0 || positionX > (A_ScreenWidth - 100)) {
    positionX := 0
}
if (positionY < 0 || positionY > (A_ScreenHeight - 100)) {
    positionY := 0
}

pomodoroCount := LoadPomodoroCount()
timerStatus := ""
elapsedTime := 0

; GUI Settings
TraySeticon(A_ScriptDir . "\pomodoro-timer.ico")
MyGui := Gui("-Caption -Border +ToolWindow +AlwaysOnTop", WINDOW_TITLE)
MyGui.SetFont("s10", "Consolas")
MyGui.OnEvent("Escape", (*) => StopTimer())

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

; Start timer function
StartTimer() {
    global
    if (elapsedTime <= 0) {
        currentTime := TIME_TO_FOCUS
        timerStatus := "W"
        elapsedTime := 0
    }
    MyGui.Submit(false)
    ShowGui(false)
    SetTimer(TimerHandler, 1000)
}

; Stop timer function
StopTimer() {
    ShowGui()
    MyGui.BackColor := GetDefaultGuiColor()
    SetTimer(TimerHandler, 0)
}

; Timer handler function
TimerHandler() {
    global
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
            if (MsgBox("To keep working?", "Pomodoro Timer Alert", 1) == "OK") {
                currentTime := TIME_TO_FOCUS
                timerStatus := "W"
            } else {
                currentTime := TIME_TO_REST
                timerStatus := "B"
            }
        } else {
            SoundPlay A_ScriptDir . "\audio\Sound2.mp3"
            ShowLabel(timeLeft, timerStatus, pomodoroCount)
            if (MsgBox("Start working?", "Pomodoro Timer Alert", 1) == "OK") {
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
        if (winClass != "AutoHotkeyGUI") { ; is MsgBox?
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