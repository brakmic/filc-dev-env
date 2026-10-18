#!/usr/bin/env bash
# Run the Fil-C demo suite and validate the expected behavior.
#
# Requirements:
#   - filcc and fil++ in PATH (for example /opt/fil/bin or a pizfix build)
#   - readelf from binutils
#
# Usage: ./tests/run-tests.sh [--verbose] [--keep]

set -u

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_DIR/src/filc"
CC="${FILC_CC:-filcc}"
CXX="${FILC_CXX:-fil++}"
FILC_FLAGS=(-O0 -fno-builtin -fno-inline)
VERBOSE=false
KEEP=false

pass_count=0
fail_count=0
failed_names=()

pass() {
    pass_count=$((pass_count + 1))
    printf '  ok   %s\n' "$1"
}

fail() {
    fail_count=$((fail_count + 1))
    failed_names+=("$1")
    printf '  FAIL %s: %s\n' "$1" "$2"
}

note() {
    if [ "$VERBOSE" = true ]; then
        printf '       %s\n' "$1"
    fi
}

usage() {
    cat <<EOF
Usage: ./tests/run-tests.sh [OPTIONS]

Compile and run every program in src/filc and check the expected result.
Each source declares its expectation with a "// EXPECT: success" or
"// EXPECT: panic" marker. A panic must exit with status 133 and print
"filc safety error".

Options:
  -v, --verbose  Show compiler version and captured output
      --keep     Keep the temporary build directory
  -h, --help     Show this help

Environment:
  FILC_CC        C compiler (default: filcc)
  FILC_CXX       C++ compiler (default: fil++)
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -v|--verbose) VERBOSE=true ;;
        --keep) KEEP=true ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

TMP_DIR="$(mktemp -d)"
# shellcheck disable=SC2329  # invoked by the EXIT trap below
cleanup() {
    if [ "$KEEP" = true ]; then
        echo "Kept test artifacts: $TMP_DIR"
    else
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

echo "==> Repository: $REPO_DIR"

if ! command -v "$CC" >/dev/null 2>&1; then
    echo "Error: $CC not found in PATH" >&2
    echo "Add /opt/fil/bin to PATH or set FILC_CC to the compiler path." >&2
    exit 2
fi
if ! command -v "$CXX" >/dev/null 2>&1; then
    echo "Error: $CXX not found in PATH" >&2
    exit 2
fi
if ! command -v readelf >/dev/null 2>&1; then
    echo "Error: readelf not found (install binutils)" >&2
    exit 2
fi

echo "==> Compiler: $("$CC" --version | head -1)"

# ---------------------------------------------------------------------------
# Script checks
# ---------------------------------------------------------------------------
echo ""
echo "==> Script checks"
for file in setup.sh .bash_aliases tests/run-tests.sh; do
    if bash -n "$REPO_DIR/$file" 2>"$TMP_DIR/syntax.log"; then
        pass "syntax: $file"
    else
        fail "syntax: $file" "$(head -3 "$TMP_DIR/syntax.log")"
    fi
done

for file in setup.sh .bash_aliases tests/run-tests.sh; do
    if grep -q $'\r' "$REPO_DIR/$file"; then
        fail "line endings: $file" "CRLF found"
    else
        pass "line endings: $file"
    fi
done

if grep -q 'eol=lf' "$REPO_DIR/.gitattributes" 2>/dev/null; then
    pass ".gitattributes defines LF"
else
    fail ".gitattributes defines LF" "missing or incomplete"
fi

if bash "$REPO_DIR/setup.sh" --help 2>/dev/null | grep -q -- '--no-install'; then
    pass "setup.sh --help"
else
    fail "setup.sh --help" "expected option list"
fi

# ---------------------------------------------------------------------------
# Demo programs
# ---------------------------------------------------------------------------
echo ""
echo "==> Demo programs"
for src in "$SRC_DIR"/*.c "$SRC_DIR"/*.cpp; do
    [ -f "$src" ] || continue
    name="${src##*/}"
    stem="${name%.*}"
    bin="$TMP_DIR/$stem"
    compiler="$CC"
    case "$src" in
        *.cpp) compiler="$CXX" ;;
    esac

    expect=$(grep -m1 -o 'EXPECT: [a-z]*' "$src" | awk '{print $2}')
    if [ -z "$expect" ]; then
        fail "$name" "missing EXPECT marker"
        continue
    fi

    if ! "$compiler" "${FILC_FLAGS[@]}" "$src" -o "$bin" >"$TMP_DIR/$name.compile.log" 2>&1; then
        fail "$name" "compilation failed"
        sed 's/^/       /' "$TMP_DIR/$name.compile.log" | head -20
        continue
    fi

    if ! readelf -l "$bin" 2>/dev/null | grep -Eq 'ld-fil1|ld-yolo'; then
        fail "$name" "not linked with the Fil-C loader"
        continue
    fi

    if command -v timeout >/dev/null 2>&1; then
        { ( timeout 20 "$bin" >"$TMP_DIR/$name.out" 2>"$TMP_DIR/$name.err" ); rc=$?; } 2>/dev/null
    else
        { ( "$bin" >"$TMP_DIR/$name.out" 2>"$TMP_DIR/$name.err" ); rc=$?; } 2>/dev/null
    fi

    case "$expect" in
        success)
            if [ "$rc" -eq 0 ]; then
                pass "$name (success)"
                note "$(cat "$TMP_DIR/$name.out")"
            else
                fail "$name" "expected exit 0, got $rc"
            fi
            ;;
        panic)
            if [ "$rc" -eq 133 ] && grep -q 'filc safety error' "$TMP_DIR/$name.err"; then
                pass "$name (panic)"
                note "$(grep -m1 'filc safety error' "$TMP_DIR/$name.err")"
            else
                fail "$name" "expected panic 133, got $rc"
            fi
            ;;
        *)
            fail "$name" "unknown EXPECT value: $expect"
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Workflow functions
# ---------------------------------------------------------------------------
echo ""
echo "==> Workflow functions"
if (
    export HOME="$TMP_DIR/alias-home"
    export FILC_BUILD_DIR="$TMP_DIR/alias-build"
    export FILC_BIN_DIR="$TMP_DIR/alias-bin"
    mkdir -p "$HOME"
    # shellcheck source=/dev/null
    . "$REPO_DIR/.bash_aliases" >/dev/null 2>&1
    filcc-build "$SRC_DIR/hello.c" >/dev/null 2>&1 || exit 1
    [ -x "$FILC_BUILD_DIR/hello" ] || exit 2
    filc-exec hello >"$TMP_DIR/alias-exec.out" 2>&1 || exit 3
    grep -q 'Hello from Fil-C!' "$TMP_DIR/alias-exec.out" || exit 4
    filc-verify hello >"$TMP_DIR/alias-verify.out" 2>&1 || exit 5
    grep -Eq 'ld-fil1|ld-yolo' "$TMP_DIR/alias-verify.out" || exit 6
    filc-list >"$TMP_DIR/alias-list.out" 2>&1 || exit 7
    grep -q 'hello' "$TMP_DIR/alias-list.out" || exit 8
    filc-clean >/dev/null 2>&1 || exit 9
    [ -z "$(find "$FILC_BUILD_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ] || exit 10
); then
    pass "alias functions"
else
    fail "alias functions" "function check failed"
fi

# ---------------------------------------------------------------------------
# setup.sh sandbox
# ---------------------------------------------------------------------------
echo ""
echo "==> setup.sh sandbox"
if [ -d /opt/fil ]; then
    pass "setup.sh sandbox (skipped: /opt/fil exists)"
else
    setup_home="$TMP_DIR/setup-home"
    mkdir -p "$setup_home"
    echo 'alias my_personal_alias=keepme' >"$setup_home/.bash_aliases"

    if HOME="$setup_home" bash "$REPO_DIR/setup.sh" --no-deps --no-install --yes \
        >"$TMP_DIR/setup1.log" 2>&1; then
        setup_problem=""
        [ -f "$setup_home/.filc_aliases" ] || setup_problem="missing .filc_aliases"
        if [ -z "$setup_problem" ]; then
            grep -q 'keepme' "$setup_home/.bash_aliases" || setup_problem="personal .bash_aliases changed"
        fi
        if [ -z "$setup_problem" ]; then
            grep -q '>>> Fil-C workflow aliases >>>' "$setup_home/.bashrc" || setup_problem="missing .bashrc block"
        fi
        if [ -z "$setup_problem" ]; then
            [ -d "$setup_home/build" ] || setup_problem="missing build directory"
        fi
        if [ -z "$setup_problem" ]; then
            pass "setup.sh sandbox"
        else
            fail "setup.sh sandbox" "$setup_problem"
        fi
    else
        fail "setup.sh sandbox" "non-zero exit"
        sed 's/^/       /' "$TMP_DIR/setup1.log" | head -20
    fi

    HOME="$setup_home" bash "$REPO_DIR/setup.sh" --no-deps --no-install --yes \
        >"$TMP_DIR/setup2.log" 2>&1 || true
    blocks=$(grep -c '>>> Fil-C workflow aliases >>>' "$setup_home/.bashrc" 2>/dev/null || true)
    if [ "$blocks" -eq 1 ]; then
        pass "setup.sh idempotent"
    else
        fail "setup.sh idempotent" "expected 1 .bashrc block, found $blocks"
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "==> Results: $pass_count passed, $fail_count failed"
if [ "$fail_count" -ne 0 ]; then
    printf '    Failed: %s\n' "${failed_names[*]}"
    exit 1
fi
exit 0
