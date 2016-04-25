#/bin/sh

# gh issue #82, per-frontend wildcard certificates

. ${TESTDIR}common.sh
set +o errexit

PORT1=$(($RANDOM + 1024))
PORT2=$(($RANDOM + 1024))
PORT3=$(($RANDOM + 1024))

mk_cfg <<EOF
backend = "[hitch-tls.org]:80"

tls = on
ciphers = "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA:DHE-RSA-CAMELLIA128-SHA:DHE-RSA-CAMELLIA256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA:AES256-SHA:CAMELLIA128-SHA:CAMELLIA256-SHA:ECDHE-RSA-DES-CBC3-SHA:DES-CBC3-SHA:!LOW:!MEDIUM"
prefer-server-ciphers = on
ssl-engine = ""
sni-nomatch-abort = on

workers = 2
backlog = 100
keepalive = 3600
#chroot = "/etc/hitch"
#user = "hitch"
#group = "hitch"
quiet = off
syslog = on
syslog-facility = "daemon"
daemon = on

write-ip = off
write-proxy-v1 = off
# write-proxy-v2 = on
proxy-proxy = off

frontend = {
  host = "$LISTENADDR"
  port = "$PORT1"
  pem-file = "$CERTSDIR/wildcard.example.com"
}

frontend = {
  host = "$LISTENADDR"
  port = "$PORT2"
  pem-file = "$CERTSDIR/wildcard.example.com"
  pem-file = "$CERTSDIR/site1.example.com"
}

frontend = {
  host = "$LISTENADDR"
  port = "$PORT3"
  pem-file = "$CERTSDIR/site2.example.com"
}
EOF

hitch $HITCH_ARGS --config=$CONFFILE
test "$?" = "0" || die "Hitch did not start."

# Wildcard cert on frontend #1
echo | openssl s_client -servername foo.example.com -prexit -connect $LISTENADDR:$PORT1 >$DUMPFILE 2>&1
test "$?" = "0" || die "s_client failed"
grep -q -c "/CN=\*.example.com" $DUMPFILE
test "$?" = "0" || die "s_client got wrong certificate in listen port #1"

# Wildcard cert on frontend #2
echo | openssl s_client -servername bar.example.com -prexit -connect $LISTENADDR:$PORT2 >$DUMPFILE 2>&1
test "$?" = "0" || die "s_client failed"
grep -q -c "/CN=\*.example.com" $DUMPFILE
test "$?" = "0" || die "s_client got wrong certificate in listen port #2"

# Exact match on frontend #2
echo | openssl s_client -servername site1.example.com -prexit -connect $LISTENADDR:$PORT2 >$DUMPFILE 2>&1
test "$?" = "0" || die "s_client failed"
grep -q -c "/CN=site1.example.com" $DUMPFILE
test "$?" = "0" || die "s_client got wrong certificate in listen port #2"