#!/usr/bin/perl

# Tests for ngx_http_substitutions_filter_module.

###############################################################################

use warnings;
use strict;

use Test::More;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib 'lib';
use Test::Nginx;

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

my $t = Test::Nginx->new()->has(qw/http/)->plan(7);

$t->write_file_expand('nginx.conf', <<'EOF');

%%TEST_GLOBALS%%

daemon off;

events {
}

http {
    %%TEST_GLOBALS_HTTP%%

    default_type text/html;

    server {
        listen       127.0.0.1:8080;
        server_name  localhost;

        location /sub/ {
            alias %%TESTDIR%%/html/;
            subs_filter hello goodbye gi;
            subs_filter "foo([0-9]+)" "bar$1" r;
        }

        location /raw/ {
            alias %%TESTDIR%%/html/;
        }
    }
}

EOF

mkdir $t->testdir() . "/html";
$t->write_file('html/page.html',
	"hello world\nHELLO AGAIN\nitem foo42 and foo7\nleave this line alone\n");

$t->run();

###############################################################################

my $b = http_get('/sub/page.html');
like($b, qr/goodbye world/,         'fixed-string substitution');
like($b, qr/goodbye AGAIN/,         'case-insensitive substitution');
like($b, qr/bar42/,                 'regex capture substitution (foo42)');
like($b, qr/bar7/,                  'regex capture substitution (foo7)');
like($b, qr/leave this line alone/, 'untouched line kept');
unlike($b, qr/hello|foo[0-9]/i,     'no original token survived');

my $raw = http_get('/raw/page.html');
like($raw, qr/hello world/,         'a location without subs_filter is left alone');

###############################################################################
