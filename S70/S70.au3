;
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

; -------------------------------------------------------------------------------------------
; INCLUDE
; -------------------------------------------------------------------------------------------

#include <C:\Program Files (x86)\AutoIt3\Include\ScreenCapture.au3>
#include <C:\Program Files (x86)\AutoIt3\Include\GUIConstantsEx.au3>
#include <C:\Program Files (x86)\AutoIt3\Include\Clipboard.au3>
#include <C:\Program Files (x86)\AutoIt3\Include\Excel.au3>
#include <C:\Program Files (x86)\AutoIt3\Include\ExcelConstants.au3>
#include <C:\Program Files (x86)\AutoIt3\Include\File.au3>
#include <C:\Program Files (x86)\AutoIt3\Include\Date.au3>
#include <Print.au3>
#include <Json.au3>

; -------------------------------------------------------------------------------------------
; VAR
; -------------------------------------------------------------------------------------------

$VERSION = '1.5'
$AGE = 24; default stored data age in hours

global $log_file = @ScriptDir & '\' & 'S70.log'
global $config_file = @ScriptDir & '\' & 'S70.ini'
global $result_file = @ScriptDir & '\' & 'zaver.txt'

global $export_path = @ScriptDir & '\' & 'input'
global $archive_path = @ScriptDir & '\' & 'archiv'

global $runtime = @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC

;data template
global $json_template='{' _
	& '"patient":null,' _
	& '"name":null,' _
	& '"poj":null,' _
	& '"bsa":1.9,' _
	& '"weight":75,' _
	& '"height":191,' _
	& '"date",null,' _
	& '"result":null,' _
	& '"group":{' _
		& '"lk":{"label":"Levá komora", "note":null, "id":null},' _
		& '"ls":{"label":"Levá síň", "note":null, "id":null},' _
		& '"pk":{"label":"Pravá komora", "note":null, "id":null},' _
		& '"ps":{"label":"Pravá síň", "note":null, "id":null},' _
		& '"ao":{"label":"Aorta", "note":null, "id":null},' _
		& '"ach":{"label":"Aortální chlopeň", "note":null, "id":null},' _
		& '"mch":{"label":"Mitrální chlopeň", "note":null, "id":null},' _
		& '"pch":{"label":"Pulmonární chlopeň", "note":null, "id":null},' _
		& '"tch":{"label":"Trikuspidální chlopeň", "note":null, "id":null},' _
		& '"p":{"label":"Perikard", "note":null, "id":null},' _
		& '"other":{"label":"Ostatní", "note":null, "id":null}' _
	& '},' _
	& '"data":{' _
		& '"lk":{' _
			& '"IVSd":{"label":"IVS", "unit":"mm", "value":null, "id":null},' _
			& '"LVIDd":{"label":"LVd", "unit":"mm", "value":null, "id":null},' _
			& '"LVd index":{"label":"LVD index", "unit":"mm/m²", "value":null, "id":null},' _
			& '"LVPWd":{"label":"ZS", "unit":"mm", "value":null, "id":null},' _
			& '"LVIDs"::{"label":"LVs", "unit":"mm", "value":null, "id":null},' _
			& '"LVs index":{"label":"LVs index", "unit":"mm/m²", "value":null, "id":null},' _
			& '"LVEF % Teich":{"label":"LVEF % Teich.", "unit":"%", "value":null, "id":null},' _
			& '"LVEF % odhad":{"label":"LVEF % odhad", "unit":"%", "value":null, "id":null},' _
			& '"LVmass":{"label":"LVmass", "unit":"g", "value":null, "id":null},' _
			& '"LVmass-i^2,7":{"label":"LVmass-i^2.7", "unit":"g/m2.7", "value":null, "id":null},' _
			& '"LVmass-BSA":{"label":"LVmass-BSA", "unit":"g/m²", "value":null, "id":null},' _
			& '"RTW":{"label":"RTW", "unit":"?", "value":null, "id":null},' _
			& '"FS":{"label":"FS", "unit":"%", "value":null, "id":null},' _
			& '"EF Biplane":{"label":"LVEF biplane", "unit":"%", "value":null, "id":null},' _
			& '"SV MOD A4C":{"label":null, "unit":null, "value":10},' _; calculation
			& '"SV MOD A2C":{"label":null, "unit":null, "value":20},' _; calculation
			& '"SV-biplane":{"label":"SV-biplane", "unit":"ml", "value":null, "id":null},' _
			& '"LVEDV MOD BP":{"label":"EDV", "unit":"ml", "value":10, "id":null},' _
			& '"LVESV MOD BP":{"label":"ESV", "unit":"ml", "value":20, "id":null},' _
			& '"EDVi":{"label":"EDVi", "unit":"ml/m²", "value":null, "id":null},' _
			& '"ESVi":{"label":"ESVi", "unit":"ml/m²", "value":null, "id":null}' _
		& '},' _
		& '"ls":{' _
			& '"LA Diam":{"label":"Plax", "unit":"mm", "value":null, "id":null},' _
			& '"LAV-A4C":{"label":"LAV-A4C", "unit":"ml", "value":null, "id":null},' _
			& '"LAV-2D":{"label":"LAV-2D", "unit":"ml", "value":null, "id":null},' _
			& '"LAVi-2D":{"label":"LAVi-2D", "unit":"ml/m²", "value":null, "id":null},' _
			& '"LAEDV A-L A4C":{"label":null, "unit":null, "value":null},' _; calculation
			& '"LAEDV MOD A4C":{"label":null, "unit":null, "value":null},' _; calculation
			& '"LAEDV A-L A2C":{"label":null, "unit":null, "value":120},' _; calculation
			& '"LAEDV MOD A2C":{"label":null, "unit":null, "value":130},' _; calculation
			& '"LA Minor":{"label":"LA šířka", "unit":"mm", "value":null, "id":null},' _
			& '"LA Major":{"label":"LA délka", "unit":"mm", "value":null, "id":null},' _
			& '"LAVi":{"label":"LAVi", "unit":"ml/m²", "value":null, "id":null}' _
		& '},' _
		& '"pk":{' _
			& '"RV Major":{"label":"RVplax", "unit":"mm", "value":null, "id":null},' _
			& '"RVIDd":{"label":"RVD1", "unit":"mm", "value":null, "id":null},' _
			& '"S-RV":{"label":"S-RV", "unit":"cm/s", "value":null, "id":null},' _
			& '"EDA":{"label":"EDA", "unit":"?", "value":null, "id":null},' _
			& '"ESA":{"label":"ESA", "unit":"?", "value":null, "id":null},' _
			& '"FAC%":{"label":"FAC%", "unit":"%", "value":null, "id":null},' _
			& '"TAPSE":{"label":"TAPSE", "unit":"mm", "value":null, "id":null}' _
		& '},' _
		& '"ps":{' _
			& '"RA Minor":{"label":"RA šířka", "unit":"mm", "value":null, "id":null},' _
			& '"RA Major":{"label":"RA délka", "unit":"mm", "value":null, "id":null},' _
			& '"RAV":{"label":"RAV", "unit":"ml", "value":null, "id":null},' _
			& '"RAVi":{"label":"RAVi", "unit":"ml/m²", "value":null, "id":null}' _
		& '},' _
		& '"ao":{' _
			& '"Ao Diam SVals":{"label":"Bulbus", "unit":"mm", "value":null, "id":null},' _
			& '"Ao Diam":{"label":"Asc-Ao", "unit":"mm", "value":null, "id":null}' _
		& '},' _
		& '"ach":{' _
			& '"LVOT Diam":{"label":"LVOT", "unit":"mm", "value":3.2, "id":null},' _
			& '"AR Rad":{"label":"PSA AR radius", "unit":"mm", "value":0.54, "id":null},' _
			& '"AV Vmax":{"label":"Vmax", "unit":"m/s", "value":null, "id":null},' _
			& '"AV maxPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"AV meanPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"AV max/meanPG":{"label":"AV max/meanPG", "unit":"torr", "value":null, "id":null},' _
			& '"AV VTI":{"label":"Ao-VTI", "unit":"cm/torr?", "value":null, "id":null},' _
			& '"LVOT VTI":{"label":"LVOT-VTI", "unit":"cm/torr?", "value":1.5, "id":null},' _
			& '"SV":{"label":null, "unit":"ml/m²", "value":null},' _; calculation
			& '"SVi":{"label":null, "unit":"ml/m²", "value":null},' _; calculation
			& '"SV/SVi":{"label":"SV/SVi", "unit":"ml/m²", "value":null, "id":null},' _
			& '"AVA":{"label":"AVA", "unit":"cm", "value":null, "id":null},' _
			& '"AVAi":{"label":"AVAi", "unit":"cm²", "value":null, "id":null},' _
			& '"VTI LVOT/Ao":{"label":"VTI LVOT/Ao", "unit":"ratio", "value":null, "id":null},' _
			& '"AR VTI":{"label":"AR-VTI", "unit":"cm", "value":null, "id":null},' _
			& '"AR ERO":{"label":"AR-ERO", "unit":"cm²", "value":null, "id":null},' _
			& '"AR RV":{"label":"AR-RV", "unit":"ml", "value":null, "id":null}' _
		& '},' _
		& '"mch":{' _
			& '"MR Rad":{"label":"PISA MR radius", "unit":"mm", "value":null, "id":null},' _
			& '"MV E Vel":{"label":"E", "unit":"cm/s", "value":null, "id":null},' _
			& '"MV A Vel":{"label":"A", "unit":"cm/s", "value":null, "id":null},' _
			& '"MV E/A Ratio":{"label":"E/A", "unit":"ratio", "value":null, "id":null},' _
			& '"MV DecT":{"label":"DecT", "unit":"ms", "value":null, "id":null},' _
			& '"MV PHT":{"label":"MR-PHT", "unit":"ms", "value":null, "id":null},' _
			& '"MV maxPG":{"label":null, "unit":null, "value":1},' _; calculation
			& '"MV meanPG":{"label":null, "unit":null, "value":23},' _; calculation
			& '"MV max/meanPG":{"label":"MV max/meanPG", "unit":"torr", "value":null, "id":null},' _
			& '"MVA-PHT":{"label":"MVA-PHT", "unit":"cm²", "value":null, "id":null},' _
			& '"MVAi-PHT":{"label":"MVAi-PHT", "unit":"cm²/2", "value":null, "id":null},' _
			& '"EmSept":{"label":"EmSept", "unit":"cm/s", "value":null, "id":null},' _
			& '"EmLat":{"label":"EmLat", "unit":"cm/s", "value":null, "id":null},' _
			& '"E/Em":{"label":"E/Em", "unit":"ratio", "value":null, "id":null},' _
			& '"MR VTI":{"label":"MR-VTI", "unit":"cm", "value":null, "id":null},' _
			& '"MR ERO":{"label":"MR-ERO", "unit":"cm²", "value":null, "id":null},' _
			& '"MR RV":{"label":"MR-RV", "unit":"ml", "value":null, "id":null}' _
		& '},' _
		& '"pch":{' _
			& '"PV Vmax":{"label":"Vmax", "unit":"m/s", "value":66, "id":null},' _
			& '"PVAcc T":{"label":"ACT", "unit":"ms", "value":null, "id":null},' _
			& '"PV maxPG":{"label":null, "unit":null, "value":3},' _; calculation
			& '"PV meanPG":{"label":null, "unit":null, "value":14},' _; calculation
			& '"PV max/meanPG":{"label":"PV max/meanPG", "unit":"torr", "value":null, "id":null},' _
			& '"PRend PG":{"label":"PGed-reg", "unit":"torr", "value":null, "id":null},' _
			& '"PR maxPG":{"label":null, "unit":null, "value":2},' _; calculation
			& '"PR meanPG":{"label":null, "unit":null, "value":17},' _; calculation
			& '"PR max/meanPG":{"label":"PR max/meanPG", "unit":"torr", "value":null, "id":null}' _
		& '},' _
		& '"tch":{' _
			& '"TR maxPG":{"label":"PGmax-reg", "unit":"torr", "value":null, "id":null},' _
			& '"TR meanPG":{"label":"PGmean-reg", "unit":"torr", "value":null, "id":null},' _
			& '"TV maxPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"TV meanPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"TV max/meanPG":{"label":"TV max/meanPG", "unit":"torr", "value":null, "id":null}' _
		& '},' _
		& '"p":{' _
		& '},' _
		& '"other":{' _
			& '"IVC Diam Exp":{"label":"DDŽexp", "unit":"mm", "value":null, "id":null},' _
			& '"IVC diam Ins":{"label":"DDŽins", "unit":"mm", "value":null, "id":null}' _
		& '}' _
	& '}' _
& '}'

;data
global $history = Json_Decode($json_template)
global $buffer = Json_Decode($json_template)

;XLS variable
global $excel, $book

; -------------------------------------------------------------------------------------------
; CONTROL
; -------------------------------------------------------------------------------------------

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

; -------------------------------------------------------------------------------------------
; INIT
; -------------------------------------------------------------------------------------------

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
global $export_file = get_export_file($export_path, $cmdline[1])
if @error or not $export_file then logger('Soubor exportu nebyl nalezen: ' & $cmdline[1])

; update data buffer from export
if FileExists($export_file) then
	$parse = export_parse($export_file)
;	if @error then
;		FileMove($export_file, $export_file & '.err', 1); overwrite
;		logger('Nepodařilo se načíst export: ' & $cmdline[1] & '.dat')
;	else
;		FileMove($export_file, $export_file & '.old', 1); overwrite
;	endif
endif

; update history buffer from archive
if FileExists($archive_file) then
	$history = Json_Decode(FileRead($archive_file))
	if @error then logger('Nepodařilo se načíst historii: ' & $cmdline[1] & '.dat')
endif

; update data buffer note from history
if $history then
	for $group in Json_Get($history,'.group')
		Json_Put($buffer, '.group.' & $group & '.note', Json_Get($history, 'group.' & $group & '.note'), True)
	next
endif

; calculate values
calculate()

; default result template
if not Json_Get($buffer, '.result') then
	$result_text = FileRead($result_file)
	if @error then
		logger('Načtení výchozího závěru selhalo.')
	else
		Json_Put($buffer, '.result', $result_text, True)
	endif
endif

; -------------------------------------------------------------------------------------------
; GUI
; -------------------------------------------------------------------------------------------

$gui_index = 0
$gui_top_offset = 33
$gui_left_offset = 0
$gui_group_top_offset = 33 + 10
$gui_group_index = 0

$gui = GUICreate("S70 Echo " & $VERSION, 950, 990, 100, 10)

; header
$label_pacient = GUICtrlCreateLabel('Pacient', 60, 9, 40, 17)
$input_pacient = GUICtrlCreateInput($cmdline[3] & ' ' & $cmdline[2], 106, 6, 121, 21, 1); read only
$label_rc = GUICtrlCreateLabel('r.č.', 268, 9, 19, 17)
$input_rc = GUICtrlCreateInput(StringRegExpReplace($cmdline[1], '(^\d{6})(.*)', '$1 \/ $2'), 290, 6, 105, 21, 1); read only
$label_poj = GUICtrlCreateLabel('Poj.', 452, 9, 22, 17)
$input_poj = GUICtrlCreateInput($cmdline[4], 476, 6, 41, 21, 1); read only

; groups
for $group in Json_Get($history, '.group')
	for $member in Json_Get($history, '.data.' & $group)
;		; data
		if IsString(Json_Get($buffer, '.data.' & $group & '."' & $member & '".label')) then
;			; update index / offset
			if Mod($gui_index, 5) = 0 then
				$gui_top_offset+=26
				$gui_left_offset=10
			Else
				$gui_left_offset+=185
			endif
;			; label
			GUICtrlCreateLabel(Json_Get($buffer, '.data.' & $group & '."' & $member & '".label'), $gui_left_offset, 3 + $gui_top_offset, 90, 21, 0x0002); align right
;			; input
			Json_Put($buffer,'.data.' & $group & '."' & $member & '".id', GUICtrlCreateInput(Json_Get($buffer, '.data.' & $group & '."' & $member & '".value'), 96 + $gui_left_offset, $gui_top_offset, 41, 21, 1), True)
;			; unit
			GUICtrlCreateLabel(Json_Get($buffer, '.data.' & $group & '."' & $member & '".unit'), 144 + $gui_left_offset, 3 + $gui_top_offset, 45, 21)
			; update index
			$gui_index+=1
		endif
	next
	; note
	GUICtrlCreateLabel('Poznámka', 10, 28 + $gui_top_offset, 90, 21, 0x0002)
	Json_Put($buffer, '.group.' & $group & '.id', GUICtrlCreateInput(Json_Get($buffer, '.group.' & $group & '.note'), 106, 26 + $gui_top_offset, 830, 21, 1))
	$gui_top_offset+=26 - 13

	; group
	GUICtrlCreateGroup(Json_Get($buffer, '.group.' & $group & '.label'), 5, $gui_group_top_offset, 940, 21 + 26 * (gui_get_group_index($gui_index,5)+ 1))
	$gui_group_top_offset += 10 + 13 + 26 + 26 * gui_get_group_index($gui_index, 5)

	; update index / offset
	$gui_top_offset+=26 + 10
	$gui_left_offset=10
	$gui_index=0
next

; dekurz
;$label_dekurz = GUICtrlCreateLabel('Závěr:', 15, 722 , 70, 17)
;$edit_dekurz = GUICtrlCreateEdit(Json_Get($buffer, '.data.result'), 8, 740, 609, 97, BitOR(64, 4096, 0x00200000)); $ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL

; date
;$label_date = GUICtrlCreateLabel('Datum:', 15, 852, 50, 17)
;$label_datetime = GUICtrlCreateLabel($runtime, 51, 853, 100, 17)

; button
;$button_history = GUICtrlCreateButton('Historie', 305, 846, 75, 25)
;$button_tisk = GUICtrlCreateButton('Tisk', 384, 846, 75, 25)
;$button_dekurz = GUICtrlCreateButton('Dekurz', 463, 846, 75, 25)
;$button_konec = GUICtrlCreateButton('Konec', 542, 846, 75, 25)

; GUI tune
;GUICtrlSetBkColor($input_pacient, 0xC0DCC0)
;GUICtrlSetBkColor($input_rc, 0xC0DCC0)
;GUICtrlSetBkColor($input_poj, 0xC0DCC0)
;GUICtrlSetState($button_konec, $GUI_FOCUS)

; GUI display
GUISetState(@SW_SHOW)

; dekurz initialize
;$dekurz_init = dekurz_init()
;if @error then logger($dekurz_init)

_ScreenCapture_Capture(@ScriptDir & "\gui.jpg")

; -------------------------------------------------------------------------------------------
; MAIN
; -------------------------------------------------------------------------------------------

; main loop
While 1
	$msg = GUIGetMsg()
	; generate dekurz clipboard
;	if $msg = $button_dekurz then
;		$dekurz = dekurz()
;		if @error then
;			logger($dekurz)
;			MsgBox(48, 'S70 Echo v' & $VERSION, 'Generování dekurzu selhalo.')
;		endif
;	endif
;	; print data
;	if $msg = $button_tisk Then
;		$print = print()
;		if @error then
;			logger($print)
;			MsgBox(48, 'S70 Echo v' & $VERSION, 'Tisk selhal.')
;		endif
;	endif
;	; load history
;	if $msg = $button_history Then
;		if FileExists($archive_file) then
;			if _DateDiff('h', $runtime, Json_Get($history,'.date')) < $AGE then
;				if msgbox(4, 'S70 Echo ' & $VERSION & ' - Historie', 'Načíst poslední naměřené hodnoty?' & @CRLF & '(Popisy se načítají vždy.)') = 6 then
;
;					; update GUI from history
;					for $group in Json_Get($buffer, '.group')
;						; update note
;						GUICtrlSetData(Json_Get($buffer, '.group.' & $group & '.id'), Json_Get($history, '.group.' & $group & '.note'))
;						; update data
;						for $member in Json_Get($buffer, '.data.' & $group)
;							GUICtrlSetData(Json_Get($buffer,'.data.' & $group & '.' & $member & '.id'), Json_Get($history,'.data.' & $group & '.' & $member & '.value'))
;						next
;					next
;				endif
;			else
;				msgbox(4, 'S70 Echo ' & $VERSION & ' - Historie', 'Nelze načís historii. Příliš stará data.')
;			endif
;		else
;			MsgBox(48, 'S70 Echo v' & $VERSION, 'Historie není dostupná.')
;		endif
;	endif
	; write & exit
;	if $msg = $GUI_EVENT_CLOSE or $msg = $button_konec then
	if $msg = $GUI_EVENT_CLOSE then
		; close dekurz
	;	_Excel_BookClose($book)
	;	_Excel_Close($excel)

		; update data buffer
	;	for $group in Json_Get($buffer, '.group')
	;		; update note
	;		Json_Put($buffer, '.group.' & $group & '.note', GuiCtrlRead(Json_Get($buffer, '.group.' & $group & '.id')))
	;		; update data
	;		for $member in Json_Get($buffer, '.data.' & $group)
	;			Json_Put($buffer, '.data.'  & $group & '.' & $member & '.value', GuiCtrlRead(Json_Get($buffer, '.data.'  & $group & '.' & $member & '.id')))
	;		next
	;	next
		; write data buffer to archive
	;	$out = FileOpen($archive_file, 2 + 256); UTF8 / BOM
	;	FileWrite($out, Json_Encode($buffer))
	;	if @error then logger('Zápis archivu selhal: ' & $cmdline[1] & '.dat')
	;	FileClose($out)
		; exit
		exitloop
	endif
wend

;exit
logger('Program exit: ' & @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC)
logger('----')
FileClose($log)

exit

; -------------------------------------------------------------------------------------------
; FUNCTION
; -------------------------------------------------------------------------------------------

; logging
func logger($text)
	FileWriteLine($log_file, $text)
endfunc

; read configuration file
func read_config_file($file)
	local $cfg
	_FileReadToArray($file, $cfg, 0, "=")
	if @error then return SetError(1)
	for $i = 0 to UBound($cfg) - 1
		if $cfg[$i][0] == 'export' then $export_path = StringRegExpReplace($cfg[$i][1], '\\$', ''); strip trailing backslash
		if $cfg[$i][0] == 'archiv' then $archive_path = StringRegExpReplace($cfg[$i][1], '\\$', ''); strip trailing backslash
		if $cfg[$i][0] == 'result' then $result_file = $cfg[$i][1]
		if $cfg[$i][0] == 'history' then $AGE = $cfg[$i][1]
	next
endfunc

; find export file
func get_export_file($export_path, $rc)
	local $list = _FileListToArray($export_path, '*.txt', 1); files only
	if @error then Return SetError(1)
	for $i = 1 to ubound($list) - 1
		if StringRegExp($list[$i], '^' & $rc & '_.*') then return $export_path & '\' & $list[$i]
	next
	return ''
endfunc

; parse S70 export file
;
; FIX: 'dot' variables
;
func export_parse($export)
	local $raw
	_FileReadToArray($export, $raw, 0); no count
	if @error then return SetError(1, 0, 'Nelze načíst souboru exportu.')
	for $group in Json_ObjGet($history, '.group')
		for $member in Json_ObjGet($history, '.data.' & $group)
			for $i = 0 to UBound($raw) - 1
				if StringRegExp($raw[$i], '^' & $member & '\t.*') then
					StringReplace($raw[$i], @TAB, '')
					if @extended == 2 Then
						Json_Put($buffer, '.data.' & $group & '."' & $member & '".value', Number(StringRegExpReplace($raw[$i], '^.*\t(.*)\t.*', '$1')), True); check exists
					elseif @extended == 1 then
						Json_Put($buffer, '.data.' & $group & '."' & $member & '".value', Number(StringRegExpReplace($raw[$i], '.*\t(.*)$', '$1')), True)
					endif
				endif
			next
		next
	next
endfunc

; calculate aditional variables
func calculate()
	; LVEF % Teich.
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVIDs.value')) then
		Json_Put($buffer, '.data.lk."LVEF % Teich".value', Round((7/(2.4+Json_Get($buffer, '.data.lk.LVIDd.value')/10)*(Json_Get($buffer, '.data.lk.LVIDd.value')/10)^3-7/(2.4+Json_Get($buffer, '.data.lk.LVIDs.value')/10)*(Json_Get($buffer, '.data.lk.LVIDs.value')/10)^3)/(7/(2.4+Json_Get($buffer, '.data.lk.LVIDd.value')/10)*(Json_Get($buffer, '.data.lk.LVIDd.value')/10)^3)*100, 2), True)
	endif
	; LVmass
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.IVSd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVPWd.value')) then
		Json_Put($buffer, '.data.lk.LVmass.value', Round(1.04*(Json_get($buffer, '.data.lk.LVIDd.value')/10 + Json_Get($buffer, '.data.lk.IVSd.value')/10 + Json_Get($buffer, '.data.lk.LVPWd.value')/10)^3-(Json_Get($buffer, '.data.lk.LVIDd.value')/10)^3-13.6, 2), True)
	endif
	; LVmass-i^2,7
	if IsNumber(Json_Get($buffer, '.height')) and IsNumber(Json_Get($buffer, '.data.lk.LVmass.value')) then
		Json_Put($buffer, '.data.lk."LVmass-i^2,7".value', Round(Json_Get($buffer, '.data.lk.LVmass.value')/(Json_Get($buffer, '.height')/100)^2.7, 2), True)
	endif
	; LVmass-BSA
	if IsNumber(Json_Get($buffer, '.bsa')) and IsNumber(Json_Get($buffer, '.data.lk.LVmass.value')) then
		Json_Put($buffer, '.data.lk.LVmass-BSA.value', Round(Json_Get($buffer, '.data.lk.LVmass.value')/Json_Get($buffer, '.bsa'), 2), True)
	endif
	; RTW
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVPWd.value')) then
		Json_Put($buffer, '.data.lk.RTW.value', Round(2*Json_Get($buffer, '.data.lk.LVPWd.value')/Json_Get($buffer, '.data.lk.LVIDd.value'), 2), True)
	endif
	; FS
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVIDs.value')) then
		Json_Put($buffer, '.data.lk.FS.value', Round((Json_Get($buffer, '.data.lk.LVIDd.value')-Json_Get($buffer, '.data.lk.LVIDs.value'))/Json_Get($buffer, '.data.lk.LVIDd.value')*100, 2), True)
	endif
	; SV-biplane
	if IsNumber(Json_Get($buffer, '.data.lk."SV MOD A2C".value')) and IsNumber(Json_Get($buffer, '.data.lk."SV MOD A4C".value')) then
		Json_Put($buffer, '.data.lk.SV-biplane.value', Round((Json_Get($buffer, '.data.lk."SV MOD A4C".value') + Json_Get($buffer, '.data.lk."SV MOD A2C".value'))/2, 2), True)
	endif
	;EDVi
	if IsNumber(Json_Get($buffer, '.data.lk."LVEDV MOD BP".value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.lk.EDVi.value', Round(Json_Get($buffer, '.data.lk."LVEDV MOD BP".value')/Json_Get($buffer, '.bsa'), 2), True)
	endif
	;ESVi
	if IsNumber(Json_Get($buffer, '.data.lk."LVESV MOD BP".value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.lk.ESVi.value', Round(Json_Get($buffer, '.data.lk."LVESV MOD BP".value')/Json_Get($buffer, '.bsa'), 2), True)
	endif
	; LAV-A4C
	if IsNumber(Json_Get($buffer, '.data.ls."LAEDV A-L A4C".value')) and IsNumber(Json_Get($buffer, '.data.ls."LAEDV MOD A4C".value')) then
		Json_Put($buffer, '.data.ls.LAV-A4C.value', Round((Json_Get($buffer, '.data.ls."LAEDV A-L A4C".value') + Json_Get($buffer, '.data.ls."LAEDV MOD A4C".value'))/2, 2), True)
	endif
	; LAV-2D
	if IsNumber(Json_Get($buffer,'.data.ls.LAV-A4C.value')) and IsNumber(Json_Get($buffer, '.data.ls."LAEDV A-L A2C".value')) and IsNumber(Json_Get($buffer, '.data.ls."LAEDV MOD A2C".value')) then
		Json_Put($buffer, '.data.ls.LAV-2D.value',Round((Json_Get($buffer, '.data.ls.LAV-A4C.value')+(Json_Get($buffer, '.data.ls."LAEDV A-L A2C".value') + Json_Get($buffer, '.data.ls."LAEDV MOD A2C".value'))/2)/2, 2), True)
	endif
	; LAVi-2D
	if IsNumber(Json_Get($buffer,'.data.ls.LAV-2D.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.ls.LAVi-2D.value', Round(Json_Get($buffer, '.data.ls.LAV-2D.value')/Json_Get($buffer, '.bsa'), 2), True)
	endif
	;MR Rad
	if IsNumber(Json_Get($buffer,'.data.mch."MR Rad".value')) then
		Json_Put($buffer, '.data.mch."MR Rad".value', Round(Json_Get($buffer, '.data.mch."MR Rad".value')*100, 2), True)
	endif
	;AR Rad
	if IsNumber(Json_Get($buffer,'.data.ach."AR Rad".value')) then
		Json_Put($buffer, '.data.ach."AR Rad".value', Round(Json_Get($buffer, '.data.ach."AR Rad".value')*100, 2), True)
	endif
	;PV Vmax
	if IsNumber(Json_Get($buffer,'.data.pch."PV Vmax".value')) then
		Json_Put($buffer, '.data.pch."PV Vmax".value', Round(Json_Get($buffer, '.data.pch."PV Vmax".value')/100, 2), True)
	endif
	; PV max/meanPG
	if IsNumber(Json_Get($buffer,'.data.pch."PV maxPG".value')) and IsNumber(Json_Get($buffer, '.data.pch."PV maxPG".value')) then
		Json_Put($buffer, '.data.pch."PV max/meanPG".value', Json_Get($buffer, '.data.pch."PV maxPG".value') & '/' & Json_Get($buffer, '.data.pch."PV meanPG".value'), True)
	endif
	; PR max/meanPG
	if IsNumber(Json_Get($buffer,'.data.pch."PR maxPG".value')) and IsNumber(Json_Get($buffer, '.data.pch."PR maxPG".value')) then
		Json_Put($buffer, '.data.pch."PR max/meanPG".value', Json_Get($buffer, '.data.pch."PR maxPG".value') & '/' & Json_Get($buffer, '.data.pch."PR meanPG".value'), True)
	endif
	; MV max/meanPG
	if IsNumber(Json_Get($buffer,'.data.mch."MV maxPG".value')) and IsNumber(Json_Get($buffer, '.data.mch."MV maxPG".value')) then
		Json_Put($buffer, '.data.mch."MV max/meanPG".value', Round(Json_Get($buffer, '.data.mch."MV maxPG".value'), 2) & '/' & Round(Json_Get($buffer, '.data.mch."MV meanPG".value'), 2), True)
	endif
	; MVA-PHT
	if IsNumber(Json_Get($buffer,'.data.mch."MV PHT".value')) then
		Json_Put($buffer, '.data.mch."MVA-PHT".value', Round(220/Json_Get($buffer, '.data.mch."MV PHT".value'), 2), True)
	endif
	; MVAi-PHT
	if IsNumber(Json_Get($buffer,'.data.mch."MVA-PHT".value')) and IsNumber(Json_Get($buffer,'.bsa')) then
		Json_Put($buffer, '.data.mch."MVAi-PHT".value', Round(Json_Get($buffer, '.data.mch."MV PHT".value')/Json_Get($buffer, '.bsa'), 2), True)
	endif
	; TV max/meanPG
	if IsNumber(Json_Get($buffer,'.data.tch."TV maxPG".value')) and IsNumber(Json_Get($buffer, '.data.tch."TV maxPG".value')) then
		Json_Put($buffer, '.data.tch."TV max/meanPG".value', Round(Json_Get($buffer, '.data.tch."TV maxPG".value'), 2) & '/' & Round(Json_Get($buffer, '.data.tch."TV meanPG".value'), 2), True)
	endif
	; AV max/meanPG
	if IsNumber(Json_Get($buffer,'.data.ach."AV maxPG".value')) and IsNumber(Json_Get($buffer, '.data.ach."AV maxPG".value')) then
		Json_Put($buffer, '.data.ach."AV max/meanPG".value', Round(Json_Get($buffer, '.data.ach."AV maxPG".value'), 2) & '/' & Round(Json_Get($buffer, '.data.ach."AV meanPG".value'), 2), True)
	endif
	; SV
	if IsNumber(Json_Get($buffer,'.data.ach."LVOT Diam".value')) and IsNumber(Json_Get($buffer, '.data.ach."LVOT VTI".value')) then
		Json_Put($buffer, '.data.ach.SV.value', Round(Json_Get($buffer,'.data.ach."LVOT VTI".value')*Json_Get($buffer,'.data.ach."LVOT Diam".value')^2*3.4159265/4/100, 2), True)
	endif
	; SVi
	if IsNumber(Json_Get($buffer,'.data.ach.SV.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.ach.SVi.value', Round(Json_Get($buffer,'.data.ach.SV.value')/Json_Get($buffer,'.bsa'), 2), True)
	endif
	; SV/SVi
	if IsNumber(Json_Get($buffer,'.data.ach.SV.value')) and IsNumber(Json_Get($buffer, '.data.ach.SVi.value')) then
		Json_Put($buffer, '.data.ach."SV/SVi".value', Round(Json_Get($buffer,'.data.ach.SV.value'), 2) & '/' & Round(Json_Get($buffer,'.data.ach.SVi.value'), 2), True)
	endif
	; AVA
	if IsNumber(Json_Get($buffer,'.data.ach."LVOT Diam".value')) and IsNumber(Json_Get($buffer, '.data.ach."LVOT VTI".value')) and IsNumber(Json_Get($buffer, '.data.ach."AV VTI".value')) then
		Json_Put($buffer, '.data.ach.AVA.value', Round(Json_Get($buffer,'.data.ach."LVOT VTI".value')*Json_Get($buffer,'.data.ach."LVOT Diam".value')^2*3.4159265/4/Json_Get($buffer,'.data.ach."LVOT Diam".value')/100, 2), True)
	endif
	; AVAi
	if IsNumber(Json_Get($buffer,'.data.ach.AVA.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.ach.AVAi.value', Round(Json_Get($buffer,'.data.ach.AVA.value')/Json_Get($buffer,'.bsa'), 2), True)
	endif
	; VTI LVOT/Ao
	if IsNumber(Json_Get($buffer, '.data.ach."LVOT VTI".value')) and IsNumber(Json_Get($buffer, '.data.ach."AV VTI".value')) then
		Json_Put($buffer, '.data.ach."VTI LVOT/Ao".value', Round(Json_Get($buffer,'.data.ach."LVOT VTI".value')/Json_Get($buffer,'.data.ach."AV VTI".value'), 2), True)
	endif
EndFunc

; gui get group index
func gui_get_group_index($i, $mod)
	if mod($i, $mod) == 0 then
		return int($i/5)
	Else
		return int($i/5+ 1)
	endif
EndFunc

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
	; columns width [ group. label | memeber.label | mameber.value | ... ]
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
	logger('Generuji dekurz: ' & @MIN & ':' & @SEC)
	;clear the clip
	_ClipBoard_Open(0)
	_ClipBoard_Empty()
	_ClipBoard_Close()

	; generate data
	for $group in Json_Get($buffer, '.group')
		; group label
		_Excel_RangeWrite($book, $book.Activesheet, Json_Get($buffer, '.group.' & $group & '.label'), 'A3')
		$book.Activesheet.Range('A3').Font.Bold = True
		for $member in Json_Get($buffer, '.data.' & $group)
			_Excel_RangeWrite($book, $book.Activesheet, Json_Get($buffer, '.data.' & $group & '.' & $member & '.label'), 'B3')
			$book.Activesheet.Range('B3').HorizontalAlignment = $xlRight;
			_Excel_RangeWrite($book, $book.Activesheet, Json_Get($buffer, '.data.' & $group & '.' & $member & '.value') , 'C3')
			$book.Activesheet.Range('C3').HorizontalAlignment = $xlCenter;
			; break
		next
		;note
		$book.Activesheet.Range('B6:H6').MergeCells = True
		_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead(Json_Get($buffer,'.group.' & $group & '.note')), 'B6')
		; group line
		With $book.Activesheet.Range('A6:H6').Borders(9)
			.LineStyle = 1
			.Weight = 2
		EndWith
	next

	; clip
	$range = $book.ActiveSheet.Range('A1:H21')
	_Excel_RangeCopyPaste($book.ActiveSheet,$range)
	if @error then return SetError(1, 0, 'Nelze kopirovat data.')
	logger('Zápis dokončen: ' & @MIN & ':' & @SEC)
EndFunc

func print()
	local $printer,$printer_error

	local $text,$x,$y

	;priner init


	$printer = _PrintDllStart($printer_error)
	if $printer = 0 then return SetError(1, 0, 'Printer error: ' & $printer_error)

	; page title
	_PrintSetDocTitle($printer,"S70 Dekurz - Pacient: " & $cmdline[1])

	; printer create page
	_PrintStartPrint($printer)

	$page_hegiht=_PrintGetPageHeight($printer)
	$page_width=_PrintGetPageWidth($printer)
	; header
	_PrintSetFont($printer,'Arial',18,0,'bold,underline')
	_PrintText($printer, $text, $x, $y)
	;logo [ bmp | jpg | ico ]
	_PrintImage($printer,"logo.bmp", $x, $y,300,350)
	; company
	_PrintText($printer, 'Julian Delphiki', $x, $y)
	_PrintText($printer, 'Street 23', $x, $y)
	_PrintText($printer, 'Rotterdam 31415', $x, $y)
	_PrintText($printer, 'Tel: 314-159-265', $x, $y)
	; patient
	_PrintText($printer, Json_Get($buffer,'.name'), $x, $y)
	_PrintText($printer, Json_Get($buffer,'.id'), $x, $y)
	_PrintText($printer, Json_Get($buffer,'.bsa'), $x, $y)
	_PrintText($printer, Json_Get($buffer,'.weight'), $x, $y)
	_PrintText($printer, Json_Get($buffer,'.height'), $x, $y)
	; separator
	_PrintSetLineWid($printer, 2)
	_PrintLine($printer, $x, $y, $x, $y)

	; data
	_PrintSetFont($printer,'Times New Roman',12,0,'')
	for $group in Json_Get($buffer, '.group')
		; group name
		_PrintText($printer, Json_Get($buffer,'.group.' & $group & '.label'), $x, $y)
		; group data
		for $member in Json_Get($buffer, '.data.' & $group)
			_PrintText($printer, Json_Get($buffer,'.data.' & $group & '.' & $member & '.label'), $x, $y)
			_PrintText($printer, Json_Get($buffer,'.data.' & $group & '.' & $member & '.value'), $x, $y)
			_PrintText($printer, Json_Get($buffer,'.data.' & $group & '.' & $member & '.unit'), $x, $y)
			; break
		next
		; separator
		_PrintSetLineWid($printer, 2)
		_PrintLine($printer, $x, $y, $x, $y)
	next

	; result
	_PrintText($printer, Json_Get($buffer,'.result'), $x, $y)

	; print
	_PrintEndPrint($printer)
	_PrintNewPage($printer)
	_printDllClose($printer)
EndFunc
