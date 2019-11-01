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

$ini = @ScriptDir & '\' & 'NASBackup.ini'
$rsync = @ScriptDir & '\cygwin\' & 'rsync.exe'
$ssh = @ScriptDir & '\cygwin\' & 'ssh.exe'

global $configuration[0][2]
global $component[3][4]

;CONTROL

; one instance
if UBound(ProcessList(@ScriptName)) > 2 then
	MsgBox(48, "NAS Z�loha - Kardio Jan Skoda v1.0","Program byl jiz spusten. [R]")
	exit
endif
; 64-bit only
;if @OSArch <> 'X64' then
;	MsgBox(48, "NAS Z�loha - Kardio Jan Skoda v1.0","Tento system nen� podporov�n. [x64]")
;	exit
;endif
; logging
$log = FileOpen(@ScriptDir & '\' & 'NASBackup.log', 1)
if @error then
	MsgBox(48, "NAS Z�loha - Kardio Jan Skoda v1.0","System je pripojen pouze pro cteni. [RO]")
	exit
endif

; INIT

logger("Program begin: " & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)
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
	FileClose($f)
endif
_FileReadToArray($ini, $configuration, 0, '='); 0-based
if @error or UBound($configuration) <> 8 then
	logger("Nacteni konfigurace selhalo.")
	exit
else
	logger("Configuration INI loaded.")
endif

; GUI

$gui = GUICreate('NAS Z�loha - Kardio Jan Skoda v1.0', 488, 173, Default, Default)

for $i = 0 to 2
	$component[$i][0] = GUICtrlCreateLabel('Adresar:', 8, 14 + $i * 33, 44, 17); text
	$component[$i][1] = GUICtrlCreateInput($configuration[$i][1], 52, 10 + $i * 33, 345, 21); dir
	$component[$i][2] = GUICtrlCreateButton('Prochazet', 406, 8 + $i * 33, 75, 25); select
next

$gui_button_config = GUICtrlCreateButton('Nastaveni', 8, 107, 75, 25)
$gui_progress = GUICtrlCreateProgress(94, 111, 385, 16)
$gui_error = GUICtrlCreateLabel('ERROR', 8, 146, 270, 17)
$gui_button_backup = GUICtrlCreateButton('Z�lohovat', 322, 140, 75, 25)
$gui_button_exit = GUICtrlCreateButton('Konec', 406, 140, 75, 25)

GUISetState(@SW_SHOW)

; MAIN

while 1
	$event = GUIGetMsg()
	; update directory intput
	for $i = 0 to 2
		if $event = $component[$i][2] then
			$dir_input = FileSelectFolder("Adresar", @HomeDrive)
			GUICtrlSetData($component[$i][1], $dir_input)
			$configuration[$i][1] = $dir_input
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
		elseif not StringRegExp($configuration[get_index('remote')][1], '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') then
			GUICtrlSetData($gui_error, "E: Neplatna IP adresa.")
		elseif not StringRegExp($configuration[get_index('port')][1], '\d{1,5}') then
			GUICtrlSetData($gui_error, "E: Neplatne cislo portu.")
		elseif $configuration[get_index('target')][1] == '' then
			GUICtrlSetData($gui_error, "E: Neplatny cilovy adresar.")
		elseif not FileExists($configuration[get_index('key')][1]) then
			GUICtrlSetData($gui_error, "E: Klic neexistuje.")
		else
			; disable backup button
			GUICtrlSetState($gui_button_backup, $GUI_DISABLE)
			; backup
			for $i = 0 to 2
				if GUICtrlRead($component[$i][1]) <> '' then
					if FileExists(GUICtrlRead($component[$i][1])) then
						; disable input
						GUICtrlSetState($component[$i][1], $GUI_DISABLE)
						; rsync
						RunWait($rsync & ' -az -e "' & $ssh & ' -o "StrictHostKeyChecking no" -p '_
						& $configuration[get_index('port')][1] & ' -i '_
						& $configuration[get_index('key')][1] & '" '_
						& GUICtrlRead($component[$i][1]) & ' '_
						& $configuration[get_index('user')][1] & '@'_
						& $configuration[get_index('remote')][1] & ':/'_
						& $configuration[get_index('target')][1])
						; update progress
						GUICtrlSetData($gui_progress, round(($i + 1) * 100 / 3))
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
			GUICtrlSetState($gui_button_backup, $GUI_ENABLE)
		endif
		logger("Backup end.")
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
logger("Program exit: " & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)
logger("------------------------------------")
FileClose($log)
exit

; FUNC

func logger($text)
	FileWriteLine($log, $text)
endfunc

func get_index($variable)
	return _ArraySearch($configuration, $variable, 0, 0, 0, 1)
endfunc

func nas_gui()
	$nas_gui = GUICreate("NAS Z�loha - Konfigurace NAS", 400, 150, Default, Default)
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
	$nas_gui_save_button = GUICtrlCreateButton("Ulozit", 225, 74, 75, 25)
	$nas_gui_exit_button = GUICtrlCreateButton("Konec", 300, 74, 75, 25)

	GUISetState(@SW_SHOW, $nas_gui)

	while 1
		$event = GUIGetMsg($nas_gui)

		if $event = $nas_gui_key_button then
			GUICtrlSetData($nas_gui_key_input, FileSelectFolder("Adresar", @HomeDrive))
		endif
		if $event = $nas_gui_save_button then
			$configuration[get_index('user')][1] = GUICtrlRead($nas_gui_user_input)
			$configuration[get_index('remote')][1] = GUICtrlRead($nas_gui_remote_input)
			$configuration[get_index('port')][1] = GUICtrlRead($nas_gui_port_input)
			$configuration[get_index('target')][1] = GUICtrlRead($nas_gui_target_input)
			$configuration[get_index('key')][1] = GUICtrlRead($nas_gui_key_input)
			logger("Konfigurace byla aktualizovana.")
			exitloop
		endif
		if $event = $GUI_EVENT_CLOSE or $event = $nas_gui_exit_button then exitloop
	wend
	GUIDelete($nas_gui)
endfunc
