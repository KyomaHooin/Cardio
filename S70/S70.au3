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
$medicus_in = @ScriptDir & '\' & 'S70_meducus_in.dat'

$archive_path = @ScriptDir & '\' & 'archive'

global $configuration[0][2]
global $medicus_id[0]

global $map[], $d2[], $d2calc[], $doppler[]

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
	exit
endif
if not FileExists($template) then
	logger('Nelze nalézt XLSX šablonu.')
	exit
endif
if not FileExits($medicus_in) the
	logger('Nelze nalézt vstupní Medicus soubor.')
	exit
endif

; load config
_FileReadToArray($ini, $configuration, 0, '=')
if @error then
	logger('Načtení konfiguračního INI souboru selhalo.')
	exit
endif

; test export setup
$txt_path = StringRegExpReplace($configuration[0][1],'\\+$', ''); remove trailing slash
if not $txt_path or not FileExists($txt_path) then
	logger('Neplatný adresář pro export.')
	exit
endif

; test medicus ID
_FileReadToArray($medicus_in, $medicus_id, 0)
if @error then
	logger('Načtení ID pacienta selhalo.')
	exit
endif

; MAIN

; load config
$d2 = get_map(StringSplit($configuration[1][1], '|', 2))
$d2calc = get_map(StringSplit($configuration[2][1], '|', 2))
$doppler = get_map(StringSplit($configuration[3][1], '|', 2))

; get filename
$filename = @ScriptDir & '\' & $medicus_id[0] & '_' & @YEAR & @MON & @MDAY & '_' & @HOUR & @MIN & @SEC & '.xlsx'

; check export
$txt_file = file_from_export($medicus_id[0], $txt_path)

; check archive
$archive_file = file_from_archive($medicus_id[0], $archive_path)

if not $txt_file then
	; load archive ?
	if msgbox(4, 'S70 Echo - Historie', 'Načíst poslední záznam?') = 6 then; OK
		if $archive_file then; archived ?
			FileCopy($archive & '\' & $archive_file, $filename)
			if @error then
				logger('Načtení z archivu selhalo.')
				FileCopy($template, $filename)
			endif
		else
			FileCopy($template, $filename)
		endif
	else
		FileCopy($template, $filename)
	endif
else
	; load export
	$raw = FileReadToArray($txtpath & '\' & $txt_file, 0)
	if @error then
		logger('Načtení exportu ' & txt_file  & ' selhalo.')
		FileCopy($template, $filename)
	else
		; parse export
		$data = parse_export($raw)
		; write export
		if $archive_file then
			templete_update_data($data, $filename, 0)
		else
			templete_update_data($data, $filename, 1)
		endif
	endif
	;export cleanup
	FileDelete($txt_path & '\*.txt')
endIf

; update temeplate header
if $archive_file then template_update_header($archive_file, $filename)

; run temeplate
$excel = _Excel_Open()
$book = _Excel_BookOpen($filename)
while _ArraySearch(_ExcelBookList(), $book)
	sleep(5000)
wend
;parse new data
$new = templete_read_data($filename)

;write_medicus
write_medicus($new, $medicus_out)

;update archive
if FileExists($filename) then
	if $archive_file then FileDelete($archive_file)
	FileMove($filename, $archive_path)
endif

; exit
logger('Program exit: ' & @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC)
logger('------------------------------------')
FileClose($log)
exit

; FUNC

func logger($text)
	FileWriteLine($log, $text)
endfunc

func file_from_archive($id, $path)
	$list = _FileListToArray($path, '*.xlsx')
	for $i = 0 to ubound($list)
		if StringRegExp($list[$i], "$id_.*") then return $list[$i]
	next
endfunc

func file_from_export($id, $path)
	$list = _FileListToArray($path, '*.txt')
	for $i = 0 to ubound($list)
		if StringRegExp($list[$i], "$id_.*") then return $list[$i]
	next
endfunc

func get_map($list)
	local $map[]
	; valid touples
	if Mod(UBound($A1), 2) <> 0 then return
	for $i=0 to UBound($A1) / 2 - 1
		$map[$list[2 * $i]] =  $list[2 * $i + 1]
	next
	return $map
EndFunc

func parse_export($raw)
	local $map[]
	; header
	$map['name'] = StringRegExpReplace($raw[8], 'Name ', '')
	$map['id'] = StringRegExpReplace($raw[9], 'Patient Id ', '')
	$map['bsa'] = StringRegExpReplace($raw[10], 'BSA ', '')
	$map['height'] = StringRegExpReplace($raw[11], 'Height ', '')
	$map['weight'] = StringRegExpReplace($raw[12], 'Weight ', '')
	$map['date'] = StringRegExpReplace($raw[13], 'Date ', '')
	; index
	for $i = 0 to ubound($raw)
		if $raw[$i] = '2-D parametry' then $d2_index = $i + 2 
		if $raw[$i] = '2-D kalkulace' then $d2calc_index = $i + 2 
		if $raw[$i] = 'Doppler+Mmode' then $doppler_index = $i + 2 
		if $raw[$i] = 'Souhrn:' then $end_index = $i - 2
	next
	; data
	for $i = $d2_index to $d2calc_index - 2
		$map[StringRegExpReplace($raw[$i], ' +\d+.*', '')] = StringRegExpReplace($raw[$i], '.*(\d+.?\d+).*', '\\1')
	next 
	for $i = $d2calc_index to $doppler_index - 2
		$map[StringRegExpReplace($raw[$i], ' +\d+.*', '')] = StringRegExpReplace($raw[$i], '.*(\d+.?\d+).*', '\\1')
	next 
	for $i = $doppler to $end_index
		$map[StringRegExpReplace($raw[$i], ' +\d+.*', '')] = StringRegExpReplace($raw[$i], '.*(\d+.?\d+).*', '\\1')
	next 
	return $map
endfunc

func template_update_data($data, $file, $header)
	$excel = _Excel_Open(False, False, False, False, True)
	if @error Then Return SetError(1, 0, 'Nelze spustit aplikaci Excel.')
	$book = _Excel_BookOpen($excel, $file, False, False)
	if @error Then return SetError(1, 0, 'Nelze načíst soubor: ' & $out)

	if $header then

	

	;_Excel_RangeWrite($book, $excel.ActiveSheet, $name, 'B2')
	
	_Excel_BookSave($book)
	_Excel_BookClose($book)
	_Excel_Close($excel)
endfunc

func template_read_data($file)
	$excel = _Excel_Open(False, False, False, False, True)
	if @error Then Return SetError(1, 0, 'Nelze spustit aplikaci Excel.')
	$book = _Excel_BookOpen($excel, $file, True, False)
	if @error Then return SetError(1, 0, 'Nelze načíst soubor: ' & $out)

	;_Excel_RangeWrite($book, $excel.ActiveSheet, $name, 'B2')
	
	_Excel_BookClose($book)
	_Excel_Close($excel)
endfunc

func temeplate_update_header($in, $out)
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

func template_update_data($data, $file)
	$excel = _Excel_Open(False, False, False, False, True)
	if @error Then Return SetError(1, 0, 'Nelze spustit aplikaci Excel.')
	$book = _Excel_BookOpen($excel, $file, True, False)
	if @error Then return SetError(1, 0, 'Nelze načíst soubor: ' & $out)

	;_Excel_RangeWrite($book, $excel.ActiveSheet, $name, 'B2')
	
	_Excel_BookSave($book)
	_Excel_BookClose($book)
	_Excel_Close($excel)
endfunc

func rite_medicus($data,$out)
endfunc

