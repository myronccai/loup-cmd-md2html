#!/usr/bin/env bash
# Parity tests: convert every tests/fixtures/*.md in both lanes that the
# same host.dual source runs in, and compare the HTML with the golden
# tests/fixtures/*.html byte for byte.
#
#   interpreted   LOUP run source/main.loup -- FILE
#   native        NATIVE_BIN FILE
#
# usage: tests/parity.sh LOUP NATIVE_BIN

set -u
LOUP=$1
NATIVE=$2
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0
count=0

# run_lane LANE FILE > html; with FILE "-", the input comes from standard
# input (the document fixture).
run_lane() {
    local lane=$1 file=$2
    case $lane in
        interpreted) "$LOUP" run source/main.loup -- "$file" ;;
        native)      "$NATIVE" "$file" ;;
    esac
}

compare() {
    local name=$1 lane=$2 status=$3 expected=$4
    if [ "$status" -eq 0 ] && [ ! -s "$TMP/err" ] && cmp -s "$expected" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name ($lane lane, exit $status)"
        diff "$expected" "$TMP/out" | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

for md in tests/fixtures/*.md; do
    name=$(basename "$md" .md)
    count=$((count + 1))
    for lane in interpreted native; do
        run_lane "$lane" "$md" > "$TMP/out" 2> "$TMP/err"
        compare "$name" "$lane" $? "${md%.md}.html"
    done
done

# The same document through standard input.
count=$((count + 1))
for lane in interpreted native; do
    run_lane "$lane" - < tests/fixtures/document.md > "$TMP/out" 2> "$TMP/err"
    compare "document (stdin)" "$lane" $? tests/fixtures/document.html
done

echo "parity: $pass passed, $fail failed (2 lanes x $count inputs)"
[ "$fail" -eq 0 ]
