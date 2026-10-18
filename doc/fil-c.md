# Fil-C Manual Installation Guide

> Complete step-by-step manual installation for WSL2 Ubuntu 24.04+ (tested on 26.04)

This guide shows you how to manually install and configure Fil-C without using the automated `setup.sh` script. If you prefer automation, run `./setup.sh` from the repository root instead.

---

## 1) System Preparations

Install required dependencies:

```bash
sudo apt update
sudo apt upgrade -y

# Required tools for download, extraction, compilation, and debugging
sudo apt install -y \
  curl ca-certificates wget xz-utils \
  build-essential binutils file \
  git pkg-config \
  gdb strace
```

**What these packages do:**

* `curl`, `wget`, `xz-utils` → Download and extract the Fil-C bundle
* `build-essential`, `binutils` → Compile and link your code with Fil-C
* `file`, `readelf` (part of binutils) → Verify binaries use Fil-C
* `gdb`, `strace` → Debug programs and trace system calls
* `git`, `pkg-config` → Development tools

---

## 2) Download the Precompiled Fil-C Bundle

**2.1** Create working directory and download:

```bash
mkdir -p ~/downloads/optfil-work
cd ~/downloads
curl -L -O https://github.com/pizlonator/fil-c/releases/download/v0.686/optfil-0.686-linux-x86_64.tar.xz
```

Download size: ~265 MB for x86_64, ~236 MB for aarch64.

For ARM64, replace the archive name with `optfil-0.686-linux-aarch64.tar.xz`. The ARM64 `/opt/fil` distribution is experimental.

**2.2** Extract the archive:

```bash
tar -C ~/downloads/optfil-work -xf optfil-0.686-linux-x86_64.tar.xz
cd ~/downloads/optfil-work/optfil-0.686-linux-x86_64
ls -l
```

You should see: `setup.sh`, `fil.tar.xz`, `README.md`, and several license files.

**2.3** Install Fil-C to `/opt/fil`:

The included `setup.sh` extracts `fil.tar.xz` to `/opt`, which creates `/opt/fil`. You can do this manually:

```bash
# Create /opt if needed and extract the Fil-C distribution
sudo mkdir -p /opt
sudo tar -C /opt -xf fil.tar.xz

# Verify installation
ls -l /opt/fil
```

You should see directories: `bin/`, `lib/`, `include/`, `share/`, etc.

> The archive contains a top-level `fil/` directory, so extracting it into `/opt/fil` would create `/opt/fil/fil/`.

**Alternative:** Run the included installer if you prefer:

```bash
sudo ./setup.sh
# When prompted, type: YES
# Use sudo ./setup.sh -u for unattended mode (declines optional SSH/systemd setup)
```

If `/opt/fil` already exists, move it out of the way first:

```bash
sudo mv /opt/fil /opt/fil.backup-$(date +%Y%m%d-%H%M%S)
sudo ./setup.sh
```

---

## 3) Configure Your Environment

**3.1** Add Fil-C binaries to your `PATH`:

```bash
# Open bashrc in your editor
nano ~/.bashrc
```

Add this line at the end:

```bash
export PATH=/opt/fil/bin:$PATH
```

Save the file (Ctrl+O, Enter, Ctrl+X in nano), then reload:

```bash
source ~/.bashrc
```

Verify it works:

```bash
which filcc
# Expected: /opt/fil/bin/filcc

filcc --version
# Expected: clang version 20.1.8 (Fil-C 0.686 ...)
```

**3.2** Do not add `/opt/fil/lib` to the system loader configuration:

Fil-C programs use `/opt/fil/lib/ld-fil1-x86_64.so` and find their runtime libraries automatically. Adding `/opt/fil/lib` to `/etc/ld.so.conf.d` makes system programs load Fil-C builds of common libraries such as `libpcre2` and `libssl`, which can break tools like `grep`.

For diagnostics, resolve the libraries explicitly:

```bash
LD_LIBRARY_PATH=/opt/fil/lib ldd ~/build/test
```

**3.3** Set up build directory:

```bash
# Create directory for compiled binaries
mkdir -p ~/build

# Optionally add environment variable for convenience
echo 'export FILC_BUILD_DIR=$HOME/build' >> ~/.bashrc
source ~/.bashrc
```

**3.4 (Optional)** Make `clang`/`clang++` use Fil-C by default:

```bash
echo 'alias clang=/opt/fil/bin/filcc' >> ~/.bashrc
echo 'alias clang++=/opt/fil/bin/fil++' >> ~/.bashrc
source ~/.bashrc
```

> Note: System compilers remain available at `/usr/bin/clang` and `/usr/bin/gcc`.

---

## 4) Verify Installation

**4.1** Check compiler version:

```bash
filcc --version
```

Expected output:

```text
clang version 20.1.8 (Fil-C 0.686 ...)
Target: x86_64-unknown-linux-gnu
Thread model: posix
InstalledDir: /opt/fil/bin
```

**4.2** Create a test program:

```bash
cat > ~/build/test.c <<'EOF'
int main() {
    int arr[10];
    arr[100] = 42;  // Far out of bounds - should trigger Fil-C panic
    return 0;
}
EOF
```

**4.3** Compile the test:

```bash
filcc -O0 -g ~/build/test.c -o ~/build/test
```

**4.4** Verify the binary uses Fil-C:

```bash
# Check the interpreter (must be Fil-C's loader)
readelf -l ~/build/test | grep 'program interpreter'
# Expected: /opt/fil/lib/ld-fil1-x86_64.so

# Check runtime library dependencies (must come from /opt/fil/lib)
LD_LIBRARY_PATH=/opt/fil/lib ldd ~/build/test | grep -E 'libpizlo|yolocimpl|yolomimpl|libc.so.6666'
```

Expected output:

```text
libpizlo.so => /opt/fil/lib/libpizlo.so
libyolocimpl.so => /opt/fil/lib/libyolocimpl.so
libyolomimpl.so => /opt/fil/lib/libyolomimpl.so
libc.so.6666 => /opt/fil/lib/libc.so.6666
```

**4.5** Run the test and verify it panics:

```bash
~/build/test
echo $?
```

Expected:

```text
filc safety error: ...
Exit code: 133
```

If you see the panic message and non-zero exit, **Fil-C is working correctly!**

---

## 5) Test Programs Demonstrating Memory Safety Bugs

> **Important:** Always compile test programs with `-O0` to prevent the compiler from optimizing away the bugs. Use `volatile` for pointer variables to ensure memory accesses actually happen.
>
> **Allocation granularity:** Fil-C rounds every allocation up to 16 bytes. An access that stays inside the rounded allocation is not detected. The examples below use offsets beyond that boundary.

### 5.1 Use-After-Free (Highly Reliable)

```bash
cat > ~/build/uaf.c <<'EOF'
#include <stdlib.h>
int main() {
    volatile int *p = (int*)malloc(8);
    free((void*)p);
    *p = 1;  // Use after free - Fil-C will catch this
    return 0;
}
EOF

filcc -O0 -fno-builtin -fno-inline ~/build/uaf.c -o ~/build/uaf
~/build/uaf
echo $?
# Expected: "filc safety error" + exit code 133
```

### 5.2 Invalid System Call Buffer

```bash
cat > ~/build/write_bad.c <<'EOF'
#include <unistd.h>
int main() {
    char *invalid_ptr = (char*)0x1;  // Invalid address
    return (int)write(1, invalid_ptr, 1);  // Fil-C catches bad syscall buffer
}
EOF

filcc -O0 ~/build/write_bad.c -o ~/build/write_bad
~/build/write_bad
echo $?
# Expected: "filc safety error" + exit code 133
```

### 5.3 Heap Out-of-Bounds (Large Offset)

Fil-C rounds allocations up to 16 bytes, so small overflows that stay inside the rounded allocation are not detected. Use offsets beyond the rounded size (4096+ bytes is a safe choice):

```bash
cat > ~/build/heap_oob_big.c <<'EOF'
#include <stdlib.h>
int main() {
    volatile char *p = (char*)malloc(1);
    p[4096] = 7;  // Way out of bounds
    return 0;
}
EOF

filcc -O0 ~/build/heap_oob_big.c -o ~/build/heap_oob_big
~/build/heap_oob_big
echo $?
# Expected: "filc safety error" + exit code 133
```

### 5.4 Negative Index Out-of-Bounds

```bash
cat > ~/build/heap_oob_neg.c <<'EOF'
#include <stdlib.h>
int main() {
    volatile char *p = (char*)malloc(8);
    volatile char x = p[-1];  // Reading before allocated memory
    return (int)x;
}
EOF

filcc -O0 ~/build/heap_oob_neg.c -o ~/build/heap_oob_neg  
~/build/heap_oob_neg
echo $?
# Expected: "filc safety error" + exit code 133
```

### 5.5 Stack Buffer Overflow

```bash
cat > ~/build/stack_oob.c <<'EOF'
int main() {
    volatile int arr[10];
    arr[16] = 42;  // Beyond the rounded 48-byte allocation
    return 0;
}
EOF

filcc -O0 ~/build/stack_oob.c -o ~/build/stack_oob
~/build/stack_oob
echo $?
# Expected: "filc safety error" + exit code 133
```

### 5.6 Small Heap Overflow (Not Detected)

```bash
cat > ~/build/heap_oob_small.c <<'EOF'
#include <stdlib.h>
int main() {
    volatile char *p = (char*)malloc(4);
    p[8] = 42;  // Inside the rounded 16-byte allocation
    return 0;
}
EOF

filcc -O0 ~/build/heap_oob_small.c -o ~/build/heap_oob_small
~/build/heap_oob_small
echo $?
# Expected: no panic; the write stays inside the rounded allocation
```

An access at `p[16]` or beyond would panic. Use offsets beyond the rounded size in tests that must be detected.

---

## 6) Usage Notes

### Compiler Usage

* **Drop-in replacement:** Use `filcc` and `fil++` exactly like `clang` and `clang++`
* **Don't mix toolchains:** Always compile AND link with Fil-C for memory-safe binaries
* **No `-rpath` needed:** The Fil-C loader finds `/opt/fil/lib` automatically

### Build Flags

* **For demos:** Use `-O0 -fno-builtin -fno-inline` to prevent optimization
* **For production:** You can use `-O2` or `-O3`, but memory safety checks remain active
* **Debug builds:** Add `-g` for symbols: `filcc -O0 -g program.c`

### File Paths

* **Use Linux paths:** Build under `$HOME`, not `/mnt/c/` (NTFS has performance issues)
* **Output location:** Put binaries in `~/build/` to keep home directory clean

### Performance

* **Normal execution:** Near-clang performance for memory-safe code
* **On violations:** Fil-C panics immediately instead of invoking undefined behavior
* **No overhead:** Memory safety doesn't require runtime flags

---

## 7) Troubleshooting

### Program Runs But Doesn't Panic

**Symptom:** A program with an obvious bug runs without panicking.

**Diagnosis:**

```bash
# Check if it's actually a Fil-C binary
readelf -l ./program | grep 'program interpreter'
# Must show: /opt/fil/lib/ld-fil1-x86_64.so

LD_LIBRARY_PATH=/opt/fil/lib ldd ./program | grep -E 'libpizlo|yolocimpl|yolomimpl'
# Must show libraries from /opt/fil/lib
```

**Solutions:**

* If wrong interpreter: You compiled with system `clang`, use `filcc` instead
* If libraries missing: Confirm the binary uses Fil-C's loader; the loader finds `/opt/fil/lib` automatically
* For small OOB: Use larger offsets (4096+) or negative indices
* For optimized code: Rebuild with `-O0 -fno-builtin -fno-inline`
* Add `volatile` to pointer variables

### Cannot Find Fil-C Libraries

**Symptom:** `error while loading shared libraries: libpizlo.so`

**Solution:**

Check that the binary uses the Fil-C loader:

```bash
readelf -l ./program | grep 'program interpreter'
# Must show: /opt/fil/lib/ld-fil1-x86_64.so
```

If the loader is correct, Fil-C finds its own libraries. Do not add `/opt/fil/lib` to the system loader configuration.

**Diagnostic workaround:**

```bash
LD_LIBRARY_PATH=/opt/fil/lib ./program
```

### ldd Shows "not found" for ld-fil1-x86_64.so

**This is normal.** The `ldd` tool uses the system loader, which does not know Fil-C's search path. The kernel loads the Fil-C loader via `PT_INTERP`, and that loader finds `/opt/fil/lib` on its own. Use `LD_LIBRARY_PATH=/opt/fil/lib ldd ./program` for diagnostics; do not add `/opt/fil/lib` to the global loader configuration.

### Compilation Fails with Missing Headers

**Symptom:** `fatal error: 'stdio.h' file not found`

**Solution:** Install build-essential:

```bash
sudo apt install build-essential
```

---

## 8) Optional: Wrapper Script with Embedded RPATH

Fil-C's loader normally finds `/opt/fil/lib` on its own. If you prefer an explicit rpath, for example for tooling that inspects binaries, use a wrapper script:

```bash
mkdir -p ~/bin

cat > ~/bin/filccr <<'EOF'
#!/usr/bin/env bash
exec /opt/fil/bin/filcc -Wl,-rpath,/opt/fil/lib "$@"
EOF

chmod +x ~/bin/filccr

# Add to PATH if needed
grep -q "$HOME/bin" <<< "$PATH" || echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Usage:
filccr program.c -o program
./program
```

**Note:** The wrapper is optional; Fil-C's loader normally handles the library path.

---

## 9) Next Steps

Test Fil-C with your own programs:

```bash
vim ~/build/mytest.c
filcc -O0 ~/build/mytest.c -o ~/build/mytest
~/build/mytest
```

Try compiling larger projects, multithreaded programs, or C++ code with `fil++`.

To run the repository demo suite:

```bash
cd /path/to/filc-dev-env
./tests/run-tests.sh
```

---

## 10) Uninstalling Fil-C

Remove Fil-C installation:

```bash
# Remove binaries and libraries
sudo rm -rf /opt/fil

# Remove old loader configuration if present; it can break system tools
sudo rm -f /etc/ld.so.conf.d/filc.conf
sudo ldconfig

# Remove PATH configuration and the aliases block
nano ~/.bashrc
# Delete: export PATH=/opt/fil/bin:$PATH
# Delete the block between "# >>> Fil-C workflow aliases >>>" and "# <<< Fil-C workflow aliases <<<"
source ~/.bashrc

# Remove the workflow functions
rm -f ~/.filc_aliases

# Remove downloads
rm -rf ~/downloads/optfil-work
rm -f ~/downloads/optfil-*.tar.xz
```

---

## References

* [Fil-C website](https://fil-c.org/)
* [Fil-C GitHub repository](https://github.com/pizlonator/fil-c)
* [Fil-C releases](https://github.com/pizlonator/fil-c/releases)
