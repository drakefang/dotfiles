#!/bin/bash
# shellcheck disable=SC2155

#================================================================================#
# .SYNOPSIS
#     A comprehensive script to set up a full development environment on a new macOS system.
#
# .DESCRIPTION
#     This script automates the installation of:
#     1. Xcode Command Line Tools (essential for development).
#     2. Homebrew package manager.
#     3. A list of essential applications and development tools via Homebrew.
#     4. The Rust toolchain (via rustup) with Aliyun mirrors.
#     5. A list of essential Rust tools via Cargo, also using Aliyun mirror.
#
# .NOTES
#     Author: yuyz
#     Version: 1.1 
#     Date: 2025-08-14
#     Requirements: macOS, Internet connection.
#     Usage: Save as setup_macos.sh and run from your terminal: /bin/bash setup_macos.sh
#================================================================================#

# --- Configuration ---

# List of Homebrew formulas (command-line tools) to install.
brew_formulas=(
    git
    neovim
    neovim-qt
    powershell
    cmake
    python
    lua
    rustup-init # Use rustup-init to install rustup
    gcc         # For C/C++ development
    llvm        # For Clang/LLVM toolchain
    # -- CLI Power Tools --
    ripgrep
    fd
    fzf
    lazygit
    starship
    zellij
    tree-sitter
    starship
    win32yank # Note: on macOS this is often handled by pbcopy/pbpaste, but can be useful for consistency
    # Add more formulas here...
)

# List of Homebrew casks (GUI applications) to install.
brew_casks=(
    wezterm
    firefox
    visual-studio-code
    rider         # JetBrains Rider
    clion         # JetBrains CLion
    fork          # Git GUI client
    docker
    raycast       # The ultimate uTools/Flow Launcher alternative on macOS
    obsidian
    # Add more GUI apps here...
)

# List of Rust tools (cargo packages) to install.
rust_tools=(
    cargo-edit
    cargo-watch
    cargo-expand
    cargo-udeps
    cargo-audit
)

# --- Helper Functions ---

# Function to print colored log messages.
log() {
    local color_code=$1
    local message=$2
    # Check if stdout is a terminal
    if [ -t 1 ]; then
        echo -e "\033[${color_code}m${message}\033[0m"
    else
        echo "${message}"
    fi
}

info() { log "36" "--- $1 ---"; } # Cyan
success() { log "32" "✅ $1"; }
warn() { log "33" "⏳ $1"; }
error() { log "31" "❌ $1"; }
header() { log "35" "🚀 $1"; }

# Function to check if a command exists.
command_exists() {
    command -v "$1" &>/dev/null
}

# --- Installation Modules ---

install_xcode_tools() {
    info "Module 1: Checking for Xcode Command Line Tools"
    if xcode-select -p &>/dev/null; then
        success "Xcode Command Line Tools are already installed."
    else
        warn "Xcode Command Line Tools not found. Starting installation..."
        # This will pop up a dialog for the user to confirm.
        xcode-select --install
        # Note: This part of the script will pause until the user finishes the installation.
        success "Please follow the on-screen instructions to install Xcode Command Line Tools."
        read -p "Press [Enter] to continue after installation is complete..."
    fi
}

install_homebrew() {
    info "Module 2: Checking for Homebrew"
    if command_exists brew; then
        success "Homebrew is already installed. Updating..."
        brew update
    else
        warn "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [[ $? -ne 0 ]]; then
            error "Homebrew installation failed."
            exit 1
        fi
        success "Homebrew installed successfully."
        # Add Homebrew to PATH for the current script session.
        # This is important for the rest of the script to find brew-installed commands.
        if [[ "$(uname -m)" == "arm64" ]]; then # Apple Silicon
             eval "$(/opt/homebrew/bin/brew shellenv)"
        else # Intel
             eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
}

install_brew_packages() {
    info "Module 3: Installing Homebrew Formulas & Casks"
    
    warn "Installing command-line tools (formulas)..."
    for formula in "${brew_formulas[@]}"; do
        if brew list --formula | grep -q "^${formula}$"; then
            success "Formula '$formula' is already installed. Skipping."
        else
            warn "   Installing '$formula'..."
            brew install "$formula"
        fi
    done

    warn "Installing GUI applications (casks)..."
    # Note: Added a placeholder for a SpaceSniffer-like app
    warn "Note: For a 'SpaceSniffer' alternative, consider installing 'grandperspective' or 'omnidisksweeper' manually via `brew install --cask`."
    for cask in "${brew_casks[@]}"; do
        if [[ "$cask" == "spacesniffer-like-app" ]]; then continue; fi # Skip placeholder
        if brew list --cask | grep -q "^${cask}$"; then
            success "Cask '$cask' is already installed. Skipping."
        else
            warn "   Installing '$cask'..."
            brew install --cask "$cask"
        fi
    done
}

install_rust() {
    info "Module 4: Installing Rust Toolchain with Aliyun Mirrors"
    
    if command_exists rustup; then
        success "Rust (rustup) is already installed. Updating..."
        rustup update
    else
        warn "Setting up Rustup Aliyun mirror environment variables..."
        export RUSTUP_UPDATE_ROOT="https://mirrors.aliyun.com/rustup/rustup"
        export RUSTUP_DIST_SERVER="https://mirrors.aliyun.com/rustup"
        success "Mirror set to Aliyun."

        warn "Initializing rustup..."
        rustup-init -y --no-modify-path
        
        export PATH="$HOME/.cargo/bin:$PATH"
    fi

    local cargo_config_dir="$HOME/.cargo"
    local cargo_config_file="$cargo_config_dir/config.toml" 
    if [ -f "$cargo_config_file" ] || [ -f "$cargo_config_dir/config" ]; then
        success "Cargo config already exists."
    else
        warn "Creating Cargo config for Aliyun mirror..."
        mkdir -p "$cargo_config_dir"
        cat > "$cargo_config_file" << EOF
[source.crates-io]
replace-with = 'aliyun'

[source.aliyun]
registry = "sparse+https://mirrors.aliyun.com/crates.io-index/"
EOF
        success "Cargo mirror configured to Aliyun."
    fi
}

install_rust_tools() {
    info "Module 5: Installing Rust Tools via Cargo"
    for tool in "${rust_tools[@]}"; do
        if command_exists "$tool"; then
            success "Rust tool '$tool' is already installed. Skipping."
        else
            warn "   Installing '$tool' via Cargo..."
            cargo install "$tool"
        fi
    done
}

configure_shells() {
    info "Module 6: Configuring Shells (Zsh, Bash, PowerShell)"

    # --- Starship Configuration ---
    warn "   Configuring Starship prompt for Zsh, Bash, and PowerShell..."
    
    # Zsh (~/.zshrc)
    local zsh_config="$HOME/.zshrc"
    if ! grep -q "starship init zsh" "$zsh_config" 2>/dev/null; then
        echo -e '\n# Initialize Starship Prompt\neval "$(starship init zsh)"' >> "$zsh_config"
        success "Starship configured for Zsh."
    else
        success "Starship already configured for Zsh."
    fi

    # Bash (~/.bash_profile)
    local bash_config="$HOME/.bash_profile"
    if ! grep -q "starship init bash" "$bash_config" 2>/dev/null; then
        echo -e '\n# Initialize Starship Prompt\neval "$(starship init bash)"' >> "$bash_config"
        success "Starship configured for Bash."
    else
        success "Starship already configured for Bash."
    fi

    # PowerShell (~/.config/powershell/profile.ps1)
    local pwsh_config_dir="$HOME/.config/powershell"
    local pwsh_profile="$pwsh_config_dir/profile.ps1"
    mkdir -p "$pwsh_config_dir"
    if ! grep -q "starship init powershell" "$pwsh_profile" 2>/dev/null; then
        echo -e '\n# Initialize Starship Prompt\nInvoke-Expression (&starship init powershell)' >> "$pwsh_profile"
        success "Starship configured for PowerShell."
    else
        success "Starship already configured for PowerShell."
    fi
    
    # --- Rust Environment Variables ---
    warn "   Configuring Rust environment for Zsh, Bash, and PowerShell..."
    
    local rust_env_vars=(
        'export RUSTUP_UPDATE_ROOT="https://mirrors.aliyun.com/rustup/rustup"'
        'export RUSTUP_DIST_SERVER="https://mirrors.aliyun.com/rustup"'
        'export PATH="$HOME/.cargo/bin:$PATH"'
    )
    
    # Zsh/Bash (~/.zshenv for Zsh, ~/.bash_profile for Bash)
    # .zshenv is a good place for env vars as it's sourced for all shell types
    local zsh_env_file="$HOME/.zshenv"
    for var in "${rust_env_vars[@]}"; do
        if ! grep -q "$var" "$zsh_env_file" 2>/dev/null; then
            echo "$var" >> "$zsh_env_file"
        fi
        if ! grep -q "$var" "$bash_config" 2>/dev/null; then
            echo "$var" >> "$bash_config"
        fi
    done
    success "Rust environment variables configured for Zsh and Bash."
    
    # PowerShell Profile
    # PowerShell syntax is different
    local pwsh_rust_vars=(
        '$env:RUSTUP_UPDATE_ROOT = "https://mirrors.aliyun.com/rustup/rustup"'
        '$env:RUSTUP_DIST_SERVER = "https://mirrors.aliyun.com/rustup"'
        '$env:PATH = "$HOME\.cargo\bin;" + $env:PATH'
    )
    for var in "${pwsh_rust_vars[@]}"; do
        if ! grep -q "$var" "$pwsh_profile" 2>/dev/null; then
             echo "$var" >> "$pwsh_profile"
        fi
    done
    success "Rust environment variables configured for PowerShell."
}

# --- Main Execution ---

main() {
    header "Starting Development Environment Setup on macOS..."

    install_xcode_tools
    install_homebrew
    install_brew_packages
    install_rust
    install_rust_tools
    configure_shells

    header "🎉 All setup tasks completed!"
    success "IMPORTANT: Please close and reopen your terminal, or run 'source ~/.zshrc' to apply all changes."
}

# Execute the main function.
main