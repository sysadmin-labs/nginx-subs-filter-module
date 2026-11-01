# nginx-subs-filter-module

[![Build&Test][build-test-badge]][build-test-link]
[![Substitutions][subs-badge]][subs-link]
[![FreeBSD][freebsd-badge]][freebsd-link]
[![A/UBSan][sanitizers-badge]][sanitizers-link]
[![Valgrind][valgrind-badge]][valgrind-link]
[![Reload][reload-badge]][reload-link]
[![CodeQL][codeql-badge]][codeql-link]
[![Lint][lint-badge]][lint-link]

[build-test-badge]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/build-test.yml/badge.svg
[build-test-link]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/build-test.yml
[subs-badge]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/subs_filter.yml/badge.svg
[subs-link]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/subs_filter.yml
[freebsd-badge]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/freebsd.yml/badge.svg
[freebsd-link]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/freebsd.yml
[sanitizers-badge]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/sanitizers.yml/badge.svg
[sanitizers-link]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/sanitizers.yml
[valgrind-badge]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/valgrind.yml/badge.svg
[valgrind-link]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/valgrind.yml
[reload-badge]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/reload.yml/badge.svg
[reload-link]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/reload.yml
[codeql-badge]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/codeql.yml/badge.svg
[codeql-link]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/codeql.yml
[lint-badge]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/lint.yml/badge.svg
[lint-link]: https://github.com/sysadmin-labs/nginx-subs-filter-module/actions/workflows/lint.yml

This module rewrites strings in the response body as nginx sends it, like a
streaming `sed` for HTTP.  Matches can be fixed strings or regular
expressions with captures, applied to a configurable set of content types.
It is a maintained fork of yaoweibin/ngx_http_substitutions_filter_module.

## Synopsis

```nginx
location / {
    subs_filter_types text/html text/css;
    subs_filter old.example.com new.example.com;
    subs_filter "<head>" "<head><base href=\"/\">" ro;
    subs_filter "foo([0-9]+)" "bar$1" r;
}
```

## Directives

- `subs_filter <match> <replacement> [flags]`: replace `match` with
  `replacement` in the body.  Flags are a single token made of:
  `g` global (the default), `i` case-insensitive, `r` treat `match` as a
  regular expression (so `$1`..`$9` are captures), `o` replace only once.
- `subs_filter_types <type> ...`: content types to filter in addition to
  `text/html` (the default).
- `subs_filter_bypass <variable> ...`: skip filtering when any value is
  non-empty and not `0`.
- `subs_buffers <number> <size>`: how many buffers and of what size the
  filter may use for a rewritten response.
- `subs_line_buffer_size <size>`: the largest match that can span buffer
  boundaries.

## Building

```sh
./configure --add-module=/path/to/nginx-subs-filter-module
```

or as a loadable module

```sh
./configure --add-dynamic-module=/path/to/nginx-subs-filter-module
```

with `load_module modules/ngx_http_subs_filter_module.so;` in the main
context.  The module is self-contained and needs no extra libraries.

## Testing

```sh
ci/build.sh 1.30.5 /tmp/nginx-test
TEST_NGINX_BINARY=/tmp/nginx-test/sbin/nginx prove -r t/
ci/subs_filter.sh /tmp/nginx-test/sbin/nginx
ci/reload.sh /tmp/nginx-test/sbin/nginx
```

The `t/` suite needs only core Perl; the nginx core `Test::Nginx` is
vendored under `t/lib`.  `ci/subs_filter.sh` needs only `curl`.

## License

BSD 2-Clause, see [LICENSE](LICENSE).
