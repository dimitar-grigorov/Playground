#NoTrayIcon

; ============================================================
;  MinimizeOnIdle.au3
;
;  Minimizes a target window after IDLE_THRESHOLD seconds
;  of no user input.
; ============================================================

Global Const $TARGET_CLASS    = "MozillaWindowClass"  ; change to target a different app
Global Const $IDLE_THRESHOLD  = 120   ; seconds — adjust as needed
Global Const $CHECK_INTERVAL  = 5000  ; ms between checks
Global Const $LOG_FILE        = @ScriptDir & "\MinimizeOnIdle.log"

_Log("Started. Target: " & $TARGET_CLASS & ", Idle threshold: " & $IDLE_THRESHOLD & "s")

While True
    Local $hwnd = _GetWindowHwnd($TARGET_CLASS)

    If $hwnd <> 0 And Not _IsMinimized($hwnd) Then
        Local $idleSec = _GetIdleSeconds()
        If $idleSec >= $IDLE_THRESHOLD Then
            WinSetState($hwnd, "", @SW_MINIMIZE)
            _Log("Minimized after " & $idleSec & "s idle")
        EndIf
    EndIf

    Sleep($CHECK_INTERVAL)
Wend

; -------------------------------------------------------
Func _GetWindowHwnd($sClass)
    Local $hWnd = WinGetHandle("[CLASS:" & $sClass & "]")
    If @error Then Return 0
    Return $hWnd
EndFunc

Func _IsMinimized($hWnd)
    Return BitAND(WinGetState($hWnd), 16) <> 0
EndFunc

Func _GetIdleSeconds()
    Local $tInfo = DllStructCreate("uint cbSize;dword dwTime")
    DllStructSetData($tInfo, "cbSize", DllStructGetSize($tInfo))
    DllCall("user32.dll", "bool", "GetLastInputInfo", "ptr", DllStructGetPtr($tInfo))
    Local $dwTime = DllStructGetData($tInfo, "dwTime")
    Local $dwTick = DllCall("kernel32.dll", "dword", "GetTickCount")
    Return Int(($dwTick[0] - $dwTime) / 1000)
EndFunc

Func _Log($sMsg)
    Local $sLine = "[" & @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & "] " & $sMsg
    ConsoleWrite($sLine & @CRLF)
    FileWriteLine($LOG_FILE, $sLine)
EndFunc