#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=shutdown.ico
#AutoIt3Wrapper_Res_Description=Work Day updater
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#AutoIt3Wrapper_Res_ProductName=Work Days Updater
#AutoIt3Wrapper_Res_File_Add=E:\GitHub\Shutdown\splash.jpg
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.16.1
 Author:         myName

 Script Function:
	Template AutoIt script.

#ce ----------------------------------------------------------------------------
#pragma compile(inputboxres, true)

Opt("TrayIconHide", 1)
Opt("TrayAutoPause", 0)

#include <WindowsStylesConstants.au3>
#include <StaticConstants.au3>
$sSplashPath = @TempDir & "\splash.jpg"
FileInstall("splash.jpg", $sSplashPath, 1)
Sleep(1000)
$Path = StringReplace($CmdLineRaw,"'","")


;~ _splash()
;~ Sleep(30000)
;~ MsgBox(262144,"",$Path & "\Workdays.tmp")

If Not FileExists($Path & "\Shutdown.tmp") Then
	Exit
Else
	_splash()
	Sleep(8000)
	FileMove($Path & "\Shutdown.tmp",$Path & "\Shutdown.exe",9)
	Sleep(2000)
	Run($Path & "\Shutdown.exe")
EndIf
Exit

Func _splash()

	$splashWin_X = 640
	$splashWin_Y = 360

	Global $Form_Splash = GUICreate("", $splashWin_X, $splashWin_Y, -1, -1, $WS_POPUP, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW, $WS_EX_LAYERED))


	Global $Pic_Splash = GUICtrlCreatePic($sSplashPath, 5, 5, 630, 350)

	Global $Label_Percentage = GUICtrlCreateLabel("Updating . . .", 5, 290, 630, 40, $SS_CENTER)
	GUICtrlSetFont($Label_Percentage, 20)
	GUICtrlSetColor($Label_Percentage, 0xFF0000)

	GUISetState(@SW_SHOW, $Form_Splash)


EndFunc   ;==>_splash
