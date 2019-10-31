;
; SSH Rsync backup WIN -> NAS CLI Setup
;

#AutoIt3Wrapper_Icon=NASBackup.ico
#NoTrayIcon

;INCLUDE

#include <File.au3>
#include <Array.au3>

;VAR

$ini = @ScriptDir & '\' & 'NASBackup.ini
$rsync = @ScriptDir & '\cygwin\' & 'rsync.exe'
$ssh = @ScriptDir & '\cygwin\' & 'ssh.exe'

global $configuration[2][0], $dirlist

;CONTROL

; one instance
if UBound(ProcessList(@ScriptName)) > 2 then exit
; logging
$log = FileOpen(@ScriptDir & '\' & 'NASBackupAuto.log', 1)
if @error then exit
; 64-bit only
;if @OSArch <> 'X64' then
;	logger("Tato architektura neni podporovana.")
;	exit
;endif
; ini file
if not FileExists($ini) then
	logger("Missing INI configuration.")
	exit
endif
if $CmdLine[1] <> "--auto" then
	logger("Missing control parametr.")
	exit
endif

; INIT

logger("Program begin: " & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)

; load configuration
_FileReadToArray($ini, $configuration, 0, ' '); 0-based space split
logger("Configuration INI loaded.")
; dirlist count
for $i = 0 to ubound($configuration) - 1
	if StringRegExp($configuration[$i][0], '^[dir.*') then $dirlist += 1
next
_ArrayDisplay($configuration); DEBUG

logger("Backup begin.")
if $configuration[get_index('user')][1] == '' then
	logger("E: Neplatny uzivatel.")
elseif not StringRegExp($configuration[get_index('remote')][1], '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}) then
	logger("E: Neplatna IP adresa.")
elseif not StringRegExp($configuration[get_index('port')][1], '\d{1,5}') then
	logger("E: Neplatne cislo portu.")
elseif $configuration[get_index('target')][1] == '' then
	logger("E: Neplatny cilovy adresar.")
elseif not FileExists($configuration[get_index('key')][1]) then
	logger("E: Klic neexistuje.")
else
	for $i = 0 to $dirlist - 1
		; rsync
		RunWait($rsync & ' -az -e "' & $ssh & ' -o "StrictHostKeyChecking no" -p ' &_
		$configuration[get_index('port')][1] & ' -i ' &_
		$configuration[get_index('key')][1] & '" '&_
		$configuration[get_index('dir' & ($i + 1))][1] & ' ' &_
		$configuration[get_index('user')][1] & '@' &_
		$configuration[get_index('remote')][1] & ':/' &_
		$configuration[get_index('target')][1])
		logger('Directory ' & $i + 1 & ' backed up!')
	next
endif
logger("Backup end.")

; exit
logger("Program end: " & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)
logger("-----------------------------------")
FileClose($log)
exit

; FUNC

func logger($text)
	FileWriteLine($log, $text)
endfunc

func get_index($variable)
	return _ArraySearch($configuration, '[' & $variable & ']', 0, 0, 0, 1)
endfunc

