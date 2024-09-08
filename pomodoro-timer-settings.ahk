#Requires AutoHotkey v2.0
#SingleInstance Force

; Global variables
global iniFile := A_ScriptDir "\pomodoro-timer.ini"

settingGui := Setting()
settingGui.Show()

Class Setting {
  __New() {
    ; GUI creation
    this.settingGui := Gui()
    this.settingGui.SetFont("s10", "Consolas")
    this.settingGui.OnEvent("Close", (*) => ExitApp())
    this.settingGui.Title := "Pomodoro Timer Settings"

    ; Top section
    this.settingGui.Add("Text", "x10 y10 w350 h30", "Click buttons to edit items to the list below:")
    this.focusBtn := this.settingGui.Add("Button", "x10 y40 w80 h30", "&Focus")
    this.focusBtn.OnEvent("Click", (*) => this.AddTimer("F"))
    this.breakBtn := this.settingGui.Add("Button", "x100 y40 w80 h30", "&Break")
    this.breakBtn.OnEvent("Click", (*) => this.AddTimer("B"))
    this.editBtn := this.settingGui.Add("Button", "x190 y40 w80 h30", "&Edit")
    this.editBtn.OnEvent("Click", (*) => this.EditTimeMenu())
    this.deleteBtn := this.settingGui.Add("Button", "x280 y40 w80 h30", "&Delete")
    this.deleteBtn.OnEvent("Click", (*) => this.DeleteItem())

    ; Bottom section
    this.timerDetailLV := this.settingGui.Add("ListView", "x10 y80 w350 h200 +Multi NoSortHdr", ["Order", "Type", "Time (min)"])
    this.timerDetailLV.OnEvent("DoubleClick", ObjBindMethod(this, "EditTime"))
    this.timerDetailLV.OnEvent("ItemFocus", ObjBindMethod(this, "UpdateButtonStates"))
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

    this.startTimerAtStartupChk := this.settingGui.Add("Checkbox", "x10 y285 w180 h30", "Start Timer At Startup")
    this.autoStopWhenAwayChk := this.settingGui.Add("Checkbox", "x200 y285 w160 h30", "Auto Stop When Away")

    ; Buttons
    this.resetBtn := this.settingGui.Add("Button", "x10 y320 w80 h30", "&Reset")
    this.resetBtn.OnEvent("Click", ObjBindMethod(this, "ResetSettings"))

    this.saveBtn := this.settingGui.Add("Button", "x100 y320 w80 h30 Default", "&Save")
    this.saveBtn.OnEvent("Click", ObjBindMethod(this, "SaveSettings"))

    this.LoadSettings()
  }

  Show() {
    this.settingGui.Show()
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
    Loop this.timerDetailLV.GetCount() {
      timers.Push(this.timerDetailLV.GetText(A_Index, 2) . "," . this.timerDetailLV.GetText(A_Index, 3))
    }
    IniWrite(this.StrJoin(timers, "|"), iniFile, "General", "Timers")
    IniWrite(this.startTimerAtStartupChk.Value, iniFile, "General", "StartTimerAtStartup")
    IniWrite(this.autoStopWhenAwayChk.Value, iniFile, "General", "AutoStopWhenAway")
    MsgBox("Settings have been saved.")
  }

  ; Load settings function
  LoadSettings() {
    if (FileExist(iniFile)) {
      timers := StrSplit(IniRead(iniFile, "General", "Timers", ""), "|")
      for timer in timers {
        parts := StrSplit(timer, ",")
        if (parts.Length == 2) {
          if (parts[1] == "Focus Time")
            this.timerDetailLV.Add(, "", parts[1], parts[2])
          else
            this.timerDetailLV.Add(, "", parts[1], parts[2])
        }
      }

      if (timers.Length == 0) {
        this.ResetSettings()
        this.SaveSettings()
      }
      this.UpdateOrder()
    }
  }

  ; Reset settings function
  ResetSettings(*) {
    this.timerDetailLV.Delete()
    Loop 16 {
      this.timerDetailLV.Add(, A_Index, "Focus Time", "25")
      this.timerDetailLV.Add(, "", "Break Time", "5")
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

  ; Update button states
  UpdateButtonStates(*) {
    this.saveBtn.Enabled := (this.timerDetailLV.GetCount() > 0)
    this.resetBtn.Enabled := true
  }
}

; ======================================================================================================================
; LV_TV_WantReturnSC (SubClassing)
;     'Fakes' Return key processing for ListView and Treeview controls which otherwise won't process it.
;     If enabled, the control will receive a NM_RETURN (-4) notification whenever the Return key is pressed while
;     the control has the focus.
; Usage:
;     To register a control call the functions once and pass the Gui.Control object as the first parameter.
;     To deregister it, call the function again with the same Gui.Control object as the first parameter.
;     You may pass a function object in the second parameterto be used as subclassproc for the specified control.
;     This function must accept 6 parameters. Look at the built-in SubClassProc method for further details.
; ----------------------------------------------------------------------------------------------------------------------
; NM_RETURN    -> https://learn.microsoft.com/en-us/windows/win32/controls/nm-return-list-view-
;              -> https://learn.microsoft.com/en-us/windows/win32/controls/nm-return-tree-view-
; WM_KEYDOWN   -> https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-keydown
; ======================================================================================================================
Class LV_TV_WantReturnSC {
  Static Ctrls := Map()
  Static SCProc := CallbackCreate(ObjBindMethod(LV_TV_WantReturnSC, "SubClassProc"), , 6)
  ; -------------------------------------------------------------------------------------------------------------------
  Static Register(CtrlObj, SubClassProc?) {
    If (Type(CtrlObj) = "Gui.ListView") || (Type(CtrlObj) = "Gui.TreeView") {
      Local Hwnd := CtrlObj.Hwnd, SCP := 0
      If This.Ctrls.Has(Hwnd) { ; the control is already registered, remove it
        DllCall("RemoveWindowSubclass", "Ptr", Hwnd, "Ptr", This.Ctrls[Hwnd].SCP, "UPtr", Hwnd, "Int")
        This.Ctrls.Delete(Hwnd)
        Return True
      }
      SCP := IsSet(SubClassProc) && IsObject(SubClassProc) ? CallbackCreate(SubClassProc, , 6) : This.SCProc
      This.Ctrls[CtrlObj.Hwnd] := { CID: This.GetDlgCtrlID(Hwnd), HGUI: CtrlObj.Gui.Hwnd, SCP: SCP }
      Return DllCall("SetWindowSubclass", "Ptr", Hwnd, "Ptr", SCP, "Ptr", Hwnd, "Ptr", SCP, "UInt")
    }
    Return False
  }
  ; -------------------------------------------------------------------------------------------------------------------
  Static SubClassProc(HWND, Msg, wParam, lParam, ID, Data) {
    Static NMHDR := Buffer(24, 0) ; NMHDR structure 64-bit
    Static NM_RETURN := -4
    Switch Msg {
      Case 135: ; WM_GETDLGCODE (0x0087)
        If (wParam = 13) ; VK_RETURN
          Return 4 ; DLGC_WANTALLKEYS
        else If (wParam = 46) ; VK_DEL
          Return 4 ; DLGC_WANTALLKEYS
      Case 256: ; WM_KEYDOWN (0x0100)
        If (wParam = 13) { ; VK_RETURN
          Local Ctl := This.Ctrls[Hwnd]
          If !(lParam & 0x40000000) { ; not auto-repetition
            NumPut("Ptr", HWND, "Ptr", Ctl.CID, "Ptr", NM_RETURN, NMHDR)
            PostMessage(0x004E, Ctl.CID, NMHDR.Ptr, Ctl.HGUI) ; WM_NOTIFY
          }
          Return 0
        }
      Case 2:   ; WM_DESTROY (0x0002)
        DllCall("RemoveWindowSubclass", "Ptr", HWND, "Ptr", Data, "UPtr", Hwnd)
    }
    Return DllCall("DefSubclassProc", "Ptr", HWND, "UInt", Msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
  }
  ; -------------------------------------------------------------------------------------------------------------------
  Static GetDlgCtrlID(Hwnd) => DllCall("GetDlgCtrlID", "Ptr", Hwnd, "Int")
}