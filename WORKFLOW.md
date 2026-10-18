# Fil-C Development Workflow

## Directory Structure

```text
filc-dev-env/
├── src/filc/          # C/C++ demo sources
├── tests/             # Automated test suite
├── doc/               # Documentation
└── setup.sh           # Environment setup
```

Source files stay in `src/filc/`. Compiled binaries go to `~/build` (`$FILC_BUILD_DIR`), and helper scripts can go to `~/bin` (`$FILC_BIN_DIR`). Neither directory is inside the repository.

## Commands

### Compile and Run (one step)

```bash
filcc-run src/filc/uaf.c              # Compile and run a C program
filcpp-run src/filc/cpp_oob.cpp       # Compile and run a C++ program
```

### Build Only (no execution)

```bash
filcc-build src/filc/heap_oob.c       # Builds to $FILC_BUILD_DIR/heap_oob
filcpp-build src/filc/myprogram.cpp   # Builds to $FILC_BUILD_DIR/myprogram
```

### Execute Pre-Built Programs

```bash
filc-exec uaf                         # Runs $FILC_BUILD_DIR/uaf
filc-exec heap_oob_big                # Runs $FILC_BUILD_DIR/heap_oob_big
```

### Project Management

```bash
filc-list                             # Show executable programs in $FILC_BUILD_DIR
filc-clean                            # Delete all files in $FILC_BUILD_DIR
filc-verify uaf                       # Check that a binary uses Fil-C
filc-test-all                         # Compile and run all programs in src/filc
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
gdb "$FILC_BUILD_DIR/mynewtest"

# Run again without recompiling
filc-exec mynewtest

# Clean up when done
filc-clean
```

## Testing All Programs

```bash
# Compile and run everything in src/filc/
filc-test-all
```

`filc-test-all` prints a summary and treats exit code 133 (a Fil-C safety panic) as expected. It returns 0 when there are no compilation or unexpected runtime failures.

For assertions, line-ending checks and workflow-function tests, run:

```bash
./tests/run-tests.sh
```

Each source declares its expectation with `// EXPECT: success` or `// EXPECT: panic`.

> **Note:** Fil-C rounds allocations up to 16 bytes. Small overflows that stay inside the rounded allocation are not detected, so the demos use offsets beyond that boundary.

## Notes

Environment variables `FILC_BUILD_DIR` and `FILC_BIN_DIR` default to `$HOME/build` and `$HOME/bin`.

All functions use `-O0 -fno-builtin -fno-inline` by default. Pass additional flags as needed: `filcc-build src/test.c -DDEBUG -lm`.
