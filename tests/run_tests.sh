#!/usr/bin/env bash
# Run all Mojo tests in this directory.
set -uo pipefail


shopt -s nullglob
TEST_FILES=(tests/test_*.mojo tests/*_test.mojo)

if [ ${#TEST_FILES[@]} -eq 0 ]; then
    echo "error: no test files found in $SCRIPT_DIR" >&2
    exit 1
fi

pass=0
fail=0
failed_files=()

for file in "${TEST_FILES[@]}"; do
    printf '\n=== %s ===\n' "$(basename "$file")"
    if pixi run mojo -I lib "$file" "$@"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        failed_files+=("$(basename "$file")")
    fi
done

printf '\n----------------------------------------\n'
printf 'Files passed: %d, files failed: %d\n' "$pass" "$fail"

if [ "$fail" -ne 0 ]; then
    printf 'Failed files:\n'
    printf '  %s\n' "${failed_files[@]}"
    exit 1
fi
