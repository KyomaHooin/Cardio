;
; S70 - Patch archive files with updated machine variables
;
#NoTrayIcon
#AutoIt3Wrapper_Change2CUI=y

#include <File.au3>
#include <String.au3>

; conversion map
global $map[10][2] = [ _
	['L Area-A4C','AAA'], _
	['L Area-A2C','BBB'], _
	['P Area-A4C','CCC'], _
	['A Anulus','DDD'], _
	['Asc-Ao index','EEE'], _
	['Anulus-AP','FFF'], _
	['Anulus-IC','GGG'], _
	['M Spid','HHH'], _
	['AP Spid ratio','III'], _
	['T Anulus','JJJ'] _
]

;check cmdline
if UBound($cmdline) <> 2 then
	ConsoleWrite('Pouziti: patch.exe [cesta]')
	Exit
endif

;check directory
if not FileExists($cmdline[1]) Then
	ConsoleWrite('Neplatna cesta.')
	Exit
endif

;load files
$data = _FileListToArrayRec($cmdline[1], '*.dat', 1, 1, 1, 2); files only, recursion, sorted, full path

;patch
for $i=1 to UBound($data) - 1
	; in memory replace
	$f = FileOpen($data[$i], 256); UTF8 NOBOM read
	$buffer = FileRead($f)
	FileClose($f)
	for $j=0 to UBound($map) - 1
		$buffer = StringReplace($buffer, $map[$j][0] & '":{', $map[$j][1] & '":{')
	next
	; write buffer
	$f = FileOpen($data[$i], 2 + 256); UTF8 NOBOM overwrite
	FileWrite($f, $buffer)
	FileClose($f)
	; progressbar
	$progress_head = _StringRepeat(Chr(219), Ceiling(79*Ceiling($i/(UBound($data)-1)*100)/100))
	$progress_tail = _StringRepeat(Chr(177), 79 - Ceiling(79*Ceiling($i/(UBound($data)-1)*100)/100))
	ConsoleWrite(@CR & $progress_head & $progress_tail)
next

; exit
ConsoleWrite(@CRLF & 'Hotovo.')
exit
