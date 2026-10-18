# Fil-C workflow functions for demo/test programs
# These prevent compiler optimizations that hide memory safety bugs

# Build directory for all compilation artifacts
export FILC_BUILD_DIR="${FILC_BUILD_DIR:-$HOME/build}"
export FILC_BIN_DIR="${FILC_BIN_DIR:-$HOME/bin}"

# Ensure directories exist
mkdir -p "$FILC_BUILD_DIR" "$FILC_BIN_DIR"

# C compiler with demo-safe flags (no optimization, no inlining/builtins)
alias filcc-demo='filcc -O0 -fno-builtin -fno-inline'

# C compiler with debug symbols for gdb
alias filcc-debug='filcc -O0 -g -fno-builtin -fno-inline'

# C++ compiler with demo-safe flags
alias filcpp-demo='fil++ -O0 -fno-builtin -fno-inline'

# C++ compiler with debug symbols
alias filcpp-debug='fil++ -O0 -g -fno-builtin -fno-inline'

# Quick compile and run (C) - builds to FILC_BUILD_DIR, runs from there
filcc-run() {
    if [ $# -eq 0 ]; then
        echo "Usage: filcc-run <source.c> [additional flags]"
        return 1
    fi
    
    local src="$1"
    shift
    local basename="${src##*/}"
    local out="$FILC_BUILD_DIR/${basename%.*}"
    
    echo "==> Compiling: $src -> $out"
    filcc -O0 -fno-builtin -fno-inline "$src" -o "$out" "$@" && {
        echo "==> Running: $out"
        "$out"
        local exitcode=$?
        echo "==> Exit code: $exitcode"
        return $exitcode
    }
}

# Quick compile and run (C++) - builds to FILC_BUILD_DIR, runs from there
filcpp-run() {
    if [ $# -eq 0 ]; then
        echo "Usage: filcpp-run <source.cpp> [additional flags]"
        return 1
    fi
    
    local src="$1"
    shift
    local basename="${src##*/}"
    local out="$FILC_BUILD_DIR/${basename%.*}"
    
    echo "==> Compiling: $src -> $out"
    fil++ -O0 -fno-builtin -fno-inline "$src" -o "$out" "$@" && {
        echo "==> Running: $out"
        "$out"
        local exitcode=$?
        echo "==> Exit code: $exitcode"
        return $exitcode
    }
}

# Build without running - outputs to FILC_BUILD_DIR by default
filcc-build() {
    if [ $# -eq 0 ]; then
        echo "Usage: filcc-build <source.c> [-o output] [additional flags]"
        echo "Default output: $FILC_BUILD_DIR/<basename>"
        return 1
    fi
    
    local src="$1"
    shift
    
    # Check if -o is specified
    local has_output=0
    for arg in "$@"; do
        if [ "$arg" = "-o" ]; then
            has_output=1
            break
        fi
    done
    
    if [ $has_output -eq 0 ]; then
        local basename="${src##*/}"
        local out="$FILC_BUILD_DIR/${basename%.*}"
        echo "==> Building: $src -> $out"
        filcc -O0 -fno-builtin -fno-inline "$src" -o "$out" "$@"
    else
        echo "==> Building: $src"
        filcc -O0 -fno-builtin -fno-inline "$src" "$@"
    fi
}

# Build C++ without running - outputs to FILC_BUILD_DIR by default
filcpp-build() {
    if [ $# -eq 0 ]; then
        echo "Usage: filcpp-build <source.cpp> [-o output] [additional flags]"
        echo "Default output: $FILC_BUILD_DIR/<basename>"
        return 1
    fi
    
    local src="$1"
    shift
    
    # Check if -o is specified
    local has_output=0
    for arg in "$@"; do
        if [ "$arg" = "-o" ]; then
            has_output=1
            break
        fi
    done
    
    if [ $has_output -eq 0 ]; then
        local basename="${src##*/}"
        local out="$FILC_BUILD_DIR/${basename%.*}"
        echo "==> Building: $src -> $out"
        fil++ -O0 -fno-builtin -fno-inline "$src" -o "$out" "$@"
    else
        echo "==> Building: $src"
        fil++ -O0 -fno-builtin -fno-inline "$src" "$@"
    fi
}

# Run a previously built binary from FILC_BUILD_DIR
filc-exec() {
    if [ $# -eq 0 ]; then
        echo "Usage: filc-exec <program-name>"
        echo "Runs $FILC_BUILD_DIR/<program-name>"
        return 1
    fi
    
    local prog="$FILC_BUILD_DIR/$1"
    shift
    
    if [ ! -f "$prog" ]; then
        echo "Error: $prog not found"
        echo "Available programs in $FILC_BUILD_DIR:"
        local file found=0
        for file in "$FILC_BUILD_DIR"/*; do
            if [ -f "$file" ] && [ -x "$file" ]; then
                echo "  ${file##*/}"
                found=1
            fi
        done
        [ "$found" -eq 1 ] || echo "  (none)"
        return 1
    fi
    
    "$prog" "$@"
    local exitcode=$?
    echo "==> Exit code: $exitcode"
    return $exitcode
}

# Verify a binary is using Fil-C
filc-verify() {
    if [ $# -eq 0 ]; then
        echo "Usage: filc-verify <binary>"
        return 1
    fi
    
    if ! command -v readelf >/dev/null 2>&1; then
        echo "Error: readelf is not installed"
        return 1
    fi

    local prog="$1"
    
    # If just a name is given, check in build dir first
    if [ ! -f "$prog" ] && [ -f "$FILC_BUILD_DIR/$prog" ]; then
        prog="$FILC_BUILD_DIR/$prog"
    fi
    
    if [ ! -f "$prog" ]; then
        echo "Error: $prog not found"
        return 1
    fi
    
    local interpreter
    interpreter=$(readelf -l "$prog" 2>/dev/null | grep 'program interpreter' || true)
    if [ -z "$interpreter" ]; then
        echo "==> Not a dynamically linked binary: $prog"
        return 1
    fi
    if ! printf '%s\n' "$interpreter" | grep -Eq 'ld-fil1|ld-yolo'; then
        echo "==> Not a Fil-C binary: $interpreter"
        return 1
    fi

    echo "==> Checking interpreter:"
    echo "$interpreter"
    echo ""
    echo "==> Checking Fil-C runtime libraries:"
    local libraries
    libraries=$(ldd "$prog" 2>/dev/null | grep -E 'libpizlo|yolocimpl|yolomimpl|libc\.so\.6666' || true)
    if [ -z "$libraries" ] || printf '%s\n' "$libraries" | grep -q 'not found'; then
        libraries=$(LD_LIBRARY_PATH=/opt/fil/lib ldd "$prog" 2>/dev/null | grep -E 'libpizlo|yolocimpl|yolomimpl|libc\.so\.6666' || true)
    fi
    if [ -n "$libraries" ]; then
        printf '%s\n' "$libraries"
    else
        echo "  (ldd could not resolve the Fil-C libraries)"
    fi
}

# List all built programs
filc-list() {
    echo "==> Programs in $FILC_BUILD_DIR:"
    local file found=0
    for file in "$FILC_BUILD_DIR"/*; do
        if [ -f "$file" ] && [ -x "$file" ]; then
            printf '  %-32s %s bytes\n' "${file##*/}" "$(stat -c %s "$file")"
            found=1
        fi
    done
    [ "$found" -eq 1 ] || echo "  (none)"
}

# Clean build directory
filc-clean() {
    echo "==> Cleaning $FILC_BUILD_DIR..."
    find "$FILC_BUILD_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    echo "Done. Build directory cleaned."
}

# Compile and run all programs in src/filc, then report a summary.
# Exit status 133 (Fil-C safety panic) is expected for the bug demos.
filc-test-all() {
    echo "==> Testing all programs in src/filc..."
    local src_dir="${1:-./src/filc}"
    
    if [ ! -d "$src_dir" ]; then
        echo "Error: $src_dir not found"
        return 1
    fi

    local total=0 clean=0 panics=0 failures=0
    local src name out rc
    
    for src in "$src_dir"/*.c "$src_dir"/*.cpp; do
        [ -f "$src" ] || continue
        name="${src##*/}"
        out="$FILC_BUILD_DIR/${name%.*}"
        total=$((total + 1))
        echo ""
        echo "======================================"
        echo "Testing: $name"
        echo "======================================"

        case "$src" in
            *.cpp)
                if ! fil++ -O0 -fno-builtin -fno-inline "$src" -o "$out"; then
                    echo "==> Compilation failed"
                    failures=$((failures + 1))
                    continue
                fi
                ;;
            *)
                if ! filcc -O0 -fno-builtin -fno-inline "$src" -o "$out"; then
                    echo "==> Compilation failed"
                    failures=$((failures + 1))
                    continue
                fi
                ;;
        esac

        "$out"
        rc=$?
        if [ "$rc" -eq 133 ]; then
            panics=$((panics + 1))
        elif [ "$rc" -eq 0 ]; then
            clean=$((clean + 1))
        else
            failures=$((failures + 1))
        fi
        echo "==> Exit code: $rc"
    done
    
    if [ "$total" -eq 0 ]; then
        echo "Error: no .c or .cpp files found in $src_dir"
        return 1
    fi

    echo ""
    echo "==> Summary: $total programs, $clean clean exits, $panics safety panics, $failures failures"
    [ "$failures" -eq 0 ]
}
