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
#include <CryptoNG.au3>
#include <Json.au3>

; ---------------------------------------------------------
; VAR
; ---------------------------------------------------------

global $version = '2.0'

global $ini = @ScriptDir & '\NAS.ini'
global $logfile = @ScriptDir & '\NAS.log'

global $login = '0x3BD1B351E7E2488CBA0DED73A0D1AD1D60509F6B1C9EBC6C4032C03BD5A42B4CAA134BB7039EBA70AE5D16B89F3AF055FA31339BB85F0BE97973AFB75B310F0B'
global $admin = False
global $debug = False

global $white = 0xffffff
global $green = 0x77dd77
global $orange = 0xffb347
global $red = 0xff6961

global $remote[8][5]; checkbox | source | button | prefix | target
global $local[10][5]; checkbox | source | button | target | button
global $network[2][11]; label | host | label | port | label | user | label | key | button | label | prefix

global $default = '{' _
	& '"remote":[' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""}],' _
	& '"local":[' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""},' _
	& '{"state":4,"enable":0,"source":"","target":""}],' _
	& '"network":[' _
	& '{"host":"","port":"","user":"","key":"","prefix":""},' _
	& '{"host":"","port":"","user":"","key":"","prefix":""}],' _
	& '"setup":{"debug":0}' _
	& '}'

global $conf = JsonDecode($default)

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
	FileWrite($ini, Json_Encode($conf))
endif

;read configuration
$conf = JsonDecode(FileRead($ini))
if $error then
	MsgBox(48, 'NAS ' & $version, 'Read config failed.')
	exit
else
	logger("Read configuration.")

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
	GUICtrlSetState($remote[$i][0], Json_ObjGet($conf, '.remote.[' & $i & '].enable'))
	$remote[$i][1] = GUICtrlCreateInput(Json_ObjGet($conf, '.remote.[' & $i & '].source'), 40, 49 + $i*26, 189, 21)
	$remote[$i][2] = GUICtrlCreateButton('Procházet', 233, 49 + $i*26, 75, 21)
	$remote[$i][3] = GUICtrlCreateLabel(Json_ObjGet($conf, '.network.[0].prefix'), 325, 52 + $i*26, 90, 21, 0x01); $SS_CENTER
	$remote[$i][4] = GUICtrlCreateInput(Json_ObjGet($conf, '.remote.[' & $i & '].target'), 421, 49 + $i*26, 188, 21)
	$remote[$i+4][0] = GUICtrlCreateCheckbox('', 20, 185 + $i*26, 16, 21)
	GUICtrlSetState($remote[$i+4][0], Json_ObjGet($conf, '.remote.[' & $i+4 & '].enable'))
	$remote[$i+4][1] = GUICtrlCreateInput(Json_ObjGet($conf, '.remote.[' & $i+4 & '].source'), 40, 185 + $i*26, 189, 21)
	$remote[$i+4][2] = GUICtrlCreateButton('Procházet', 233, 185 + $i*26, 75, 21)
	$remote[$i+4][3] = GUICtrlCreateLabel(Json_ObjGet($conf, '.network.[1].prefix'), 325, 188 + $i*26, 90, 21, 0x01); $SS_CENTER
	$remote[$i+4][4] = GUICtrlCreateInput(Json_ObjGet($conf, '.remote.[' & $i+4 & '].target'), 421, 185 + $i*26, 188, 21)
next
; GUI - LOCAL
$gui_tab_local = GUICtrlCreateTabItem('Lokální')
$gui_group_local_source = GUICtrlCreateGroup('Zdroj', 12, 28, 312, 270)
$gui_group_local_target = GUICtrlCreateGroup('Cíl', 327, 28, 291, 270)
for $i = 0 to 9
	$local[$i][0] = GUICtrlCreateCheckbox('', 20, 43 + $i*25, 16, 21)
	GUICtrlSetState($local[$i][0], Json_ObjGet($conf, '.local.[' & $i & '].enable'))
	$local[$i][1] = GUICtrlCreateInput(Json_ObjGet($conf, '.local.[' & $i & '].source'), 40, 44 + $i*25, 196, 21)
	$local[$i][2] = GUICtrlCreateButton('Procházet', 241, 44 + $i*25, 75, 21)
	$local[$i][3] = GUICtrlCreateInput(Json_ObjGet($conf, '.local.[' & $i & '].target'), 335, 44 + $i*25, 195, 21)
	$local[$i][4] = GUICtrlCreateButton('Procházet', 535, 44 + $i*25, 75, 21)
next
; GUI - OUTPUT
$gui_tab_output = GUICtrlCreateTabItem('Výstup')
$gui_output_input = GUICtrlCreateEdit('', 15, 35, 600, 262, BitOR($ES_AUTOVSCROLL, $ES_READONLY, $ES_WANTRETURN, $WS_VSCROLL))
; GUI - CONNECTION
$gui_tab_connection = GUICtrlCreateTabItem('Připojení')
$gui_group_connection_nas1 = GUICtrlCreateGroup('Lokalita A', 12, 28, 606, 135)
$gui_group_connection_nas2 = GUICtrlCreateGroup('Lokalita B', 12, 163, 606, 135)
for $i = 0 to 1
	$network[$i][0] = GUICtrlCreateLabel('Host:', 20 ,46 + $i*135, 60, 21)
	$network[$i][1] = GUICtrlCreateInput(Json_ObjGet($conf, '.network.[' & $i & '].host'), 240, 40 + $i*135, 90, 21)
	$network[$i][2] = GUICtrlCreateLabel('Port:',20 , 68 + $i*135, 25, 21)
	$network[$i][3] = GUICtrlCreateInput(Json_ObjGet($conf, '.network.[' & $i & '].port'), 290, 64 + $i*135, 40, 21)
	$network[$i][4] = GUICtrlCreateLabel('Uživatel:',20 , 92 + $i*135, 40, 21)
	$network[$i][5] = GUICtrlCreateInput(Json_ObjGet($conf, '.network.[' & $i & '].user'), 240, 88 + $i*135, 90, 21)
	$network[$i][6] = GUICtrlCreateLabel('SSH klíč:', 20, 116 + $i*135, 90, 21)
	$network[$i][7] = GUICtrlCreateInput(Json_ObjGet($conf, '.network.[' & $i & '].key'), 68, 112 + $i*135, 262, 21)
	$network[$i][8] = GUICtrlCreateButton('Procházet', 334, 112 + $i*135, 75, 21)
	$network[$i][9] = GUICtrlCreateLabel('NAS prefix:', 20, 140 + $i*135, 60, 21)
	$network[$i][10] = GUICtrlCreateInput(Json_ObjGet($conf, '.network.[' & $i & '].prefix'), 220, 136 + $i*135, 110, 21)
next
; GUI - SETUP
$gui_tab_setup = GUICtrlCreateTabItem('Nastavení')
$gui_group_setup = GUICtrlCreateGroup('', 12, 28, 606, 66)
$gui_group_setup_blank = GUICtrlCreateGroup('', 12, 94, 606, 204)
$gui_setup_debug_label = GUICtrlCreateLabel('Režim ladění:', 20, 46, 80, 21)
$gui_setup_debug_check = GUICtrlCreateCheckbox('', 240, 40, 16, 21)
GUICtrlSetState($gui_setup_debug_check, Json_ObjGet($conf, '.setup.debug'))
$gui_setup_pwd_label = GUICtrlCreateLabel('Režim správce:', 20, 68, 150, 21)
$gui_setup_pwd = GUICtrlCreateInput('', 240, 64, 90, 21, BitOR(0x0020,0x0001)); ES_PASSWORD
$gui_setup_button_pwd = GUICtrlCreateButton('Povolit', 334, 64, 75, 21)

$gui_tab_end = GUICtrlCreateTabItem('')
$gui_error = GUICtrlCreateLabel('', 10, 318, 298, 21)
$gui_button_run = GUICtrlCreateButton('Spustit', 394, 314, 75, 21)
$gui_button_break = GUICtrlCreateButton('Přerušit', 472, 314, 75, 21)
$gui_button_exit = GUICtrlCreateButton('Storno', 550, 314, 75, 21)

; set default focus
GUICtrlSetState($gui_button_exit, $GUI_FOCUS)

; set default mode
admin_mode($admin)

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
			GUICtrlSetData($gui_setup_pwd, '')
		endif
	endif
	; debug mode
	if GUICtrlRead($gui_setup_debug_check) = $GUI_CHECKED then
		$debug = True
	else
		$debug = False
	endif
	; select remote source
;	$browse = _ArrayBinarySearch($remote, $event, Default, Default, 2); 2'nd column
;	if not @error then
;		$path = FileSelectFolder('NAS ' & $version & ' - Zdrojový adresář', @HomeDrive)
;		if not @error then GUICtrlSetData($remote[$browse][1], $path)
;	endif
	; exit
	if $event = $GUI_EVENT_CLOSE or $event = $gui_button_exit then
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
