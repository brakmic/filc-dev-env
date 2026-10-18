# Fil-C Development Environment

A ready-to-use development environment for [Fil-C](https://fil-c.org/), a memory-safe C/C++ implementation that catches all memory safety errors at runtime.

## What This Repo Provides

- **Pre-configured shell environment** with convenience aliases and functions
- **Organized directory structure** for clean source/build separation
- **Test programs** demonstrating various memory safety violations
- **Automated test suite** for the demo programs and workflow functions
- **Documentation** for setup and workflows

## Quick Start

### Prerequisites

- **OS**: Linux x86_64 or aarch64 (x86_64 tested on WSL2 Ubuntu 24.04 and 26.04; aarch64 is supported but experimental)
- **Shell**: Bash
- **Sudo access** for installing Fil-C to `/opt/fil`

### Installation

```bash
# Clone the repository
git clone https://github.com/brakmic/filc-dev-env.git
cd filc-dev-env

# Run the automated setup script
./setup.sh
```

The `setup.sh` script will:

1. Check for required system dependencies and optionally install them
2. Create `~/build` and `~/bin`
3. Install the workflow functions to `~/.filc_aliases` and source them from `~/.bashrc` (your `~/.bash_aliases` is left untouched)
4. Download and install Fil-C 0.686 to `/opt/fil` (checksum verified; an existing installation is backed up)
5. Configure PATH and the dynamic loader
6. Verify the installation and print the next steps

Use `./setup.sh --help` for the non-interactive options (`--yes`, `--no-deps`, `--no-install`).

After setup completes:

```bash
source ~/.bashrc
filcc --version
filcc-run src/filc/hello.c
```

### Upgrading an Existing Checkout

If you cloned this repository before the LF line-ending rules were added, the Windows worktree may still contain CRLF files. Refresh it with:

```bash
git rm --cached -r .
git reset --hard
```

This discards uncommitted changes, so commit or stash them first. Alternatively, clone the repository again.

### Manual Installation

If you prefer to install manually, follow the detailed guide in [`doc/fil-c.md`](doc/fil-c.md):

```bash
# Install dependencies
sudo apt update && sudo apt install -y \
  curl ca-certificates wget xz-utils \
  build-essential binutils file \
  git pkg-config gdb strace

# Download and install Fil-C 0.686
mkdir -p downloads/optfil-work
cd downloads
curl -L -O https://github.com/pizlonator/fil-c/releases/download/v0.686/optfil-0.686-linux-x86_64.tar.xz
tar -C optfil-work -xf optfil-0.686-linux-x86_64.tar.xz
cd optfil-work/optfil-0.686-linux-x86_64
sudo ./setup.sh          # type YES when prompted, or use -u for unattended mode

# Configure PATH and loader
grep -q '/opt/fil/bin' ~/.bashrc || echo 'export PATH=/opt/fil/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
echo '/opt/fil/lib' | sudo tee /etc/ld.so.conf.d/filc.conf
sudo ldconfig
```

The manual path installs Fil-C only. Run `./setup.sh --no-install --no-deps` afterwards to install the workflow functions, or source `.bash_aliases` directly.

### Verifying Installation

```bash
# Verify Fil-C is installed
filcc --version
# Expected: clang version 20.1.8 (Fil-C 0.686 ...)

# Quick test - should trigger a memory safety panic
filcc-run src/filc/uaf.c
# Expected: "filc safety error" and exit code 133

# Test all demo programs
filc-test-all
```

## What Gets Installed

The setup script installs:

- **Fil-C 0.686** to `/opt/fil` (compiler, runtime libraries, loader)
- **Workflow functions** in `~/.filc_aliases` (filcc-run, filcc-build, etc.)
- **Test programs** demonstrating memory safety bugs
- **Documentation** for development workflows

Download size: ~265 MB. Installed size: ~1.5 GB in `/opt/fil`.

## Directory Structure

```text
filc-dev-env/
├── .bash_aliases       # Fil-C workflow functions and aliases
├── .gitattributes      # Forces LF line endings for WSL/Linux
├── src/
│   └── filc/           # Test programs demonstrating memory safety bugs
│       ├── hello.c     # Positive control (exits 0)
│       ├── uaf.c       # Use-after-free
│       ├── double_free.c    # Double free
│       ├── type_confusion.c # Incompatible object layout
│       ├── oob.c       # Stack buffer overflow
│       ├── heap_oob.c  # Small heap overflow
│       ├── heap_oob_big.c   # Large heap overflow
│       ├── heap_oob_neg.c   # Negative offset OOB
│       ├── write_bad.c      # Invalid syscall buffer
│       └── cpp_oob.cpp      # C++ with safety violation
├── tests/
│   └── run-tests.sh    # Automated test suite
├── doc/
│   └── fil-c.md        # Detailed Fil-C installation guide
├── setup.sh            # Automated setup script
├── WORKFLOW.md         # Development workflow reference
└── README.md           # This file
```

Compiled binaries go to `~/build` (or `$FILC_BUILD_DIR`), not into the repository.

## Available Commands

### Compile and Run (one step)

```bash
filcc-run src/filc/uaf.c          # Compile and run a C program
filcpp-run src/filc/cpp_oob.cpp   # Compile and run a C++ program
```

### Build Only

```bash
filcc-build src/filc/test.c       # Output: ~/build/test
filcpp-build src/filc/test.cpp    # Output: ~/build/test
```

### Execute Pre-Built Programs

```bash
filc-exec uaf                     # Run ~/build/uaf
filc-list                         # Show all built programs
```

### Project Management

```bash
filc-clean                        # Delete all binaries in ~/build
filc-verify uaf                   # Verify a binary uses Fil-C
filc-test-all                     # Compile and run all programs in src/filc
```

See [`WORKFLOW.md`](WORKFLOW.md) for detailed usage examples.

## Testing

Run the automated suite from the repository root:

```bash
./tests/run-tests.sh
```

Each demo declares its expected outcome with a `// EXPECT: success` or `// EXPECT: panic` marker. The runner asserts exit code 133 and a `filc safety error` for panic demos, checks that binaries use the Fil-C loader, and exercises the workflow functions and the `setup.sh` sandbox.

The suite requires `filcc` and `fil++` in `PATH` (for example after `source ~/.bashrc`, or with `/opt/fil/bin` prepended manually).

## What Fil-C Catches

The demos in `src/filc/` exercise several classes of memory safety errors that Fil-C catches at runtime:

- ✅ **Out-of-bounds access** (heap and stack)
- ✅ **Use-after-free**
- ✅ **Double free**
- ✅ **Type confusion** between incompatible object layouts
- ✅ **Invalid system call buffers**

Fil-C also catches pointer races and other violations that are difficult to demonstrate deterministically.

`hello.c` is a positive control and exits with status 0. Every other demo panics with `filc safety error` and exit code 133.

> **Allocation granularity:** Fil-C rounds every allocation up to 16 bytes. An access that stays inside the rounded allocation (for example `a[2]` on a one-element `int` array) is not detected. The demos therefore use offsets beyond that boundary.

## Key Features of This Environment

### Clean Build Separation

- Sources in `src/filc/`
- Binaries in `~/build` or `$FILC_BUILD_DIR` (automatically managed)
- Home directory stays clean

### Demo-Safe Compilation

All functions automatically use flags that prevent compiler optimizations from hiding bugs:

- `-O0` - No optimization
- `-fno-builtin` - No builtin function optimizations
- `-fno-inline` - No function inlining

### Professional Workflow

- Batch testing with `filc-test-all`
- Easy verification with `filc-verify`
- Consistent build output management
- Clear progress messages
- Automated tests in `tests/run-tests.sh`

## Requirements

- **OS**: Linux x86_64 or aarch64 (x86_64 tested on WSL2 Ubuntu 24.04 and 26.04; aarch64 is supported but experimental)
- **Fil-C**: Version 0.686 or later
- **Shell**: Bash (functions defined in `.bash_aliases` and installed as `~/.filc_aliases`)

## Documentation

- [`doc/fil-c.md`](doc/fil-c.md) - Complete Fil-C installation guide
- [`WORKFLOW.md`](WORKFLOW.md) - Detailed workflow examples
- [Fil-C Official Website](https://fil-c.org/)
- [Fil-C GitHub](https://github.com/pizlonator/fil-c)

## Customization

### Adding Your Own Test Programs

```bash
# Create a new test
vim src/filc/my_test.c

# Compile and run
filcc-run src/filc/my_test.c

# Or just build it
filcc-build src/filc/my_test.c
```

Add a `// EXPECT: success` or `// EXPECT: panic` marker so `tests/run-tests.sh` can check the result.

### Modifying Aliases

Edit `~/.filc_aliases` and reload:

```bash
vim ~/.filc_aliases
source ~/.filc_aliases
```

## Contributing

This is a personal development environment setup, but feel free to:

- Fork and adapt to your needs
- Submit issues for bugs or improvements
- Share your own Fil-C test programs

## License

The environment configuration and test programs are provided as-is for educational purposes.

Fil-C itself is licensed separately:

- Compiler (LLVM/clang): LLVM License
- Runtime: PAS License
- See Fil-C distribution for full license details

## Acknowledgments

- [Fil-C Project](https://fil-c.org/) by Filip Pizlo
- Based on clang 20.1.8 and LLVM infrastructure

---

**Note**: This repository contains configuration files and test programs only. You need to install Fil-C separately following the instructions in [`doc/fil-c.md`](doc/fil-c.md).
