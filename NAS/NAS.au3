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

#Include <GuiEdit.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPIProc.au3>
#include <CryptoNG.au3>
#include <Json.au3>

; ---------------------------------------------------------
; VAR
; ---------------------------------------------------------

global $version = '2.0'

global $ini = @ScriptDir & '\NAS.ini'
global $logfile = @ScriptDir & '\NAS.log'
global $rsync_binary = @ScriptDir & '\bin\rsync.exe'
global $ssh_binary = @ScriptDir & '\bin\ssh.exe'

global $login = '0x3BD1B351E7E2488CBA0DED73A0D1AD1D60509F6B1C9EBC6C4032C03BD5A42B4CAA134BB7039EBA70AE5D16B89F3AF055FA31339BB85F0BE97973AFB75B310F0B'
global $admin = False
global $debug = False

global $white = 0xffffff
global $green = 0x77dd77
global $orange = 0xffb347
global $red = 0xff6961

global $remote[8][5]; GUI handle map: checkbox | source | button | prefix | target
global $local[10][5]; GUI handle map: checkbox | source | button | target | button
global $network[2][11]; GUI handle map: label | host | label | port | label | user | label | key | button | label | prefix

global $INVALID_HANDLE_VALUE = ptr(0xffffffff)

global $rsync; rsync PID
global $option; rsync option
global $buffer; rsync combined buffer
global $buffer_out; rsync STDOUT
global $buffer_err; rsync STDERR

global $token_remote = False
global $token_local = False
global $token_run = False
global $token_terminate = False

global $index[0]; enabled remote/local
global $conf; configuration struct

global $color_white = 0xffffff
global $color_green = 0x77dd77
global $color_orange = 0xffb347
global $color_red = 0xff6961

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

global $default = '{' _
	& '"remote":[' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""}],' _
	& '"local":[' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""},' _
	& '{"enable":4,"source":"","target":""}],' _
	& '"network":[' _
	& '{"host":"","port":"","user":"","key":"","prefix":""},' _
	& '{"host":"","port":"","user":"","key":"","prefix":""}],' _
	& '"setup":{"debug":4}' _
	& '}'

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

; default ini
if not FileExists($ini) then
	$out = FileOpen($ini, 2 + 256); UTF8 / NOBOM overwrite
	FileWrite($out, Json_Encode(Json_Decode($default)))
	if @error then logger('Zápis výchozího nastavení selhal.')
	FileClose($out)
endif

;read configuration
$conf = Json_Decode(FileRead($ini))
if @error then
	MsgBox(48, 'NAS ' & $version, 'Načtení nastavení selhalo.')
	exit
endif

; ---------------------------------------------------------
; GUI
; ---------------------------------------------------------

$gui = GUICreate('NAS ' & $version, 632, 340, Default, Default)
$gui_tab = GUICtrlCreateTab(5, 5, 621, 302)
; GUI - REMOTE
$gui_tab_remote = GUICtrlCreateTabItem('Vzdálená')
$gui_group_remote_nas1 = GUICtrlCreateGroup('Lokalita A', 12, 28, 606, 135)
$gui_group_remote_nas2 = GUICtrlCreateGroup('Lokalita B', 12, 163, 606, 135)
for $i = 0 to 3
	$remote[$i][0] = GUICtrlCreateCheckbox('', 20, 48 + $i*26, 16, 21)
	GUICtrlSetState($remote[$i][0], Json_Get($conf, '.remote[' & $i & '].enable'))
	$remote[$i][1] = GUICtrlCreateInput(Json_Get($conf, '.remote[' & $i & '].source'), 40, 49 + $i*26, 189, 21)
	$remote[$i][2] = GUICtrlCreateButton('Procházet', 233, 49 + $i*26, 75, 21)
	$remote[$i][3] = GUICtrlCreateLabel(Json_Get($conf, '.network[0].prefix'), 325, 52 + $i*26, 90, 21, 0x01); $SS_CENTER
	$remote[$i][4] = GUICtrlCreateInput(Json_Get($conf, '.remote[' & $i & '].target'), 421, 49 + $i*26, 188, 21)
	$remote[$i+4][0] = GUICtrlCreateCheckbox('', 20, 185 + $i*26, 16, 21)
	GUICtrlSetState($remote[$i+4][0], Json_Get($conf, '.remote[' & $i+4 & '].enable'))
	$remote[$i+4][1] = GUICtrlCreateInput(Json_Get($conf, '.remote[' & $i+4 & '].source'), 40, 185 + $i*26, 189, 21)
	$remote[$i+4][2] = GUICtrlCreateButton('Procházet', 233, 185 + $i*26, 75, 21)
	$remote[$i+4][3] = GUICtrlCreateLabel(Json_Get($conf, '.network[1].prefix'), 325, 188 + $i*26, 90, 21, 0x01); $SS_CENTER
	$remote[$i+4][4] = GUICtrlCreateInput(Json_Get($conf, '.remote[' & $i+4 & '].target'), 421, 185 + $i*26, 188, 21)
next
; GUI - LOCAL
$gui_tab_local = GUICtrlCreateTabItem('Lokální')
$gui_group_local_source = GUICtrlCreateGroup('Zdroj', 12, 28, 312, 270)
$gui_group_local_target = GUICtrlCreateGroup('Cíl', 327, 28, 291, 270)
for $i = 0 to 9
	$local[$i][0] = GUICtrlCreateCheckbox('', 20, 43 + $i*25, 16, 21)
	GUICtrlSetState($local[$i][0], Json_Get($conf, '.local[' & $i & '].enable'))
	$local[$i][1] = GUICtrlCreateInput(Json_Get($conf, '.local[' & $i & '].source'), 40, 44 + $i*25, 196, 21)
	$local[$i][2] = GUICtrlCreateButton('Procházet', 241, 44 + $i*25, 75, 21)
	$local[$i][3] = GUICtrlCreateInput(Json_Get($conf, '.local[' & $i & '].target'), 335, 44 + $i*25, 195, 21)
	$local[$i][4] = GUICtrlCreateButton('Procházet', 535, 44 + $i*25, 75, 21)
next
; GUI - OUTPUT
$gui_tab_output = GUICtrlCreateTabItem('Výstup')
$gui_output = GUICtrlCreateEdit('', 15, 35, 600, 262, BitOR($ES_AUTOVSCROLL, $ES_READONLY, $ES_WANTRETURN, $WS_VSCROLL))
; GUI - CONNECTION
$gui_tab_connection = GUICtrlCreateTabItem('Připojení')
$gui_group_connection_nas1 = GUICtrlCreateGroup('Lokalita A', 12, 28, 606, 135)
$gui_group_connection_nas2 = GUICtrlCreateGroup('Lokalita B', 12, 163, 606, 135)
for $i = 0 to 1
	$network[$i][0] = GUICtrlCreateLabel('Host:', 20 ,46 + $i*135, 60, 21)
	$network[$i][1] = GUICtrlCreateInput(Json_Get($conf, '.network[' & $i & '].host'), 240, 40 + $i*135, 90, 21)
	$network[$i][2] = GUICtrlCreateLabel('Port:',20 , 68 + $i*135, 25, 21)
	$network[$i][3] = GUICtrlCreateInput(Json_Get($conf, '.network[' & $i & '].port'), 290, 64 + $i*135, 40, 21)
	$network[$i][4] = GUICtrlCreateLabel('Uživatel:',20 , 92 + $i*135, 40, 21)
	$network[$i][5] = GUICtrlCreateInput(Json_Get($conf, '.network[' & $i & '].user'), 240, 88 + $i*135, 90, 21)
	$network[$i][6] = GUICtrlCreateLabel('SSH klíč:', 20, 116 + $i*135, 90, 21)
	$network[$i][7] = GUICtrlCreateInput(Json_Get($conf, '.network[' & $i & '].key'), 76, 112 + $i*135, 254, 21)
	$network[$i][8] = GUICtrlCreateButton('Procházet', 334, 112 + $i*135, 75, 21)
	$network[$i][9] = GUICtrlCreateLabel('NAS prefix:', 20, 140 + $i*135, 60, 21)
	$network[$i][10] = GUICtrlCreateInput(Json_Get($conf, '.network[' & $i & '].prefix'), 220, 136 + $i*135, 110, 21)
next
; GUI - SETUP
$gui_tab_setup = GUICtrlCreateTabItem('Nastavení')
$gui_group_setup = GUICtrlCreateGroup('', 12, 28, 606, 66)
$gui_group_setup_blank = GUICtrlCreateGroup('', 12, 94, 606, 204)
$gui_setup_debug_label = GUICtrlCreateLabel('Režim ladění:', 20, 46, 80, 21)
$gui_setup_debug_check = GUICtrlCreateCheckbox('', 240, 40, 16, 21)
GUICtrlSetState($gui_setup_debug_check, Json_Get($conf, '.setup.debug'))
$gui_setup_pwd_label = GUICtrlCreateLabel('Režim správce:', 20, 68, 150, 21)
$gui_setup_pwd = GUICtrlCreateInput('', 240, 64, 90, 21, BitOR(0x0020,0x0001)); ES_PASSWORD
$gui_setup_button_pwd = GUICtrlCreateButton('Povolit', 334, 64, 75, 21)
$gui_tab_end = GUICtrlCreateTabItem(''); tab end
; GUI - MAIN
$gui_error = GUICtrlCreateLabel('', 10, 318, 298, 21)
$gui_button_run = GUICtrlCreateButton('Spustit', 394, 314, 75, 21)
$gui_button_break = GUICtrlCreateButton('Přerušit', 472, 314, 75, 21)
$gui_button_exit = GUICtrlCreateButton('Storno', 550, 314, 75, 21)

; set mode
admin_mode()

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
	if $event = $gui_setup_button_pwd then
		if _CryptoNG_HashData($CNG_BCRYPT_SHA512_ALGORITHM , GUICtrlRead($gui_setup_pwd)) = Binary($login) then
			if $admin = False Then
				$admin = True
				GUICtrlSetData($gui_setup_button_pwd,'Zakázat')
			else
				$admin = False
				GUICtrlSetData($gui_setup_button_pwd,'Povolit')
			endif
			admin_mode($admin)
		endif
		GUICtrlSetData($gui_setup_pwd, '')
	endif
	; debug mode
	if GUICtrlRead($gui_setup_debug_check) = $GUI_CHECKED then
		$debug = True
	else
		$debug = False
	endif
	; remote source
	$browse = _ArraySearch($remote, $event, Default, Default, Default, Default, Default, 2); 3'rd column
	if not @error then
		$path = FileSelectFolder('NAS ' & $version & ' - Zdrojový adresář', @HomeDrive)
		if not @error then GUICtrlSetData($remote[$browse][1], $path)
	endif
	; local source
	$browse = _ArrayBinarySearch($local, $event, Default, Default, 2); 3'rd column
	if not @error then
		$path = FileSelectFolder('NAS ' & $version & ' - Zdrojový adresář', @HomeDrive)
		if not @error then GUICtrlSetData($local[$browse][1], $path)
	endif
	; local target
	$browse = _ArrayBinarySearch($local, $event, Default, Default, 4); 5'th column
	if not @error then
		$path = FileSelectFolder('NAS ' & $version & ' - Cílový adresář', @HomeDrive)
		if not @error then GUICtrlSetData($local[$browse][3], $path)
	endif
	; SSH key
	if $event = $network[0][8] then
		$key = FileOpenDialog('NAS ' & $version & ' - SSH klíč', @HomeDrive,  'All (*.*)')
		if not @error then GUICtrlSetData($network[0][7], $key)
	endif
	if $event = $network[1][8] then
		$key = FileOpenDialog('NAS ' & $version & ' - SSH klíč', @HomeDrive,  'All (*.*)')
		if not @error then GUICtrlSetData($network[1][7], $key)
	endif
	; update remote prefix
	if $event = $gui_tab Then
		if GUICtrlRead($gui_tab) = 0 Then; 1st tab
			for $i=0 to 3
				GUICtrlSetData($remote[$i][3], GUICtrlRead($network[0][10]))
				GUICtrlSetData($remote[$i+4][3], GUICtrlRead($network[1][10]))
			Next
		endif
	endif
	; limit run / terminate tab
	if $event = $gui_tab Then
		if GUICtrlRead($gui_tab) > 1 Then; 2nd+ tab
			if GUICtrlGetState($gui_button_run) = BitOR($GUI_SHOW, $GUI_ENABLE) Then
				GUICtrlSetState($gui_button_run, $GUI_DISABLE)
			endif
		elseif GUICtrlGetState($gui_button_run) = BitOR($GUI_SHOW, $GUI_DISABLE) Then
			if not ($token_remote or $token_local) then
				GUICtrlSetState($gui_button_run, $GUI_ENABLE)
			endif
		endif
	endif
	; unset color on disable
	$checkbox = _ArrayBinarySearch($remote, $event, Default, Default, 0); zero column
	if not @error then
		if GUICtrlRead($remote[$checkbox][0]) = $GUI_UNCHECKED then GUICtrlSetBkColor($remote[$checkbox][1], $white)
	endif
	$checkbox = _ArrayBinarySearch($local, $event, Default, Default, 0); zero column
	if not @error then
		if GUICtrlRead($local[$checkbox][0]) = $GUI_UNCHECKED then GUICtrlSetBkColor($local[$checkbox][1], $white)
	endif
	; init
	if $event = $gui_button_run then
		if GuiCtrlRead($gui_tab) = 0 then
			$verify = verify_remote_setup()
			if @error Then
				logger('CHYBA: ' & $verify)
				GUICtrlSetData($gui_error, $verify)
			else
				; option
				$option=''
				; clear output
				GUICtrlSetData($gui_output, '')
				; set token
				$token_remote=True
				; update index
				global $index[0]; flush
				for $i = 0 to 3
					if GUICtrlRead($remote[$i][0]) = $GUI_CHECKED then _ArrayAdd($index, $i)
					if GUICtrlRead($remote[$i+4][0]) = $GUI_CHECKED then _ArrayAdd($index, $i+4)
					; reset color
					GUICtrlSetBkColor($remote[$i][1], $white)
					GUICtrlSetBkColor($remote[$i+4][1], $white)
				next
				; disable GUI
				GUICtrlSetState($gui_button_run, $GUI_DISABLE)
				if $admin then
					for $i = 0 to 3
						GUICtrlSetState($remote[$i][0], $GUI_DISABLE)
						GUICtrlSetState($remote[$i+4][0], $GUI_DISABLE)
					next
				endif
			endif
		endif
		if GuiCtrlRead($gui_tab) = 1 then
			; option
			$option=''
			; clear output
			GUICtrlSetData($gui_output, '')
			; set token
			$token_local=True
			; update index
			global $index[0]; flush
			for $i = 0 to 9
				if GUICtrlRead($local[$i][0]) = $GUI_CHECKED then _ArrayAdd($index, $i)
				; reset color
				GUICtrlSetBkColor($local[$i][1], $white)
			next
			; disable GUI
			GUICtrlSetState($gui_button_run, $GUI_DISABLE)
			if $admin then
				for $i = 0 to 9
					GUICtrlSetState($local[$i][0], $GUI_DISABLE)
				next
			endif
		endif
	endif
	; terminate
	if $event = $gui_button_break then
		if $token_run then
			ProcessClose($rsync)
			if @error then
				logger('CHYBA: ProcessClose')
			else
				logger('rsync: Probíhá ukončení.')
				ProcessWaitClose($rsync)
			endif
			; set token
			$token_terminate=True
		endif
	endif
	; backup
	if $token_remote or $token_local then
		; post-run
		if $token_run and not ProcessExists($rsync) then
			; update I/O
			$buffer_out = StringReplace(StderrRead($rsync), @LF, @CRLF)
			$buffer_err = StringReplace(StdoutRead($rsync), @LF, @CRLF)
			$buffer &= $buffer_out
			$buffer &= $buffer_err
			; update output
			GUICtrlSetData($gui_output, GUICtrlRead($gui_output) & BinaryToString(StringToBinary($buffer), $SB_UTF8))
			; exit code
			$proc = _WinAPI_OpenProcess($PROCESS_QUERY_LIMITED_INFORMATION, 0, $rsync, True)
			if @error or $proc = $INVALID_HANDLE_VALUE then
				if $debug then logger('CHYBA: WinAPI OpenProcess (query limited info)')
				; error code
				if $buffer_out <> '' or $buffer_err <> '' then
					$code = StringRegExp($buffer_out & $buffer_err, '\(code (\d+)\)', $STR_REGEXPARRAYMATCH)
					if not @error then
						; update output
						$code_index = _ArrayBinarySearch($error_code, $code[0])
						if @error then
							if $debug then logger('CHYBA: Neznámý chybový kód ' & $code[0])
							GUICtrlSetData($gui_output, GUICtrlRead($gui_output) & @CRLF & 'CHYBA: Neznámý chybový kód ' & $code[0] & '.' & @CRLF)
							GUICtrlSetData($gui_error, 'Neznámá chyba.')
						else
							logger('rsync: Kód chyby ' & $code[0] & '.')
							GUICtrlSetData($gui_output, GUICtrlRead($gui_output) & @CRLF & 'CHYBA: ' & $error_code[$code_index][1] & @CRLF)
							GUICtrlSetData($gui_error, $error_code[$code_index][1])
						endif
						; update color
						if $token_remote then GUICtrlSetBkColor($remote[$index[0]][1], $red)
						if $token_local then GUICtrlSetBkColor($local[$index[0]][1], $red)
					else
						if $debug then logger('CHYBA: Žádný chybový kód.')
						if $token_remote then GUICtrlSetBkColor($remote[$index[0]][1], $green)
						if $token_local then GUICtrlSetBkColor($local[$index[0]][1], $green)
						GUICtrlSetData($gui_error, 'Dokončeno.')
					endif
				else
					logger('rsync: Žádný chybový výstup.')
					if $token_remote then GUICtrlSetBkColor($remote[$index[0]][1], $green)
					if $token_local then GUICtrlSetBkColor($local[$index[0]][1], $green)
					GUICtrlSetData($gui_error, 'Dokončeno.')
				endif
			else
				$exit_code = _WinAPI_GetExitCodeProcess($proc)
				if $exit_code = 0 then
					if $token_terminate then
						GUICtrlSetData($gui_error, 'Přerušeno.')
					else
						if $token_remote then GUICtrlSetBkColor($remote[$index[0]][1], $green)
						if $token_local then GUICtrlSetBkColor($local[$index[0]][1], $green)
						GUICtrlSetData($gui_error, 'Dokončeno.')
					endif
				else
					; update output
					$code_index = _ArrayBinarySearch($error_code, $exit_code)
					if @error then
						if $debug then logger('CHYBA: Neznámý kód ' & $exit_code)
						GUICtrlSetData($gui_output, GUICtrlRead($gui_output) & @CRLF & 'CHYBA: Neznámý kód ' & $exit_code & '.' & @CRLF)
						GUICtrlSetData($gui_error, 'Dokončeno.')
					else
						logger('CHYBA: ' & $error_code[$code_index][1])
						GUICtrlSetData($gui_output, GUICtrlRead($gui_output) & @CRLF & 'CHYBA: ' & $error_code[$code_index][1] & @CRLF)
						GUICtrlSetData($gui_error, $error_code[$code_index][1])
					endif
					if $token_remote then GUICtrlSetBkColor($remote[$index[0]][1], $red)
					if $token_local then GUICtrlSetBkColor($local[$index[0]][1], $red)
				endif
			endif
			; close handle
			_WinAPI_CloseHandle($proc)
			; log I/O
			if $buffer_out <> '' then logger(BinaryToString(StringToBinary($buffer_out), $SB_UTF8))
			if $buffer_err <> '' then logger(BinaryToString(StringToBinary($buffer_err), $SB_UTF8))
			; round
			logger(@CRLF & '[' & $index + 1 & '] Zálohování dokončeno.')
			; reset token
			$token_run = False
			; pop index
			_ArrayDelete($index, 0)
		endif
		; run
		if not ( $token_run or $token_terminate ) and Ubound($index) then
			; update output
			GUICtrlSetData($gui_output, GUICtrlRead($gui_output) & @CRLF & ' -- >> ZÁLOHA << --' & @CRLF & @CRLF)
			if $token_remote then
				if GUICtrlRead($remote[$index][1]) == '' or not FileExists(GUICtrlRead($remote[$index][1])) then
					; update color
					GUICtrlSetBkColor($remote[$index[0]][1], $red)
					; update output
					GUICtrlSetData($gui_error, 'Zdrojový adresář neexistuje.')
					GUICtrlSetData($gui_output, GUICtrlRead($gui_output) & 'Zdrojový adresář neexistuje.' & @CRLF)
					logger(@CRLF & 'Zdrojový adresář neexistuje.')
					; pop index
					_ArrayDelete($index, 0)
				 else
					logger(@CRLF & 'Vzdálené zálohování zahájeno.' & @CRLF & @CRLF)
					;localtion
					$site = 0
					if $index[0] > 3 then $site = 1
					; clear current I/O buffer
					$buffer = ''
					; update color
					GUICtrlSetBkColor($remote[$index[0]][1], $orange)
					; update output
					GUICtrlSetData($gui_error, 'Probíhá vzdálená záloha.')
					; rsync
					$rsync = Run('"' & $rsync_binary & '"' _
					& ' -avz -s -h ' & $option & ' --stats -e ' & "'" _
					& '"' & $ssh_binary & '"' _
					& ' -o "StrictHostKeyChecking no" -o "UserKnownHostsFile=/dev/null"' _
					& ' -p ' & GUICtrlRead($network[$site][3]) _
					& ' -i "' & GUICtrlRead($network[$site][7]) & '"' & "' " _
					& "'" & get_cygwin_path(GUICtrlRead($remote[$index[0]][1])) & "' " _
					& GUICtrlRead($network[$site][5]) & '@' & GUICtrlRead($network[$site][1]) _
					& ':' & "'" & GUICtrlRead($network[$site][10]) & GUICtrlRead($remote[$index[0]][4]) & "'" _
					, @ScriptDir, @SW_HIDE, BitOR($STDERR_CHILD, $STDOUT_CHILD))
					; update token
					$token_run = True
				endif
			endif
			if $token_local then
				if not FileExists(GUICtrlRead($local[$index[0]][1])) then
					; update color
					GUICtrlSetBkColor($local[$index[0]][1], $red)
					; update output
					GUICtrlSetData($gui_error, 'Zdrojový adresář neexistuje.')
					GUICtrlSetData($gui_output, GUICtrlRead($gui_output) & 'Zdrojový adresář neexistuje.' & @CRLF)
					logger(@CRLF & 'Zdrojový adresář neexistuje.')
					; pop index
					_ArrayDelete($index, 0)
				elseif not FileExists(GUICtrlRead($local[$index[0]][3])) then
					; update color
					GUICtrlSetBkColor($local[$index[0]][1], $red)
					; update output
					GUICtrlSetData($gui_error, 'Cilový adresář neexistuje.')
					GUICtrlSetData($gui_output, GUICtrlRead($gui_output) & 'Cilový adresář neexistuje.' & @CRLF)
					logger(@CRLF & 'Cilový adresář neexistuje.')
					; pop index
					_ArrayDelete($index, 0)
				else
					logger(@CRLF & 'Lokální zálohování zahájeno.' & @CRLF & @CRLF)
					; clear current I/O buffer
					$buffer = ''
					; update color
					GUICtrlSetBkColor($local[$index[0]][1], $orange)
					; update output
					GUICtrlSetData($gui_error, 'Probíhá lokální záloha.')
					; rsync
					$rsync = Run('"' & $rsync_binary & '" -avz -s -h --stats ' _
					& "'" & get_cygwin_path(GUICtrlRead($local[$index[0]][1])) & "' " _
					& "'" & get_cygwin_path(GUICtrlRead($local[$index[0]][3])) & "'" _
					, @ScriptDir, @SW_HIDE, BitOR($STDERR_CHILD, $STDOUT_CHILD))
					; update token
					$token_run = True
				endif
			endif
		endif
		; end
		if not Ubound($index) or $token_terminate then
			; enable buttons
			GUICtrlSetState($gui_button_run, $GUI_ENABLE)
			if $admin then
				for $i = 0 to 3
					GUICtrlSetState($remote[$i][0], $GUI_ENABLE)
					GUICtrlSetState($remote[$i+4][0], $GUI_ENABLE)
				next
				for $i = 0 to 9
					GUICtrlSetState($local[$i][0], $GUI_ENABLE)
				next
			endif
			; reset tokens
			$token_remote=False
			$token_local=False
			$token_terminate=False
		endif
	endif
	; exit
	if $event = $GUI_EVENT_CLOSE or $event = $gui_button_exit then
		if $token_run then
			GUICtrlSetData($gui_error, 'Nelze ukončit probíhající operaci.')
		else
			; update config
			for $i = 0 to 3; remote
				Json_Put($conf, '.remote[' & $i & '].enable', GuiCtrlRead($remote[$i][0]), True)
				Json_Put($conf, '.remote[' & $i+4 & '].enable', GuiCtrlRead($remote[$i+4][0]), True)
				Json_Put($conf, '.remote[' & $i & '].source', GuiCtrlRead($remote[$i][1]), True)
				Json_Put($conf, '.remote[' & $i+4 & '].source', GuiCtrlRead($remote[$i+4][1]), True)
				Json_Put($conf, '.remote[' & $i & '].target', GuiCtrlRead($remote[$i][4]), True)
				Json_Put($conf, '.remote[' & $i+4 & '].target', GuiCtrlRead($remote[$i+4][4]), True)
			next
			for $i = 0 to 9; local
				Json_Put($conf, '.local[' & $i & '].enable', GuiCtrlRead($local[$i][0]), True)
				Json_Put($conf, '.local[' & $i & '].source', GuiCtrlRead($local[$i][1]), True)
				Json_Put($conf, '.local[' & $i & '].target', GuiCtrlRead($local[$i][3]), True)
			next
			for $i = 0 to 1; network
				Json_Put($conf, '.network[' & $i & '].host', GuiCtrlRead($network[$i][1]), True)
				Json_Put($conf, '.network[' & $i & '].port', GuiCtrlRead($network[$i][3]), True)
				Json_Put($conf, '.network[' & $i & '].user', GuiCtrlRead($network[$i][5]), True)
				Json_Put($conf, '.network[' & $i & '].key', GuiCtrlRead($network[$i][7]), True)
				Json_Put($conf, '.network[' & $i & '].prefix', GuiCtrlRead($network[$i][10]), True)
			next
			Json_Put($conf, '.setup.debug', GuiCtrlRead($gui_setup_debug_check), True)
			; write config
			$out = FileOpen($ini, 2 + 256); UTF8 / NOBOM overwrite
			FileWrite($out, Json_Encode($conf))
			if @error then logger('Zápis nastavení selhal.')
			FileClose($out)
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

func verify_remote_setup()
	for $i = 0 to 1; network
		; invalid IP address
		if not StringRegExp(GUICtrlRead($network[$i][1]), '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') then return SetError(1, 0, 'Neplatný host.')
		; invalid port number
		if GUICtrlRead($network[$i][3]) < 1 or GUICtrlRead($network[$i][3]) > 65535 then return SetError(1, 0, 'Neplatné číslo portu.')
		; empty user
		if GUICtrlRead($network[$i][5]) == '' then return SetError(1, 0, 'Neplatný uživatel.')
		; invalid key file
		if not FileExists(GUICtrlRead($network[$i][7])) then return SetError(1, 0, 'Neplatný klíč.')
		; empty prefix
		if GUICtrlRead($network[$i][10]) == '' then return SetError(1, 0, 'Neplatný prefix.')
	next
endfunc

func admin_mode($admin=False)
	local $state=$GUI_DISABLE, $style=0x800; RO
	if $admin = True then
		$state = $GUI_ENABLE
		$style = ''
	endif
	for $i = 0 to 3; remote
		GUICtrlSetState($remote[$i][0], $state)
		GUICtrlSetStyle($remote[$i][1], $style)
		GUICtrlSetBkColor($remote[$i][1], $white)
		GUICtrlSetState($remote[$i][2], $state)
		GUICtrlSetStyle($remote[$i][4], $style)
		GUICtrlSetBkColor($remote[$i][4], $white)
		GUICtrlSetState($remote[$i+4][0], $state)
		GUICtrlSetStyle($remote[$i+4][1], $style)
		GUICtrlSetBkColor($remote[$i+4][1], $white)
		GUICtrlSetState($remote[$i+4][2], $state)
		GUICtrlSetStyle($remote[$i+4][4], $style)
		GUICtrlSetBkColor($remote[$i+4][4], $white)
	next
	for $i = 0 to 9; local
		GUICtrlSetState($local[$i][0], $state)
		GUICtrlSetStyle($local[$i][1], $style)
		GUICtrlSetBkColor($local[$i][1], $white)
		GUICtrlSetState($local[$i][2], $state)
		GUICtrlSetStyle($local[$i][3], $style)
		GUICtrlSetBkColor($local[$i][3], $white)
		GUICtrlSetState($local[$i][4], $state)
	next
	for $i = 0 to 1; network
		GUICtrlSetStyle($network[$i][1], $style)
		GUICtrlSetBkColor($network[$i][1], $white)
		GUICtrlSetStyle($network[$i][3], $style)
		GUICtrlSetBkColor($network[$i][3], $white)
		GUICtrlSetStyle($network[$i][5], $style)
		GUICtrlSetBkColor($network[$i][5], $white)
		GUICtrlSetStyle($network[$i][7], $style)
		GUICtrlSetBkColor($network[$i][7], $white)
		GUICtrlSetState($network[$i][8], $state)
		GUICtrlSetStyle($network[$i][10], $style)
		GUICtrlSetBkColor($network[$i][10], $white)
	next
	GUICtrlSetState($gui_setup_debug_check, $state); debug
endfunc
