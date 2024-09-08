#Requires AutoHotkey v2.0
#SingleInstance Force

; Global variables
global timerElements := []
global iniFile := A_ScriptDir "\pomodoro-timer.ini"

; GUI creation
settingGui := Gui()
settingGui.SetFont("s10", "Consolas")
settingGui.OnEvent("Close", (*) => ExitApp())
settingGui.Title := "Pomodoro Timer Settings"

; Top section
settingGui.Add("Text", "x10 y10 w380 h30", "Click buttons to edit items to the list below:")
focusBtn := settingGui.Add("Button", "x10 y40 w80 h30", "&Focus")
focusBtn.OnEvent("Click", (*) => AddTimer("F"))
breakBtn := settingGui.Add("Button", "x100 y40 w80 h30", "&Break")
breakBtn.OnEvent("Click", (*) => AddTimer("B"))
editBtn := settingGui.Add("Button", "x190 y40 w80 h30", "&Edit")
editBtn.OnEvent("Click", EditTimeMenu)
deleteBtn := settingGui.Add("Button", "x280 y40 w80 h30", "&Delete")
deleteBtn.OnEvent("Click", DeleteItem)

; Bottom section
timerDetailLV := settingGui.Add("ListView", "x10 y80 w380 h200 +Multi NoSortHdr", ["Order", "Type", "Time (min)"])
timerDetailLV.OnEvent("DoubleClick", EditTime)
timerDetailLV.OnEvent("ItemFocus", UpdateButtonStates)
timerDetailLV.OnNotify(-4, KeyHandler)
LV_TV_WantReturnSC.Register(timerDetailLV) ; register the LV
timerDetailLV.ModifyCol(1, "50 Right")  ; Order column
timerDetailLV.ModifyCol(2, "180")       ; Type column
timerDetailLV.ModifyCol(3, "100 Right") ; Time column

LVN_FIRST := 0 - 100
LVN_KEYDOWN := LVN_FIRST - 55
timerDetailLV.OnNotify(LVN_KEYDOWN, LV_OnKeyDown)
LV_OnKeyDown(timerDetailLV, lParam) {
  NMHDR_hwndFrom := NumGet(lParam, 0, 'Ptr')
  NMHDR_idFrom := NumGet(lParam, A_PtrSize, 'UInt')
  NMHDR_code := NumGet(lParam, 2 * A_PtrSize, 'UInt')
  LVKEYDOWN_wVKey := NumGet(lParam, 3 * A_PtrSize, 'UShort')
  ; LVKEYDOWN_flags ; is always 0
  if (LVKEYDOWN_wVKey == 46) { ; Del key
    DeleteItem()
  }
}

; Context menu
contextMenu := Menu()
contextMenu.Add("Edit Time", EditTimeMenu)
contextMenu.Add("Delete Item", DeleteItem)
timerDetailLV.OnEvent("ContextMenu", (*) => contextMenu.Show())

; Buttons
resetBtn := settingGui.Add("Button", "x10 y290 w80 h30", "&Reset")
resetBtn.OnEvent("Click", ResetSettings)

saveBtn := settingGui.Add("Button", "x100 y290 w80 h30 Default", "&Save")
saveBtn.OnEvent("Click", SaveSettings)

; GUI display
LoadSettings()
settingGui.Show()

; Add Timer function
AddTimer(type) {
  focusCount := 0
  selectedRow := timerDetailLV.GetNext(0, "Focused")

  Loop timerDetailLV.GetCount()
    if (timerDetailLV.GetText(A_Index, 2) == "Focus Time")
      focusCount++

  if (type == "F") {
    newRow := selectedRow ? selectedRow + 1 : timerDetailLV.GetCount() + 1
    timerDetailLV.Insert(newRow, , focusCount + 1, "Focus Time", "25")
  } else {
    newRow := selectedRow ? selectedRow + 1 : timerDetailLV.GetCount() + 1
    timerDetailLV.Insert(newRow, , "", "Break Time", "5")
  }

  UpdateOrder()
}

; Update order function
UpdateOrder() {
  focusCount := 0
  Loop timerDetailLV.GetCount() {
    if (timerDetailLV.GetText(A_Index, 2) == "Focus Time") {
      focusCount++
      timerDetailLV.Modify(A_Index, , focusCount)
    } else {
      timerDetailLV.Modify(A_Index, , "")
    }
  }
}

; 키 입력 이벤트 처리 함수
KeyHandler(*) {
  ; Enter 키가 눌렸을 때 현재 선택된 항목에 대해 시간 수정 호출
  focusedRow := timerDetailLV.GetNext(0, "Focused")
  if (focusedRow > 0) {
    EditTime(timerDetailLV, focusedRow)
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
  if (timerDetailLV.GetNext(0, "Focused") > 0)
    EditTime(timerDetailLV, timerDetailLV.GetNext(0, "Focused"))
}

; Context menu - Delete item
DeleteItem(*) {
  selectedRows := []
  row := 0

  while (row := timerDetailLV.GetNext(row)) {
    if (!row) {
      break
    }
    selectedRows.InsertAt(1, row)
  }

  for row in selectedRows {
    timerDetailLV.Delete(row)
    timerDetailLV.Modify(row, "Select")
  }

  UpdateOrder()
}

; Key input handling
HandleKeyPress(ThisHotkey, *) {
  switch ThisHotkey.Hotkey {
    case "Delete":
      DeleteItem()
    case "Enter":
      EditTimeMenu()
  }
}

; Move selected items
MoveSelectedItems(direction) {
  selectedRows := []
  row := 0
  while (row := timerDetailLV.GetNext(row, "Focused"))
    selectedRows.Push(row)

  if (direction == -1)
    selectedRows.Sort((a, b) => a - b)
  else
    selectedRows.Sort((a, b) => b - a)

  for currentRow in selectedRows {
    targetRow := currentRow + direction
    if (targetRow > 0 && targetRow <= timerDetailLV.GetCount()) {
      SwapRows(currentRow, targetRow)
    }
  }

  UpdateOrder()
}

; Swap rows
SwapRows(row1, row2) {
  data1 := [timerDetailLV.GetText(row1, 1), timerDetailLV.GetText(row1, 2), timerDetailLV.GetText(row1, 3)]
  data2 := [timerDetailLV.GetText(row2, 1), timerDetailLV.GetText(row2, 2), timerDetailLV.GetText(row2, 3)]

  timerDetailLV.Modify(row1, , data2[1], data2[2], data2[3])
  timerDetailLV.Modify(row2, , data1[1], data1[2], data1[3])

  if (timerDetailLV.GetNext(row1, "Focused"))
    timerDetailLV.Modify(row2, "Select Focus")
  else if (timerDetailLV.GetNext(row2, "Focused"))
    timerDetailLV.Modify(row1, "Select Focus")
}

; Save settings function
SaveSettings(*) {
  elements := []
  Loop timerDetailLV.GetCount() {
    elements.Push(timerDetailLV.GetText(A_Index, 2) . "," . timerDetailLV.GetText(A_Index, 3))
  }
  IniWrite(StrJoin(elements, "|"), iniFile, "Settings", "Elements")
  MsgBox("Settings have been saved.")
}

; Load settings function
LoadSettings() {
  if (FileExist(iniFile)) {
    elements := StrSplit(IniRead(iniFile, "Settings", "Elements", ""), "|")
    for element in elements {
      parts := StrSplit(element, ",")
      if (parts.Length == 2) {
        if (parts[1] == "Focus Time")
          timerDetailLV.Add(, "", parts[1], parts[2])
        else
          timerDetailLV.Add(, "", parts[1], parts[2])
      }
    }
    UpdateOrder()
  }
}

; Reset settings function
ResetSettings(*) {
  timerDetailLV.Delete()
  Loop 16 {
    timerDetailLV.Add(, A_Index, "Focus Time", "25")
    timerDetailLV.Add(, "", "Break Time", "5")
  }
}

; String join function
StrJoin(arr, delimiter) {
  result := ""
  for index, element in arr {
    if (index > 1)
      result .= delimiter
    result .= element
  }
  return result
}

; Update button states
UpdateButtonStates(*) {
  saveBtn.Enabled := (timerDetailLV.GetCount() > 0)
  resetBtn.Enabled := true
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