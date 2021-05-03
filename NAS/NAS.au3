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
#AutoIt3Wrapper_Res_ProductVersion=1.6
#AutoIt3Wrapper_Res_CompanyName=Kyouma Houin
#AutoIt3Wrapper_Res_LegalCopyright=GNU GPL v3
#AutoIt3Wrapper_Res_Language=1029
#AutoIt3Wrapper_Icon=NAS.ico
#NoTrayIcon

; ---------------------------------------------------------
; INCLUDE
; ---------------------------------------------------------

#include <File.au3>
#Include <GuiEdit.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPIProc.au3>

; ---------------------------------------------------------
; VAR
; ---------------------------------------------------------

global $version = '1.6'
global $ini = @ScriptDir & '\NAS.ini'
global $logfile = @ScriptDir & '\' & 'NAS.log'
global $rsync_binary = @ScriptDir & '\bin\rsync.exe'
global $ssh_binary = @ScriptDir & '\bin\ssh.exe'

global $conf[0][2]; INI configuration
global $ctrl[10][5]; GUI handle map

global $rsync; Rsync PID
global $option; Rsync option
global $buffer; Rsync global I/O buffer
global $buffer_out; Rsync STDOUT
global $buffer_err; Rsync STDERR

global $backup=False
global $test=False
global $terminate=False
global $run=False

global $failed = 4
global $paused = 3
global $done = 1
global $new = 0

global $white = 0xffffff
global $green = 0x77dd77
global $orange = 0xffb347
global $red = 0xff6961

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
; CONTROL
; ---------------------------------------------------------

; one instance
if UBound(ProcessList(@ScriptName)) > 2 then
	MsgBox(48, 'NAS Záloha ' & $version, 'Program byl již spuštěn.')
	exit
endif

; logging
$log = FileOpen($logfile, 1); overwrite
if @error then
	MsgBox(48, 'NAS Záloha ' & $version, 'Systém je připojen pouze pro čtení.')
	exit
endif

; ---------------------------------------------------------
; INIT
; ---------------------------------------------------------

logger('Start programu: ' & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)

; default INI
if not FileExists($ini) then
	$f = FileOpen($ini, 1)
	for $i=1 to 10
		FileWriteLine($f, 'source' & $i & '=')
		FileWriteLine($f, 'target' & $i & '=')
		FileWriteLine($f, 'enable' & $i & '=' & '4'); default 4
		FileWriteLine($f, 'state' & $i & '=' & '0'); default 0
	next
	FileWriteLine($f, 'key=')
	FileWriteLine($f, 'user=')
	FileWriteLine($f, 'host=')
	FileWriteLine($f, 'port=')
	FileWriteLine($f, 'prefix=')
	FileWriteLine($f, 'restore=' & '0'); default 0
	FileClose($f)
endif

; read configuration
_FileReadToArray($ini, $conf, 0, '='); 0-based
if @error then
	MsgBox(0, 'NAS Záloha ' & $version, 'Načtení konfiguračního INI souboru selhalo.')
	exit
else
	logger('Konfigurační INI soubor byl načten.')
endif

; ---------------------------------------------------------
; GUI
; ---------------------------------------------------------

$gui = GUICreate('NAS Záloha ' & $version, 632, 340, Default, Default)
$gui_tab = GUICtrlCreateTab(5, 5, 621, 302)

$gui_tab_dir = GUICtrlCreateTabItem('Adresář')
$gui_group_source = GUICtrlCreateGroup('Zdroj', 12, 28, 379, 270)
$gui_group_target = GUICtrlCreateGroup('Cíl', 394, 28, 224, 270)

for $i = 0 to 9
	$ctrl[$i][0] = GUICtrlCreateCheckbox('', 20, 43 + $i * 25, 16, 21)
	GUICtrlSetState($ctrl[$i][0], $conf[$i*4+2][1])
	$ctrl[$i][1] = GUICtrlCreateInput($conf[$i*4][1], 40, 44 + $i * 25, 264, 21); source
	$ctrl[$i][2] = GUICtrlCreateButton('Procházet', 308, 44 + $i * 25, 75, 21)
	$ctrl[$i][3] = GUICtrlCreateLabel(conf_get_value('prefix'), 400, 48 + $i * 25, 90, 21, 0x01); $SS_CENTER
	$ctrl[$i][4] = GUICtrlCreateInput($conf[$i*4+1][1], 496, 44 + $i * 25, 113, 21); target
next

$gui_tab_progress = GUICtrlCreateTabItem('Výstup')
$gui_progress = GUICtrlCreateEdit('', 15, 35, 600, 262, BitOR($ES_AUTOVSCROLL, $ES_READONLY, $ES_WANTRETURN, $WS_VSCROLL))

$gui_tab_setup = GUICtrlCreateTabItem('Nastavení')
$gui_group_connection = GUICtrlCreateGroup('Připojení', 12, 28, 605, 94)
$gui_host_label = GUICtrlCreateLabel('Adresa IP:', 20 ,48 , 60, 21)
$gui_host = GUICtrlCreateInput(conf_get_value('host'), 240, 44, 90, 21)
$gui_port_label = GUICtrlCreateLabel('Port:', 20 ,72 , 25, 21)
$gui_port = GUICtrlCreateInput(conf_get_value('port'), 290, 68, 40, 21)
$gui_user_label = GUICtrlCreateLabel('Uživatel:', 20 , 96, 40, 21)
$gui_user = GUICtrlCreateInput(conf_get_value('user'), 240, 92, 90, 21)
$gui_group_key = GUICtrlCreateGroup('SSH', 12, 122, 605, 46)
$gui_prefix_label = GUICtrlCreateLabel('Klíč:', 20 ,142, 90, 21)
$gui_key = GUICtrlCreateInput(conf_get_value('key'), 48, 138, 282, 21)
$gui_button_key = GUICtrlCreateButton('Procházet', 334, 138, 75, 21)
$gui_group_nas = GUICtrlCreateGroup('NAS', 12, 168, 605, 46)
$gui_prefix_label = GUICtrlCreateLabel('Prefix:', 20 ,188, 30, 21)
$gui_prefix = GUICtrlCreateInput(conf_get_value('prefix'), 220, 184, 110, 21)
$gui_group_fill = GUICtrlCreateGroup('', 12, 214, 605, 84)

$gui_tab_end = GUICtrlCreateTabItem('')

$gui_error = GUICtrlCreateLabel('', 10, 318, 298, 21)
$gui_button_backup = GUICtrlCreateButton('Zálohovat', 316, 314, 75, 21)
$gui_button_test = GUICtrlCreateButton('Test', 394, 314, 75, 21)
$gui_button_break = GUICtrlCreateButton('Přerušit', 472, 314, 75, 21)
$gui_button_exit = GUICtrlCreateButton('Konec', 550, 314, 75, 21)

; update colors on restore
if conf_get_value('restore') > 0 then
	; update button
	GuiCtrlSetData($gui_button_break, 'Pokračovat')
	; update colors
	for $i = 0 to 9
		if GUICtrlRead($ctrl[$i][0]) = $GUI_CHECKED and $conf[$i*4][1] <> '' and $conf[$i*4+3][1] = $done then
			GUICtrlSetBkColor($ctrl[$i][1], $green)
		endif
		if GUICtrlRead($ctrl[$i][0]) = $GUI_CHECKED and $conf[$i*4][1] <> '' and $conf[$i*4+3][1] = $paused then
			GUICtrlSetBkColor($ctrl[$i][1], $orange)
		endif
		if GUICtrlRead($ctrl[$i][0]) = $GUI_CHECKED and $conf[$i*4][1] <> '' and $conf[$i*4+3][1] = $failed then
			GUICtrlSetBkColor($ctrl[$i][1], $red)
		endif
	next
endif

; set default focus
GUICtrlSetState($gui_button_exit, $GUI_FOCUS)

;show
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
				GUICtrlSetData($ctrl[$i][3], GUICtrlRead($gui_prefix))
			Next
		endif
	endif
	; unset color on unchecked
	$checkbox = _ArrayBinarySearch($ctrl, $event, Default, Default, 0); 0' column
	if not @error then
		if GUICtrlRead($ctrl[$checkbox][0]) = $GUI_UNCHECKED then GUICtrlSetBkColor($ctrl[$checkbox][1], $white)
	endif
	; backup
	if $event = $gui_button_backup then
		$verify = verify_setup()
		if @error Then
			logger($verify)
			GUICtrlSetData($gui_error, $verify)
		else
			; set token
			$backup=True
			; option
			$option=''
			; clear buffer
			$buffer = ''
			; reset restore
			conf_set_value('restore', 0)
			GUICtrlSetData($gui_button_break, 'Přerušit')
			; reset state and color
			for $i = 0 to 9
				$conf[$i*4+3][1] = $new
				GUICtrlSetBkColor($ctrl[$i][1], $white)
			next
			; disable buttons
			GUICtrlSetState($gui_button_backup, $GUI_DISABLE)
			GUICtrlSetState($gui_button_test, $GUI_DISABLE)
			for $i = 0 to 9
				GUICtrlSetState($ctrl[$i][0], $GUI_DISABLE)
			next
		endif
	endif
	; test
	if $event = $gui_button_test Then
		$verify = verify_setup()
		if @error Then
			logger($verify)
			GUICtrlSetData($gui_error, $verify)
		else
			; set token
			$test=True
			; option
			$option='-n'
			; clear buffer
			$buffer = ''
			; reset restore
			conf_set_value('restore', 0)
			GUICtrlSetData($gui_button_break, 'Přerušit')
			; reset state and color
			for $i = 0 to 9
				$conf[$i*4+3][1] = $new
				GUICtrlSetBkColor($ctrl[$i][1], $white)
			next
			; disable buttons
			GUICtrlSetState($gui_button_backup, $GUI_DISABLE)
			GUICtrlSetState($gui_button_test, $GUI_DISABLE)
			for $i = 0 to 9
				GUICtrlSetState($ctrl[$i][0], $GUI_DISABLE)
			next
		endif
	endif
	; terminate / resume
	if $event = $gui_button_break then
		; terminate
		if $run then
			ProcessClose($rsync)
			if @error then
				logger("ERROR: ProcessClose")
			else
				; set token
				$terminate=True
				;set restore
				if $backup then conf_set_value('restore', 1)
				if $test then conf_set_value('restore', 2)
				;update button
				GuiCtrlSetData($gui_button_break, 'Pokračovat')
			endif
		endif
		; resume
		if not $run and conf_get_value('restore') > 0 then
			$verify = verify_setup()
			if @error Then
				logger($verify)
				GUICtrlSetData($gui_error, $verify)
			else
				; restore backup
				if conf_get_value('restore') = 1 then
					$option=''
					$backup=True
				endif
				; restore test
				if conf_get_value('restore') = 2 then
					$option='-n'
					$test=True
				endif
				; clear buffer
				$buffer = ''
				; reset restore
				conf_set_value('restore', 0)
				; update button
				GUICtrlSetData($gui_button_break, 'Přerušit')
				; disable buttons
				GUICtrlSetState($gui_button_backup, $GUI_DISABLE)
				GUICtrlSetState($gui_button_test, $GUI_DISABLE)
				for $i = 0 to 9
					GUICtrlSetState($ctrl[$i][0], $GUI_DISABLE)
				next
			endif
		endif
	endif
	; main
	if $backup or $test then
		; logging
		if $run and get_free() > -1 and not ProcessExists($rsync) then
			; free
			$index = get_free()
			; update I/O
			$buffer_out = StringReplace(StderrRead($rsync), @LF, @CRLF)
			$buffer_err = StringReplace(StdoutRead($rsync), @LF, @CRLF)
			$buffer &= $buffer_out
			$buffer &= $buffer_err
			if not $terminate then $buffer &= @CRLF
			; update output
			GUICtrlSetData($gui_progress, BinaryToString(StringToBinary($buffer), $SB_UTF8))
			; exit code
			$proc = _WinAPI_OpenProcess($PROCESS_QUERY_LIMITED_INFORMATION, 0, $rsync)
			if @error then logger('ERROR: WinAPI OpenProcess (limited)')
			$exit_code = DllCall("kernel32.dll", "bool", "GetExitCodeProcess", "HANDLE", $proc, "dword*", -1)
			if not @error then
				if $exit_code[2] = 0 then
					if not $terminate then GUICtrlSetBkColor($ctrl[$index][1], $green)
					GUICtrlSetData($gui_error, 'Dokončeno.')
				else
					$code_index = _ArrayBinarySearch($error_code, $exit_code[2])
					if not @error then
						GUICtrlSetData($gui_error, $error_code[$code_index][1])
						GUICtrlSetBkColor($ctrl[$index][1], $red)
					else
						logger("ERROR: Unknown code " & $exit_code[2])
					endif
				endif
				logger('rsync: Kód ukončení ' & $exit_code[2] & '.')
			else
				logger('ERROR: GetExitCodeProcess')
			endif
			_WinAPI_CloseHandle($proc)
			; error code
			if $buffer_err <> '' then
				$code = StringRegExp($buffer_err, '\(code (\d+)\)', $STR_REGEXPARRAYMATCH)
				if not @error then logger('rsync: Kód chyby ' & $code[0] & '.')
			endif
			; log I/O
			if $buffer_out <> '' then logger(BinaryToString(StringToBinary($buffer_out), $SB_UTF8))
			if $buffer_err <> '' then logger(BinaryToString(StringToBinary($buffer_err), $SB_UTF8))
			; round
			logger('[' & $index + 1 & '] Zalohování dokončeno.')
			; update state
			if $terminate then
				$conf[$index*4+3][1] = $paused
			elseif $exit_code[2] = 0 then
				$conf[$index*4+3][1] = $done
			else
				$conf[$index*4+3][1] = $failed
			endif
			; reset token
			$run = False
		endif
		; run
		if not $run and get_free() > -1 and not $terminate then
			; free
			$index = get_free()
			; source
			if FileExists(GUICtrlRead($ctrl[$index][1])) then
				logger('[' & $index + 1 & '] Zálohovaní zahájeno.')
				; update color
				GUICtrlSetBkColor($ctrl[$index][1], $orange)
				; update output
				if $backup then GUICtrlSetData($gui_error, 'Probíhá záloha..')
				if $test then GUICtrlSetData($gui_error, 'Probíhá test..')
				; rsync
				$rsync = Run('"' & $rsync_binary & '" -avz -h '& $option & ' -e ' & "'" _
					& '"' & get_cygwin_path($ssh_binary) & '"'  _
					& ' -o "StrictHostKeyChecking no"' _
					& ' -o "UserKnownHostsFile=/dev/null"' _
					& ' -p ' & GUICtrlRead($gui_port) _
					& ' -i "' & get_cygwin_path(GUICtrlRead($gui_key)) & '"' & "' " & '"' _
					& get_cygwin_path(GUICtrlRead($ctrl[$index][1])) & '" ' _
					& GUICtrlRead($gui_user) & '@' & GUICtrlRead($gui_host) & ':' & '"' _
					& GUICtrlRead($gui_prefix) & StringRegExpReplace(GUICtrlRead($ctrl[$index][4]), '\\', '\/') & '"' _
					, @ScriptDir, @SW_HIDE, BitOR($STDERR_CHILD, $STDOUT_CHILD) _
				)
				; update token
				$run = True
			elseif GUICtrlRead($ctrl[$index][1]) <> '' then
				; update state
				$conf[$index*4+3][1] = $failed
				; update color
				GUICtrlSetBkColor($ctrl[$index][1], $red)
				; update output
				GUICtrlSetData($gui_error, 'Zdrojový adresář neexistuje.')
				logger('[' & $index + 1 & '] NAS: Zdrojový adresář neexistuje.')
			endif
		endif
		; end
		if ( not $run and get_free() < 0 ) or $terminate Then
			; enable buttons
			GUICtrlSetState($gui_button_backup, $GUI_ENABLE)
			GUICtrlSetState($gui_button_test, $GUI_ENABLE)
			for $i = 0 to 9
				GUICtrlSetState($ctrl[$i][0], $GUI_ENABLE)
			next
			; reset tokens
			$backup=False
			$test=False
			$terminate=False
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
			FileWriteLine($f, 'state' & $i + 1 & '=' & $conf[$i*4 + 3][1])
		next
		FileWriteLine($f, 'key=' & GUICtrlRead($gui_key))
		FileWriteLine($f, 'user=' & GUICtrlRead($gui_user))
		FileWriteLine($f, 'host=' & GUICtrlRead($gui_host))
		FileWriteLine($f, 'port=' & GUICtrlRead($gui_port))
		FileWriteLine($f, 'prefix=' & GUICtrlRead($gui_prefix))
		FileWriteLine($f, 'restore=' & conf_get_value('restore'))
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

func conf_set_value($val, $data)
	$index = _ArraySearch($conf, $val)
	if not @error then $conf[$index][1] = $data
	return
endfunc

func conf_get_value($val)
	$index = _ArraySearch($conf, $val)
	if not @error then return $conf[$index][1]
	return ''
endfunc

func get_cygwin_path($path)
	local $cygwin_path
	$cygwin_path = StringRegExpReplace($path , '\\', '\/'); convert backslash -> slash
	$cygwin_path = StringRegExpReplace($cygwin_path, '^(.)\:(.*)', '\/cygdrive\/$1$2'); convert drive colon
	return $cygwin_path; catch space by doublequote
endfunc

func verify_setup()
	; invalid key file
	if not FileExists(GUICtrlRead($gui_key)) then return SetError(1, 0, "Neplatný klíč.")
	; empty user
	if GUICtrlRead($gui_user) == '' then return SetError(1, 0, "Neplatný uživatel.")
	; invalid IP address
	if not StringRegExp(GUICtrlRead($gui_host), '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') then return SetError(1, 0, "Neplatný host.")
	; invalid port number
	if GUICtrlRead($gui_port) < 1 or GUICtrlRead($gui_port) > 65535 then return SetError(1, 0, "Neplatné číslo portu.")
	; empty prefix
	if GUICtrlRead($gui_prefix) == '' then return SetError(1, 0, "Neplatný prefix.")
endfunc

func get_free()
	for $i = 0 to 9
		if GUICtrlRead($ctrl[$i][0]) = $GUI_CHECKED then
			if $conf[$i*4+3][1] = $new or $conf[$i*4+3][1] = $paused then
				return $i
			endif
		endif
	next
	return -1
endfunc
