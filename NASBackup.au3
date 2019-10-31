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

$ini = @ScriptDir & '\' & 'NASBackup.ini
$rsync = @ScriptDir & '\cygwin\' & 'rsync.exe'
$ssh = @ScriptDir & '\cygwin\' & 'ssh.exe'

global $configuration[2][0], $component[4][10], $dirlist

;CONTROL

; one instance
if UBound(ProcessList(@ScriptName)) > 2 then
	MsgBox(48, "NAS Záloha - Kardio Jan Skoda v1.0","Program byl jiz spusten. [R]")
	exit
endif
; 64-bit only
;if @OSArch <> 'X64' then
;	MsgBox(48, "NAS Záloha - Kardio Jan Skoda v1.0","Tento system není podporován. [x64]")
;	exit
;endif
; logging
$log = FileOpen(@ScriptDir & '\' & 'NASBackup.log', 1)
if @error then
	MsgBox(48, "NAS Záloha - Kardio Jan Skoda v1.0","System je pripojen pouze pro cteni. [RO]")
	exit
endif

; INIT

logger("Program begin: " & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)
; read configuration
if not FileExists($ini) then
	$f = FileOpen($ini, 1)
	FileWriteLine($f, '[dir1]')
	FileWriteLine($f, '[user]')
	FileWriteLine($f, '[remote]')
	FileWriteLine($f, '[port]')
	FileWriteLine($f, '[target]')
	FileWriteLine($f, '[key]')
	FileClose($f)
endif
_FileReadToArray($ini, $configuration, 0, ' '); 0-based space split
_ArrayDisplay($configuration); DEBUG
logger("Configuration INI loaded.")
; dirlist count
for $i = 0 to ubound($configuration) - 1
	if StringRegExp($configuration[$i][0], '^[dir.*') then $dirlist += 1
next

; GUI

$gui = GUICreate("NAS Záloha - Kardio Jan Skoda v1.0", 527, 74 + $dirlist * 32, Default, Default)

for $i = 0 to $dirlist - 1
	$component[$i][0] = GUICtrlCreateLabel("Adresar:", 8, 14 + $i * 32, 44, 17); text
	$component[$i][1] = GUICtrlCreateInput($configuration[$i][1], 52, 10 + $i * 32, 345, 21); dir
	$component[$i][2] = GUICtrlCreateButton("Prochazet", 408, 8 + $i * 32, 75, 25); select
	$component[$1][3] = GUICtrlCreateButton("+", 500, 8 + $i * 32, 25, 25); add
next

$gui_button_config = GUICtrlCreateButton("NAS", 8, 14 + $dirlist * 32, 25, 25)
$gui_progress = GUICtrlCreateProgress(130, 14 + $dirlist * 32, 352, 16)
$gui_error = GUICtrlCreateLabel("", 8, 44 + $dirlist * 32, 136, 17)
$gui_button_backup = GUICtrlCreateButton("Zálohovat", 320, 40  + $dirlist * 32, 75, 25)
$gui_button_exit = GUICtrlCreateButton("Konec", 408, 40 + $dirlist * 32, 75, 25)

GUISetState(@SW_SHOW)

; MAIN

while 1
	$event = GUIGetMsg()
	
	; update directory intput
	for $i = 0 to $dirlist - 1
		if $event = $component[$i][2] then
			$dir_input = FileSelectFolder("Adresar", @HomeDrive)
			GUICtrlSetData($component[$i][$2], $dir_input)
			$configuration[$i][1] = $dir_input
		endif
	next
	; add directory & update dirlist
	for $i = 0 to $dirlist - 1
		if $event = $component[$i][3] and $dirlist < 10 then
			update_gui($configuration, $dirlist)
			$dirlist += 1
		endif
	next
	; NAS config
	if $event = $gui_button_config then nas_gui()
	; backup
	if $event = $gui_button_backup then
		logger("Backup begin.")
		; reset error
		GUICtrlSetData($gui_error,'')
		; reset progress
		GUICtrlSetData($gui_progress, 0)
		; check input
		if $configuration[get_index('user')][1] == '' then
			GUICtrlSetData($gui_error, "E: Neplatny uzivatel.")
		elseif not StringRegExp($configuration[get_index('remote')][1], '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}) then
			GUICtrlSetData($gui_error, "E: Neplatna IP adresa.")
		elseif not StringRegExp($configuration[get_index('port')][1], '\d{1,5}') then
			GUICtrlSetData($gui_error, "E: Neplatne cislo portu.")
		elseif $configuration[get_index('target')][1] == '' then
			GUICtrlSetData($gui_error, "E: Neplatny cilovy adresar.")
		elseif not FileExists($configuration[get_index('key')][1]) then
			GUICtrlSetData($gui_error,"E: Klic neexistuje.")
		else
			; disable backup button
			GUICtrlSetState($gui_button_backup,$GUI_DISABLE)
			; backup
			for $i = 0 to $dirlist - 1
				if GUICtrlRead($component[$i][1] <> '' then
					if FileExists(GUICtrlRead($component[$i][1]) then
						; disable input
						GUICtrlSetState($component[$i][1], $GUI_DISABLE)
						; rsync
						RunWait($rsync & ' -az -e "' & $ssh & ' -o "StrictHostKeyChecking no" -p ' &_
						$configuration[get_index('port')][1] & ' -i ' &_
						$configuration[get_index('key')][1] & '" '&_
						GUICtrlRead($component[$i][1] & ' ' &_
						$configuration[get_index('user')][1] & '@' &_
						$configuration[get_index('remote')][1] & ':/' &_
						$configuration[get_index('target')][1])
						; update progress
						GUICtrlSetData($gui_progress, round(($i + 1) * 100/ $dirlist))
						; enable input
						GUICtrlSetState($component[$i][1], $GUI_ENABLE)
						; logging
						logger("Adresar " & $i + 1 & " byl zalohovan!")
					else
						GUICtrlSetData($gui_error, 'E: Adresar [' & $i & '] neexistuje.')
						exitloop
					endif
				endif
			next
			; enable backup button
			GUICtrlSetState($gui_button_backup,$GUI_ENABLE)
		endif
		logger("Backup end.")
	endif
	; exit
	If $event = $GUI_EVENT_CLOSE or $event = $gui_button_exit then
		; update configuration
		for $i = 0 to $dirlist - 1
			if GUICtrlRead($component[$i][1] <> '' then
				if get_index('dir' & $i) then
					$configuration[$i][1] = GUICrtlRead($component[$i][1])
				else
					_ArrayInsert($configuration, $i, '[dir' & $i & '] ' & GUICtrlRead($component[$i][1]), ' ')
				endif
			endif
		next
		; write configuration
		$f = FileOpen($ini, 2); overwrite
		for $i = 0 to ubound($configuration) - 1
			FileWriteLine($ini, $configuration[$i][0] & ' ' & $configuration[$i][1])
		next
		FileClose($f)
		; exit
		exitloop
	endif
wend

; exit
logger("Program exit: " & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)
logger("------------------------------------")
FileClose($log)
exit

; FUNC

func logger($text)
	FileWriteLine($log, $text)
endfunc

func get_index($variable)
	return _ArraySearch($configuration, '[' & $variable & ']', 0, 0, 0, 1)
endfunc

func update_gui($configuration, $dirlist)
	; resize gui
	WinMove($gui, Default, Default, Default, Default, 74 + ($dirlist + 1) * 32)
	; add dir
	$component[$dirlist][0] = GUICtrlCreateLabel("Adresar:", 8, 14 + ($dirlist + 1) * 32, 44, 17); text
	$component[$dirlist][1] = GUICtrlCreateInput('', 52, 10 + ($dirlist + 1) * 32, 345, 21); dir
	$component[$dirlist][2] = GUICtrlCreateButton("Prochazet", 408, 8 + ($dirlist + 1) * 32, 75, 25); select
	$component[$dirlist][3] = GUICtrlCreateButton("+", 500, 8 + ($dirlist + 1) * 32, 25, 25); add
	; move components
	ControlMove($gui, Defaulat, $gui_button_config, Default, 14 + ($dirlist + 1) * 32)
	ControlMove($gui, Defaulat, $gui_progress, Default, 14 + ($dirlist + 1) * 32)
	ControlMove($gui, Defaulat, $gui_error, Default, 44 + ($dirlist + 1) * 32)
	ControlMove($gui, Defaulat, $gui_button_backup, Default, 40 + ($dirlist + 1) * 32)
	ControlMove($gui, Defaulat, $gui_button_exit, Default, 40 + ($dirlist + 1) * 32)
endfunc

func nas_gui()
	$nas_gui = GUICreate("NAS Záloha - Konfigurace NAS", 400, 150, Default, Default)
	$nas_gui_user_label = GUICtrlCreateLabel("Uzivatel:", 8, 10, 32, 40)
	$nas_gui_user_input = GUICtrlCreateInput($configuration[get_index('user')][1], 50, 10 , 32, 40)
	$nas_gui_remote_label = GUICtrlCreateLabel("NAS IP:", 100, 10, 32, 40)
	$nas_gui_remote_input = GUICtrlCreateInput($configuration[get_index('remote')][1], 150, 10, 32, 100)
	$nas_gui_port_label = GUICtrlCreateLabel("Port",260, 10, 32, 20)
	$nas_gui_port_input = GUICtrlCreateInput($configuration[get_index('port')][1], 285, 10, 32, 20)
	$nas_gui_target_label = GUICtrlCreateLabel("Cil:",305, 10, 32, 20)
	$nas_gui_target_input = GUICtrlCreateInput($configuration[get_index('target')][1], 330, 10, 32, 40)
	$nas_gui_key_label = GUICtrlCreateLabel("Klic:", 8, 42, 32 , 40)
	$nas_gui_key_input = GUICtrlCreateInput($configuration[get_index('key')][1], 50, 42, 32, 150)
	$nas_gui_key_button = GUICtrlCreateButton("Prochazet", 210, 42, 75, 25)
	$nas_gui_error = GUICtrlCreateLabel('', 8, 74, 32 , 150)
	$nas_gui_save_button = GUICtrlCreateButton("Ulozit", 225, 74, 75, 25)
	$nas_gui_exit_button = GUICtrlCreateButton("Konec", 300, 74, 75, 25)

	GUISetState(@SW_SHOW, $nas_gui)

	while 1
		$event = GUIGetMsg($nas_gui)

		if $event = $gui_key_button then
			GUICtrlSetData($nas_gui_key_input, FileSelectFolder("Adresar", @HomeDrive))
		endif
		if $event = $gui_save_button then
			$configuration[get_index('user')][1] = GUICtrlRead($nas_gui_user_input)
			$configuration[get_index('remote')][1] = GUICtrlRead($nas_gui_remote_input)
			$configuration[get_index('port')][1] = GUICtrlRead($nas_gui_port_input)
			$configuration[get_index('target')][1] = GUICtrlRead($nas_gui_target_input)
			$configuration[get_index('key')][1] = GUICtrlRead($nas_gui_key_input)
			logger("Konfigurace byla aktualizovana.")
			exitloop
		endif
		if $event = $GUI_EVENT_CLOSE or $event = $gui_exit_button then exitloop
	wend
	GUIDelete($nas_gui)
endfunc

