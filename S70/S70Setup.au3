;
; S70 PDF to XLSX convertor
;
; TODO
;
; - read INI
; - write INI
;

#AutoIt3Wrapper_Icon=S70.ico
#NoTrayIcon

; INLUDE

#include <File.au3>
#include <GUIConstantsEx.au3>

;VAR

$version = '1.0'
$ini = @ScriptDir & '\S70.ini'
global $configuration[0][0]

;CONTROL

; one instance
if UBound(ProcessList(@ScriptName)) > 2 then
	MsgBox(48, 'S70 v ' & $version, 'Program byl již spuštěn. [R]')
	exit
endif
; logging
$log = FileOpen(@ScriptDir & '\' & 'S70.log', 1)
if @error then
	MsgBox(48, 'S70 v ' & $version, 'System je připojen pouze pro čtení. [RO]')
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
	logger('Konfigurační INI soubor byl načten.')
endif

; GUI

$gui = GUICreate('S70Setup v ' & $version, 424, 70, Default, Default)
$gui_dir_text = GUICtrlCreateLabel('Adresář:', 8, 11, 43, 17)
$gui_dir_input = GUICtrlCreateInput('', 54, 8, 280, 21)
$gui_dir_button = GUICtrlCreateButton('Procházet', 342, 6, 75, 25)
$gui_button_setup = GUICtrlCreateButton('', 308, 38, 25, 25, 0x0040); BS_ICON
$gui_button_exit = GUICtrlCreateButton('Konec', 342, 38, 75, 25)
$gui_error = GUICtrlCreateLabel('', 8, 43, 290, 17)

; set default focus
GUICtrlSetState($gui_button_exit, $GUI_FOCUS)
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
		;$configuration[$i][1] = $dir_input
	endif
	; translation setup
	If $event = $gui_button_setup then setup($configuration)
	; exit
	if $event = $GUI_EVENT_CLOSE or $event = $gui_button_exit then
		; update input configuration
		; write configuration
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

func setup($configuration)
	$setup = GUICreate('Nastavení překladu', 721, 632, Default, Default)

	$setup_2D_group = GUICtrlCreateGroup('', 10, 6, 702, 168)
	$setup_2D_group_label = GUICtrlCreateLabel(' 2-D parametry', 24, 6, 72, 17)
	;column 1
	$setup_label1 = GUICtrlCreateLabel('RS Major', 18, 25, 80, 17)
	$setup_input1 = GUICtrlCreateInput('RS Major', 100, 22, 85, 21, 0x0001)
	$setup_label2 = GUICtrlCreateLabel('IVSd', 18, 55, 80, 17)
	$setup_input2 = GUICtrlCreateInput('IVSd', 100, 52, 85, 21, 0x0001)
	$setup_label3 = GUICtrlCreateLabel('LVIDd', 18, 85, 80, 17)
	$setup_input3 = GUICtrlCreateInput('LVIDd', 100, 82, 85, 21, 0x0001)
	$setup_label4 = GUICtrlCreateLabel('LVPWd', 18, 115, 80, 17)
	$setup_input4 = GUICtrlCreateInput('LVPWd', 100, 112, 85, 21, 0x0001)
	$setup_label5 = GUICtrlCreateLabel('LVIDs', 18, 145, 80, 17)
	$setup_input5 = GUICtrlCreateInput('LVIDs', 100, 142, 85, 21, 0x0001)
	;column 2
	$setup_label6 = GUICtrlCreateLabel('LA Diam', 190, 25, 80, 17)
	$setup_input6 = GUICtrlCreateInput('LA Diam', 272, 22, 85, 21, 0x0001)
	$setup_label7 = GUICtrlCreateLabel('Ao Diam Svals', 190, 55, 80, 17)
	$setup_input7 = GUICtrlCreateInput('Ao Diam Svals', 272, 52, 85, 21, 0x0001)
	$setup_label8 = GUICtrlCreateLabel('RVIDd', 190, 85, 80, 17)
	$setup_input8 = GUICtrlCreateInput('RVIDd', 272, 82, 85, 21, 0x0001)
	$setup_label9 = GUICtrlCreateLabel('RA Minor', 190, 115, 80, 17)
	$setup_input9 = GUICtrlCreateInput('RA Minor', 272, 112, 85, 21, 0x0001)
	$setup_label10 = GUICtrlCreateLabel('RA Major', 190, 145, 80, 17)
	$setup_input10 = GUICtrlCreateInput('RA Major', 272, 142, 85, 21, 0x0001)
	;column 3
	$setup_label11 = GUICtrlCreateLabel('LA Minor', 362, 25, 80, 17)
	$setup_input11 = GUICtrlCreateInput('LA Minor', 444, 22, 85, 21, 0x0001)
	$setup_label12 = GUICtrlCreateLabel('LA Major', 364, 55, 80, 17)
	$setup_input12 = GUICtrlCreateInput('LA Major', 444, 52, 85, 21, 0x0001)
	$setup_label13 = GUICtrlCreateLabel('LAAd A4C', 362, 85, 80, 17)
	$setup_input13 = GUICtrlCreateInput('LAAd A4C', 444, 82, 85, 21, 0x0001)
	$setup_label14 = GUICtrlCreateLabel('LALd A4C', 362, 115, 80, 17)
	$setup_input14 = GUICtrlCreateInput('LALd A4C', 444, 112, 85, 21, 0x0001)
	$setup_label15 = GUICtrlCreateLabel('LAEDV A-L A4C', 362, 145, 80, 17)
	$setup_input15 = GUICtrlCreateInput('LAEDV A-L A4C', 444, 142, 85, 21, 0x0001)
	;column 4
	$setup_label16 = GUICtrlCreateLabel('LAEDV MOD A4C', 534, 25, 90, 17)
	$setup_input16 = GUICtrlCreateInput('LAEDV MOD A4C', 616, 22, 85, 21, 0x0001)
	$setup_label17 = GUICtrlCreateLabel('MR Rad', 534, 55, 80, 17)
	$setup_input17 = GUICtrlCreateInput('MR Rad', 616, 52, 85, 21, 0x0001)
	$setup_label18 = GUICtrlCreateLabel('MR Als.Vel', 534, 85, 80, 17)
	$setup_input18 = GUICtrlCreateInput('MR Als.Vel', 616, 82, 85, 21, 0x0001)
	$setup_label19 = GUICtrlCreateLabel('MR Flow', 534, 115, 80, 17)
	$setup_input19 = GUICtrlCreateInput('MR Flow', 616, 112, 85, 21, 0x0001)

;	$setup_label2 = GUICtrlCreateLabel("IVSd", 16, 48, 23, 17)
;	$setup_input2 = GUICtrlCreateInput("IVSd", 56, 48, 81, 21)
;	$setup_label3 = GUICtrlCreateLabel("LVPWd", 16, 106, 34, 17)
;	$setup_input3 = GUICtrlCreateInput("LVPWd", 56, 106, 81, 21)
;	$setup_label4 = GUICtrlCreateLabel("LVIDd", 18, 75, 26, 17)
;	$setup_input4 = GUICtrlCreateInput("LVIDd", 58, 75, 81, 21)
;	$Label15 = GUICtrlCreateLabel("lwids", 14, 135, 27, 17)
;	$Input15 = GUICtrlCreateInput("lwids", 54, 135, 81, 21)
;	$setup_label5 = GUICtrlCreateLabel("LA Diam", 154, 27, 34, 17)
;	$setup_input5 = GUICtrlCreateInput("LA Diam", 194, 27, 81, 21)
;	$Label5 = GUICtrlCreateLabel("aodiam", 155, 52, 38, 17)
;	$Input5 = GUICtrlCreateInput("aodiamsvals", 195, 52, 81, 21)
;	$Label6 = GUICtrlCreateLabel("rvidd", 155, 76, 27, 17)
;	$Input6 = GUICtrlCreateInput("rvidd", 195, 76, 81, 21)
;	$Label7 = GUICtrlCreateLabel("laminor", 293, 23, 37, 17)
;	$Input7 = GUICtrlCreateInput("laminor", 333, 23, 81, 21)
;	$Label8 = GUICtrlCreateLabel("lamajor", 293, 47, 37, 17)
;	$Input8 = GUICtrlCreateInput("lamoajor", 333, 47, 81, 21)
;	$Label9 = GUICtrlCreateLabel("laad a4c", 290, 77, 45, 17)
;	$Input9 = GUICtrlCreateInput("laada4c", 330, 77, 81, 21)
;	$Label10 = GUICtrlCreateLabel("laedvmod", 426, 21, 50, 17)
;	$Input10 = GUICtrlCreateInput("laedvmod", 466, 21, 81, 21)
;	$Label11 = GUICtrlCreateLabel("mrrad", 427, 51, 30, 17)
;	$Input11 = GUICtrlCreateInput("mrrad", 467, 51, 81, 21)
;	$Label12 = GUICtrlCreateLabel("mrals", 427, 75, 28, 17)
;	$Input12 = GUICtrlCreateInput("mrals", 467, 75, 81, 21)
;	$Label13 = GUICtrlCreateLabel("laedval", 301, 134, 38, 17)
;	$Input13 = GUICtrlCreateInput("laedval", 341, 134, 81, 21)
;	$Label14 = GUICtrlCreateLabel("ramajor", 157, 134, 38, 17)
;	$Input14 = GUICtrlCreateInput("ramajor", 197, 134, 81, 21)
;	$Label16 = GUICtrlCreateLabel("mrflow", 430, 103, 34, 17)
;	$Input16 = GUICtrlCreateInput("mrflow", 470, 103, 81, 21)
;	GUICtrlCreateGroup("", -99, -99, 1, 1)
;	$setup_Calculation_group = GUICtrlCreateGroup('', 10, 8, 327, 185)
;	$setup_Calculation_group_label = GUICtrlCreateRadio('2-D kalkulace', 24, 8, 100, 17)
;	$Label17 = GUICtrlCreateLabel("lalda4c", 296, 106, 38, 17)
;	$Input17 = GUICtrlCreateInput("lalda4c", 336, 106, 81, 21)
;	$Label19 = GUICtrlCreateLabel("raminor", 157, 104, 38, 17)
;	$Input19 = GUICtrlCreateInput("raminor", 197, 104, 81, 21)
;	$Label20 = GUICtrlCreateLabel("lvidind", 10, 201, 34, 17)
;	$Input20 = GUICtrlCreateInput("lvidind", 50, 201, 81, 21)
;	$Label21 = GUICtrlCreateLabel("edvteich", 10, 225, 45, 17)
;	$Input21 = GUICtrlCreateInput("edvteich", 50, 225, 81, 21)
;	$Label22 = GUICtrlCreateLabel("edvcube", 12, 252, 46, 17)
;	$Input22 = GUICtrlCreateInput("edvcube", 52, 252, 81, 21)
;	$Label23 = GUICtrlCreateLabel("lvdmassase", 148, 204, 59, 17)
;	$Input23 = GUICtrlCreateInput("lvdmassase", 188, 204, 81, 21)
;	$Label24 = GUICtrlCreateLabel("lvdmassind", 149, 229, 56, 17)
;	$Input24 = GUICtrlCreateInput("lvdmassind", 189, 229, 81, 21)
;	$Label25 = GUICtrlCreateLabel("ase", 149, 253, 21, 17)
;	$Input25 = GUICtrlCreateInput("ase", 189, 253, 81, 21)
;	$Label26 = GUICtrlCreateLabel("efteich", 287, 200, 36, 17)
;	$Input26 = GUICtrlCreateInput("efteich", 327, 200, 81, 21)
;	$Label27 = GUICtrlCreateLabel("esvcube", 287, 224, 45, 17)
;	$Input27 = GUICtrlCreateInput("esvcube", 327, 224, 81, 21)
;	$Label28 = GUICtrlCreateLabel("efcube", 284, 254, 37, 17)
;	$Input28 = GUICtrlCreateInput("efcube", 324, 254, 81, 21)
;	$Label29 = GUICtrlCreateLabel("siteich", 420, 198, 34, 17)
;	$Input29 = GUICtrlCreateInput("siteich", 460, 198, 81, 21)
;	$Label30 = GUICtrlCreateLabel("svcube", 421, 228, 39, 17)
;	$Input30 = GUICtrlCreateInput("svcube", 461, 228, 81, 21)
;	$Label31 = GUICtrlCreateLabel("sicube", 421, 252, 35, 17)
;	$Input31 = GUICtrlCreateInput("sicube", 461, 252, 81, 21)
;	$Label32 = GUICtrlCreateLabel("lvdmassindex", 7, 311, 67, 17)
;	$Input32 = GUICtrlCreateInput("lvdmassindex", 47, 311, 81, 21)
;	$Label33 = GUICtrlCreateLabel("esvteich", 151, 311, 44, 17)
;	$Input33 = GUICtrlCreateInput("esvteich", 191, 311, 81, 21)
;	$Label34 = GUICtrlCreateLabel("svteich", 288, 312, 38, 17)
;	$Input34 = GUICtrlCreateInput("svteich", 328, 312, 81, 21)
;	$Label35 = GUICtrlCreateLabel("lavi", 424, 280, 20, 17)
;	$Input35 = GUICtrlCreateInput("lavi", 464, 280, 81, 21)
;	GUICtrlCreateGroup("", -99, -99, 1, 1)
;	$setup_Doppler_group = GUICtrlCreateGroup('', 10, 8, 327, 185)
;	$setup_Doppler_group_label = GUICtrlCreateRadio('Doppler + Mmode', 24, 8, 100, 17)
;	$Label36 = GUICtrlCreateLabel("fs", 290, 283, 12, 17)
;	$Input36 = GUICtrlCreateInput("fs", 330, 283, 81, 21)
;	$Label37 = GUICtrlCreateLabel("lvdmass", 10, 283, 42, 17)
;	$Input37 = GUICtrlCreateInput("lvdmass", 50, 283, 81, 21)
;	$Label38 = GUICtrlCreateLabel("lvidsind", 151, 281, 39, 17)
;	$Input38 = GUICtrlCreateInput("lvidsind", 191, 281, 81, 21)
;	$Label39 = GUICtrlCreateLabel("aodiam", 18, 379, 38, 17)
;	$Input39 = GUICtrlCreateInput("aodiam", 58, 379, 81, 21)
;	$Label40 = GUICtrlCreateLabel("tvmax", 18, 403, 32, 17)
;	$Input40 = GUICtrlCreateInput("tvmax", 58, 403, 81, 21)
;	$Label41 = GUICtrlCreateLabel("mvevel", 20, 430, 38, 17)
;	$Input41 = GUICtrlCreateInput("mvevel", 60, 430, 81, 21)
;	$Label42 = GUICtrlCreateLabel("emsept", 156, 382, 38, 17)
;	$Input42 = GUICtrlCreateInput("emsept", 196, 382, 81, 21)
;	$Label43 = GUICtrlCreateLabel("emlat", 157, 407, 29, 17)
;	$Input43 = GUICtrlCreateInput("emlat", 197, 407, 81, 21)
;	$Label44 = GUICtrlCreateLabel("emaver", 157, 431, 39, 17)
;	$Input44 = GUICtrlCreateInput("emaver", 197, 431, 81, 21)
;	$Label45 = GUICtrlCreateLabel("mrmeanpg", 295, 378, 53, 17)
;	$Input45 = GUICtrlCreateInput("mrmeanpg", 335, 378, 81, 21)
;	$Label46 = GUICtrlCreateLabel("mrvti", 295, 402, 26, 17)
;	$Input46 = GUICtrlCreateInput("mrvti", 335, 402, 81, 21)
;	$Label47 = GUICtrlCreateLabel("avvmax", 292, 432, 41, 17)
;	$Input47 = GUICtrlCreateInput("avvmax", 332, 432, 81, 21)
;	$Label48 = GUICtrlCreateLabel("avvti", 428, 376, 27, 17)
;	$Input48 = GUICtrlCreateInput("avvti", 468, 376, 81, 21)
;	$Label49 = GUICtrlCreateLabel("mrvmax", 429, 406, 40, 17)
;	$Input49 = GUICtrlCreateInput("mrvmax", 469, 406, 81, 21)
;	$Label50 = GUICtrlCreateLabel("mrvti", 429, 430, 26, 17)
;	$Input50 = GUICtrlCreateInput("mrvti", 469, 430, 81, 21)
;	$Label54 = GUICtrlCreateLabel("mrero", 432, 458, 30, 17)
;	$Input54 = GUICtrlCreateInput("mrero", 472, 458, 81, 21)
;	$Label55 = GUICtrlCreateLabel("avvmean", 298, 461, 48, 17)
;	$Input55 = GUICtrlCreateInput("avvmean", 338, 461, 81, 21)
;	$Label56 = GUICtrlCreateLabel("mvavel", 18, 461, 38, 17)
;	$Input56 = GUICtrlCreateInput("mvavel", 58, 461, 81, 21)
;	$Label57 = GUICtrlCreateLabel("eem", 159, 459, 24, 17)
;	$Input57 = GUICtrlCreateInput("eem", 199, 459, 81, 21)
;	$Label58 = GUICtrlCreateLabel("mrrv", 433, 484, 24, 17)
;	$Input58 = GUICtrlCreateInput("mrrv", 473, 484, 81, 21)
;	$Label59 = GUICtrlCreateLabel("avmaxpg", 307, 487, 47, 17)
;	$Input59 = GUICtrlCreateInput("avmaxpg", 347, 487, 81, 21)
;	$Label60 = GUICtrlCreateLabel("mvearat", 27, 487, 42, 17)
;	$Input60 = GUICtrlCreateInput("mvearat", 67, 487, 81, 21)
;	$Label61 = GUICtrlCreateLabel("mrvmax", 168, 485, 40, 17)
;	$Input61 = GUICtrlCreateInput("mrvmax", 208, 485, 81, 21)
;	$Label51 = GUICtrlCreateLabel("avenvti", 305, 546, 39, 17)
;	$Input51 = GUICtrlCreateInput("avenvti", 345, 546, 81, 21)
;	$Label52 = GUICtrlCreateLabel("avmeanpg", 299, 517, 54, 17)
;	$Input52 = GUICtrlCreateInput("avmeanpg", 339, 517, 81, 21)
;	$Label53 = GUICtrlCreateLabel("mvdect", 19, 517, 39, 17)
;	$Input53 = GUICtrlCreateInput("mvdect", 59, 517, 81, 21)
;	$Label62 = GUICtrlCreateLabel("mrvmean", 160, 515, 47, 17)
;	$Input62 = GUICtrlCreateInput("mrvmean", 200, 515, 81, 21)
;	$Label63 = GUICtrlCreateLabel("mvpht", 15, 548, 33, 17)
;	$Input63 = GUICtrlCreateInput("mvpht", 55, 548, 81, 21)
;	$Label64 = GUICtrlCreateLabel("mrmaxpg", 156, 546, 46, 17)
;	$Input64 = GUICtrlCreateInput("mrmaxpg", 196, 546, 81, 21)
;	GUICtrlCreateGroup("", -99, -99, 1, 1)
	$setup_button_ok = GUICtrlCreateButton("Ok", 400, 592, 75, 25)
	$setup_button_exit = GUICtrlCreateButton("Storno", 488, 592, 75, 25)

	; set default focus
	GUICtrlSetState($setup_button_exit, $GUI_FOCUS)

	GUISetState(@SW_SHOW, $setup)

	while 1
		$setup_event = GUIGetMsg()
		;update configuration
		;......
		;exit
		if $setup_event = $GUI_EVENT_CLOSE or $setup_event = $setup_button_exit then
		; update input configuration
		;......
		; write configuration
		;......
		; exit
			exitloop
		endif
	WEnd
	GUIDelete($setup)
EndFunc
