<#
.SYNOPSIS
    A comprehensive script to set up a full development environment on a new Windows system.
.DESCRIPTION
    This script automates the installation of:
    1. MSVC C++ Build Tools (via Visual Studio Installer).
    2. Scoop package manager.
    3. A list of essential applications and .NET SDKs via Scoop.
    4. The Rust toolchain (via rustup, installed by Scoop) with domestic mirrors.
    5. A list of essential Rust tools via Cargo.
.NOTES
    Author: yuyz
    Version: 1.0
    Date: 2025-08-14
    Requirements: Windows 10/11, PowerShell 5.1+, Internet connection.
    Usage: Run this script from an ADMINISTRATOR PowerShell terminal.
#>

# List of Scoop packages to install.
$scoopApps = @(
  "git",
  "neovim",
  "neovim-qt",
  "vscode",
  "7zip",
  "spacesniffer",
  "python",
  "docker",
  "dotnet-sdk",
  "rider",
  "clion",
  "cmake",
  "ninja",
  "firefox",
  "fork",
  "rustup",
  "scons",
  "wezterm",
  "dark",
  "everything",
  "vcpkg",
  "lua51",
  "fd",
  "fzf",
  "lazygit",
  "win32yank",
  "gcc",
  "llvm",
  "ripgrep",
  "tree-sitter",
  "pwsh",
  "starship",
  "powertoys"
  # Add more apps here...
)

# List of Rust tools (cargo packages) to install.
$rustTools = @(
  "cargo-edit",
  "cargo-watch",
  "cargo-expand",
  "cargo-udeps",
  "cargo-audit"
)

function Test-CommandExists {
  param($command)
  return (Get-Command $command -ErrorAction SilentlyContinue)
}

function Write-Log {
  param(
    [string]$Message,
    [string]$Color = "White"
  )
  Write-Host $Message -ForegroundColor $Color
}

function Install-MsvcBuildTools {
  Write-Log "--- Module 1: Checking for MSVC C++ Build Tools ---" -Color Cyan

  $vsInstallerPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe"
  if (Test-Path $vsInstallerPath) {
    Write-Log "✅ Visual Studio Installer found. Assuming MSVC tools are installed or can be installed manually." -Color Green
    Write-Log "   If C++ tools are missing, please open 'Visual Studio Installer' and add the 'Desktop development with C++' workload."
  }
  else {
    Write-Log "⏳ Visual Studio Installer not found. Downloading and installing VS Build Tools..." -Color Yellow
        
    $vsBuildToolsUrl = "https://aka.ms/vs/17/release/vs_buildtools.exe"
    $installerPath = "$env:TEMP\vs_buildtools.exe"
        
    Invoke-WebRequest -Uri $vsBuildToolsUrl -OutFile $installerPath
        
    Write-Log "   Starting VS Build Tools installer. Please follow the on-screen instructions."
    Write-Log "   IMPORTANT: Make sure to select the 'Desktop development with C++' workload in the installer." -Color Magenta
        
    Start-Process -FilePath $installerPath -ArgumentList "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive --wait" -Wait -PassThru
        
    if ($?) {
      Write-Log "✅ VS Build Tools installation process completed." -Color Green
    }
    else {
      Write-Log "❌ VS Build Tools installation failed or was cancelled." -Color Red
    }
  }
}

function Install-Scoop {
  Write-Log "--- Module 2: Checking for Scoop ---" -Color Cyan
  if (Test-CommandExists "scoop") {
    Write-Log "✅ Scoop is already installed. Updating..." -Color Green
    scoop update
  }
  else {
    Write-Log "⏳ Scoop not found. Installing..." -Color Yellow
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod get.scoop.sh | Invoke-Expression
    if ($?) {
      Write-Log "✅ Scoop installed successfully." -Color Green
    }
    else {
      Write-Log "❌ Scoop installation failed." -Color Red
      exit 1
    }
  }
}

function Install-ScoopApps {
  param($apps)
  Write-Log "--- Module 3: Installing Scoop Apps ---" -Color Cyan
    
  # Add the 'extras' bucket, which contains many common apps.
  $bucketList = scoop bucket list
  if (-not ($bucketList -like "*extras*")) {
    Write-Log "   Adding 'extras' bucket..." -Color Gray
    scoop bucket add extras
  }
  if (-not ($bucketList -like "*versions*")) {
    Write-Log "   Adding 'versions' bucket..." -Color Gray
    scoop bucket add versions
  }

  $failedApps = [System.Collections.ArrayList]@()
    
  foreach ($app in $apps) {
    if ((scoop list | Select-String -Pattern "^$app\s" -Quiet)) {
      Write-Log "✅ App '$app' is already installed. Skipping." -Color Green
    }
    else {
      Write-Log "⏳ Installing '$app' via Scoop..." -Color Yellow
      scoop install $app
      if ($LASTEXITCODE -ne 0) {
        Write-Log "❌ Failed to install '$app'." -Color Red
        [void]$failedApps.Add($app)
      }
    }
  }

  if ($failedApps.Count -gt 0) {
    Write-Log "--- Summary of Failed Scoop Installations ---" -Color Yellow
    foreach ($failed in $failedApps) {
      Write-Log "  - $failed" -Color Red
    }
  }
}

function Install-Rust {
  Write-Log "--- Module 4: Installing Rust Toolchain ---" -Color Cyan

  if (Test-CommandExists "rustup") {
    Write-Log "✅ Rust (rustup) is already installed. Updating..." -Color Green
    rustup update
  }
  else {
    Write-Log "⏳ Setting up Rustup domestic mirror environment variables..." -Color Yellow
    [Environment]::SetEnvironmentVariable("RUSTUP_UPDATE_ROOT", "https://mirrors.aliyun.com/rustup/rustup", "User")
    [Environment]::SetEnvironmentVariable("RUSTUP_DIST_SERVER", "https://mirrors.aliyun.com/rustup", "User")
    Write-Log "   Mirror set to aliyun." -Color Green

    Write-Log "   Installing 'rustup' via Scoop..." -Color Yellow
    scoop install rustup
        
    $env:PATH = "$($env:USERPROFILE)\.cargo\bin;" + $env:PATH
  }

  $cargoConfigPath = "$env:USERPROFILE\.cargo\config"
  if (Test-Path $cargoConfigPath) {
    Write-Log "✅ Cargo config already exists." -Color Green
  }
  else {
    Write-Log "   Creating Cargo config for domestic mirror..." -Color Gray
    $cargoConfig = @"
[source.crates-io]
replace-with = 'aliyun'
[source.aliyun]
registry = "sparse+https://mirrors.aliyun.com/crates.io-index/"
"@
    New-Item -Path $cargoConfigPath -ItemType File -Value $cargoConfig -Force
    Write-Log "✅ Cargo mirror configured." -Color Green
  }
}

function Install-RustTools {
  param($tools)
  Write-Log "--- Module 5: Installing Rust Tools via Cargo ---" -Color Cyan
    
  foreach ($tool in $tools) {
    if (Test-CommandExists $tool) {
      Write-Log "✅ Rust tool '$tool' is already installed. Skipping." -Color Green
    }
    else {
      Write-Log "⏳ Installing '$tool' via Cargo..." -Color Yellow
      cargo install $tool
    }
  }
}

# --- Main Execution ---
function Main {
  if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "❌ This script must be run as an Administrator. Please right-click and 'Run as Administrator'." -Color Red
    Read-Host "Press Enter to exit..."
    exit 1
  }
  Write-Log "🚀 Starting Development Environment Setup..." -Color Magenta
    
  # Run each installation module in order.
  Install-MsvcBuildTools
  Install-Scoop
  Install-ScoopApps -apps $scoopApps
  Install-Rust
  Install-RustTools -tools $rustTools

  Write-Log "🎉 All setup tasks completed! Please restart your terminal to ensure all environment variables are loaded correctly." -Color Magenta
}

# Execute the main function.
Main
