Class ClassSetting {
  SECS := 60

  __New(main) {
    this.timers := []
    this.main := main
    this.mainGui := main.mainGui
    this.iniFile := main.INI_FILE

    ; GUI creation
    this.settingGui := Gui()
    this.settingGui.SetFont("s10", "Consolas")
    this.settingGui.Title := "Pomodoro Timer Settings"

    this.settingGui.OnEvent("Close", (*) => this.OnClose())

    ; Top section
    this.settingGui.Add("Text", "x10 y10 w350 h30", "Click buttons to edit items to the list below:")
    focusBtn := this.settingGui.Add("Button", "x10 y40 w80 h30", "&Focus")
    focusBtn.OnEvent("Click", (*) => this.AddTimer("F"))
    breakBtn := this.settingGui.Add("Button", "x100 y40 w80 h30", "&Break")
    breakBtn.OnEvent("Click", (*) => this.AddTimer("B"))
    editBtn := this.settingGui.Add("Button", "x190 y40 w80 h30", "&Edit")
    editBtn.OnEvent("Click", (*) => this.EditTimeMenu())
    deleteBtn := this.settingGui.Add("Button", "x280 y40 w80 h30", "&Delete")
    deleteBtn.OnEvent("Click", (*) => this.DeleteItem())

    ; Bottom section
    this.timerDetailLV := this.settingGui.Add("ListView", "x10 y80 w350 h200 +Multi NoSortHdr", ["Order", "Type", "Time (min)"])
    this.timerDetailLV.OnEvent("DoubleClick", ObjBindMethod(this, "EditTime"))
    this.timerDetailLV.OnNotify(-4, ObjBindMethod(this, "KeyHandler"))
    LV_TV_WantReturnSC.Register(this.timerDetailLV) ; register the LV
    this.timerDetailLV.ModifyCol(1, "50 Center")  ; Order column
    this.timerDetailLV.ModifyCol(2, "180")       ; Type column
    this.timerDetailLV.ModifyCol(3, "100 Right") ; Time column

    LVN_FIRST := 0 - 100
    LVN_KEYDOWN := LVN_FIRST - 55
    this.timerDetailLV.OnNotify(LVN_KEYDOWN, ObjBindMethod(this, "LV_OnKeyDown"))

    ; Context menu
    contextMenu := Menu()
    contextMenu.Add("Edit Time", ObjBindMethod(this, "EditTimeMenu"))
    contextMenu.Add("Delete Item", ObjBindMethod(this, "DeleteItem"))
    this.timerDetailLV.OnEvent("ContextMenu", (*) => contextMenu.Show())

    this.startTimerAtStartupChk := this.settingGui.Add("Checkbox", "x10 y285 w260 h20", "Start timer at startup")
    this.autoStopWhenAwayChk := this.settingGui.Add("Checkbox", "x10 y305 w260 h20", "Auto stop when away for 1 min")

    ; Buttons
    resetBtn := this.settingGui.Add("Button", "x10 y330 w80 h30", "&Reset")
    resetBtn.OnEvent("Click", ObjBindMethod(this, "ResetSettings"))

    saveBtn := this.settingGui.Add("Button", "x100 y330 w80 h30 Default", "&Save")
    saveBtn.OnEvent("Click", ObjBindMethod(this, "SaveSettings"))

    this.LoadSettings()
    this.LoadTimers()
  }

  GetLvLastOrder() {
    count := this.timerDetailLV.GetCount()
    Loop count {
      rowIndex := count - A_Index + 1
      if (this.__GetLvType(rowIndex) == "F") {
        return this.__GetLvOrder(rowIndex)
      }
    }
    return 1
  }

  LoadTimers() {
    this.timers := []

    prevTotalElapsedTimeSec := 1
    totalElapsedTimeSec := 1

    count := this.timerDetailLV.GetCount()
    Loop count {
      timeSec := this.__GetLvTimeSec(A_Index) * this.SECS
      if (this.__GetLvType(A_Index) == "F") {
        totalElapsedTimeSec += timeSec
      }
    }

    prevTimer := false
    Loop count {
      timeSec := this.__GetLvTimeSec(A_Index) * this.SECS

      currentTimer := ClassTimer(A_Index, this.__GetLvOrder(A_Index), this.__GetLvType(A_Index), this.__GetLvTimeSec(A_Index), prevTotalElapsedTimeSec, totalElapsedTimeSec, prevTimer)

      if (prevTimer) {
        prevTimer.nextTimer := currentTimer
      }

      this.timers.Push(currentTimer)
      prevTimer := currentTimer

      if (this.__GetLvType(A_Index) == "F") {
        prevTotalElapsedTimeSec += timeSec
      }
    }

    if (1 < this.timers.Length) {
      this.timers[this.timers.Length].nextTimer := this.GetNextFocusingTimerByPomodoroCount(this.timers.Length)
    }
  }

  GetNextFocusingTimerByPomodoroCount(pomodoroCount) {
    lastFocusingTimer := false

    for timer in this.timers {
      if (timer.order) {
        lastFocusingTimer := timer
        if (pomodoroCount < timer.order) {
          return timer
        }
      }
    }
    if (lastFocusingTimer) {
      return lastFocusingTimer
    }

    return timer[timer.Length]
  }

  GetNextBreakTimerByPomodoroCount(pomodoroCount) {
    breakTimer := false

    for timer in this.timers {
      if (timer.order) {
        lastFocusingTimer := timer
        if (pomodoroCount < timer.order && breakTimer) {
          return breakTimer
        }
      } else {
        breakTimer := timer
      }
    }
    if (breakTimer) {
      return breakTimer 
    }

    return timer[timer.Length]
  }

  GetTimer(timersArrayIndex) {
    if (timersArrayIndex > this.timers.Length) {
      return false
    }
    return this.timers[timersArrayIndex]
  }

  __GetLvOrder(rowIndex) {
    return this.__GetLvText(rowIndex, 1)
  }

  __GetLvType(rowIndex) {
    if (this.__GetLvText(rowIndex, 2) == "Focus Time") {
      return "F"
    }
    return "B"
  }

  __GetLvTimeSec(rowIndex) {
    return this.__GetLvText(rowIndex, 3) * this.SECS
  }

  __GetLvText(rowIndex, colIndex) {
    if (rowIndex > this.timerDetailLV.GetCount()) {
      rowIndex := this.timerDetailLV.GetCount()
    }
    return this.timerDetailLV.GetText(rowIndex, colIndex)
  }

  Show() {
    this.mainGui.Opt("+Disabled")  ; 부모 GUI 비활성화
    this.LoadSettings()
    this.settingGui.Show()
  }

  OnClose() {
    this.settingGui.Hide()
    this.mainGui.Opt("-Disabled")
    this.main.OnSettingGuiClosed()
  }

  LV_OnKeyDown(timerDetailLV, lParam) {
    NMHDR_hwndFrom := NumGet(lParam, 0, 'Ptr')
    NMHDR_idFrom := NumGet(lParam, A_PtrSize, 'UInt')
    NMHDR_code := NumGet(lParam, 2 * A_PtrSize, 'UInt')
    LVKEYDOWN_wVKey := NumGet(lParam, 3 * A_PtrSize, 'UShort')
    ; LVKEYDOWN_flags ; is always 0
    if (LVKEYDOWN_wVKey == 46) { ; Del key
      this.DeleteItem()
    }
  }

  ; Add Timer function
  AddTimer(type) {
    focusCount := 0
    selectedRow := this.timerDetailLV.GetNext(0, "Focused")

    Loop this.timerDetailLV.GetCount()
      if (this.timerDetailLV.GetText(A_Index, 2) == "Focus Time")
        focusCount++

    if (type == "F") {
      newRow := selectedRow ? selectedRow + 1 : this.timerDetailLV.GetCount() + 1
      this.timerDetailLV.Insert(newRow, , focusCount + 1, "Focus Time", "25")
    } else {
      newRow := selectedRow ? selectedRow + 1 : this.timerDetailLV.GetCount() + 1
      this.timerDetailLV.Insert(newRow, , "", "Break Time", "5")
    }

    this.UpdateOrder()
  }

  ; Update order function
  UpdateOrder() {
    focusCount := 0
    Loop this.timerDetailLV.GetCount() {
      if (this.timerDetailLV.GetText(A_Index, 2) == "Focus Time") {
        focusCount++
        this.timerDetailLV.Modify(A_Index, , focusCount)
      } else {
        this.timerDetailLV.Modify(A_Index, , "")
      }
    }
  }

  ; 키 입력 이벤트 처리 함수
  KeyHandler(*) {
    ; Enter 키가 눌렸을 때 현재 선택된 항목에 대해 시간 수정 호출
    focusedRow := this.timerDetailLV.GetNext(0, "Focused")
    if (focusedRow > 0) {
      this.EditTime(this.timerDetailLV, focusedRow)
    }
  }

  ; Edit time function
  EditTime(LV, RowNumber) {
    if (RowNumber > 0) {
      currentTime := LV.GetText(RowNumber, 3)
      newTime := InputBox("Enter new time (minutes):", "Edit Time", , currentTime)
      if (newTime.Result == "OK" && IsNumber(newTime.Value) && newTime.Value > 0) {
        LV.Modify(RowNumber, , , , newTime.Value)
      }
    }
  }

  ; Context menu - Edit time
  EditTimeMenu(*) {
    if (this.timerDetailLV.GetNext(0, "Focused") > 0)
      this.EditTime(this.timerDetailLV, this.timerDetailLV.GetNext(0, "Focused"))
  }

  ; Context menu - Delete item
  DeleteItem(*) {
    selectedRows := []
    row := 0

    while (row := this.timerDetailLV.GetNext(row)) {
      if (!row) {
        break
      }
      selectedRows.InsertAt(1, row)
    }

    for row in selectedRows {
      this.timerDetailLV.Delete(row)
      this.timerDetailLV.Modify(row, "Select")
    }

    this.UpdateOrder()
  }

  ; Key input handling
  HandleKeyPress(ThisHotkey, *) {
    switch ThisHotkey.Hotkey {
      case "Delete":
        this.DeleteItem()
      case "Enter":
        this.EditTimeMenu()
    }
  }

  ; Move selected items
  MoveSelectedItems(direction) {
    selectedRows := []
    row := 0
    while (row := this.timerDetailLV.GetNext(row, "Focused"))
      selectedRows.Push(row)

    if (direction == -1)
      selectedRows.Sort((a, b) => a - b)
    else
      selectedRows.Sort((a, b) => b - a)

    for currentRow in selectedRows {
      targetRow := currentRow + direction
      if (targetRow > 0 && targetRow <= this.timerDetailLV.GetCount()) {
        this.SwapRows(currentRow, targetRow)
      }
    }

    this.UpdateOrder()
  }

  ; Swap rows
  SwapRows(row1, row2) {
    data1 := [this.timerDetailLV.GetText(row1, 1), this.timerDetailLV.GetText(row1, 2), this.timerDetailLV.GetText(row1, 3)]
    data2 := [this.timerDetailLV.GetText(row2, 1), this.timerDetailLV.GetText(row2, 2), this.timerDetailLV.GetText(row2, 3)]

    this.timerDetailLV.Modify(row1, , data2[1], data2[2], data2[3])
    this.timerDetailLV.Modify(row2, , data1[1], data1[2], data1[3])

    if (this.timerDetailLV.GetNext(row1, "Focused"))
      this.timerDetailLV.Modify(row2, "Select Focus")
    else if (this.timerDetailLV.GetNext(row2, "Focused"))
      this.timerDetailLV.Modify(row1, "Select Focus")
  }

  ; Save settings function
  SaveSettings(*) {
    timers := []
    focusCount := 0
    breakCount := 0
    Loop this.timerDetailLV.GetCount() {
      timerType := this.timerDetailLV.GetText(A_Index, 2)
      timerDuration := this.timerDetailLV.GetText(A_Index, 3)
      timers.Push(timerType . "," . timerDuration)
      if (timerType == "Focus Time")
        focusCount++
      else if (timerType == "Break Time")
        breakCount++
    }
    
    if (focusCount == 0 || breakCount == 0) {
      MsgBox("Please register at least one Focus Time and one Break Time.")
      return
    }
    
    IniWrite(this.StrJoin(timers, "|"), this.iniFile, "General", "Timers")
    IniWrite(this.startTimerAtStartupChk.Value, this.iniFile, "General", "StartTimerAtStartup")
    IniWrite(this.autoStopWhenAwayChk.Value, this.iniFile, "General", "AutoStopWhenAway")
    this.LoadTimers()
    this.OnClose()
  }

  ; Load settings function
  LoadSettings() {
    this.timerDetailLV.Delete()
    timers := StrSplit(IniRead(this.iniFile, "General", "Timers", ""), "|")
    if (!FileExist(this.iniFile) || timers.Length == 0) {
      this.ResetSettings()
      this.SaveSettings()
    }
    for timer in timers {
      parts := StrSplit(timer, ",")
      if (parts.Length == 2) {
        if (parts[1] == "Focus Time")
          this.timerDetailLV.Add(, "", parts[1], parts[2])
        else
          this.timerDetailLV.Add(, "", parts[1], parts[2])
      }
    }
    this.UpdateOrder()
    this.startTimerAtStartupChk.Value := IniRead(this.iniFile, "General", "StartTimerAtStartup")
    this.autoStopWhenAwayChk.Value := IniRead(this.iniFile, "General", "AutoStopWhenAway")
  }

  ; Reset settings function
  ResetSettings(*) {
    this.timerDetailLV.Delete()
    Loop 16 {
      this.timerDetailLV.Add(, A_Index, "Focus Time", "25")
      if (Mod(A_Index, 4) == 0) {
        this.timerDetailLV.Add(, "", "Break Time", "15")
      } else {
        this.timerDetailLV.Add(, "", "Break Time", "5")
      }
    }
    this.startTimerAtStartupChk.Value := 1
    this.autoStopWhenAwayChk.Value := 1
  }

  ; String join function
  StrJoin(arr, delimiter) {
    result := ""
    for index, timer in arr {
      if (index > 1)
        result .= delimiter
      result .= timer
    }
    return result
  }
}