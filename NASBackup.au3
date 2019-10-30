;
; SSH Rsync backup WIN -> NAS GUI Setup
;
; TODO:
;
; -auto vs gui
; -SSH key MGMT
; -rsync
;

#AutoIt3Wrapper_Icon=NASBackup.ico
#NoTrayIcon


;INCLUDE


#include <File.au3>
#include <GUIConstantsEx.au3>


;VAR


$ini = @ScriptDir & '\' & 'NASBackup.ini;
;$rsync = @ScriptDir & '\' & 'rsync.exe'

global $config[2][0], $component[4][10], $dirlist


;CONTROL


; one instance
if UBound(ProcessList(@ScriptName)) > 2 then exit
	MsgBox(48,"NAS Záloha - Kardio Jan Škoda v1.0","Program byl jiz spusten. [R]")
	exit
endif

; 64-bit only
;if @OSArch <> 'X64' Then
;	MsgBox(48,"NAS Záloha - Kardio Jan Škoda v1.0","Tento system není podporován. [x64]")
;	Exit
;EndIf

; logging
$log = FileOpen(@ScriptDir & '\' & 'NASBackup.log',1)
if @error then
	MsgBox(48,"NAS Záloha - Kardio Jan Škoda v1.0","System je pripojen pouze pro cteni. [RO]")
	exit
endif


; INIT


logger("Program Start" & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR
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

$gui = GUICreate("NAS Záloha - Kardio Jan Škoda v1.0", 492, 170, Default, Default)

for $i = 0 to $dirlist
	$component[$i][0] = GUICtrlCreateLabel("Adresáø:", 8, 14, 44, 17); text
	$component[$i][1] = GUICtrlCreateInput($configuration[$i][1], 52, 10, 345, 21); dir
	$component[$i][2] = GUICtrlCreateButton("Procházet", 408, 8, 75, 25); select
	$component[$1][3] = GUICtrlCreateButton("+", 408, 8, 75, 25); add
next

$gui_progress = GUICtrlCreateProgress(130, 110, 352, 16)
$gui_error = GUICtrlCreateLabel("", 8, 140, 136, 17)
$gui_button_exit = GUICtrlCreateButton("Konec", 408, 136, 75, 25)
$gui_button_backup = GUICtrlCreateButton("Zálohovat", 320, 136, 75, 25)

GUISetState(@SW_SHOW)


; MAIN


while 1
	$event = GUIGetMsg()

	; update dir loop
	; DIR 1
	if $event = $gui_button_path1 Then; data path
		$data_path1 = FileSelectFolder("Adresáø", @HomeDrive)
		if $gui_dirpath1 then GUICtrlSetData($gui_dirpath1, $data_path1); update path
	EndIf

	; BACKUP
	if $event = $gui_button_backup Then; data path
		; empty /exist control loop
		if GUICtrlRead($gui_dirpath1) and not FileExists(GUICtrlRead($gui_dirpath1)) then
			GUICtrlSetData($gui_error,"E: Adresáø [1] neexistuje.")
		else
			$i = 0
			$j = 1
			;disable input loop
			GUICtrlSetState($gui_dirpath1,$GUI_DISABLE)
			GUICtrlSetState($gui_button_backup,$GUI_DISABLE)
			;reset progress
			GUICtrlSetData($gui_progress, 0)
			;Backup loop
			if GUICtrlRead($gui_dirpath1) then
				RunWait(@ScriptDir & '\' & 'back.exe ' & GUICtrlRead($gui_dirpath1),@ScriptDir,@SW_HIDE)
				GUICtrlSetData($gui_progress, round($j * 100/ $i))
				$j+=1
			endif
			; re-enable loop
			GUICtrlSetState($gui_dirpath1,$GUI_ENABLE)
			GUICtrlSetState($gui_button_backup,$GUI_ENABLE)
		EndIf
	EndIf
	; EXIT
	If $event = $GUI_EVENT_CLOSE or $event = $gui_button_exit then
		;update history loop
		$f = FileOpen($ini,2);overwrite
		FileWriteLine($f,'[dir1] ' & GUICtrlRead($gui_dirpath1))
		FileClose($f)
		exit
	endif
wend


; FUNC


func update_gui()
	WinCtrlSetPos
	WinMove
endfunc

func logger($text)
	FileWriteLine($log,$text)
endfunc

