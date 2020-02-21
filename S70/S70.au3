;
; CMD: S70.exe %RODCISN% %JMENO% %PRIJMENI% %POJ%
;

#AutoIt3Wrapper_Icon=S70.ico
;#AutoIt3Wrapper_UseX64=y
#NoTrayIcon

; INCLUDE

#include <GUIConstantsEx.au3>
;#include <Clipboard.au3>
#include <Excel.au3>
#include <File.au3>

; VAR

$version = '1.2'
$logfile = @ScriptDir & '\' & 'S70.log'
$archive_path = @ScriptDir & '\' & 'archive'
$export_path = @ScriptDir & '\' & 'export'
$current_date = @MDAY & '.' & @MON & '.' & @YEAR & ' ' & @HOUR & ':' & @MIN

global $varlist[] = [ _
'RV Major', 'IVSd', 'LVIDd', 'LVPWd', 'LVIDs', 'LA Diam', 'Ao Diam SVals', 'RVIDd', 'RA Minor', 'RA Major', _
'LA Minor', 'LA Major', 'LAAd A4C', 'LALd A4C', 'LAEDV A-L A4C', 'LAEDV MOD A4C', 'MR Rad' , 'MR Als.Vel', _
'MR Flow', _
'LVIDd Index', 'EDV\(Teich\)', 'EDV\(Cube\)', 'LVd Mass', 'LVd Mass Index', 'LVd Mass \(ASE\)', 'LVd Mass Ind \(ASE\)', _
'LVIDs Index', 'ESV\(Teich\)', 'EF\(Teich\)', 'ESV\(Cube\)', 'EF\(Cube\)', '%FS', 'SV\(Teich\)', 'SI\(Teich\)', 'SV\(Cube\)', _
'SI\(Cube\)', 'LAVi', _
'Ao Diam', 'TV maxPG', 'MV E Vel', 'MV A Vel', 'MV E/A Ratio', 'MV DecT', 'MV PHT', 'EmSept', 'EmLat', 'EmAver', _
'E/Em', 'MR Vmax', 'MR Vmean', 'MR maxPG', 'MR meanPG', 'MR VTI', 'AV Vmax', 'AV Vmean', 'AV Env\.Ti', 'AV VTI', _
'MR Vmax', 'MR VTI', 'MR ERO', 'MR RV' _
]
global $buffer = ObjCreate('Scripting.Dictionary')
$buffer.CompareMode = 0
$buffer.RemoveAll
global $excel, $book
global $dekurz = @ScriptDir & '\' & 'dekurz.txt'

; CONTROL

; create archive
DirCreate($archive_path)
DirCreate($export_path)
; one instance
if UBound(ProcessList(@ScriptName)) > 2 then
	MsgBox(48, 'S70 Echo v' & $version, 'Program byl již spuštěn.')
	exit
endif
; logging
$log = FileOpen($logfile, 1)
if @error then
	MsgBox(48, 'S70 Echo v' & $version, 'System je připojen pouze pro čtení.')
	exit
endif
; cmdline
if UBound($cmdline) <> 5 then
	MsgBox(48, 'S70 Echo v' & $version, 'Načtení dat Medicus selhalo.')
	exit
endif

; GUI

$gui = GUICreate("S70 Echo " & $version, 626, 880, 900, 11)
; header
$label_pacient = GUICtrlCreateLabel('Pacient', 60, 9, 40, 17)
$input_pacient = GUICtrlCreateInput('', 106, 6, 121, 21, 1)
$label_rc = GUICtrlCreateLabel('r.č.', 268, 9, 19, 17)
$input_rc = GUICtrlCreateInput('', 290, 6, 105, 21, 1)
$label_poj = GUICtrlCreateLabel('Poj.', 452, 9, 22, 17)
$input_poj = GUICtrlCreateInput('', 476, 6, 41, 21, 1)
; aorta
$group_aorta = GUICtrlCreateGroup("Aorta", 8, 32, 610, 65)
$label_ao_root = GUICtrlCreateLabel('Kořen aorty:', 108, 46, 70, 17)
$input_ao_root = GUICtrlCreateInput('', 172, 44, 41, 21, 1)
$label_ao_root_unit = GUICtrlCreateLabel('(M<37, Z<33 mm)', 218, 46, 100, 17)
$label_ao_index = GUICtrlCreateLabel('Index:', 358, 46, 30, 17)
$input_ao_index = GUICtrlCreateInput('', 392, 44, 41, 21, 1)
$label_ao_index_unit = GUICtrlCreateLabel('(19+-1 mm/m2)', 440, 46, 80, 17)
$label_ao_note = GUICtrlCreateLabel('Popis:', 70, 74, 80, 17)
$input_ao_note = GUICtrlCreateInput('', 106, 70, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; leva komora
$group_lk = GUICtrlCreateGroup("Levá komora", 8, 100, 610, 113)
$label_lk_lvedd = GUICtrlCreateLabel('LVEDD:', 128, 116, 50, 17)
$input_lk_lvedd = GUICtrlCreateInput('', 172, 112, 41, 21, 1)
$label_lk_lvedd_unit = GUICtrlCreateLabel('(M<58, Z<52 mm)', 218, 116, 100, 17)
$label_lk_lvesd = GUICtrlCreateLabel('LVESD:', 128, 139, 50, 17)
$input_lk_lvesd = GUICtrlCreateInput('', 172, 135, 41, 21, 1)
$label_lk_lvesd_unit = GUICtrlCreateLabel('(M<40, Z<35 mm)', 218, 139, 100, 17)
$label_lk_lvef = GUICtrlCreateLabel('LVEF:', 135, 162, 50, 17)
$input_lk_lvef = GUICtrlCreateInput('', 172, 158, 41, 21, 1)
$label_lk_lvef_unit = GUICtrlCreateLabel('(> 53%), odhadem', 218, 162, 100, 17)
;--------
$label_lk_lveddi = GUICtrlCreateLabel('LVEDDi:', 345, 116, 50, 17)
$input_lk_lveddi = GUICtrlCreateInput('', 392, 112, 41, 21, 1)
$label_lk_lveddi_unit = GUICtrlCreateLabel('(<31 mm/m2)', 440, 116, 100, 17)
$label_lk_ivs = GUICtrlCreateLabel('IVS:', 365, 139, 40, 17)
$input_lk_ivs = GUICtrlCreateInput('', 392, 135, 41, 21, 1)
$label_lk_ivs_unit = GUICtrlCreateLabel('(6-11 mm)', 440, 139, 100, 17)
$label_lk_inferolat = GUICtrlCreateLabel('Inferolat:', 345, 162, 60, 17)
$input_lk_inferolat = GUICtrlCreateInput('', 392, 158, 41, 21, 1)
$label_lk_inferolat_unit = GUICtrlCreateLabel('(6-11)', 440, 162, 100, 17)
;--------
$label_lk_note = GUICtrlCreateLabel('Popis:', 70, 190, 80, 17)
$input_lk_note = GUICtrlCreateInput('', 106, 185, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; leva sin
$group_ls = GUICtrlCreateGroup("Levá síň", 8, 216, 610, 38)
$label_ls_laplax = GUICtrlCreateLabel('LA-PLAX:', 120, 232, 70, 17)
$input_ls_laplax = GUICtrlCreateInput('', 172, 228, 41, 21, 1)
$label_ls_laplax_unit = GUICtrlCreateLabel('(<41 mm)', 218, 232, 100, 17)
$label_ls_lav = GUICtrlCreateLabel('LAV:', 296, 232, 40, 17)
$input_ls_lav = GUICtrlCreateInput('', 326, 228, 41, 21, 1)
$label_ls_lav_unit = GUICtrlCreateLabel('(ml)', 374, 232, 100, 17)
$label_ls_lavi = GUICtrlCreateLabel('LAV-i:', 440, 232, 40, 17)
$input_ls_lavi = GUICtrlCreateInput('', 476, 228, 41, 21, 1)
$label_ls_lavi_unit = GUICtrlCreateLabel('(<34 ml/m2)', 524, 232, 80, 17)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; prava komora
$group_pk = GUICtrlCreateGroup("Pravá komora", 8, 257, 610, 38)
$label_pk_rveddplax = GUICtrlCreateLabel('RVEDD-PLAX:', 94, 273, 70, 17)
$input_pk_rveddplax = GUICtrlCreateInput('', 172, 269, 41, 21, 1)
$label_pk_rveddplax_unit = GUICtrlCreateLabel('(<31 mm)', 218, 273, 100, 17)
$label_pk_kinetika = GUICtrlCreateLabel('TAPSE:', 280, 273, 40, 17)
$input_pk_kinetika = GUICtrlCreateInput('', 326, 269, 41, 21, 1)
$label_pk_kinetika_unit = GUICtrlCreateLabel('(mm)', 374, 273, 100, 17)
$label_pk_rvd1 = GUICtrlCreateLabel('RVD1:', 436, 273, 40, 17)
$input_pk_rvd1 = GUICtrlCreateInput('', 476, 269, 41, 21, 1)
$label_pk_rvd1_unit = GUICtrlCreateLabel('(mm)', 524, 273, 80, 17)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; prava sin
$group_ps = GUICtrlCreateGroup("Pravá síň", 8, 298, 610, 38)
$label_ps_raa4c = GUICtrlCreateLabel('RA-A4C:', 124, 314, 50, 17)
$input_ps_raa4c = GUICtrlCreateInput('', 172, 310, 41, 21, 1)
$label_ps_raa4c_unit = GUICtrlCreateLabel('(<50 mm)', 218, 314, 100, 17)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; aortalni chlopen
$group_ach = GUICtrlCreateGroup("Aortální chlopeň", 8, 339, 610, 40)
$label_ach_note = GUICtrlCreateLabel('Popis:', 70, 355, 80, 17)
$input_ach_note = GUICtrlCreateInput('', 106, 352, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; mitralni chlopen
$group_mch = GUICtrlCreateGroup("Mitrální chlopeň", 8, 382, 610, 113)
$label_mch_es = GUICtrlCreateLabel("E':", 152, 398, 15, 17)
$input_mch_es = GUICtrlCreateInput('', 172, 394, 41, 21, 1)
$label_mch_es_unit = GUICtrlCreateLabel('(cm/s)', 218, 398, 30, 17)
$label_mch_ee = GUICtrlCreateLabel("E/E':", 140, 421, 30, 17)
$input_mch_ee = GUICtrlCreateInput('', 172, 417, 41, 21, 1)
$label_mch_e = GUICtrlCreateLabel('E:', 153, 443, 15, 17)
$input_mch_e = GUICtrlCreateInput('', 172, 440, 41, 21, 1)
$label_mch_e_unit = GUICtrlCreateLabel('(m/s)', 218, 443, 25, 17)
;--------
$label_mch_dt = GUICtrlCreateLabel('DT:', 367, 398, 25, 17)
$input_mch_dt = GUICtrlCreateInput('', 392, 394, 41, 21, 1)
$label_mch_dt_unit = GUICtrlCreateLabel('(ms)', 440, 398, 30, 17)
$label_mch_a = GUICtrlCreateLabel('A:', 373, 421, 15, 17)
$input_mch_a = GUICtrlCreateInput('', 392, 417, 41, 21, 1)
$label_mch_a_unit = GUICtrlCreateLabel('(m/s)', 440, 421, 30, 17)
$label_mch_ea = GUICtrlCreateLabel('E/A:', 362, 443, 30, 17)
$input_mch_ea = GUICtrlCreateInput('', 392, 440, 41, 21, 1)
;--------
$label_mch_note = GUICtrlCreateLabel('Popis:', 70, 468, 80, 17)
$input_mch_note = GUICtrlCreateInput('', 106, 467, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; trikuspidalni chlopen
$group_trikuspidal = GUICtrlCreateGroup("Trikuspidální chlopeň", 8, 498, 610, 65)
$label_tch_pg = GUICtrlCreateLabel('PGmax-reg:', 110, 512, 70, 17)
$input_tch_pg = GUICtrlCreateInput('', 172, 509, 41, 21, 1)
$label_tch_pg_unit = GUICtrlCreateLabel('(mmHg)', 218, 512, 100, 17)
$label_tch_ddz = GUICtrlCreateLabel('DDŽ:', 358, 512, 30, 17)
$input_tch_ddz = GUICtrlCreateInput('', 392, 509, 41, 21, 1)
$label_tch_ddz_unit = GUICtrlCreateLabel('(mm)', 440, 512, 80, 17)
$label_tch_note = GUICtrlCreateLabel('Popis:', 70, 538, 80, 17)
$input_tch_note = GUICtrlCreateInput('', 106, 535, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; pulmonalni chlopen
$group_pulmonal = GUICtrlCreateGroup("Pulmonární chlopeň", 8, 566, 610, 65)
$label_pch_pg = GUICtrlCreateLabel('V max:', 134, 581, 50, 17)
$input_pch_pg = GUICtrlCreateInput('', 172, 577, 41, 21, 1)
$label_pch_pg_unit = GUICtrlCreateLabel('(m/s)', 218, 581, 100, 17)
$label_pch_note = GUICtrlCreateLabel('Popis:', 70, 602, 80, 17)
$input_pch_note = GUICtrlCreateInput('', 106, 603, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; perikard
$group_perikard = GUICtrlCreateGroup("Perikard", 8, 634, 610, 40)
$label_perikard_note = GUICtrlCreateLabel('Popis:', 70, 650, 80, 17)
$input_perikard_note = GUICtrlCreateInput('', 106, 647, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; jine
$group_other = GUICtrlCreateGroup("Jiné", 8, 677, 610, 40)
$label_other_note = GUICtrlCreateLabel('Popis:', 70, 693, 80, 17)
$input_other_note = GUICtrlCreateInput('', 106, 690, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; dekurz
$label_dekurz = GUICtrlCreateLabel('Závěr:', 15, 722 , 70, 17)
$edit_dekurz = GUICtrlCreateEdit('', 8, 740, 609, 97, BitOR(64, 4096, 0x00200000)); $ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL
; date
$label_date = GUICtrlCreateLabel('Datum:', 15, 852, 50, 17)
$label_datetime = GUICtrlCreateLabel('', 51, 853, 100, 17)
; button
$button_tisk = GUICtrlCreateButton('Tisk', 384, 846, 75, 25)
$button_dekurz = GUICtrlCreateButton('Dekurz', 463, 846, 75, 25)
$button_konec = GUICtrlCreateButton('Konec', 542, 846, 75, 25)

; GUI tune

GUICtrlSetBkColor($input_pacient, 0xC0DCC0)
GUICtrlSetBkColor($input_rc, 0xC0DCC0)
GUICtrlSetBkColor($input_poj, 0xC0DCC0)
GUICtrlSetState($button_konec, $GUI_FOCUS)
GUICtrlSetData($label_datetime, $current_date)

; MAIN

; logging
logger('Program begin: ' & @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC)

; cmdline
if UBound($cmdline) == 5 then
	GUICtrlSetData($input_pacient, $cmdline[3] & ' ' & $cmdline[2])
	GUICtrlSetData($input_rc, StringRegExpReplace($cmdline[1], '(^\d{6})(.*)', '$1 \/ $2'))
	GUICtrlSetData($input_poj, $cmdline[4])
endif

; export / history
$export_file = file_from_export($export_path, $cmdline[1])
if $export_file then
	export_parse($export_path & '\' & $export_file, $buffer)
	if @error Then logger('Nepodařilo se zpracovat export: ' & $export_file)
	;FileDelete($export_path & '\' & $export_file)
elseif FileExists($archive_path & '\' & $cmdline[1] & '.dat') Then
	if msgbox(4, 'S70 Echo ' & $version & ' - Historie', 'Načíst poslední záznam?') = 6 then
		$raw = StringSplit(FileRead($archive_path & '\' & $cmdline[1] & '.dat'), '|', 2)
		if @error then logger('Nepodařilo se načíst historii: ' & $cmdline[1] & '.dat')
		$list_to_dict = list_to_dict($raw, $buffer)
	endif
endif

; Fill GUI & Default

if $buffer.Exists('IVSd') then GUICtrlSetData($input_lk_ivs, $buffer.Item('IVSd'))
GUICtrlSetData($edit_dekurz, 'Levá komora nedilatovaná, není hypertrofická, s normální celkovou systolickou funkcí (EFLK odhad >65%), bez  hrubší regionální poruchy kinetiky, diastolická funkce v normě,levá síň nedilatovaná, mitrální chlopeň jemná, stopová  mitrální regurgitace, aortální chlopeň trojcípá, jemná, bez vady, norm. vel. ascend. aorty, pravá komora nedilatovaná, s normální systolickou funkcí, pravá síň nedilatovaná, stopová pulmonální  a  trikuspidální regurgitace, odhadovaný systolický tlak v plicnici nezvýšen, VCI nedilatovaná, kolabuje nad 50% s respirací, perikard bez patologické separace.'& @CRLF & @CRLF & 'Závěr:  Dobrá syst. i diast. fce obou nedil. komor, ost. srd. oddíly nedilat, chlopenní aparát bez významnější valvulopatie, tenze v plicnici nezvýšena.')

; GUI

GUISetState(@SW_SHOW)

While 1
	$msg = GUIGetMsg()
	if $msg = $button_dekurz then
		dekurz()
		if @error then logger('Nepodařolo se vygenerovat dekurz.')
	EndIf
	if $msg = $button_tisk Then
		dekurz_print(StringRegExpReplace($cmdline[1], '(^\d{6})(.*)', '$1 \/ $2'), $cmdline[3] & ' ' & $cmdline[2], $current_date)
		if @error then logger('Nepodařolo se vytisknout dekurz.')
	endif
	if $msg = $GUI_EVENT_CLOSE or $msg = $button_konec then
		; close dekurz
		_Excel_BookClose($book)
		_Excel_Close($excel)
		;update data
		if GUICtrlRead($input_lk_ivs) then
			if $buffer.Exists('IVSd') then $buffer.Remove('IVSd')
			$buffer.Add('IVSd', GUICtrlRead($input_lk_ivs))
		endif
		;update archive
		$f = FileOpen($archive_path & '\' & $cmdline[1] & '.dat', 2)
		dict_to_file($f, $buffer)
		FileClose($f)
		exitloop
	endif
wend

logger('Program exit: ' & @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC)
FileClose($log)
exit

; FUNC

func logger($text)
	FileWriteLine($logfile, $text)
endfunc

func file_from_export($path, $id)
	local $list = _FileListToArray($path, '*.txt')
	if not @error then
		for $i = 1 to ubound($list) - 1
			if StringRegExp($list[$i], '^' & $id & '_.*') then return $list[$i]
		next
	endif
endfunc

func list_to_dict($list, $buffer)
	for $i = 0 to UBound($list) / 2 - 1
		$buffer.Add(String($list[2 * $i]), $list[2 * $i + 1])
	next
endfunc

func dict_to_file($file, $buffer)
	local $keys = $buffer.keys
	local $str
	for $i = 0 to UBound($keys) - 1
		$str &= '|' & $keys[$i] & '|' & $buffer($keys[$i])
	next
	FileWrite($file, StringTrimLeft($str, 1)); update
	if @error then Return SetError(1, 0, 'Zápis selhal.')
endfunc

func export_parse($file, $buffer)
		local $raw
		_FileReadToArray($file, $raw, 0)
		if @error then return SetError(1, 0, 'Nelze načíst soubor exportu.')
		for $i = 0 to UBound($varlist) - 1
			for $j = 0 to UBound($raw) - 1
				if StringRegExp($raw[$j], '^' & $varlist[$i] & '\t.*') then
					$key = String($varlist[$i])
					if $buffer.Exists($varlist[$i]) Then $buffer.Remove($varlist[$i])
					$buffer.Add($varlist[$i], StringRegExpReplace($raw[$j], '.*\t(.*)\t.*', '$1'))
				EndIf
			next
		next
endfunc

func dekurz()
	;clear the clip
	;_ClipBoard_Open(0)
	;_ClipBoard_Empty()
	;_ClipBoard_Close()
	; excel
	$excel = _Excel_Open(False, False, False, False, False)
	;$excel = _Excel_Open()
	if @error then logger('Nelze spustit aplikaci Excel.')
	$book = _Excel_BookNew($excel)
	if @error Then logger('Nelze vytvořit book.')
	; style
	$book.Activesheet.Range('B1').ColumnWidth = 15
	; aorta
	_Excel_RangeWrite($book, $book.Activesheet, 'Aorta', 'A1')
	$book.Activesheet.Range('A1').Font.Bold = True
	_Excel_RangeWrite($book, $book.Activesheet, 'Kořen aorty:', 'B1')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_ao_root), 'C1')
	_Excel_RangeWrite($book, $book.Activesheet, 'Popis:', 'B2')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_ao_note), 'C2')
	With $book.Activesheet.Range('A2:C2').Borders(9)
		.LineStyle = 1
		.Weight = 2
	EndWith
	; clip
	$range = $book.ActiveSheet.Range('A1:C2')
	_Excel_RangeCopyPaste($book.ActiveSheet,$range)
	if @error Then logger('Nelze kopirovat data.')
EndFunc

func dekurz_print($rc,$name,$date)
	$f = FileOpen($dekurz, 256 + 2); UTF no BOM overwrite
	if @error then logger('Nemuzu otevrit dekurz.txt.')
	FileWriteLine($f, 'Pacient:      Tomas Okurka')
	FileWriteLine($f, 'Rodne cislo: 123456/1234')
	FileWriteLine($f, '----------------------------------------------------------------------------------')
	FileWriteLine($f, 'Aorta')
	FileWriteLine($f, '               Koren Auroty: 15 mm          Index: 14')
	FileWriteLine($f, '               Popis: Je to v pohode.')
	FileWriteLine($f, '----------------------------------------------------------------------------------')
	FileWriteLine($f, 'Mitrálni chlopeň')
	FileWriteLine($f, '               LVEDD: 13 (< 25 mm/m2)   LVDi: 14 (cm)     Index: 16')
	FileWriteLine($f, '----------------------------------------------------------------------------------')
	FileWriteLine($f, 'Pulmonárni')
	FileWriteLine($f, '               LVEDD: 13 (< 25 mm/m2)   LVDi: 14 (cm)     Index: 16')
	FileWriteLine($f, '----------------------------------------------------------------------------------')
	FileClose($f)
	_FilePrint($dekurz)
	if @error then logger('Nemuzu tisknout..')
	FileDelete($dekurz)
EndFunc
