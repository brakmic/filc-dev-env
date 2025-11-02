# Fil-C compiler aliases for demo/test programs
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

# Quick compile and run (C) - builds to ~/build, runs from there
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

# Quick compile and run (C++) - builds to ~/build, runs from there
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

# Build without running - outputs to ~/build by default
filcc-build() {
    if [ $# -eq 0 ]; then
        echo "Usage: filcc-build <source.c> [-o output] [additional flags]"
        echo "Default output: ~/build/<basename>"
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

# Build C++ without running - outputs to ~/build by default
filcpp-build() {
    if [ $# -eq 0 ]; then
        echo "Usage: filcpp-build <source.cpp> [-o output] [additional flags]"
        echo "Default output: ~/build/<basename>"
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

# Run a previously built binary from ~/build
filc-exec() {
    if [ $# -eq 0 ]; then
        echo "Usage: filc-exec <program-name>"
        echo "Runs ~/build/<program-name>"
        return 1
    fi
    
    local prog="$FILC_BUILD_DIR/$1"
    shift
    
    if [ ! -f "$prog" ]; then
        echo "Error: $prog not found"
        echo "Available programs in ~/build:"
        ls -1 "$FILC_BUILD_DIR" 2>/dev/null | grep -v '\.'
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
    
    local prog="$1"
    
    # If just a name is given, check in build dir first
    if [ ! -f "$prog" ] && [ -f "$FILC_BUILD_DIR/$prog" ]; then
        prog="$FILC_BUILD_DIR/$prog"
    fi
    
    if [ ! -f "$prog" ]; then
        echo "Error: $prog not found"
        return 1
    fi
    
    echo "==> Checking interpreter:"
    readelf -l "$prog" | grep 'program interpreter'
    echo ""
    echo "==> Checking Fil-C runtime libraries:"
    ldd "$prog" | egrep 'libpizlo|yolocimpl|yolomimpl|libc.so.6666'
}

# List all built programs
filc-list() {
    echo "==> Programs in ~/build:"
    ls -lh "$FILC_BUILD_DIR" 2>/dev/null | grep -v '^total' | grep -v '\.$'
}

# Clean build directory
filc-clean() {
    echo "==> Cleaning ~/build..."
    rm -f "$FILC_BUILD_DIR"/*
    echo "Done. Build directory cleaned."
}

# Quick test all programs in src/filc
filc-test-all() {
    echo "==> Testing all programs in src/filc..."
    local src_dir="${1:-./src/filc}"
    
    if [ ! -d "$src_dir" ]; then
        echo "Error: $src_dir not found"
        return 1
    fi
    
    for src in "$src_dir"/*.c; do
        [ -f "$src" ] || continue
        local basename="${src##*/}"
        echo ""
        echo "======================================"
        echo "Testing: $basename"
        echo "======================================"
        filcc-run "$src"
    done
    
    for src in "$src_dir"/*.cpp; do
        [ -f "$src" ] || continue
        local basename="${src##*/}"
        echo ""
        echo "====================================="
        echo "Testing: $basename"
        echo "====================================="
        filcpp-run "$src"
    done
}
