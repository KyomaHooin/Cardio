;

; Secure Rsync Win64 GUI
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

#AutoIt3Wrapper_Res_Description=NAS Rsync GUI
#AutoIt3Wrapper_Res_ProductName=NAS
#AutoIt3Wrapper_Res_ProductVersion=1.2
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

; ---------------------------------------------------------
;VAR
; ---------------------------------------------------------

global $version = '1.2'
global $ini = @ScriptDir & '\NAS.ini'
global $configuration[0][2]

global $rsync_binary = @ScriptDir & '\bin\rsync.exe'
global $ssh_binary = @ScriptDir & '\bin\ssh.exe'

global $key = @ScriptDir & '\key\id_ed25519'
global $remote_user = 'backup'
global $remote_host = '10.8.0.1'
global $remote_port = '22'
global $remote_prefix = '/volume1/DATA/'

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
	FileWriteLine($f, 'dir1=')
	FileWriteLine($f, 'dir2=')
	FileWriteLine($f, 'dir3=')
	FileWriteLine($f, 'dir4=')
	FileWriteLine($f, 'dir5=')
	FileWriteLine($f, 'dir6=')
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

$gui = GUICreate('NAS Záloha ' & $version, 574, 234, Default, Default)
$gui_group1 = GUICtrlCreateGroup('', 5, 0, 564, 68)
$gui_label_source1 = GUICtrlCreateLabel('Zdroj:', 12, 18, 30, 21)
$gui_input_source1 = GUICtrlCreateInput($configuration[_ArrayBinarySearch($configuration,'dir1')][1], 42, 15, 438, 21)
$gui_button_source1 = GUICtrlCreateButton("Procházet", 486, 15, 75, 21)
$gui_label_target1 = GUICtrlCreateLabel('Cíl:', 22, 42, 30, 21)
$gui_input_target1 = GUICtrlCreateInput($configuration[_ArrayBinarySearch($configuration,'dir2')][1], 42, 38, 438, 21)

$gui_group2 = GUICtrlCreateGroup('', 5, 68, 564, 68)
$gui_label_source2 = GUICtrlCreateLabel('Zdroj:', 12, 86, 30, 21)
$gui_input_source2 = GUICtrlCreateInput($configuration[_ArrayBinarySearch($configuration,'dir3')][1], 42, 83, 438, 21)
$gui_button_source2 = GUICtrlCreateButton('Procházet', 486, 82, 75, 21)
$gui_label_target2 = GUICtrlCreateLabel('Cíl:', 22, 110, 30, 21)
$gui_input_target2 = GUICtrlCreateInput($configuration[_ArrayBinarySearch($configuration,'dir4')][1], 42, 106, 438, 21)

$gui_group3 = GUICtrlCreateGroup('', 5, 136, 564, 68)
$gui_label_source3 = GUICtrlCreateLabel('Zdroj:', 12, 154, 30, 21)
$gui_input_source3 = GUICtrlCreateInput($configuration[_ArrayBinarySearch($configuration,'dir5')][1], 42, 150, 438, 21)
$gui_button_source3 = GUICtrlCreateButton('Procházet', 486, 150, 75, 21)
$gui_label_target3 = GUICtrlCreateLabel('Cíl:', 22, 176, 30, 21)
$gui_input_target3 = GUICtrlCreateInput($configuration[_ArrayBinarySearch($configuration,'dir6')][1], 42, 172, 438, 21)

$gui_button_backup = GUICtrlCreateButton('Zálohovat', 412, 208, 75, 21)
$gui_button_exit = GUICtrlCreateButton('Konec', 492, 208, 75, 21)

; set default focus
GUICtrlSetState($gui_button_exit, $GUI_FOCUS)

GUISetState(@SW_SHOW)

; ---------------------------------------------------------
; MAIN
; ---------------------------------------------------------

while 1
	$event = GUIGetMsg()
	; source/target selection
	if $event = $gui_button_source1 Then
		$path = FileSelectFolder('NAS Záloha ' & $version & ' - Zdrojový adresář', @HomeDrive)
		if not @error then GUICtrlSetData($gui_input_source1, $path)
	endif
	if $event = $gui_button_source2 Then
		$path = FileSelectFolder('NAS Záloha ' & $version & ' - Zdrojový adresář', @HomeDrive)
		if not @error then GUICtrlSetData($gui_input_source2, $path)
	endif
	if $event = $gui_button_source3 Then
		$path = FileSelectFolder('NAS Záloha ' & $version & ' - Zdrojový adresář', @HomeDrive)
		if not @error then GUICtrlSetData($gui_input_source3, $path)
	endif
	; backup
	if $event = $gui_button_backup then
		; disable button
		GUICtrlSetState($gui_button_backup, $GUI_DISABLE)
		; backup
		if FileExists(GUICtrlRead($gui_input_source1)) then
			logger('[1] Zálohovaní zahájeno.')
			rsync(get_cygwin_path(GUICtrlRead($gui_input_source1)),StringRegExpReplace(GUICtrlRead($gui_input_target1), '\\', '\/'))
			logger('[1] Zalohování dokončeno.')
		else
			logger('[1] Chyba: Zdrojový, nebo cílový adresář neexistuje.')
		endif
		;if FileExists(GUICtrlRead($gui_input_source2)) and FileExists(GUICtrlRead($gui_input_target2)) then
		;	logger('[2] Zálohovaní zahájeno.')
		;	rsync(get_cygwin_path(GUICtrlRead($gui_input_source2)),get_cygwin_path(GUICtrlRead($gui_input_target2)))
		;	logger('[2] Zalohování dokončeno.')
		;else
		;	logger('[2] Chyba: Zdrojový, nebo cílový adresář neexistuje.')
		;endif
		;if FileExists(GUICtrlRead($gui_input_source3)) and FileExists(GUICtrlRead($gui_input_target3)) then
		;	logger('[3] Zálohovaní zahájeno.')
		;	rsync(get_cygwin_path(GUICtrlRead($gui_input_source3)),get_cygwin_path(GUICtrlRead($gui_input_target3)))
		;	logger('[3] Zalohování dokončeno.')
		;else
		;	logger('[3] Chyba: Zdrojový, nebo cílový adresář neexistuje.')
		;endif
		; enable button
		GUICtrlSetState($gui_button_backup, $GUI_ENABLE)
	endif
	; exit
	if $event = $GUI_EVENT_CLOSE or $event = $gui_button_exit then
		; write configuration
		$f = FileOpen($ini, 2); overwrite
		FileWriteLine($ini, 'dir1=' & GUICtrlRead($gui_input_source1))
		FileWriteLine($ini, 'dir2=' & GUICtrlRead($gui_input_target1))
		FileWriteLine($ini, 'dir3=' & GUICtrlRead($gui_input_source2))
		FileWriteLine($ini, 'dir4=' & GUICtrlRead($gui_input_target2))
		FileWriteLine($ini, 'dir5=' & GUICtrlRead($gui_input_source3))
		FileWriteLine($ini, 'dir6=' & GUICtrlRead($gui_input_target3))
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
	$cygwin_path = StringRegExpReplace($path , '\\', '\/'); convert backslash -> slash
	$cygwin_path = StringRegExpReplace($cygwin_path ,'^(.)\:(.*)', '\/cygdrive\/$1$2'); convert drive colon
	return StringRegExpReplace($cygwin_path ,'(.*)', '$1'); catch space by doublequote
endfunc

func rsync($source,$target)
	$gui_rsync = GUICreate("NAS Záloha - Rsync 3.1.2", 625, 320, Default, Default)
	$gui_rsync_edit = GUICtrlCreateEdit("", 8, 8, 609, 305, BitOR($ES_AUTOVSCROLL,$ES_READONLY,$ES_WANTRETURN,$WS_VSCROLL))
	; show RSync
	GUISetState(@SW_SHOW, $gui_rsync)
	;return
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
	; progress
	while ProcessExists($rsync)
		$out_buffer = StringReplace(StdoutRead($rsync), @LF, @CRLF)
		if $out_buffer <> '' then GUICtrlSetData($gui_rsync_edit, GUICtrlRead($gui_rsync_edit) & $out_buffer)
		$err_buffer = StringReplace(StderrRead($rsync), @LF, @CRLF)
		if $err_buffer <> '' then GUICtrlSetData($gui_rsync_edit, GUICtrlRead($gui_rsync_edit) & $err_buffer)
		_GUICtrlEdit_Scroll($gui_rsync_edit, 4); scroll down
	wend
	; logging
	logger(GUICtrlRead($gui_rsync_edit))
	; destroy GUI
	GUIDelete($gui_rsync)
	;exit
	return
EndFunc
