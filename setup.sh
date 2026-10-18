#!/bin/bash
# Fil-C Development Environment Setup Script
# Run this after cloning the repository to set up your environment

set -e

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
FILC_VERSION="${FILC_VERSION:-0.686}"
FILC_ARCH="x86_64"
FILC_DOWNLOAD_DIR="${FILC_DOWNLOAD_DIR:-$HOME/downloads}"
FILC_ASSET="optfil-${FILC_VERSION}-linux-${FILC_ARCH}.tar.xz"
FILC_URL="https://github.com/pizlonator/fil-c/releases/download/v${FILC_VERSION}/${FILC_ASSET}"
# SHA-256 of optfil-0.686-linux-x86_64.tar.xz.
# Set FILC_SHA256 to the matching value when installing a different release,
# or set it to an empty string to skip verification.
FILC_SHA256="${FILC_SHA256:-3a0ba45283ff29668335d288530f35fe69c28ab8d663b4deb8801474825f117a}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ALIASES_SRC="$SCRIPT_DIR/.bash_aliases"
ALIASES_DEST="$HOME/.filc_aliases"
BASHRC="$HOME/.bashrc"
ALIASES_BLOCK_BEGIN="# >>> Fil-C workflow aliases >>>"
ALIASES_BLOCK_END="# <<< Fil-C workflow aliases <<<"

ASSUME_YES=false
SKIP_DEPS=false
SKIP_INSTALL=false

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info() { printf '%b%s%b\n' "$GREEN" "$1" "$NC"; }
warn() { printf '%b%s%b\n' "$YELLOW" "$1" "$NC"; }
error() { printf '%b%s%b\n' "$RED" "$1" "$NC" >&2; }

usage() {
    cat <<EOF
Usage: ./setup.sh [OPTIONS]

Install the Fil-C development environment.

Options:
  -y, --yes          Answer yes to all prompts (non-interactive)
      --no-deps      Do not install system packages
      --no-install   Configure only; do not download or install Fil-C
  -h, --help         Show this help

Environment:
  FILC_VERSION       Fil-C release to install (default: $FILC_VERSION)
  FILC_DOWNLOAD_DIR  Download directory (default: \$HOME/downloads)
  FILC_SHA256        Expected SHA-256 of the release archive
EOF
}

confirm() {
    if [ "$ASSUME_YES" = true ]; then
        return 0
    fi
    local reply
    read -r -p "$1 [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes) ASSUME_YES=true ;;
        --no-deps) SKIP_DEPS=true ;;
        --no-install) SKIP_INSTALL=true ;;
        -h|--help) usage; exit 0 ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

echo "=========================================="
echo "Fil-C Development Environment Setup"
echo "=========================================="
echo ""

# System checks
if [ "$(uname -s)" != "Linux" ]; then
    error "Error: This script only supports Linux."
    exit 1
fi

if [ "$(uname -m)" != "$FILC_ARCH" ]; then
    error "Error: This script requires $FILC_ARCH."
    exit 1
fi

info "✓ System check passed"
echo ""

# Use sudo only when the script is not already running as root.
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Step 1: Dependencies
echo "Step 1: Checking system dependencies..."
if [ "$SKIP_DEPS" = false ]; then
    MISSING_TOOLS=()
    for tool in curl xz tar gcc make gdb strace readelf file pkg-config git; do
        command -v "$tool" >/dev/null 2>&1 || MISSING_TOOLS+=("$tool")
    done

    if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
        echo "Missing tools: ${MISSING_TOOLS[*]}"
        echo "The following packages provide them:"
        echo "  curl ca-certificates wget xz-utils build-essential binutils file git pkg-config gdb strace"
        echo ""
        if confirm "Install system dependencies with apt?"; then
            $SUDO apt-get update
            $SUDO apt-get install -y \
                curl ca-certificates wget xz-utils \
                build-essential binutils file \
                git pkg-config gdb strace
            info "✓ Dependencies installed"
        else
            warn "⚠ Skipping dependency installation"
        fi
    else
        info "✓ All dependencies are already installed"
    fi
else
    echo "Skipping dependency installation (--no-deps)"
fi
echo ""

# Step 2: Create build directory
echo "Step 2: Creating build and bin directories..."
mkdir -p "$HOME/build" "$HOME/bin"
info "✓ Build directory created: ~/build"
info "✓ Bin directory created: ~/bin"
echo ""

# Step 3: Install workflow functions
echo "Step 3: Installing Fil-C workflow functions..."
if [ ! -f "$ALIASES_SRC" ]; then
    error "Error: $ALIASES_SRC not found"
    exit 1
fi
cp "$ALIASES_SRC" "$ALIASES_DEST"
info "✓ Installed $ALIASES_DEST"

touch "$BASHRC"
if ! grep -qF "$ALIASES_BLOCK_BEGIN" "$BASHRC"; then
    {
        echo ""
        echo "$ALIASES_BLOCK_BEGIN"
        echo "if [ -f \"\$HOME/.filc_aliases\" ]; then"
        echo "    . \"\$HOME/.filc_aliases\""
        echo "fi"
        echo "$ALIASES_BLOCK_END"
    } >> "$BASHRC"
    info "✓ Added the Fil-C aliases block to ~/.bashrc"
else
    info "✓ ~/.bashrc already sources the Fil-C aliases"
fi

if [ -f "$HOME/.bash_aliases" ] && grep -qF "Fil-C compiler aliases" "$HOME/.bash_aliases"; then
    warn "⚠ ~/.bash_aliases still contains an older Fil-C copy; it was left untouched."
fi
echo ""

# Step 4: Check for an existing installation
echo "Step 4: Checking Fil-C installation..."
FILC_INSTALLED=false
if [ -x "/opt/fil/bin/filcc" ] && /opt/fil/bin/filcc --version 2>/dev/null | grep -q "Fil-C"; then
    FILC_INSTALLED=true
    info "✓ Fil-C is already installed"
    /opt/fil/bin/filcc --version | head -1
elif [ -e "/opt/fil" ]; then
    warn "⚠ /opt/fil exists but does not contain a working Fil-C compiler"
else
    warn "⚠ Fil-C is not installed in /opt/fil"
    if command -v filcc >/dev/null 2>&1; then
        warn "  A different filcc was found at $(command -v filcc)"
    fi
fi
echo ""

# Step 5: Install Fil-C
if [ "$SKIP_INSTALL" = true ]; then
    echo "Step 5: Skipping Fil-C installation (--no-install)"
elif [ "$FILC_INSTALLED" = true ]; then
    echo "Step 5: Fil-C already installed, skipping"
else
    echo "Step 5: Fil-C $FILC_VERSION installation"
    echo "This will:"
    echo "  - Download ~265 MB from GitHub"
    echo "  - Install about 1.5 GB into /opt/fil (requires sudo)"
    echo "  - Configure PATH and the dynamic loader"
    echo ""

    DO_INSTALL=true
    if ! confirm "Install Fil-C $FILC_VERSION to /opt/fil?"; then
        DO_INSTALL=false
    fi
    if [ "$DO_INSTALL" = true ] && [ -e "/opt/fil" ]; then
        if confirm "Back up /opt/fil and install a fresh copy?"; then
            FILC_BACKUP="/opt/fil.backup.$(date +%Y%m%d-%H%M%S)"
            $SUDO mv /opt/fil "$FILC_BACKUP"
            info "✓ Moved the existing installation to $FILC_BACKUP"
        else
            warn "⚠ Keeping the existing /opt/fil"
            DO_INSTALL=false
        fi
    fi

    if [ "$DO_INSTALL" = true ]; then
        for tool in curl xz tar; do
            if ! command -v "$tool" >/dev/null 2>&1; then
                error "Error: $tool is required to install Fil-C"
                error "Install the dependencies first or rerun without --no-deps"
                exit 1
            fi
        done

        mkdir -p "$FILC_DOWNLOAD_DIR/optfil-work"
        ARCHIVE="$FILC_DOWNLOAD_DIR/$FILC_ASSET"

        if [ -f "$ARCHIVE" ]; then
            echo "Using cached archive: $ARCHIVE"
        else
            echo "Downloading Fil-C $FILC_VERSION..."
            curl -fL --retry 3 -o "$ARCHIVE" "$FILC_URL"
        fi

        if [ -n "$FILC_SHA256" ] && command -v sha256sum >/dev/null 2>&1; then
            ACTUAL_SHA256=$(sha256sum "$ARCHIVE" | cut -d' ' -f1)
            if [ "$ACTUAL_SHA256" != "$FILC_SHA256" ]; then
                error "Error: checksum mismatch for $ARCHIVE"
                error "Expected: $FILC_SHA256"
                error "Actual:   $ACTUAL_SHA256"
                error "Remove the cached archive and try again."
                exit 1
            fi
            info "✓ Checksum verified"
        else
            warn "⚠ Checksum verification skipped"
        fi

        echo "Extracting..."
        tar -C "$FILC_DOWNLOAD_DIR/optfil-work" -xf "$ARCHIVE"
        INSTALLER_DIR="$FILC_DOWNLOAD_DIR/optfil-work/optfil-${FILC_VERSION}-linux-${FILC_ARCH}"
        if [ ! -x "$INSTALLER_DIR/setup.sh" ]; then
            error "Error: installer not found at $INSTALLER_DIR/setup.sh"
            exit 1
        fi

        echo "Running the Fil-C installer in unattended mode..."
        (cd "$INSTALLER_DIR" && $SUDO ./setup.sh -u)
        FILC_INSTALLED=true
        info "✓ Fil-C $FILC_VERSION installed"
    else
        warn "⚠ Skipping Fil-C installation"
        echo "To install later, follow the guide in doc/fil-c.md"
    fi
fi
echo ""

# Step 6: Configure the environment
echo "Step 6: Configuring environment..."
if ! grep -qF "/opt/fil/bin" "$BASHRC"; then
    # shellcheck disable=SC2016
    echo 'export PATH=/opt/fil/bin:$PATH' >> "$BASHRC"
    info "✓ Added /opt/fil/bin to PATH in ~/.bashrc"
else
    info "✓ PATH is already configured in ~/.bashrc"
fi

if [ -d "/opt/fil/lib" ]; then
    if command -v ldconfig >/dev/null 2>&1 && { [ -w /etc/ld.so.conf.d ] || [ -n "$SUDO" ]; }; then
        echo '/opt/fil/lib' | $SUDO tee /etc/ld.so.conf.d/filc.conf >/dev/null
        $SUDO ldconfig
        info "✓ Configured the dynamic loader for /opt/fil/lib"
    else
        warn "⚠ Cannot write /etc/ld.so.conf.d; skipping dynamic loader configuration"
    fi
else
    warn "⚠ /opt/fil/lib not found; skipping dynamic loader configuration"
fi
echo ""

# Step 7: Final verification
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""

if [ -x "/opt/fil/bin/filcc" ] && /opt/fil/bin/filcc --version 2>/dev/null | grep -q "Fil-C"; then
    info "✓ Fil-C is ready to use"
    /opt/fil/bin/filcc --version | head -1
    echo ""
    echo "Test programs are in the repository directory:"
    echo "  src/filc/hello.c      - Basic hello world"
    echo "  src/filc/uaf.c        - Use-after-free test"
    echo "  src/filc/oob.c        - Stack buffer overflow"
    echo "  src/filc/heap_oob*.c  - Heap overflow variants"
    echo "  src/filc/write_bad.c  - Invalid syscall buffer"
    echo "  src/filc/cpp_oob.cpp  - C++ out-of-bounds test"
    echo ""
    echo "Try these commands:"
    echo "  source ~/.bashrc                # Load the workflow functions"
    echo "  filcc-run src/filc/hello.c      # Compile and run hello world"
    echo "  filcc-run src/filc/uaf.c        # Test memory safety detection"
    echo "  ./tests/run-tests.sh            # Run the automated test suite"
else
    warn "⚠ Fil-C is not installed"
    echo "Follow the installation guide in doc/fil-c.md"
fi

echo ""
echo "Documentation:"
echo "  README.md      - Project overview"
echo "  WORKFLOW.md    - Development workflow"
echo "  doc/fil-c.md   - Fil-C installation guide"
echo ""
info "Please run: source ~/.bashrc"
echo "Or open a new terminal to activate the environment."
