# 🍎 Ultimate macOS Developer Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-12%2B-blue)](https://www.apple.com/macos/)
[![Shell](https://img.shields.io/badge/Shell-Zsh-green)](https://www.zsh.org/)

> **Transform your fresh Mac into a powerhouse development machine in minutes!**

A comprehensive, idempotent macOS setup script that configures everything you need for modern development. Featuring Kali Linux-inspired themes, AI-powered CLIs, and essential developer tools.

## ✨ Features

- 🚀 **One-command setup** - Zero manual configuration needed
- 🔄 **Idempotent** - Safe to run multiple times, skips existing installs
- 🎨 **Kali Linux themes** - Dark terminal themes for Terminal.app & iTerm2
- 🤖 **AI CLIs** - GitHub Copilot, Claude & OpenAI command-line tools
- 📦 **Essential tools** - Homebrew, Git, Node.js, Python, Go, Rust, Docker
- 🐚 **Enhanced shell** - Oh My Zsh + Powerlevel10k + useful plugins
- ⚡ **Custom aliases** - `chz` for `chmod +x`, `openz` for TextEdit
- 🔐 **Security first** - Firewall, stealth mode, SSH key generation
- 🛠 **macOS tweaks** - Developer-friendly system preferences

## 🚀 Quick Start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/heyfinal/scripts/main/mac_setup.sh)
```

**That's it!** The script will:
1. Install and configure everything
2. Set up your development environment
3. Apply Kali-style terminal themes
4. Reboot automatically to complete setup

## 📋 What Gets Installed

### 🛠 Development Tools
- **Package Manager**: Homebrew
- **Languages**: Node.js, Python 3.12, Go, Rust
- **Containers**: Docker, Docker Compose
- **Version Control**: Git (with configuration)

### 🤖 AI-Powered CLIs
- **GitHub Copilot CLI** - AI-powered terminal assistance
- **Claude CLI** - Direct access to Anthropic's Claude
- **OpenAI CLI** - Command-line interface for OpenAI models

### 📱 Applications
- **Terminal**: iTerm2 (with Kali theme)
- **Productivity**: Rectangle, Alfred, 1Password
- **Communication**: Discord, Slack, Zoom

### ⚡ CLI Enhancements
- **Modern replacements**: `bat` (cat), `eza` (ls), `fd` (find), `rg` (grep)
- **Shell**: Oh My Zsh + autosuggestions + syntax highlighting
- **Theme**: Powerlevel10k (optional Kali-style alternative)
- **Utilities**: `fzf`, `htop`, `jq`, `tree`, `tldr`

### 🎨 Terminal Themes
Beautiful Kali Linux-inspired dark themes with:
- **Black background** (#000000)
- **Bright green text** (#00FF00)
- **Authentic ANSI color palette**
- **Powerline-compatible fonts**

## 🛡 Security Features

- ✅ **Firewall enabled** with stealth mode
- ✅ **Firewall logging** for monitoring
- ✅ **SSH key generation** (Ed25519)
- ✅ **Quarantine dialog disabled** for trusted apps
- ✅ **Security-focused system preferences**

## ⚙️ System Optimizations

### 🖱 Enhanced Input
- Fast key repeat rates
- Tap to click enabled
- Right-click configured
- Increased trackpad speed

### 🖥 UI Improvements
- Show hidden files and extensions
- Dock auto-hide with no delay
- Faster Mission Control animations
- List view as default in Finder

## 📖 Usage Examples

### Custom Aliases
```bash
# Make file executable
chz script.sh

# Open file in TextEdit
openz notes.txt

# Modern CLI replacements
ll                    # Enhanced ls with git info
cat file.txt         # Syntax-highlighted output
find . -name "*.js"  # Fast file search
```

### AI CLI Usage
```bash
# GitHub Copilot
gh copilot suggest "create a git ignore file"
gh copilot explain "docker run -it ubuntu"

# Claude CLI
claude "explain this bash script"
claude config  # Configure API access

# OpenAI CLI
openai "generate a Python function to sort a list"
openai config  # Set up API key
```

## 🎯 Target Audience

Perfect for:
- 👨‍💻 **Developers** setting up new Macs
- 🔄 **Teams** standardizing development environments  
- 🎓 **Students** learning modern development tools
- 🏢 **Organizations** onboarding developers quickly

## ⚡ Performance

- **Fast execution** - Skips already installed packages
- **Minimal downloads** - Only installs what's needed
- **Parallel processing** - Where possible
- **Clean logging** - Full logs saved to `/tmp/mac_setup.log`

## 🔧 Customization

The script is designed to be easily customizable:

### Adding Applications
```bash
# Add to the Applications section
install_brew_cask "your-app-name"
```

### Custom Aliases
```bash
# Add to the aliases section in .zshrc
alias your_alias='your_command'
```

### System Preferences
```bash
# Add new preferences
set_pref com.apple.domain PreferenceKey -bool true
```

## 🤝 Contributing

We welcome contributions! Please:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature-name`
3. **Test** your changes thoroughly
4. **Commit** with clear messages: `git commit -m "Add feature"`
5. **Push** to your branch: `git push origin feature-name`
6. **Open** a Pull Request

### Development Guidelines
- Keep the script idempotent
- Add proper error handling
- Update documentation
- Test on clean macOS installations

## 📝 Requirements

- **macOS 12+** (Monterey or later)
- **Admin privileges** (for system preferences)
- **Internet connection** (for downloads)

## 🐛 Troubleshooting

### Common Issues

**Script fails with permissions error:**
```bash
# Run with sudo for system preferences
sudo bash <(curl -fsSL https://raw.githubusercontent.com/heyfinal/scripts/main/mac_setup.sh)
```

**Homebrew PATH issues:**
```bash
# Reload shell or run:
eval "$(/opt/homebrew/bin/brew shellenv)"  # Apple Silicon
eval "$(/usr/local/bin/brew shellenv)"     # Intel
```

**GitHub Copilot not working:**
```bash
# Login to GitHub first
gh auth login
gh copilot config
```

**OpenAI CLI setup:**
```bash
# Configure your API key
openai config
# Or set environment variable
export OPENAI_API_KEY="your-api-key-here"
```

## 📊 Statistics

- ⏱ **Setup time**: ~10-15 minutes
- 📦 **Packages installed**: 20+ essential tools
- 🎨 **Themes configured**: 2 (Terminal.app + iTerm2)
- 🔧 **System preferences**: 15+ optimizations
- 📱 **Applications**: 7 productivity apps

## 🗺 Roadmap

- [ ] **GUI installer** for non-technical users
- [ ] **Configuration profiles** (minimal, full, custom)
- [ ] **Backup/restore** existing settings
- [ ] **Linux support** (Ubuntu, Fedora)
- [ ] **Windows support** (WSL2)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Homebrew](https://brew.sh/) - The missing package manager for macOS
- [Oh My Zsh](https://ohmyz.sh/) - Delightful zsh configuration framework
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k) - Zsh theme
- [Kali Linux](https://www.kali.org/) - Terminal theme inspiration

---

<div align="center">

**[⬆ Back to Top](#-ultimate-macos-developer-setup)**

Made with ❤️ for the developer community

</div>