#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte) and exit status with the expected ones.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$1
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]
# Like check, but compares standard error (standard output must be empty).
check_err() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want_err"
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && [ ! -s "$TMP/out" ] && cmp -s "$TMP/want_err" "$TMP/err"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff "$TMP/want_err" "$TMP/err" | sed 's/^/    /' | head -10
        sed 's/^/    stdout: /' "$TMP/out" | head -5
    fi
}

USAGE_HINT=$'Try \'md2html --help\' for more information.\n'
F=tests/fixtures

# Input from a file, standard input and -
check_file "file"            0 "$F/headings.html"      "$F/headings.md"
IN="$F/lists.md" check_file "stdin"  0 "$F/lists.html"
IN="$F/lists.md" check_file "dash"   0 "$F/lists.html"  -
printf '' > "$TMP/empty.md"
check "empty input"          0 ''                      "$TMP/empty.md"
printf 'no final newline' > "$TMP/nonl.md"
check "no final newline"     0 $'<p>no final newline</p>\n' "$TMP/nonl.md"
printf '# Title\r\n\r\ntext\r\n' > "$TMP/crlf.md"
check "CRLF input"           0 $'<h1>Title</h1>\n<p>text</p>\n' "$TMP/crlf.md"

# -o writes a file and prints nothing
check "output option"        0 ''                      -o "$TMP/out.html" "$F/quotes.md"
check_file "output content"  0 "$F/quotes.html"        "$F/quotes.md"
cmp -s "$TMP/out.html" "$F/quotes.html" && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: -o file content"; }
check "--output="            0 ''                      "--output=$TMP/out2.html" "$F/rules.md"
cmp -s "$TMP/out2.html" "$F/rules.html" && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: --output= file content"; }

# Standalone pages
printf '# Hello & welcome\n\nSome *text*.\n' > "$TMP/page.md"
check "standalone" 0 '<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Hello &amp; welcome</title>
</head>
<body>
<h1>Hello &amp; welcome</h1>
<p>Some <em>text</em>.</p>
</body>
</html>
' -s "$TMP/page.md"
check "title option"         0 $'<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8">\n<title>My &lt;Page&gt;</title>\n</head>\n<body>\n<p>no final newline</p>\n</body>\n</html>\n' --title 'My <Page>' "$TMP/nonl.md"
printf 'just text\n' > "$TMP/notes.md"
check "title from file name" 0 $'<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8">\n<title>notes</title>\n</head>\n<body>\n<p>just text</p>\n</body>\n</html>\n' --standalone "$TMP/notes.md"
IN="$TMP/notes.md" check "untitled stdin" 0 $'<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8">\n<title>Untitled</title>\n</head>\n<body>\n<p>just text</p>\n</body>\n</html>\n' -s
printf '<main title="{{title}}">\n{{body}}</main>\n' > "$TMP/layout.html"
check "template"             0 $'<main title="Hello &amp; welcome">\n<h1>Hello &amp; welcome</h1>\n<p>Some <em>text</em>.</p>\n</main>\n' -t "$TMP/layout.html" "$TMP/page.md"
check "template + title"     0 $'<main title="T">\n<p>just text</p>\n</main>\n' --template="$TMP/layout.html" --title T "$TMP/notes.md"

# Errors: status 1
check_err "missing input"    1 "md2html: $TMP/nope.md: No such file or directory"$'\n' "$TMP/nope.md"
check_err "input is a dir"   1 "md2html: $TMP: Is a directory"$'\n' "$TMP"
check_err "missing template" 1 "md2html: $TMP/nope.html: No such file or directory"$'\n' -t "$TMP/nope.html" "$TMP/page.md"
check_err "missing out dir"  1 "md2html: $TMP/no/out.html: No such file or directory"$'\n' -o "$TMP/no/out.html" "$TMP/page.md"
check_err "output is a dir"  1 "md2html: $TMP: Is a directory"$'\n' -o "$TMP" "$TMP/page.md"

# Usage errors: status 2
check_err "extra operand"    2 "md2html: extra operand 'b.md'"$'\n'"$USAGE_HINT" a.md b.md
check_err "unknown option"   2 "md2html: unknown option '-x'"$'\n'"$USAGE_HINT" -x
check_err "missing value"    2 "md2html: option '-o' requires a value"$'\n'"$USAGE_HINT" -o
check_err "flag with value"  2 "md2html: option '--standalone' does not take a value"$'\n'"$USAGE_HINT" --standalone=1

# help and version
check "version"              0 $'md2html (loup-cmd-md2html) 0.1.0\n'  --version
"$BIN" --help > "$TMP/help" 2>&1
if head -1 "$TMP/help" | grep -q '^usage: md2html \[OPTION\]... \[FILE\]$'; then
    pass=$((pass + 1))
else
    fail=$((fail + 1)); echo "FAIL: --help first line"
fi

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
