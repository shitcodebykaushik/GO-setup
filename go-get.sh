#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/usr/local"
GO_DIR="$INSTALL_DIR/go"
MIN_SPACE_MB=1024 # 1GB

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

check_dependencies() {
    local deps=("curl" "tar" "sudo")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "$dep is required but not installed. Please install it first."
            exit 1
        fi
    done
}

check_disk_space() {
    log_info "Checking disk space in $INSTALL_DIR..."
    
    # Get available space in MB
    local available_space
    available_space=$(df -m "$INSTALL_DIR" | awk 'NR==2 {print $4}')
    
    if [ "$available_space" -lt "$MIN_SPACE_MB" ]; then
        log_error "Not enough disk space. Required: ${MIN_SPACE_MB}MB, Available: ${available_space}MB"
        exit 1
    fi
    
    log_success "Disk space check passed (${available_space}MB available)."
}

get_latest_version() {
    log_info "Fetching latest Go version..."
    local latest_version
    latest_version=$(curl -s https://go.dev/dl/?mode=json | grep -o '"version": "go[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$latest_version" ]; then
        log_error "Failed to fetch latest Go version."
        exit 1
    fi
    
    echo "$latest_version"
}

get_installed_version() {
    if command -v go &> /dev/null; then
        go version | awk '{print $3}'
    else
        echo "none"
    fi
}

install_go() {
    local version=$1
    local os="linux"
    local arch
    
    # Detect architecture
    case $(uname -m) in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv6l) arch="armv6l" ;;
        *) log_error "Unsupported architecture: $(uname -m)"; exit 1 ;;
    esac
    
    local filename="${version}.${os}-${arch}.tar.gz"
    local url="https://go.dev/dl/$filename"
    
    log_info "Downloading $filename..."
    if ! curl -L -O "$url"; then
        log_error "Download failed."
        exit 1
    fi
    
    log_info "Installing Go to $GO_DIR..."
    
    # Remove existing installation
    if [ -d "$GO_DIR" ]; then
        log_info "Removing previous installation..."
        sudo rm -rf "$GO_DIR"
    fi
    
    # Extract
    if ! sudo tar -C "$INSTALL_DIR" -xzf "$filename"; then
        log_error "Extraction failed."
        rm "$filename"
        exit 1
    fi
    
    # Cleanup
    rm "$filename"
    log_success "Go installed successfully!"
}

setup_path() {
    local bin_path="$GO_DIR/bin"
    local shell_profile=""
    local user_shell=""
    
    # Detect shell
    user_shell=$(basename "$SHELL")
    
    case "$user_shell" in
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                shell_profile="$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                shell_profile="$HOME/.bash_profile"
            fi
            ;;
        zsh)
            shell_profile="$HOME/.zshrc"
            ;;
        *)
            # Fallback detection
            if [ -f "$HOME/.zshrc" ]; then
                shell_profile="$HOME/.zshrc"
            elif [ -f "$HOME/.bashrc" ]; then
                shell_profile="$HOME/.bashrc"
            fi
            ;;
    esac

    # Check current PATH
    if [[ ":$PATH:" == *":$bin_path:"* ]]; then
        log_success "Go binary path is already in PATH."
        return
    fi

    log_info "Go binary path is not in your PATH."
    
    if [ -n "$shell_profile" ]; then
        # Check if already in profile
        if grep -q "export PATH=$bin_path:\$PATH" "$shell_profile"; then
             log_success "Path configuration already exists in $shell_profile (needs source)."
             echo -e "Run: source $shell_profile"
             return
        fi

        echo -e "Detected shell profile: ${GREEN}$shell_profile${NC}"
        read -p "Do you want to automatically add Go to your PATH in $shell_profile? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo >> "$shell_profile"
            echo "# Go programming language" >> "$shell_profile"
            echo "export PATH=$bin_path:\$PATH" >> "$shell_profile"
            log_success "Added Go to PATH in $shell_profile"
            
            # Prompt for shell reload
            echo
            log_info "To apply changes, your shell needs to be reloaded."
            read -p "Do you want to reload your shell now? (This will restart your terminal session) [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "Reloading shell..."
                exec "$user_shell"
            else
                echo -e "To apply changes immediately, run: source $shell_profile"
            fi
        else
             log_info "Skipping automatic PATH configuration."
             echo -e "Add the following line to your shell profile:"
             echo -e "${GREEN}export PATH=$bin_path:\$PATH${NC}"
        fi
    else
        log_info "Could not detect shell profile."
        echo -e "Add the following line to your shell profile (e.g., ~/.bashrc, ~/.zshrc):"
        echo -e "${GREEN}export PATH=$bin_path:\$PATH${NC}"
    fi
}

main() {
    check_dependencies
    check_disk_space
    
    local latest_ver
    latest_ver=$(get_latest_version)
    log_info "Latest version: $latest_ver"
    
    local current_ver
    current_ver=$(get_installed_version)
    log_info "Installed version: $current_ver"
    
    if [ "$current_ver" == "$latest_ver" ]; then
        log_success "Go is already up to date."
        exit 0
    fi
    
    if [ "$current_ver" != "none" ]; then
        log_info "Update available: $current_ver -> $latest_ver"
        read -p "Do you want to update? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Update cancelled."
            exit 0
        fi
    else
        log_info "Go is not installed. Installing $latest_ver..."
    fi
    
    install_go "$latest_ver"
    setup_path
    
    # Verify installation
    if "$GO_DIR/bin/go" version &> /dev/null; then
        log_success "Verification passed: $("$GO_DIR/bin/go" version)"
    else
        log_error "Verification failed."
        exit 1
    fi
}

main
