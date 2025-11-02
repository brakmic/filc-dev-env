# Fil-C Development Workflow

## Directory Structure

```
filc-dev-env/
├── src/filc/          # C/C++ source files
├── build/             # Compiled binaries
├── bin/               # Optional scripts/tools
└── doc/               # Documentation
```

Source files in `src/`, binaries in `build/`.

## Commands

### Compile and Run (one step)
```bash
filcc-run src/filc/uaf.c              # Compile + run C program
filcpp-run src/filc/cpp_oob.cpp       # Compile + run C++ program
```

### Build Only (no execution)
```bash
filcc-build src/filc/heap_oob.c       # Builds to ~/build/heap_oob
filcpp-build src/filc/myprogram.cpp   # Builds to ~/build/myprogram
```

### Execute Pre-Built Programs
```bash
filc-exec uaf                         # Runs ~/build/uaf
filc-exec heap_oob_big                # Runs ~/build/heap_oob_big
```

### Project Management
```bash
filc-list                             # Show all built programs
filc-clean                            # Delete all binaries in ~/build
filc-verify uaf                       # Check if binary uses Fil-C
filc-test-all                         # Compile and test all programs in src/filc
```

## Manual Compilation (with aliases)

If you need more control:
```bash
filcc-demo src/filc/test.c -o build/test      # With demo flags
filcc-debug src/filc/test.c -o build/test     # With debug symbols
filcpp-demo src/filc/test.cpp -o build/test   # C++ with demo flags
```

## Typical Development Session

```bash
# Write code in src/filc/
vim src/filc/mynewtest.c

# Quick test it
filcc-run src/filc/mynewtest.c

# If you need to debug
filcc-build src/filc/mynewtest.c -g
gdb $FILC_BUILD_DIR/mynewtest

# Run again without recompiling
filc-exec mynewtest

# Clean up when done
filc-clean
```

## Testing All Programs

```bash
# Test everything in src/filc/
filc-test-all
```

All programs should trigger Fil-C safety panics.

## Notes

Environment variables `FILC_BUILD_DIR` and `FILC_BIN_DIR` default to `$HOME/build` and `$HOME/bin`.

All functions use `-O0 -fno-builtin -fno-inline` by default. Pass additional flags as needed: `filcc-build src/test.c -DDEBUG -lm`
