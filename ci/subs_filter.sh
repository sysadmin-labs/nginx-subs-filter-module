#!/bin/sh
#
# Drive the subs_filter module against a running nginx with a real HTTP
# client: it rewrites matched strings in the response body, so this fetches
# a known page and checks that fixed-string, case-insensitive and regex
# substitutions all took effect and that an untouched location is left
# alone.  This is also what the FreeBSD job, the sanitizer job and the
# valgrind job run.
#
# usage: ci/subs_filter.sh <nginx binary>
#
# Set SUBS_FILTER_LOAD_MODULE to the path of ngx_http_subs_filter_module.so
# to test a loadable build.  Set SUBS_FILTER_VALGRIND=1 to run one foreground
# nginx under valgrind and fail on any memory finding.

set -eu

NGINX=${1:?path to the nginx binary missing}
SRC=$(cd "$(dirname "$0")/.." && pwd)
WORK=${CI_WORK:-$SRC/ci-work}/subs_filter
PORT=${SUBS_FILTER_PORT:-18680}

command -v curl > /dev/null || { echo "curl(1) is needed" >&2; exit 2; }

VG=${SUBS_FILTER_VALGRIND:-}
vglog="$WORK/logs/valgrind.log"
maxtime=10
daemon_mode=on
master_mode=on
if [ -n "$VG" ]; then
	command -v valgrind > /dev/null || { echo "valgrind(1) is needed" >&2; exit 2; }
	daemon_mode=off
	master_mode=off
	maxtime=60
fi

rm -rf "$WORK"
mkdir -p "$WORK/conf" "$WORK/logs" "$WORK/root"

fail=0
note() { echo "  $1" >&2; fail=1; }

# A page with every case the filter has to handle, and one line it must not
# touch.
cat > "$WORK/root/page.html" <<'HTML'
hello world
HELLO AGAIN
item foo42 and foo7
leave this line alone
HTML
cp "$WORK/root/page.html" "$WORK/root/raw.html"

load=
[ -n "${SUBS_FILTER_LOAD_MODULE:-}" ] && load="load_module $SUBS_FILTER_LOAD_MODULE;"

ngx_user=
if [ "$(id -u)" = 0 ]; then
	ngx_user="user root $(id -gn);"
fi

cat > "$WORK/conf/nginx.conf" <<CONF
$load
$ngx_user
daemon $daemon_mode;
master_process $master_mode;
worker_processes 1;
pid $WORK/logs/nginx.pid;
error_log $WORK/logs/error.log info;
events { worker_connections 64; }
http {
    access_log off;
    default_type text/html;

    server {
        listen 127.0.0.1:$PORT;
        root $WORK/root;

        location /sub/ {
            alias $WORK/root/;
            subs_filter hello goodbye gi;
            subs_filter "foo([0-9]+)" "bar\$1" r;
        }

        location /raw/ {
            alias $WORK/root/;
        }
    }
}
CONF

"$NGINX" -p "$WORK" -c "$WORK/conf/nginx.conf" -t 2> "$WORK/logs/t.log" ||
	{ cat "$WORK/logs/t.log" >&2; echo "ci/subs_filter.sh: config rejected" >&2; exit 1; }

ngxpid=
if [ -n "$VG" ]; then
	valgrind --leak-check=full --show-leak-kinds=definite,indirect \
		--errors-for-leak-kinds=definite,indirect --error-exitcode=99 \
		--log-file="$vglog" --suppressions="$SRC/valgrind.suppress" \
		--trace-children=no \
		"$NGINX" -p "$WORK" -c "$WORK/conf/nginx.conf" &
	ngxpid=$!
	up=0; i=0
	while [ $i -lt 80 ]; do
		if curl -s -o /dev/null --max-time 5 "http://127.0.0.1:$PORT/raw/raw.html"; then
			up=1; break
		fi
		sleep 0.5; i=$((i + 1))
	done
	[ "$up" = 1 ] || { echo "ci/subs_filter.sh: nginx did not come up under valgrind" >&2; kill "$ngxpid" 2>/dev/null; exit 1; }
else
	"$NGINX" -p "$WORK" -c "$WORK/conf/nginx.conf"
	sleep 1
fi

stop() {
	if [ -n "$ngxpid" ]; then
		kill -QUIT "$ngxpid" 2>/dev/null
		wait "$ngxpid" 2>/dev/null
	elif [ -s "$WORK/logs/nginx.pid" ]; then
		kill -QUIT "$(cat "$WORK/logs/nginx.pid")" 2>/dev/null
	fi
	return 0
}
trap stop EXIT INT TERM

base="http://127.0.0.1:$PORT"

echo "== the filter rewrites the body"
body=$(curl -s --max-time "$maxtime" "$base/sub/page.html")
printf '%s\n' "$body" | grep -q 'goodbye world'   || note "fixed-string substitution missing"
printf '%s\n' "$body" | grep -q 'goodbye AGAIN'   || note "case-insensitive substitution missing"
printf '%s\n' "$body" | grep -q 'bar42'           || note "regex capture substitution missing (foo42)"
printf '%s\n' "$body" | grep -q 'bar7'            || note "regex capture substitution missing (foo7)"
printf '%s\n' "$body" | grep -q 'leave this line alone' || note "untouched line was lost"
if printf '%s\n' "$body" | grep -qiE 'hello|foo[0-9]'; then
	note "an original token survived the substitution"
	printf '%s\n' "$body" | grep -niE 'hello|foo[0-9]' >&2
fi

echo "== a location without subs_filter is left alone"
raw=$(curl -s --max-time "$maxtime" "$base/raw/raw.html")
printf '%s\n' "$raw" | grep -q 'hello world' || note "unfiltered location was modified"

echo "== error log"
if grep -qE '\[(alert|emerg|crit)\]' "$WORK/logs/error.log"; then
	note "alert/emerg/crit in the error log"
	grep -E '\[(alert|emerg|crit)\]' "$WORK/logs/error.log" | head -3 >&2
else
	echo "  clean"
fi

if [ -n "$VG" ]; then
	echo "== valgrind"
	stop
	ngxpid=
	trap - EXIT INT TERM
	errs=$(sed -n 's/.*ERROR SUMMARY: \([0-9][0-9]*\) errors.*/\1/p' "$vglog" | tail -1)
	defl=$(sed -n 's/.*definitely lost: \([0-9,]*\) bytes.*/\1/p' "$vglog" | tr -d , | tail -1)
	indl=$(sed -n 's/.*indirectly lost: \([0-9,]*\) bytes.*/\1/p' "$vglog" | tr -d , | tail -1)
	if [ "${errs:-0}" != 0 ] || [ "${defl:-0}" != 0 ] || [ "${indl:-0}" != 0 ]; then
		note "valgrind: ${errs:-?} errors, definitely lost ${defl:-?}, indirectly lost ${indl:-?}"
		grep -niE "Invalid read|Invalid write|uninitialised|Mismatched free" "$vglog" >&2
	else
		echo "  clean (errors $errs, suppressed shown in log)"
	fi
fi

[ "$fail" -eq 0 ] || { echo "ci/subs_filter.sh: failed" >&2; exit 1; }
echo "ci/subs_filter.sh: ok"
