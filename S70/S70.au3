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

$VERSION = '1.4'
$HISTORY = 24; stored data age in hours

global $log_file = @ScriptDir & '\' & 'S70.log'
global $config_file = @ScriptDir & '\' & 'S70.ini'
global $result_file = @ScriptDir & '\' & 'result.txt'; default result text
global $runtime = @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC

;default path
global $export_path = 'c:\ECHOREPORTY'
global $archive_path = @ScriptDir & '\' & 'archive'

;
; DATA
;

global $note_list[] = ['AONOTE','LKNOTE','ACHNOTE','MCHNOTE','TCHNOTE','PCHNOTE','PNOTE','ONOTE']
global $varlist[]=[ _
'RV Major', 'RVIDd', 'S-RV', 'EDA', 'ESA', 'FAC%', 'TAPSE', _; pk
'RA Minor', 'RA Major', 'RAV', 'RAVi', _; ps
'IVSd', 'LVIDd', 'LVPWd', 'LVIDs', 'EF Biplane', 'SV MOD A4C', 'SV MOD A2C', 'LVEDV MOD BP', 'LVESV MOD BP', _; lk
'LA Diam', 'LAEDV A-L A4C', 'LAEDV MOD A4C', 'LAEDV A-L A2C', 'LAEDV MOD A2C', 'LA Minor', 'LA Major', 'LAVi', _; ls
'Ao Diam SVals', 'Ao Diam', _; ao
'LVOT Diam', 'AR Rad', 'PV Vmax', 'AV Vmax', 'AV maxPG', 'AV meanPG', 'AV VTI', 'LVOT VTI', 'AR VTI', 'AR ERO', 'AR RV', _; aoch
'MR Rad', 'MV E Vel', 'MV A Vel', 'MV E/A Ratio', 'MV DecT','MV1 PHT', 'MV maxPG', 'MV meanPG', 'EmSept', 'EmLat', 'MR VTI', 'MR ERO', 'MR RV', _; mitch
'PV Vmax', 'PVAcc T', 'PV maxPG', 'PV meanPG', 'PRend PG', 'PR maxPG', 'PR meanPG', _; pulmch
'IVC Diam Exp', 'IVC diam Ins' _; other
]

global $excel, $book

; data dictionary buffer
$buffer = ObjCreate('Scripting.Dictionary')
$buffer.CompareMode = 0
$buffer.RemoveAll

; note dictionary buffer
$buffer_note = ObjCreate('Scripting.Dictionary')
$buffer_note.CompareMode = 0
$buffer_note.RemoveAll

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

global $archive_file = $archive_path & '\' & $cmdline[1] & '.dat'
global $export_file = get_export_file($export_path, $cmdline[1])

; logging
logger('Program start: ' & @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC)

; update paths from conifguration
if FileExists($config_file) then
	read_config_file($config_file)
	if @error then logger('Načtení konfiguračního souboru selhalo.')
endif

; create dirs
DirCreate($archive_path)
DirCreate($export_path)

; read note buffer from history
if FileExists($archive_file) then
	$raw_note = StringSplit(FileReadLine($archive_file, 2), '|', 2)
	if @error then
		logger('Nepodařilo se načíst historii popisů: ' & $cmdline[1] & '.dat')
	else
		list_to_dict($raw_note, $buffer_note)
	endif
endif

; read default result
if FileExists($result_file) then
	$result_text = StringSplit(FileRead($dekurz_file)
	if @error then
		$result_text = ''
		logger('Nepodařilo se načíst výchozí závěr: ' & $result_file)
	endif
endif

; write export to buffer
if $export_file then
	$export = export_parse($export_path & '\' & $export_file, $buffer)
	if @error then logger($export & ': ' & $export_file)
	;FileDelete($export_path & '\' & $export_file)

; update buffer from history
elseif FileExists($archive_file) then
	$c_time = FileGetTime($archive_file)
	if @error then
		logger('Nepodařilo se získat časové razítko souboru: ' & $cmdline[1] & '.dat')
	else
		$file_time = $c_time[0] & '/' & $c_time[1] & '/' & $c_time[2] & ' ' & $c_time[3] & ':' & $c_time[4] & ':' & $c_time[5]
		if _DateDiff('h', $file_time, $runtime) < $HISTORY then
			if msgbox(4, 'S70 Echo ' & $VERSION & ' - Historie', 'Načíst poslední hodnoty?') = 6 then
				$raw_data = StringSplit(FileReadLine($archive_path & '\' & $cmdline[1] & '.dat', 1), '|', 2)
				if @error then
					logger('Nepodařilo se načíst historii dat: ' & $cmdline[1] & '.dat')
				else
					list_to_dict($raw_data, $buffer)
				endif
			endif
		endif
	endif
endif

;
; GUI
;

$gui = GUICreate("S70 Echo " & $VERSION, 626, 880, 900, 11)
; header
$label_pacient = GUICtrlCreateLabel('Pacient', 60, 9, 40, 17)
$input_pacient = GUICtrlCreateInput($cmdline[3] & ' ' & $cmdline[2], 106, 6, 121, 21, 1)
$label_rc = GUICtrlCreateLabel('r.č.', 268, 9, 19, 17)
$input_rc = GUICtrlCreateInput(StringRegExpReplace($cmdline[1], '(^\d{6})(.*)', '$1 \/ $2'), 290, 6, 105, 21, 1)
$label_poj = GUICtrlCreateLabel('Poj.', 452, 9, 22, 17)
$input_poj = GUICtrlCreateInput($cmdline[4], 476, 6, 41, 21, 1)
; aorta
$group_aorta = GUICtrlCreateGroup('Aorta', 8, 32, 610, 65)
$label_ao_root = GUICtrlCreateLabel('Kořen aorty:', 108, 46, 65, 17)
$input_ao_root = GUICtrlCreateInput('', 172, 44, 41, 21, 1)
$label_ao_root_unit = GUICtrlCreateLabel('(M<37, Z<33 mm)', 218, 46, 100, 17)
$label_ao_index = GUICtrlCreateLabel('Index:', 358, 46, 30, 17)
$input_ao_index = GUICtrlCreateInput('', 392, 44, 41, 21, 1)
$label_ao_index_unit = GUICtrlCreateLabel('(19+-1 mm/m2)', 440, 46, 80, 17)
$label_ao_note = GUICtrlCreateLabel('Popis:', 70, 74, 30, 17)
$input_ao_note = GUICtrlCreateInput($buffer_note.Item('AONOTE'), 106, 70, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; leva komora
$group_lk = GUICtrlCreateGroup('Levá komora', 8, 100, 610, 113)
$label_lk_lvedd = GUICtrlCreateLabel('LVEDD:', 128, 116, 45, 17)
$input_lk_lvedd = GUICtrlCreateInput('', 172, 112, 41, 21, 1)
$label_lk_lvedd_unit = GUICtrlCreateLabel('(M<58, Z<52 mm)', 218, 116, 100, 17)
$label_lk_lvesd = GUICtrlCreateLabel('LVESD:', 128, 139, 45, 17)
$input_lk_lvesd = GUICtrlCreateInput('', 172, 135, 41, 21, 1)
$label_lk_lvesd_unit = GUICtrlCreateLabel('(M<40, Z<35 mm)', 218, 139, 100, 17)
$label_lk_lvef = GUICtrlCreateLabel('LVEF:', 135, 162, 30, 17)
$input_lk_lvef = GUICtrlCreateInput('', 172, 158, 41, 21, 1)
$label_lk_lvef_unit = GUICtrlCreateLabel('(> 53%), odhadem', 218, 162, 100, 17)
;--------
$label_lk_lveddi = GUICtrlCreateLabel('LVEDDi:', 345, 116, 45, 17)
$input_lk_lveddi = GUICtrlCreateInput('', 392, 112, 41, 21, 1)
$label_lk_lveddi_unit = GUICtrlCreateLabel('(<31 mm/m2)', 440, 116, 100, 17)
$label_lk_ivs = GUICtrlCreateLabel('IVS:', 365, 139, 30, 17)
$input_lk_ivs = GUICtrlCreateInput('', 392, 135, 41, 21, 1)
$label_lk_ivs_unit = GUICtrlCreateLabel('(6-11 mm)', 440, 139, 100, 17)
$label_lk_inferolat = GUICtrlCreateLabel('Inferolat:', 345, 162, 50, 17)
$input_lk_inferolat = GUICtrlCreateInput('', 392, 158, 41, 21, 1)
$label_lk_inferolat_unit = GUICtrlCreateLabel('(6-11)', 440, 162, 100, 17)
;--------
$label_lk_note = GUICtrlCreateLabel('Popis:', 70, 190, 30, 17)
$input_lk_note = GUICtrlCreateInput($buffer_note.Item('LKNOTE'), 106, 185, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; leva sin
$group_ls = GUICtrlCreateGroup('Levá síň', 8, 216, 610, 38)
$label_ls_laplax = GUICtrlCreateLabel('LA-PLAX:', 120, 232, 50, 17)
$input_ls_laplax = GUICtrlCreateInput('', 172, 228, 41, 21, 1)
$label_ls_laplax_unit = GUICtrlCreateLabel('(<41 mm)', 218, 232, 100, 17)
$label_ls_lav = GUICtrlCreateLabel('LAV:', 296, 232, 30, 17)
$input_ls_lav = GUICtrlCreateInput('', 326, 228, 41, 21, 1)
$label_ls_lav_unit = GUICtrlCreateLabel('(ml)', 374, 232, 100, 17)
$label_ls_lavi = GUICtrlCreateLabel('LAV-i:', 440, 232, 35, 17)
$input_ls_lavi = GUICtrlCreateInput('', 476, 228, 41, 21, 1)
$label_ls_lavi_unit = GUICtrlCreateLabel('(<34 ml/m2)', 524, 232, 80, 17)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; prava komora
$group_pk = GUICtrlCreateGroup('Pravá komora', 8, 257, 610, 38)
$label_pk_rveddplax = GUICtrlCreateLabel('RVEDD-PLAX:', 94, 273, 70, 17)
$input_pk_rveddplax = GUICtrlCreateInput('', 172, 269, 41, 21, 1)
$label_pk_rveddplax_unit = GUICtrlCreateLabel('(<31 mm)', 218, 273, 100, 17)
$label_pk_tapse = GUICtrlCreateLabel('TAPSE:', 280, 273, 40, 17)
$input_pk_tapse = GUICtrlCreateInput('', 326, 269, 41, 21, 1)
$label_pk_tapse_unit = GUICtrlCreateLabel('(mm)', 374, 273, 100, 17)
$label_pk_rvd1 = GUICtrlCreateLabel('RVD1:', 436, 273, 40, 17)
$input_pk_rvd1 = GUICtrlCreateInput('', 476, 269, 41, 21, 1)
$label_pk_rvd1_unit = GUICtrlCreateLabel('(mm)', 524, 273, 80, 17)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; prava sin
$group_ps = GUICtrlCreateGroup('Pravá síň', 8, 298, 610, 38)
$label_ps_raa4c = GUICtrlCreateLabel('RA-A4C:', 124, 314, 50, 17)
$input_ps_raa4c = GUICtrlCreateInput('', 172, 310, 41, 21, 1)
$label_ps_raa4c_unit = GUICtrlCreateLabel('(<50 mm)', 218, 314, 100, 17)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; aortalni chlopen
$group_ach = GUICtrlCreateGroup('Aortální chlopeň', 8, 339, 610, 40)
$label_ach_note = GUICtrlCreateLabel('Popis:', 70, 355, 30, 17)
$input_ach_note = GUICtrlCreateInput($buffer_note.Item('ACHNOTE'), 106, 352, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; mitralni chlopen
$group_mch = GUICtrlCreateGroup('Mitrální chlopeň', 8, 382, 610, 113)
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
$label_mch_note = GUICtrlCreateLabel('Popis:', 70, 468, 30, 17)
$input_mch_note = GUICtrlCreateInput($buffer_note.Item('MCHNOTE'), 106, 467, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; trikuspidalni chlopen
$group_trikuspidal = GUICtrlCreateGroup('Trikuspidální chlopeň', 8, 498, 610, 65)
$label_tch_pg = GUICtrlCreateLabel('PGmax-reg:', 110, 512, 65, 17)
$input_tch_pg = GUICtrlCreateInput('', 172, 509, 41, 21, 1)
$label_tch_pg_unit = GUICtrlCreateLabel('(mmHg)', 218, 512, 100, 17)
$label_tch_ddz = GUICtrlCreateLabel('DDŽ:', 358, 512, 30, 17)
$input_tch_ddz = GUICtrlCreateInput('', 392, 509, 41, 21, 1)
$label_tch_ddz_unit = GUICtrlCreateLabel('(mm)', 440, 512, 80, 17)
$label_tch_note = GUICtrlCreateLabel('Popis:', 70, 538, 30, 17)
$input_tch_note = GUICtrlCreateInput($buffer_note.Item('TCHNOTE'), 106, 535, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; pulmonalni chlopen
$group_pulmonal = GUICtrlCreateGroup('Pulmonární chlopeň', 8, 566, 610, 65)
$label_pch_vmax = GUICtrlCreateLabel('V max:', 134, 581, 40, 17)
$input_pch_vmax = GUICtrlCreateInput('', 172, 577, 41, 21, 1)
$label_pch_vmax_unit = GUICtrlCreateLabel('(m/s)', 218, 581, 100, 17)
$label_pch_note = GUICtrlCreateLabel('Popis:', 70, 602, 30, 17)
$input_pch_note = GUICtrlCreateInput($buffer_note.Item('PCHNOTE'), 106, 603, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; perikard
$group_perikard = GUICtrlCreateGroup('Perikard', 8, 634, 610, 40)
$label_perikard_note = GUICtrlCreateLabel('Popis:', 70, 650, 30, 17)
$input_perikard_note = GUICtrlCreateInput($buffer_note.Item('PNOTE'), 106, 647, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; jine
$group_other = GUICtrlCreateGroup('Jiné', 8, 677, 610, 40)
$label_other_note = GUICtrlCreateLabel('Popis:', 70, 693, 30, 17)
$input_other_note = GUICtrlCreateInput($buffer_note.Item('ONOTE'), 106, 690, 506, 21)
GUICtrlCreateGroup('', -99, -99, 1, 1)
; dekurz
$label_dekurz = GUICtrlCreateLabel('Závěr:', 15, 722 , 70, 17)
$edit_dekurz = GUICtrlCreateEdit($result_text, 8, 740, 609, 97, BitOR(64, 4096, 0x00200000)); $ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL
; date
$label_date = GUICtrlCreateLabel('Datum:', 15, 852, 50, 17)
$label_datetime = GUICtrlCreateLabel($runtime, 51, 853, 100, 17)
; button
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
		$prn = print($cmdline[1], $cmdline[3] & ' ' & $cmdline[2], $runtime)
		if @error then
			logger($prn)
			MsgBox(48, 'S70 Echo v' & $VERSION, 'Tisk selhal.')
		endif
	endif
	; write & exit
	if $msg = $GUI_EVENT_CLOSE or $msg = $button_konec then

		; close dekurz
		_Excel_BookClose($book)
		_Excel_Close($excel)
		; update data
		$buffer.Item('IVSd') = GUICtrlRead($input_lk_ivs)
		;....
		;....
		;
		; update note
		$buffer_note.Item('AONOTE') = GUICtrlRead($input_ao_note)
		$buffer_note.Item('LKNOTE') = GUICtrlRead($input_lk_note)
		$buffer_note.Item('ACHNOTE') = GUICtrlRead($input_ach_note)
		$buffer_note.Item('MCHNOTE') = GUICtrlRead($input_mch_note)
		$buffer_note.Item('TCHNOTE') = GUICtrlRead($input_tch_note)
		$buffer_note.Item('PCHNOTE') = GUICtrlRead($input_pch_note)
		$buffer_note.Item('PNOTE') = GUICtrlRead($input_perikard_note)
		$buffer_note.Item('ONOTE') = GUICtrlRead($input_other_note)
	
		; write archive
		$f = FileOpen($archive_path & '\' & $cmdline[1] & '.dat', 2 + 256); UTF8 / BOM
		$write_data = dict_to_file($f, $buffer)
		if @error then logger($write_data & ': ' & $cmdline[1] & '.dat')
		$write_note = dict_to_file($f, $buffer_note)
		if @error then logger($write_note & ': ' & $cmdline[1] & '.dat')
		FileClose($f)
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

func logger($text)
	FileWriteLine($log_file, $text)
endfunc

func get_export_file($export_path, $rc)
	local $list = _FileListToArray($export_path, '*.txt')
	if not @error then; _ArraySearch()?
		for $i = 1 to ubound($list) - 1
			if StringRegExp($list[$i], '^' & $rc & '_.*') then return $list[$i]
		next
	endif
endfunc

;func space_align($str, $cnt, $right = True)
;	if $right then
;		return $str & _StringRepeat(' ', $cnt)
;	else
;		return _StringRepeat(' ', $cnt) & $str
;	endif
;endfunc

;read list to dict
func list_to_dict($list, $buffer)
	for $i = 0 to UBound($list) / 2 - 1
		$buffer.Add(String($list[2 * $i]), $list[2 * $i + 1])
	next
endfunc

;write dict to file
func dict_to_file($file, $buffer)
	local $str, $keys = $buffer.keys
	for $i = 0 to UBound($keys) - 1
		$str &= '|' & $keys[$i] & '|' & $buffer($keys[$i])
	next
	FileWrite($file, StringTrimLeft($str, 1)); update
	if @error then Return SetError(1, 0, 'Zápis selhal.')
endfunc

; parse S70 txt file 
func export_parse($file, $buffer)
	local $raw
	_FileReadToArray($file, $raw, 0); no count
	if @error then return SetError(1, 0, 'Nelze načíst soubor exportu.')
	for $i = 0 to UBound($varlist) - 1
		for $j = 0 to UBound($raw) - 1
			if StringRegExp($raw[$j], '^' & $varlist[$i] & '\t.*') then
				if $buffer.Exists($varlist[$i]) then $buffer.Remove($varlist[$i])
				$buffer.Add($varlist[$i], StringRegExpReplace($raw[$j], '.*\t(.*)\t.*', '$1'))
			EndIf
		next
	next
endfunc

; read configuration file 
func read_config_file($file)
	local $cfg
	_FileReadToArray($file, $cfg, 0, '='); no count; split by '='
	if @error then return SetError(1)
	for $i = 0 to UBound($cfg) - 1
		if $cfg[$i][0] == 'export' then $export_path = $cfg[$i][1]
		if $cfg[$i][0] == 'archiv' then $archive_path = $cfg[$i][1]
	next
endfunc

; initialize XLS template
func dekurz_init()
	; excel
	$excel = _Excel_Open(False, False, False, False, True)
	if @error then return SetError(1, 0, 'Nelze spustit aplikaci Excel.')
	$book = _Excel_BookNew($excel)
	if @error then return SetError(1, 0, 'Nelze vytvořit book.')
	; styling
	$book.Activesheet.Range('A1').ColumnWidth = 20
	$book.Activesheet.Range('B1').ColumnWidth = 11
	$book.Activesheet.Range('C1').ColumnWidth = 3.5
	$book.Activesheet.Range('D1').ColumnWidth = 9
	$book.Activesheet.Range('E1').ColumnWidth = 3.5
	$book.Activesheet.Range('F1').ColumnWidth = 9
	$book.Activesheet.Range('G1').ColumnWidth = 3.5
	$book.Activesheet.Range('H1').ColumnWidth = 3.5
	$book.Activesheet.Range('A1:A21').RowHeight = 13
	; aorta
	_Excel_RangeWrite($book, $book.Activesheet, 'Aorta', 'A1')
	$book.Activesheet.Range('A1').Font.Bold = True
	_Excel_RangeWrite($book, $book.Activesheet, 'Kořen aorty:', 'B1')
	$book.Activesheet.Range('B1').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('C1').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, 'Index:', 'D1')
	$book.Activesheet.Range('D1').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('E1').HorizontalAlignment = $xlCenter;
	$book.Activesheet.Range('B2:H2').MergeCells = True
	With $book.Activesheet.Range('A2:H2').Borders(9)
		.LineStyle = 1
		.Weight = 2
	EndWith
	; leva komora
	_Excel_RangeWrite($book, $book.Activesheet, 'Levá komora', 'A3')
	$book.Activesheet.Range('A3').Font.Bold = True
	_Excel_RangeWrite($book, $book.Activesheet, 'LVEDD:', 'B3')
	$book.Activesheet.Range('B3').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('C3').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, 'LVEDDi:', 'D3')
	$book.Activesheet.Range('D3').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('E3').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, 'LVESD:', 'B4')
	$book.Activesheet.Range('B4').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('C4').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, 'IVS:', 'D4')
	$book.Activesheet.Range('D4').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('E4').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, 'LVEF:', 'B5')
	$book.Activesheet.Range('B5').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('C5').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, 'Inferolat:', 'D5')
	$book.Activesheet.Range('D5').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('E5').HorizontalAlignment = $xlCenter;
	$book.Activesheet.Range('B6:H6').MergeCells = True
	With $book.Activesheet.Range('A6:H6').Borders(9)
		.LineStyle = 1
		.Weight = 2
	EndWith
	; leva sin
	_Excel_RangeWrite($book, $book.Activesheet, 'Levá síň', 'A7')
	$book.Activesheet.Range('A7').Font.Bold = True
	_Excel_RangeWrite($book, $book.Activesheet, 'LA-PLAX:', 'B7')
	$book.Activesheet.Range('B7').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('C7').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, 'LAV:', 'D7')
	$book.Activesheet.Range('D7').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('E7').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, 'LAV-i:', 'F7')
	$book.Activesheet.Range('F7').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('G7').HorizontalAlignment = $xlCenter;
	With $book.Activesheet.Range('A7:H7').Borders(9)
		.LineStyle = 1
		.Weight = 2
	EndWith
	; prava komora
	_Excel_RangeWrite($book, $book.Activesheet, 'Pravá komora', 'A8')
	$book.Activesheet.Range('A8').Font.Bold = True
	_Excel_RangeWrite($book, $book.Activesheet, 'REDD-PLAX:', 'B8')
	$book.Activesheet.Range('B8').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('C8').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, 'TAPSE:', 'D7')
	$book.Activesheet.Range('D8').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('E8').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, 'RVD1:', 'F7')
	$book.Activesheet.Range('F8').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('G8').HorizontalAlignment = $xlCenter;
	With $book.Activesheet.Range('A8:H8').Borders(9)
		.LineStyle = 1
		.Weight = 2
	EndWith
	; prava sin
	_Excel_RangeWrite($book, $book.Activesheet, 'Pravá síň', 'A9')
	$book.Activesheet.Range('A9').Font.Bold = True
	_Excel_RangeWrite($book, $book.Activesheet, 'RA-A4C:', 'B9')
	$book.Activesheet.Range('B9').HorizontalAlignment = $xlRight;
	With $book.Activesheet.Range('A9:H9').Borders(9)
		.LineStyle = 1
		.Weight = 2
	EndWith
	; aortalni chlopen
	_Excel_RangeWrite($book, $book.Activesheet, 'Aortální chlopeň', 'A10')
	$book.Activesheet.Range('A10').Font.Bold = True
	$book.Activesheet.Range('B10:H10').MergeCells = True
	With $book.Activesheet.Range('A10:H10').Borders(9)
		.LineStyle = 1
		.Weight = 2
	EndWith
	; mitralni chlopen
	_Excel_RangeWrite($book, $book.Activesheet, 'Mitrální chlopeň', 'A11')
	$book.Activesheet.Range('A11').Font.Bold = True
	_Excel_RangeWrite($book, $book.Activesheet, "E':", 'B11')
	$book.Activesheet.Range('B11').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('C11').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, 'DT:', 'D11')
	$book.Activesheet.Range('D11').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('E11').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, "E/E':", 'B12')
	$book.Activesheet.Range('B12').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('C12').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, 'A:', 'D12')
	$book.Activesheet.Range('D12').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('E12').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, 'E:', 'B13')
	$book.Activesheet.Range('B13').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('C13').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, 'E/A:', 'D13')
	$book.Activesheet.Range('D13').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('E13').HorizontalAlignment = $xlCenter;
	$book.Activesheet.Range('B14:H14').MergeCells = True
	With $book.Activesheet.Range('A14:H14').Borders(9)
		.LineStyle = 1
		.Weight = 2
	EndWith
	; trikuspidalni chlopen
	_Excel_RangeWrite($book, $book.Activesheet, 'Trikuspidální chlopeň', 'A15')
	$book.Activesheet.Range('A15').Font.Bold = True
	_Excel_RangeWrite($book, $book.Activesheet, 'PGmax-reg:', 'B15')
	$book.Activesheet.Range('B15').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('C15').HorizontalAlignment = $xlCenter;
	_Excel_RangeWrite($book, $book.Activesheet, 'DDŽ:', 'D15')
	$book.Activesheet.Range('D15').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('E15').HorizontalAlignment = $xlCenter;
	$book.Activesheet.Range('B16:H16').MergeCells = True
	With $book.Activesheet.Range('A16:H16').Borders(9)
		.LineStyle = 1
		.Weight = 2
	EndWith
	; pulmonarni chlopen
	_Excel_RangeWrite($book, $book.Activesheet, 'Pulmonární chlopeň', 'A17')
	$book.Activesheet.Range('A17').Font.Bold = True
	_Excel_RangeWrite($book, $book.Activesheet, 'Vmax:', 'B17')
	$book.Activesheet.Range('B17').HorizontalAlignment = $xlRight;
	$book.Activesheet.Range('C17').HorizontalAlignment = $xlCenter;
	$book.Activesheet.Range('B18:H18').MergeCells = True
	With $book.Activesheet.Range('A18:H18').Borders(9)
		.LineStyle = 1
		.Weight = 2
	EndWith
	; perikard
	_Excel_RangeWrite($book, $book.Activesheet, 'Perikard', 'A19')
	$book.Activesheet.Range('A19').Font.Bold = True
	$book.Activesheet.Range('B19:H19').MergeCells = True
	With $book.Activesheet.Range('A19:H19').Borders(9)
		.LineStyle = 1
		.Weight = 2
	EndWith
	; jine
	_Excel_RangeWrite($book, $book.Activesheet, 'Jiné', 'A20')
	$book.Activesheet.Range('A20').Font.Bold = True
	$book.Activesheet.Range('B20:H20').MergeCells = True
	With $book.Activesheet.Range('A20:H20').Borders(9)
		.LineStyle = 1
		.Weight = 2
	EndWith
	; zaver
	_Excel_RangeWrite($book, $book.Activesheet, 'Závěr', 'A21')
	$book.Activesheet.Range('A21').Font.Bold = True
	$book.Activesheet.Range('B21:H21').MergeCells = True
	With $book.Activesheet.Range('A21:H21').Borders(9)
		.LineStyle = 1
		.Weight = 2

; update XLS data & write clipboard
func dekurz()
	logger('Generuji dekurz: ' & @MIN & ':' & @SEC)
	;clear the clip
	_ClipBoard_Open(0)
	_ClipBoard_Empty()
	_ClipBoard_Close()
	; aorta
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_ao_root), 'C1')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_ao_index), 'E1')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_ao_note), 'B2')
	; leva komora
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_lk_lvedd), 'C3')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_lk_lveddi), 'E3')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_lk_lvesd), 'C4')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_lk_ivs), 'E4')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_lk_lvef), 'C5')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_lk_inferolat), 'E5')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_lk_note), 'B6')
	; leva sin
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_ls_laplax), 'C7')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_ls_lav), 'E7')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_ls_lavi), 'G7')
	; prava komora
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_pk_rveddplax), 'C8')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_pk_tapse), 'E8')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_pk_rvd1), 'G8')
	; prava sin
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_ps_raa4c), 'C9')
	; aortalni chlopen
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_ao_note), 'B10')
	; mitralni chlopen
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_mch_es), 'C11')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_mch_dt), 'E11')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_mch_ee), 'C12')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_mch_a), 'E12')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_mch_e), 'C13')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_mch_ea), 'E13')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_mch_note), 'B14')
	; trikuspidalni chlopen
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_tch_pg), 'C15')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_tch_ddz), 'E15')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_tch_note), 'B16')
	; pulmonarni chlopen
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_pch_vmax), 'C17')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_pch_note), 'B18')
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_perikard_note), 'B19')
	; jine
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($input_other_note), 'B20')
	; zaver
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($edit_dekurz), 'B21')
	; clip
	$range = $book.ActiveSheet.Range('A1:H21')
	_Excel_RangeCopyPaste($book.ActiveSheet,$range)
	if @error then return SetError(1, 0, 'Nelze kopirovat data.')
	logger('Zápis dokončen: ' & @MIN & ':' & @SEC)
EndFunc

func print($id,$name,$date)
	local $printer,$printer_error,$marginx,$marginy
	;priner init
	$printer = _PrintDllStart($printer_error)
	if $printer = 0 then
		logger('Priner error: ' & $printer_error & @CRLF)
	endif
	;_PrintPageOrientation($printer,0);landscape

	_PrintSetDocTitle($printer,"S70 Dekurz - Patient ID: 123456")

	; printer write data
	_PrintStartPrint($printer)

	;_PrintGetpageheight($printer) - _PrintGetYOffset($printer)
	;_PrintGetpageWidth($printer) - _PrintGetXOffset($printer)
	;_PrintSetFont($printer,'Arial',18,0,'bold,underline')
	;_PrintGetTextWidth($printer,$Title)
	;_PrintGetTextHeight($printer,$title)
	;_PrintSetLineWid($printer,2)
	;_PrintSetLineCol($printer,0)
	;_printsetfont($printer,'Times New Roman',12,0,'')
	;_PrintGetTextHeight($printer,"Jan")
	;_PrintText($printer,$n,$basex - _PrintGetTextWidth($printer,$n) - 20,$pght-$basey-$n*$ydiv-Int(_printGetTextHeight($printer,'10')/2))
	;_PrintLIne($printer,$basex - 5,$pght - $basey - $n*$ydiv,$basex + 5,$pght - $basey - $n*$ydiv)
	;_PrintSetLineCol($printer,0x0000ff)
	;_PrintSetBrushCol($printer,0x55FF55)
	;_PrintSetLineCol($printer,0)
	;_PrintLine($printer,Int($pgwd/2),2*$th + 125,$Basex + 8*$xdiv ,$pght - $basey - Int($sales[8]*$ydiv/10))
	;_Printsetlinecol($printer,0x0000ff)
	;_PrintSetLineWid($printer,10)
	;_PrintSetBrushCol($printer,0xbbccee)
	;_PrintEllipse($printer,Int($pgwd/2) - 200,2*$th,Int($pgwd/2) + 200,2*$th + 250)
	;_PrintImage($printer,"screenshot004.bmp",Int($pgwd/2) - 150,2*$th+260,300,350)

	; print end data
	_PrintEndPrint($printer)
	_PrintNewPage($printer)
	_printDllClose($printer)
EndFunc
