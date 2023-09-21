
![NAS](https://github.com/KyomaHooin/Cardio/raw/master/NAS/NAS.png "screenshot")

DESCRIPTION

Secure Rsync NAS GUI for Win64-bit OS for Synology DS118j.

TODO
<pre>
- Wireguard
- S70 archiving SW
</pre>
UART
<pre>
| 2 | 4 | 6 |
| 1 | 3 | 5 |
  ^

1 .. 3v3
2 .. <b>GND</b>
4 .. <b>TX</b>
6 .. <b>RX</b>

minicom -D /dev/ttyUSB0 -b 115200

[Ctrl] > [A] > [Z] > [O] > Serial port setup > [F]low control > Off
</pre>
TUNE
<pre>
mkdir /var/services/homes/backup/.ssh/
chmod 700 .ssh
chown backup:users .ssh
echo 'ssh-ed25519 ...' > .ssh/authorized_keys
chmod 644 authorized_keys
chown backup:users authorized_keys

/var/packages/VPNCenter/etc/openvpn/openvpn.conf:
log-append /var/log/openvpn.log
keepalive 10 120
#plugin /var/packages/VPNCenter/target/lib/radiusplugin.so ...
</pre>
FILE
<pre>
               bin/ - Cygwin lib/binary.

            NAS.au3 - Source code.
       CryptoNG.au3 - Cryptography NG library by "TheXMan".
           Json.au3 - JSON library by "Ward".
     BinaryCall.au3 - JSON binary wrapper.
            NAS.ini - Configuration file(JSON UTF-8 encoding).
            NAS.ico - ICON file.
            NAS.png - Application screen.

          CHANGELOG - Changelog.
            LICENSE - GNU GLPv3 license.
</pre>
SOURCE

https://github.com/KyomaHooin/Cardio

