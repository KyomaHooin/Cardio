;
; Secure Rsync NAS GUI
;
; Copyright (c) 2021 Kyoma Hooin
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;

#AutoIt3Wrapper_Res_Description=Secure Rsync NAS GUI
#AutoIt3Wrapper_Res_ProductName=NAS
#AutoIt3Wrapper_Res_ProductVersion=1.4
#AutoIt3Wrapper_Res_CompanyName=Kyouma Houin
#AutoIt3Wrapper_Res_LegalCopyright=GNU GPL v3
#AutoIt3Wrapper_Res_Language=1029
#AutoIt3Wrapper_Icon=NAS.ico
#NoTrayIcon

; ---------------------------------------------------------
;INCLUDE
; ---------------------------------------------------------

#include <File.au3>
#Include <GuiEdit.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPIProc.au3>

; ---------------------------------------------------------
;VAR
; ---------------------------------------------------------

global $version = '1.4'
global $ini = @ScriptDir & '\NAS.ini'
global $rsync_binary = @ScriptDir & '\bin\rsync.exe'
global $ssh_binary = @ScriptDir & '\bin\ssh.exe'

global $key = @ScriptDir & '\key\id_ed25519'
global $remote_user = 'backup'
global $remote_host = '10.8.0.1'
global $remote_port = '22'
global $remote_prefix = '/volume1/'

global $configuration[0][2]
global $ctrl[10][4]
global $error_code[25][2]=[ _
	[0,'Dokončeno.'], _
	[1,'Chyba syntaxe.'], _
	[2,'Chyba kompatibility protokolu.'], _
	[3,'Chyba při výběru souborů, nebo adresářů.'], _
	[4,'Požadovaná akce není podporována.'], _
	[5,'Chyba při zahájení klient-server protokolu.'], _
	[6,'Chyba při zápisu do logu.'], _
	[10,'I/O chyba soketu.'], _
	[11,'I/O chyba souboru.'], _
	[12,'Chyba v datovém proudu.'], _
	[13,'Diagnostická chyba.'], _
	[14,'Chyba IPC.'], _
	[20,'Signál přerušení SIGUSR1, SIGINT.'], _
	[21,'Chyba při čekání procesu.'], _
	[22,'Nedostatek paměti.'], _
	[23,'Chyba během přenosu.'], _
	[24,'Nedostupný zdroj během přenosu.'], _
	[25,'Omezení smazání souboru.'], _
	[30,'Vypršení časového limitu přenosu.'], _
	[35,'Vypršení časového limitu spojení.'], _
	[124,'Neočekávaná chyba.'], _
	[125,'Příkaz ukončen signálem.'], _
	[126,'Příkaz nelze spustit.'], _
	[127,'Příkaz nebyl nalezen.'], _
	[255,'Neočekávaná chyba.']]

; ---------------------------------------------------------
;CONTROL
; ---------------------------------------------------------

; one instance
if UBound(ProcessList(@ScriptName)) > 2 then
	MsgBox(48, 'NAS Záloha ' & $version, 'Program byl již spuštěn.')
	exit
endif

; logging
$log = FileOpen(@ScriptDir & '\' & 'NAS.log', 1)
if @error then
	MsgBox(48, 'NAS Záloha ' & $version, 'System je připojen pouze pro čtení.')
	exit
endif

; ---------------------------------------------------------
; INIT
; ---------------------------------------------------------

logger('Start programu: ' & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)

; read configuration
if not FileExists($ini) then
	$f = FileOpen($ini, 1)
	for $i=1 to 10
		FileWriteLine($f, 'source' & $i & '=')
		FileWriteLine($f, 'target' & $i & '=')
	next
	FileClose($f)
endif
_FileReadToArray($ini, $configuration, 0, '='); 0-based
if @error then
	MsgBox(0, 'NAS Záloha ' & $version, 'Načtení konfiguračního INI souboru selhalo.')
	exit
else
	logger("Konfigurační INI soubor byl načten.")
endif

; ---------------------------------------------------------
; GUI
; ---------------------------------------------------------

$gui = GUICreate('NAS Záloha ' & $version, 615, 300, Default, Default)
$gui_group1 = GUICtrlCreateGroup('Zdroj', 5, 0, 378, 270)
$gui_group100 = GUICtrlCreateGroup('Cíl', 386, 0, 224, 270)

for $i = 0 to 9
	$ctrl[$i][0] = GUICtrlCreateInput($configuration[$i*2][1], 12, 15 + $i * 25, 282, 21)
	$ctrl[$i][1] = GUICtrlCreateButton("Procházet", 300, 15 + $i * 25, 75, 21)
	$ctrl[$i][2] = GUICtrlCreateLabel($remote_prefix, 394, 18 + $i * 25, 50, 21)
	$ctrl[$i][3] = GUICtrlCreateInput($configuration[$i*2+1][1], 450, 15 + $i * 25, 153, 21)
next

$gui_error = GUICtrlCreateLabel('', 10, 278, 358, 21)
$gui_button_backup = GUICtrlCreateButton('Zálohovat', 378, 275, 75, 21)
$gui_button_cancel = GUICtrlCreateButton('Přerušit', 456, 275, 75, 21)
$gui_button_exit = GUICtrlCreateButton('Konec', 534, 275, 75, 21)

; set default focus
GUICtrlSetState($gui_button_exit, $GUI_FOCUS)

GUISetState(@SW_SHOW)

; ---------------------------------------------------------
; MAIN
; ---------------------------------------------------------

while 1
	$event = GUIGetMsg()
	; source/target selection
	$browse = _ArrayBinarySearch($ctrl, $event, Default, Default, 1)
	if not @error then
		$path = FileSelectFolder('NAS Záloha ' & $version & ' - Zdrojový adresář', @HomeDrive)
			if not @error then GUICtrlSetData($ctrl[$browse][0], $path)
	endif
	; backup
	if $event = $gui_button_backup then
		; disable button
		GUICtrlSetState($gui_button_backup, $GUI_DISABLE)
		; backup
		for $i = 0 to 9
			if FileExists(GUICtrlRead($ctrl[$i][0])) then
				logger('[' & $i + 1 & '] Zálohovaní zahájeno.')
				GUICtrlSetBkColor($ctrl[$i][0], 0xffb347)
				rsync(get_cygwin_path(GUICtrlRead($ctrl[$i][0])),StringRegExpReplace(GUICtrlRead($ctrl[$i][3]), '\\', '\/'), $ctrl[$i][0])
				logger('[' & $i + 1 & '] Zalohování dokončeno.')
			ElseIf GUICtrlRead($ctrl[$i][0]) <> '' then
				logger('[' & $i + 1 & '] Chyba: Zdrojový, nebo cílový adresář neexistuje.')
			endif
		next
		; enable button
		GUICtrlSetState($gui_button_backup, $GUI_ENABLE)
	endif
	; exit
	if $event = $GUI_EVENT_CLOSE or $event = $gui_button_exit then
		; write configuration
		$f = FileOpen($ini, 2); overwrite
		for $i=0 to 9
			FileWriteLine($ini, 'source' & $i + 1 & '=' & GUICtrlRead($ctrl[$i][0]))
			FileWriteLine($ini, 'target' & $i + 1 & '=' & GUICtrlRead($ctrl[$i][3]))
		next
		FileClose($f)
		; exit
		exitloop
	endif
wend

; exit
logger('Konec programu: ' & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)
logger('------------------------------------')
FileClose($log)
exit

; ---------------------------------------------------------
; FUNC
; ---------------------------------------------------------

func logger($text)
	FileWriteLine($log, $text)
endfunc

func get_cygwin_path($path)
	local $cygwin_path
	$cygwin_path = StringRegExpReplace($path , '\\', '\/'); convert backslash -> slash
	$cygwin_path = StringRegExpReplace($cygwin_path ,'^(.)\:(.*)', '\/cygdrive\/$1$2'); convert drive colon
	return StringRegExpReplace($cygwin_path ,'(.*)', '$1'); catch space by doublequote
endfunc

func rsync($source,$target,$handle)
	local $buffer, $out_buffer, $err_buffer, $code, $code_index, $proc, $exit_code
	; rsync
	$rsync = Run(@ComSpec & ' /c ' & $rsync_binary & ' -avz -h -e ' & "'" _
		& get_cygwin_path($ssh_binary) _
		& ' -o "StrictHostKeyChecking no"' _
		& ' -o "UserKnownHostsFile=/dev/null"' _
		& ' -p ' & $remote_port _
		& ' -i "' & get_cygwin_path($key) & '"' & "' '" _
		& $source & "' '" _
		& $remote_user & '@' & $remote_host & ':' & $remote_prefix & $target & "'" _
		, @ScriptDir, @SW_HIDE, BitOR($STDERR_CHILD, $STDOUT_CHILD) _
	)
	; stderr / stdout
	while ProcessExists($rsync)
		$out_buffer = StringReplace(StdoutRead($rsync), @LF, @CRLF)
		if $out_buffer <> '' then $buffer &= $out_buffer
		$err_buffer = StringReplace(StderrRead($rsync), @LF, @CRLF)
		if $err_buffer <> '' then $buffer &= $err_buffer
	wend
	; exit code
	$proc = _WinAPI_OpenProcess($PROCESS_QUERY_LIMITED_INFORMATION, 0, $rsync)
	$exit_code = DllCall("kernel32.dll", "bool", "GetExitCodeProcess", "HANDLE", $proc, "dword*", -1)
	if not @error then
		if $exit_code[2] = 0 then
			GUICtrlSetBkColor($handle, 0x77dd77)
			GUICtrlSetData($gui_error, 'Hotovo.')
		else
			$code_index = _ArrayBinarySearch($error_code, $exit_code[2])
			if not @error then
				GUICtrlSetData($gui_error, $error_code[$code_index][1])
				GUICtrlSetBkColor($handle, 0xff6961)
				GUICtrlSetColor($gui_error, 0xff0000)
			Else
				logger('rsync: Kód  ukončení ' & $exit_code[2] & '.')
			endif
		endif
	endif
	_WinAPI_CloseHandle($proc)
	; error code
	if $buffer <> '' then
		$code = StringRegExp($buffer, '\(code (\d+)\)', $STR_REGEXPARRAYMATCH)
		if not @error then
			logger('rsync: Kód chyby ' & $code[0] & '.')
		endif
	endif
	; logging
	logger($buffer)
	;exit
	return
EndFunc
