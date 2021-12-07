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
#AutoIt3Wrapper_Res_ProductVersion=2.0
#AutoIt3Wrapper_Res_CompanyName=Kyouma Houin
#AutoIt3Wrapper_Res_LegalCopyright=GNU GPL v3
#AutoIt3Wrapper_Res_Language=1029
#AutoIt3Wrapper_Icon=NAS.ico
#NoTrayIcon

; ---------------------------------------------------------
; INCLUDE
; ---------------------------------------------------------

#include <File.au3>
#include <Date.au3>
#Include <GuiEdit.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPIProc.au3>
#include <CryptoNG.au3>

; ---------------------------------------------------------
; VAR
; ---------------------------------------------------------

global $version = '2.0'
global $ini = @ScriptDir & '\NAS.ini'
global $logfile = @ScriptDir & '\NAS.log'
global $rsync_binary = @ScriptDir & '\bin\rsync.exe'
global $ssh_binary = @ScriptDir & '\bin\ssh.exe'

global $INVALID_HANDLE_VALUE = ptr(0xffffffff)

global $login = '0x3BD1B351E7E2488CBA0DED73A0D1AD1D60509F6B1C9EBC6C4032C03BD5A42B4CAA134BB7039EBA70AE5D16B89F3AF055FA31339BB85F0BE97973AFB75B310F0B'

global $admin = False
global $debug = False

global $remote[8][5]; checkbox | source | button | prefix | target
global $local[10][5]; checkbox | source | button | target | button
global $network[2][11]; label | host | label | port | label | user | label | key | button | label | prefix

global $rsync; Rsync PID
global $option; Rsync option
global $buffer; Rsync combined buffer
global $buffer_out; Rsync STDOUT
global $buffer_err; Rsync STDERR

global $backup = False; restore state = 1
global $test = False; restore state = 2
global $restore = False; restore state = 3
global $restore_test = False; restore state = 4
global $terminate = False
global $error = False
global $run = False

global $transfer_start

global $failed = 4
global $paused = 3
global $done = 1
global $new = 0

global $white = 0xffffff
global $green = 0x77dd77
global $orange = 0xffb347
global $red = 0xff6961

global $error_code[26][2]=[ _
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
	[255,'Neočekávaná chyba.'], _
	[259,'Stále aktivní.']]

; Default INI
global $ini_template='{' _
	& '"global":{"restore":"","local_restore":"","debug":"0"},' _
	& '"site-A":{"key":"","user":"","host":"","port":"","prefix":""},' _
	& '"site-B":{"key":"","user":"","host":"","port":"","prefix":""},' _
	& '"restore":{"source":"","target":"","enable":4,"state":0},' _
	& '"local_restore":{"source":"","target":"","enable":4,"state":0},' _
	& '"local":{' _
		& '"0":{"source":"","target":"","enable":4,"state":0,"stat":""},' _
		& '"1":{"source":"","target":"","enable":4,"state":0,"stat":""},' _
		& '"2":{"source":"","target":"","enable":4,"state":0,"stat":""},' _
		& '"3":{"source":"","target":"","enable":4,"state":0,"stat":""},' _
		& '"4":{"source":"","target":"","enable":4,"state":0,"stat":""},' _
	& '},' _
	& '"remote":{' _
		& '"0":{"source":"","target":"","enable":4,"state":0,"stat":""},' _
		& '"1":{"source":"","target":"","enable":4,"state":0,"stat":""},' _
		& '"2":{"source":"","target":"","enable":4,"state":0,"stat":""},' _
		& '"3":{"source":"","target":"","enable":4,"state":0,"stat":""},' _
		& '"4":{"source":"","target":"","enable":4,"state":0,"stat":""},' _
	& '}' _
& '}'

; conf
;$conf = Json_Decode($ini_template)

; ---------------------------------------------------------
; CONTROL
; ---------------------------------------------------------

; one instance
if UBound(ProcessList(@ScriptName)) > 2 then
	MsgBox(48, 'NAS ' & $version, 'Program byl již spuštěn.')
	exit
endif

; logging
$log = FileOpen($logfile, 1); overwrite
if @error then
	MsgBox(48, 'NAS ' & $version, 'Systém je připojen pouze pro čtení.')
	exit
endif

; ---------------------------------------------------------
; INIT
; ---------------------------------------------------------

logger('Start programu: ' & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)

; write default ini
if not FileExists($ini) then
	$f = FileOpen($ini, 2 + 256); UTF8 no BOM overwrite
	FileWrite($f, Json_Encode($conf))
	FileClose($f)
endif

; read configuration
$conf = Json_Decode(FileRead($ini))
if @error then
	MsgBox(0, 'NAS ' & $version, 'Načtení konfiguračního INI souboru selhalo.')
	exit
else
	logger('Konfigurační INI soubor byl načten.')
endif

; ---------------------------------------------------------
; GUI
; ---------------------------------------------------------

$gui = GUICreate('NAS ' & $version, 632, 340, Default, Default)
$gui_tab = GUICtrlCreateTab(5, 5, 621, 302)

$gui_tab_remote = GUICtrlCreateTabItem('Vzdálená')
$gui_group_remote_nas1 = GUICtrlCreateGroup('Lokalita A', 12, 28, 606, 135)
$gui_group_remote_nas2 = GUICtrlCreateGroup('Lokalita B', 12, 163, 606, 135)
for $i = 0 to 3
	$remote[$i][0] = GUICtrlCreateCheckbox('', 20, 48 + $i*26, 16, 21)
	$remote[$i][1] = GUICtrlCreateInput('', 40, 49 + $i*26, 189, 21)
	$remote[$i][2] = GUICtrlCreateButton('Procházet', 233, 49 + $i*26, 75, 21)
	$remote[$i][3] = GUICtrlCreateLabel('xxxxxxxxxxxxxxxxxxxxxxxxx', 325, 52 + $i*26, 90, 21, 0x01); $SS_CENTER
	$remote[$i][4] = GUICtrlCreateInput('', 421, 49 + $i*26, 188, 21)
	$remote[$i+4][0] = GUICtrlCreateCheckbox('', 20, 185 + $i*26, 16, 21)
	$remote[$i+4][1] = GUICtrlCreateInput('', 40, 185 + $i*26, 189, 21)
	$remote[$i+4][2] = GUICtrlCreateButton('Procházet', 233, 185 + $i*26, 75, 21)
	$remote[$i+4][3] = GUICtrlCreateLabel('xxxxxxxxxxxxxxxxxxxxxxxxx', 325, 188 + $i*26, 90, 21, 0x01); $SS_CENTER
	$remote[$i+4][4] = GUICtrlCreateInput('', 421, 185 + $i*26, 188, 21)
next

$gui_tab_local = GUICtrlCreateTabItem('Lokální')
$gui_group_local_source = GUICtrlCreateGroup('Zdroj', 12, 28, 312, 270)
$gui_group_local_target = GUICtrlCreateGroup('Cíl', 327, 28, 291, 270)
for $i = 0 to 9
	$local[$i][0] = GUICtrlCreateCheckbox('', 20, 43 + $i*25, 16, 21)
	$local[$i][1] = GUICtrlCreateInput('', 40, 44 + $i*25, 196, 21)
	$local[$i][2] = GUICtrlCreateButton('Procházet', 241, 44 + $i*25, 75, 21)
	$local[$i][3] = GUICtrlCreateInput('', 335, 44 + $i*25, 195, 21)
	$local[$i][4] = GUICtrlCreateButton('Procházet', 535, 44 + $i*25, 75, 21)
next

$gui_tab_output = GUICtrlCreateTabItem('Výstup')
$gui_output = GUICtrlCreateEdit('', 15, 35, 600, 262, BitOR($ES_AUTOVSCROLL, $ES_READONLY, $ES_WANTRETURN, $WS_VSCROLL))

$gui_tab_connection = GUICtrlCreateTabItem('Připojení')
$gui_group_connection_nas1 = GUICtrlCreateGroup('Lokalita A', 12, 28, 606, 135)
$gui_group_connection_nas2 = GUICtrlCreateGroup('Lokalita B', 12, 163, 606, 135)
for $i = 0 to 1
	$network[$i][0] = GUICtrlCreateLabel('Host:', 20 ,46 + $i*135, 60, 21)
	$network[$i][1] = GUICtrlCreateInput('', 240, 40 + $i*135, 90, 21)
	$network[$i][2] = GUICtrlCreateLabel('Port:',20 , 68 + $i*135, 25, 21)
	$network[$i][3] = GUICtrlCreateInput('', 290, 64 + $i*135, 40, 21)
	$network[$i][4] = GUICtrlCreateLabel('Uživatel:',20 , 92 + $i*135, 40, 21)
	$network[$i][5] = GUICtrlCreateInput('', 240, 88 + $i*135, 90, 21)
	$network[$i][6] = GUICtrlCreateLabel('SSH klíč:', 20, 116 + $i*135, 90, 21)
	$network[$i][7] = GUICtrlCreateInput('', 68, 112 + $i*135, 262, 21)
	$network[$i][8] = GUICtrlCreateButton('Procházet', 334, 112 + $i*135, 75, 21)
	$network[$i][9] = GUICtrlCreateLabel('NAS prefix:', 20, 140 + $i*135, 60, 21)
	$network[$i][10] = GUICtrlCreateInput('', 220, 136 + $i*135, 110, 21)
next

$gui_tab_setup = GUICtrlCreateTabItem('Nastavení')
$gui_group_setup = GUICtrlCreateGroup('', 12, 28, 606, 66)
$gui_group_setup_blank = GUICtrlCreateGroup('', 12, 94, 606, 204)
$gui_setup_debug_label = GUICtrlCreateLabel('Režim ladění:', 20, 46, 80, 21)
$gui_setup_debug_check = GUICtrlCreateCheckbox('', 240, 40, 16, 21)
$gui_setup_pwd_label = GUICtrlCreateLabel('Režim správce:', 20, 68, 150, 21)
$gui_setup_pwd = GUICtrlCreateInput('', 240, 64, 90, 21, BitOR(0x0020,0x0001)); ES_PASSWORD
$gui_setup_button_pwd = GUICtrlCreateButton('Povolit', 334, 64, 75, 21)

$gui_tab_end = GUICtrlCreateTabItem('')
$gui_error = GUICtrlCreateLabel('', 10, 318, 298, 21)
$gui_button_run = GUICtrlCreateButton('Spustit', 394, 314, 75, 21)
$gui_button_break = GUICtrlCreateButton('Přerušit', 472, 314, 75, 21)
$gui_button_exit = GUICtrlCreateButton('Storno', 550, 314, 75, 21)

; update debug
;if Json_ObjGet($conf, '.setup.debug') = 1 then GUICtrlSetState($gui_debug_check, $GUI_CHECKED)
; update button
;if Json_ObjGet($conf, '.setup.restore') > 0 then GuiCtrlSetData($gui_button_break, 'Pokračovat')
; update colors
;if Json_ObjGet($conf, '.setup.restore') > 0 and Json_ObjGet($conf, '.setup.restore') < 3 then; backup
;	for $i = 0 to 9
;		if Json_ObjGet($conf, '.backup.' & $i & '.enable') = $GUI_CHECKED Then
;			if Json_ObjGet($conf, '.backup.' & $i & '.source') <> '' Then
;				if Json_ObjGet($conf, '.backup.' & $i & '.state') = $done then GUICtrlSetBkColor($remote[$i][1], $green)
;				if Json_ObjGet($conf, '.backup.' & $i & '.state') = $paused then GUICtrlSetBkColor($remote[$i][1], $orange)
;				if Json_ObjGet($conf, '.backup.' & $i & '.state') = $failed then GUICtrlSetBkColor($remote[$i][1], $red)
;			endif
;		endif
;	next
;endif

;if Json_ObjGet($conf, '.setup.restore') > 2 then; restore
;	if Json_ObjGet($conf, '.restore.enable') = $GUI_CHECKED then
;		if Json_ObjGet($conf, '.restore.target') <> '' then
;			if Json_ObjGet($conf, '.restore.state') = $done then GUICtrlSetBkColor($gui_restore_target, $green)
;			if Json_ObjGet($conf, '.restore.state') = $paused then GUICtrlSetBkColor($gui_restore_target, $orange)
;			if Json_ObjGet($conf, '.restore.state') = $failed then GUICtrlSetBkColor($gui_restore_target, $red)
;		endif
;	endif
;endif

; set default mode
;admin_mode($admin)

; set default focus
GUICtrlSetState($gui_button_exit, $GUI_FOCUS)

;show
GUISetState(@SW_SHOW)

; ---------------------------------------------------------
; MAIN
; ---------------------------------------------------------

while 1
	$event = GUIGetMsg()
	; admin mode
	if $event = $gui_button_pwd Then
		if _CryptoNG_HashData($CNG_BCRYPT_SHA512_ALGORITHM , GUICtrlRead($gui_pwd)) = Binary($login) then
			if $admin = False Then
				$admin = True
				GUICtrlSetData($gui_button_pwd,'Zakázat')
			else
				$admin = False
				GUICtrlSetData($gui_button_pwd,'Povolit')
			endif
			admin_mode($admin)
			GUICtrlSetData($gui_pwd, '')
		endif
	endif
	; enable debugging
	if GUICtrlRead($gui_debug_check) = $GUI_CHECKED then
		$debug = True
		Json_Put($conf, '.setup.debug', 1)
	else
		$debug = False
		Json_Put($conf, '.setup.debug', 0)
	endif
	; select source
	$browse = _ArrayBinarySearch($remote, $event, Default, Default, 2); 2'nd column
	if not @error then
		$path = FileSelectFolder('NAS ' & $version & ' - Zdrojový adresář', @HomeDrive)
		if not @error then GUICtrlSetData($remote[$browse][1], $path)
	endif
	; select restore target
	if $event = $gui_button_restore_target then
		$path = FileSelectFolder('NAS ' & $version & ' - Cílový adresář', @HomeDrive)
		if not @error then GUICtrlSetData($gui_restore_target, $path)
	endif
	; select SSH key
	if $event = $gui_button_key Then
		$key_path = FileOpenDialog('NAS ' & $version & ' - Soukromý klíč', @HomeDrive, 'All (*.*)')
		if not @error then GUICtrlSetData($gui_key, $key_path)
	endif
	; update prefix
	if $event = $gui_tab Then
		if GUICtrlRead($gui_tab) = 0 Then; 1st tab
			for $i=0 to 9
				GUICtrlSetData($remote[$i][3], GUICtrlRead($gui_prefix))
			Next
		endif
		if GUICtrlRead($gui_tab) = 3 Then; 4th tab
			GUICtrlSetData($gui_restore_source_label, GUICtrlRead($gui_prefix))
		endif
	endif
	; unset color on unchecked
	$checkbox = _ArrayBinarySearch($remote, $event, Default, Default, 0); 0' column
	if not @error then
		if GUICtrlRead($remote[$checkbox][0]) = $GUI_UNCHECKED then GUICtrlSetBkColor($remote[$checkbox][1], $white)
	endif
	if $event = $gui_restore_box then
		if GUICtrlRead($gui_restore_box) = $GUI_UNCHECKED then GUICtrlSetBkColor($gui_restore_target, $white)
	endif
	; backup & restore
	if $event = $gui_button_run then
		$verify = verify_setup()
		if @error Then
			logger('CHYBA: ' & $verify)
			GUICtrlSetData($gui_error, $verify)
		else
			; option
			$option=''
			; clear output
			GUICtrlSetData($gui_progress, '')
			; reset restore
			Json_Put($conf, '.setup.restore', 0)
			GUICtrlSetData($gui_button_break, 'Přerušit')
			; setup
			if GuiCtrlRead($gui_restore_box) = $GUI_CHECKED then
				; set token
				$restore=True
				; reset state and color
				Json_Put($conf, '.restore.state', $new)
				GUICtrlSetBkColor($gui_restore_target, $white)
			else
				; set token
				$backup=True
				; reset state and color
				for $i = 0 to 9
					Json_Put($conf, '.backup.' & $i & '.state', $new)
					GUICtrlSetBkColor($remote[$i][1], $white)
				next
			endif
			; disable buttons
			GUICtrlSetState($gui_button_run, $GUI_DISABLE)
			GUICtrlSetState($gui_button_test, $GUI_DISABLE)
			for $i = 0 to 9
				GUICtrlSetState($remote[$i][0], $GUI_DISABLE)
			next
			GUICtrlSetState($gui_restore_box, $GUI_DISABLE)
		endif
	endif
	; backup test & restore test
	if $event = $gui_button_test Then
		$verify = verify_setup()
		if @error Then
			logger('CHYBA: ' & $verify)
			GUICtrlSetData($gui_error, $verify)
		else
			; option
			$option='-n'
			; clear output
			GUICtrlSetData($gui_progress, '')
			; reset restore
			Json_Put($conf, '.setup.restore', 0)
			GUICtrlSetData($gui_button_break, 'Přerušit')
			; setup
			if GuiCtrlRead($gui_restore_box) = $GUI_CHECKED then
				; set token
				$restore_test=True
				; reset state and color
				Json_Put($conf, '.restore.state', $new)
				GUICtrlSetBkColor($gui_restore_target, $white)
			else
				; set token
				$test=True
				; reset state and color
				for $i = 0 to 9
					Json_Put($conf, '.backup.' & $i & '.state', $new)
					GUICtrlSetBkColor($remote[$i][1], $white)
				next
			endif
			; disable buttons
			GUICtrlSetState($gui_button_run, $GUI_DISABLE)
			GUICtrlSetState($gui_button_test, $GUI_DISABLE)
			for $i = 0 to 9
				GUICtrlSetState($remote[$i][0], $GUI_DISABLE)
			next
			GUICtrlSetState($gui_restore_box, $GUI_DISABLE)
		endif
	endif
	; terminate / resume
	if $event = $gui_button_break then
		; terminate
		if $run then
			ProcessClose($rsync)
			if @error then
				logger('CHYBA: ProcessClose')
			else
				logger('rsync: Probíhá ukončení.')
				ProcessWaitClose($rsync)
				; set token
				$terminate=True
				;set restore
				if $backup then Json_Put($conf, '.setup.restore', 1)
				if $test then Json_Put($conf, '.setup.restore', 2)
				if $restore then Json_Put($conf, '.setup.restore', 3)
				if $restore_test then Json_Put($conf, '.setup.restore', 4)
				;update button
				GuiCtrlSetData($gui_button_break, 'Pokračovat')
			endif
		endif
		; resume
		if not $run and Json_ObjGet($conf, '.setup.restore') > 0 then
			$verify = verify_setup()
			if @error Then
				logger('CHYBA: ' & $verify)
				GUICtrlSetData($gui_error, $verify)
			else
				; restore backup
				if Json_ObjGet($conf, '.setup.restore') = 1 then
					$option=''
					$backup=True
				endif
				; restore test
				if Json_ObjGet($conf, '.setup.restore') = 2 then
					$option='-n'
					$test=True
				endif
				; restore restore
				if Json_ObjGet($conf, '.setup.restore') = 3 then
					$option=''
					$restore=True
				endif
				; restore restore test
				if Json_ObjGet($conf, '.setup.restore') = 4 then
					$option='-n'
					$restore_test=True
				endif
				; clear output
				GUICtrlSetData($gui_progress, '')
				; reset restore
				Json_Put($conf, '.setup.restore', 0)
				; update button
				GUICtrlSetData($gui_button_break, 'Přerušit')
				; disable buttons
				GUICtrlSetState($gui_button_run, $GUI_DISABLE)
				GUICtrlSetState($gui_button_test, $GUI_DISABLE)
				for $i = 0 to 9
					GUICtrlSetState($remote[$i][0], $GUI_DISABLE)
				next
				GUICtrlSetState($gui_restore_box, $GUI_DISABLE)
			endif
		endif
	endif
	; restore & restore test
	if $restore or $restore_test then
		; logging
		if $run and get_free_restore() and not ProcessExists($rsync) then
			; update I/O
			$buffer_out = StringReplace(StderrRead($rsync), @LF, @CRLF)
			$buffer_err = StringReplace(StdoutRead($rsync), @LF, @CRLF)
			$buffer &= $buffer_out
			$buffer &= $buffer_err
			; update output
			GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & BinaryToString(StringToBinary($buffer), $SB_UTF8))
			; exit code
			$proc = _WinAPI_OpenProcess($PROCESS_QUERY_LIMITED_INFORMATION, 0, $rsync, True)
			if @error or $proc = $INVALID_HANDLE_VALUE then
				if $debug then logger('CHYBA: WinAPI OpenProcess (query limited info)')
				; error code
				if $buffer_out <> '' or $buffer_err <> '' then
					$code = StringRegExp($buffer_out & $buffer_err, '\(code (\d+)\)', $STR_REGEXPARRAYMATCH)
					if not @error then
						; update errror
						$error = True
						; update output
						$code_index = _ArrayBinarySearch($error_code, $code[0])
						if @error then
							if $debug then logger('CHYBA: Neznámý chybový kód ' & $code[0])
							GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & @CRLF & 'CHYBA: Neznámý chybový kód' & $code[0] & '.' & @CRLF)
							GUICtrlSetData($gui_error, 'Neznámá chyba.')
 						else
							logger('CHYBA: ' & $error_code[$code_index][1])
							GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & @CRLF & 'CHYBA: ' & $error_code[$code_index][1] & @CRLF)
							GUICtrlSetData($gui_error, $error_code[$code_index][1])
						endif
						; update color
						GUICtrlSetBkColor($gui_restore_target, $red)
					else
						if $debug then logger('CHYBA: Žádný chybový kód.')
						GUICtrlSetBkColor($gui_restore_target, $green)
						GUICtrlSetData($gui_error, 'Dokončeno.')
					endif
				else
					logger('rsync: Žádný chybový kód.')
					GUICtrlSetBkColor($gui_restore_target, $green)
					GUICtrlSetData($gui_error, 'Dokončeno.')
				endif
			else
				$exit_code = _WinAPI_GetExitCodeProcess($proc)
				if $exit_code = 0 then
					if not $terminate then
						GUICtrlSetBkColor($gui_restore_target, $green)
						GUICtrlSetData($gui_error, 'Dokončeno.')
					else
						GUICtrlSetData($gui_error, 'Přerušeno.')
					endif
				else
					; update error
					$error = True
					; update output
					$code_index = _ArrayBinarySearch($error_code, $exit_code)
					if @error then
						if $debug then logger('CHYBA: Neznámý kód ' & $exit_code)
						GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & @CRLF & 'CHYBA: Neznámý kód ' & $code[0] & '.' & @CRLF)
						GUICtrlSetData($gui_error, 'Dokončeno.')
					else
						logger('CHYBA: ' & $error_code[$code_index][1])
						GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & @CRLF & 'CHYBA: ' & $error_code[$code_index][1] & @CRLF)
						GUICtrlSetData($gui_error, $error_code[$code_index][1])
					endif
					GUICtrlSetBkColor($gui_restore_target, $red)
				endif
			endif
			; close handle
			_WinAPI_CloseHandle($proc)
			; log I/O
			if $buffer_out <> '' then logger(BinaryToString(StringToBinary($buffer_out), $SB_UTF8))
			if $buffer_err <> '' then logger(BinaryToString(StringToBinary($buffer_err), $SB_UTF8))
			; round
			logger(@CRLF & '[R] Obnovení dokončeno.')
			; update state
			if $terminate then
				Json_Put($conf, '.restore.state', $paused)
			elseif $error then
				Json_Put($conf, '.restore.state', $failed)
			else
				Json_Put($conf, '.restore.state', $done)
			endif
			; reset token
			$run = False
		endif
		; run
		if not $run and get_free_restore() and not $terminate then
			; reset error
			$error = False
			; update progress
			if $restore then GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & @CRLF & ' -- R -- >> OBNOVA << --' & @CRLF & @CRLF)
			if $restore_test then GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & @CRLF & ' -- R -- >> TEST OBNOVY << --' & @CRLF & @CRLF)
			; empty source
			if GUICtrlRead($gui_restore_target) == '' or not FileExists(GUICtrlRead($gui_restore_target)) then
				; update state
				Json_Put($conf, '.restore.state', $failed)
				; update color
				GUICtrlSetBkColor($gui_restore_target, $red)
				; update output
				GUICtrlSetData($gui_error, 'Cílový adresář neexistuje.')
				GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & 'Cílový adresář neexistuje.' & @CRLF)
				logger(@CRLF & '[R] NAS: Cílový adresář neexistuje.')
			 else
				logger(@CRLF & '[R] Obnovení zahájeno.' & @CRLF & @CRLF)
				; clear buffer
				$buffer = ''
				; update color
				GUICtrlSetBkColor($gui_restore_target, $orange)
				; update output
				if $restore then GUICtrlSetData($gui_error, 'Probíhá obnova.')
				if $restore_test then GUICtrlSetData($gui_error, 'Probíhá test obnovy.')
				; rsync
				$rsync = Run('"' & $rsync_binary & '"' _
				& ' -avz -s -h ' & $option & ' --stats -e ' & "'" _
				& '"' & $ssh_binary & '"' _
				& ' -o "StrictHostKeyChecking no" -o "UserKnownHostsFile=/dev/null"' _
				& ' -p ' & GUICtrlRead($gui_port) _
				& ' -i "' & GUICtrlRead($gui_key) & '"' & "' " _
				& GUICtrlRead($gui_user) & '@' & GUICtrlRead($gui_host) _
				& ':' & "'" & GUICtrlRead($gui_prefix) & GUICtrlRead($gui_restore_source) & "' " _
				& "'" & get_cygwin_path(GUICtrlRead($gui_restore_target)) & "'" _
				, @ScriptDir, @SW_HIDE, BitOR($STDERR_CHILD, $STDOUT_CHILD))
				; update token
				$run = True
			endif
		endif
		; end
		if not $run or $terminate Then
			; enable buttons
			GUICtrlSetState($gui_button_run, $GUI_ENABLE)
			if $admin then
				GUICtrlSetState($gui_button_test, $GUI_ENABLE)
				for $i = 0 to 9
					GUICtrlSetState($remote[$i][0], $GUI_ENABLE)
				next
				GUICtrlSetState($gui_restore_box, $GUI_ENABLE)
			endif
			; reset tokens
			$restore=False
			$restore_test=False
			$terminate=False
		endif
	endif
	; backup & backup test
	if $backup or $test then
		; logging
		if $run and get_free() >= 0 and not ProcessExists($rsync) then
			; free
			$index = get_free()
			; update I/O
			$buffer_out = StringReplace(StderrRead($rsync), @LF, @CRLF)
			$buffer_err = StringReplace(StdoutRead($rsync), @LF, @CRLF)
			$buffer &= $buffer_out
			$buffer &= $buffer_err
			; update output
			GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & BinaryToString(StringToBinary($buffer), $SB_UTF8))
			; exit code
			$proc = _WinAPI_OpenProcess($PROCESS_QUERY_LIMITED_INFORMATION, 0, $rsync, True)
			if @error or $proc = $INVALID_HANDLE_VALUE then
				if $debug then logger('CHYBA: WinAPI OpenProcess (query limited info)')
				; error code
				if $buffer_out <> '' or $buffer_err <> '' then
					$code = StringRegExp($buffer_out & $buffer_err, '\(code (\d+)\)', $STR_REGEXPARRAYMATCH)
					if not @error then
						; update errror
						$error = True
						; update output
						$code_index = _ArrayBinarySearch($error_code, $code[0])
						if @error then
							if $debug then logger('CHYBA: Neznámý chybový kód ' & $code[0])
							GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & @CRLF & 'CHYBA: Neznámý chybový kód ' & $code[0] & '.' & @CRLF)
							GUICtrlSetData($gui_error, 'Neznámá chyba.')
						else
							logger('rsync: Kód chyby ' & $code[0] & '.')
							GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & @CRLF & 'CHYBA: ' & $error_code[$code_index][1] & @CRLF)
							GUICtrlSetData($gui_error, $error_code[$code_index][1])
						endif
						; update color
						GUICtrlSetBkColor($remote[$index][1], $red)
					else
						if $debug then logger('CHYBA: Žádný chybový kód.')
						GUICtrlSetBkColor($remote[$index][1], $green)
						GUICtrlSetData($gui_error, 'Dokončeno.')
					endif
				else
					logger('rsync: Žádný chybový kód.')
					GUICtrlSetBkColor($remote[$index][1], $green)
					GUICtrlSetData($gui_error, 'Dokončeno.')
				endif
			else
				$exit_code = _WinAPI_GetExitCodeProcess($proc)
				if $exit_code = 0 then
					if not $terminate then
						GUICtrlSetBkColor($remote[$index][1], $green)
						GUICtrlSetData($gui_error, 'Dokončeno.')
					else
						GUICtrlSetData($gui_error, 'Přerušeno.')
					endif
				else
					; update errror
					$error = True
					; update output
					$code_index = _ArrayBinarySearch($error_code, $exit_code)
					if @error then
						if $debug then logger('CHYBA: Neznámý kód ' & $exit_code)
						GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & @CRLF & 'CHYBA: Neznámý kód ' & $exit_code & '.' & @CRLF)
						GUICtrlSetData($gui_error, 'Dokončeno.')
					else
						logger('CHYBA: ' & $error_code[$code_index][1])
						GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & @CRLF & 'CHYBA: ' & $error_code[$code_index][1] & @CRLF)
						GUICtrlSetData($gui_error, $error_code[$code_index][1])
					endif
					GUICtrlSetBkColor($remote[$index][1], $red)
				endif
			endif
			; close handle
			_WinAPI_CloseHandle($proc)
			; log I/O
			if $buffer_out <> '' then logger(BinaryToString(StringToBinary($buffer_out), $SB_UTF8))
			if $buffer_err <> '' then logger(BinaryToString(StringToBinary($buffer_err), $SB_UTF8))
			; round
			logger(@CRLF & '[' & $index + 1 & '] Zálohování dokončeno.')
			; update state
			if $terminate then
				Json_Put($conf, '.backup.' & $index & '.state', $paused)
			elseif $error then
				Json_Put($conf, '.backup.' & $index & '.state', $failed)
			else
				Json_Put($conf, '.backup.' & $index & '.state', $done)
				; update stats
				if $backup then Json_Put($conf, '.backup.' & $index & '.stat', update_stat($buffer_out & $buffer_err, $index))
			endif
			; reset token
			$run = False
		endif
		; run
		if not $run and get_free() >= 0 and not $terminate then
			; free
			$index = get_free()
			; reset error
			$error = False
			; update progress
			if $backup then	GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & @CRLF & ' -- ' & $index + 1 & ' -- >> ZÁLOHA << --' & @CRLF & @CRLF)
			if $test then GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & @CRLF & ' -- ' & $index + 1 & ' -- >> TEST ZÁLOHY << --' & @CRLF & @CRLF)
			; stats
			GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & get_stat($index))
			; empty source
			if GUICtrlRead($remote[$index][1]) == '' or not FileExists(GUICtrlRead($remote[$index][1])) then
				; update state
				Json_Put($conf, '.backup.' & $index & '.state', $failed)
				; update color
				GUICtrlSetBkColor($remote[$index][1], $red)
				; update output
				GUICtrlSetData($gui_error, 'Zdrojový adresář neexistuje.')
				GUICtrlSetData($gui_progress, GUICtrlRead($gui_progress) & 'Zdrojový adresář neexistuje.' & @CRLF)
				logger(@CRLF & '[' & $index + 1 & '] NAS: Zdrojový adresář neexistuje.')
			 else
				logger(@CRLF & '[' & $index + 1 & '] Zálohování zahájeno.' & @CRLF & @CRLF)
				; clear buffer
				$buffer = ''
				; update transfer start
				$transfer_start = @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC
				; update color
				GUICtrlSetBkColor($remote[$index][1], $orange)
				; update output
				if $backup then GUICtrlSetData($gui_error, 'Probíhá záloha.')
				if $test then GUICtrlSetData($gui_error, 'Probíhá test.')
				; rsync
				$rsync = Run('"' & $rsync_binary & '"' _
				& ' -avz -s -h ' & $option & ' --stats -e ' & "'" _
				& '"' & $ssh_binary & '"' _
				& ' -o "StrictHostKeyChecking no" -o "UserKnownHostsFile=/dev/null"' _
				& ' -p ' & GUICtrlRead($gui_port) _
				& ' -i "' & GUICtrlRead($gui_key) & '"' & "' " _
				& "'" & get_cygwin_path(GUICtrlRead($remote[$index][1])) & "' " _
				& GUICtrlRead($gui_user) & '@' & GUICtrlRead($gui_host) _
				& ':' & "'" & GUICtrlRead($gui_prefix) & GUICtrlRead($remote[$index][4]) & "'" _
				, @ScriptDir, @SW_HIDE, BitOR($STDERR_CHILD, $STDOUT_CHILD))
				; update token
				$run = True
			endif
		endif
		; end
		if ( not $run and get_free() < 0 ) or $terminate Then
			; enable buttons
			GUICtrlSetState($gui_button_run, $GUI_ENABLE)
			if $admin then
				GUICtrlSetState($gui_button_test, $GUI_ENABLE)
				for $i = 0 to 9
					GUICtrlSetState($remote[$i][0], $GUI_ENABLE)
				next
				GUICtrlSetState($gui_restore_box, $GUI_ENABLE)
			endif
			; reset tokens
			$backup=False
			$test=False
			$terminate=False
		endif
	endif
	; exit
	if $event = $GUI_EVENT_CLOSE or $event = $gui_button_exit then
		; not running
		if $run then
			GUICtrlSetData($gui_error, 'Nelze ukončit probíhající operaci.')
		else
			; write configuration
			for $i=0 to 9
				Json_Put($conf, '.backup.' & $i & '.source', GUICtrlRead($remote[$i][1]))
				Json_Put($conf, '.backup.' & $i & '.target', GUICtrlRead($remote[$i][4]))
				Json_Put($conf, '.backup.' & $i & '.enable', GUICtrlRead($remote[$i][0]))
			next
			Json_Put($conf, '.restore.source', GUICtrlRead($gui_restore_source))
			Json_Put($conf, '.restore.target', GUICtrlRead($gui_restore_target))
			Json_Put($conf, '.restore.enable', GUICtrlRead($gui_restore_box))
			Json_Put($conf, '.setup.host', GUICtrlRead($gui_host))
			Json_Put($conf, '.setup.port', GUICtrlRead($gui_port))
			Json_Put($conf, '.setup.user', GUICtrlRead($gui_user))
			Json_Put($conf, '.setup.key', GUICtrlRead($gui_key))
			Json_Put($conf, '.setup.prefix', GUICtrlRead($gui_prefix))
			$f = FileOpen($ini, 2 + 256); UTF8 no BOM overwrite
			FileWrite($f, Json_Encode($conf))
			FileClose($f)
			; exit
			exitloop
		endif
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
	$cygwin_path = StringRegExpReplace($cygwin_path, '^(.)\:(.*)', '\/cygdrive\/$1$2'); convert drive colon
	return $cygwin_path
endfunc

func verify_setup()
	; invalid key file
	if not FileExists(GUICtrlRead($gui_key)) then return SetError(1, 0, 'Neplatný klíč.')
	; empty user
	if GUICtrlRead($gui_user) == '' then return SetError(1, 0, 'Neplatný uživatel.')
	; invalid IP address
	if not StringRegExp(GUICtrlRead($gui_host), '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') then return SetError(1, 0, 'Neplatný host.')
	; invalid port number
	if GUICtrlRead($gui_port) < 1 or GUICtrlRead($gui_port) > 65535 then return SetError(1, 0, 'Neplatné číslo portu.')
	; empty prefix
	if GUICtrlRead($gui_prefix) == '' then return SetError(1, 0, 'Neplatný prefix.')
	; backup with restore
	for $i = 0 to 9
		if GUICtrlRead($remote[$i][0]) = $GUI_CHECKED then
			if GUICtrlRead($gui_restore_box) = $GUI_CHECKED then return SetError(1, 0, 'Nelze spustit zálohu i obnovu.')
		endif
	next
endfunc

func get_free()
	for $i = 0 to 9
		if GUICtrlRead($remote[$i][0]) = $GUI_CHECKED then
			if Json_ObjGet($conf, '.backup.' & $i & '.state') = $new or Json_ObjGet($conf, '.backup.' & $i & '.state') = $paused then
				return $i
			endif
		endif
	next
	return -1
endfunc

func get_free_restore()
	if GUICtrlRead($gui_restore_box) = $GUI_CHECKED then
		if Json_ObjGet($conf, '.restore.state') = $new then return True
		if Json_ObjGet($conf, '.restore.state') = $paused then return True
	endif
	return False
endfunc

func get_stat($index)
	local $data, $date, $output
	$date = @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' &  @SEC
	$data = StringSplit(Json_ObjGet($conf, '.backup.' & $index & '.stat'), '|', 2); 2-no count
	if not @error then
		$output &= ' -- Poslední zápis' & @CRLF
		if $data[0] then $output &= @CRLF & '    Datum: ' & StringReplace($data[0], '/', '.')
		if $data[1] then $output &= @CRLF & '    Velikost: ' & $data[1] & ' MB'
		if $data[2] then $output &= @CRLF & '    Trvání: ' & Round($data[2]/60, 2) & ' minut'
		if $data[3] then $output &= @CRLF & '    Interval: ' & $data[3] & ' dní'
		$output &= @CRLF & @CRLF
		if $data[0] and $data[1] and $data[2] and $data[3] then
			$output &= '    Odhadovaná velikost: ' & _DateDiff('D', $data[0], $date) / $data[3] * $data[1] & ' MB' & @CRLF
			$output &= '    Odhadovaný čas: ' & Round(_DateDiff('D', $data[0], $date) / $data[3] * $data[2] / 60) & ' minut'
			$output &= @CRLF & @CRLF
		endif
	endif
	return $output
endfunc

func update_stat($buffer, $index)
	local $date, $unit, $size, $time_generation, $duration, $data, $interval
	; date
	$date = @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' &  @SEC
	; size
	$unit = StringRegExp($buffer, 'Total transferred file size: (.+) bytes', $STR_REGEXPARRAYMATCH)
	if not @error then
		switch StringRegExpReplace($unit[0], '.*(.)$', '$1')
			case 'K'
				$size = StringRegExpReplace($unit[0], '(.*).$', '$1') * 1000
			case 'M'
				$size = StringRegExpReplace($unit[0], '(.*).$', '$1') * 1
			case 'G'
				$size = StringRegExpReplace($unit[0], '(.*).$', '$1') / 1000
			case 'T'
				$size = StringRegExpReplace($unit[0], '(.*).$', '$1') / 1000^2
			case 'P'
				$size = StringRegExpReplace($unit[0], '(.*).$', '$1') / 1000^3
		endswitch
	endif
	; duration
	$time_generation = StringRegExp($buffer, 'File list generation time: (.+) seconds', $STR_REGEXPARRAYMATCH)
	if not @error then
		$duration = _DateDiff('s', $transfer_start, $date) + int($time_generation[0])
	endif
	; interval
	$data = StringSplit(Json_ObjGet($conf, '.backup.' & $index & '.stat'), '|', 2); no-count
	if not @error then
		if $data[0] then $interval = _DateDiff('D', $data[0], $date)
	endif
	return $date & '|' & Round($size) & '|' & $duration & '|' & $interval
endfunc

func admin_mode($admin)
	local $state, $style
	if $admin = True then
		$state = $GUI_ENABLE
		$style = ''; default
	else
		$state = $GUI_DISABLE
		$style = 0x800; READ_ONLY
	endif
	GUICtrlSetState($gui_button_test, $state)
	GUICtrlSetStyle($gui_host, $style)
	GUICtrlSetStyle($gui_port, $style)
	GUICtrlSetStyle($gui_user, $style)
	GUICtrlSetStyle($gui_key, $style)
	GUICtrlSetState($gui_button_key, $state)
	GUICtrlSetStyle($gui_prefix, $style)
	GUICtrlSetState($gui_debug_check, $state)
	GUICtrlSetState($gui_restore_box, $state)
	GUICtrlSetStyle($gui_restore_source, $style)
	GUICtrlSetStyle($gui_restore_target, $style)
	GUICtrlSetState($gui_button_restore_target, $state)
	for $i = 0 to 3
		GUICtrlSetState($remote[$i][0], $state); checbox
		GUICtrlSetStyle($remote[$i][1], $style); source
		GUICtrlSetBkColor($remote[$i][1], $white)
		GUICtrlSetState($remote[$i][2], $state); button
		GUICtrlSetStyle($remote[$i][4], $style); target
		GUICtrlSetBkColor($remote[$i][4], $white)
	next
endfunc
