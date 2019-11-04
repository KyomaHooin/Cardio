;
; SSH Rsync backup WIN -> NAS GUI Setup
;

#AutoIt3Wrapper_Icon=NASBackup.ico
#NoTrayIcon

;INCLUDE

#include <File.au3>
#include <Array.au3>
#include <GUIConstantsEx.au3>

;VAR

$version = '1.3'
$ini = @ScriptDir & '\NASBackup.ini'

global $configuration[0][2]
global $component[3][4]

;CONTROL

; one instance
if UBound(ProcessList(@ScriptName)) > 2 then
	MsgBox(48, 'NAS Záloha v ' & $version, 'Program byl již spuštěn. [R]')
	exit
endif
; 64-bit only
;if @OSArch <> 'X64' then
;	MsgBox(48, 'NAS Záloha v ' & $version, 'Tento systém není podporován. [x64]')
;	exit
;endif
; logging
$log = FileOpen(@ScriptDir & '\' & 'NASBackup.log', 1)
if @error then
	MsgBox(48, 'NAS Záloha v ' & $version, 'System je připojen pouze pro čtení. [RO]')
	exit
endif

; INIT

logger('Program begin: ' & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)
; read configuration
if not FileExists($ini) then
	$f = FileOpen($ini, 1)
	FileWriteLine($f, 'dir1=')
	FileWriteLine($f, 'dir2=')
	FileWriteLine($f, 'dir3=')
	FileWriteLine($f, 'user=')
	FileWriteLine($f, 'remote=')
	FileWriteLine($f, 'port=')
	FileWriteLine($f, 'target=')
	FileWriteLine($f, 'key=')
	FileWriteLine($f, 'local=')
	FileWriteLine($f, 'default=0')
	FileClose($f)
endif
_FileReadToArray($ini, $configuration, 0, '='); 0-based
if @error or UBound($configuration) <> 10 then
	logger('Načtení konfiguračního INI souboru selhalo.')
	exit
else
	logger("Konfigurační INI soubor byl načten.")
endif

; GUI

$gui = GUICreate('NAS Záloha v ' & $version, 488, 140, Default, Default)

for $i = 0 to 2
	$component[$i][0] = GUICtrlCreateLabel('Adresář:', 8, 14 + $i * 33, 44, 17); text
	$component[$i][1] = GUICtrlCreateInput($configuration[$i][1], 52, 10 + $i * 33, 345, 21); dir
	$component[$i][2] = GUICtrlCreateButton('Procházet', 406, 8 + $i * 33, 75, 25); select
next

$gui_error = GUICtrlCreateLabel('', 8, 113, 218, 17)
$gui_button_backup = GUICtrlCreateButton('Zálohovat', 238, 107, 75, 25)
$gui_button_config = GUICtrlCreateButton('Nastavení', 322, 107, 75, 25)
$gui_button_exit = GUICtrlCreateButton('Konec', 406, 107, 75, 25)

; set default focus
GUICtrlSetState($gui_button_exit, $GUI_FOCUS)

GUISetState(@SW_SHOW)

; MAIN

while 1
	$event = GUIGetMsg()
	; update directory intput
	for $i = 0 to 2
		if $event = $component[$i][2] then
			$dir_input = FileSelectFolder('Adresář', @HomeDrive)
			GUICtrlSetData($component[$i][1], $dir_input)
			$configuration[$i][1] = $dir_input
		endif
	next
	; NAS config
	if $event = $gui_button_config then nas_gui()
	; backup
	if $event = $gui_button_backup then
		logger('Zahájeno zálohovaní..')
		; reset error
		GUICtrlSetData($gui_error,'')
		; check input
		if $configuration[get_index('default')][1] = 0 and $configuration[get_index('user')][1] == '' then
			GUICtrlSetData($gui_error, 'E: Neplatný uživatel.')
		elseif $configuration[get_index('default')][1] = 0 and not StringRegExp($configuration[get_index('remote')][1], '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') then
			GUICtrlSetData($gui_error, 'E: Neplatná IP adresa.')
		elseif $configuration[get_index('default')][1] = 0 and Int($configuration[get_index('port')][1]) > 65535 then
			GUICtrlSetData($gui_error, 'E: Neplatné číslo portu.')
		elseif $configuration[get_index('default')][1] = 0 and not StringRegExp($configuration[get_index('port')][1], '^\d{1,5}$') then
			GUICtrlSetData($gui_error, 'E: Neplatné číslo portu.')
		elseif $configuration[get_index('default')][1] = 0 and $configuration[get_index('target')][1] == '' then
			GUICtrlSetData($gui_error, 'E: Neplatný cílový adresář.')
		elseif $configuration[get_index('default')][1] = 0 and not FileExists($configuration[get_index('key')][1]) then
			GUICtrlSetData($gui_error, 'E: Klíč neexistuje.')
		elseif $configuration[get_index('default')][1] = 1 and not FileExists($configuration[get_index('local')][1]) then
			GUICtrlSetData($gui_error, 'E: Cílový adresář neexistuje.')
		else
			; disable backup button
			GUICtrlSetState($gui_button_backup, $GUI_DISABLE)
			; clear error label
			GUICtrlSetData($gui_error,'')
			; backup
			for $i = 0 to 2
				if GUICtrlRead($component[$i][1]) <> '' then
					if FileExists(GUICtrlRead($component[$i][1])) then
						; verbose logging..
						GUICtrlSetData($gui_error, 'Probíhá zálohování adresáře ' & $i + 1 & ' ..')
						; disable input
						GUICtrlSetState($component[$i][1], $GUI_DISABLE)
						if $configuration[get_index('default')][1] = 0 then
							$cygwin_src_path = get_cygpwin_path(GUICtrlRead($component[$i][1]))
							;remote rsync
							$rsync = RunWait(@ComSpec & ' /c ' & 'rsync.exe -avz -e ' _
								& "'" & 'ssh.exe -o "StrictHostKeyChecking no" -p ' _
								& $configuration[get_index('port')][1] & ' -i ' _
								& '"' & $configuration[get_index('key')][1] & '"' & "' " _
								& "'" & $cygwin_src_path & "'" & ' ' _
								& $configuration[get_index('user')][1] & '@' _
								& $configuration[get_index('remote')][1] & ':' _
								& $configuration[get_index('target')][1] _
								& ' > rsync.log 2> error.log' _
								, @ScriptDir & '\cygwin', @SW_HIDE)
						ElseIf $configuration[get_index('default')][1] = 1 then
							$cygwin_src_path = get_cygpwin_path(GUICtrlRead($component[$i][1]))
							$cygwin_dst_path = get_cygpwin_path($configuration[get_index('local')][1])
							;local rsync
							$rsync = RunWait(@ComSpec & ' /c ' & 'rsync.exe -avz ' _
								& "'" &  $cygwin_src_path & "'" & ' ' _
								& "'" & $cygwin_dst_path & "'" _
								& ' > rsync.log 2> error.log' _
								, @ScriptDir & '\cygwin', @SW_HIDE)
						endif
						; enable input
						GUICtrlSetState($component[$i][1], $GUI_ENABLE)
						; logging
						if FileGetSize(@ScriptDir & '\cygwin\rsync.log') > 0 then
							GUICtrlSetData($gui_error, 'Záloha adresáře ' & $i + 1 & ' dokončena.')
							logger('Adresář ' & GUICtrlRead($component[$i][1]) & ' byl zálohován.')
						elseif FileGetSize(@ScriptDir & '\cygwin\error.log') > 0 then
							GUICtrlSetData($gui_error, 'Zálohování adresáře ' & $i + 1 & ' selhalo.')
							logger('Zálohovaní adresáře ' & GUICtrlRead($component[$i][1]) & ' selhalo.')
						endif
					else
						GUICtrlSetData($gui_error, 'E: Adresář ' & $i + 1 & ' neexistuje.')
						exitloop
					endif
				endif
			next
			; enable backup button
			GUICtrlSetState($gui_button_backup, $GUI_ENABLE)
		endif
		logger('Zalohování dokončeno.')
	endif
	; exit
	if $event = $GUI_EVENT_CLOSE or $event = $gui_button_exit then
		; update configuration
		for $i = 0 to 2
			$configuration[$i][1] = GUICtrlRead($component[$i][1])
		next
		; write configuration
		$f = FileOpen($ini, 2); overwrite
		for $i = 0 to ubound($configuration) - 1
			FileWriteLine($ini, $configuration[$i][0] & '=' & $configuration[$i][1])
		next
		FileClose($f)
		; exit
		exitloop
	endif
wend

; exit
logger('Program exit: ' & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)
logger('------------------------------------')
FileClose($log)
exit

; FUNC

func logger($text)
	FileWriteLine($log, $text)
endfunc

func get_cygpwin_path($path)
	$cygwin_path = StringRegExpReplace($path , '\\', '\/'); convert backslash -> slash
	$cygwin_path = StringRegExpReplace($cygwin_path ,'^(.)\:(.*)', '\/cygdrive\/$1$2'); convert drive colon
	return StringRegExpReplace($cygwin_path ,'(.*)', '$1'); catch space by doublequote
endfunc

func get_index($variable)
	return _ArraySearch($configuration, $variable, 0, 0, 0, 1)
endfunc

func nas_gui()
	global $nas_gui = GUICreate('NAS Záloha v ' & $version & ' - Konfigurace', 346, 310, Default, Default)
	global $nas_gui_remote_group = GUICtrlCreateGroup('', 10, 8, 327, 185)
	global $nas_gui_remote = GUICtrlCreateRadio('Vzdálená záloha', 24, 8, 100, 17)
	global $nas_gui_user = GUICtrlCreateLabel('Uživatel:', 18, 32, 45, 17)
	global $nas_gui_user_input = GUICtrlCreateInput($configuration[get_index('user')][1], 276, 28, 49, 21, 0x0001); align center
	global $nas_gui_ip = GUICtrlCreateLabel('IP Adresa:', 18, 58, 53, 17)
	global $nas_gui_ip_input = GUICtrlCreateInput($configuration[get_index('remote')][1], 236, 54, 89, 21, 0x0001); align center
	global $nas_gui_port = GUICtrlCreateLabel('Port:', 18, 84, 29, 17)
	global $nas_gui_port_input = GUICtrlCreateInput($configuration[get_index('port')][1], 276, 80, 49, 21, 0x0001); align center
	global $nas_gui_remote_target = GUICtrlCreateLabel('Cíl:', 18, 110, 18, 17)
	global $nas_gui_remote_target_input = GUICtrlCreateInput($configuration[get_index('target')][1], 188, 106, 137, 21)
	global $nas_gui_key = GUICtrlCreateLabel('Klíč:', 18, 160, 21, 17)
	global $nas_gui_key_input = GUICtrlCreateInput($configuration[get_index('key')][1], 46, 158, 194, 21)
	global $nas_gui_key_button = GUICtrlCreateButton('Procházet', 250, 156, 75, 25)
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	global $nas_gui_local_group = GUICtrlCreateGroup('', 10, 205, 327, 61)
	global $nas_gui_local = GUICtrlCreateRadio('Lokální záloha', 24, 205, 90, 17)
	global $nas_gui_local_target = GUICtrlCreateLabel('Cíl:', 18, 233, 18, 17)
	global $nas_gui_local_target_input = GUICtrlCreateInput($configuration[get_index('local')][1], 46, 229, 194, 21)
	global $nas_gui_local_target_button = GUICtrlCreateButton('Procházet', 250, 228, 75, 25)
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	global $nas_gui_save_button = GUICtrlCreateButton('OK', 178, 276, 75, 25)
	global $nas_gui_exit_button = GUICtrlCreateButton('Storno', 262, 276, 75, 25)

	;set remote by default
	if $configuration[get_index('default')][1] = 0 then
		GUICtrlSetState($nas_gui_remote, $GUI_CHECKED)
		set_default_target($GUI_ENABLE, $GUI_DISABLE)
	else
		GUICtrlSetState($nas_gui_local, $GUI_CHECKED)
		set_default_target($GUI_DISABLE, $GUI_ENABLE)
	endif
	; set default focus
	GUICtrlSetState($nas_gui_exit_button, $GUI_FOCUS)

	GUISetState(@SW_SHOW, $nas_gui)

	while 1
		$nas_event = GUIGetMsg($nas_gui)

		if $nas_event = $nas_gui_key_button then
			GUICtrlSetData($nas_gui_key_input, FileOpenDialog('Privátní klíč', @HomeDrive, 'Key file (*.*)'))
		endif
		if $nas_event = $nas_gui_local_target_button then
			GUICtrlSetData($nas_gui_local_target_input, FileSelectFolder('Adresář', @HomeDrive))
		endif
		if $nas_event = $nas_gui_remote and GUICtrlRead($nas_gui_remote) = $GUI_CHECKED then
			GUICtrlSetState($nas_gui_local,$GUI_UNCHECKED)
			set_default_target($GUI_ENABLE, $GUI_DISABLE)
		endif
		if $nas_event = $nas_gui_local and GUICtrlRead($nas_gui_local) = $GUI_CHECKED then
			GUICtrlSetState($nas_gui_remote,$GUI_UNCHECKED)
			set_default_target($GUI_DISABLE, $GUI_ENABLE)
		endif
		if $nas_event = $nas_gui_save_button then
			$configuration[get_index('user')][1] = GUICtrlRead($nas_gui_user_input)
			$configuration[get_index('remote')][1] = GUICtrlRead($nas_gui_ip_input)
			$configuration[get_index('port')][1] = GUICtrlRead($nas_gui_port_input)
			$configuration[get_index('target')][1] = GUICtrlRead($nas_gui_remote_target_input)
			$configuration[get_index('key')][1] = GUICtrlRead($nas_gui_key_input)
			$configuration[get_index('local')][1] = GUICtrlRead($nas_gui_local_target_input)
			if GUICtrlRead($nas_gui_local) = $GUI_CHECKED then
				$configuration[get_index('default')][1] = 1
			else
				$configuration[get_index('default')][1] = 0
			endif
			logger('Konfigurační INI soubor byl aktualizován.')
			exitloop
		endif
		if $nas_event = $GUI_EVENT_CLOSE or $nas_event = $nas_gui_exit_button then exitloop
	wend
	GUIDelete($nas_gui)
endfunc

func set_default_target($remote_state, $local_state)
	;set remote
	GUICtrlSetState($nas_gui_user_input, $remote_state)
	GUICtrlSetState($nas_gui_ip_input, $remote_state)
	GUICtrlSetState($nas_gui_port_input, $remote_state)
	GUICtrlSetState($nas_gui_remote_target_input, $remote_state)
	GUICtrlSetState($nas_gui_key_input, $remote_state)
	GUICtrlSetState($nas_gui_key_button, $remote_state)
	;set local
	GUICtrlSetState($nas_gui_local_target_input, $local_state)
	GUICtrlSetState($nas_gui_local_target_button, $local_state)
endfunc
