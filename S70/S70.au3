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
$medicus_out = @ScriptDir & '\' & 'S70out.dat'
$medicus_in = @ScriptDir & '\' & 'S70in.dat'
$template = @ScriptDir & '\' & 'S70_template.xlsx'

$archive_dir = @ScriptDir & '\' & 'archive'

global $header = ['name', 'id', 'bsa', 'height', 'weight', 'date']
global $configuration[0][2]
global $patient_id[0]

global $2D[0][2]
global $2DCalc[0][2]
global $Doppler[0][2]

;CONTROL

; one instance
if UBound(ProcessList(@ScriptName)) > 2 then
	MsgBox(48, 'S70 v ' & $version, 'Program byl již spuštěn.')
	exit
endif

; logging
$log = FileOpen($logfile, 1)
if @error then
	MsgBox(48, 'S70 v ' & $version, 'System je připojen pouze pro čtení.')
	exit
endif

; create data structure
DirCreate($export)
DirCreate($archive)

; INIT

logger('Program begin: ' & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)

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
	logger('Nelze nalézt Medicus soubor.')
	exit
endif

; load config
_FileReadToArray($ini, $configuration, 0, '=')
if @error then
	logger('Načtení konfiguračního INI souboru selhalo.')
	exit
endif

; test export setup
$txtpath = StringRegExpReplace($configuration[0][1],'\\+$',''); remove trailing slash
if not $txtpath or not FileExists($txtpath) then
	logger('Neplatný adresář pro export.')
	exit
endif

; test ID load
_FileReadToArray($medicus_in, $patient_id, 0)
if @error then
	logger('Načtení ID pacienta selhalo.')
	exit
endif

; MAIN

;load configuration
$d2 = A1toA2(StringSplit($configuration[1][1], '|', 2))
$d2calc = A1toA2(StringSplit($configuration[2][1], '|', 2))
$doppler = A1toA2(StringSplit($configuration[3][1], '|', 2))

; get filename
$filename = $medicus_in[1] & @YEAR & @MON & @MDAY & '_' & @HOUR & @MIN & @SEC

; check export
$txtlist = _FileListToArray($txtpath, '*.txt')

; check archive
$archive_file = file_from_archive($patient_id[0])

if ubound($txtlist) < 2 then
	if msgbox(4,"Historie", "Načíst poslední záznam?") = 6 then; OK
		if $archive_file then; archived?
			FileCopy($archive & '\' & $archive_file, @ScriptDir & '\' & $filename)
			if @error then
				logger('Načtení z archivu selhalo.')
				FileCopy($template, $ScriptDir & '\' & $filename)
			endif
		else
			FileCopy($template, $ScriptDir & '\' & $filename)
			if $archive_file then temeplate_update_header($archive_file, $filename)
		endif
	else
		FileCopy($template, $ScriptDir & '\' & $filename)
		if $archive_file then temeplate_update_header($archive_file, $filename)
	endif
else
	;load export
	$raw = FileReadToArray($txtpath & '\' & $txtlist[1], 0)
	if @error then
		logger('Načtení exportu: ' & txtlist  & 'selhalo.')
		FileCopy($template, $ScriptDir & '\' & $filename)
		if $archive_file then temeplate_update_header($archive_file, $filename)
	else
		$filename = StringRegExpReplace($txtlist[1], '.txt', '.xlsx'); update filename 
		$data = parse_export($raw); parse export
		if $archive_file then temeplate_update_header($archive_file, $filename)
		templete_update_data($data, $filename)
	endif
	;export leanup
	FileDelete($txtpath & '\*.txt')
endIf

; run temeplate
$excel = _Excel_Open()
$book = _ExcelBookOpen($excel, @ScriptDir & '\' & $filename)
while check_booklist($book)
	sleep(5000)
wend

;parse new data
$new = templete_read_data($filename)

;write_medicus
write_medicus($new, $medicus_out)

;archive
if FileExists(@ScriptDir & '\' & $filename) then 
	FileMove(@ScriptDir & '\' & $filename, $archive & '\' & $filename)
	FileDelete($archive_file)
endif

; exit
logger('Program exit: ' & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)
logger('------------------------------------')
FileClose($log)
exit

; FUNC

func logger($text)
	FileWriteLine($log, $text)
endfunc

func file_from_archive($id)
	for $f in  _FileListToArray($archive, '*.xlsx')
		if StringRegExp($f, "$id_.*") then return $f
	next
endfunc

func A1toA2($A1)
	local $A2[0][2]
	if Mod(UBound($A1), 2) <> 0 then return
	for $i=0 to UBound($A1) / 2 - 1
		_ArrayAdd($A2, $A1[2 * $i] & '|' & $A1[2 * $i + 1])
	next
	return $A2
EndFunc

func check_booklist($instance)
	return _ArraySearch(_ExcelBookList(), $instance)
endfunc

func parse_export($raw)
	local $data[0][2]
	$index = 0
	;header
	for $i = 0 to ubound($header)
		$data[$index][$heaer[$i]] = $raw[_ArraySearch($raw, $heaer[$i])]
		$index=+1
	next
	;data
	for $i = 0 to ubound($d2)
		$data[$index][$d2[$i]] = $raw[_ArraySearch($raw, $d2[$i])]
		$index=+1
	next
	for $i = 0 to ubound($d2calc)
		$data[$index][$d2calc[$i]] = $raw[_ArraySearch($raw, $d2calc[$i])]
		$index=+1
	next
	for $i = 0 to ubound($doppler)
		$data[$index][$doppler[$i]] = $raw[_ArraySearch($raw, $doppler[$i])]
		$index=+1
	next
	return $data
endfunc

func template_update_data($data, $file)
	$excel = _Excel_Open(False, False, False, False, True)
	if @error Then Return SetError(1, 0, 'Nelze spustit aplikaci Excel.')
	$book = _Excel_BookOpen($excel, $file, False, False)
	if @error Then return SetError(1, 0, 'Nelze načíst soubor: ' & $out)

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

