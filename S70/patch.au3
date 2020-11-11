;
; S70 - Patch archive files with updated machine variables
;
#NoTrayIcon
#AutoIt3Wrapper_Change2CUI=y

#include <File.au3>

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
	ConsoleWrite('Usage patch.exe [path]')
	Exit
endif

;check directory
if not FileExists($cmdline[1]) Then
	ConsoleWrite('Invalid directory.')
	Exit
endif

;load files
$data = _FileListToArrayRec($cmdline[1], '*.dat', 1, 1, 1, 2); files only, recursion, sorted, full path

;patch strings
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
	; verbose
	ConsoleWrite('Zpracovavam.. ' & StringRegExpReplace($data[$i], '^.*\\(.*)', '$1') & @CRLF)
next

; exit
ConsoleWrite(@CRLF & 'Hotovo.')
exit
