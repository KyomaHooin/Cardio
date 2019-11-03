;
; SSH Rsync backup WIN -> NAS GUI Setup
;

#AutoIt3Wrapper_Icon=NASBackup.ico
#NoTrayIcon

;INCLUDE

#include <File.au3>
#include <Array.au3>

;VAR

$version = '1.3'
$company = 'Your Company'
$ini = @ScriptDir & '\NASBackup.ini'

global $configuration[0][2]

;CONTROL

; one instance
if UBound(ProcessList(@ScriptName)) > 2 then exit
; logging
$log = FileOpen(@ScriptDir & '\' & 'NASBackupAuto.log', 1)
if @error then exit
; 64-bit only
;if @OSArch <> 'X64' then
;	logger('Tento systém není podporován. [x64]')
;	exit
;endif

; INIT

logger('Program begin: ' & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)
; read configuration
if not FileExists($ini) then
	$f = FileOpen($ini, 1)
	FileWriteLine($f, 'dir1=')
	FileWriteLine($f, 'dir2=')
	FileWriteLine($f, 'dir3=')
	FileWriteLine($f, 'user=')
	FileWriteLine($f, 'remote=')
	FileWriteLine($f, 'port=')
	FileWriteLine($f, 'target=')
	FileWriteLine($f, 'key=')
	FileWriteLine($f, 'local=')
	FileWriteLine($f, 'default=0')
	FileClose($f)
endif
_FileReadToArray($ini, $configuration, 0, '='); 0-based
if @error or UBound($configuration) <> 10 then
	logger('Načtení konfiguračního INI souboru selhalo.')
	exit
else
	logger("Konfigurační INI soubor byl načten.")
endif

; MAIN

logger('Zahájeno zálohovaní..')
; check input
if $configuration[get_index('default')][1] = 0 and $configuration[get_index('user')][1] == '' then
	logger('E: Neplatný uživatel.')
elseif $configuration[get_index('default')][1] = 0 and not StringRegExp($configuration[get_index('remote')][1], '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') then
	logger('E: Neplatná IP adresa.')
	exit
elseif $configuration[get_index('default')][1] = 0 and Int($configuration[get_index('port')][1]) > 65535 then
	logger('E: Neplatné číslo portu.')
	exit
elseif $configuration[get_index('default')][1] = 0 and not StringRegExp($configuration[get_index('port')][1], '^\d{1,5}$') then
	logger('E: Neplatné číslo portu.')
	exit
elseif $configuration[get_index('default')][1] = 0 and $configuration[get_index('target')][1] == '' then
	logger('E: Neplatný cílový adresář.')
	exit
elseif $configuration[get_index('default')][1] = 0 and not FileExists($configuration[get_index('key')][1]) then
	logger('E: Klíč neexistuje.')
	exit
elseif $configuration[get_index('default')][1] = 1 and not FileExists($configuration[get_index('local')][1]) then
	logger('E: Cílový adresář neexistuje.')
	exit
else
	for $i = 0 to 2
		if $configuration[get_index('dir' & $i + 1)][1] <> '' then
			if FileExists($configuration[get_index('dir' & $i + 1)][1]) then
				if $configuration[get_index('default')][1] = 0 then
					$cygwin_src_path = get_cygpwin_path($configuration[get_index('dir' & $i + 1)][1])
					;remote rsync
					$rsync = RunWait(@ComSpec & ' /c ' & 'rsync.exe -avz -e ' _
						& "'" & 'ssh.exe -o "StrictHostKeyChecking no" -p ' _
						& $configuration[get_index('port')][1] & ' -i ' _
						& '"' & $configuration[get_index('key')][1] & '"' & "' " _
						& "'" & $cygwin_src_path & "'" & ' ' _
						& $configuration[get_index('user')][1] & '@' _
						& $configuration[get_index('remote')][1] & ':' _
						& $configuration[get_index('target')][1] _
						& ' > auto_rsync.log 2> auto_error.log' _
						, @ScriptDir & '\cygwin', @SW_HIDE)
				ElseIf $configuration[get_index('default')][1] = 1 then
					$cygwin_src_path = get_cygpwin_path($configuration[get_index('dir' & $i + 1)][1])
					$cygwin_dst_path = get_cygpwin_path($configuration[get_index('local')][1])
					;local rsync
					$rsync = RunWait(@ComSpec & ' /c ' & 'rsync.exe -avz ' _
						& "'" &  $cygwin_src_path & "'" & ' ' _
						& "'" & $cygwin_dst_path & "'" _
						& ' > auto_rsync.log 2> auto_error.log' _
						, @ScriptDir & '\cygwin', @SW_HIDE)
				endif
				; logging
				if FileGetSize(@ScriptDir & '\cygwin\auto_rsync.log') > 0 then
					logger('Adresář ' & $configuration[get_index('dir' & $i + 1)][1] & ' byl zálohován.')
				elseif FileGetSize(@ScriptDir & '\cygwin\auto_error.log') > 0 then
					logger('Zálohovaní adresáře ' & $configuration[get_index('dir' & $i + 1)][1] & ' selhalo.')
				endif
			else
				logger('E: Adresář ' & $i + 1 & ' neexistuje.')
				exitloop
			endif
		endif
	next
endif
logger('Zalohování dokončeno.')
; exit
logger('Program exit: ' & @HOUR & ':' & @MIN & ':' & @SEC & ' ' & @MDAY & '.' & @MON & '.' & @YEAR)
logger('------------------------------------')
FileClose($log)
exit

; FUNC

func logger($text)
	FileWriteLine($log, $text)
endfunc

func get_cygpwin_path($path)
	$cygwin_path = StringRegExpReplace($path , '\\', '\/'); convert backslash -> slash
	$cygwin_path = StringRegExpReplace($cygwin_path ,'^(.)\:(.*)', '\/cygdrive\/$1$2'); convert drive colon
	return StringRegExpReplace($cygwin_path ,'(.*)', '$1'); catch space by doublequote
endfunc

func get_index($variable)
	return _ArraySearch($configuration, $variable, 0, 0, 0, 1)
endfunc
