;
; S70 PDF to XLSX convertor
;

#AutoIt3Wrapper_Icon=S70.ico
#NoTrayIcon

; INLUDE

#include <File.au3>
#include <Excel.au3>

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
				logger("Zpracovávám soubor:" & $pdfpath & '\' & $pdflist[$i])
				; parse text
				$pid = Run(@ComSpec & ' /c ' & 'pdftotext.exe -raw -q ' & $pdfpath & '\' & $pdflist[$i] & ' -', @ScriptDir, @SW_HIDE, $STDERR_MERGED)
				ProcessWaitClose($pid, 5)
				$out = StdoutRead($pid)
				if $out == '' Then
					logger("Chyba při zpracování textu: " & $pdfpath & '\' & $pdflist[$i])
				else
					$text = StringSplit(StringTrimRight(StringStripCR($out), StringLen(@CRLF)), @CRLF)
					;parse images
					$pid = Run(@ComSpec & ' /c ' & 'pdfimages.exe -j -q ' & $pdfpath & '\' & $pdflist[$i] & ' ' & @ScriptDir & '\img', @ScriptDir, @SW_HIDE)
					ProcessWaitClose($pid, 10)
					if not (FileExists(@ScriptDir & '\img-001.jpg') and FileExists(@ScriptDir & '\img-002.jpg')) Then
						logger("Chyba při zpracování obrázků: " & $pdfpath & '\' & $pdflist[$i])
					else
						; - construct XSL
						$xlsx = get_xlsx($text, @ScriptDir & '\img-001.jpg', @ScriptDir & '\img-002.jpg')
						if @error Then
							logger($xlsx)
						else
							logger("Hotovo: " & $pdfpath & '\' & $pdflist[$i])
						EndIf
					EndIf
				EndIf
			EndIf
			;cleanup
			FileDelete(@ScriptDir & '\img*.jpg')
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

func get_xlsx($text, $img1, $img2)
	$excel = _Excel_Open(False, False, False, False, True)
	if @error Then Return SetError(1, 0, "Nelze spustit aplikaci Excel.")
	$book = _Excel_BookNew($excel, 1)
	if @error Then return SetError(1, 0, "Nelze vytvořit Excel sešit.")

	_Excel_BookClose($book)
	_Excel_Close($excel)
EndFunc
