#!/bin/bash
#
# volume status probe
#

CA="
-----BEGIN CERTIFICATE-----
-----END CERTIFICATE-----"

CRT="
-----BEGIN CERTIFICATE-----
-----END CERTIFICATE-----"

KEY="
-----BEGIN PRIVATE KEY-----
-----END PRIVATE KEY-----"

HOST='https://xxx'

LOCK=$(synoshare --is_accessible 'DATA' | sed -r 's/.*(.).$/\1/')

wget -O - -4 -q \
	--header="HTTP_X_NAS_I:probe" \
	--header="HTTP_X_NAS_I_LOCK:$LOCK" \
	--ca-certificate <(echo "$CA") \
	--certificate <(echo "$CRT") \
	--private-key <(echo "$KEY") \
	"$HOST" > /dev/null

exit 0

