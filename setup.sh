#!/bin/bash
# Fil-C Development Environment Setup Script
# Run this after cloning the repository to set up your environment

set -e

echo "=========================================="
echo "Fil-C Development Environment Setup"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}Error: This script only supports Linux x86_64${NC}"
    exit 1
fi

# Check architecture
if [[ "$(uname -m)" != "x86_64" ]]; then
    echo -e "${RED}Error: This script requires x86_64 architecture${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} System check passed"
echo ""

# Check if Fil-C is already fully installed and functional
if [ -x "/opt/fil/bin/filcc" ] && [ -f "/opt/fil/lib/libpizlo.so" ]; then
    FILC_VERSION=$(/opt/fil/bin/filcc --version 2>/dev/null | head -1)
    if [ $? -eq 0 ] && [[ "$FILC_VERSION" == *"Fil-C"* ]]; then
        echo -e "${YELLOW}⚠ Fil-C is already installed${NC}"
        echo "  Version: $FILC_VERSION"
        echo "  Location: /opt/fil"
        echo ""
        echo "This script will:"
        echo "  - Skip Fil-C installation"
        echo "  - Update shell configuration and workflow functions"
        echo ""
        read -p "Continue with configuration updates? (y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Setup cancelled."
            exit 0
        fi
        FILC_ALREADY_INSTALLED=true
    else
        FILC_ALREADY_INSTALLED=false
    fi
else
    FILC_ALREADY_INSTALLED=false
fi
echo ""

# Step 1: Install dependencies
echo "Step 1: Installing system dependencies..."
echo "This requires sudo privileges and is needed for Fil-C installation."
echo ""
echo "Required packages:"
echo "  - curl, xz-utils (download/extraction)"
echo "  - build-essential, binutils (compilation tools)"
echo "  - gdb, strace (debugging)"
echo ""
read -p "Install dependencies? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo apt update
    sudo apt install -y \
        curl ca-certificates wget xz-utils \
        build-essential binutils file \
        git pkg-config gdb strace
    echo -e "${GREEN}✓${NC} Dependencies installed"
else
    echo -e "${YELLOW}⚠${NC} Skipping dependency installation"
    echo -e "${RED}Warning: Fil-C installation will fail without curl and xz-utils${NC}"
fi
echo ""

# Step 2: Create build directory
echo "Step 2: Creating build directory..."
mkdir -p "$HOME/build"
echo -e "${GREEN}✓${NC} Build directory created: ~/build/"
echo ""

# Step 3: Install bash aliases
echo "Step 3: Installing Fil-C workflow functions..."
if [ -f ".bash_aliases" ]; then
    cp .bash_aliases ~/.bash_aliases
    echo -e "${GREEN}✓${NC} Installed ~/.bash_aliases"
else
    echo -e "${YELLOW}⚠${NC} .bash_aliases not found in repository"
fi

# Ensure .bashrc sources .bash_aliases
if ! grep -q ".bash_aliases" ~/.bashrc 2>/dev/null; then
    echo "" >> ~/.bashrc
    echo "# Source Fil-C aliases" >> ~/.bashrc
    echo "if [ -f ~/.bash_aliases ]; then" >> ~/.bashrc
    echo "    . ~/.bash_aliases" >> ~/.bashrc
    echo "fi" >> ~/.bashrc
    echo -e "${GREEN}✓${NC} Updated ~/.bashrc to source aliases"
fi
echo ""

echo "Step 4: Checking Fil-C installation..."
if [ "$FILC_ALREADY_INSTALLED" = true ]; then
    echo -e "${GREEN}✓${NC} Fil-C is already installed and functional"
    /opt/fil/bin/filcc --version | head -1
elif command -v filcc &> /dev/null && filcc --version 2>/dev/null | grep -q "Fil-C"; then
    echo -e "${GREEN}✓${NC} Fil-C is already installed"
    filcc --version | head -1
    FILC_ALREADY_INSTALLED=true
else
    echo -e "${YELLOW}⚠${NC} Fil-C is not installed"
    FILC_ALREADY_INSTALLED=false
fi
echo ""

# Step 5: Offer to install Fil-C
if [ "$FILC_ALREADY_INSTALLED" = false ]; then
    echo "Step 5: Fil-C Installation"
    echo "Would you like to install Fil-C 0.673 now?"
    echo "This will:"
    echo "  - Download ~150MB from GitHub"
    echo "  - Install to /opt/fil (requires sudo)"
    echo "  - Configure PATH and dynamic loader"
    read -p "Install Fil-C? (y/n) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Check for required tools
        if ! command -v curl &> /dev/null; then
            echo -e "${RED}Error: curl is not installed${NC}"
            echo "Please install dependencies first (Step 1) or install curl manually:"
            echo "  sudo apt install curl"
            exit 1
        fi
        
        if ! command -v xz &> /dev/null; then
            echo -e "${RED}Error: xz is not installed${NC}"
            echo "Please install dependencies first (Step 1) or install xz-utils manually:"
            echo "  sudo apt install xz-utils"
            exit 1
        fi
        
        echo "Downloading Fil-C..."
        mkdir -p "$HOME/downloads/optfil-work"
        cd "$HOME/downloads"
        
        if [ ! -f "optfil-0.673-linux-x86_64.tar.xz" ]; then
            curl -L -O https://github.com/pizlonator/fil-c/releases/download/v0.673/optfil-0.673-linux-x86_64.tar.xz
        else
            echo "Archive already downloaded, using cached version"
        fi
        
        echo "Extracting..."
        tar -C "$HOME/downloads/optfil-work" -xf optfil-0.673-linux-x86_64.tar.xz
        
        echo "Running installer (requires sudo)..."
        cd "$HOME/downloads/optfil-work/optfil-0.673-linux-x86_64"
        
        if [ -d "/opt/fil" ]; then
            echo -e "${YELLOW}⚠${NC} /opt/fil already exists"
            read -p "Remove and reinstall? (y/n) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo rm -rf /opt/fil
                sudo ./setup.sh
            else
                echo "Skipping Fil-C installation"
            fi
        else
            if ! sudo ./setup.sh; then
                echo -e "${RED}Error: Fil-C installation failed${NC}"
                echo "Check the error messages above and try again."
                exit 1
            fi
        fi
        
        echo "Configuring PATH..."
        if ! grep -q '/opt/fil/bin' ~/.bashrc; then
            echo 'export PATH=/opt/fil/bin:$PATH' >> ~/.bashrc
        fi
        
        echo "Configuring dynamic loader..."
        echo '/opt/fil/lib' | sudo tee /etc/ld.so.conf.d/filc.conf
        sudo ldconfig
        
        export PATH=/opt/fil/bin:$PATH
        
        echo -e "${GREEN}✓${NC} Fil-C installed successfully"
        cd "$HOME"
    else
        echo -e "${YELLOW}⚠${NC} Skipping Fil-C installation"
        echo "To install later, follow the guide in doc/fil-c.md"
    fi
else
    echo "Step 5: Fil-C already installed, skipping"
fi
echo ""

# Step 6: Final verification
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""

if [ -x "/opt/fil/bin/filcc" ] && /opt/fil/bin/filcc --version &>/dev/null; then
    echo -e "${GREEN}✓${NC} Fil-C is ready to use"
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
    echo "  source ~/.bash_aliases         # Load workflow functions"
    echo "  filcc-run src/filc/hello.c     # Compile and run hello world"
    echo "  filcc-run src/filc/uaf.c       # Test memory safety detection"
    echo "  filc-test-all                  # Run all test programs"
else
    echo -e "${YELLOW}⚠${NC} Fil-C is not installed"
    echo "Follow the installation guide in doc/fil-c.md"
fi

echo ""
echo "Documentation:"
echo "  README.md      - Project overview"
echo "  WORKFLOW.md    - Development workflow"
echo "  doc/fil-c.md   - Fil-C installation guide"
echo ""
echo -e "${GREEN}Please run: source ~/.bashrc${NC}"
echo "Or open a new terminal to activate the environment."
