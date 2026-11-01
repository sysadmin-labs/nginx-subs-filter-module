# Changelog

## 0.6.5 (2026-11-01)

Taken over as a maintained fork of yaoweibin/ngx_http_substitutions_filter_module,
which last changed in 2022.  Its newest tag is 0.6.4, but its master branch
carries a lot of unreleased work on top of that tag: PCRE2 support, loadable
(dynamic) module support, the `subs_filter_bypass` directive and the
case-insensitive none-regex path.  This release is that master state, built
and tested against current nginx.

No behaviour of the module is changed in this release; the work here is the
build, the test harness and the packaging.  The FreeBSD port has shipped this
same master state (pinned to a commit, since upstream never tagged it).

The `t/` suite drives the filter through the nginx core `Test::Nginx`
(vendored under `t/lib`) and needs only core Perl.  `ci/subs_filter.sh`
fetches a page with curl and checks the fixed-string, case-insensitive and
regex-capture substitutions, and that a location without the filter is left
untouched.

Valgrind runs against that end-to-end driver, not the Test::Nginx suite: the
driver starts one foreground nginx under valgrind and stops it with QUIT, so
the pools are freed and a leak report would be the module's own; it is clean.
