
![VPS](https://github.com/KyomaHooin/Cardio/raw/master/VPS/vps_screen.png "screenshot")

DESCRIPTION

Prescription website.

INSTALL
<pre>
apt-get install apache2 sqlite3 apache2-mod-php php php-sqlite3 certbot python3-certbot-apache

certbot --apache -d xxx -d www.xxx
a2enmod headers
</pre>
EASY-RSA
<pre>
2.2.2 to 3.0.7:

cp -r EasyRSA-2.2.2/* /usr/share/easy-rsa/
cp -r keys/ /usr/share/easy-rsa/
cp vars /usr/share/easy-rsa/

./easyrsa upgrade pki

3.0.7 to 3.1.7:

cp -r pki/ /usr/share/easy-rsa/

./easyrsa build-server-full "domain name" nopass
./easyrsa build-client-full "name" nopass
./easyrsa export-p12 "name"
</pre>
FILE
<pre>
                  html/ - PHP Bootstrap frontend.
                   nas/ - Simple NAS IP lookup.
          prescription/ - PHP Bootstrap backend.
     cardio-database.py - Prescription SQLite3 template.
        nas-database.py - NAS SQLite3 template.
     
       000-default.conf - Default configuration.
000-default-ca-ssl.conf - Backend configuration.
    000-nas-ca-ssl.conf - NAS backend configuration.
000-default-le-ssl.conf - Frontend configuration.
</pre>
TODO
<pre>
- CAA record
- backend LE
- bookworm -> trixie
- cron | timer hourly probe 
- lock detection payload (synoshare --is_accessible $mount + HTTP_X_NAS_I_LOCK)
</pre>

SOURCE

https://github.com/KyomaHooin/Cardio

