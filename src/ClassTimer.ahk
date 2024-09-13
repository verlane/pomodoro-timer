Class ClassTimer {
  __New(id, order, type, settingTimeSec, prevTotalElapsedTimeSec, totalElapsedTimeSec, prevTimer, nextTimer := false) {
    this.id := id
    this.order := order
    this.type := type
    this.settingTimeSec := settingTimeSec
    this.prevTotalElapsedTimeSec := prevTotalElapsedTimeSec
    this.totalElapsedTimeSec := totalElapsedTimeSec
    this.elapsedTimeSec := 0
    this.prevTimer := prevTimer
    this.nextTimer := nextTimer
  }

  static GetNextFocusingTimer(timer) {
    While (timer := timer.nextTimer) {
      if (timer.IsFocusingTimer()) {
        return timer
      }
    }
    return false
  }

  IsFocusingTimer() {
    return this.type == "F"
  }

  GetRemainingTimeSec() {
    return this.settingTimeSec - this.elapsedTimeSec
  }

  Ticktock() {
    this.elapsedTimeSec += 1
  }

  GetProgressValue() {
    return (this.prevTotalElapsedTimeSec + this.elapsedTimeSec - this.settingTimeSec) * 100 / this.totalElapsedTimeSec
  }

  Reset() {
    this.elapsedTimeSec := 0
  }

  ToString() {
    return "`n`n"
      . "Timer ID: " . this.id . "`n"
      . "Order: " . this.order . "`n"
      . "Type: " . this.type . "`n"
      . "Setting Time: " . this.settingTimeSec . " sec`n"
      . "Elapsed Time: " . this.elapsedTimeSec . " sec`n"
      . "Remaining Time: " . this.GetRemainingTimeSec() . " sec`n"
      . "Progress: " . Round(this.GetProgressValue(), 2) . "%`n"
      . "Is Focusing Timer: " . (this.IsFocusingTimer() ? "Yes" : "No") . "`n"
      . "Has Previous Timer: " . (this.prevTimer ? this.prevTimer.id : "") . "`n"
      . "Has Next Timer: " . (this.nextTimer ? this.nextTimer.id : "")
  }
}