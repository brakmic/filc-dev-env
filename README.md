# Fil-C Development Environment

A ready-to-use development environment for [Fil-C](https://fil-c.org/), a memory-safe C/C++ implementation that catches all memory safety errors at runtime.

## What This Repo Provides

- **Pre-configured shell environment** with convenience aliases and functions
- **Organized directory structure** for clean source/build separation  
- **Test programs** demonstrating various memory safety violations
- **Documentation** for setup and workflows
- **Professional build tooling** for Fil-C development

## Quick Start

### Prerequisites

- **OS**: Linux x86_64 (tested on WSL2 Ubuntu 24.04)
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
1. Install required system dependencies (curl, build-essential, gdb, etc.)
2. Create the directory structure (`build/`, `src/filc/`, `doc/`)
3. Install Fil-C workflow aliases to `~/.bash_aliases`
4. Download and install Fil-C 0.673 to `/opt/fil`
5. Configure PATH and dynamic loader
6. Copy all test programs and documentation

After setup completes:
```bash
source ~/.bashrc
filcc --version
filcc-run src/filc/hello.c
```

### Manual Installation

If you prefer to install manually, follow the detailed guide in [`doc/fil-c.md`](doc/fil-c.md):

```bash
# Install dependencies
sudo apt update && sudo apt install -y \
  curl ca-certificates wget xz-utils \
  build-essential binutils file \
  git pkg-config gdb strace

# Download and install Fil-C 0.673
mkdir -p downloads/optfil-work
cd downloads
curl -L -O https://github.com/pizlonator/fil-c/releases/download/v0.673/optfil-0.673-linux-x86_64.tar.xz
tar -C optfil-work -xf optfil-0.673-linux-x86_64.tar.xz
cd optfil-work/optfil-0.673-linux-x86_64
sudo ./setup.sh

# Configure PATH and loader
grep -q '/opt/fil/bin' ~/.bashrc || echo 'export PATH=/opt/fil/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
echo '/opt/fil/lib' | sudo tee /etc/ld.so.conf.d/filc.conf
sudo ldconfig
```

### Verifying Installation

```bash
# Verify Fil-C is installed
filcc --version
# Expected: Fil-C 0.673 clang version 20.x.x

# Quick test - should trigger a memory safety panic
filcc-run src/filc/uaf.c
# Expected: "filc safety error" and exit code 133

# Test all demo programs
filc-test-all
```

## What Gets Installed

The setup script installs:
- **Fil-C 0.673** to `/opt/fil` (compiler, runtime libraries, loader)
- **Workflow functions** in `~/.bash_aliases` (filcc-run, filcc-build, etc.)
- **Test programs** demonstrating memory safety bugs
- **Documentation** for development workflows

Download size: ~150MB  
Installed size: ~500MB in `/opt/fil`

## Directory Structure

```
filc-dev-env/
├── .bash_aliases       # Fil-C workflow functions and aliases
├── src/
│   └── filc/          # Test programs demonstrating memory safety bugs
│       ├── hello.c
│       ├── uaf.c              # Use-after-free
│       ├── oob.c              # Stack buffer overflow
│       ├── heap_oob.c         # Small heap overflow
        ├── heap_oob_big.c     # Large heap overflow
        ├── heap_oob_neg.c     # Negative offset OOB
        ├── write_bad.c        # Invalid syscall buffer
        └── cpp_oob.cpp        # C++ with safety violation
├── build/             # Compiled binaries (auto-created, not in git)
├── doc/
│   └── fil-c.md       # Detailed Fil-C installation guide
├── setup.sh           # Automated setup script
├── WORKFLOW.md        # Development workflow reference
└── README.md          # This file
```

## Available Commands

### Compile & Run (one step)
```bash
filcc-run src/filc/uaf.c          # Compile + run C program
filcpp-run src/filc/cpp_oob.cpp   # Compile + run C++ program
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
filc-verify uaf                   # Verify binary uses Fil-C
filc-test-all                     # Test all programs in src/filc
```

See [`WORKFLOW.md`](WORKFLOW.md) for detailed usage examples.

## What Fil-C Catches

All test programs in `src/filc/` demonstrate real memory safety bugs that Fil-C catches at runtime:

- ✅ **Out-of-bounds access** (heap and stack)
- ✅ **Use-after-free**
- ✅ **Type confusion** between pointers and non-pointers
- ✅ **Invalid system call buffers**
- ✅ **Pointer races**
- ✅ **And more...**

Expected behavior: All test programs should panic with "filc safety error" and exit code 133.

## Key Features of This Environment

### Clean Build Separation
- Sources in `src/filc/`
- Binaries in `build/` (automatically managed)
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

## Requirements

- **OS**: Linux x86_64 (tested on WSL2 Ubuntu 24.04)
- **Fil-C**: Version 0.673 or later
- **Shell**: Bash (functions defined in `.bash_aliases`)

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

### Modifying Aliases

Edit `~/.bash_aliases` and reload:
```bash
vim ~/.bash_aliases
source ~/.bash_aliases
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
