Class ClassMain {
  WINDOW_TITLE := "BSB Pomodoro Timer"

  TIME_TO_STOP_AUTO := 1 * 60 * 1000 ; 1 min
  GUI_MIN_WIDTH := 64
  GUI_MAX_WIDTH := 186
  INI_FILE := A_ScriptDir "\pomodoro-timer.ini"

  __New() {
    this.timerFunc := (*) => this.TimerHandler()

    this.positionX := this.GetIniValue("Position", "X", -1)
    this.positionY := this.GetIniValue("Position", "Y", -1)
    startTimerAtStartup := this.GetIniValue("General", "StartTimerAtStartup", true)
    autoStopWhenAway := this.GetIniValue("General", "AutoStopWhenAway", true)

    if (this.positionX < 0 || this.positionX > (A_ScreenWidth - 100)) {
      this.positionX := 0
    }
    if (this.positionY < 0 || this.positionY > (A_ScreenHeight - 100)) {
      this.positionY := 0
    }

    ; Tray Settings
    this.trayMenu := A_TrayMenu ; For convenience.
    this.trayMenu.Delete()
    this.trayMenu.Add("Start Timer", ObjBindMethod(this, "HandleStartOrStopOption"))
    this.trayMenu.Add()
    this.trayMenu.Add("&Prev Timer", ObjBindMethod(this, "HandleMoveTimerOption"))
    this.trayMenu.Add("&Next Timer", ObjBindMethod(this, "HandleMoveTimerOption"))
    this.trayMenu.Add()
    this.trayMenu.Add("+1 Pomodoro", ObjBindMethod(this, "HandleAddPomodoroOption"))
    this.trayMenu.Add("-1 Pomodoro", ObjBindMethod(this, "HandleAddPomodoroOption"))
    this.trayMenu.Add()
    this.trayMenu.Add("&Settings", (*) => this.ShowSettingGui())
    this.trayMenu.Add()
    this.trayMenu.Add("About", (*) => MsgBox("verlane/pomodoro-timer v0.1.0"))
    this.trayMenu.Add("&Reload", (*) => Reload())
    this.trayMenu.Add("E&xit", (*) => ExitApp())

    this.mainGui := Gui("-Caption -Border +ToolWindow +AlwaysOnTop +OwnDialogs +Owner", this.WINDOW_TITLE)
    this.mainGui.SetFont("s10", "Consolas")
    this.mainGui.OnEvent("Escape", (*) => this.StopTimer())
    OnMessage(0x204, OnWM_RBUTTONDOWN)
    OnWM_RBUTTONDOWN(*) {
      if (WinGetTitle() == this.WINDOW_TITLE) {
        this.trayMenu.Show()
      }
    }

    this.setting := ClassSetting(this)

    this.pomodoroCount := this.LoadPomodoroCount()
    this.currentTimer := this.setting.GetTimer(this.pomodoroCount + 1)

    workCountLabel := Format("{:02d}:00 {:02d}", Floor(this.currentTimer.settingTimeSec / 60), this.pomodoroCount)
    this.elapsedTimeText := this.mainGui.Add("Text", "x2 y3 w140 h20", workCountLabel)

    startTimerButton := this.mainGui.Add("Button", "x66 y0 w50 h20 Default", "&Start")
    startTimerButton.OnEvent("Click", (*) => this.StartTimer())

    stopTimerButton := this.mainGui.Add("Button", "x116 y0 w50 h20", "S&top")
    stopTimerButton.OnEvent("Click", (*) => this.StopTimer())

    quitButton := this.mainGui.Add("Button", "x166 y0 w20 h20", "&X")
    quitButton.OnEvent("Click", (*) => this.Quit())

    this.workCountProgress := this.mainGui.Add("Progress", "x-1 y0 w" . (this.GUI_MIN_WIDTH + 2) . " h3 -Smooth", (this.pomodoroCount * 100 / this.setting.GetLvLastOrder()))
    this.mainGui.Show("x" . this.positionX . " y" . this.positionY . " w" . this.GUI_MAX_WIDTH . " h20")

    OnMessage(0x200, ObjBindMethod(this, "PomoWmMouseMove"))

    if (startTimerAtStartup) {
      IniWrite(true, this.INI_FILE, "General", "StartTimerAtStartup")
      this.StartTimer()
    }

    if (autoStopWhenAway) {
      IniWrite(true, this.INI_FILE, "General", "AutoStopWhenAway")
    }

    this.LoadSetting()
    this.UpdatePrevPomodoroMenuState()
  }

  OnSettingGuiClosed() {
    this.LoadSetting()
  }

  LoadSetting() {
    tmpCurrentTimer := this.currentTimer
    if (this.currentTimer.IsFocusingTimer()) {
      this.currentTimer := this.setting.GetNextFocusingTimerByPomodoroCount(this.pomodoroCount)
    } else {
      this.currentTimer := this.setting.GetNextBreakTimerByPomodoroCount(this.pomodoroCount)
    }
    if (tmpCurrentTimer) {
      this.currentTimer.elapsedTimeSec := tmpCurrentTimer.elapsedTimeSec
    }
  }

  HandleStartOrStopOption(menuItemName, callbackOrSubmenu, options) {
    if (menuItemName == "Start Timer") {
      this.StartTimer()
    } else {
      this.StopTimer()
    }
  }

  HandleAddPomodoroOption(menuItemName, callbackOrSubmenu, options) {
    if (RegExMatch(menuItemName, "i)^([`+`-][0-9]+) Pomodoro$", &SubPat)) {
      this.pomodoroCount := this.pomodoroCount + SubPat[1]
      if (this.pomodoroCount < 0) {
        this.pomodoroCount := 0
      }
      this.WritePomodoroCount(this.pomodoroCount)
      this.LoadSetting()
      this.TimerHandler()
      this.UpdatePrevPomodoroMenuState()
    }
  }

  HandleMoveTimerOption(menuItemName, callbackOrSubmenu, options) {
    if (menuItemName == "&Prev Timer") {
      prevTimer := this.currentTimer.prevTimer
      if (prevTimer) {
        this.currentTimer := prevTimer
        if (this.currentTimer.IsFocusingTimer() && this.pomodoroCount > 0) {
          this.pomodoroCount -= 1
        }
      }
    } else if (menuItemName == "&Next Timer") {
      nextTimer := this.currentTimer.nextTimer
      if (nextTimer) {
        if (this.currentTimer.IsFocusingTimer()) {
          this.pomodoroCount += 1
        }
        this.currentTimer := nextTimer
      }
    }

    if (this.currentTimer.IsFocusingTimer()) {
      this.WritePomodoroCount(this.pomodoroCount)
    }

    this.LoadSetting()
    this.TimerHandler()
    this.UpdatePrevPomodoroMenuState()
  }

  UpdatePrevPomodoroMenuState() {
    if (this.pomodoroCount == 0) {
      this.trayMenu.Disable("&Prev Timer")
    } else {
      this.trayMenu.Enable("&Prev Timer")
    }
  }

  ShowSettingGui() {
    this.setting.Show()
  }

  StartTimer() {
    try {
      this.trayMenu.Rename("Start Timer", "Stop Timer")
    } catch TargetError as err {
    }
    this.mainGui.Submit(false)
    this.ShowGui(false)
    SetTimer(this.timerFunc, 1000)
  }

  StopTimer() {
    try {
      this.trayMenu.Rename("Stop Timer", "Start Timer")
    } catch TargetError as err {
    }
    this.ShowGui()
    this.mainGui.BackColor := this.GetDefaultGuiColor()
    SetTimer(this.timerFunc, 0)
  }

  TimerHandler() {
    this.mainGui.Opt("+AlwaysOnTop")
    if (this.currentTimer.IsFocusingTimer() && A_TimeIdlePhysical >= this.TIME_TO_STOP_AUTO) {
      this.mainGui.BackColor := 0x555555
      this.elapsedTimeText.Opt("+cWhite")
      return
    }

    this.elapsedTimeText.Opt("+c" . this.GetDefaultGuiColor(8))
    if (this.currentTimer.IsFocusingTimer()) {
      this.mainGui.BackColor := 0xFFFFFF
    } else {
      this.mainGui.BackColor := 0xFACF2C ; yellow
    }

    this.currentTimer.Ticktock()
    remainingTimeSec := this.currentTimer.GetRemainingTimeSec()
    this.workCountProgress.Value := this.currentTimer.GetProgressValue()
    if (this.workCountProgress.Value >= 100) {
      this.workCountProgress.Opt("+cBlue")
    }

    if (0 < remainingTimeSec) {
      this.ShowLabel(remainingTimeSec, this.currentTimer.type, this.pomodoroCount)
      return
    }

    if (this.currentTimer.IsFocusingTimer()) {
      SoundPlay A_ScriptDir . "\audio\Sound1.mp3"
      this.pomodoroCount := this.pomodoroCount + 1
      this.WritePomodoroCount(this.pomodoroCount)
      this.UpdatePrevPomodoroMenuState()
    } else {
      SoundPlay A_ScriptDir . "\audio\Sound2.mp3"
    }
    this.ShowLabel(remainingTimeSec, this.currentTimer.type, this.pomodoroCount)

    nextTimer := this.currentTimer.nextTimer
    if (this.currentTimer.type != nextTimer.type) {
      if (this.currentTimer.IsFocusingTimer()) {
        if (this.MsgBoxEx("To keep focusing?") == "Yes") {
          this.currentTimer := ClassTimer.GetNextFocusingTimer(this.currentTimer)
        } else {
          this.currentTimer := nextTimer
        }
      } else {
        if (this.MsgBoxEx("Start focusing?") != "Yes") {
          this.StopTimer()
        }
        this.currentTimer := nextTimer
      }
    } else {
      this.currentTimer := nextTimer
    }

    this.currentTimer.Reset()
  }

  Quit() {
    ExitApp
  }

  ShowGui(fullFlag := true) {
    if (fullFlag) {
      this.mainGui.Show("x" . this.positionX . " y" . this.positionY . " w" . this.GUI_MAX_WIDTH . " h20")
    } else {
      this.mainGui.Show("x" . this.positionX . " y" . this.positionY . " w" . this.GUI_MIN_WIDTH . " h20")
    }
  }

  ShowLabel(timeLeft, timerStatus, pomodoroCount) {
    minutesLeft := floor(timeLeft / 60)
    secondsLeft := mod(timeLeft, 60)
    this.elapsedTimeText.Text := Format("{:02d}:{:02d} {:02d}", minutesLeft, secondsleft, pomodoroCount)
  }

  WritePomodoroCount(count) {
    nDate := FormatTime(A_Now, "yyyyMMdd")
    IniWrite(count, "pomodoro-timer.ini", "Date", nDate)
  }

  LoadPomodoroCount() {
    nDate := FormatTime(A_Now, "yyyyMMdd")
    count := this.GetIniValue("Date", nDate, 0)
    if (count == "ERROR") {
      count := 0
      IniWrite(count, "pomodoro-timer.ini", "Date", nDate)
    }
    return count
  }

  PomoWmMouseMove(wparam, lparam, msg, hwnd) {
    if (wparam = 1) { ; LButton
      try {
        winClass := WinGetClass("A")
        winTitle := WinGetTitle("A")
        if (winClass != "AutoHotkeyGUI" || winTitle == "Pomodoro Timer Alert" || winTitle == "Pomodoro Timer Settings") { ; is MsgBox?
          return
        }
        PostMessage 0xA1, 2, , , "A" ; WM_NCLBUTTONDOWN
        this.SavePosition()
      } catch TargetError as err {
      }
    }
  }

  GetDefaultGuiColor(elementIndex := 15) {
    ; http://msdn.microsoft.com/en-us/library/ms724371%28VS.85%29.aspx
    defaultGUIColor := DllCall("User32.dll\GetSysColor", "Int", elementIndex, "UInt")
    R := defaultGUIColor & 0xFF
    G := (defaultGUIColor >> 8) & 0xFF
    B := (defaultGUIColor >> 16) & 0xFF
    hex := Format("{:02X}{:02X}{:02X}", R, G, B)
    return hex
  }

  SavePosition() {
    WinGetPos(&positionX, &positionY, &width, &height)
    this.positionX := positionX
    this.positionY := positionY

    if ((this.positionX - 20) < 0) {
      this.positionX := 0
    }
    if ((this.positionY - 20) < 0) {
      this.positionY := 0
    }
    IniWrite(this.positionX, "pomodoro-timer.ini", "Position", "X")
    IniWrite(this.positionY, "pomodoro-timer.ini", "Position", "Y")
    WinMove this.positionX, this.positionY, , , "ahk_id " this.mainGui.Hwnd
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
    msgBoxGui.OnEvent("Close", (*) => this.SetMsgBoxExResult("No", &result, msgBoxGui))
    okButton.OnEvent("Click", (*) => this.SetMsgBoxExResult("Yes", &result, msgBoxGui))
    cancelButton.OnEvent("Click", (*) => this.SetMsgBoxExResult("No", &result, msgBoxGui))
    msgBoxGui.OnEvent("Escape", (*) => this.SetMsgBoxExResult("No", &result, msgBoxGui))

    While (result == "") {
      Sleep(100)
    }

    return result
  }

  SetMsgBoxExResult(value, &result, msgBoxGui) {
    result := value
    msgBoxGui.Destroy()
  }
}