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