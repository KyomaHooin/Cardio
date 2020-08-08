;
; GE Vivid S70 - Medicus 3 integration
; CMD: S70.exe %RODCISN% %CELEJMENO% %VYSKA% %VAHA%
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
; TODO:
;
; gui: Red missing BSA
; parse: dup bug (Ao Diam, PV Vmax..)
; parse: dot var bug
; recount: fix cm mm conversion dup.
; print: superscript m2
; print: in-memory bitmap
;

#AutoIt3Wrapper_Icon=S70.ico
;#AutoIt3Wrapper_Outfile_x64=S70_64.exe
;#AutoIt3Wrapper_UseX64=y
#NoTrayIcon

; -------------------------------------------------------------------------------------------
; INCLUDE
; -------------------------------------------------------------------------------------------

#include <GUIConstantsEx.au3>
#include <Clipboard.au3>
#include <Excel.au3>
#include <ExcelConstants.au3>
#include <File.au3>
#include <Date.au3>
#include <Print.au3>
#include <Json.au3>

; -------------------------------------------------------------------------------------------
; VAR
; -------------------------------------------------------------------------------------------

$VERSION = '1.6'
$AGE = 24; default stored data age in hours

global $log_file = @ScriptDir & '\' & 'S70.log'
global $config_file = @ScriptDir & '\' & 'S70.ini'
global $result_file = @ScriptDir & '\' & 'zaver.txt'

global $export_path = @ScriptDir & '\' & 'input'
global $archive_path = @ScriptDir & '\' & 'archiv'

global $runtime = @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC

;data template
global $json_template='{' _
	& '"bsa":null,' _
	& '"weight":null,' _
	& '"height":null,' _
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
			& '"SV MOD A4C":{"label":null, "unit":null, "value":null},' _; calculation
			& '"SV MOD A2C":{"label":null, "unit":null, "value":null},' _; calculation
			& '"SV-biplane":{"label":"SV-biplane", "unit":"ml", "value":null, "id":null},' _
			& '"LVEDV MOD BP":{"label":"EDV", "unit":"ml", "value":null, "id":null},' _
			& '"LVESV MOD BP":{"label":"ESV", "unit":"ml", "value":null, "id":null},' _
			& '"EDVi":{"label":"EDVi", "unit":"ml/m²", "value":null, "id":null},' _
			& '"ESVi":{"label":"ESVi", "unit":"ml/m²", "value":null, "id":null}' _
		& '},' _
		& '"ls":{' _
			& '"LA Diam":{"label":"Plax", "unit":"mm", "value":null, "id":null},' _
			& '"LAV-A4C":{"label":"LAV-1D", "unit":"ml", "value":null, "id":null},' _
			& '"LAV-2D":{"label":"LAV-2D", "unit":"ml", "value":null, "id":null},' _
			& '"LAVi-2D":{"label":"LAVi-2D", "unit":"ml/m²", "value":null, "id":null},' _
			& '"LAEDV A-L A4C":{"label":null, "unit":null, "value":null},' _; calculation
			& '"LAEDV MOD A4C":{"label":null, "unit":null, "value":null},' _; calculation
			& '"LAEDV A-L A2C":{"label":null, "unit":null, "value":null},' _; calculation
			& '"LAEDV MOD A2C":{"label":null, "unit":null, "value":null},' _; calculation
			& '"LA Minor":{"label":"LA šířka", "unit":"mm", "value":null, "id":null},' _
			& '"LA Major":{"label":"LA délka", "unit":"mm", "value":null, "id":null},' _
			& '"LAVi":{"label":"LAVi-1D", "unit":"ml/m²", "value":null, "id":null}' _
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
			& '"LVOT Diam":{"label":"LVOT", "unit":"mm", "value":null, "id":null},' _
			& '"AR Rad":{"label":"PISA radius", "unit":"mm", "value":null, "id":null},' _
			& '"AV Vmax":{"label":"Vmax", "unit":"m/s", "value":null, "id":null},' _
			& '"AV maxPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"AV meanPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"AV max/meanPG":{"label":"PG max/mean", "unit":"torr", "value":null, "id":null},' _
			& '"AV VTI":{"label":"Ao-VTI", "unit":"cm/torr?", "value":null, "id":null},' _
			& '"LVOT VTI":{"label":"LVOT-VTI", "unit":"cm/torr?", "value":null, "id":null},' _
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
			& '"MR Rad":{"label":"PISA radius", "unit":"mm", "value":null, "id":null},' _
			& '"MV E Vel":{"label":"E", "unit":"cm/s", "value":null, "id":null},' _
			& '"MV A Vel":{"label":"A", "unit":"cm/s", "value":null, "id":null},' _
			& '"MV E/A Ratio":{"label":"E/A", "unit":"ratio", "value":null, "id":null},' _
			& '"MV DecT":{"label":"DecT", "unit":"ms", "value":null, "id":null},' _
			& '"MV PHT":{"label":"MR-PHT", "unit":"ms", "value":null, "id":null},' _
			& '"MV maxPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"MV meanPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"MV max/meanPG":{"label":"PG max/mean", "unit":"torr", "value":null, "id":null},' _
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
			& '"PV Vmax":{"label":"Vmax", "unit":"m/s", "value":null, "id":null},' _
			& '"PVAcc T":{"label":"ACT", "unit":"ms", "value":null, "id":null},' _
			& '"PV maxPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"PV meanPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"PV max/meanPG":{"label":"PG max/mean", "unit":"torr", "value":null, "id":null},' _
			& '"PRend PG":{"label":"PGed-reg", "unit":"torr", "value":null, "id":null},' _
			& '"PR maxPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"PR meanPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"PR max/meanPG":{"label":"PR max/meanPG", "unit":"torr", "value":null, "id":null}' _
		& '},' _
		& '"tch":{' _
			& '"TR maxPG":{"label":"PGmax-reg", "unit":"torr", "value":null, "id":null},' _
			& '"TR meanPG":{"label":"PGmean-reg", "unit":"torr", "value":null, "id":null},' _
			& '"TV maxPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"TV meanPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"TV max/meanPG":{"label":"PG max/mean", "unit":"torr", "value":null, "id":null}' _
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
if UBound($cmdline) < 3 then; minimum RC + NAME
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
if @error or not $export_file then logger('Soubor exportu nebyl nalezen: ' & $cmdline[1] & '.txt')

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

; update note from history
for $group in Json_Get($history, '.group')
	Json_Put($buffer, '.group.' & $group & '.note', Json_Get($history, '.group.' & $group & '.note'), True)
next

; update height & weight if not export
if UBound($cmdline) == 6  Then
		if not Json_Get($buffer, '.height') then Json_Put($buffer, '.height', Number($cmdline[4]), True)
		if not Json_Get($buffer, '.weight') then Json_Put($buffer, '.weight', Number($cmdline[5]), True)
endif

; update result from history or template
Json_Put($buffer, '.result', Json_Get($history, '.result'), True)
if not Json_Get($buffer, '.result') then
	$result_text = FileRead($result_file)
	if @error then
		logger('Načtení výchozího závěru selhalo.')
	else
		Json_Put($buffer, '.result', $result_text, True)
	endif
endif

; calculate values
calculate()

; -------------------------------------------------------------------------------------------
; GUI
; -------------------------------------------------------------------------------------------

$gui_index = 0
$gui_top_offset = 15; offset from basic
$gui_left_offset = 0
$gui_group_top_offset = 20
$gui_group_index = 0

;$gui = GUICreate("S70 Echo " & $VERSION & ' - ' & $cmdline[1] & ' : ' & $cmdline[2]& ' ' & $cmdline[3], 930, 1010, @DesktopWidth-930-5, 0)
$gui = GUICreate("S70 Echo " & $VERSION & ' - ' & $cmdline[1] & ' : ' & $cmdline[2]& ' ' & $cmdline[3], 930, 1010, 120, 0)

; header

$label_height = GUICtrlCreateLabel('Výška', 0, 5, 85, 17, 0x0002); right
$input_height = GUICtrlCreateInput(Json_Get($buffer, '.height'), 90, 2, 34, 19, 1)
$input_height_unit = GUICtrlCreateLabel('cm', 130, 4, 45, 21)

$label_wegiht = GUICtrlCreateLabel('Váha', 185, 5, 85, 17, 0x0002); right
$input_weight = GUICtrlCreateInput(Json_Get($buffer, '.weight'), 185 + 90, 2, 34, 19, 1)
$input_weight_unit = GUICtrlCreateLabel('kg', 185 + 130, 4, 45, 21)

$label_bsa = GUICtrlCreateLabel('BSA', 185 + 185, 5, 85, 17, 0x0002); right
$input_bsa = GUICtrlCreateInput(Json_Get($buffer, '.bsa'), 185 + 185 + 92, 2, 34, 19, BitOr(0x0001, 0x0800)); read-only
$input_bsa_unit = GUICtrlCreateLabel('m²', 185 + 185 + 130, 4, 45, 21)

$button_recount = GUICtrlCreateButton('Přepočítat', 850, 2, 75, 21)

; groups
for $group in Json_Get($history, '.group')
	for $member in Json_Get($history, '.data.' & $group)
		; data
		if IsString(Json_Get($buffer, '.data.' & $group & '."' & $member & '".label')) then
			; update index / offset
			if Mod($gui_index, 5) = 0 then; = both start or end offset!
				$gui_top_offset+=21; member spacing
				$gui_left_offset=0; reset
			Else
				$gui_left_offset+=185; column offset
			endif
			; label
			GUICtrlCreateLabel(Json_Get($buffer, '.data.' & $group & '."' & $member & '".label'), $gui_left_offset, $gui_top_offset + 3, 85, 21, 0x0002); align right
			; input
			Json_Put($buffer,'.data.' & $group & '."' & $member & '".id', GUICtrlCreateInput(Json_Get($buffer, '.data.' & $group & '."' & $member & '".value'), 90 + $gui_left_offset, $gui_top_offset, 34, 19, 1), True)
			; unit
			GUICtrlCreateLabel(Json_Get($buffer, '.data.' & $group & '."' & $member & '".unit'), 130 + $gui_left_offset, $gui_top_offset + 3, 45, 21)
			; update index
			$gui_index+=1
		endif
	next
	; note
	GUICtrlCreateLabel('Poznámka:', 0, 21 + $gui_top_offset + 3, 85, 21, 0x0002)
	Json_Put($buffer, '.group.' & $group & '.id', GUICtrlCreateInput(Json_Get($buffer, '.group.' & $group & '.note'), 90, 21 + $gui_top_offset, 825, 21))

	$gui_top_offset+=18; group spacing

	; group
	GUICtrlCreateGroup(Json_Get($buffer, '.group.' & $group & '.label'), 5, $gui_group_top_offset, 920, 21 + 21 * (gui_get_group_index($gui_index,5)+ 1))
	GUICtrlSetFont(-1, 8, 800, 0, "MS Sans Serif")
	$gui_group_top_offset += 21 + 21 * (gui_get_group_index($gui_index, 5) + 1)

	; update index / offset
	$gui_top_offset+=24; group spacing
	$gui_left_offset=0; reset
	$gui_index=0; reset
next

; dekurz
$label_dekurz = GUICtrlCreateLabel('Závěr:', 0, $gui_group_top_offset + 8, 85, 21,0x0002); align right
$edit_dekurz = GUICtrlCreateEdit(Json_Get($buffer, '.result'), 90, $gui_group_top_offset + 8, 832, 90, BitOR(64, 4096, 0x00200000)); $ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL

; date
$label_datetime = GUICtrlCreateLabel($runtime, 8, $gui_group_top_offset + 108, 150, 17)

; button
$button_history = GUICtrlCreateButton('Historie', 616, $gui_group_top_offset + 104, 75, 21)
$button_tisk = GUICtrlCreateButton('Tisk', 694, $gui_group_top_offset + 104, 75, 21)
$button_dekurz = GUICtrlCreateButton('Dekurz', 772, $gui_group_top_offset + 104, 75, 21)
$button_konec = GUICtrlCreateButton('Konec', 850, $gui_group_top_offset + 104, 75, 21)

; GUI tune
GUICtrlSetBkColor($input_height, 0xC0DCC0)
GUICtrlSetBkColor($input_weight, 0xC0DCC0)
GUICtrlSetBkColor($input_bsa, 0xC0DCC0)
GUICtrlSetState($button_konec, $GUI_FOCUS)

; GUI display
GUISetState(@SW_SHOW)

; dekurz initialize
$dekurz_init = dekurz_init()
if @error then logger($dekurz_init)

; -------------------------------------------------------------------------------------------
; MAIN
; -------------------------------------------------------------------------------------------

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
	; re-calculate
	if $msg = $button_recount Then
		; update height / weight
		Json_Put($buffer, '.height', GuiCtrlRead($input_height), True)
		Json_Put($buffer, '.weight', GuiCtrlRead($input_weight), True)
		; update data buffer
		for $group in Json_Get($history, '.group')
			for $member in Json_Get($history, '.data.' & $group)
				if not GuiCtrlRead(Json_Get($buffer, '.data.'  & $group & '."' & $member & '".id')) then
					Json_Put($buffer, '.data.'  & $group & '."' & $member & '".value', Null)
				else
					Json_Put($buffer, '.data.'  & $group & '."' & $member & '".value', Number(GuiCtrlRead(Json_Get($buffer, '.data.'  & $group & '."' & $member & '".id'))))
				endif
			next
		next
		; re-calculate
		calculate()
		; re-fill BSA
		GUICtrlSetData($input_bsa, Json_Get($buffer, '.bsa'))
		; re-fill data
		for $group in Json_Get($history, '.group')
			for $member in Json_Get($history, '.data.' & $group)
				GUICtrlSetData(Json_Get($buffer, '.data.' & $group & '."' & $member & '".id'), Json_Get($buffer,'.data.' & $group & '."' & $member & '".value'))
			next
		next
	endif
	; load history
	if $msg = $button_history Then
		MsgBox(0,"debug", _DateDiff('h', $runtime, Json_Get($history,'.date')))
		if FileExists($archive_file) then
			if _DateDiff('h', $runtime, Json_Get($history,'.date')) < $AGE then
				if msgbox(4, 'S70 Echo ' & $VERSION & ' - Historie', 'Načíst poslední naměřené hodnoty?') = 6 then
					; update GUI from history
					for $group in Json_Get($buffer, '.group')
						; update note
						GUICtrlSetData(Json_Get($buffer, '.group.' & $group & '.id'), Json_Get($history, '.group.' & $group & '.note'))
						; update data
						for $member in Json_Get($buffer, '.data.' & $group)
							GUICtrlSetData(Json_Get($buffer,'.data.' & $group & '."' & $member & '".id'), Json_Get($history,'.data.' & $group & '."' & $member & '".value'))
						next
					next
				endif
			else
				msgbox(48, 'S70 Echo ' & $VERSION & ' - Historie', 'Nelze načís historii. Příliš stará data.')
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
		; update result
		Json_Put($buffer, '.result', GuiCtrlRead($edit_dekurz), True)
		; update height / weight
		Json_Put($buffer, '.height', GuiCtrlRead($input_height), True)
		Json_Put($buffer, '.weight', GuiCtrlRead($input_weight), True)
		; update data buffer
		for $group in Json_Get($history, '.group')
			; update note
			Json_Put($buffer, '.group.' & $group & '.note', GuiCtrlRead(Json_Get($buffer, '.group.' & $group & '.id')))
			; update data
			for $member in Json_Get($history, '.data.' & $group)
				if not GuiCtrlRead(Json_Get($buffer, '.data.'  & $group & '."' & $member & '".id')) then
					Json_Put($buffer, '.data.'  & $group & '."' & $member & '".value', Null)
				else
					Json_Put($buffer, '.data.'  & $group & '."' & $member & '".value', Number(GuiCtrlRead(Json_Get($buffer, '.data.'  & $group & '."' & $member & '".id'))))
				endif
			next
		next
		; update timestamp
		Json_Put($buffer, '.date', $runtime, True)
		; write data buffer to archive
		$out = FileOpen($archive_file, 2 + 256); UTF8 / BOM overwrite
		FileWrite($out, Json_Encode($buffer))
		if @error then logger('Zápis archivu selhal: ' & $cmdline[1] & '.dat')
		FileClose($out)
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
func export_parse($export)
	local $raw
	_FileReadToArray($export, $raw, 0); no count
	if @error then return SetError(1, 0, 'Nelze načíst souboru exportu.')
	; parse basic
	for $i = 0 to UBound($raw) - 1
		if StringRegExp($raw[$i], '^BSA\h.*') then Json_Put($buffer, '.bsa', Number(StringRegExpReplace($raw[$i], '^BSA\h(.*) .*', '$1')), True)
		if StringRegExp($raw[$i], '^Height\h.*') then Json_Put($buffer, '.height', Number(StringRegExpReplace($raw[$i], '^Height\h(.*) .*', '$1')), True)
		if StringRegExp($raw[$i], '^Weight\h.*') then Json_Put($buffer, '.weight', Number(StringRegExpReplace($raw[$i], '^Weight\h(.*) .*', '$1')), True)
	next
	; parse data
	for $group in Json_ObjGet($history, '.group')
		for $member in Json_ObjGet($history, '.data.' & $group)
			for $j = 0 to UBound($raw) - 1
				if StringRegExp($raw[$j], '^' & $member & '\t.*') then
					StringReplace($raw[$j], @TAB, ''); test tabs
					if @extended == 2 Then
						Json_Put($buffer, '.data.' & $group & '."' & $member & '".value', Round(Number(StringRegExpReplace($raw[$j], '^.*\t(.*)\t.*', '$1')), 1), True); check exists
					elseif @extended == 1 then
						Json_Put($buffer, '.data.' & $group & '."' & $member & '".value', Round(Number(StringRegExpReplace($raw[$j], '.*\t(.*)$', '$1')), 1), True)
					endif
				endif
			next
		next
	next
endfunc

; calculate aditional variables
func calculate()
	; BSA
	if IsNumber(Json_Get($buffer, '.weight')) and IsNumber(Json_Get($buffer, '.height')) and not IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.bsa', Round((Json_Get($buffer, '.weight')^0.425)*(Json_Get($buffer, '.height')^0.725)*71.84*(10^-4), 1), True)
	EndIf
	; LVEF % Teich.
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVIDs.value')) then
		Json_Put($buffer, '.data.lk."LVEF % Teich".value', Round((7/(2.4+Json_Get($buffer, '.data.lk.LVIDd.value')/10)*(Json_Get($buffer, '.data.lk.LVIDd.value')/10)^3-7/(2.4+Json_Get($buffer, '.data.lk.LVIDs.value')/10)*(Json_Get($buffer, '.data.lk.LVIDs.value')/10)^3)/(7/(2.4+Json_Get($buffer, '.data.lk.LVIDd.value')/10)*(Json_Get($buffer, '.data.lk.LVIDd.value')/10)^3)*100, 1), True)
	endif
	; LVmass
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.IVSd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVPWd.value')) then
		Json_Put($buffer, '.data.lk.LVmass.value', Round(1.04*(Json_get($buffer, '.data.lk.LVIDd.value')/10 + Json_Get($buffer, '.data.lk.IVSd.value')/10 + Json_Get($buffer, '.data.lk.LVPWd.value')/10)^3-(Json_Get($buffer, '.data.lk.LVIDd.value')/10)^3-13.6, 1), True)
	endif
	; LVmass-i^2,7
	if IsNumber(Json_Get($buffer, '.height')) and IsNumber(Json_Get($buffer, '.data.lk.LVmass.value')) then
		Json_Put($buffer, '.data.lk."LVmass-i^2,7".value', Round(Json_Get($buffer, '.data.lk.LVmass.value')/(Json_Get($buffer, '.height')/100)^2.7, 1), True)
	endif
	; LVmass-BSA
	if IsNumber(Json_Get($buffer, '.bsa')) and IsNumber(Json_Get($buffer, '.data.lk.LVmass.value')) then
		Json_Put($buffer, '.data.lk.LVmass-BSA.value', Round(Json_Get($buffer, '.data.lk.LVmass.value')/Json_Get($buffer, '.bsa'), 1), True)
	endif
	; RTW
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVPWd.value')) then
		Json_Put($buffer, '.data.lk.RTW.value', Round(2*Json_Get($buffer, '.data.lk.LVPWd.value')/Json_Get($buffer, '.data.lk.LVIDd.value'), 1), True)
	endif
	; FS
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVIDs.value')) then
		Json_Put($buffer, '.data.lk.FS.value', Round((Json_Get($buffer, '.data.lk.LVIDd.value')-Json_Get($buffer, '.data.lk.LVIDs.value'))/Json_Get($buffer, '.data.lk.LVIDd.value')*100, 1), True)
	endif
	; SV-biplane
	if IsNumber(Json_Get($buffer, '.data.lk."SV MOD A2C".value')) and IsNumber(Json_Get($buffer, '.data.lk."SV MOD A4C".value')) then
		Json_Put($buffer, '.data.lk.SV-biplane.value', Round((Json_Get($buffer, '.data.lk."SV MOD A4C".value') + Json_Get($buffer, '.data.lk."SV MOD A2C".value'))/2, 1), True)
	endif
	;EDVi
	if IsNumber(Json_Get($buffer, '.data.lk."LVEDV MOD BP".value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.lk.EDVi.value', Round(Json_Get($buffer, '.data.lk."LVEDV MOD BP".value')/Json_Get($buffer, '.bsa'), 1), True)
	endif
	;ESVi
	if IsNumber(Json_Get($buffer, '.data.lk."LVESV MOD BP".value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.lk.ESVi.value', Round(Json_Get($buffer, '.data.lk."LVESV MOD BP".value')/Json_Get($buffer, '.bsa'), 1), True)
	endif
	; LAV-A4C
	if IsNumber(Json_Get($buffer, '.data.ls."LAEDV A-L A4C".value')) and IsNumber(Json_Get($buffer, '.data.ls."LAEDV MOD A4C".value')) then
		Json_Put($buffer, '.data.ls.LAV-A4C.value', Round((Json_Get($buffer, '.data.ls."LAEDV A-L A4C".value') + Json_Get($buffer, '.data.ls."LAEDV MOD A4C".value'))/2, 1), True)
	endif
	; LAV-2D
	if IsNumber(Json_Get($buffer,'.data.ls.LAV-A4C.value')) and IsNumber(Json_Get($buffer, '.data.ls."LAEDV A-L A2C".value')) and IsNumber(Json_Get($buffer, '.data.ls."LAEDV MOD A2C".value')) then
		Json_Put($buffer, '.data.ls.LAV-2D.value',Round((Json_Get($buffer, '.data.ls.LAV-A4C.value')+(Json_Get($buffer, '.data.ls."LAEDV A-L A2C".value') + Json_Get($buffer, '.data.ls."LAEDV MOD A2C".value'))/2)/2, 1), True)
	endif
	; LAVi-2D
	if IsNumber(Json_Get($buffer,'.data.ls.LAV-2D.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.ls.LAVi-2D.value', Round(Json_Get($buffer, '.data.ls.LAV-2D.value')/Json_Get($buffer, '.bsa'), 1), True)
	endif
	;MR Rad
	if IsNumber(Json_Get($buffer,'.data.mch."MR Rad".value')) then
		Json_Put($buffer, '.data.mch."MR Rad".value', Round(Json_Get($buffer, '.data.mch."MR Rad".value')*100, 1), True)
	endif
	;AR Rad
	if IsNumber(Json_Get($buffer,'.data.ach."AR Rad".value')) then
		Json_Put($buffer, '.data.ach."AR Rad".value', Round(Json_Get($buffer, '.data.ach."AR Rad".value')*100, 1), True)
	endif
	;PV Vmax
	if IsNumber(Json_Get($buffer,'.data.pch."PV Vmax".value')) then
		Json_Put($buffer, '.data.pch."PV Vmax".value', Round(Json_Get($buffer, '.data.pch."PV Vmax".value')/100, 1), True)
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
		Json_Put($buffer, '.data.mch."MV max/meanPG".value', Round(Json_Get($buffer, '.data.mch."MV maxPG".value'), 2) & '/' & Round(Json_Get($buffer, '.data.mch."MV meanPG".value'), 1), True)
	endif
	; MVA-PHT
	if IsNumber(Json_Get($buffer,'.data.mch."MV PHT".value')) then
		Json_Put($buffer, '.data.mch."MVA-PHT".value', Round(220/Json_Get($buffer, '.data.mch."MV PHT".value'), 1), True)
	endif
	; MVAi-PHT
	if IsNumber(Json_Get($buffer,'.data.mch."MVA-PHT".value')) and IsNumber(Json_Get($buffer,'.bsa')) then
		Json_Put($buffer, '.data.mch."MVAi-PHT".value', Round(Json_Get($buffer, '.data.mch."MV PHT".value')/Json_Get($buffer, '.bsa'), 1), True)
	endif
	; TV max/meanPG
	if IsNumber(Json_Get($buffer,'.data.tch."TV maxPG".value')) and IsNumber(Json_Get($buffer, '.data.tch."TV maxPG".value')) then
		Json_Put($buffer, '.data.tch."TV max/meanPG".value', Round(Json_Get($buffer, '.data.tch."TV maxPG".value'), 2) & '/' & Round(Json_Get($buffer, '.data.tch."TV meanPG".value'), 1), True)
	endif
	; AV max/meanPG
	if IsNumber(Json_Get($buffer,'.data.ach."AV maxPG".value')) and IsNumber(Json_Get($buffer, '.data.ach."AV maxPG".value')) then
		Json_Put($buffer, '.data.ach."AV max/meanPG".value', Round(Json_Get($buffer, '.data.ach."AV maxPG".value'), 2) & '/' & Round(Json_Get($buffer, '.data.ach."AV meanPG".value'), 1), True)
	endif
	; SV
	if IsNumber(Json_Get($buffer,'.data.ach."LVOT Diam".value')) and IsNumber(Json_Get($buffer, '.data.ach."LVOT VTI".value')) then
		Json_Put($buffer, '.data.ach.SV.value', Round(Json_Get($buffer,'.data.ach."LVOT VTI".value')*Json_Get($buffer,'.data.ach."LVOT Diam".value')^2*3.4159265/4/100, 1), True)
	endif
	; SVi
	if IsNumber(Json_Get($buffer,'.data.ach.SV.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.ach.SVi.value', Round(Json_Get($buffer,'.data.ach.SV.value')/Json_Get($buffer,'.bsa'), 1), True)
	endif
	; SV/SVi
	if IsNumber(Json_Get($buffer,'.data.ach.SV.value')) and IsNumber(Json_Get($buffer, '.data.ach.SVi.value')) then
		Json_Put($buffer, '.data.ach."SV/SVi".value', Round(Json_Get($buffer,'.data.ach.SV.value'), 2) & '/' & Round(Json_Get($buffer,'.data.ach.SVi.value'), 1), True)
	endif
	; AVA
	if IsNumber(Json_Get($buffer,'.data.ach."LVOT Diam".value')) and IsNumber(Json_Get($buffer, '.data.ach."LVOT VTI".value')) and IsNumber(Json_Get($buffer, '.data.ach."AV VTI".value')) then
		Json_Put($buffer, '.data.ach.AVA.value', Round(Json_Get($buffer,'.data.ach."LVOT VTI".value')*Json_Get($buffer,'.data.ach."LVOT Diam".value')^2*3.4159265/4/Json_Get($buffer,'.data.ach."LVOT Diam".value')/100, 1), True)
	endif
	; AVAi
	if IsNumber(Json_Get($buffer,'.data.ach.AVA.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.ach.AVAi.value', Round(Json_Get($buffer,'.data.ach.AVA.value')/Json_Get($buffer,'.bsa'), 1), True)
	endif
	; VTI LVOT/Ao
	if IsNumber(Json_Get($buffer, '.data.ach."LVOT VTI".value')) and IsNumber(Json_Get($buffer, '.data.ach."AV VTI".value')) then
		Json_Put($buffer, '.data.ach."VTI LVOT/Ao".value', Round(Json_Get($buffer,'.data.ach."LVOT VTI".value')/Json_Get($buffer,'.data.ach."AV VTI".value'), 1), True)
	endif
EndFunc

; gui get group index
func gui_get_group_index($i, $mod)
	if mod($i, $mod) == 0 then
		return int($i/5)
	Else
		return int($i/5 + 1)
	endif
EndFunc

; initialize XLS template
func dekurz_init()
	; excel
	$excel = _Excel_Open(False, False, False, False, True)
;	$excel = _Excel_Open()
	if @error then return SetError(1, 0, 'Nelze spustit aplikaci Excel.')
	$book = _Excel_BookNew($excel)
	if @error then return SetError(1, 0, 'Nelze vytvořit book.')
	; default font
	$book.Activesheet.Range('A1:P32').Font.Size = 8
	; columns height
	$book.Activesheet.Range('A1:P32').RowHeight = 13
	; number format
	$book.Activesheet.Range('A1:P32').NumberFormat = "@"; string
	; columns width [ group. label | member.label | member.value | member.unit | ... ]
	$book.Activesheet.Range('A1').ColumnWidth = 15; group A-P
	for $i = 0 to 4; five columns starts B[66]
		$book.Activesheet.Range(Chr(66 + 3*$i) & '1').ColumnWidth = 9
		$book.Activesheet.Range(Chr(66 + 3*$i + 1) & '1').ColumnWidth = 3.5
		$book.Activesheet.Range(Chr(66 + 3*$i + 2) & '1').ColumnWidth = 4.5
	Next
endFunc

func not_empty_group($group)
	if StringLen(GUICtrlRead(Json_Get($buffer, '.group.' & $group & '.id'))) > 0 then return True
	for $member in Json_Get($history, '.data.' & $group)
		if GUICtrlRead(Json_Get($buffer, '.data.' & $group & '."' & $member & '".id')) then return True
	next
	return False
endFunc

; update XLS data & write clipboard
func dekurz()
;	logger('Generuji dekurz: ' & @MIN & ':' & @SEC)
	;clear the clip
	_ClipBoard_Open(0)
	_ClipBoard_Empty()
	_ClipBoard_Close()

	$row_index = 1
	$column_index = 65; A ... 66-68 BCD, 69-71 EFG, 72-74 HIJ, 75-77 KLM, 78-80 NOP

	; generate data
	for $group in Json_Get($history, '.group')
		if not_empty_group($group) then
			; group label
			_Excel_RangeWrite($book, $book.Activesheet, Json_Get($buffer, '.group.' & $group & '.label'), 'A' & $row_index)
			$book.Activesheet.Range('A' & $row_index).Font.Bold = True
			for $member in Json_Get($history, '.data.' & $group)
				if GUICtrlRead(Json_Get($buffer, '.data.' & $group & '."' & $member & '".id')) then; has value
					; update index
					if $column_index == 80 Then; reset
						$column_index = 65
						$row_index+=1
					endif
					; label
					_Excel_RangeWrite($book, $book.Activesheet, String(Json_Get($buffer, '.data.' & $group & '."' & $member & '".label')), Chr($column_index + 1) & $row_index)
					$book.Activesheet.Range(Chr($column_index + 1) & $row_index).HorizontalAlignment = $xlRight;
					; value
					_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead(Json_Get($buffer, '.data.' & $group & '."' & $member & '".id')) , Chr($column_index + 2) & $row_index)
					; unit
					$book.Activesheet.Range(Chr($column_index + 2) & $row_index).HorizontalAlignment = $xlCenter;
					_Excel_RangeWrite($book, $book.Activesheet, Json_Get($buffer, '.data.' & $group & '."' & $member & '".unit') , Chr($column_index + 3) & $row_index)
					; update index
					$column_index+=3
				endif
			next
			; note
			if StringLen(GUICtrlRead(Json_Get($buffer,'.group.' & $group & '.id'))) > 0 then
				if $column_index <> 65 then $row_index+=1; not only note
				$book.Activesheet.Range('B' & $row_index & ':P' & $row_index).MergeCells = True
				_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead(Json_Get($buffer,'.group.' & $group & '.id')), 'B' & $row_index)
			endif
			; group line
			With $book.Activesheet.Range('A' & $row_index & ':P' & $row_index).Borders(9)
				.LineStyle = 1
				.Weight = 2
			EndWith
			; update index
			$row_index+=1
			$column_index = 65
		endif
	next
	; result
	$book.Activesheet.Range('A' & $row_index & ':P' & $row_index).MergeCells = True
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($edit_dekurz), 'A' & $row_index)
	; result line
	With $book.Activesheet.Range('A' & $row_index & ':P' & $row_index).Borders(9)
		.LineStyle = 1
		.Weight = 2
	EndWith
	; clip
	_Excel_RangeCopyPaste($book.ActiveSheet, 'A1:P' & $row_index)
	if @error then return SetError(1, 0, 'Nelze kopirovat data.')
;	logger('Zápis dokončen: ' & @MIN & ':' & @SEC)
EndFunc

func print(); 2100 x 2970
;	logger('Generuji tisk: ' & @MIN & ':' & @SEC)
	local $printer, $printer_error
	;priner init
	$printer = _PrintDllStart($printer_error)
	if $printer = 0 then return SetError(1, 0, 'Printer error: ' & $printer_error)
	; printer create page
	_PrintStartPrint($printer)

	$max_height = _PrintGetPageHeight($printer) - _PrintGetYOffset($printer)
	$max_width = _PrintGetPageWidth($printer) - _PrintGetXOffset($printer)
	$line_offset = 5
	$line_max = $max_width - 100
	$top_offset = 0

	;logo
	_PrintImage($printer,@ScriptDir & '\' & 'logo_128x128.bmp', 50,50,300,300)
	; QR code
	_PrintImage($printer,@ScriptDir & '\' & 'vcard.bmp', $max_width - 300 - 50, 50, 300,300)
	; address
	_PrintSetFont($printer,'Arial',12, Default, Default)
	$text_height = _PrintGetTextHeight($printer, 'Arial')
	$top_offset += 125
	_PrintText($printer, 'Cardiologie - Petr Vesely', ($max_width - _PrintGetTextWidth($printer, 'Cardiologie - Petr Vesely'))/2, $top_offset)
	$top_offset+=$text_height + $line_offset
	_PrintText($printer, 'Kounicova 1350 / 15', ($max_width - _PrintGetTextWidth($printer, 'Kounicova 1350 / 15'))/2, $top_offset)
	$top_offset+=$text_height + $line_offset
	_PrintText($printer, 'Praha 17 16300', ($max_width - _PrintGetTextWidth($printer, 'Praha 17 16300'))/2, $top_offset)
	$top_offset+=$text_height + $line_offset
	_PrintText($printer, 'Tel: +420315159265', ($max_width - _PrintGetTextWidth($printer, 'Tel: +420315159265'))/2, $top_offset)
	$top_offset+=$text_height + $line_offset
	; separator
	_PrintSetLineWid($printer, 2)
	_PrintLine($printer, 50, $top_offset + 85, $max_width - 50, $top_offset + 85)
	$top_offset+=85
	; patient
	_PrintSetFont($printer, 'Arial',10, Default, Default)
	$text_height = _PrintGetTextHeight($printer, 'Arial')
	$top_offset += 50
	_PrintText($printer, 'Jmeno: ' & $cmdline[2]& ' ' & $cmdline[3], 50, $top_offset)
	_PrintText($printer, 'Vyska: ' & GUICtrlRead($input_height) & ' cm', 550, $top_offset)
	_PrintText($printer, 'BSA: ' & GUICtrlRead($input_bsa) & ' m²', 1050, $top_offset)
	$top_offset+=$text_height + $line_offset
	_PrintText($printer, 'Rodne cislo: ' & $cmdline[1], 50, $top_offset)
	_PrintText($printer, 'Vaha: ' & GUICtrlRead($input_weight) & ' kg', 550, $top_offset)
	; separator
	_PrintSetLineWid($printer, 2)
	_PrintLine($printer, 50, $top_offset + 90, $max_width - 50, $top_offset + 90)
	$top_offset+=90
	; data
	_PrintSetFont($printer, 'Arial',10, Default, Default)
	$text_height = _PrintGetTextHeight($printer, 'Arial')
	$top_offset += 50
	for $group in Json_Get($history, '.group')
		if not_empty_group($group) then
			; line index
			$line_index = 1
			; group name
			_PrintSetFont($printer, 'Arial',10, Default, 'bold')
			_PrintText($printer, Json_Get($buffer,'.group.' & $group & '.label'), 50, $top_offset)
			$top_offset += $text_height + $line_offset
			_PrintSetFont($printer, 'Arial',10, Default, Default)
			; group data
			for $member in Json_Get($history, '.data.' & $group)
				if GUICtrlRead(Json_Get($buffer, '.data.' & $group & '."' & $member & '".id')) then; has value
					if $line_index = 5 Then
						$line_index = 1
						$top_offset += $text_height + $line_offset
					endif
					_PrintText($printer, Json_Get($buffer,'.data.' & $group & '."' & $member & '".label') & ' ' & String(GuiCtrlRead(Json_Get($buffer,'.data.' & $group & '."' & $member & '".id'))) & ' ' & Json_Get($buffer,'.data.' & $group & '."' & $member & '".unit'), 400*$line_index, $top_offset)
					$line_index+=1
				endif
			next
			; update offset [?]
			$top_offset += $text_height + $line_offset
			; note
			$line_len = 50
			if StringLen(GUICtrlRead(Json_Get($buffer,'.group.' & $group & '.id')))> 1 then
				for $word in StringSplit(GUICtrlRead(Json_Get($buffer,'.group.' & $group & '.id')), ' ', 2); no count
					if _PrintGetTextWidth($printer, ' ' & $word) + $line_len > $line_max Then
						$line_len=50
						$top_offset+=$text_height + $line_offset
					EndIf
					_PrintText($printer, ' ' & $word, $line_len, $top_offset)
					$line_len+=_PrintGetTextWidth($printer, ' ' & $word)
				next
				; update offset
				$top_offset += $text_height + $line_offset
			endif
		endif
	next
	; separator
	_PrintSetLineWid($printer, 2)
	_PrintLine($printer, 50, $top_offset + 50, $max_width - 50, $top_offset + 50)
	$top_offset += 50
	; result
	_PrintSetFont($printer, 'Arial',10, Default, Default)
	$text_height = _PrintGetTextHeight($printer, 'Arial')
	$top_offset += 50
	$line_len = 50
	for $word in StringSplit(GUICtrlRead($edit_dekurz), ' ', 2); no count
		if _PrintGetTextWidth($printer, ' ' & $word) + $line_len > $line_max Then
			$line_len=50
			$top_offset+=$text_height + $line_offset
		EndIf
		_PrintText($printer, ' ' & $word, $line_len, $top_offset)
		$line_len+=_PrintGetTextWidth($printer, ' ' & $word)
	next
	$top_offset += $text_height + $line_offset
	; date
	$top_offset += 10
	_PrintText($printer, 'Datum: ' & $runtime, 50, $max_height - 100)
	; singnature
	_PrintText($printer, 'Podpis:', 1500, $max_height - 100)
	_PrintSetLineWid($printer, 2)
	_PrintLine($printer, 1650, $max_height - 80, $max_width - 50, $max_height - 80)
	; print
	_PrintEndPrint($printer)
	_PrintNewPage($printer)
	_printDllClose($printer)
;	logger('Tisknu: ' & @MIN & ':' & @SEC)
EndFunc
