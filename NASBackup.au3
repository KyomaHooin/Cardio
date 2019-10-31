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


$ini = @ScriptDir & '\' & 'NASBackup.ini;
$rsync = @ScriptDir & '\bin\' & 'rsync.exe'
$ssh = @ScriptDir & '\bin\' & 'rsync.exe'


global $configuration[2][0], $component[4][10], $dirlist


;CONTROL


; one instance
if UBound(ProcessList(@ScriptName)) > 2 then exit
	MsgBox(48,"NAS Záloha - Kardio Jan Skoda v1.0","Program byl jiz spusten. [R]")
	exit
endif

; 64-bit only
;if @OSArch <> 'X64' Then
;	MsgBox(48,"NAS Záloha - Kardio Jan Skoda v1.0","Tento system není podporován. [x64]")
;	Exit
;EndIf

; logging
$log = FileOpen(@ScriptDir & '\' & 'NASBackup.log',1)
if @error then
	MsgBox(48,"NAS Záloha - Kardio Jan Skoda v1.0","System je pripojen pouze pro cteni. [RO]")
	exit
endif


; INIT


logger("Program Start :" & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR

; configuration
if not FileExists($ini) then
	; write template
	$f = FileOpen($ini,1)
	FileWriteLine($f, '[dir1]')
	FileWriteLine($f, '[user]')
	FileWriteLine($f, '[remote]')
	FileWriteLine($f, '[target]')
	FileClose($f)
	logger("Default configuration INI loaded.")
else
	_FileReadToArray($ini,$configuration, 0, ' '); 0-based, split by space
	logger("Configuration INI loaded.")
endif

; dirlist
for $i = 0 to ubound($config) - 1
	if StringRegExp($config[$i][0],'^[dir.*') then $dirlist += 1
next

; gui
$gui = GUICreate("NAS Záloha - Kardio Jan Skoda v1.0", 527, 74 + $dirlist * 32, Default, Default)
for $i = 0 to $dirlist
	$component[$i][0] = GUICtrlCreateLabel("Adresár:", 8, 14 + $i * 32, 44, 17); text
	$component[$i][1] = GUICtrlCreateInput($configuration[$i][1], 52, 10 + $i * 32, 345, 21); dir
	$component[$i][2] = GUICtrlCreateButton("Procházet", 408, 8 + $i * 32, 75, 25); select
	$component[$1][3] = GUICtrlCreateButton("+", 500, 8 + $i * 32, 25, 25); add
next
$gui_button_config = GUICtrlCreateButton("NAS", 8, 14 + $dirlist * 32, 25, 25); add
$gui_progress = GUICtrlCreateProgress(130, 14 + $dirlist * 32, 352, 16)
$gui_error = GUICtrlCreateLabel("", 8, 44 + $dirlist * 32, 136, 17)
$gui_button_exit = GUICtrlCreateButton("Konec", 408, 40 + $dirlist * 32, 75, 25)
$gui_button_backup = GUICtrlCreateButton("Zálohovat", 320, 40  + $dirlist * 32, 75, 25)


GUISetState(@SW_SHOW)


; MAIN


while 1
	$event = GUIGetMsg()

	; update directory
	for $i = 0 to $dirlist
		if $event = $component[$i][2] then; select
			$dir_update = FileSelectFolder("Adresar", @HomeDrive)
			if $dir_update then
				$configuration[$i][1] = $dir_update; update configuration
				GUICtrlSetData($component[$i][$2], $dir_update); update component
	next

	; update dir
	for $i = 0 to $dirlist
		if $event = $component[$i][3] then
			$dirlist += 1
			update_gui($configuration,$dirlist)
	next

	; NAS config
	if $event = $component[$i][3] then nas_gui()

	; backup
	if $event = $gui_button_backup Then; data path
		;test port/key/user/remote/target
		
		;reset progress
		GUICtrlSetData($gui_progress, 0)
		;disable re-run
		GUICtrlSetState($gui_button_backup,$GUI_DISABLE)
		; test directory
		for $i = 0 to $dirlist
			if GUICtrlRead($component[$i][1] <> '' then; not empty
				if FileExists(GUICtrlRead($component[$i][1]) then; exists
					;disable input
					GUICtrlSetState($component[$i][1], $GUI_DISABLE); disable change
					;rsync
					RunWait($rsync & ' -az -e "' & $ssh & ' -p ' & $port & ' -i ' & $key & '" '&_
					$user & '@' & $remote & ':/' & target & ' ' &_
					GUICtrlRead($gui_dirpath1), @ScriptDir & '\bin', @SW_HIDE)
					;update progress
					GUICtrlSetData($gui_progress, round($j * 100/ $i))
					;re-enable input
					GUICtrlSetState($component[$i][1], $GUI_ENABLE)
				else
					GUICtrlSetData($gui_error,"E: Adresar [" & $i & "] neexistuje.")
				endif
			endif
		next
		;re-enable backup
		GUICtrlSetState($gui_button_backup,$GUI_ENABLE)
	endif

	; exit
	If $event = $GUI_EVENT_CLOSE or $event = $gui_button_exit then
		; update configuration
		for $i = 0 to $dirlist
			if GUICtrlRead($component[$i][1] <> '' then; not empty
				if StringRegExp($configuration[$i][0],'^\[dir.*') then; update
					$configuration[$i][1] = GUICrtlRead($component[$i][1])
				else
					_ArrayInsert($configuration, $i, '[dir' & $i & '] ' & GUICtrlRead($component[$i][1]), ' ')
				endif
		next
		; write configuration
		$f = FileOpen($ini,2); overwrite
		for $i = 0 to ubound($configuration) - 1
			FileWriteLine($ini, $configuration[$i][0] & ' ' & $configuration[$i][1])
		next
		FileClose($f)
		; exit
		logger("Program exit: " & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR
		exit
	endif
wend


; FUNC


func update_gui($configuration,$dirlist)
	if $dirlist <= 10 then
		; resize gui
		WinMove($gui, Default, Default, Default, Default, 74 + $dirlist * 32)
		; add dir
		$component[$dirlist][0] = GUICtrlCreateLabel("Adresar:", 8, 14 + $i * 32, 44, 17); text
		$component[$dirlist][1] = GUICtrlCreateInput('', 52, 10 + $i * 32, 345, 21); dir
		$component[$dirlist][2] = GUICtrlCreateButton("Prochazet", 408, 8 + $i * 32, 75, 25); select
		$component[$dirlist][3] = GUICtrlCreateButton("+", 500, 8 + $i * 32, 25, 25); add
		; move components
		ControlMove($gui, Defaulat, $gui_button_config, Default, 14 + $dirlist * 32)
		ControlMove($gui, Defaulat, $gui_progress, Default, 14 + $dirlist * 32)
		ControlMove($gui, Defaulat, $gui_error, Default, 44 + $dirlist * 32)
		ControlMove($gui, Defaulat, $gui_button_backup, Default, 40 + $dirlist * 32)
		ControlMove($gui, Defaulat, $gui_button_exit, Default, 40 + $dirlist * 32)
endfunc

func logger($text)
	FileWriteLine($log,$text)
endfunc

func nas_gui()
	$nas_gui = GUICreate("NAS Záloha - Kardio Jan Skoda v1.0", 527, 74 + $dirlist * 32, Default, Default)

	$nas_gui_user_label
	$nas_gui_user_input
	$nas_gui_remote_label
	$nas_gui_remote_input
	$nas_gui_port_label
	$nas_gui_port_input
	$nas_gui_target_label
	$nas_gui_target_input
	$nas_gui_key_lable
	$nas_gui_key_input
	$nas_gui_key_button
	$nas_gui_save_button

	;update from configuration

	GUISetState(@SW_SHOW,$nas_gui)

	while 1
		$event = GUIGetMsg($nas_gui)

		if $event = $gui_key_button then
			$key_dir_update = FileSelectFolder("Adresar", @HomeDrive)
			GUICtrlSetData($nas_gui_key_input,$key_dir_update)
		endif

		if $event = $GUI_EVENT_CLOSE or $event = $gui_save_button then
			; update/write configuration
			; user
			if $row = _ArraySearch($configuration,'[user]',0,0,0,1) then
				$configuration[$row][1] = GUICtrlRead($nas_gui_user_input)
			else
				_ArrayAdd($configuration, '[user] ' & GUICtrlRead($nas_gui_user_input), Default, Default, ' ')
			endif
			;remote
			if $row = _ArraySearch($configuration,'[remote]',0,0,0,1) then
				$configuration[$row][1] = GUICtrlRead($nas_gui_remote_input)
			else
				_ArrayAdd($configuration, '[remote] ' & GUICtrlRead($nas_gui_remote_input), Default, Default, ' ')
			endif
			;port
			if $row = _ArraySearch($configuration,'[port]',0,0,0,1) then
				$configuration[$row][1] = GUICtrlRead($nas_gui_port_input)
			else
				_ArrayAdd($configuration, '[port] ' & GUICtrlRead($nas_gui_port_input), Default, Default, ' ')
			endif
			;target
			if $row = _ArraySearch($configuration,'[target]',0,0,0,1) then
				$configuration[$row][1] = GUICtrlRead($nas_gui_target_input)
			else
				_ArrayAdd($configuration, '[target] ' & GUICtrlRead($nas_gui_target_input), Default, Default, ' ')
			endif
			;key
			if $row = _ArraySearch($configuration,'[key]',0,0,0,1) then
				$configuration[$row][1] = GUICtrlRead($nas_gui_key_input)
			else
				_ArrayAdd($configuration, '[key] ' & GUICtrlRead($nas_gui_key_input), Default, Default, ' ')
			endif
			;exit
			logger("Konfigurace byla aktualizovana.")
			exitloop
		endif
	wend
	;drop self
	GUIDelete($nas_gui)

endfunc

