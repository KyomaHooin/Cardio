;
; S70 PDF to XLSX convertor
;

#AutoIt3Wrapper_Icon=S70.ico
#NoTrayIcon

; INLUDE

#include <File.au3>
#include <Excel.au3>
#include <ExcelConstants.au3>

;VAR

$version = '1.1'
$ini = @ScriptDir & '\' & 'S70.ini'
$logfile = @ScriptDir & '\' & 'S70.log'

global $configuration[0][2]
global $2D[0][2]
global $2DCalc[0][2]
global $Doppler[0][2]

;CONTROL

; one instance
if UBound(ProcessList(@ScriptName)) > 2 then
	MsgBox(48, 'S70 v ' & $version, 'Program byl již spuštěn. [R]')
	exit
endif
; logging
$log = FileOpen($logfile, 1)
if @error then
	MsgBox(48, 'S70 v ' & $version, 'System je připojen pouze pro čtení. [RO]')
	exit
endif

; INIT

logger('Program begin: ' & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)
; read configuration
if not FileExists($ini) then
	logger('Nelze nalézt konfigurační INI soubor.')
	exit
endif
_FileReadToArray($ini, $configuration, 0, '='); 0-based
if @error then
	logger('Načtení konfiguračního INI souboru selhalo.')
	exit
else
	logger('Konfigurační INI soubor byl načten.')
endif
; split configuration
$D2 = A1toA2(StringSplit($configuration[1][1], '|', 2))
$D2Calc = A1toA2(StringSplit($configuration[2][1], '|', 2))
$Doppler = A1toA2(StringSplit($configuration[3][1], '|', 2))

; MAIN

$pdfpath = StringRegExpReplace($configuration[0][1],'\\+$',''); remove trailing slash
if not ($pdfpath and FileExists($pdfpath)) then
	logger('Neplatný adresář.')
else
	$pdflist = _FileListToArray($pdfpath, "*.pdf")
	if ubound($pdflist) < 2 then
		logger('Nebyl nalezen žádný PDF soubor.')
	else
		for $i=1 to ubound($pdflist) - 1
			if not FileExists(StringRegExpReplace($pdfpath & '\' & $pdflist[$i],'pdf','xlsx')) then; done before
				;logger("Zpracovávám soubor: " & $pdflist[$i])
				; DATA DUMP
				RunWait(@ComSpec & ' /c ' & 'pdftotext.exe -raw -q ' & $pdfpath & '\' & $pdflist[$i] & ' data.txt', @ScriptDir, @SW_HIDE, $STDERR_MERGED)
				$data = FileReadToArray(@ScriptDir & '\data.txt')
				if UBound($data) == 0 Then
					logger("Chyba při zpracování textu: " & $pdflist[$i])
				else
					; IMAGES DUMP
					RunWait(@ComSpec & ' /c ' & 'pdfimages.exe -j -q ' & $pdfpath & '\' & $pdflist[$i] & ' ' & @ScriptDir & '\img', @ScriptDir, @SW_HIDE)
					if not (FileExists(@ScriptDir & '\img-0000.jpg') and FileExists(@ScriptDir & '\img-0001.jpg')) Then
						logger("Chyba při zpracování obrázků: " & $pdflist[$i])
					else
						; TRANSLATE DATA
						;$data = parse_data($dump)
						;if UBound($data) == 0 Then
						;	logger("Chyba při převodu textu: " & $pdfpath & '\' & $pdflist[$i])
						;else
						; GET XSL
						$xlsx = get_xlsx($data, @ScriptDir & '\img-0000.jpg', @ScriptDir & '\img-0001.jpg', $pdflist[$i])
						if @error Then logger($xlsx)
						;EndIf
					EndIf
				EndIf
				;blind cleanup
				FileDelete(@ScriptDir & '\data.txt')
				FileDelete(@ScriptDir & '\img*.jpg')
			EndIf
		Next
	endIf
EndIf

; exit
logger('Program exit: ' & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)
logger('------------------------------------')
FileClose($log)
exit

; FUNC

func logger($text)
	FileWriteLine($log, $text)
endfunc

func A1toA2($A1)
	local $A2[0][2]
	if Mod(UBound($A1), 2) <> 0 then return
	for $i=0 to UBound($A1) / 2 - 1
		_ArrayAdd($A2, $A1[2 * $i] & '|' & $A1[2 * $i + 1])
	next
	return $A2
EndFunc

;func parse_data($dump)
;		_ArrayDisplay($dump)
;		local $data[0][2]
;		$d2_index = _ArraySearch($dump, '2-D parametry')
;		$d2calc_index = _ArraySearch($dump, '2-D kalkulace')
;		$doppler_index = _ArraySearch($dump, 'Doppler+Mmode')
;		$end_index = _ArraySearch($dump, 'Souhrn:')
;		MsgBox(0, "index list", $D2_index & ' ' & $D2Calc_index & ' ' & $Doppler_index & ' ' & $end_index)
;		Return $data
;EndFunc

func get_xlsx($dump, $img1, $img2, $pdffile)
	$excel = _Excel_Open(False, False, False, False, True)
	if @error Then Return SetError(1, 0, "Nelze spustit aplikaci Excel.")
	$book = _Excel_BookNew($excel, 1)
	if @error Then return SetError(1, 0, "Nelze vytvořit Excel sešit.")
	$excel.ActiveSheet.Name = 'S70'
	; HEAER
	$book.ActiveSheet.Range("A2").ColumnWidth = 12;
	$book.ActiveSheet.Range("A4").RowHeight = 20;
	$book.ActiveSheet.Range("B2").ColumnWidth = 25;
	$book.ActiveSheet.Range("F2").ColumnWidth = 1;

	_Excel_RangeWrite($book, $excel.ActiveSheet, $dump[0], 'A2'); examination
	$book.ActiveSheet.Range("A2").Font.Bold = True;
	$book.ActiveSheet.Range("A2").Font.Size = 18;
	_Excel_RangeWrite($book, $excel.ActiveSheet, $dump[2], 'G2'); device
;	_Excel_RangeWrite($book, $excel.ActiveSheet, $dump[1], 'A3'); address
	_Excel_RangeWrite($book, $excel.ActiveSheet, 'Kardiologie Praha 17-Řepy s.r.o.               ', 'A3'); address
	$book.ActiveSheet.Range("A3").Font.Bold = True;
	$book.ActiveSheet.Range("A3").Font.Underline = True;
	$book.ActiveSheet.Range("A3").Font.Size = 18;
	_Excel_RangeWrite($book, $excel.ActiveSheet, 'Jméno', 'A5'); name
	_Excel_RangeWrite($book, $excel.ActiveSheet, StringReplace($dump[4],'Name ',''), 'B5')
	$book.ActiveSheet.Range("B5").Font.Bold = True;
	_Excel_RangeWrite($book, $excel.ActiveSheet, 'ID Pacienta', 'A6'); ID
	_Excel_RangeWrite($book, $excel.ActiveSheet, StringReplace($dump[5],'Patient Id ',''), 'B6')
	$book.ActiveSheet.Range("B6").Font.Bold = True;
	$book.ActiveSheet.Range("B6").HorizontalAlignment = $xlLeft;
	_Excel_RangeWrite($book, $excel.ActiveSheet, 'BSA', 'A7'); BSA
	_Excel_RangeWrite($book, $excel.ActiveSheet, StringReplace($dump[6],'BSA ',''), 'B7')
	$book.ActiveSheet.Range("B7").Font.Bold = True;
	_Excel_RangeWrite($book, $excel.ActiveSheet, 'Výška', 'A8'); Height
	_Excel_RangeWrite($book, $excel.ActiveSheet, StringReplace($dump[7],'Height ',''), 'B8')
	$book.ActiveSheet.Range("B8").Font.Bold = True;
	_Excel_RangeWrite($book, $excel.ActiveSheet, 'Váha', 'A9'); Weight
	_Excel_RangeWrite($book, $excel.ActiveSheet, StringReplace($dump[8],'Weight ',''), 'B9')
	$book.ActiveSheet.Range("B9").Font.Bold = True;
	_Excel_RangeWrite($book, $excel.ActiveSheet, 'Datum', 'A10'); Date
	_Excel_RangeWrite($book, $excel.ActiveSheet, StringReplace($dump[9],'Date ',''), 'B10')
	$book.ActiveSheet.Range("B10").Font.Bold = True;
	$book.ActiveSheet.Range("B10").HorizontalAlignment = $xlLeft;
	; IMAGE
	_Excel_PictureAdd($book, $excel.ActiveSheet, $img1, "C5:E11", Default, Default, Default, False)
	if @error then logger("Picture implant error: " & @error)
	_Excel_PictureAdd($book, $excel.ActiveSheet, $img2, 'G5:I11', Default, Default, Default, False)
	if @error then logger("Picture implant error: " & @error)
	; DATA
	; FOOTER
	;WRITE FILE
	_Excel_BookSaveAs($book, StringRegExpReplace($pdfpath & '\' & $pdflist[$i],'pdf','xlsx'))
	if @error Then return SetError(1, 0, "Nelze zapsat Excel sešit.")
	; EXIT
	_Excel_BookClose($book)
	_Excel_Close($excel)
	return
EndFunc
