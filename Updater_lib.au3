#include-once
; ----------------------------------------------------------------------------------------------------------------------
; Updater
; ----------------------------------------------------------------------------------------------------------------------

; COM error handler (catches $oConn.Execute failures instead of crashing)
Global $g_oComErr = ObjEvent("AutoIt.Error", "_ComErrorHandler")
Global $g_sLastComError = ""

Func _ComErrorHandler()
    Local $oErr = $g_oComErr
    $g_sLastComError = "COM Error 0x" & Hex($oErr.number, 8) & ": " & $oErr.description
    _LogVerbose("COM error captured: " & $g_sLastComError)
EndFunc

; ----------------------------------------------------------------------------------------------------------------------
; Logging helpers
; Verbose mode is controlled by settings.ini:
; [Logging]
; VerboseMode=1
; ----------------------------------------------------------------------------------------------------------------------
Func _GetLogPath()
    If IsDeclared("g_sLogPath") Then
        Local $sPath = Eval("g_sLogPath")
        If StringStripWS($sPath, 3) <> "" Then Return $sPath
    EndIf

    Return @ScriptDir & "\log\Shutdown_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & "_" & @ComputerName & "_" & @UserName & ".log"
EndFunc

Func _IsVerboseLogEnabled()
    If IsDeclared("g_iVerboseMode") Then Return Number(Eval("g_iVerboseMode")) = 1
    Return Number(IniRead(@ScriptDir & "\settings.ini", "Logging", "VerboseMode", "0")) = 1
EndFunc

Func _LogWrite($sMessage, $bVerbose = False)
    If $bVerbose And Not _IsVerboseLogEnabled() Then Return

    Local $sLogPath = _GetLogPath()
    Local $iSlash = StringInStr($sLogPath, "\", 0, -1)
    If $iSlash > 0 Then
        Local $sLogDir = StringLeft($sLogPath, $iSlash - 1)
        If StringStripWS($sLogDir, 3) <> "" And Not FileExists($sLogDir) Then DirCreate($sLogDir)
    EndIf

    _FileWriteLog($sLogPath, $sMessage)
EndFunc

Func _LogInfo($sMessage)
    _LogWrite("INFO    | " & $sMessage, False)
EndFunc

Func _LogVerbose($sMessage)
    _LogWrite("VERBOSE | " & $sMessage, True)
EndFunc


Func _GetUpdateAppName()
    ; Keep the update staging name stable and independent from @ScriptName casing.
    ; shutdown.exe on GitHub is lowercase, and GitHub raw URLs are case-sensitive.
    If IsDeclared("g_sUpdateAppName") Then
        Local $sConfiguredAppName = StringStripWS(Eval("g_sUpdateAppName"), 3)
        If $sConfiguredAppName <> "" Then Return $sConfiguredAppName
    EndIf

    Local $sScriptBase = _FileNameWithoutExtension(@ScriptName)
    If StringStripWS($sScriptBase, 3) = "" Then Return "shutdown"
    Return StringLower($sScriptBase)
EndFunc

Func _GetPublishedExeName()
    ; Official published executable name in GitHub. Do not derive this from @ScriptName.
    If IsDeclared("g_sPublishedExeName") Then
        Local $sConfiguredExeName = StringStripWS(Eval("g_sPublishedExeName"), 3)
        If $sConfiguredExeName <> "" Then Return $sConfiguredExeName
    EndIf

    Return _GetUpdateAppName() & ".exe"
EndFunc

Func _CheckGitHubUpdate($bManual = False)
    _LogInfo("GitHub update check started. Manual=" & $bManual)
    _LogVerbose("Runtime context: ScriptFullPath=" & @ScriptFullPath & " | ScriptName=" & @ScriptName & " | ScriptDir=" & @ScriptDir & " | Compiled=" & @Compiled & " | AutoItX64=" & @AutoItX64 & " | OS=" & @OSVersion)
    _LogVerbose("Update settings: raw_base=" & $g_sGitHubRawBase & " | published_exe=" & _GetPublishedExeName() & " | update_app_name=" & _GetUpdateAppName() & " | settings.ini=" & @ScriptDir & "\settings.ini")

    Local $sCurrentVersion = FileGetVersion(@ScriptFullPath)
    _LogVerbose("Local FileGetVersion(" & @ScriptFullPath & ") returned: '" & $sCurrentVersion & "' | @error=" & @error & " | @extended=" & @extended)
    If StringStripWS($sCurrentVersion, 3) = "" Then
        _LogInfo("GitHub update check skipped: local file version could not be read from " & @ScriptFullPath)
        If $bManual Then MsgBox(48, "Shutdown Update", "The local application version could not be read. Check the log file for details." & @CRLF & @CRLF & _GetLogPath())
        Return False
    EndIf

    Local $sAppName = _GetUpdateAppName()
    Local $sPublishedExeName = _GetPublishedExeName()
    Local $sRemoteVersionUrl = _JoinUrl($g_sGitHubRawBase, "version.txt")
    Local $sRemoteExeUrl = _JoinUrl($g_sGitHubRawBase, $sPublishedExeName)
    Local $sRemoteVersionTmp = @ScriptDir & "\" & $sAppName & "_github_version.txt"
    Local $sRemoteExeTmp = @ScriptDir & "\" & $sAppName & "_github_latest.exe"
    Local $sLocalTmp = @ScriptDir & "\" & $sAppName & ".tmp"
    Local $sUpdaterFile = @ScriptDir & "\Updater.exe"

    _LogVerbose("Resolved update paths: app_name=" & $sAppName & " | published_exe=" & $sPublishedExeName & " | version_url=" & $sRemoteVersionUrl & " | exe_url=" & $sRemoteExeUrl & " | version_tmp=" & $sRemoteVersionTmp & " | exe_tmp=" & $sRemoteExeTmp & " | local_tmp=" & $sLocalTmp & " | updater=" & $sUpdaterFile)

    If FileExists($sUpdaterFile) Then
        Local $bDeletedUpdater = FileDelete($sUpdaterFile)
        _LogVerbose("Existing Updater.exe deleted before refresh. Result=" & $bDeletedUpdater & " | @error=" & @error)
    Else
        _LogVerbose("No existing Updater.exe found before update check.")
    EndIf

    Local $sRemoteVersion = _GetGitHubVersionFromTextFile($sRemoteVersionUrl, $sRemoteVersionTmp)
    If StringStripWS($sRemoteVersion, 3) = "" Then
        _LogInfo("GitHub update check skipped: remote version.txt could not be read or parsed.")
        FileDelete($sRemoteVersionTmp)
        If $bManual Then MsgBox(48, "Shutdown Update", "Could not read the remote version.txt from GitHub. Check the log file for details." & @CRLF & @CRLF & _GetLogPath())
        Return False
    EndIf

    Local $iVersionCompare = _CompareVersions($sRemoteVersion, $sCurrentVersion)
    _LogInfo("Version comparison completed. Local=" & $sCurrentVersion & " | GitHub=" & $sRemoteVersion & " | CompareResult=" & $iVersionCompare)

    If $iVersionCompare <= 0 Then
        _LogInfo("No update required.")
        FileDelete($sRemoteVersionTmp)
        If $bManual Then MsgBox(64, "Shutdown Update", "You already have the latest version." & @CRLF & @CRLF & "Local version: " & $sCurrentVersion & @CRLF & "GitHub version: " & $sRemoteVersion)
        Return False
    EndIf

    _LogInfo("Newer GitHub version found. Downloading executable from: " & $sRemoteExeUrl)

    If Not _DownloadFile($sRemoteExeUrl, $sRemoteExeTmp) Then
        _LogInfo("Update aborted: executable download failed.")
        FileDelete($sRemoteVersionTmp)
        If $bManual Then MsgBox(48, "Shutdown Update", "The new executable could not be downloaded. Check the log file for details." & @CRLF & @CRLF & _GetLogPath())
        Return False
    EndIf

    ; Validate that the executable we are about to install matches the version announced in version.txt.
    ; This prevents installing an older exe when version.txt was updated before the executable was published.
    Local $sDownloadedExeVersion = FileGetVersion($sRemoteExeTmp)
    _LogVerbose("Downloaded executable FileGetVersion(" & $sRemoteExeTmp & ") returned: '" & $sDownloadedExeVersion & "' | @error=" & @error & " | @extended=" & @extended & " | size=" & FileGetSize($sRemoteExeTmp))
    If StringStripWS($sDownloadedExeVersion, 3) = "" Then
        _LogInfo("Update aborted: downloaded executable version could not be read.")
        FileDelete($sRemoteVersionTmp)
        FileDelete($sRemoteExeTmp)
        If $bManual Then MsgBox(48, "Shutdown Update", "The downloaded executable version could not be read. Check the log file for details." & @CRLF & @CRLF & _GetLogPath())
        Return False
    EndIf

    If _CompareVersions($sDownloadedExeVersion, $sRemoteVersion) < 0 Then
        _LogInfo("Update aborted: downloaded executable version is older than version.txt. Downloaded=" & $sDownloadedExeVersion & " | version.txt=" & $sRemoteVersion)
        FileDelete($sRemoteVersionTmp)
        FileDelete($sRemoteExeTmp)
        If $bManual Then MsgBox(48, "Shutdown Update", "The downloaded executable is older than the version announced in version.txt. Check the log file for details." & @CRLF & @CRLF & _GetLogPath())
        Return False
    EndIf

    If _CompareVersions($sDownloadedExeVersion, $sCurrentVersion) <= 0 Then
        _LogInfo("Update aborted: downloaded executable version is not newer. Downloaded=" & $sDownloadedExeVersion & " | Local=" & $sCurrentVersion)
        FileDelete($sRemoteVersionTmp)
        FileDelete($sRemoteExeTmp)
        If $bManual Then MsgBox(64, "Shutdown Update", "The downloaded executable is not newer than the installed version. Check the log file for details." & @CRLF & @CRLF & _GetLogPath())
        Return False
    EndIf

    FileDelete($sLocalTmp)
    _LogVerbose("Staging update. Moving downloaded exe to local tmp: " & $sLocalTmp)
    If Not FileMove($sRemoteExeTmp, $sLocalTmp, 9) Then
        _LogInfo("Update aborted: could not stage downloaded file at " & $sLocalTmp & " | @error=" & @error)
        FileDelete($sRemoteVersionTmp)
        FileDelete($sRemoteExeTmp)
        If $bManual Then MsgBox(48, "Shutdown Update", "The update was downloaded but could not be staged. Check the log file for details." & @CRLF & @CRLF & _GetLogPath())
        Return False
    EndIf

    _LogInfo("Update staged successfully at: " & $sLocalTmp)

    Local $bInstalledUpdater = FileInstall("Updater.exe", $sUpdaterFile, 1)
    _LogVerbose("FileInstall Updater.exe result=" & $bInstalledUpdater & " | target=" & $sUpdaterFile & " | exists=" & FileExists($sUpdaterFile) & " | @error=" & @error)
    If Not FileExists($sUpdaterFile) Then
        _LogInfo("Update aborted: Updater.exe could not be installed/extracted.")
        If $bManual Then MsgBox(48, "Shutdown Update", "Updater.exe could not be prepared. Check the log file for details." & @CRLF & @CRLF & _GetLogPath())
        Return False
    EndIf

    Local $sRunCommand = '"' & $sUpdaterFile & '" "' & @ScriptDir & '"'
    _LogInfo("Launching Updater.exe with command: " & $sRunCommand)
    Local $iPid = Run($sRunCommand, @ScriptDir)
    _LogVerbose("Run updater returned PID=" & $iPid & " | @error=" & @error & " | @extended=" & @extended)
    If $iPid = 0 Then
        _LogInfo("Update aborted: Updater.exe could not be started.")
        If $bManual Then MsgBox(48, "Shutdown Update", "Updater.exe could not be started. Check the log file for details." & @CRLF & @CRLF & _GetLogPath())
        Return False
    EndIf

    _LogInfo("Updater.exe launched. Current application will exit to allow replacement.")
    Sleep(100)
    Exit
EndFunc

Func _GetGitHubVersionFromTextFile($sUrl, $sDestination)
    _LogVerbose("Reading GitHub version file. URL=" & $sUrl & " | destination=" & $sDestination)
    FileDelete($sDestination)
    If Not _DownloadFile($sUrl, $sDestination) Then Return ""

    Local $sContent = FileRead($sDestination)
    Local $iReadError = @error
    _LogVerbose("version.txt FileRead completed. @error=" & $iReadError & " | raw_length=" & StringLen($sContent))
    If $iReadError Then Return ""

    $sContent = StringStripWS($sContent, 3)
    _LogVerbose("version.txt content after trim: '" & $sContent & "'")

    ; version.txt must contain only the version number, for example: 1.1.5.0
    Local $aMatch = StringRegExp($sContent, "^([0-9]+(?:\.[0-9]+){1,3})$", 1)
    If @error Or UBound($aMatch) = 0 Then
        _LogInfo("Invalid version.txt content: '" & $sContent & "'")
        Return ""
    EndIf

    Return $aMatch[0]
EndFunc

Func _DownloadFile($sUrl, $sDestination)
    _LogVerbose("Download started. URL=" & $sUrl & " | destination=" & $sDestination)
    FileDelete($sDestination)

    Local $hDownload = InetGet($sUrl, $sDestination, $INET_FORCERELOAD, $INET_DOWNLOADWAIT)
    Local $iInetError = @error
    Local $iInetExtended = @extended
    Local $bExists = FileExists($sDestination)
    Local $iSize = 0
    If $bExists Then $iSize = FileGetSize($sDestination)

    _LogVerbose("Download finished. Return=" & $hDownload & " | @error=" & $iInetError & " | @extended=" & $iInetExtended & " | exists=" & $bExists & " | size=" & $iSize)
    If $iInetError Or $hDownload = 0 Or Not $bExists Or $iSize <= 0 Then
        _LogInfo("Download failed: " & $sUrl & " | destination=" & $sDestination & " | return=" & $hDownload & " | @error=" & $iInetError & " | @extended=" & $iInetExtended & " | exists=" & $bExists & " | size=" & $iSize)
        Return False
    EndIf

    Return True
EndFunc

Func _JoinUrl($sBase, $sFile)
    Local $sCleanBase = StringStripWS($sBase, 3)
    While StringRight($sCleanBase, 1) = "/"
        $sCleanBase = StringTrimRight($sCleanBase, 1)
    WEnd
    Local $sUrl = $sCleanBase & "/" & $sFile
    _LogVerbose("Joined URL: base=" & $sBase & " | file=" & $sFile & " | result=" & $sUrl)
    Return $sUrl
EndFunc

Func _FileNameWithoutExtension($sFileName)
    Local $iDot = StringInStr($sFileName, ".", 0, -1)
    If $iDot <= 1 Then Return $sFileName
    Return StringLeft($sFileName, $iDot - 1)
EndFunc

Func _CompareVersions($sLeft, $sRight)
    _LogVerbose("Comparing versions: left=" & $sLeft & " | right=" & $sRight)
    Local $aLeft = StringSplit(StringStripWS($sLeft, 3), ".")
    Local $aRight = StringSplit(StringStripWS($sRight, 3), ".")
    Local $iMax = $aLeft[0]
    If $aRight[0] > $iMax Then $iMax = $aRight[0]

    For $i = 1 To $iMax
        Local $nLeft = 0
        Local $nRight = 0
        If $i <= $aLeft[0] Then $nLeft = Number($aLeft[$i])
        If $i <= $aRight[0] Then $nRight = Number($aRight[$i])

        _LogVerbose("Version segment " & $i & ": left=" & $nLeft & " | right=" & $nRight)
        If $nLeft > $nRight Then Return 1
        If $nLeft < $nRight Then Return -1
    Next

    Return 0
EndFunc
