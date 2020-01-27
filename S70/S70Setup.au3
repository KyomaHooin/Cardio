;
; S70 PDF to XLSX convertor
;

#AutoIt3Wrapper_Icon=S70.ico
#NoTrayIcon

; INLUDE

#include <File.au3>
#include <GuiListView.au3>

;VAR

$version = '1.2'
$ini = @ScriptDir & '\' & 'S70.ini'
$logfile = @ScriptDir & '\' & 'S70.log'

global $configuration[0][2]
global $2D[0][2]
global $2DCalc[0][2]
global $Doppler[0][2]

;CONTROL

; one instance
if UBound(ProcessList(@ScriptName)) > 2 then
	MsgBox(48, 'S70Setup v ' & $version, 'Program byl již spuštěn. [R]')
	exit
endif
; logging
$log = FileOpen($logfile, 1)
if @error then
	MsgBox(48, 'S70Setup v ' & $version, 'System je připojen pouze pro čtení. [RO]')
	exit
endif

; INIT

logger('Program begin: ' & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)
; read configuration
if not FileExists($ini) then
	$f = FileOpen($ini, 1)
	FileWriteLine($f, 'path=')
	FileWriteLine($f, '2D=RS Major|RS Major|LVSd|LVSd|LVIDd|LVIDd|LVPWd|LVPWd|LVIDs|LVIDs|LA Diam|LA Diam|Ao Diam Svals|Ao Diam Svals|RVIDd|RVIDd|RA Minor|RA Minor|RA Major|RA Major|LA Minor|LA Minor|LA Major|LA Major|LAAd A4C|LAAd A4C|LALd A4C|LALd A4C|LAEDV A-L A4C|LAEDV A-L A4C|LAEDV MOD A4C|LAEDV MOD A4C|MR Rad|MR Rad|MR Als.Vel|MR Als.Vel|MR Flow|MR Flow')
	FileWriteLine($f, '2DCalc=LVIDd Index|LVIDd Index|EDV(Teich)|EDV(Teich)|EDV(Cube)|EDV(Cube)|LVd Mass|LVd Mass|LVd Mass Index|LVd Mass Index|LVd Mass (ASE)|LVd Mass (ASE)|LVd Mass Ind (ASE)|LVd Mass Ind (ASE)|LVIDs Index|LVIDs Index|ESV (Teich)|ESV (Teich)|EF (Teich|EF (Teich)|ESV (Cube)|ESV (Cube)|EF (Cube)|EF (Cube)|%FS|%FS|SV(Teich)|SV(Teich)|SI(Teich)|SI(Teich)|SV(Cube)|SV(Cube)|SI(Cube)|SI(Cube)|LAVi|LAVi')
    FileWriteLine($f, 'Doppler=Ao Diam|Ao Diam|TV maxPG|TV maxPG|MV E Vel|MV E Vel|MV A Vel|MV A Vel|MV E/A Ratio|MV E/A Ratio|MV DecT|MV DecT|MV PHT|MV PHT|EmSept|EmSept|EmLat|EmLat|EmAver|EmAver|E/Em|E/Em|MR Vmax|MR Vmax|MR Vmean|MR Vmean|MR maxPG|MR maxPG|MR meanPG|MR meanPG|MR VTI|MR VTI|AV Vmax|AV Vmax|AV Vmean|AV Vmean|AV maxPG|AV maxPG|AV meanPG|AV meanPG|AV Env.Ti|AV env.Ti|AV VTI|AV VTI|MR Vmax|MR Vmax|MR VTI|MR VTI|MR ERO|MR ERO|MR RV|MR RV')
	FileClose($f)
endif
_FileReadToArray($ini, $configuration, 0, '='); 0-based
if @error then
	logger('Načtení konfiguračního INI souboru selhalo.')
	exit
else
	logger('Konfigurační INI soubor byl načten.')
endif
; split configuration
$D2 = A1toA2(StringSplit($configuration[1][1], '|', 2))
$D2Calc = A1toA2(StringSplit($configuration[2][1], '|', 2))
$Doppler = A1toA2(StringSplit($configuration[3][1], '|', 2))

; GUI

$gui = GUICreate('S70Setup v ' & $version, 424, 70, Default, Default)
$gui_dir_text = GUICtrlCreateLabel('Adresář:', 8, 11, 43, 17)
$gui_dir_input = GUICtrlCreateInput($configuration[0][1], 54, 8, 280, 21)
$gui_dir_button = GUICtrlCreateButton('Procházet', 342, 6, 75, 25)
$gui_button_setup = GUICtrlCreateButton('', 308, 38, 25, 25, 0x0040); BS_ICON
$gui_button_exit = GUICtrlCreateButton('Konec', 342, 38, 75, 25)
$gui_error = GUICtrlCreateLabel('', 8, 43, 290, 17)

; set default focus
GUICtrlSetState($gui_button_exit, 256); focus
;set button icon
GUICtrlSetImage($gui_button_setup, 'gear.ico')

GUISetState(@SW_SHOW, $gui)

; MAIN

while 1
	$event = GUIGetMsg()
	; update dir intput
	If $event = $gui_dir_button then
		$dir_input = FileSelectFolder('Adresář', @HomeDrive)
		GUICtrlSetData($gui_dir_input, $dir_input)
		$configuration[0][1] = $dir_input
	endif
	; translation setup
	If $event = $gui_button_setup then setup($configuration)
	; exit
	if $event = -3 or $event = $gui_button_exit then; event close
		; update configuration
		$configuration[0][1] = GUICtrlRead($gui_dir_input)
		if UBound($D2) > 0 then $configuration[1][1] = _ArrayToString($D2, '|', Default, Default, '|')
		if UBound($D2Calc) > 0 then $configuration[2][1] = _ArrayToString($D2Calc, '|', Default, Default, '|')
		if UBound($Doppler) > 0 then $configuration[3][1] = _ArrayToString($Doppler, '|', Default, Default, '|')
		; write configuration
		$f = FileOpen($ini, 2); overwrite
		for $i = 0 to ubound($configuration) - 1
			FileWriteLine($ini, $configuration[$i][0] & '=' & $configuration[$i][1])
		next
		FileClose($f)
		; exit
		exitloop
	endif
WEnd

; exit
logger('Program exit: ' & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)
logger('------------------------------------')
FileClose($log)
exit

; FUNC

func logger($text)
	FileWriteLine($log, $text)
endfunc

func A1toA2($A1)
	local $A2[0][2]
	if Mod(UBound($A1), 2) <> 0 then return
	for $i=0 to UBound($A1) / 2 - 1
		_ArrayAdd($A2, $A1[2 * $i] & '|' & $A1[2 * $i + 1])
	next
	return $A2
EndFunc

func setup($configuration)

	$setup = GUICreate('Nastavení překladu', 370, 460, Default, Default)
	$setup_store_button = GUICtrlCreateButton('Uložit', 288, 135, 75, 25)
	$setup_edit_label = GUICtrlCreateLabel('Hodnota:', 242, 30, 45, 20)
	$setup_edit_label_input = GUICtrlCreateInput('', 242, 50, 120, 25, 0x0800); read only
	$setup_edit_label_translate = GUICtrlCreateLabel('Překlad:', 242, 80, 45, 20)
	$setup_edit_label_translate_input = GUICtrlCreateInput('', 242, 100, 120, 25)
	$setup_tab = GUICtrlCreateTab(8,8,225,445)
	$setup_tab_2d = GUICtrlCreateTabItem('2-D parametry')
	$setup_tab_2d_list = GUICtrlCreateListView('Hodnota|Překlad', 15, 35, 210, 410, Default, BitOR(0x00000001, 0x00000020))
	_GUICtrlListView_SetColumnWidth($setup_tab_2d_list, 0, 103)
	_GUICtrlListView_SetColumnWidth($setup_tab_2d_list, 1, 103)
	GUICtrlCreateTabItem('')
	$setup_tab_2d_calc = GUICtrlCreateTabItem("2-D kalkulace")
	$setup_tab_2d_calc_list = GUICtrlCreateListView('Hodnota|Překlad', 15, 35, 210, 410, Default, BitOR(0x00000001, 0x00000020))
	_GUICtrlListView_SetColumnWidth($setup_tab_2d_calc_list, 0, 103)
	_GUICtrlListView_SetColumnWidth($setup_tab_2d_calc_list, 1, 103)
	GUICtrlCreateTabItem('')
	$setup_tab_doppler = GUICtrlCreateTabItem('Doppler')
	$setup_tab_doppler_list = GUICtrlCreateListView('Hodnota|Překlad', 15, 35, 210, 410, Default, BitOR(0x00000001, 0x00000020))
	_GUICtrlListView_SetColumnWidth($setup_tab_doppler_list, 0, 103)
	_GUICtrlListView_SetColumnWidth($setup_tab_doppler_list, 1, 103)
	GUICtrlCreateTabItem('')
	$setup_button_exit = GUICtrlCreateButton('Konec', 288, 428, 75, 25)

	for $i=0 to UBound($D2) - 1
		GUICtrlCreateListViewItem($D2[$i][0] & '|' & $D2[$i][1], $setup_tab_2d_list)
	next
	for $i=0 to UBound($D2Calc) - 1
		GUICtrlCreateListViewItem($D2Calc[$i][0] & '|' & $D2Calc[$i][1],$setup_tab_2d_calc_list)
	next
	for $i=0 to UBound($Doppler) - 1
		GUICtrlCreateListViewItem($Doppler[$i][0] & '|' & $Doppler[$i][1],$setup_tab_doppler_list)
	next

	; set default focus
	GUICtrlSetState($setup_button_exit, 256); focus

	GUISetState(@SW_SHOW, $setup)

	local $next = -1, $prev = -1, $next_tab = 0

	while 1
		;event collector
		$setup_event = GUIGetMsg()
		;get selection
		switch GUICtrlRead($setup_tab)
			case 0
				if $next_tab <> 0 Then
					$next_tab = 0
					$next = -1
					$prev = -1
					GUICtrlSetData($setup_edit_label_input, '')
					GUICtrlSetData($setup_edit_label_translate_input, '')
					_GUICtrlListView_SetItemSelected($setup_tab_2d_list, -1, False)
				endif
				$next = _GUICtrlListView_GetNextItem($setup_tab_2d_list)
				if $next <> $prev Then; update input
					GUICtrlSetData($setup_edit_label_input, $D2[$next][0])
					GUICtrlSetData($setup_edit_label_translate_input, $D2[$next][1])
					$prev = $next
				endif
			case 1
				if $next_tab <> 1 Then
					$next_tab = 1
					$next = -1
					$prev = -1
					GUICtrlSetData($setup_edit_label_input, '')
					GUICtrlSetData($setup_edit_label_translate_input, '')
					_GUICtrlListView_SetItemSelected($setup_tab_2d_calc_list, -1, False)
				endif
				$next = _GUICtrlListView_GetNextItem($setup_tab_2d_calc_list)
				if $next <> $prev Then
					GUICtrlSetData($setup_edit_label_input, $D2Calc[$next][0])
					GUICtrlSetData($setup_edit_label_translate_input, $D2Calc[$next][1])
					$prev = $next
				endif
			case 2
				if $next_tab <> 2 Then
					$next_tab = 2
					$next = -1
					$prev = -1
					GUICtrlSetData($setup_edit_label_input, '')
					GUICtrlSetData($setup_edit_label_translate_input, '')
					_GUICtrlListView_SetItemSelected($setup_tab_doppler_list, -1, False)
				endif
				$next = _GUICtrlListView_GetNextItem($setup_tab_doppler_list)
				if $next <> $prev Then
					GUICtrlSetData($setup_edit_label_input, $Doppler[$next][0])
					GUICtrlSetData($setup_edit_label_translate_input, $Doppler[$next][1])
					$prev = $next
				endif
		EndSwitch
		;update configuration
		if $setup_event = $setup_store_button then
			switch $next_tab
				case 0
					$D2[$next][1] = GUICtrlRead($setup_edit_label_translate_input)
					_GUICtrlListView_SetItemText($setup_tab_2d_list, $next, GUICtrlRead($setup_edit_label_translate_input), 1)
				case 1
					$D2Calc[$next][1] = GUICtrlRead($setup_edit_label_translate_input)
					_GUICtrlListView_SetItemText($setup_tab_2d_calc_list, $next, GUICtrlRead($setup_edit_label_translate_input), 1)
				case 2
					$Doppler[$next][1] = GUICtrlRead($setup_edit_label_translate_input)
					_GUICtrlListView_SetItemText($setup_tab_doppler_list, $next, GUICtrlRead($setup_edit_label_translate_input), 1)
			endswitch
		endif
		;exit
		if $setup_event = -3 or $setup_event = $setup_button_exit then exitloop; event close
	WEnd
	GUIDelete($setup)
EndFunc
