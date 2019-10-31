
![NASBackup](https://github.com/KyomaHooin/NASBackup/raw/master/NASBackup.png "screenshot")

DESCRIPTION

Secure NAS rsync backup GUI for Win64-bit OS.

TODO

<pre>
-screenshot
</pre>

NAS

<pre>
QNAP:
  Control Panel > Network & File Services > Telnet / SSH
  Backup Station > Backup Server > Rsync Server
  -patch RSYNC CLI config
Synology:
  Control Panel > Users > 'kardio'
  Control Panel > Terminal & SNMP > SSH
  Control Panel > Backup Services > Enable network backup service / no speed limit
  COntrol Panel > Permission > Shared Folder > 'kardio' R/W
  -patch SSHD config
WD MyCloud:
  Settings > SSH > On
</pre>

ROUTER

<pre>
  - SSH port forward
  - Static IP
</pre>

FILE
<pre>
NASBackupAuto.au3 - Source code CLI version.
    NASBackup.au3 - Source code GUI version.
    NASBackup.ico - Icon file.
    NASBackup.png - Application screen.
       kardio.key - RSA test private key.
       kardio.pub - RSA test pub key.

          cygwin/ - <a href="https://cygwin.com">Cygwin</a> dll & binary.
</pre>
SOURCE

https://github.com/KyomaHooin/NASBackup

