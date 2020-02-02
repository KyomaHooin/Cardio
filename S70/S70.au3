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

;get filename
$filename = $medicus_in[1] & @YEAR & @MON & @MDAY & '_' & @HOUR & @MIN & @SEC
;check export
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
		endif
	else
		FileCopy($template, $ScriptDir & '\' & $filename)
		; write header from archive
		if $archive_file then
			update_header(@ScriptDir & '\' & archive_file, @ScriptDir & '\' & $filename)
		endif
	endif
else
	;load export
	$data = FileReadToArray($txtpath & '\' & $txtlist[1])
	if @error then
		logger('Načtení exportu: ' & txtlist  & 'selhalo.')
		FileCopy($template, $ScriptDir & '\' & $filename)
	else
		$filename = StringRegExpReplace($txtlist[1], '.txt', '.xlsx'); updat filename by export
		;parse_export
		; write temeplate header
		if $archive_file then update_header(@ScriptDir & '\' & archive_file, @ScriptDir & '\' & $filename)
		; write texport
	endif
	;cleanup
	FileDelete($txtpath & '\*.txt')
endIf

; run excel
$excel = _Excel_Open(False, False, False, False, True)
$book = _ExcelBookOpen($excel, @ScriptDir & '\' & $filename)
;parse_xlsx_back
;write_medicus
;archive
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

func write_temeplate($data, $file)
	$excel = _Excel_Open(False, False, False, False, True)
	if @error Then Return SetError(1, 0, "Nelze spustit aplikaci Excel.")
	$book = _Excel_BookNew($excel, 1)
	if @error Then return SetError(1, 0, "Nelze vytvořit Excel sešit.")
	$excel.ActiveSheet.Name = 'S70'
	;HEADER

	_Excel_RangeWrite($book, $excel.ActiveSheet, $dump[0], 'A2'); examination
	$book.ActiveSheet.Range("A2").Font.Bold = True;
	$book.ActiveSheet.Range("A2").Font.Size = 18;
	_Excel_RangeWrite($book, $excel.ActiveSheet, $dump[2], 'G2'); device
;	_Excel_RangeWrite($book, $excel.ActiveSheet, $dump[1], 'A3'); address
	_Excel_RangeWrite($book, $excel.ActiveSheet, 'Kardiologie Praha 17-Řepy s.r.o.               ', 'A3'); address
	_Excel_RangeWrite($book, $excel.ActiveSheet, 'Jméno', 'A5'); name
	_Excel_RangeWrite($book, $excel.ActiveSheet, StringReplace($dump[4],'Name ',''), 'B5')
	_Excel_RangeWrite($book, $excel.ActiveSheet, 'ID Pacienta', 'A6'); ID
	_Excel_RangeWrite($book, $excel.ActiveSheet, StringReplace($dump[5],'Patient Id ',''), 'B6')
	$book.ActiveSheet.Range("B6").HorizontalAlignment = -4131; xlLeft
	_Excel_RangeWrite($book, $excel.ActiveSheet, 'BSA', 'A7'); BSA
	_Excel_RangeWrite($book, $excel.ActiveSheet, StringReplace($dump[6],'BSA ',''), 'B7')
	_Excel_RangeWrite($book, $excel.ActiveSheet, 'Výška', 'A8'); Height
	_Excel_RangeWrite($book, $excel.ActiveSheet, StringReplace($dump[7],'Height ',''), 'B8')
	_Excel_RangeWrite($book, $excel.ActiveSheet, 'Váha', 'A9'); Weight
	_Excel_RangeWrite($book, $excel.ActiveSheet, StringReplace($dump[8],'Weight ',''), 'B9')
	_Excel_RangeWrite($book, $excel.ActiveSheet, 'Datum', 'A10'); Date
	_Excel_RangeWrite($book, $excel.ActiveSheet, StringReplace($dump[9],'Date ',''), 'B10')
	; DATA
	; FOOTER
	;WRITE FILE
	_Excel_BookSaveAs($book, StringRegExpReplace($export & '\' & $filename,'txt','xlsx'))
	if @error Then return SetError(1, 0, "Nelze zapsat Excel sešit.")
	; EXIT
	_Excel_BookClose($book)
	_Excel_Close($excel)
	return
EndFunc

