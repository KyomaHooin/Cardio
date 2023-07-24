
![VPS](https://github.com/KyomaHooin/Cardio/raw/master/VPS/vps_screen.png "screenshot")

DESCRIPTION

Prescription website.

INSTALL
<pre>
apt-get install apache2 sqlite3 apache2-mod-php php php-sqlite3 certbot python3-certbot-apache

certbot --apache -d xxx -d www.xxx
a2enmod headers
</pre>
FILE
<pre>
                  html/ - PHP Bootstrap frontend.
          prescription/ - PHP Bootstrap backend.
     cardio-database.py - SQLite3 template.
     
       000-default.conf - Default configuration.
000-default-ca-ssl.conf - Backend configuration.
000-default-le-ssl.conf - Frontend configuration.
</pre>
SOURCE

https://github.com/KyomaHooin/Cardio

