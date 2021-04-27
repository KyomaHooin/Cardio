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
#AutoIt3Wrapper_Res_ProductVersion=1.5
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

global $version = '1.5'
global $ini = @ScriptDir & '\NAS.ini'
global $log = @ScriptDir & '\' & 'NAS.log'
global $rsync_binary = @ScriptDir & '\bin\rsync.exe'
global $ssh_binary = @ScriptDir & '\bin\ssh.exe'

global $configuration[0][2]
global $ctrl[10][5]
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
$log = FileOpen($log, 1)
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
		FileWriteLine($f, 'enable' & $i & '=')
	next
	FileWriteLine($f, 'key=')
	FileWriteLine($f, 'user=')
	FileWriteLine($f, 'host=')
	FileWriteLine($f, 'port=')
	FileWriteLine($f, 'prefix=')
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

$gui = GUICreate('NAS Záloha ' & $version, 632, 340, Default, Default)
$gui_tab = GUICtrlCreateTab(5,5,621,302)

$gui_tab_dir = GUICtrlCreateTabItem('Adresář')
$gui_group_source = GUICtrlCreateGroup('Zdroj', 12, 28, 379, 270)
$gui_group_target = GUICtrlCreateGroup('Cíl', 394, 28, 224, 270)
for $i = 0 to 9
	$ctrl[$i][0] = GUICtrlCreateCheckbox('', 20, 43 + $i * 25, 16, 21)
	GUICtrlSetState($ctrl[$i][0], $configuration[$i*3+2][1])
	$ctrl[$i][1] = GUICtrlCreateInput($configuration[$i*3][1], 40, 44 + $i * 25, 264, 21)
	$ctrl[$i][2] = GUICtrlCreateButton("Procházet", 308, 44 + $i * 25, 75, 21)
	$ctrl[$i][3] = GUICtrlCreateLabel(get_conf_value($configuration, 'prefix'), 400, 48 + $i * 25, 90, 21, 0x01); $SS_CENTER
	$ctrl[$i][4] = GUICtrlCreateInput($configuration[$i*3+1][1], 496, 44 + $i * 25, 113, 21)
next

$gui_tab_progress = GUICtrlCreateTabItem('Průběh')
$gui_progress = GUICtrlCreateEdit('', 15, 35, 600, 262, BitOR($ES_AUTOVSCROLL,$ES_READONLY,$ES_WANTRETURN,$WS_VSCROLL))

$gui_tab_setup = GUICtrlCreateTabItem('Nastavení')
$gui_group_connection = GUICtrlCreateGroup('Připojení', 12, 28, 605, 94)
$gui_host_label = GUICtrlCreateLabel('Adresa IP:', 20 ,48 , 60, 21)
$gui_host = GUICtrlCreateInput(get_conf_value($configuration, 'host'), 240, 44, 90, 21)
$gui_port_label = GUICtrlCreateLabel('Port:', 20 ,72 , 25, 21)
$gui_port = GUICtrlCreateInput(get_conf_value($configuration, 'port'), 290, 68, 40, 21)
$gui_user_label = GUICtrlCreateLabel('Uživatel:', 20 , 96, 40, 21)
$gui_user = GUICtrlCreateInput(get_conf_value($configuration, 'user'), 240, 92, 90, 21)
$gui_group_key = GUICtrlCreateGroup('SSH', 12, 122, 605, 46)
$gui_prefix_label = GUICtrlCreateLabel('Klíč:', 20 ,142, 90, 21)
$gui_key = GUICtrlCreateInput(get_conf_value($configuration, 'key'), 48, 138, 282, 21)
$gui_button_key = GUICtrlCreateButton('Procházet', 334, 138, 75, 21)
$gui_group_nas = GUICtrlCreateGroup('NAS', 12, 168, 605, 46)
$gui_prefix_label = GUICtrlCreateLabel('Prefix:', 20 ,188, 30, 21)
$gui_prefix = GUICtrlCreateInput(get_conf_value($configuration, 'prefix'), 220, 184, 110, 21)
$gui_group_fill = GUICtrlCreateGroup('', 12, 214, 605, 84)

$gui_tab_end = GUICtrlCreateTabItem('')

$gui_error = GUICtrlCreateLabel('', 10, 318, 358, 21)
$gui_button_backup = GUICtrlCreateButton('Zálohovat', 472, 314, 75, 21); 394
;$gui_button_cancel = GUICtrlCreateButton('Přerušit', 472, 314, 75, 21)
$gui_button_exit = GUICtrlCreateButton('Konec', 550, 314, 75, 21)

; set default focus
GUICtrlSetState($gui_button_exit, $GUI_FOCUS)

GUISetState(@SW_SHOW)

; ---------------------------------------------------------
; MAIN
; ---------------------------------------------------------

while 1
	$event = GUIGetMsg()
	; select source
	$browse = _ArrayBinarySearch($ctrl, $event, Default, Default, 2); 2'nd column
	if not @error then
		$path = FileSelectFolder('NAS Záloha ' & $version & ' - Zdrojový adresář', @HomeDrive)
		if not @error then GUICtrlSetData($ctrl[$browse][1], $path)
	endif
	; select SSH key
	if $event = $gui_button_key Then
		$key_path = FileOpenDialog('NAS Záloha ' & $version & ' - Soukromý klíč', @HomeDrive, 'All (*.*)')
		if not @error then GUICtrlSetData($gui_key, $key_path)
	endif
	; update prefix
	if $event = $gui_tab Then
		if GUICtrlRead($gui_tab) = 0 Then
			for $i=0 to 9
				GUICtrlSetData($ctrl[$i][3],GUICtrlRead($gui_prefix))
			Next
		endif
	endif
	; checkbox unset
	$checkbox = _ArrayBinarySearch($ctrl, $event, Default, Default, 0); 0' column
	if not @error then
		if GUICtrlRead($ctrl[$checkbox][0]) = 4 then GUICtrlSetBkColor($ctrl[$checkbox][1], 0xffffff)
	endif
	; backup
	if $event = $gui_button_backup then
		$verify = verify_setup()
		if @error Then
			logger($verify)
			GUICtrlSetData($gui_error, $verify)
		else
			; disable button
			GUICtrlSetState($gui_button_backup, $GUI_DISABLE)
			; backup
			for $i = 0 to 9
				if GUICtrlRead($ctrl[$i][0]) = $GUI_CHECKED then
					if FileExists(GUICtrlRead($ctrl[$i][1])) then
						logger('[' & $i + 1 & '] Zálohovaní zahájeno.')
						GUICtrlSetBkColor($ctrl[$i][1], 0xffb347)
						GUICtrlSetData($gui_error, 'Probíhá záloha..')
						rsync(get_cygwin_path(GUICtrlRead($ctrl[$i][1])), StringRegExpReplace(GUICtrlRead($ctrl[$i][4]), '\\', '\/'), $ctrl[$i][1])
						logger('[' & $i + 1 & '] Zalohování dokončeno.')
					ElseIf GUICtrlRead($ctrl[$i][1]) <> '' then
						GUICtrlSetBkColor($ctrl[$i][1], 0xff6961)
						GUICtrlSetData($gui_error, 'Zdrojový adresář neexistuje.')
						logger('[' & $i + 1 & '] NAS: Zdrojový adresář neexistuje.')
					endif
				endif
			next
			; enable button
			GUICtrlSetState($gui_button_backup, $GUI_ENABLE)
		endif
	endif
	; exit
	if $event = $GUI_EVENT_CLOSE or $event = $gui_button_exit then
		; write configuration
		$f = FileOpen($ini, 2); overwrite
		for $i=0 to 9
			FileWriteLine($f, 'source' & $i + 1 & '=' & GUICtrlRead($ctrl[$i][1]))
			FileWriteLine($f, 'target' & $i + 1 & '=' & GUICtrlRead($ctrl[$i][4]))
			FileWriteLine($f, 'enable' & $i + 1 & '=' & GUICtrlRead($ctrl[$i][0]))
		next
		FileWriteLine($f, 'key=' & GUICtrlRead($gui_key))
		FileWriteLine($f, 'user=' & GUICtrlRead($gui_user))
		FileWriteLine($f, 'host=' & GUICtrlRead($gui_host))
		FileWriteLine($f, 'port=' & GUICtrlRead($gui_port))
		FileWriteLine($f, 'prefix=' & GUICtrlRead($gui_prefix))
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

func get_conf_value($conf,$item)
	$index = _ArraySearch($conf, $item)
	if not @error then return $conf[$index][1]
	return ''
endfunc

func get_cygwin_path($path)
	local $cygwin_path
	$cygwin_path = StringRegExpReplace($path , '\\', '\/'); convert backslash -> slash
	$cygwin_path = StringRegExpReplace($cygwin_path ,'^(.)\:(.*)', '\/cygdrive\/$1$2'); convert drive colon
	return StringRegExpReplace($cygwin_path ,'(.*)', '$1'); catch space by doublequote
endfunc

func verify_setup()
	if not FileExists(GUICtrlRead($gui_key)) then return SetError(1, 0, "Neplatný klíč.")
	if GUICtrlRead($gui_user) == '' then return SetError(1, 0, "Neplatný uživatel.")
	if not StringRegExp(GUICtrlRead($gui_host),'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') then return SetError(1, 0, "Neplatný host.")
	if GUICtrlRead($gui_port) < 1 or GUICtrlRead($gui_port) > 65535 then return SetError(1, 0, "Neplatné číslo portu.")
	if GUICtrlRead($gui_prefix) == '' then return SetError(1, 0, "Neplatný prefix.")
endfunc

func rsync($source,$target,$handle)
	local $buffer, $out_buffer, $err_buffer, $code, $code_index, $proc, $exit_code
	; rsync
	$rsync = Run(@ComSpec & ' /c ' & $rsync_binary & ' -avz -h -e ' & "'" _
		& get_cygwin_path($ssh_binary) _
		& ' -o "StrictHostKeyChecking no"' _
		& ' -o "UserKnownHostsFile=/dev/null"' _
		& ' -p ' & GUICtrlRead($gui_port) _
		& ' -i "' & get_cygwin_path(GUICtrlRead($gui_key)) & '"' & "' '" _
		& $source & "' '" _
		& GUICtrlRead($gui_user) & '@' & GUICtrlRead($gui_host) & ':' & GUICtrlRead($gui_prefix) & $target & "'" _
		, @ScriptDir, @SW_HIDE, BitOR($STDERR_CHILD, $STDOUT_CHILD) _
	)
	; stderr / stdout
	while ProcessExists($rsync)
		; I/O
		$out_buffer = StringReplace(StdoutRead($rsync), @LF, @CRLF)
		if $out_buffer <> '' then $buffer &= $out_buffer
		$err_buffer = StringReplace(StderrRead($rsync), @LF, @CRLF)
		if $err_buffer <> '' then $buffer &= $err_buffer
		; update progress
		if $buffer <> '' then GUICtrlSetData($gui_progress, $buffer)
		_GUICtrlEdit_Scroll($gui_progress, 4); scroll down
		Sleep(1); do not scress CPU
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
			endif
		endif
		logger('rsync: Kód ukončení ' & $exit_code[2] & '.')
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
