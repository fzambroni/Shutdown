#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=shutdown.ico
#AutoIt3Wrapper_Res_Fileversion=4.0.0.5
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_File_Add=E:\GitHub\Shutdown\shutdown.ico
#AutoIt3Wrapper_Res_File_Add=E:\GitHub\Shutdown\beep-01a.wav
#AutoIt3Wrapper_Res_File_Add=E:\GitHub\Shutdown\beep-07.wav
#AutoIt3Wrapper_Res_File_Add=E:\GitHub\Shutdown\Updater_Shutdown.exe
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****


#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <Date.au3>
#include <MsgBoxConstants.au3>
#include <TrayConstants.au3>
#include <FontConstants.au3>
#include <Array.au3>
#include <GDIPlus.au3>
#include <File.au3>
#include <ListBoxConstants.au3>
#include <EditConstants.au3>
#include <GuiStatusBar.au3>
#include <Constants.au3>
#include <Misc.au3>
#include <ProgressConstants.au3>

Opt("TrayIconHide",    1)
Opt("TrayAutoPause",   0)
Opt("TrayMenuMode",    3)
Opt("MouseCoordMode",  1) ; Absolute screen coordinates (required for multi-monitor)

$shutdown_ico = @TempDir & "\Shutdown.ico"
FileInstall("shutdown.ico", $shutdown_ico, 1)

$beep_01a_wav = @TempDir & "\beep-01a.wav"
FileInstall("beep-01a.wav", $beep_01a_wav, 1)

$beep_07_wav = @TempDir & "\beep-07.wav"
FileInstall("beep-07.wav", $beep_07_wav, 1)

; =============================================================================
; CONSTANTS
; =============================================================================
; Query Windows for the real dialog background color (COLOR_BTNFACE = 15).
; Using -1 only tells AutoIt to "forget" the color but does NOT force a repaint,
; so an orange/red window stays orange until Windows decides to redraw on its own.
; Querying the actual RGB value and calling RedrawWindow guarantees an immediate reset.
Global Const $COLOR_BK_DEFAULT  = _WinAPIGetBtnFace() ; Real Windows gray (theme-aware)
Global Const $COLOR_BK_WARNING  = 0xFF6600  ; Orange  – last 30 s (flash phase A)
Global Const $COLOR_BK_ALERT    = 0xCC0000  ; Red     – reserved for future use
Global Const $COLOR_TEXT_NORMAL = 0x000000  ; Black   – normal state
Global Const $COLOR_TEXT_RED    = 0xBB0000  ; Dark red – warning text on default bg
;~ Global Const $COLOR_WHITE       = 0xFFFFFF  ; White   – text on coloured bg

Global $UpdatePath = "\\lp16-fzi1-dsa\Shutdown"

; Returns the current Windows dialog-background color (COLOR_BTNFACE).
; GetSysColor() returns a COLORREF (0x00BBGGRR), so bytes must be swapped to AutoIt's 0xRRGGBB.
Func _WinAPIGetBtnFace()
    Local $iBGR = DllCall("user32.dll", "int", "GetSysColor", "int", 15)[0]
    ; Swap R and B channels:  0x00BBGGRR  →  0xRRGGBB
    Local $r = BitAND($iBGR,       0x0000FF)
    Local $g = BitAND(BitShift($iBGR, -8),  0xFF) ; BitShift with negative = left shift
    ; Corrected swap using BitAND and division/multiplication:
    $r = BitAND($iBGR, 0xFF)
    $g = BitAND(Int($iBGR / 0x100), 0xFF)
    Local $b = BitAND(Int($iBGR / 0x10000), 0xFF)
    Return BitOR(BitOR($r * 0x10000, $g * 0x100), $b)
EndFunc

; Restores the form background to the Windows default and forces an immediate full repaint.
; Must be called with the window handle (WinGetHandle($Form_Main)) AFTER the GUI is created.
Func _ResetBkColor($hWnd)
    GUISetBkColor($COLOR_BK_DEFAULT, $hWnd)
    ; RDW_ERASE=0x04 | RDW_INVALIDATE=0x01 | RDW_UPDATENOW=0x100 | RDW_ALLCHILDREN=0x80
    DllCall("user32.dll", "bool", "RedrawWindow", "hwnd", WinGetHandle($hWnd), "ptr", 0, "ptr", 0, "uint", 0x0185)
EndFunc

; Windows API constants for multi-monitor
;~ Global Const $SM_XVIRTUALSCREEN  = 76
;~ Global Const $SM_YVIRTUALSCREEN  = 77
;~ Global Const $SM_CXVIRTUALSCREEN = 78
;~ Global Const $SM_CYVIRTUALSCREEN = 79

; =============================================================================
; GLOBAL STATE VARIABLES
; =============================================================================
Global $g_iStart           = 0
Global $g_iFloatWinShow    = 0
Global $g_iLockMouseMove   = 1
Global $g_iRed             = 1
Global $g_iBeepCount       = 2
Global $g_iBeepTimeSec     = -1
Global $g_iSecBuff         = -1
Global $g_iSecBuff2        = -1
Global $g_iMouseCount      = 0
Global $g_aMousePos[2]     = [0, 0]
Global $g_aMousePosHist[2] = [0, 0]
Global $g_hTimer           = TimerInit()
Global $g_hDLL             = DllOpen("user32.dll")
Global $g_sLogPath         = @ScriptDir & "\" & @ComputerName & "_" & @UserName & ".log"
Global $g_sEndDate         = ""
Global $g_iTotalSeconds    = 1
Global $TimerInHours       = "00"
Global $TimerInMinutes     = "00"
Global $TimerInSeconds     = "00"

; =============================================================================
; MULTI-MONITOR VIRTUAL SCREEN METRICS
; Queried once at startup - covers ALL monitors in the setup
; =============================================================================
Global $g_iVirtX = _SysMetric($SM_XVIRTUALSCREEN)   ; Left edge of virtual screen
Global $g_iVirtY = _SysMetric($SM_YVIRTUALSCREEN)   ; Top edge of virtual screen
Global $g_iVirtW = _SysMetric($SM_CXVIRTUALSCREEN)  ; Total width across all monitors
Global $g_iVirtH = _SysMetric($SM_CYVIRTUALSCREEN)  ; Total height across all monitors


; =============================================================================
; Update
; =============================================================================
$UpdatedVersion = FileGetVersion($UpdatePath & "\shutdown.exe")
$currentVersion = FileGetVersion(@ScriptDir & "\shutdown.exe")

If $UpdatedVersion > $currentVersion Then
	FileCopy($UpdatePath & "\shutdown.exe", @ScriptDir & "\shutdown.tmp", 9)
EndIf





; =============================================================================
; INITIALISATION
; =============================================================================
_InitLog()
;~ _CheckRequiredFiles()
_CheckSingleInstance()

_GDIPlus_Startup()
Global $g_hImageIcon = _GDIPlus_ImageLoadFromFile($shutdown_ico)

; Floating notification window (hidden at startup)
Global $g_ahNotify[2]
$g_ahNotify = _CreateNotifyWin("This device will shut down soon...", "Countdown initialising...", $g_hImageIcon, 0, 0)
WinSetTrans($g_ahNotify[0], "", 220)
GUISetState(@SW_HIDE, $g_ahNotify[0])

; =============================================================================
; MAIN FORM  (345 x 280)
; Layout:  Left column = controls (10..268)  |  Right column = history (274..338)
; =============================================================================
;~ Global $Form_Main = GUICreate("Time Control", 348, 282, -1, -1)
Global $Form_Main = GUICreate("Time Control", 348, 320, -1, -1)
GUISetBkColor($COLOR_BK_DEFAULT, $Form_Main) ; Windows default gray (theme-aware)

; --- Update Button ---
$Button_Update = GUICtrlCreateButton("UPDATE AVAILABLE - Click to execute", 8, 255, 258, 40, $SS_CENTER)
GUICtrlSetColor($Button_Update, 0xFF0000)
GUICtrlSetFont($Button_Update, 8, 700)
;~ GUICtrlSetState($Button_Update, $GUI_HIDE)

If FileExists(@ScriptDir & "\shutdown.tmp") Then
	GUICtrlSetState($Button_Update, $GUI_SHOW)
Else
	GUICtrlSetState($Button_Update, $GUI_HIDE)
EndIf

; --- Status bar ---
Global $StatusBar = _GUICtrlStatusBar_Create($Form_Main)
Dim $aBarParts[2] = [88, -1]
_GUICtrlStatusBar_SetParts($StatusBar, $aBarParts)
_GUICtrlStatusBar_SetText($StatusBar, FileGetVersion(@ScriptFullPath), 0)
_GUICtrlStatusBar_SetText($StatusBar, "Dev. By Fabricio Zambroni", 1)

; ---------------------------------------------------------------------------
; ACTION GROUP  –  Shutdown / Restart / Hibernate / Stop / Close
; ---------------------------------------------------------------------------
GUICtrlCreateGroup("", 6, 5, 335, 33)
Global $Radio_Shutdown  = GUICtrlCreateRadio("Shutdown",  14,  16,  63, 16)
Global $Radio_Restart   = GUICtrlCreateRadio("Restart",   80,  16,  55, 16)
Global $Radio_Hibernate = GUICtrlCreateRadio("Hibernate", 135, 16,  68, 16)
Global $Radio_StopTimer = GUICtrlCreateRadio("Stop",      206, 16,  48, 16)
Global $Radio_Close     = GUICtrlCreateRadio("Close",     257, 16,  55, 16)
GUICtrlCreateGroup("", -99, -99, 1, 1)
_RestoreRadioState()

; --- Action descriptions (small label updated dynamically) ---
Global $Label_ActionDesc = GUICtrlCreateLabel("Powered off", 8, 42, 258, 14, $SS_CENTER)
GUICtrlSetFont(-1, 7, 400, 2, "Arial")
GUICtrlSetColor(-1, $COLOR_TEXT_NORMAL)
_UpdateActionDesc()

; ---------------------------------------------------------------------------
; TIME MODE GROUP  –  Specific Time vs Duration
; ---------------------------------------------------------------------------
GUICtrlCreateGroup("Mode", 8, 52, 258, 33)
Global $Radio_FixedTime = GUICtrlCreateRadio("Specific Time",  18, 65,  90, 16)
Global $Radio_Duration  = GUICtrlCreateRadio("Duration H:M",  118, 65,  90, 16)
GUICtrlCreateGroup("", -99, -99, 1, 1)
If RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "TimeMode") = "1" Then
    GUICtrlSetState($Radio_Duration,  $GUI_CHECKED)
Else
    GUICtrlSetState($Radio_FixedTime, $GUI_CHECKED)
EndIf

; ---------------------------------------------------------------------------
; TIME PICKERS  +  START / CANCEL
; ---------------------------------------------------------------------------
GUICtrlCreateLabel("H",  10, 93, 12, 16, $SS_CENTER)
GUICtrlSetFont(-1, 8, 700, 0, "Arial")
GUICtrlSetColor(-1, $COLOR_TEXT_NORMAL)
Global $Combo_Hora = GUICtrlCreateCombo("", 22, 90, 50, 24, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
GUICtrlSetData($Combo_Hora, _BuildNumList(0, 23, "%02d"), RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Hour"))

GUICtrlCreateLabel("M",  78, 93, 12, 16, $SS_CENTER)
GUICtrlSetFont(-1, 8, 700, 0, "Arial")
GUICtrlSetColor(-1, $COLOR_TEXT_NORMAL)
Global $Combo_Minuto = GUICtrlCreateCombo("", 90, 90, 50, 24)
GUICtrlSetData($Combo_Minuto, _BuildNumList(0, 59, "%02d"), RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Minute"))

Global $Button_Start  = GUICtrlCreateButton("START",  148, 89, 64, 26)
GUICtrlSetBkColor($Button_Start, 0x007700)
GUICtrlSetFont(-1, 9, 700, 0, "Arial")
GUICtrlSetColor($Button_Start, 0xFFFFFF)

Global $Button_Cancel = GUICtrlCreateCheckbox("STOP", 148, 88, 64, 26, $BS_PUSHLIKE)
GUICtrlSetBkColor($Button_Cancel, 0xBB0000)
GUICtrlSetFont(-1, 9, 700, 0, "Arial")
GUICtrlSetState($Button_Cancel, $GUI_HIDE)

Global $Label_Mode = GUICtrlCreateLabel("Defined time", 216, 94, 52, 14, $SS_CENTER)
GUICtrlSetFont(-1, 7, 400, 2, "Arial")
GUICtrlSetColor(-1, $COLOR_TEXT_NORMAL)

; ---------------------------------------------------------------------------
; COUNTDOWN DISPLAY
; ---------------------------------------------------------------------------
GUICtrlCreateGroup("", 8, 112, 258, 40)
Global $Label_Countdown = GUICtrlCreateLabel("00:00:00", 14, 121, 246, 28, $SS_CENTER)
GUICtrlSetFont(-1, 22, 700, 0, "Courier New")
GUICtrlSetColor(-1, $COLOR_TEXT_NORMAL)
GUICtrlCreateGroup("", -99, -99, 1, 1)

; ---------------------------------------------------------------------------
; PROGRESS BAR
; ---------------------------------------------------------------------------
Global $ProgressBar = GUICtrlCreateProgress(8, 155, 258, 9)

; ---------------------------------------------------------------------------
; OPTIONS ROW 1  –  Sound
; ---------------------------------------------------------------------------
Global $Check_Sound = GUICtrlCreateCheckbox("Play Sound   Vol:", 8, 170, 112, 17)
GUICtrlSetColor(-1, $COLOR_TEXT_NORMAL)
_RestoreCheck($Check_Sound, "Sound")
Local $sVol = RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Volume_Set")
If $sVol = "" Then $sVol = "30"
Global $Combo_Volume = GUICtrlCreateCombo("", 122, 169, 46, 22, $CBS_DROPDOWNLIST)
GUICtrlSetData($Combo_Volume, "5|10|20|30|40|50|60|70|80|90|100", $sVol)
Global $Button_TestSound = GUICtrlCreateButton("Test", 172, 170, 36, 16)
GUICtrlSetFont($Button_TestSound, 7, 400, 0, "Arial")

; ---------------------------------------------------------------------------
; OPTIONS ROW 2  –  Tray
; ---------------------------------------------------------------------------
Global $Check_Tray = GUICtrlCreateCheckbox("Minimize to tray", 8, 192, 120, 17)
GUICtrlSetColor(-1, $COLOR_TEXT_NORMAL)
_RestoreCheck($Check_Tray, "TrayCheck")

; ---------------------------------------------------------------------------
; OPTIONS ROW 3  –  Mouse keep-alive
; ---------------------------------------------------------------------------
Global $Check_MouseMove = GUICtrlCreateCheckbox("Mouse jigger Sens:", 8, 212, 110, 17)
GUICtrlSetColor(-1, $COLOR_TEXT_NORMAL)
_RestoreCheck($Check_MouseMove, "MouseMove")

Local $sSens = RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "MouseSensitivity")
If $sSens = "" Then $sSens = "20"
Global $Combo_MouseSens = GUICtrlCreateCombo("", 122, 207, 46, 22, $CBS_DROPDOWNLIST)
GUICtrlSetData($Combo_MouseSens, "10|20|30|40|50|60|70|80|90|100|200|300|400|500", $sSens)

GUICtrlCreateLabel("Spd:", 180, 209, 26, 14)
GUICtrlSetColor(-1, $COLOR_TEXT_NORMAL)
Local $sSpd = RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "MouseSpeed")
If $sSpd = "" Then $sSpd = "20"
Global $Combo_MouseSpeed = GUICtrlCreateCombo("", 210, 207, 28, 22, $CBS_DROPDOWNLIST)
GUICtrlSetData($Combo_MouseSpeed, "0|5|10|20|30|40|50|60|70|80|90|100", $sSpd)

; ---------------------------------------------------------------------------
; OPTIONS ROW 4  –  Whisper mode
; ---------------------------------------------------------------------------
Global $Check_Whisper = GUICtrlCreateCheckbox("Whisper mode (subtle micro-jiggle only)", 8, 230, 250, 17)
GUICtrlSetColor(-1, $COLOR_TEXT_NORMAL)
_RestoreCheck($Check_Whisper, "Whisper")

; ---------------------------------------------------------------------------
; HISTORY LIST  (right column)
; ---------------------------------------------------------------------------
Global $List_History = GUICtrlCreateList("", 274, 57, 66, 200)
Local $sHist = _CleanPipes(RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "History"))
GUICtrlSetData($List_History, $sHist)
GUICtrlSetFont($List_History, 7, 700, 0, "Courier New")
GUICtrlSetBkColor($List_History, 0xFFFFFF)   ; white listbox on gray form
GUICtrlSetColor($List_History, 0x000000)      ; black text

Global $Button_ClearHistory = GUICtrlCreateButton("CLEAR", 274, 270, 66, 18)
GUICtrlSetFont($Button_ClearHistory, 7, 400, 0, "Arial")

; ---------------------------------------------------------------------------
; TRAY MENU
; ---------------------------------------------------------------------------
Global $iTray_Restore = TrayCreateItem("Restore")
TrayCreateItem("")
Global $iTray_Stop = TrayCreateItem("STOP")
TrayCreateItem("")
Global $iTray_Exit = TrayCreateItem("Exit")

; =============================================================================
; SHOW MAIN WINDOW
; =============================================================================
GUISetState(@SW_SHOW,    $Form_Main)
GUISetState(@SW_RESTORE, $Form_Main)
$g_hTimer = TimerInit()

; =============================================================================
; MAIN LOOP
; =============================================================================
While 1
    Local $nMsg  = GUIGetMsg($Form_Main)
    Local $nMsg2 = GUIGetMsg($g_ahNotify[0])
    Local $TMsg  = TrayGetMsg()

    ; ---- Reset mouse counter on any mouse button press ----
    If _IsPressed("01", $g_hDLL) Or _IsPressed("02", $g_hDLL) Or _IsPressed("04", $g_hDLL) Or _IsPressed("05", $g_hDLL) Then
        $g_iMouseCount = 0
    EndIf

    ; ---- Tray events ----
    Switch $TMsg
        Case $TRAY_EVENT_PRIMARYDOUBLE, $iTray_Restore
            _ShowMainWindow()
        Case $iTray_Stop
            TraySetState(9)
            _Stop()
        Case $iTray_Exit
            _AppExit()
    EndSwitch

    ; ---- Floating notification events ----
    Switch $nMsg2
        Case $GUI_EVENT_CLOSE, $g_ahNotify[1]
            GUIDelete($g_ahNotify[0])
            $g_iFloatWinShow = 1   ; force recreation on next tick
            _ShowMainWindow()
        Case $GUI_EVENT_PRIMARYDOWN, $GUI_EVENT_SECONDARYDOWN
            $g_iMouseCount = 0
    EndSwitch

    ; ---- Main form events ----
    Switch $nMsg
		Case $Button_Update
			$Updater_File = @TempDir & "\Updater_Shutdown.exe"
			FileInstall("Updater_Shutdown.exe", $Updater_File, 1)
			Sleep(500)
			Run(@TempDir & "\Updater_Shutdown.exe '" & @ScriptDir & "'")
;~ 			Run($Updater_File)
			Sleep(500)
			Exit

        Case $GUI_EVENT_CLOSE
            _AppExit()

        Case $GUI_EVENT_MINIMIZE
            If GUICtrlRead($Check_Tray) = $GUI_CHECKED Then
                GUISetState(@SW_HIDE, $Form_Main)
                Opt("TrayIconHide", 0)
            EndIf

        Case $GUI_EVENT_PRIMARYDOWN, $GUI_EVENT_SECONDARYDOWN
            $g_iMouseCount = 0

        ; -- Action radio buttons --
        Case $Radio_Shutdown, $Radio_Restart, $Radio_Hibernate, $Radio_StopTimer, $Radio_Close
            _SaveRadioState()
            _UpdateActionDesc()

        ; -- Mode radio buttons --
        Case $Radio_FixedTime
            RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "TimeMode", "REG_SZ", "0")
            _UpdateModeLabel()
        Case $Radio_Duration
            RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "TimeMode", "REG_SZ", "1")
            _UpdateModeLabel()

        ; -- Start / Cancel --
        Case $Button_Start
            _StartTimer()
        Case $Button_Cancel
            _Stop()
            TraySetState(10)

        ; -- History --
        Case $List_History
            Local $sItem = GUICtrlRead($List_History)
            If $sItem <> "" Then
                Local $aParts = StringSplit($sItem, ":")
                If $aParts[0] >= 2 Then
                    GUICtrlSetData($Combo_Hora,   $aParts[1])
                    GUICtrlSetData($Combo_Minuto, $aParts[2])
                EndIf
            EndIf

        Case $Button_ClearHistory
            _ClearHistory()

        ; -- Sound --
        Case $Check_Sound
            If GUICtrlRead($Check_Sound) = $GUI_CHECKED Then
                RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Sound", "REG_SZ", "1")
            Else
                RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Sound", "REG_SZ", "0")
            EndIf
        Case $Combo_Volume
            RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Volume_Set", "REG_SZ", GUICtrlRead($Combo_Volume))
        Case $Button_TestSound
            SoundSetWaveVolume(GUICtrlRead($Combo_Volume))
            SoundPlay(@TempDir & "\beep-07.wav",  0)
            SoundPlay(@TempDir & "\beep-01a.wav", 0)

        ; -- Tray option --
        Case $Check_Tray
            If GUICtrlRead($Check_Tray) = $GUI_CHECKED Then
                Opt("TrayIconHide", 0)
                RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "TrayCheck", "REG_SZ", "1")
            Else
                Opt("TrayIconHide", 1)
                RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "TrayCheck", "REG_SZ", "0")
            EndIf

        ; -- Mouse options --
        Case $Check_MouseMove
            If GUICtrlRead($Check_MouseMove) = $GUI_CHECKED Then
                RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "MouseMove", "REG_SZ", "1")
            Else
                RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "MouseMove", "REG_SZ", "0")
            EndIf
        Case $Combo_MouseSens
            RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "MouseSensitivity", "REG_SZ", GUICtrlRead($Combo_MouseSens))
        Case $Combo_MouseSpeed
            RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "MouseSpeed", "REG_SZ", GUICtrlRead($Combo_MouseSpeed))
        Case $Check_Whisper
            If GUICtrlRead($Check_Whisper) = $GUI_CHECKED Then
                RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Whisper", "REG_SZ", "1")
            Else
                RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Whisper", "REG_SZ", "0")
            EndIf

    EndSwitch

    ; ---- Countdown tick every 500 ms ----
    If $g_iStart = 1 And TimerDiff($g_hTimer) > 500 Then
        $g_hTimer = TimerInit()
        RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Volume_Set", "REG_SZ", GUICtrlRead($Combo_Volume))
        _CountDown()
        ; Auto-hide if minimised and tray-to-tray is enabled
        Local $aStyle = GUIGetStyle($Form_Main)
        If GUICtrlRead($Check_Tray) = $GUI_CHECKED And $aStyle[0] = -1261830144 Then
            GUISetState(@SW_HIDE, $Form_Main)
            Opt("TrayIconHide", 0)
        EndIf
    EndIf

WEnd

; =============================================================================
;  HELPER / UTILITY FUNCTIONS
; =============================================================================

; Wrapper: GetSystemMetrics (avoids inline DLL noise)
Func _SysMetric($iIndex)
    Return DllCall("user32.dll", "int", "GetSystemMetrics", "int", $iIndex)[0]
EndFunc

; Get the accurate cursor position via WinAPI.
; MouseGetPos() can mis-report on some multi-monitor DPI configurations.
Func _CursorPos()
    Local $tPT = DllStructCreate("int X; int Y")
    DllCall("user32.dll", "bool", "GetCursorPos", "struct*", $tPT)
    Local $a[2] = [DllStructGetData($tPT, "X"), DllStructGetData($tPT, "Y")]
    Return $a
EndFunc

; Return the WORK area [left, top, right, bottom] of the monitor that
; currently contains the mouse cursor.  Falls back to primary monitor.
Func _ActiveMonitorWorkArea()
    Local $tPT = DllStructCreate("int X; int Y")
    DllCall("user32.dll", "bool", "GetCursorPos", "struct*", $tPT)
    ; MONITOR_DEFAULTTONEAREST = 2
    Local $hMon = DllCall("user32.dll", "handle", "MonitorFromPoint", "struct", $tPT, "dword", 2)[0]
    ; MONITORINFO layout: cbSize + rcMonitor(4 ints) + rcWork(4 ints) + dwFlags
    Local $tMI = DllStructCreate("dword cbSize;int rcL;int rcT;int rcR;int rcB;int wkL;int wkT;int wkR;int wkB;dword flags")
    DllStructSetData($tMI, "cbSize", DllStructGetSize($tMI))
    DllCall("user32.dll", "bool", "GetMonitorInfoW", "handle", $hMon, "struct*", $tMI)
    Local $a[4] = [DllStructGetData($tMI,"wkL"), DllStructGetData($tMI,"wkT"), DllStructGetData($tMI,"wkR"), DllStructGetData($tMI,"wkB")]
    If $a[2] = 0 And $a[3] = 0 Then ; fallback
        $a[0] = 0
	$a[1] = 0
 $a[2] = @DesktopWidth
 $a[3] = @DesktopHeight
    EndIf
    Return $a
EndFunc

Func _BuildNumList($iFrom, $iTo, $sFmt)
    Local $s = ""
    For $i = $iFrom To $iTo
        $s &= "|" & StringFormat($sFmt, $i)
    Next
    Return $s
EndFunc

Func _CleanPipes($s)
    Return StringRegExpReplace(StringStripWS($s, 3), "\|{2,}", "|")
EndFunc

Func _FormatHMS($iSeconds)
    If $iSeconds < 0 Then $iSeconds = 0
    Local $h = Int($iSeconds / 3600)
    Local $m = Int(($iSeconds - $h * 3600) / 60)
    Local $s = $iSeconds - $h * 3600 - $m * 60
    Return StringFormat("%02d:%02d:%02d", $h, $m, $s)
EndFunc

; =============================================================================
;  INITIALISATION HELPERS
; =============================================================================

Func _InitLog()
    If Not FileExists($g_sLogPath) Then
        Local $hF = FileOpen($g_sLogPath, 10)
        FileClose($hF)
        _FileWriteLog($g_sLogPath, "Log file created.")
    EndIf
    _FileWriteLog($g_sLogPath, "App started.  Virtual screen: " & $g_iVirtW & "x" & $g_iVirtH & " @ (" & $g_iVirtX & "," & $g_iVirtY & ")")
EndFunc

Func _CheckRequiredFiles()
    Local $aFiles[] = ["shutdown.ico", "beep-01a.wav", "beep-07.wav"]
    For $f In $aFiles
        If Not FileExists(@TempDir & "\" & $f) Then
            MsgBox(262160, "Shutdown", "Required file not found:" & @CRLF & @ScriptDir & "\" & $f)
            Exit
        EndIf
    Next
EndFunc

Func _CheckSingleInstance()
    Local $aList = ProcessList(@ScriptName)
    Local $n = 0
    For $i = 1 To $aList[0][0]
        If $aList[$i][0] = @ScriptName Then
            $n += 1
            If $n > 1 Then
                MsgBox($MB_OK + $MB_ICONHAND + 262144, "Multiple Instances", "You cannot run multiple instances of this application.", 30)
                _FileWriteLog($g_sLogPath, "App closed – duplicate instance.")
                Exit
            EndIf
        EndIf
    Next
EndFunc

; =============================================================================
;  UI STATE HELPERS
; =============================================================================

Func _RestoreCheck($iCtrl, $sKey)
    If RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", $sKey) = "1" Then
        GUICtrlSetState($iCtrl, $GUI_CHECKED)
    Else
        GUICtrlSetState($iCtrl, $GUI_UNCHECKED)
    EndIf
EndFunc

Func _SaveRadioState()
    RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Shutdown",  "REG_SZ", GUICtrlRead($Radio_Shutdown))
    RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Restart",   "REG_SZ", GUICtrlRead($Radio_Restart))
    RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Hibernate", "REG_SZ", GUICtrlRead($Radio_Hibernate))
    RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_StopTimer", "REG_SZ", GUICtrlRead($Radio_StopTimer))
    RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Close",     "REG_SZ", GUICtrlRead($Radio_Close))
EndFunc

Func _RestoreRadioState()
    GUICtrlSetState($Radio_Shutdown,  RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Shutdown"))
    GUICtrlSetState($Radio_Restart,   RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Restart"))
    GUICtrlSetState($Radio_Hibernate, RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Hibernate"))
    GUICtrlSetState($Radio_StopTimer, RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_StopTimer"))
    GUICtrlSetState($Radio_Close,     RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Close"))
    ; Default to Shutdown if nothing is saved
    If GUICtrlRead($Radio_Shutdown) <> $GUI_CHECKED And GUICtrlRead($Radio_Restart) <> $GUI_CHECKED And _
       GUICtrlRead($Radio_Hibernate) <> $GUI_CHECKED And GUICtrlRead($Radio_StopTimer) <> $GUI_CHECKED And _
       GUICtrlRead($Radio_Close) <> $GUI_CHECKED Then
        GUICtrlSetState($Radio_Shutdown, $GUI_CHECKED)
        _SaveRadioState()
    EndIf
EndFunc

Func _UpdateActionDesc()
    If GUICtrlRead($Radio_Shutdown)  = $GUI_CHECKED Then
		GUICtrlSetData($Label_ActionDesc, "Computer will be powered off")
		Return
		EndIf
    If GUICtrlRead($Radio_Restart)   = $GUI_CHECKED Then
		GUICtrlSetData($Label_ActionDesc, "Computer will reboot")
		Return
		EndIf
    If GUICtrlRead($Radio_Hibernate) = $GUI_CHECKED Then
		GUICtrlSetData($Label_ActionDesc, "Computer will hibernate (saves state)")
		Return
		EndIf
    If GUICtrlRead($Radio_Close)     = $GUI_CHECKED Then
		GUICtrlSetData($Label_ActionDesc, "This application will close (Exit)")
		Return
		EndIf
    GUICtrlSetData($Label_ActionDesc, "Timer stops – computer stays on")
EndFunc

Func _UpdateModeLabel()
    If GUICtrlRead($Radio_Duration) = $GUI_CHECKED Then
        GUICtrlSetData($Label_Mode, "Countdown")
    Else
        GUICtrlSetData($Label_Mode, "Defined time")
    EndIf
EndFunc

Func _GetActionTitle()
    If GUICtrlRead($Radio_Shutdown)  = $GUI_CHECKED Then Return "This device will shut down soon..."
    If GUICtrlRead($Radio_Restart)   = $GUI_CHECKED Then Return "This device will restart soon..."
    If GUICtrlRead($Radio_Hibernate) = $GUI_CHECKED Then Return "This device will hibernate soon..."
    If GUICtrlRead($Radio_Close)     = $GUI_CHECKED Then Return "This application will close soon..."
    Return "The timer will stop soon..."
EndFunc

Func _EnableControls($bEnable)
    Local $iState
    If $bEnable Then
        $iState = $GUI_ENABLE
    Else
        $iState = $GUI_DISABLE
    EndIf
    GUICtrlSetState($Combo_Hora,          $iState)
    GUICtrlSetState($Combo_Minuto,        $iState)
    GUICtrlSetState($List_History,        $iState)
    GUICtrlSetState($Button_ClearHistory, $iState)
    GUICtrlSetState($Radio_FixedTime,     $iState)
    GUICtrlSetState($Radio_Duration,      $iState)
    If $bEnable Then
        GUICtrlSetState($Button_Start,  $GUI_SHOW)
        GUICtrlSetState($Button_Cancel, $GUI_HIDE)
        ; Restore default background and force an immediate full repaint.
        ; Must come AFTER all control state changes so no subsequent redraw can override it.
        _ResetBkColor($Form_Main)
        GUICtrlSetColor($Label_Countdown, $COLOR_TEXT_NORMAL)
    Else
        GUICtrlSetState($Button_Start,  $GUI_HIDE)
        GUICtrlSetState($Button_Cancel, $GUI_SHOW)
    EndIf
EndFunc

Func _ShowMainWindow()
    GUISetState(@SW_SHOW,    $Form_Main)
    GUISetState(@SW_RESTORE, $Form_Main)
    Opt("TrayIconHide", 1)
EndFunc

Func _AppExit()
    _FileWriteLog($g_sLogPath, "App closed by user.")
    DllClose($g_hDLL)
    _GDIPlus_ImageDispose($g_hImageIcon)
    _GDIPlus_Shutdown()
    Exit
EndFunc

; =============================================================================
;  HISTORY MANAGEMENT
; =============================================================================

Func _AddHistory($sEntry)
    Local $s = _CleanPipes(RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "History"))
    If Not StringInStr($s, $sEntry) Then
        $s = _CleanPipes($s & "|" & $sEntry)
        RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "History", "REG_SZ", $s)
        GUICtrlSetData($List_History, $s)
    EndIf
EndFunc

Func _ClearHistory()
    Local $sSelected = GUICtrlRead($List_History)
    Local $sReg = _CleanPipes(RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "History"))
    If $sSelected = "" Then
        $sReg = ""  ; Clear all
    Else
        $sReg = _CleanPipes(StringReplace($sReg, $sSelected, ""))
    EndIf
    RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "History", "REG_SZ", $sReg)
    GUICtrlSetData($List_History, $sReg)
EndFunc

; =============================================================================
;  TIMER START / STOP
; =============================================================================

Func _StartTimer()
    Local $iH = Number(GUICtrlRead($Combo_Hora))
    Local $iM = Number(GUICtrlRead($Combo_Minuto))

    If $iH > 23 Or $iH < 0 Or $iM > 59 Or $iM < 0 Then
        MsgBox(262208, "Alert", "Invalid Hour / Minute entered.")
        Return
    EndIf

    Local $sEnd
    If GUICtrlRead($Radio_Duration) = $GUI_CHECKED Then
        ; Duration mode: add H hours + M minutes to NOW
        $sEnd = _DateAdd('n', $iH * 60 + $iM, _NowCalc())
    Else
        ; Fixed time mode
        $sEnd = @YEAR & "/" & @MON & "/" & @MDAY & " " & StringFormat("%02d:%02d:00", $iH, $iM)
        ; If target time is in the past, schedule for next day
        If _DateDiff('s', _NowCalc(), $sEnd) < 0 Then
            $sEnd = _DateAdd('D', 1, @YEAR & "/" & @MON & "/" & @MDAY & " " & StringFormat("%02d:%02d:00", $iH, $iM))
        EndIf
    EndIf

    Local $iSec = _DateDiff('s', _NowCalc(), $sEnd)

    If $iSec < 16 Then
        MsgBox(262208, "Alert", "Cannot start: less than 15 seconds remaining!")
        Return
    EndIf

    ; Persist settings
    RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Hour",       "REG_SZ", StringFormat("%02d", $iH))
    RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Minute",     "REG_SZ", StringFormat("%02d", $iM))
    RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Volume_Set", "REG_SZ", GUICtrlRead($Combo_Volume))

    ; Save to history (only for fixed-time mode – duration entries vary)
    If GUICtrlRead($Radio_FixedTime) = $GUI_CHECKED Then
        _AddHistory(StringFormat("%02d:%02d", $iH, $iM))
    EndIf

    ; Store global end-date and total seconds for progress calculation
    $g_sEndDate      = $sEnd
    $g_iTotalSeconds = $iSec
    $g_iLockMouseMove = 1
    $g_iStart         = 1
    $g_iFloatWinShow  = 0
    $g_iRed           = 1
    $g_iBeepTimeSec   = -1

    _EnableControls(False)
    _FileWriteLog($g_sLogPath, "Timer started. End: " & $g_sEndDate & "  Action: " & _GetActionTitle())
EndFunc

Func _Stop()
    $g_iStart        = 0
    $g_iFloatWinShow = 0

    TrayItemSetState($iTray_Stop,   $GUI_DISABLE)
    GUICtrlSetState($Button_Cancel, $GUI_UNCHECKED)
    GUICtrlSetData($Label_Countdown, "00:00:00")
    GUICtrlSetData($ProgressBar, 0)
    TraySetToolTip()
    TraySetState(8)  ; stop flash

    ; _EnableControls(True) shows START and calls _ResetBkColor → forced repaint
    _EnableControls(True)
    GUISetState(@SW_HIDE, $g_ahNotify[0])
    _FileWriteLog($g_sLogPath, "Timer stopped.")
EndFunc

; =============================================================================
;  COUNTDOWN  (called every 500 ms while $g_iStart = 1)
; =============================================================================

Func _CountDown()
    ; Bail if user clicked CANCEL
    If GUICtrlRead($Button_Cancel) = $GUI_CHECKED Then
        GUICtrlSetState($Button_Cancel, $GUI_ENABLE)
        Return
    EndIf

    Local $iSec = _DateDiff('s', _NowCalc(), $g_sEndDate)

    ; --- Time's up ---
    If $iSec <= 0 Then
        GUICtrlSetData($Label_Countdown, "00:00:00")
        GUICtrlSetData($ProgressBar, 100)
        _ExecuteAction()
        Return
    EndIf

    ; --- Format display ---
    Local $iHours = Int($iSec / 3600)
    Local $iRemain = $iSec - ($iHours * 3600)
    Local $iMinutes = Int($iRemain / 60)
    Local $iSeconds = $iRemain - ($iMinutes * 60)

    $TimerInHours   = StringFormat("%02d", $iHours)
    $TimerInMinutes = StringFormat("%02d", $iMinutes)
    $TimerInSeconds = StringFormat("%02d", $iSeconds)
    Local $sHMS = $TimerInHours & ":" & $TimerInMinutes & ":" & $TimerInSeconds

    GUICtrlSetData($Label_Countdown, $sHMS)
    TraySetToolTip(_GetActionTitle() & "  in  " & $sHMS)

    ; --- Progress bar ---
    If $g_iTotalSeconds > 0 Then
        GUICtrlSetData($ProgressBar, Int((($g_iTotalSeconds - $iSec) / $g_iTotalSeconds) * 100))
    EndIf

    ; -------------------------------------------------------------------
    ;  MOUSE KEEP-ALIVE
    ;  Uses WinAPI cursor position (accurate on multi-monitor / per-monitor
    ;  DPI setups where MouseGetPos() can return wrong coordinates).
    ; -------------------------------------------------------------------
    If GUICtrlRead($Check_MouseMove) = $GUI_CHECKED And $g_iLockMouseMove = 1 Then
        $g_aMousePos = _CursorPos()

        If $g_aMousePos[0] = $g_aMousePosHist[0] And $g_aMousePos[1] = $g_aMousePosHist[1] Then
            $g_iMouseCount += 1
        Else
            $g_aMousePosHist[0] = $g_aMousePos[0]
            $g_aMousePosHist[1] = $g_aMousePos[1]
            $g_iMouseCount = 0
        EndIf

        If $g_iMouseCount > Number(GUICtrlRead($Combo_MouseSens)) Then
            Local $iSpd = Number(GUICtrlRead($Combo_MouseSpeed))
            If GUICtrlRead($Check_Whisper) = $GUI_CHECKED Then
                ; Whisper: imperceptible ±2 px jiggle at current position
                Local $aCur = _CursorPos()
                MouseMove($aCur[0] + 2, $aCur[1],     $iSpd)
                MouseMove($aCur[0],     $aCur[1],     $iSpd)
                MouseMove($aCur[0],     $aCur[1] + 2, $iSpd)
                MouseMove($aCur[0],     $aCur[1],     $iSpd)
            Else
                ; Random move within the FULL virtual screen (all monitors)
                ; Uses g_iVirtX/Y/W/H computed at startup via GetSystemMetrics
                Local $iRX = Random($g_iVirtX + 10, $g_iVirtX + $g_iVirtW - 10, 1)
                Local $iRY = Random($g_iVirtY + 10, $g_iVirtY + $g_iVirtH - 10, 1)
                MouseMove($iRX, $iRY, $iSpd)
                ; Refresh history so the random move itself doesn't re-trigger
                $g_aMousePosHist = _CursorPos()
            EndIf
            $g_iMouseCount = 0
        EndIf
    EndIf

    ; -------------------------------------------------------------------
    ;  VISUAL / AUDIO WARNINGS  (last 60 s)
    ; -------------------------------------------------------------------
    If $iSec <= 60 Then

        ; Sound: once per second
        If @SEC <> $g_iSecBuff2 Then
            $g_iSecBuff2 = @SEC
            If GUICtrlRead($Check_Sound) = $GUI_CHECKED Then
                SoundSetWaveVolume(GUICtrlRead($Combo_Volume))
                If $iSec <= 10 Then
                    SoundPlay(@TempDir & "\beep-01a.wav", 0)
                ElseIf $iSec <= 30 Then
					#cs
                    If $g_iBeepCount > 1 Then
                        $g_iBeepCount = 0
                        SoundPlay(@ScriptDir & "\beep-07.wav", 0)
                    Else
                        $g_iBeepCount += 1
                    EndIf
					#ce
					If @SEC <> $g_iBeepTimeSec Then
                        $g_iBeepTimeSec = @SEC
                        SoundPlay(@ScriptDir & "\beep-07.wav", 0)
                    EndIf
                Else
                    If @SEC <> $g_iBeepTimeSec Then
                        $g_iBeepTimeSec = @SEC
                        SoundPlay(@ScriptDir & "\beep-07.wav", 0)
                    EndIf
                EndIf
            EndIf
        EndIf

        ; Floating toast notification – appears on the ACTIVE monitor
        If $g_iFloatWinShow = 0 Then
            $g_iFloatWinShow = 1
            GUIDelete($g_ahNotify[0])
            Local $aWA = _ActiveMonitorWorkArea()
            Local $iNX = $aWA[2] - 370
            Local $iNY = $aWA[3] - 160
            $g_ahNotify = _CreateNotifyWin(_GetActionTitle(), "Time remaining: " & $sHMS, $g_hImageIcon, $iNX, $iNY)
            GUISetState(@SW_SHOWNOACTIVATE, $g_ahNotify[0])
            WinSetTrans($g_ahNotify[0], "", 220)
        Else
            _UpdateNotifyText(_GetActionTitle(), "Time remaining: " & $sHMS)
        EndIf
        GUISetState(@SW_SHOWNOACTIVATE, $g_ahNotify[0])

        ; -------------------------------------------------------------------
        ;  VISUAL WARNING COLOURS
        ;  ≤ 30 s : bg flashes between default-gray and orange; text contrasts
        ;  31-60 s: bg stays default; countdown text pulses dark-red / black
        ; -------------------------------------------------------------------
        If $iSec <= 30 Then
            $g_iLockMouseMove = 0  ; Stop jiggling – too close to action
            If $g_iRed = 1 Then
                $g_iFloatWinShow = 0
                _ResetBkColor($Form_Main)                           ; default gray + forced repaint
                GUICtrlSetColor($Label_Countdown, $COLOR_TEXT_RED)  ; dark-red text
                TraySetState(4)  ; flash tray icon
                $g_iRed = 0
            Else
                GUISetBkColor($COLOR_BK_WARNING, $Form_Main)        ; orange bg
                GUICtrlSetColor($Label_Countdown, $COLOR_WHITE)     ; white text on orange
                $g_iRed = 1
            EndIf
        Else
            ; 31-60 s: only the countdown text pulses; background stays default
            If @SEC <> $g_iSecBuff Then
                $g_iSecBuff = @SEC
                TraySetState(4)
                GUICtrlSetColor($Label_Countdown, $COLOR_TEXT_RED)  ; dark-red pulse
            Else
                GUICtrlSetColor($Label_Countdown, $COLOR_TEXT_NORMAL) ; back to black
            EndIf
        EndIf

    Else  ; More than 60 s remaining – calm display, Windows default bg, black text
        $g_iFloatWinShow = 0
        GUICtrlSetColor($Label_Countdown, $COLOR_TEXT_NORMAL)  ; black
        _ResetBkColor($Form_Main)                               ; default gray + forced repaint
        TraySetState(9)
        GUISetState(@SW_HIDE, $g_ahNotify[0])
    EndIf

EndFunc

; =============================================================================
;  EXECUTE THE SCHEDULED ACTION
; =============================================================================

Func _ExecuteAction()
    ; Restore normal appearance immediately.
    ; For OS actions (Shutdown/Restart/Hibernate/Close) this clears the orange/red
    ; during the brief gap before the OS acts.
    ; For Stop, _Stop() → _EnableControls(True) → _ResetBkColor handles the repaint.
    _ResetBkColor($Form_Main)
    GUICtrlSetColor($Label_Countdown, $COLOR_TEXT_NORMAL)
    GUISetState(@SW_HIDE, $g_ahNotify[0])

    _FileWriteLog($g_sLogPath, "Action executing: " & _GetActionTitle())
    If GUICtrlRead($Radio_Shutdown)  = $GUI_CHECKED Then
        Shutdown(5)  ; Shutdown + force close apps
        Exit
    ElseIf GUICtrlRead($Radio_Restart) = $GUI_CHECKED Then
        Shutdown(6)  ; Restart + force close apps
        Exit
    ElseIf GUICtrlRead($Radio_Hibernate) = $GUI_CHECKED Then
        Shutdown(64) ; Hibernate
        Exit
    ElseIf GUICtrlRead($Radio_Close) = $GUI_CHECKED Then
        _AppExit()   ; Close this application
    Else
        ; "Stop" mode: _Stop() → _EnableControls(True) → _ResetBkColor
        TraySetState(9)
        _Stop()
    EndIf
EndFunc

; =============================================================================
;  GDI+ NOTIFICATION WINDOW
; =============================================================================

; Creates the floating Win10-style notification.
; Returns array[2]: [hGUI, hCloseBtn]
Func _CreateNotifyWin($sTitle, $sText, $hIcon = 0, $iX = -1, $iY = -1, $iW = 360, $iH = 100, $sFont = "Segoe UI", $fSize = 11.5, $iBg = 0xFF1F1F1F, $iColTitle = 0xFFF8F8F8, $iColText = 0xFFA0A0A0)
    Global $hGUI_Notify     = GUICreate($sTitle, $iW, $iH, $iX, $iY, $WS_POPUP, $WS_EX_TOPMOST)
    Global $iLabel_Drag     = GUICtrlCreateLabel("", 0, 0, $iW, 11, -1, $GUI_WS_EX_PARENTDRAG)
    Global $iPic_BG         = GUICtrlCreatePic("", 0, 0, $iW, $iH)
    GUICtrlSetState(-1, $GUI_DISABLE)
    Global $iPic_Icon       = GUICtrlCreatePic("", 12, 12, 32, 32)
    GUICtrlSetState(-1, $GUI_DISABLE)
    Global $iBtn_Close      = GUICtrlCreateLabel("X", $iW - 25, 14, 10, 10, BitOR($SS_CENTER, $SS_SIMPLE))
    GUICtrlSetFont(-1, 8, 200, 0, "Arial")
    GUICtrlSetBkColor(-1, BitAND($iBg, 0x00FFFFFF))
    GUICtrlSetColor(-1, 0xF0F0F0)
    _RenderNotify($sTitle, $sText, $hIcon, $iW, $iH, $sFont, $fSize, $iBg, $iColTitle, $iColText)
    Local $aR[2] = [$hGUI_Notify, $iBtn_Close]
    Return $aR
EndFunc

; Updates the text in an already-open notification window.
Func _UpdateNotifyText($sTitle, $sText)
    _RenderNotify($sTitle, $sText, $g_hImageIcon)
EndFunc

; Internal: render GDI+ bitmap into the notification controls.
Func _RenderNotify($sTitle, $sText, $hIcon = 0, $iW = 360, $iH = 100, $sFontName = "Segoe UI", $fFontSize = 11.5, $iBgColor = 0xFF1F1F1F, $iTitleColor = 0xFFF8F8F8, $iTextColor = 0xFFA0A0A0)
    Local $hBitmap  = _GDIPlus_BitmapCreateFromScan0($iW, $iH)
    Local $hGfx     = _GDIPlus_ImageGetGraphicsContext($hBitmap)

    _GDIPlus_GraphicsSetSmoothingMode($hGfx, 4)
    _GDIPlus_GraphicsSetPixelOffsetMode($hGfx, 2)
    _GDIPlus_GraphicsSetTextRenderingHint($hGfx, 5)
    _GDIPlus_GraphicsClear($hGfx, $iBgColor)

    Local $hPen         = _GDIPlus_PenCreate(0xFF484848)
    Local $hBrushTitle  = _GDIPlus_BrushCreateSolid($iTitleColor)
    Local $hBrushText   = _GDIPlus_BrushCreateSolid($iTextColor)
    Local $hFamily      = _GDIPlus_FontFamilyCreate($sFontName)
    Local $hFontTitle   = _GDIPlus_FontCreate($hFamily, $fFontSize,     1)
    Local $hFontText    = _GDIPlus_FontCreate($hFamily, $fFontSize - 1, 0)
    Local $hFormat      = _GDIPlus_StringFormatCreate()

    _GDIPlus_GraphicsDrawRect($hGfx, 0, 0, $iW - 1, $iH - 1, $hPen)

    Local $tLytTitle = _GDIPlus_RectFCreate(56, 13, $iW - 80, 16)
    _GDIPlus_GraphicsDrawStringEx($hGfx, $sTitle, $hFontTitle, $tLytTitle, $hFormat, $hBrushTitle)

    Local $tLytText = _GDIPlus_RectFCreate(56, 33, $iW - 80, $iH - 35)
    _GDIPlus_GraphicsDrawStringEx($hGfx, $sText, $hFontText, $tLytText, $hFormat, $hBrushText)

    ; Flush bitmap to the background picture control
    Local $hBmpGDI = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hBitmap)
    _WinAPI_DeleteObject(GUICtrlSendMsg($iPic_BG, $STM_SETIMAGE, $IMAGE_BITMAP, $hBmpGDI))
    _WinAPI_DeleteObject($hBmpGDI)

    ; Icon (scaled to 32x32)
    If $hIcon Then
        Local $aDim  = _GDIPlus_ImageGetDimension($hIcon)
        Local $fMax
        If $aDim[0] >= $aDim[1] Then
            $fMax = $aDim[0]
        Else
            $fMax = $aDim[1]
        EndIf
        Local $fScale = 32 / $fMax
        Local $hScaled = _GDIPlus_ImageScale($hIcon, $fScale, $fScale)
        $hBmpGDI = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hScaled)
        _WinAPI_DeleteObject(GUICtrlSendMsg($iPic_Icon, $STM_SETIMAGE, $IMAGE_BITMAP, $hBmpGDI))
        _GDIPlus_BitmapDispose($hScaled)
        _WinAPI_DeleteObject($hBmpGDI)
    EndIf

    ; Release all GDI+ resources
    _GDIPlus_PenDispose($hPen)
    _GDIPlus_BrushDispose($hBrushTitle)
    _GDIPlus_BrushDispose($hBrushText)
    _GDIPlus_FontDispose($hFontTitle)
    _GDIPlus_FontDispose($hFontText)
    _GDIPlus_FontFamilyDispose($hFamily)
    _GDIPlus_StringFormatDispose($hFormat)
    _GDIPlus_GraphicsDispose($hGfx)
    _GDIPlus_BitmapDispose($hBitmap)

    GUICtrlSetState($iBtn_Close, $GUI_SHOW)
EndFunc
