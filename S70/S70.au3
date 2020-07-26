; GE Vivid S70 - Medicus 3 integration
; CMD: S70.exe %RODCISN% %JMENO% %PRIJMENI% %POJ%
;
; Copyright (c) 2020 Kyoma Hooin
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

#AutoIt3Wrapper_Icon=S70.ico
;#AutoIt3Wrapper_Outfile_x64=S70_64.exe
;#AutoIt3Wrapper_UseX64=y
#NoTrayIcon

;
; INCLUDE
;

#include <GUIConstantsEx.au3>
#include <Clipboard.au3>
#include <Excel.au3>
#include <ExcelConstants.au3>
#include <File.au3>
#include <Date.au3>
#include <Print.au3>
#include <Json.au3>

;
; VAR
;

$VERSION = '1.5'
$HISTORY = 24; default stored data age in hours

global $log_file = @ScriptDir & '\' & 'S70.log'
global $config_file = @ScriptDir & '\' & 'S70.ini'
global $result_file = @ScriptDir & '\' & 'zaver.txt'

global $export_path = 'c:\ECHOREPORTY'
global $archive_path = @ScriptDir & '\' & 'archiv'

global $runtime = @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC

;data template
global $json_template = '{
	"patient":null,
	"name":null,
	"poj":null,
	"bsa":null,
	"weight":null,
	"height":null,
	"date",null,
	"result":null,
	"group":{
		"lk":{
			"label":"Levá komora",
			"note":null,
			"id":null
		}
		"ls":"Levá síň",
		"pk":"Pravá komora",
		"ps":"Pravá síň",
		"ao":"Aorta",
		"ach":"Aortální chlopeň",
		"mch":"Mitrální chlopeň",
		"pch":"Pulmonární chlopeň",
		"tch":"Trikuspidální chlopeň",
		"p":"Perikard",
		"other":"Ostatní"

	},
	"data":{
		"lk":{
			"IVSd":{
				"label":"IVS",
				"unit":"mm",
				"value":null,
				"id":null
			}
			"LVIDd":null,;LVd
			"LVd index":null,
			"LVPWd":null,;ZS
			"LVIDs":null,;LVs
			"LVs index":null,
			"LVEF % Teich.":null,
			"LVEF % odhad":null,
			"LVmass":null,
			"LVmass-i^2.7":null,
			"LVmass-BSA":null,
			"RTW":null,
			"FS":null,
			"EF Biplane":null,;LVEF biplane
			"SV MOD A4C":null,;.................. calculation
			"SV MOD A2C":null,;.................. calculation
			"SV-biplane":null,
			"LVEDV MOD BP":null,;EDV
			"LVESV MOD BP":null,;ESV
			"EDVi":null,
			"ESVi":null
				
		},
		"ls":{
			"LA Diam":null,;Plax
			"LAV-A4C":null,
			"LAV-2D":null,
			"LAVi-2D":null,
			"LAEDV A-L A4C":null,;............... calculation
			"LAEDV MOD A4C":null,;............... calculation
			"LAEDV A-L A2C":null,;............... calculation
			"LAEDV MOD A2C":null,;............... calculation
			"LA Minor":null,; LA sirka
			"LA Major":null,; LA delka
			"LAVi":null;LAVi
		},
		"pk":{
			"RV Major":null,;RVplax
			"RVIDd":null,;RVD1
			"S-RV":null,
			"EDA":null,
			"ESA":null,
			"FAC%":null,
			"TAPSE":null;TAPSE
		},
		"ps":{
			"RA Minor":null,;RA sirka
			"RA Major":null,;RA delka
			"RAV":null,;RAV
			"RAVi":null;RAVi
		},
		"ao":{
			"Ao Diam SVals":null,;Bulbus
			"Ao Diam":null;Asc-Ao
		},
		"ach":{
			"LVOT Diam":null,;LVOT
			"AR Rad":null,;PISA AR radius
			"AV Vmax":null,;Vmax
			"AV maxPG":null,;.................. calculation
			"AV meanPG":null,;................. calculation
			"AV max/meanPG":null,
			"AV VTI":null,;Ao-VTI
			"LVOT VTI":null,;LVOT-VTI
			"SV/SVi":null,
			"AVA":null,
			"AVAi":null,
			"VTI LVOT/Ao":null,
			"AR VTI":null,;AR-VTI
			"AR ERO":null,;AR-ERO
			"AR RV":null;AR-RV
		},	
		"mch":{
			"MR Rad":null,;PISA MR radius
			"MV E Vel":null,;E
			"MV A Vel":null,;A
			"MV E/A Ratio":null,;E/A
			"MV DecT":null,;DecT
			"MV1 PHT":null,;MV-PHT
			"MV maxPG":null,;.................. calculation
			"MV meanPG":null,;................. calculation
			"MV max/meanPG":null,
			"MVA-PHT":null,
			"MVAi-PHT":null,
			"EmSept":null,;EmSept
			"EmLat":null,;EmLat
			"E/Em":null,
			"MR VTI":null,;MR-VTI
			"MR ERO":null,;MR-ERO
			"MR RV":null;MR-RV
		},
		"pch":{
			"PV Vmax":null,;Vmax
			"PVAcc T":null,;ACT
			"PV maxPG":null,;.................. calculation
			"PV meanPG":null,;................. calculation
			"PV max/meanPG":null,
			"PRend PG":null,;PGed-reg
			"PR maxPG":null,;.................. calculation
			"PR meanPG":null,;................. calculation
			"PR max/meanPG",null
		},
		"tch":{
			"TR maxPG":null,;PGmax-reg
			"TR meanPG":null,;PGmean-reg
			"TV maxPG":null,;.................. calculation
			"TV meanPG":null,;................. calculation
			"TV max/meanPG":null
		},
		"p":{
		},
		"other":{
			"IVC Diam Exp":null,;DDŽexp
			"IVC diam Ins":null;DDŽinsp
		}
	}
}'

;data
global $history, $buffer = Json_Decode($json_template)

;XLS variable
global $excel, $book

;
; INIT
;

; check one instance
if UBound(ProcessList(@ScriptName)) > 2 then
	MsgBox(48, 'S70 Echo v' & $VERSION, 'Program byl již spuštěn.')
	exit
endif

; logging
$log = FileOpen($log_file, 1)
if @error then
	MsgBox(48, 'S70 Echo v' & $VERSION, 'System je připojen pouze pro čtení.')
	exit
endif

; cmdline
if UBound($cmdline) <> 5 then
	MsgBox(48, 'S70 Echo v' & $VERSION, 'Načtení údajů pacienta z Medicus selhalo.')
	exit
endif

;
; MAIN
;

; logging
logger('Program start: ' & @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC)

; read configuration
if FileExists($config_file) then
	read_config_file($config_file)
	if @error then logger('Načtení konfiguračního souboru selhalo.')
endif

; create archive directory
DirCreate($archive_path)

; archive file full path
global $archive_file = $archive_path & '\' & $cmdline[1] & '.dat'
; export  file full path
global $export_file = $export_path & '\' & get_export_file($export_path, $cmdline[1])

; update history buffer from archive
if FileExists($archive_file) then
	$history = Json_Decode(FileRead($archive_file))
	if @error then logger('Nepodařilo se načíst historii: ' & $cmdline[1] & '.dat')
endif

; update data buffer from export
if FileExists($export_file) then
	$parse = export_parse($export_file, $buffer)
	if @error then
		; error
		FileMove($export_file, $export_file & '.err', 1); overwrite
		if @error then logger('Nepodařilo se načíst export: ' & $cmdline[1] & '.dat')
	else
		; archive
		FileMove($export_file, $export_file & '.old', 1); overwrite
	endif
endif

; update data buffer note from history
if $history then
	for $note in Json _ObjGetKeys($history, '.note')
		Json_Put($buffer, '.note.' & $note, Json_Get($archive, '.note.' & $n))
	next
else
	msgbox(4, 'S70 Echo ' & $VERSION & ' - Historie', 'Historie není dostupná.')
endif

; calculate complex variables
calculate()

; default result template
;if not Json_Get($export, 'result') then
;	if  FileExists($result_file) then
;		$result_text = FileRead($dekurz_file)
;		if @error then
;			logger('Načtení výchozího závěru selhalo: ' & $result_text)
;		else
;			Json_Put($buffer, 'result', $result_text)
;		endif
;endif

;
; GUI
;

$gui = GUICreate("S70 Echo " & $VERSION, 626, 880, 900, 11)

; header
$label_pacient = GUICtrlCreateLabel('Pacient', 60, 9, 40, 17)
$input_pacient = GUICtrlCreateInput($cmdline[3] & ' ' & $cmdline[2], 106, 6, 121, 21, 1); read only
$label_rc = GUICtrlCreateLabel('r.č.', 268, 9, 19, 17)
$input_rc = GUICtrlCreateInput(StringRegExpReplace($cmdline[1], '(^\d{6})(.*)', '$1 \/ $2'), 290, 6, 105, 21, 1); read only
$label_poj = GUICtrlCreateLabel('Poj.', 452, 9, 22, 17)
$input_poj = GUICtrlCreateInput($cmdline[4], 476, 6, 41, 21, 1); read only

; groups
for $group in Json_ObjGetKeys($buffer, '.group')
	GUICtrlCreateGroup(Json_Get($buffer,'.group.' & $group), 8, 32, 610, 65)
	for $member in Json_ObjGetKeys($buffer, '.data.' & $group)
		; data
		GUICtrlCreateLabel(Json_Get($buffer, '.data.' & $member & '.label'), 108, 46, 65, 17)
		Json_Put($buffer, GUICtrlCreateInput(Json_Get($buffer, '.data.' & $member & '.value'), 172, 44, 41, 21, 1)
		GUICtrlCreateLabel(Json_Get($buffer, '.data.' & $member & '.unit'), 218, 46, 100, 17)
		; note
		GUICtrlCreateLabel('Poznámka:', 108, 46, 65, 17)
		Json_Put($buffer, GUICtrlCreateInput(Json_Get($buffer, '.group.' & $member & '.note'), 172, 44, 41, 21, 1)
		; test line break
		; update offset
	next
	GUICtrlCreateGroup('', -99, -99, 1, 1)
next

; dekurz
$label_dekurz = GUICtrlCreateLabel('Závěr:', 15, 722 , 70, 17)
$edit_dekurz = GUICtrlCreateEdit(Json_Get($buffer, '.data.result'), 8, 740, 609, 97, BitOR(64, 4096, 0x00200000)); $ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL

; date
$label_date = GUICtrlCreateLabel('Datum:', 15, 852, 50, 17)
$label_datetime = GUICtrlCreateLabel($runtime, 51, 853, 100, 17)

; button
$button_history = GUICtrlCreateButton('Historie', 305, 846, 75, 25)
$button_tisk = GUICtrlCreateButton('Tisk', 384, 846, 75, 25)
$button_dekurz = GUICtrlCreateButton('Dekurz', 463, 846, 75, 25)
$button_konec = GUICtrlCreateButton('Konec', 542, 846, 75, 25)

; GUI tune
GUICtrlSetBkColor($input_pacient, 0xC0DCC0)
GUICtrlSetBkColor($input_rc, 0xC0DCC0)
GUICtrlSetBkColor($input_poj, 0xC0DCC0)
GUICtrlSetState($button_konec, $GUI_FOCUS)

; GUI display
GUISetState(@SW_SHOW)

; dekurz initialize
$dekurz_init = dekurz_init()
if @error then logger($dekurz_init)

; main loop
While 1
	$msg = GUIGetMsg()
	; generate dekurz clipboard
	if $msg = $button_dekurz then
		$dekurz = dekurz()
		if @error then
			logger($dekurz)
			MsgBox(48, 'S70 Echo v' & $VERSION, 'Generování dekurzu selhalo.')
		endif
	endif
	; print data
	if $msg = $button_tisk Then
		$print = print()
		if @error then
			logger($print)
			MsgBox(48, 'S70 Echo v' & $VERSION, 'Tisk selhal.')
		endif
	endif
	; load history
	if $msg = $button_history Then
		if FileExists($archive_file) then
			if _DateDiff('h', $runtime, Json_Get($archive,'.date') < $HISTORY then
				if msgbox(4, 'S70 Echo ' & $VERSION & ' - Historie', 'Načíst poslední naměřené hodnoty?' & @CRLF & '(Popisy se načítají vždy.)') = 6 then
						
					; update GUI from history
					GUICtrlSetData($input_lk_note, Json_Get($buffer,'.note.lk'))
					; ....
					; ....
				endif
			else
				msgbox(4, 'S70 Echo ' & $VERSION & ' - Historie', 'Nelze načís historii. Příliš stará data.')
			endif	
		else
			MsgBox(48, 'S70 Echo v' & $VERSION, 'Historie není dostupná.')
		endif		
	endif
	; write & exit
	if $msg = $GUI_EVENT_CLOSE or $msg = $button_konec then
		; close dekurz
		_Excel_BookClose($book)
		_Excel_Close($excel)

		; update data buffer
		Json_Put($buffer,'.note.lk', GUICtrlRead($input_lk_note))
		;.....
		;.....
	
		; write data buffer to archive
		$out = FileOpen($archive_file, 2 + 256); UTF8 / BOM
		FileWrite($out, Json_Encode($buffer))
		if @error then logger('Zápis archivu selhal: ' & $cmdline[1] & '.dat')
		FileClose($out)
	endif
wend

;exit
logger('Program exit: ' & @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC)
logger('----')
FileClose($log)

exit

;
; FUNCTION
;

; logging
func logger($text)
	FileWriteLine($log_file, $text)
endfunc

; find export file
func get_export_file($export_path, $rc)
	local $list = _FileListToArray($export_path, '*.txt', 1); files only
	if not @error then
		for $i = 1 to ubound($list) - 1
			if StringRegExp($list[$i], '^' & $rc & '_.*') then return $list[$i]
		next
	endif
endfunc

; read configuration file 
func read_config_file($file)
	local $cfg
	_FileReadToArray($file, $cfg, 0, '='); no count, split by '='
	if @error then return SetError(1)
	for $i = 0 to UBound($cfg) - 1
		if $cfg[$i][0] == 'export' then $export_path = StringRegExpReplace($cfg[$i][1], '\\$', ''); strip trailing backslash
		if $cfg[$i][0] == 'archiv' then $archive_path = StringRegExpReplace($cfg[$i][1], '\\$', ''); strip trailing backslash
		if $cfg[$i][0] == 'history' then $HISTORY = $cfg[$i][1]
	next
endfunc

; parse S70 export file 
func export_parse($file, $buffer)
	local $raw
	_FileReadToArray($file, $raw, 0); no count
	if @error then return SetError(1, 0, 'Nelze načíst souboru exportu.')
	for $group in Json_ObjGetKeys($buffer, '.data')
		for $member in Json_ObjGetKeys($buffer, '.data.' & $group)
			for $i = 0 to UBound($raw) - 1
				if StringRegExp($raw[$i], '^' & $member & '\t.*') then
					Json_Put($buffer, '.data.' & $group & '.' & $member, StringRegExpReplace($raw[$i], '.*\t(.*)\t.*', '$1'))
				endif
			next
		next
	next
endfunc

; calculate aditional variables
calculate()
	if $buffer then
		; LVEF % Teich.
		if Json_Get($buffer, '.data.lk.LVIDd') and Json_Get($buffer, '.data.lk.LVIDs') then
			Json_Put($buffer, '.data.lk.LVEF % Teich', 7/(2.4 + Json_Get($buffer, '.data.lk.LVIDd')/10)*(Json_Get($buffer, '.data.lk.LVIDd')/10)^3 - 7/(2.4 + Json_Get($buffer, '.data.lk.LVIDs')/10)*(Json_Get($buffer, '.data.lk.LVIDs')/10)^3)/(7/(2.4 + Json_Get($buffer, '.data.lk.LVIDd')/10)*(Json_Get($buffer, '.data.lk.LVIDd')/10)^3)*100
		endif
		; LVmass
		if Json_Get($buffer, '.data.lk.LVIDd') and Json_Get($buffer, '.data.lk.IVSd') and Json_Get($buffer, '.data.lk.LVPWd') then
			Json_Put($buffer, '.data.lk.LVmass', 1.04*((Json_get($buffer, '.data.lk.LVIDd')/10 + Json_Get($buffer, '.data.lk.IVSd')/10 + Json_Get($buffer, '.data.lk.LVPWd')/10)^3 - (Json_Get($buffer, '.data.lk.LVIDd')/10)^3) - 13.6
		endif
		; LVmass-i^2,7
		if Json_Get($buffer, '.height') and Json_Get($buffer, '.data.lk.LVmass') then
			Json_Put($buffer, 'data.lk.LVmass-i^2.7', Json_Get($buffer, 'data.lk.LVmass')/(Json_Get($buffer, '.height')/100)^2.7
		endif
		; LVmass-BSA
		if Json_Get($buffer, '.bsa') and Json_Get($buffer, '.data.lk.LVmass') then
			Json_Put($buffer,'.data.lk.LVmass-BSA', Json_Get($buffer, '.data.lk.LVmass')/Json_Get($buffer, '.bsa')
		endif
		; RTW
		if Json_Get($buffer, '.data.lk.LVIDd') and Json_Get($buffer, '.data.lk.LVPWd') then
			Json_Put($buffer, '.data.lk.RTW', (2*Json_Get($buffer, '.data.lk.LVPWd'))/Json_Get($buffer, '.data.lk.LVIDd'))
		endif
		; FS
		if Json_Get($buffer, '.data.lk.LVIDd') and Json_Get($buffer, '.data.lk.LVIDs') then
			Json_Put($buffer, '.data.lk.FS', (Json_Get($buffer, '.data.lk.LVIDd')-Json_Get($buffer, '.data.lk.LVIDs'))/Json_Get($buffer, '.data.lk.LVIDd')*100)
		endif
		; SV-biplane
		if Json_Get($buffer, '.data.lk.SV MOD A2C') and Json_Get($buffer, '.data.lk.SV MOD A4C') then
			Json_Put($buffer,'.data.lk.SV-biplane', (Json_Get($buffer, '.data.lk.SV MOD A4C') + Json_Get($buffer, '.data.lk.SV MOD A2C'))/2)
		endif
		; LAV-A4C
		if Json_Get($buffer, '.data.ls.LAEDV A-L A4C') and Json_Get($buffer, '.data.ls.LAEDV MOD A4C') then
			Json_Put($buffer,'.data.ls.LAV-A4C', (Json_Get($buffer, '.data.ls.LAEDV A-L A4C') + Json_Get($buffer, '.data.ls.LAEDV MOD A4C'))/2)
		endif
	endif

; initialize XLS template
func dekurz_init()
	; excel
	$excel = _Excel_Open(False, False, False, False, True)
	if @error then return SetError(1, 0, 'Nelze spustit aplikaci Excel.')
	$book = _Excel_BookNew($excel)
	if @error then return SetError(1, 0, 'Nelze vytvořit book.')
	; default font
	$book.Activesheet.Range('A1:A21').Font.Size = 6
	; columns height
	$book.Activesheet.Range('A1:A21').RowHeight = 13
	; columns width
	$book.Activesheet.Range('A1').ColumnWidth = 20
	$book.Activesheet.Range('B1').ColumnWidth = 11
	$book.Activesheet.Range('C1').ColumnWidth = 3.5
	$book.Activesheet.Range('D1').ColumnWidth = 9
	$book.Activesheet.Range('E1').ColumnWidth = 3.5
	$book.Activesheet.Range('F1').ColumnWidth = 9
	$book.Activesheet.Range('G1').ColumnWidth = 3.5
	$book.Activesheet.Range('H1').ColumnWidth = 3.5

endFunc

; update XLS data & write clipboard
func dekurz()
	;logger('Generuji dekurz: ' & @MIN & ':' & @SEC)
	;clear the clip
	_ClipBoard_Open(0)
	_ClipBoard_Empty()
	_ClipBoard_Close()

	;loop over group
	; ... groupname
	; ... values
	; ... line
	; ... borders


	; leva komora
	;_Excel_RangeWrite($book, $book.Activesheet, 'Levá komora', 'A3')
	;$book.Activesheet.Range('A3').Font.Bold = True
	;_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_lk_lvedd), 'C3')
	;_Excel_RangeWrite($book, $book.Activesheet, 'LVEDD:', 'B3')
	;$book.Activesheet.Range('B3').HorizontalAlignment = $xlRight;
	;$book.Activesheet.Range('C3').HorizontalAlignment = $xlCenter;
	;_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_lk_lvedd), 'C3')
	;$book.Activesheet.Range('B6:H6').MergeCells = True
	;_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_lk_note), 'B6')
	
	;With $book.Activesheet.Range('A6:H6').Borders(9)
	;	.LineStyle = 1
	;	.Weight = 2
	;EndWith

	; clip
	$range = $book.ActiveSheet.Range('A1:H21')
	_Excel_RangeCopyPaste($book.ActiveSheet,$range)
	if @error then return SetError(1, 0, 'Nelze kopirovat data.')
	;logger('Zápis dokončen: ' & @MIN & ':' & @SEC)
EndFunc

func print()
	local $printer,$printer_error,$marginx,$marginy
	;priner init
	$printer = _PrintDllStart($printer_error)
	if $printer = 0 then return SetError(1, 0, 'Printer error: ' & $printer_error)

	; page title
	_PrintSetDocTitle($printer,"S70 Dekurz - Pacient: " & $cmdline[1])

	; printer create page
	_PrintStartPrint($printer)

	; header
	; ... logo
	; ... address / contact
	; ... patient
	; ... general data
	; ... separator
	; data
	; ... group
	; ... separator
	; ...

	;_PrintSetFont($printer,'Arial',18,0,'bold,underline')
	;_PrintSetFont($printer,'Times New Roman',12,0,'')

	; bmp, jpg, ico 
	;_PrintImage($printer,"logo.bmp",x, y,300,350)

	;_PrintSetLineWid($printer, 2)
	;_PrintLine($printer, x, y x, y)

	;_PrintText($printer, text, x, y)

	;_PrintGetPageHeight($printer)
	;_PrintGetPageWidth($printer)

	; print end data
	_PrintEndPrint($printer)
	_PrintNewPage($printer)
	_printDllClose($printer)
EndFunc

