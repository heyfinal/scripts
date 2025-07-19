#!/bin/bash

# Script to install Aircrack-ng and other networking tools on macOS
# Run with: sudo bash install_network_tools.sh
# Ensure you have Homebrew installed: https://brew.sh/

# Exit on any error
set -e

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    case $color in
        "green")  echo -e "\033[32m$message\033[0m" ;;
        "red")    echo -e "\033[31m$message\033[0m" ;;
        "yellow") echo -e "\033[33m$message\033[0m" ;;
        *)        echo "$message" ;;
    esac
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    print_status red "This script must be run as root (use sudo)."
    exit 1
fi

# Check for curl
if ! command_exists curl; then
    print_status red "curl not found. Please install curl manually."
    exit 1
fi

# Check for Homebrew
if ! command_exists brew; then
    print_status yellow "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add Homebrew to PATH for different macOS architectures
    if [[ -d "/opt/homebrew/bin" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -d "/usr/local/bin" ]]; then
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    else
        print_status red "Homebrew installation failed or unsupported architecture."
        exit 1
    fi
else
    print_status green "Homebrew is already installed."
fi

# Update Homebrew
print_status yellow "Updating Homebrew..."
brew update

# Install Xcode Command Line Tools (required for some packages)
if ! xcode-select -p >/dev/null 2>&1; then
    print_status yellow "Installing Xcode Command Line Tools..."
    xcode-select --install
else
    print_status green "Xcode Command Line Tools are already installed."
fi

# Install Aircrack-ng
print_status yellow "Installing Aircrack-ng..."
if brew install aircrack-ng; then
    print_status green "Aircrack-ng installed successfully."
else
    print_status red "Failed to install Aircrack-ng. Trying to build from source..."
    brew install --build-from-source aircrack-ng
fi

# Install Wireshark
print_status yellow "Installing Wireshark..."
brew install --cask wireshark
print_status green "Wireshark installed. Run 'wireshark' to start the GUI."

# Install nmap
print_status yellow "Installing nmap..."
brew install nmap
print_status green "nmap installed. Run 'nmap --version' to verify."

# Install tcpdump
print_status yellow "Installing tcpdump..."
brew install tcpdump
print_status green "tcpdump installed. Run 'sudo tcpdump --version' to verify."

# Install libpcap (for packet capturing)
print_status yellow "Installing libpcap..."
brew install libpcap
print_status green "libpcap installed."

# Install hashcat (for password cracking, alternative to aircrack-ng)
print_status yellow "Installing hashcat..."
brew install hashcat
print_status green "hashcat installed. Run 'hashcat --version' to verify."

# Set up macOS airport