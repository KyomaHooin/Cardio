;
; Meducus 3 - S70 & TXT to XLSX templeter
;
; patient ID = RC
; filename = RC_YYYYMMDD_HHMMSS.txt
;

#AutoIt3Wrapper_Icon=S70.ico
#NoTrayIcon

; INLUDE

#include <File.au3>
#include <Excel.au3>

;VAR

$version = '1.2'

$ini = @ScriptDir & '\' & 'S70.ini'
$logfile = @ScriptDir & '\' & 'S70.log'
$template = @ScriptDir & '\' & 'S70_template.xlsx'
$medicus_out = @ScriptDir & '\' & 'S70_medicus_out.dat'
$medicus_in = @ScriptDir & '\' & 'S70_medicus_in.dat'
$archive_path = @ScriptDir & '\' & 'archive'

global $configuration[0][2]
global $medicus_id[0]
global $raw[0]
global $map[0]
global $d2[0]
global $d2calc[0]
global $doppler[0]

;_ArrayDisplay($CmdLine)

;CONTROL

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

; create archive
DirCreate($archive_path)

; INIT

logger('Program begin: ' & @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC)

; test file
if not FileExists($ini) then
	logger('Nelze nalézt konfigurační INI soubor.')
	program_exit()
endif
logger("Mam konfiguracni soubor.")

if not FileExists($template) then
	logger('Nelze nalézt XLSX šablonu.')
	program_exit()
endif
logger("Mam sablonu.")

if not FileExists($medicus_in) then
	logger('Nelze nalézt vstupní Medicus soubor.')
	program_exit()
endif
logger("Mam vstupni medicus in.")

; load config
_FileReadToArray($ini, $configuration, 0, '=')
if @error then
	logger('Načtení konfiguračního INI souboru selhalo.')
	program_exit()
endif
logger("Mam nactene INI.")

; test export setup
$txt_path = StringRegExpReplace($configuration[0][1],'\\+$', ''); remove trailing slash
if not $txt_path or not FileExists($txt_path) then
	logger('Neplatný adresář pro export.')
	program_exit()
endif
logger("Mam export adresar z konfigurace.")

; test medicus ID
_FileReadToArray($medicus_in, $medicus_id, 0)
if @error then
	logger('Načtení ID pacienta selhalo.')
	program_exit()
endif
logger("Mam mam id pacienta z medicus in.")

; MAIN

; load config
$d2 = get_map(StringSplit($configuration[1][1], '|', 2))
$d2calc = get_map(StringSplit($configuration[2][1], '|', 2))
$doppler = get_map(StringSplit($configuration[3][1], '|', 2))

;_ArrayDisplay($d2)
;_ArrayDisplay($d2calc)
;_ArrayDisplay($doppler)

logger("Mam mam data z konfigurace.")

; get filename
$filename = @ScriptDir & '\' & $medicus_id[0] & '_' & @YEAR & @MON & @MDAY & '_' & @HOUR & @MIN & @SEC & '.xlsx'

; check export
$txt_file = file_from_export($medicus_id[0], $txt_path)
logger("Mam soubor z exportu.")

; check archive
$archive_file = file_from_archive($medicus_id[0], $archive_path)
logger("Mam soubor z archivu.")

if not $txt_file then
	logger("Archive yes/no?")
	; load archive ?
	if msgbox(4, 'S70 Echo - Historie', 'Načíst poslední záznam?') = 6 then; OK
		logger("Archive yes.")
		if $archive_file then; archived ?
			logger("Archive yes,  have file..")
			FileCopy($archive_path & '\' & $archive_file, $filename)
			if @error then
				logger('Načtení z archivu selhalo.')
				FileCopy($template, $filename)
			endif
		else
			logger("Archive yes, but no file..")
			FileCopy($template, $filename)
		endif
	else
		logger("Archive yes/no .. no..")
		FileCopy($template, $filename)
	endif
else
	logger("loading export file.. " & $txt_file)
	; load export
	_FileReadToArray($txt_path & '\' & $txt_file, $raw, 0)
	if @error then
		logger('Načtení exportu ' & $txt_file  & ' selhalo.')
		FileCopy($template, $filename)
	else
;		_ArrayDisplay($raw)
		; parse export
;		logger("parsing export file..")
;		$data = parse_export($raw)
;		_ArrayDisplay($data)
		; write export
		;logger("writing parsed data..")
		;if $archive_file then
		;	template_update_data($data, $filename, 0)
		;else
		;	template_update_data($data, $filename, 1)
		;endif
	endif
	;export cleanup
	logger("dropping export file..")
	;FileDelete($txt_path & '\' & $txt_file)
endIf

; update temeplate header
;logger("updating tempelat header..")
;if $archive_file then template_update_header($archive_path & '\' & $archive_file, $filename)

; run temeplate
logger("running templete..")
$excel = _Excel_Open()
$book = _Excel_BookOpen($excel, $filename)
while 1
	_ArraySearch(_Excel_BookList(), $filename)
	if @error then ExitLoop
	sleep(5000)
wend

logger("running templete end..")

;parse new data
;logger("parsing data back..")
;$new = template_read_data($filename)
$new = ''

;write_medicus
logger("writing medicus output..")
write_medicus($new, $medicus_out)

;update archive
logger("updating archive..")
if FileExists($filename) then
	MsgBox(0, "archive","Will move to archive!")
	if $archive_file then
		FileDelete($archive_path & '\' & $archive_file)
	endif
	FileMove($filename, $archive_path)
endif

program_exit()

; FUNC

func  program_exit()
	logger('Program exit: ' & @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC)
	logger('------------------------------------')
	FileClose($log)
	exit
EndFunc

func logger($text)
	FileWriteLine($logfile, $text)
endfunc

func file_from_archive($id, $path)
	$list = _FileListToArray($path, '*.xlsx')
	if not @error then
		for $i = 1 to ubound($list) - 1
			if StringRegExp($list[$i], '^' & $id & '_.*') then return $list[$i]
		next
	endif
endfunc

func file_from_export($id, $path)
	$list = _FileListToArray($path, '*.txt')
	if not @error then
		for $i = 1 to ubound($list) - 1
	;		MsgBox(0,"regexping...", $id & ' ' & $list[$i])
			if StringRegExp($list[$i], '^' & $id & '_.*') then return $list[$i]
		next
	endif
endfunc

func get_map($list)
;	_ArrayDisplay($list)
	local $map[0][2]
;	; valid touples
	if Mod(UBound($list), 2) <> 0 then return
	for $i=0 to UBound($list) / 2 - 1
		_ArrayAdd($map, $list[2 * $i] & '|' & $list[2 * $i + 1])
	next
	return $map
EndFunc

func parse_export($raw)
	local $map[0][2], $d2_index, $d2calc_index, $doppler_index
	; header
	_ArrayAdd($map, 'name' & '|' & StringRegExpReplace($raw[8], 'Name ', ''))
	_ArrayAdd($map, 'id' & '|' & StringRegExpReplace($raw[9], 'Patient Id ', ''))
	_ArrayAdd($map, 'bsa' & '|' & StringRegExpReplace($raw[10], 'BSA ', ''))
	_ArrayAdd($map, 'height' & '|' & StringRegExpReplace($raw[11], 'Height ', ''))
	_ArrayAdd($map, 'weight' & '|' & StringRegExpReplace($raw[12], 'Weight ', ''))
	_ArrayAdd($map, 'date' &'|' & StringRegExpReplace($raw[13], 'Date ', ''))
	; index
	for $i = 0 to ubound($raw) - 1
		if StringRegExp($raw[$i], '2-D parametry') then	$d2_index = $i
		if StringRegExp($raw[$i], '2-D kalkulace') then $d2calc_index = $i
		if StringRegExp($raw[$i], 'Doppler') then $doppler_index = $i
		if StringRegExp($raw[$i], 'Souhrn:') then $end_index = $i
	next
	; data
	for $i = $d2_index + 2 to $d2calc_index - 2
		_ArrayAdd($map, StringRegExpReplace($raw[$i], '^  +\d+.*', '') & '|' & StringRegExpReplace($raw[$i], '.*(\d+.?\d+).*', '$1'))
	next
;	for $i = $d2calc_index to $doppler_index - 2
;		$map[StringRegExpReplace($raw[$i], ' +\d+.*', '')] = StringRegExpReplace($raw[$i], '.*(\d+.?\d+).*', '\\1')
;	next
;	for $i = $doppler to $end_index
;		$map[StringRegExpReplace($raw[$i], ' +\d+.*', '')] = StringRegExpReplace($raw[$i], '.*(\d+.?\d+).*', '\\1')
;	next
	return $map
endfunc

func template_update_data($data, $file, $header)
	$excel = _Excel_Open(False, False, False, False, True)
	if @error Then Return SetError(1, 0, 'Nelze spustit aplikaci Excel.')
	$book = _Excel_BookOpen($excel, $file, False, False)
	if @error Then return SetError(1, 0, 'Nelze načíst soubor: ' & $file)

	;if $header then
	;_Excel_RangeWrite($book, $excel.ActiveSheet, $name, 'B2')

	_Excel_BookSave($book)
	_Excel_BookClose($book)
	_Excel_Close($excel)
endfunc

func template_read_data($file)
	$excel = _Excel_Open(False, False, False, False, True)
	if @error Then Return SetError(1, 0, 'Nelze spustit aplikaci Excel.')
	$book = _Excel_BookOpen($excel, $file, True, False)
	if @error Then return SetError(1, 0, 'Nelze načíst soubor: ' & $file)

	;_Excel_RangeWrite($book, $excel.ActiveSheet, $name, 'B2')

	_Excel_BookClose($book)
	_Excel_Close($excel)
endfunc

func template_update_header($in, $out)
	$excel = _Excel_Open(False, False, False, False, True)
	if @error Then Return SetError(1, 0, 'Nelze spustit aplikaci Excel.')
	$book = _Excel_BookOpen($excel, $in, True, False)
	if @error Then return SetError(1, 0, 'Nelze načíst soubor: ' & $in & ' z archivu.')

	;read header
	$name =	_Excel_RangeRead($book, $excel.ActiveSheet, 'B2'); name
	$rc = _Excel_RangeRead($book, $excel.ActiveSheet, 'G2'); RC
	$poj = _Excel_RangeRead($book, $excel.ActiveSheet, 'J2'); poj.
	$tf = _Excel_RangeRead($book, $excel.ActiveSheet, 'B4'); TF
	$height = _Excel_RangeRead($book, $excel.ActiveSheet, 'E4'); height
	$weight = _Excel_RangeRead($book, $excel.ActiveSheet, 'H4'); weight
	$rhythm = _Excel_RangeRead($book, $excel.ActiveSheet, 'L2'); rhythm

	_Excel_BookClose($book)
	_Excel_Close($excel)

	$excel = _Excel_Open(False, False, False, False, True)
	if @error Then Return SetError(1, 0, 'Nelze spustit aplikaci Excel.')
	$book = _Excel_BookOpen($excel, $out, False, False)
	if @error Then return SetError(1, 0, 'Nelze načíst soubor: ' & $out)

	;write header
	_Excel_RangeWrite($book, $excel.ActiveSheet, $name, 'B2')
	_Excel_RangeWrite($book, $excel.ActiveSheet, $rc, 'G2')
	_Excel_RangeWrite($book, $excel.ActiveSheet, $poj, 'J2')
	_Excel_RangeWrite($book, $excel.ActiveSheet, $tf, 'B4')
	_Excel_RangeWrite($book, $excel.ActiveSheet, $height, 'E4')
	_Excel_RangeWrite($book, $excel.ActiveSheet, $weight, 'H4')
	_Excel_RangeWrite($book, $excel.ActiveSheet, $rhythm, 'L2')

	_Excel_BookSave($book)
	_Excel_BookClose($book)
	_Excel_Close($excel)
EndFunc

func write_medicus($data,$out)
	$f = FileOpen($out, 0)
	FileWriteLine($f, "DEEEEKUURZZZ!!!!")
	FileClose($f)
endfunc

