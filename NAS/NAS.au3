;
; rsync.exe GUI
;

#AutoIt3Wrapper_Icon="NAS.ico"
#NoTrayIcon

; ---------------------------------------------------------
;INCLUDE
; ---------------------------------------------------------

#include <File.au3>
#include <Array.au3>
#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <ProgressConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>

; ---------------------------------------------------------
;VAR
; ---------------------------------------------------------

global $version = '1.0'
global $ini = @ScriptDir & '\NAS.ini'
global $configuration[0][2]

; ---------------------------------------------------------
;CONTROL
; ---------------------------------------------------------

; one instance
if UBound(ProcessList(@ScriptName)) > 2 then
	MsgBox(48, 'NAS v ' & $version, 'Program byl již spuštěn.')
	exit
endif

; 64-bit only
;if @OSArch <> 'X64' then
;	MsgBox(48, 'NAS Záloha v ' & $version, 'Tento systém není podporován. [x64]')
;	exit
;endif

; logging
$log = FileOpen(@ScriptDir & '\' & 'NAS.log', 1)
if @error then
	MsgBox(48, 'NAS Záloha v ' & $version, 'System je připojen pouze pro čtení.')
	exit
endif

; ---------------------------------------------------------
; INIT
; ---------------------------------------------------------

logger('Program begin: ' & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)

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
	MsgBox(0, 'NAS v' & $version, 'Načtení konfiguračního INI souboru selhalo.')
	exit
else
	logger("Konfigurační INI soubor byl načten.")
endif

; ---------------------------------------------------------
; GUI
; ---------------------------------------------------------

$gui = GUICreate('NAS v' & $version, 574, 238, Default, Default)
$gui_source_group = GUICtrlCreateGroup('Zdroj', 5, 5, 564, 146)
GUICtrlSetFont(-1, 8, 800, 0, 'MS Sans Serif')
GUICtrlCreateGroup('', -99, -99, 1, 1)
$gui_input_source1 = GUICtrlCreateInput($configuration[_ArrayBinarySearch($configuration,'dir1')][1], 14, 24, 465, 21)
$gui_input_source2 = GUICtrlCreateInput($configuration[_ArrayBinarySearch($configuration,'dir2')][1], 14, 48, 465, 21)
$gui_input_source3 = GUICtrlCreateInput($configuration[_ArrayBinarySearch($configuration,'dir3')][1], 14, 72, 465, 21)
$gui_input_source4 = GUICtrlCreateInput($configuration[_ArrayBinarySearch($configuration,'dir4')][1], 14, 96, 465, 21)
$gui_input_source5 = GUICtrlCreateInput($configuration[_ArrayBinarySearch($configuration,'dir5')][1], 14, 120, 465, 21)
$gui_button_source1 = GUICtrlCreateButton("Procházet", 484, 24, 75, 21)
$gui_button_source2 = GUICtrlCreateButton("Procházet", 484, 48, 75, 21)
$gui_button_source3 = GUICtrlCreateButton('Procházet', 484, 72, 75, 21)
$gui_button_source4 = GUICtrlCreateButton('Procházet', 484, 96, 75, 21)
$gui_button_source5 = GUICtrlCreateButton('Procházet', 484, 120, 75, 21)
$gui_target_group = GUICtrlCreateGroup('Cíl', 5, 152, 564, 50)
GUICtrlSetFont(-1, 8, 800, 0, 'MS Sans Serif')
GUICtrlCreateGroup('', -99, -99, 1, 1)
$gui_input_target1 = GUICtrlCreateInput($configuration[_ArrayBinarySearch($configuration,'dir6')][1], 14, 170, 465, 21)
$gui_button_target1 = GUICtrlCreateButton('Procházet', 484, 170, 75, 21)
$gui_progress = GUICtrlCreateProgress(8, 210, 254, 16)
$gui_error = GUICtrlCreateLabel('', 270, 212, 126, 17)
$gui_button_backup = GUICtrlCreateButton('Zálohovat', 404, 208, 75, 21)
$gui_button_exit = GUICtrlCreateButton('Konec', 484, 208, 75, 21)

; set default focus
GUICtrlSetState($gui_button_exit, $GUI_FOCUS)

GUISetState(@SW_SHOW)

; ---------------------------------------------------------
; MAIN
; ---------------------------------------------------------

while 1
	$event = GUIGetMsg()
	; source selection
	if $event = $gui_button_source1 Then
		$path = FileSelectFolder("NAS / Zdrojový adresář", @HomeDrive, Default, $configuration['dir1'][1])
		if not @error then GUICtrlSetData($gui_input_source1, $path)
	endif
	if $event = $gui_button_source2 Then
		$path = FileSelectFolder("NAS / Zdrojový adresář", @HomeDrive, Default, $configuration['dir2'][1])
		if not @error then GUICtrlSetData($gui_input_source2, $path)
	endif
	if $event = $gui_button_source3 Then
		$path = FileSelectFolder("NAS / Zdrojový adresář", @HomeDrive, Default, $configuration['dir3'][1])
		if not @error then GUICtrlSetData($gui_input_source3, $path)
	endif
	if $event = $gui_button_source4 Then
		$path = FileSelectFolder("NAS / Zdrojový adresář", @HomeDrive, Default, $configuration['dir4'][1])
		if not @error then GUICtrlSetData($gui_input_source4, $path)
	endif
	if $event = $gui_button_source5 Then
		$path = FileSelectFolder("NAS / Zdrojový adresář", @HomeDrive, Default, $configuration['dir5'][1])
		if not @error then GUICtrlSetData($gui_input_source5, $path)
	endif
	; target selection
	if $event = $gui_button_target1 Then
		$path = FileSelectFolder("NAS / Cílový adresář", @HomeDrive, Default, $configuration['dir6'][1])
		if not @error then GUICtrlSetData($gui_input_target1, $path)
	endif
	; backup
	if $event = $gui_button_backup then
		logger('Zahájeno zálohovaní..')
		; disable backup button
		GUICtrlSetState($gui_button_backup, $GUI_DISABLE)
		; reset error
		GUICtrlSetData($gui_error,'')
		; check target
		if FileExists(GUICtrlRead($gui_input_target1)) then
			; check source
			if FileExists(GUICtrlRead($gui_input_source1)) then
				; rsync
				$rsync = RunWait(@ComSpec & ' /c ' & 'rsync.exe -avz ' _
					& "'" & get_cygwin_path(GUICtrlRead($gui_input_source1)) & "'" & ' ' _
					& "'" & get_cygwin_path(GUICtrlRead($gui_input_target1)) & "'" _
					& ' > rsync.log 2> error.log' _
					, @ScriptDir, @SW_HIDE)
				; logging
				if FileGetSize(@ScriptDir & 'rsync.log') > 0 then
					logger('Adresář ' & GUICtrlRead($gui_input_source1) & ' byl zálohován.')
				elseif FileGetSize(@ScriptDir & 'error.log') > 0 then
					logger('Zálohovaní adresáře ' & GUICtrlRead($gui_input_source1) & ' selhalo.')
				endif
			endif
			if FileExists(GUICtrlRead($gui_input_source2)) then
				; rsync
				$rsync = RunWait(@ComSpec & ' /c ' & 'rsync.exe -avz ' _
					& "'" & get_cygwin_path(GUICtrlRead($gui_input_source2)) & "'" & ' ' _
					& "'" & get_cygwin_path(GUICtrlRead($gui_input_target1)) & "'" _
					& ' > rsync.log 2> error.log' _
					, @ScriptDir, @SW_HIDE)
				; logging
				if FileGetSize(@ScriptDir & 'rsync.log') > 0 then
					logger('Adresář ' & GUICtrlRead($gui_input_source2) & ' byl zálohován.')
				elseif FileGetSize(@ScriptDir & 'error.log') > 0 then
					logger('Zálohovaní adresáře ' & GUICtrlRead($gui_input_source2) & ' selhalo.')
				endif
			endif
			if FileExists(GUICtrlRead($gui_input_source3)) then
				; rsync
				$rsync = RunWait(@ComSpec & ' /c ' & 'rsync.exe -avz ' _
					& "'" & get_cygwin_path(GUICtrlRead($gui_input_source3)) & "'" & ' ' _
					& "'" & get_cygwin_path(GUICtrlRead($gui_input_target1)) & "'" _
					& ' > rsync.log 2> error.log' _
					, @ScriptDir, @SW_HIDE)
				; logging
				if FileGetSize(@ScriptDir & 'rsync.log') > 0 then
					logger('Adresář ' & GUICtrlRead($gui_input_source3) & ' byl zálohován.')
				elseif FileGetSize(@ScriptDir & 'error.log') > 0 then
					logger('Zálohovaní adresáře ' & GUICtrlRead($gui_input_source3) & ' selhalo.')
				endif
			endif
			if FileExists(GUICtrlRead($gui_input_source4)) then
				; rsync
				$rsync = RunWait(@ComSpec & ' /c ' & 'rsync.exe -avz ' _
					& "'" & get_cygwin_path(GUICtrlRead($gui_input_source4)) & "'" & ' ' _
					& "'" & get_cygwin_path(GUICtrlRead($gui_input_target1)) & "'" _
					& ' > rsync.log 2> error.log' _
					, @ScriptDir, @SW_HIDE)
				; logging
				if FileGetSize(@ScriptDir & 'rsync.log') > 0 then
					logger('Adresář ' & GUICtrlRead($gui_input_source4) & ' byl zálohován.')
				elseif FileGetSize(@ScriptDir & 'error.log') > 0 then
					logger('Zálohovaní adresáře ' & GUICtrlRead($gui_input_source4) & ' selhalo.')
				endif
			endif
			if FileExists(GUICtrlRead($gui_input_source5)) then
				; rsync
				$rsync = RunWait(@ComSpec & ' /c ' & 'rsync.exe -avz ' _
					& "'" & get_cygwin_path(GUICtrlRead($gui_input_source5)) & "'" & ' ' _
					& "'" & get_cygwin_path(GUICtrlRead($gui_input_target1)) & "'" _
					& ' > rsync.log 2> error.log' _
					, @ScriptDir, @SW_HIDE)
				; logging
				if FileGetSize(@ScriptDir & 'rsync.log') > 0 then
					logger('Adresář ' & GUICtrlRead($gui_input_source5) & ' byl zálohován.')
				elseif FileGetSize(@ScriptDir & 'error.log') > 0 then
					logger('Zálohovaní adresáře ' & GUICtrlRead($gui_input_source5) & ' selhalo.')
				endif
			endif
		endif
		; enable backup button
		GUICtrlSetState($gui_button_backup, $GUI_ENABLE)
		logger('Zalohování dokončeno.')
	endif
;	; exit
	if $event = $GUI_EVENT_CLOSE or $event = $gui_button_exit then
		; write configuration
		$f = FileOpen($ini, 2); overwrite
		FileWriteLine($ini, 'dir1=' & GUICtrlRead($gui_input_source1))
		FileWriteLine($ini, 'dir2=' & GUICtrlRead($gui_input_source2))
		FileWriteLine($ini, 'dir3=' & GUICtrlRead($gui_input_source3))
		FileWriteLine($ini, 'dir4=' & GUICtrlRead($gui_input_source4))
		FileWriteLine($ini, 'dir5=' & GUICtrlRead($gui_input_source5))
		FileWriteLine($ini, 'dir6=' & GUICtrlRead($gui_input_target1))
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