#include <GUIConstantsEx.au3>
#include <TrayConstants.au3>

; ============================================================
;  MinimizeOnIdle.au3
;
;  Minimizes a target window after IDLE_THRESHOLD seconds
;  of no user input. Tray icon with pause/resume.
; ============================================================

Global Const $TARGET_CLASS   = "MozillaWindowClass"
Global Const $IDLE_THRESHOLD = 120   ; seconds
Global Const $CHECK_INTERVAL = 5000  ; ms
Global Const $LOG_FILE       = @ScriptDir & "\MinimizeOnIdle.log"

Global $bPaused   = False
Global $iLastCheck = 0

; --- Tray setup ---
Opt("TrayMenuMode", 3)
Opt("TrayOnEventMode", 1)

TraySetIcon("shell32.dll", 46)
TraySetToolTip("MinimizeOnIdle — Running")

Local $menuPause = TrayItemCreate("Pause",  $TRAY_ITEM_NORMAL)
Local $menuExit  = TrayItemCreate("Exit",   $TRAY_ITEM_NORMAL)

TrayItemSetOnEvent($menuPause, "_OnPauseToggle")
TrayItemSetOnEvent($menuExit,  "_OnExit")
TraySetState($TRAY_ICONSTATE_SHOW)

_Log("Started. Target: " & $TARGET_CLASS & ", Idle threshold: " & $IDLE_THRESHOLD & "s")

; --- Main loop ---
While True
    Sleep(250)  ; short sleep just to yield CPU, not for timing

    If $bPaused Then ContinueLoop

    Local $iNow = TimerInit()
    If TimerDiff($iLastCheck) < $CHECK_INTERVAL Then ContinueLoop
    $iLastCheck = TimerInit()

    Local $hwnd = _GetWindowHwnd($TARGET_CLASS)
    If $hwnd <> 0 And Not _IsMinimized($hwnd) Then
        Local $idleSec = _GetIdleSeconds()
        If $idleSec >= $IDLE_THRESHOLD Then
            WinSetState($hwnd, "", @SW_MINIMIZE)
            _Log("Minimized after " & $idleSec & "s idle")
        EndIf
    EndIf
Wend

; -------------------------------------------------------
Func _OnPauseToggle()
    $bPaused = Not $bPaused
    If $bPaused Then
        TrayItemSetText($menuPause, "Resume")
        TraySetIcon("shell32.dll", 131)
        TraySetToolTip("MinimizeOnIdle — Paused")
        _Log("Paused")
    Else
        TrayItemSetText($menuPause, "Pause")
        TraySetIcon("shell32.dll", 46)
        TraySetToolTip("MinimizeOnIdle — Running")
        _Log("Resumed")
    EndIf
EndFunc

Func _OnExit()
    _Log("Exited by user")
    Exit
EndFunc

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