
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
                html/ - Frontend.
          prescription/ - Backend.
     cardio-database.py - SQLite3 template.
     
       000-default.conf - Apache default configuration.
000-default-ca-ssl.conf - Backend Apache configuration.
000-default-le-ssl.conf - Apache frontend configuration.
</pre>
SOURCE

https://github.com/KyomaHooin/Cardio

