#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Icon=shutdown.ico
#AutoIt3Wrapper_Res_Fileversion=3.1.2.10
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
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

Opt("TrayIconHide", 1)
Opt("TrayAutoPause", 0)
Opt("TrayMenuMode", 3)
Opt("MouseCoordMode", 1)

Global $BK_Color = 0x327E9A
Global $BK_Color = 0x327E9A
Global $BK_Color2 = 0x004C99
Global $BK_ColorRed = 0xFF0000
Global $BeepTime = @SEC
Global $BeepCount = 2
Global $sLogPath = @ScriptDir & "\" & @ComputerName & "_" & @UserName & ".log"
Global $MouseCount = 0
Global $hDLL = DllOpen("user32.dll")

If Not FileExists($sLogPath) Then
	$sLogPath_Hwd = FileOpen($sLogPath, 10)
	FileClose($sLogPath_Hwd)
	$sLogMsg = "Log File Created ..."
	_FileWriteLog($sLogPath, $sLogMsg)
EndIf
$sLogMsg = "App Opened ..."
_FileWriteLog($sLogPath, $sLogMsg)

If Not FileExists(@ScriptDir & "\shutdown.ico") Then
	MsgBox(262160, "Shutdown", "File not found." & @CRLF & @ScriptDir & "\shutdown.ico")
	Exit
EndIf

If Not FileExists(@ScriptDir & "\beep-01a.wav") Then
	MsgBox(262160, "Shutdown", "File not found." & @CRLF & @ScriptDir & "\beep-01a.wav")
	Exit
EndIf

If Not FileExists(@ScriptDir & "\beep-07.wav") Then
	MsgBox(262160, "Shutdown", "File not found." & @CRLF & @ScriptDir & "\beep-07.wav")
	Exit
EndIf

$ProcessList = ProcessList(@ScriptName)
$CountProcess = 0
For $i = 1 To $ProcessList[0][0]
	;MsgBox($MB_SYSTEMMODAL, "", $ProcessList[$i][0] & @CRLF & "PID: " & $ProcessList[$i][1])
	If $ProcessList[$i][0] = @ScriptName Then
		$CountProcess += 1
		If $CountProcess > 1 Then
			If Not IsDeclared("iMsgBoxAnswer") Then Local $iMsgBoxAnswer
			$iMsgBoxAnswer = MsgBox($MB_OK + $MB_ICONHAND + 262144, "Multiple Instances", "You cannot run multiple instances of this application.", 30)
			Select
				Case $iMsgBoxAnswer = -1 ;Timeout
					$sLogMsg = "App Closed (Multiple Instances) - Time out ..."
					_FileWriteLog($sLogPath, $sLogMsg)
					Exit
				Case Else    ;OK
					$sLogMsg = "App Closed (Multiple Instances) - OK Button ..."
					_FileWriteLog($sLogPath, $sLogMsg)
					Exit
			EndSelect
		EndIf

	EndIf
Next


_GDIPlus_Startup()
Global $hImage_Icon = _GDIPlus_ImageLoadFromFile(@ScriptDir & "\shutdown.ico")
Global $ahGUI[999999]

Global $ahGUI = _GDIPlus_CreateW10TrayWin("This device will shut down soon...", "... time until shutdown: 00:00:00", $hImage_Icon, @DesktopWidth - 370, @DesktopHeight - 150)

WinSetTrans($ahGUI[0], "", 100)
GUISetState(@SW_HIDE, $ahGUI[0])

#Region ### START Koda GUI section ### Form=
Global $TimerInHours, $TimerInMinutes, $TimerInSeconds

Global $Form_Main = GUICreate("Time Control", 315, 230, -1, -1)
GUISetBkColor($BK_Color, $Form_Main)

$StatusBar1 = _GUICtrlStatusBar_Create($Form_Main)
Dim $StatusBar1_PartsWidth[2] = [70, -1]
_GUICtrlStatusBar_SetParts($StatusBar1, $StatusBar1_PartsWidth)
_GUICtrlStatusBar_SetText($StatusBar1, FileGetVersion(@ScriptFullPath), 0)
_GUICtrlStatusBar_SetText($StatusBar1, "Dev. By Fabrício Zambroni", 1)

Global $Combo_Hora = GUICtrlCreateCombo(@HOUR + 1, 16, 16, 65, 25, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
Global $Hora = ""
Global $count_Hora = 0
Global $SecBuff = @SEC
Global $SecBuff2 = @SEC
Global $MouseCount = 0
Global $MousePos = MouseGetPos()
Global $MousePos_Hist = MouseGetPos()
Global $lockScreen = 1
Global $MouseTimer = TimerInit()
Global $FloatWindowsShow = 0
Global $List_History_Register = RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "History")
$Red = 1
Global $UpdateWindow = 0
While 1
	If $count_Hora < 10 Then
		$Hora = $Hora & "|0" & $count_Hora
	Else
		$Hora = $Hora & "|" & $count_Hora
	EndIf
	If $count_Hora = 23 Then ExitLoop
	$count_Hora += 1

WEnd
GUICtrlSetData($Combo_Hora, $Hora, RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Hour"))

Global $Combo_Minuto = GUICtrlCreateCombo(@MIN, 96, 16, 57, 25) ;, BitOR($CBS_DROPDOWN,$CBS_AUTOHSCROLL))
$Minuto = ""
$count_Minuto = 0
While 1
	If $count_Minuto < 10 Then
		$Minuto = $Minuto & "|0" & $count_Minuto
	Else
		$Minuto = $Minuto & "|" & $count_Minuto
	EndIf
	If $count_Minuto = 59 Then ExitLoop
	$count_Minuto += 1

WEnd
GUICtrlSetData($Combo_Minuto, $Minuto, RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Minute"))

$List_History = GUICtrlCreateList("", 260, 15, 50, 109)
$List_History_Register = StringReplace($List_History_Register, "||", "|", 0, 0)
GUICtrlSetData($List_History, $List_History_Register)
GUICtrlSetFont($List_History, 7, 700)
GUICtrlSetBkColor($List_History, $BK_Color2)
GUICtrlSetColor($List_History, 0xFFFFFF)

$Group_Action = GUICtrlCreateGroup("", 16, 37, 231, 30)

$Radio_Shutdown = GUICtrlCreateRadio("Shutdown", 30, 44, 70)
GUICtrlSetState($Radio_Shutdown, RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Shutdown"))

$Radio_Stop = GUICtrlCreateRadio("Stop", 110, 44, 60)
GUICtrlSetState($Radio_Stop, RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Stop"))

$Radio_Close = GUICtrlCreateRadio("Close", 180, 44, 60)
GUICtrlSetState($Radio_Close, RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Close"))

If RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Shutdown") = "" And RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Close") = "" And RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Stop") = "" Then
	GUICtrlSetState($Radio_Shutdown, "1")
	RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Shutdown", "REG_SZ", GUICtrlRead($Radio_Shutdown))
EndIf

GUICtrlCreateGroup("", -99, -99, 1, 1)

$Group1 = GUICtrlCreateGroup("", 16, 68, 231, 50)
Global $Label_countdown = GUICtrlCreateLabel("00:00:00", 24, 80, 215, 30, $SS_CENTER)
GUICtrlSetFont(-1, 25, 400, 0, "MS Sans Serif")
GUICtrlCreateGroup("", -99, -99, 1, 1)

;Global $Label_Version = GUICtrlCreateLabel(FileGetVersion(@ScriptFullPath), 180, 123, 75, 20, $SS_CENTER)

Global $Start = 0

$Button_Shutdown = GUICtrlCreateButton("START", 173, 14, 75, 25)
GUICtrlSetBkColor($Button_Shutdown, 0x006600)

$Button_Cancel = GUICtrlCreateCheckbox("STOP", 173, 14, 75, 25, $BS_PUSHLIKE)
GUICtrlSetBkColor($Button_Cancel, 0xFF0000)
GUICtrlSetState($Button_Cancel, $gui_hide)

$Button_Clear = GUICtrlCreateButton("CLEAR", 260, 120, 50, 20) ;, $BS_PUSHLIKE)

Global $Sound = GUICtrlCreateCheckbox("Play Sound - Volume:", 10, 120)
If RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Sound") = '1' Then
	GUICtrlSetState($Sound, $GUI_CHECKED)
Else
	GUICtrlSetState($Sound, $GUI_UNCHECKED)
EndIf

$Volume_Set = RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Volume_Set")
If $Volume_Set = "" Then $Volume_Set = 30
$Combo_Volume = GUICtrlCreateCombo("", 130, 120, 45, 25, $CBS_DROPDOWNLIST)
GUICtrlSetData($Combo_Volume, "5|10|20|30|40|50|60|70|80|90|100", $Volume_Set)

$Button_Volume = GUICtrlCreateButton("Test", 180, 125, 35, 15)
GUICtrlSetFont($Button_Volume, 8)

Global $TrayCheck = GUICtrlCreateCheckbox("Minimize to tray", 10, 140)
If RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "TrayCheck") = '1' Then
	GUICtrlSetState($TrayCheck, $GUI_CHECKED)
Else
	GUICtrlSetState($TrayCheck, $GUI_UNCHECKED)
EndIf

Global $MouseMove = GUICtrlCreateCheckbox("Mouse - Sensitivity / Speed:", 10, 160)
If RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "MouseMove") = '1' Then
	GUICtrlSetState($MouseMove, $GUI_CHECKED)
Else
	GUICtrlSetState($MouseMove, $GUI_UNCHECKED)
EndIf

Global $MouseSensitivityDefault = RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "MouseSensitivity")
If $MouseSensitivityDefault = "" Then
	$MouseSensitivityDefault = "20"
EndIf

Global $MouseSpeedDefault = RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "MouseSpeed")
If $MouseSpeedDefault = "" Then
	$MouseSpeedDefault = "20"
EndIf

Global $MouseSensitivity = GUICtrlCreateCombo("", 165, 160, 45, 20, $CBS_DROPDOWNLIST)
GUICtrlSetData($MouseSensitivity, "10|20|30|40|50|60|70|80|90|100|200|300|400|500", $MouseSensitivityDefault)
Global $MouseSpeed = GUICtrlCreateCombo("", 215, 160, 45, 20, $CBS_DROPDOWNLIST)
GUICtrlSetData($MouseSpeed, "0|5|10|20|30|40|50|60|70|80|90|100", $MouseSpeedDefault)

Global $MouseWisper = GUICtrlCreateCheckbox("Whisper mode", 10, 180)
If RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Whisper") = '1' Then
	GUICtrlSetState($MouseWisper, $GUI_CHECKED)
Else
	GUICtrlSetState($MouseWisper, $GUI_UNCHECKED)
EndIf

Global $Whisper = RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Whisper")
If $Whisper = "" Then
	$Whisper = "20"
EndIf

Local $iDisplay = TrayCreateItem("Restore")
GUISetFont(-1, $FW_BOLD, -1, $iDisplay)

TrayCreateItem("") ; Create a separator line.
Local $iSTOP = TrayCreateItem("STOP")
TrayCreateItem("") ; Create a separator line.
Local $idExit = TrayCreateItem("Exit")

GUISetState(@SW_SHOW, $Form_Main)
GUISetState(@SW_RESTORE, $Form_Main)
$hTimer = TimerInit()
#EndRegion ### END Koda GUI section ###

While 1

	$nMsg = GUIGetMsg($Form_Main)
	$nMsg2 = GUIGetMsg($ahGUI[0])
	$TMsg = TrayGetMsg()

	If _IsPressed("01", $hDLL) Then
		$MouseCount = 0
		ConsoleWrite("############################################### Aqui1" & @CRLF)
	EndIf

	If _IsPressed("02", $hDLL) Then
		$MouseCount = 0
		ConsoleWrite("############################################### Aqui2" & @CRLF)
	EndIf

	If _IsPressed("03", $hDLL) Then
		$MouseCount = 0
		ConsoleWrite("############################################### Aqui3" & @CRLF)
	EndIf

	If _IsPressed("04", $hDLL) Then
		$MouseCount = 0
		ConsoleWrite("############################################### Aqui4" & @CRLF)
	EndIf

	If _IsPressed("05", $hDLL) Then
		$MouseCount = 0
		ConsoleWrite("############################################### Aqui5" & @CRLF)
	EndIf

	If _IsPressed("06", $hDLL) Then
		$MouseCount = 0
		ConsoleWrite("############################################### Aqui6" & @CRLF)
	EndIf


	Switch $TMsg

		Case $TRAY_EVENT_PRIMARYDOUBLE
			ConsoleWrite("A" & @CRLF)
			GUISetState(@SW_SHOW, $Form_Main)
			GUISetState(@SW_RESTORE, $Form_Main)
			$lockScreen = 1
			Opt("TrayIconHide", 1)

		Case $iSTOP
			TraySetState(9)
			_Stop()

		Case $iDisplay
			ConsoleWrite("A" & @CRLF)
			GUISetState(@SW_SHOW, $Form_Main)
			GUISetState(@SW_RESTORE, $Form_Main)
			$lockScreen = 1
			Opt("TrayIconHide", 1)

		Case $idExit
			ConsoleWrite("B" & @CRLF)
			Exit



	EndSwitch

	Switch $nMsg2

		Case $GUI_EVENT_CLOSE, $ahGUI[1]
			GUIDelete($ahGUI[0])
			$FloatWindowsShow = 1
			GUISetState(@SW_SHOW, $Form_Main)
			GUISetState(@SW_RESTORE, $Form_Main)

		Case $GUI_EVENT_SECONDARYDOWN
			$MouseCount = 0
;~ 			ConsoleWrite("############################################### Aqui" & @CRLF)

		Case $GUI_EVENT_PRIMARYDOWN
			$MouseCount = 0
;~ 			ConsoleWrite("############################################### Aqui" & @CRLF)

	EndSwitch

	Switch $nMsg

		Case $GUI_EVENT_SECONDARYDOWN
			$MouseCount = 0
;~ 			ConsoleWrite("############################################### Aqui" & @CRLF)

		Case $GUI_EVENT_PRIMARYDOWN
			$MouseCount = 0
;~ 			ConsoleWrite("############################################### Aqui" & @CRLF)

		Case $Button_Volume
			SoundSetWaveVolume(GUICtrlRead($Combo_Volume))
			SoundPlay(@ScriptDir & "\beep-08b.wav", 1)
			SoundPlay(@ScriptDir & "\beep-07.wav", 1)
			SoundPlay(@ScriptDir & "\beep-01a.wav", 1)
			;Sleep(200)

		Case $Button_Clear
			If GUICtrlRead($List_History) = "" Then
				RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "History", "REG_SZ", "")
				$List_History_Register = RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "History")
				GUICtrlSetData($List_History, $List_History_Register)
			Else
				$List_History_Register = RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "History")
				$List_History_Register = StringReplace($List_History_Register, GUICtrlRead($List_History), "")
				$List_History_Register = StringReplace($List_History_Register, "||", "|", 0, 0)
				$List_History_Register = StringReplace($List_History_Register, "||", "|", 0, 0)
				RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "History", "REG_SZ", $List_History_Register)
				$List_History_Register = RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "History")
				GUICtrlSetData($List_History, $List_History_Register)

			EndIf


		Case $List_History
			$List_History_Value = GUICtrlRead($List_History)
			ConsoleWrite("$List_History_Value: " & $List_History_Value & @CRLF)
			If $List_History_Value <> "" Then
				$List_History_Value_Split = StringSplit($List_History_Value, ":")
				GUICtrlSetData($Combo_Hora, $List_History_Value_Split[1])
				GUICtrlSetData($Combo_Minuto, $List_History_Value_Split[2])
			EndIf


		Case $Radio_Shutdown
			RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Shutdown", "REG_SZ", GUICtrlRead($Radio_Shutdown))
			RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Stop", "REG_SZ", GUICtrlRead($Radio_Stop))
			RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Close", "REG_SZ", GUICtrlRead($Radio_Close))

		Case $Radio_Close
			RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Shutdown", "REG_SZ", GUICtrlRead($Radio_Shutdown))
			RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Stop", "REG_SZ", GUICtrlRead($Radio_Stop))
			RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Close", "REG_SZ", GUICtrlRead($Radio_Close))

		Case $Radio_Stop
			RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Shutdown", "REG_SZ", GUICtrlRead($Radio_Shutdown))
			RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Stop", "REG_SZ", GUICtrlRead($Radio_Stop))
			RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Radio_Close", "REG_SZ", GUICtrlRead($Radio_Close))

		Case $MouseSpeed
			RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "MouseSpeed", "REG_SZ", GUICtrlRead($MouseSpeed))

		Case $MouseSensitivity
			RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "MouseSensitivity", "REG_SZ", GUICtrlRead($MouseSensitivity))

		Case $MouseWisper
			RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Whisper", "REG_SZ", GUICtrlRead($MouseWisper))

		Case $GUI_EVENT_minimize
			If GUICtrlRead($TrayCheck) = "1" Then
				GUISetState(@SW_HIDE)
				$lockScreen = 0
				Opt("TrayIconHide", 0)
			EndIf

		Case $GUI_EVENT_CLOSE
			Exit

		Case $TrayCheck
			If GUICtrlRead($TrayCheck) = "1" Then
				Opt("TrayIconHide", 0)
				RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "TrayCheck", "REG_SZ", '1')
			Else
				Opt("TrayIconHide", 1)
				RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "TrayCheck", "REG_SZ", '0')
			EndIf

		Case $Sound
			If GUICtrlRead($Sound) = "1" Then
				RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Sound", "REG_SZ", '1')
			Else
				RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Sound", "REG_SZ", '0')
			EndIf

		Case $Combo_Volume
			RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Volume_Set", "REG_SZ", GUICtrlRead($Combo_Volume))



		Case $MouseMove
			ConsoleWrite("4" & @CRLF)
			If GUICtrlRead($MouseMove) = '1' Then
				ConsoleWrite("5" & @CRLF)
				RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "MouseMove", "REG_SZ", '1')
			Else
				ConsoleWrite("6" & @CRLF)
				RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "MouseMove", "REG_SZ", '0')
			EndIf

		Case $Button_Cancel
			_Stop()
			TraySetState(10)

		Case $Button_Shutdown
			Global $MouseMoveLock = 1
			$Start = 1
			GUICtrlSetState($Combo_Hora, $gui_disable)
			GUICtrlSetState($Combo_Minuto, $gui_disable)
			GUICtrlSetState($Button_Shutdown, $gui_hide)
			GUICtrlSetState($Button_Clear, $gui_disable)
			GUICtrlSetState($List_History, $gui_disable)
			$Combo_Hora_Value = GUICtrlRead($Combo_Hora)
			$Combo_Minuto_Value = GUICtrlRead($Combo_Minuto)
			If $Combo_Hora_Value > 23 Or $Combo_Hora_Value < 00 Or $Combo_Minuto_Value > 59 Or $Combo_Minuto_Value < 00 Then
				MsgBox(262208, "Alert", "Invalid Hour / Minute")
				GUICtrlSetState($Combo_Hora, $gui_enable)
				GUICtrlSetState($Combo_Minuto, $gui_enable)
				GUICtrlSetState($Button_Shutdown, $gui_show)
				GUICtrlSetState($Button_Clear, $gui_enable)
				GUICtrlSetState($List_History, $gui_enable)
				$Start = 0
				$FloatWindowsShow = 0
				TraySetState(9)
			Else
				RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Volume_Set", "REG_SZ", GUICtrlRead($Combo_Volume))
				RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Hour", "REG_SZ", $Combo_Hora_Value)
				RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Minute", "REG_SZ", $Combo_Minuto_Value)
				$List_History_Register = RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "History")
				If Not StringInStr($List_History_Register, $Combo_Hora_Value & ":" & $Combo_Minuto_Value) Then
					$List_History_Register = $List_History_Register & "|" & $Combo_Hora_Value & ":" & $Combo_Minuto_Value
					$List_History_Register = StringReplace($List_History_Register, "||", "|", 0, 0)
					$List_History_Register = StringReplace($List_History_Register, "||", "|", 0, 0)
					RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "History", "REG_SZ", $List_History_Register)
					$List_History_Register = RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "History")
					GUICtrlSetData($List_History, $List_History_Register)
				EndIf
				$Combo_Hora_Value = GUICtrlRead($Combo_Hora)
				$Combo_Minuto_Value = GUICtrlRead($Combo_Minuto)
				$sEndDate = String(@YEAR & "/" & @MON & "/" & @MDAY & " " & $Combo_Hora_Value & ":" & $Combo_Minuto_Value & ":00")
				$TimerInSeconds = _DateDiff('s', _NowCalc(), $sEndDate)
				ConsoleWrite("$TimerInSeconds: " & $TimerInSeconds & @CRLF)
				If $TimerInSeconds < 16 And $TimerInSeconds > 0 Then
					MsgBox(262208, "Alert", "You cannot set when there is less than 15 seconds to shut down!")
					GUICtrlSetState($Combo_Hora, $gui_enable)
					GUICtrlSetState($Combo_Minuto, $gui_enable)
					GUICtrlSetState($Button_Shutdown, $gui_show)
					GUICtrlSetState($Button_Clear, $gui_enable)
					GUICtrlSetState($List_History, $gui_enable)
					$Start = 0
					$FloatWindowsShow = 0
					TraySetState(9)
				Else
					_CountDown(1)
				EndIf
			EndIf
	EndSwitch

	If $Start = 1 Then

		If TimerDiff($hTimer) > 500 Then
			$hTimer = TimerInit()
			_CountDown(0)
			$nMsg3 = GUIGetStyle($Form_Main)
			RegWrite("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Volume_Set", "REG_SZ", GUICtrlRead($Combo_Volume))
			;ConsoleWrite("$nMsg3: " & $nMsg3[0] & @CRLF)
			If GUICtrlRead($TrayCheck) = "1" And $nMsg3[0] = "-1261830144" Then
				GUISetState(@SW_HIDE)
				$lockScreen = 0
				Opt("TrayIconHide", 0)
			EndIf
		EndIf
	EndIf

WEnd

Func _Stop()
	TrayItemSetState($iSTOP, $gui_disable)
	GUICtrlSetState($Button_Cancel, $gui_hide)
	GUICtrlSetState($Combo_Hora, $gui_enable)
	GUICtrlSetState($Combo_Minuto, $gui_enable)
	GUICtrlSetState($Button_Clear, $gui_enable)
	GUICtrlSetState($List_History, $gui_enable)
	GUICtrlSetState($Button_Shutdown, $gui_show)
	GUICtrlSetData($Label_countdown, "00:00:00")
	GUICtrlSetColor($Label_countdown, 0x000000)
	TraySetToolTip()
	GUICtrlSetState($Button_Cancel, $GUI_UNCHECKED)
	GUISetBkColor($BK_Color, $Form_Main)
	$FloatWindowsShow = 0
	$Start = 0
	GUISetState(@SW_HIDE, $ahGUI[0])
	TraySetState(8) ; stop flash
	Return
EndFunc   ;==>_Stop

Func _CountDown($type)
	GUICtrlSetState($Button_Cancel, $gui_show)
	TrayItemSetState($iSTOP, $gui_enable)
	$Combo_Hora_Value = GUICtrlRead($Combo_Hora)
	$Combo_Minuto_Value = GUICtrlRead($Combo_Minuto)
	$sEndDate = String(@YEAR & "/" & @MON & "/" & @MDAY & " " & $Combo_Hora_Value & ":" & $Combo_Minuto_Value & ":00")
	$TimerInSeconds = _DateDiff('s', _NowCalc(), $sEndDate)
	If $TimerInSeconds < 0 Then
		$sEndDate = _DateAdd('D', 1, @YEAR & "/" & @MON & "/" & @MDAY & " " & $Combo_Hora_Value & ":" & $Combo_Minuto_Value & ":00")
		$TimerInSeconds = _DateDiff('s', _NowCalc(), $sEndDate)
	EndIf

	If GUICtrlRead($Button_Cancel) = "1" Or GUICtrlRead($iSTOP) = "1" Then
		ConsoleWrite("##### GUICtrlRead($Button_Cancel): " & GUICtrlRead($Button_Cancel) & @CRLF)
		GUICtrlSetState($Button_Cancel, $gui_enable)
		Return
	EndIf

	If $TimerInSeconds < 0 Or $TimerInSeconds = 0 Then
		If $type = 0 Then
			ConsoleWrite($TimerInHours & ":" & $TimerInMinutes & ":" & $TimerInSeconds & @CRLF)
			If $TimerInHours = "00" And $TimerInMinutes = "00" And $TimerInSeconds = "00" Then
				If GUICtrlRead($Radio_Shutdown) = "1" Then
					Shutdown(5)
					Exit
				Else
					If GUICtrlRead($Radio_Stop) = "1" Then
						TraySetState(9)
						_Stop()
;~ 						TraySetState(1)
						Return
					Else
						Exit
					EndIf
				EndIf
			EndIf
		Else
			$Start = 0
			MsgBox(262208, "Alert", "You cannot set when there is less than 15 seconds to shut down / close!")
			GUICtrlSetState($Combo_Hora, $gui_enable)
			GUICtrlSetState($Combo_Minuto, $gui_enable)
			GUICtrlSetState($Button_Shutdown, $gui_show)
			GUICtrlSetState($Button_Clear, $gui_enable)
			GUICtrlSetState($List_History, $gui_enable)
		EndIf

	Else
		$TimerInMinutes = $TimerInSeconds / 60
		$TimerInMinutes = Int($TimerInMinutes)

		$TimerInSeconds = $TimerInSeconds - ($TimerInMinutes * 60)
		If $TimerInSeconds < 0 Then $TimerInSeconds = 00
		If $TimerInSeconds < 10 Then $TimerInSeconds = 0 & $TimerInSeconds

		$TimerInHours = $TimerInMinutes / 60
		$TimerInHours = Int($TimerInHours)
		If $TimerInHours < 0 Then $TimerInHours = 00
		If $TimerInHours < 10 Then $TimerInHours = 0 & $TimerInHours

		$TimerInMinutes = $TimerInMinutes - ($TimerInHours * 60)
		If $TimerInMinutes < 0 Then $TimerInMinutes = 00
		If $TimerInMinutes < 10 Then $TimerInMinutes = 0 & $TimerInMinutes


		GUICtrlSetData($Label_countdown, $TimerInHours & ":" & $TimerInMinutes & ":" & $TimerInSeconds)
		TraySetToolTip()
		TraySetToolTip("Shutdown in " & $TimerInHours & ":" & $TimerInMinutes & ":" & $TimerInSeconds)

		If GUICtrlRead($MouseMove) = "1" And $MouseMoveLock = 1 Then



			$MousePos = MouseGetPos()
;~ 			ConsoleWrite("$MousePos: " & $MousePos[0] & "," & $MousePos[1] & @CRLF & @DesktopWidth - (@DesktopWidth * 0.1) & "," & @DesktopHeight - (@DesktopHeight * 0.1) & @CRLF)
			ConsoleWrite("$MousePos: " & @CRLF & $MousePos[0] & "," & $MousePos[1] & @CRLF)
			ConsoleWrite($MousePos[0] + 3 & "," & $MousePos[1] + 3& @CRLF)
;~ 			Sleep(2000)
;~ 			MouseMove($MousePos[0] + 3, $MousePos[1], 10)
			If $MousePos[0] = $MousePos_Hist[0] And $MousePos[1] = $MousePos_Hist[1] Then
				$MouseCount += 1
			Else
				$MousePos_Hist = MouseGetPos()
				$MouseCount = 0
			EndIf

;~ 			ConsoleWrite("$MouseCount: " & $MouseCount & @CRLF)
			If $MouseCount > GUICtrlRead($MouseSensitivity) Then

				$MWhisper = RegRead("HKEY_CURRENT_USER\Software\ShutdownPRJ\", "Whisper")
				If $MWhisper = "1" Then
					$MousePos = MouseGetPos()
;~ 					MsgBox(262144,"",$MousePos_whisper[0] & "," & $MousePos_whisper[1])
					MouseMove($MousePos[0] + 3, $MousePos[1], GUICtrlRead($MouseSpeed))
					MouseMove($MousePos[0], $MousePos[1], GUICtrlRead($MouseSpeed))
					ConsoleWrite(">>>>>>>>> $MousePos: " & $MousePos[0] & "," & $MousePos[1] & @CRLF & @DesktopWidth - (@DesktopWidth * 0.1) & "," & @DesktopHeight - (@DesktopHeight * 0.1) & @CRLF)
					ConsoleWrite(">>>>>>>>> $MouseCount: " & $MouseCount & @CRLF)
					$MouseCount = 0
				Else
					$Form_Main_Position = WinGetPos($Form_Main)
;~ 					MouseMove(Random(0, @DesktopWidth - (@DesktopWidth * 0.1), 1), Random(0, @DesktopHeight - (@DesktopHeight * 0.1), 1), GUICtrlRead($MouseSpeed))
					$MousePos_Hist = MouseGetPos()
					While $MousePos_Hist[0] > (@DesktopWidth - (@DesktopWidth * 0.1)) And $MousePos_Hist[1] > (@DesktopHeight - (@DesktopHeight * 0.1))
						MouseMove(Random(0, @DesktopWidth - (@DesktopWidth * 0.1), 1), Random(0, @DesktopHeight - (@DesktopHeight * 0.1), 1), GUICtrlRead($MouseSpeed))
						$MousePos_Hist = MouseGetPos()
					WEnd
					$MouseCount = 0
				EndIf

			EndIf
		EndIf


		If $TimerInHours = "00" And $TimerInMinutes = "00" And Number($TimerInSeconds) < Number(59) Then

			If $SecBuff2 <> @SEC Then
				$SecBuff2 = @SEC
				If GUICtrlRead($Sound) = "1" Then
					If $BeepTime <> @SEC Then
						;$BeepTime = @SEC
						;Beep(500, 20)
						SoundPlay(@ScriptDir & "\beep-08b.wav", 1)
					EndIf
				EndIf

				If $FloatWindowsShow = 0 Then
					$FloatWindowsShow = 1
					GUIDelete($ahGUI[0])

					If GUICtrlRead($Radio_Shutdown) = "1" Then
						Global $ahGUI = _GDIPlus_CreateW10TrayWin("This device will shut down soon...", "... time until shutdown: " & $TimerInHours & ":" & $TimerInMinutes & ":" & $TimerInSeconds, $hImage_Icon, @DesktopWidth - 370, @DesktopHeight - 150)
					Else
						If GUICtrlRead($Radio_Stop) = "1" Then
							Global $ahGUI = _GDIPlus_CreateW10TrayWin("This application will stop soon...", "... time until shutdown: " & $TimerInHours & ":" & $TimerInMinutes & ":" & $TimerInSeconds, $hImage_Icon, @DesktopWidth - 370, @DesktopHeight - 150)
						Else
							Global $ahGUI = _GDIPlus_CreateW10TrayWin("This application will close soon...", "... time until shutdown: " & $TimerInHours & ":" & $TimerInMinutes & ":" & $TimerInSeconds, $hImage_Icon, @DesktopWidth - 370, @DesktopHeight - 150)
						EndIf
					EndIf

					GUISetState(@SW_SHOW, $ahGUI[0])
					GUISetState(@SW_SHOWNOACTIVATE, $ahGUI[0])
					$UpdateWindow = 1
				EndIf

				If $UpdateWindow = 1 Then
					If GUICtrlRead($Radio_Shutdown) = "1" Then
						$Texto = "... time until shutdown: " & $TimerInHours & ":" & $TimerInMinutes & ":" & $TimerInSeconds
						_GDIPlot("This device will shut down soon...", $Texto, $hImage_Icon, @DesktopWidth - 370, @DesktopHeight - 150)
					Else
						If GUICtrlRead($Radio_Stop) = "1" Then
							$Texto = "... time until stop: " & $TimerInHours & ":" & $TimerInMinutes & ":" & $TimerInSeconds
							_GDIPlot("This application will stop soon...", $Texto, $hImage_Icon, @DesktopWidth - 370, @DesktopHeight - 150)
						Else
							$Texto = "... time until close: " & $TimerInHours & ":" & $TimerInMinutes & ":" & $TimerInSeconds
							_GDIPlot("This application will close soon...", $Texto, $hImage_Icon, @DesktopWidth - 370, @DesktopHeight - 150)
						EndIf
					EndIf
				EndIf
			EndIf

			GUISetState(@SW_SHOWNOACTIVATE, $ahGUI[0])

			If $TimerInHours = "00" And $TimerInMinutes = "00" And Number($TimerInSeconds) < Number(31) Then
				$MouseMoveLock = 0
				If GUICtrlRead($Sound) = "1" Then
					If $BeepTime <> @SEC Then
						If $TimerInHours = "00" And $TimerInMinutes = "00" And Number($TimerInSeconds) < Number(11) Then

							SoundSetWaveVolume(GUICtrlRead($Combo_Volume))
							SoundPlay(@ScriptDir & "\beep-01a.wav", 1)

						Else
							If $BeepCount > 1 Then
								$BeepCount = 0
								SoundSetWaveVolume(GUICtrlRead($Combo_Volume))
								SoundPlay(@ScriptDir & "\beep-07.wav", 1)
							Else
								$BeepCount += 1
								ConsoleWrite("$BeepCount: " & $BeepCount & @CRLF)
							EndIf

						EndIf
					EndIf
				EndIf
				If $Red = 1 Then
					$FloatWindowsShow = 0
					GUISetBkColor($BK_Color, $Form_Main)

					TraySetState(4)
					GUICtrlSetColor($Label_countdown, 0xFF0000)
					$Red = 0
				Else
					GUISetBkColor($BK_ColorRed, $Form_Main)
					GUICtrlSetColor($Label_countdown, 0x000000)
					$Red = 1
				EndIf
			Else
				If $SecBuff <> @SEC Then
					$SecBuff = @SEC
					TraySetState(4)
					GUICtrlSetColor($Label_countdown, 0xFF0000)
				Else
					GUICtrlSetColor($Label_countdown, 0x000000)
				EndIf
			EndIf

		Else
			$FloatWindowsShow = 0
			GUICtrlSetColor($Label_countdown, 0x000000)
			TraySetState(9)
		EndIf

	EndIf

EndFunc   ;==>_CountDown

Func _GDIPlus_CreateW10TrayWin($sTitle, $sText, $hBmp_Icon = 0, $iGUIPosX = -1, $iGUIPosY = -1, $iW = 360, $iH = 100, $sFontName = "Arial", $fFontSize = 11.5, $iBgColor = 0xFF1F1F1F, $iTitleColor = 0xFFF8F8F8, $iTextColor = 0xFFA0A0A0)
	Global $hGUI_W10TW = GUICreate($sTitle, $iW, $iH, $iGUIPosX, $iGUIPosY, $WS_POPUP, $WS_EX_TOPMOST)
	Global $iLable_Drag = GUICtrlCreateLabel("", 0, 0, $iW, 11, -1, $GUI_WS_EX_PARENTDRAG)
	Global $iPicBg_W10TW = GUICtrlCreatePic("", 0, 0, $iW, $iH)
	GUICtrlSetState(-1, $GUI_DISABLE)
	Global $iPicIcon_W10TW = GUICtrlCreatePic("", 12, 12, 32, 32)
	GUICtrlSetState(-1, $GUI_DISABLE)
	Global $iBtn_W10TW = GUICtrlCreateLabel("X", $iW - 25, 14, 10, 10, BitOR($SS_CENTER, $SS_SIMPLE))
	GUICtrlSetFont(-1, 8, 200, 0, "Arial")
	GUICtrlSetBkColor(-1, BitAND($iBgColor, 0x00FFFFFF))
	GUICtrlSetColor(-1, 0xF0F0F0)
	_GDIPlot($sTitle, $sText, $hBmp_Icon = 0, $iGUIPosX = -1, $iGUIPosY = -1, $iW = 360, $iH = 100, $sFontName = "Arial", $fFontSize = 11.5, $iBgColor = 0xFF1F1F1F, $iTitleColor = 0xFFF8F8F8, $iTextColor = 0xFFA0A0A0)
	Global $aGUI_W10TW[2] = [$hGUI_W10TW, $iBtn_W10TW]
	Return $aGUI_W10TW
EndFunc   ;==>_GDIPlus_CreateW10TrayWin

Func _GDIPlot($sTitle, $sText, $hBmp_Icon = 0, $iGUIPosX = -1, $iGUIPosY = -1, $iW = 360, $iH = 100, $sFontName = "Arial", $fFontSize = 11.5, $iBgColor = 0xFF1F1F1F, $iTitleColor = 0xFFF8F8F8, $iTextColor = 0xFFA0A0A0)

	Global $hBitmap = _GDIPlus_BitmapCreateFromScan0($iW, $iH)
	Global $hGfx = _GDIPlus_ImageGetGraphicsContext($hBitmap)
	_GDIPlus_GraphicsSetSmoothingMode($hGfx, 4)
	_GDIPlus_GraphicsSetPixelOffsetMode($hGfx, 2)
	_GDIPlus_GraphicsSetTextRenderingHint($hGfx, 5)
	_GDIPlus_GraphicsClear($hGfx, $iBgColor)
	Local $hBmp_GDI
	Local $hPen_Border = _GDIPlus_PenCreate(0xFF484848)
	Global $hBrush_TextTitle = _GDIPlus_BrushCreateSolid($iTitleColor), $hBrush_Text = _GDIPlus_BrushCreateSolid($iTextColor)
	_GDIPlus_GraphicsDrawRect($hGfx, 0, 0, $iW - 1, $iH - 1, $hPen_Border)

	Local $tLayout_Title = _GDIPlus_RectFCreate(56, 13, $iW - 80, 16)
	Global $hFormat_Title = _GDIPlus_StringFormatCreate()
	Global $hFamily_Title = _GDIPlus_FontFamilyCreate($sFontName)
	Global $hFont_Title = _GDIPlus_FontCreate($hFamily_Title, $fFontSize, 1)
	_GDIPlus_GraphicsDrawStringEx($hGfx, $sTitle, $hFont_Title, $tLayout_Title, $hFormat_Title, $hBrush_TextTitle)

	Global $tLayout_Text = _GDIPlus_RectFCreate(56, 33, $iW - 80, $iH - 35)
	Global $hFormat_Text = _GDIPlus_StringFormatCreate()
	Global $hFamily_Text = _GDIPlus_FontFamilyCreate($sFontName)
	Global $hFont_Text = _GDIPlus_FontCreate($hFamily_Title, $fFontSize - 1)
	_GDIPlus_GraphicsDrawStringEx($hGfx, $sText, $hFont_Text, $tLayout_Text, $hFormat_Text, $hBrush_Text)

	$hBmp_GDI = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hBitmap)
	_WinAPI_DeleteObject(GUICtrlSendMsg($iPicBg_W10TW, $STM_SETIMAGE, $IMAGE_BITMAP, $hBmp_GDI))
	_WinAPI_DeleteObject($hBmp_GDI)
	_GDIPlus_FontDispose($hFont_Title)
	_GDIPlus_FontFamilyDispose($hFamily_Title)
	_GDIPlus_StringFormatDispose($hFormat_Title)
	_GDIPlus_FontDispose($hFont_Text)
	_GDIPlus_FontFamilyDispose($hFamily_Text)
	_GDIPlus_StringFormatDispose($hFormat_Text)
	_GDIPlus_BitmapDispose($hBitmap)
	_GDIPlus_GraphicsDispose($hGfx)
	_GDIPlus_BrushDispose($hBrush_Text)
	_GDIPlus_BrushDispose($hBrush_TextTitle)
	_GDIPlus_PenDispose($hPen_Border)
	If $hBmp_Icon Then
		Local $aDim = _GDIPlus_ImageGetDimension($hBmp_Icon), $fScaleX, $fScaleY
		If $aDim[0] >= $aDim[1] Then
			$fScaleX = 32 / $aDim[0]
			$fScaleY = $fScaleX
		ElseIf $aDim[0] < $aDim[1] Then
			$fScaleY = 32 / $aDim[1]
			$fScaleX = $fScaleY
		EndIf
		Global $hBmp_tmp = _GDIPlus_ImageScale($hBmp_Icon, $fScaleX, $fScaleY)
		$hBmp_GDI = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hBmp_tmp)
		_WinAPI_DeleteObject(GUICtrlSendMsg($iPicIcon_W10TW, $STM_SETIMAGE, $IMAGE_BITMAP, $hBmp_GDI))
		_GDIPlus_BitmapDispose($hBmp_tmp)
		_WinAPI_DeleteObject($hBmp_GDI)
	EndIf

	GUICtrlSetState($iBtn_W10TW, $GUI_SHOW)

EndFunc   ;==>_GDIPlot
