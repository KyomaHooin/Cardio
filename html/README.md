
![NAS](https://github.com/KyomaHooin/Cardio/raw/master/NAS/prescription.png "screenshot")

DESCRIPTION

Prescription website.

INSTALL
<pre>
apt-get install nginx php php-fpm php-sqlite3 certbot python3-certbot-nginx

server {

	listen 80 default_server;

	root /var/www/html;

	index index.php;

	server_name xxx;

	return 301 https://$host$request_uri;

	location / {
		deny any;
	}
}

server {

	listen 443 ssl default_server;
	add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
	add_header X-Frame-Options "DENY";
	add_header X-Robots-Tag "noindex, nofollow, nosnippet, noarchive";

	# LE
	ssl_certificate /etc/letsencrypt/live/xxx/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/xxx/privkey.pem;
	include /etc/letsencrypt/options-ssl-nginx.conf;

	# Client certificate
	ssl_trusted_certificate /etc/nginx/ssl/ca.crt;
	ssl_verify_client optional;

	server_name xxx;

	root /var/www/html;
	index index.php;

	error_page 403 /4xx/403.html;
	error_page 404 /4xx/404.html;

	# 4xx
	location ~ /4xx {
		allow all;
	}
	# prescription
	location ~ /prescription {
		
		if ($ssl_client_verify != "SUCCESS") { return 403; }

		location ~ \.php$ {
			include snippets/fastcgi-php.conf;
			fastcgi_pass unix:/run/php/php7.3-fpm.sock;
		}
	}

	# fallback
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/run/php/php7.3-fpm.sock;
	}
}

</pre>
FILE
<pre>
</pre>
SOURCE

https://github.com/KyomaHooin/Cardio

