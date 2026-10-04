#!/usr/bin/env bash
set -u
ENGINE=${1:?path to VoxelEngine}
shift
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TESTS=("$@")
[ ${#TESTS[@]} -eq 0 ] && TESTS=("$ROOT"/dev/zomboid/tests/*.lua)
USERDIR=$(mktemp -d)
trap 'rm -rf "$USERDIR"' EXIT
failed=0
for t in "${TESTS[@]}"; do
    log="$USERDIR/$(basename "$t").log"
    timeout 600 "$ENGINE" --res "$ROOT/res" --dir "$USERDIR" --headless --test "$t" >"$log" 2>&1
    code=$?
    errors=$(grep -E "\[E\]|traceback|stack traceback|error:" "$log" | grep -v "^\s*$" | head -20)
    if [ $code -ne 0 ] || [ -n "$errors" ]; then
        echo "FAIL $(basename "$t") (exit $code)"
        echo "$errors"
        tail -20 "$log"
        failed=1
    else
        echo "OK   $(basename "$t")"
        grep "\[zomboid-test\]" "$log" | sed 's/^/     /'
    fi
done
exit $failed
