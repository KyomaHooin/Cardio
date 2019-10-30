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
create_gui($configuration,$dirlist)


; MAIN


while 1
	$event = GUIGetMsg()
	; DIR 1
	if $event = $gui_button_path1 Then; data path
		$data_path1 = FileSelectFolder("Adresáø", @HomeDrive)
		if $gui_dirpath1 then GUICtrlSetData($gui_dirpath1, $data_path1); update path
	EndIf
	; DIR 2
	if $event = $gui_button_path2 Then; data path
		$data_path2 = FileSelectFolder("Adresáø", @HomeDrive)
		if $gui_dirpath2 then GUICtrlSetData($gui_dirpath2, $data_path2); update path
	EndIf
	; DIR 3
	if $event = $gui_button_path3 Then; data path
		$data_path3 = FileSelectFolder("Adresáø", @HomeDrive)
		if $gui_dirpath3 then GUICtrlSetData($gui_dirpath3, $data_path3); update path
	EndIf

	; BACKUP
	if $event = $gui_button_backup Then; data path
		if GUICtrlRead($gui_dirpath1) and not FileExists(GUICtrlRead($gui_dirpath1)) then
			GUICtrlSetData($gui_error,"E: Adresáø [1] neexistuje.")
		elseIf GUICtrlRead($gui_dirpath2) and not FileExists(GUICtrlRead($gui_dirpath2)) then
			GUICtrlSetData($gui_error,"E: Adresáø [2] neexistuje.")
		elseif GUICtrlRead($gui_dirpath3) and not FileExists(GUICtrlRead($gui_dirpath3)) then
			GUICtrlSetData($gui_error,"E: Adresáø [3] neexistuje.")
		else
			$i = 0
			$j = 1
			;get dir count
			if GUICtrlRead($gui_dirpath1) then $i+=1
			if GUICtrlRead($gui_dirpath2) then $i+=1
			if GUICtrlRead($gui_dirpath3) then $i+=1
			;disable input
			GUICtrlSetState($gui_dirpath1,$GUI_DISABLE)
			GUICtrlSetState($gui_dirpath2,$GUI_DISABLE)
			GUICtrlSetState($gui_dirpath3,$GUI_DISABLE)
			GUICtrlSetState($gui_button_backup,$GUI_DISABLE)
			;reset progress
			GUICtrlSetData($gui_progress, 0)
			;Backup dir 1
			if GUICtrlRead($gui_dirpath1) then
				RunWait(@ScriptDir & '\' & 'back.exe ' & GUICtrlRead($gui_dirpath1),@ScriptDir,@SW_HIDE)
				GUICtrlSetData($gui_progress, round($j * 100/ $i))
				$j+=1
			endif
			if GUICtrlRead($gui_dirpath2) then
				RunWait(@ScriptDir & '\' & 'back.exe ' & GUICtrlRead($gui_dirpath2),@ScriptDir,@SW_HIDE)
				GUICtrlSetData($gui_progress, round($j * 100/ $i))
				$j+=1
			endif
			if GUICtrlRead($gui_dirpath3) then
				RunWait(@ScriptDir & '\' & 'back.exe ' & GUICtrlRead($gui_dirpath3),@ScriptDir,@SW_HIDE)
				GUICtrlSetData($gui_progress, round($j * 100/ $i))
				$j+=1
			endif
			;disable enable
			GUICtrlSetState($gui_dirpath1,$GUI_ENABLE)
			GUICtrlSetState($gui_dirpath2,$GUI_ENABLE)
			GUICtrlSetState($gui_dirpath3,$GUI_ENABLE)
			GUICtrlSetState($gui_button_backup,$GUI_ENABLE)

		EndIf
	EndIf
	; EXIT
	If $event = $GUI_EVENT_CLOSE or $event = $gui_button_exit then
		;update history
		$f = FileOpen($ini,2);overwrite
		FileWriteLine($f,'[dir1] ' & GUICtrlRead($gui_dirpath1))
		FileWriteLine($f,'[dir2] ' & GUICtrlRead($gui_dirpath2))
		FileWriteLine($f,'[dir3] ' & GUICtrlRead($gui_dirpath3))
		; update scheduler
		if GUICtrlRead($gui_check_schedule) = $GUI_CHECKED Then
			FileWriteLine($f,'[auto] 1')
		else
			FileWriteLine($f,'[auto] 0')
		Endif
		FileClose($f)
		;exit
		exit
	endif
wend


; FUNC


func create_gui($dirlist,$config)
	; head
	$gui = GUICreate("NAS Záloha - Kardio Jan Škoda v1.0", 492, 170, Default, Default)
	; dir
	$gui_dirtext1 = GUICtrlCreateLabel("Adresáø:", 8, 14, 44, 17)
	$gui_dirpath1 = GUICtrlCreateInput("", 52, 10, 345, 21)
	$gui_button_path1 = GUICtrlCreateButton("Procházet", 408, 8, 75, 25)
	; foot
	$gui_progress = GUICtrlCreateProgress(130, 110, 352, 16)
	$gui_error = GUICtrlCreateLabel("", 8, 140, 136, 17)
	$gui_button_exit = GUICtrlCreateButton("Konec", 408, 136, 75, 25)
	$gui_button_backup = GUICtrlCreateButton("Zálohovat", 320, 136, 75, 25)

	;set date format
	;$input_date_style = "HH:mm"
	;GUICtrlSendMsg($gui_input_date, $DTM_SETFORMATW, 0, $input_date_style)

	;set error color
	GUICtrlSetColor($gui_error, 0xFF0000)

	GUICtrlSetData($gui_dirpath1, StringRegExpReplace(FileReadLine($f,1),'^\[dir1\] (.*)','$1'))
	GUICtrlSetData($gui_dirpath2, StringRegExpReplace(FileReadLine($f,2),'^\[dir2\] (.*)','$1'))
	GUICtrlSetData($gui_dirpath3, StringRegExpReplace(FileReadLine($f,3),'^\[dir3\] (.*)','$1'))
	$auto = StringRegExpReplace(FileReadLine($f,4),'^\[auto] (.*)','$1')

	;show
	GUISetState(@SW_SHOW)
endfunc

func update_gui()
	WinCtrlSetPos
	WinMove
endfunc

func logger($text)
	FileWriteLine($log,$text)
endfunc

