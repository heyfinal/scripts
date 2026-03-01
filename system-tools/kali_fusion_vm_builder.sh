#!/usr/bin/env bash
# ==============================================================================
# kali_fusion_vm_builder.sh
# Dynamic Kali Linux ISO Builder — Optimized for VMware Fusion on MacBook
# ==============================================================================
# Supports: Intel Mac (amd64) + Apple Silicon M-series (arm64)
# Output:   Installer ISO with open-vm-tools pre-baked, preseed ready
# Runs on:  Linux only (run from inside your existing Kali VM or a Debian VM)
# Usage:    sudo ./kali_fusion_vm_builder.sh [OPTIONS]
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# ANSI Colors
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ------------------------------------------------------------------------------
# DEFAULTS (all overridable via flags or env vars)
# ------------------------------------------------------------------------------
ARCH="${ARCH:-auto}"                        # auto | amd64 | arm64
BUILD_TYPE="${BUILD_TYPE:-installer}"       # installer | live
VARIANT="${VARIANT:-default}"              # default | light | minimal | xfce | gnome
BRANCH="${BRANCH:-kali-rolling}"           # kali-rolling | kali-last-snapshot
BUILD_DIR="${BUILD_DIR:-/build/kali-fusion}"
OUTPUT_DIR="${OUTPUT_DIR:-/build/output}"
EXTRA_PKGS="${EXTRA_PKGS:-}"
PRESEED="${PRESEED:-true}"
CACHE_MIRROR="${CACHE_MIRROR:-}"
CLEAN_BUILD="${CLEAN_BUILD:-false}"
TZ="${TZ:-US/Central}"
VM_RAM_MB="${VM_RAM_MB:-8192}"
VM_DISK_GB="${VM_DISK_GB:-80}"
LOGFILE="/tmp/kali_fusion_build_$(date +%Y%m%d_%H%M%S).log"
BUILD_START=$(date +%s)
TOTAL_STEPS=8

REPO_URL="https://gitlab.com/kalilinux/build-scripts/live-build-config.git"

# ------------------------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------------------------
_log() {
    local level="$1"; shift
    local ts; ts=$(date '+%H:%M:%S')
    echo -e "${ts} ${level} $*" | tee -a "$LOGFILE"
}
info()    { _log "${BLUE}[INFO]${NC} "    "$*"; }
success() { _log "${GREEN}[✔]${NC}   "    "$*"; }
warn()    { _log "${YELLOW}[⚠]${NC}   "   "$*"; }
error()   { _log "${RED}[✘]${NC}   "    "$*"; }
step()    { echo; _log "${PURPLE}${BOLD}[STEP]${NC}" "$*"; echo; }
divider() { echo -e "${DIM}──────────────────────────────────────────────────${NC}"; }

# ------------------------------------------------------------------------------
# SIGNAL TRAP
# ------------------------------------------------------------------------------
trap 'echo; error "Interrupted — build incomplete. Log: ${LOGFILE}"; exit 130' INT TERM

# ------------------------------------------------------------------------------
# BANNER
# ------------------------------------------------------------------------------
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'BANNER'
╔══════════════════════════════════════════════════════════════════════╗
║    🐉  KALI LINUX FUSION VM ISO BUILDER                             ║
║    Dynamic · Arch-Aware · VMware Fusion Optimized                   ║
║    MacBook Intel (amd64) + Apple Silicon M-series (arm64)           ║
╚══════════════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
    echo -e "  ${BOLD}Log:${NC}    ${LOGFILE}"
    echo -e "  ${BOLD}Date:${NC}   $(date '+%Y-%m-%d %H:%M:%S')"
    divider
    echo
}

# ------------------------------------------------------------------------------
# USAGE
# ------------------------------------------------------------------------------
usage() {
    echo -e "${BOLD}Usage:${NC} sudo ./kali_fusion_vm_builder.sh [OPTIONS]"
    echo
    echo -e "${BOLD}Options:${NC}"
    echo "  --arch <auto|amd64|arm64>     Target ISO arch (default: auto-detect from host)"
    echo "  --type <installer|live>       Build type (default: installer — use for VMs)"
    echo "  --variant <default|light|...> Kali variant (default: default)"
    echo "  --branch <kali-rolling|...>   Kali branch (default: kali-rolling)"
    echo "  --output <dir>                ISO output directory (default: /build/output)"
    echo "  --build-dir <dir>             Build working directory (default: /build/kali-fusion)"
    echo "  --extra-pkgs '<pkg list>'     Space-separated extra packages to bake in"
    echo "  --no-preseed                  Skip preseed — manual install wizard"
    echo "  --cache-mirror <url>          APT proxy (e.g. http://192.168.1.1:3142/)"
    echo "  --clean                       Purge previous build artifacts before building"
    echo "  --tz <zone>                   Timezone for preseed (default: US/Central)"
    echo "  -h, --help                    Show this help"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo "  sudo ./kali_fusion_vm_builder.sh"
    echo "  sudo ./kali_fusion_vm_builder.sh --arch arm64 --output ~/Desktop"
    echo "  sudo ./kali_fusion_vm_builder.sh --arch amd64 --no-preseed --clean"
    echo "  sudo ./kali_fusion_vm_builder.sh --extra-pkgs 'wireguard tor gobuster'"
    echo "  ARCH=arm64 OUTPUT_DIR=~/iso sudo ./kali_fusion_vm_builder.sh"
    echo
}

# ------------------------------------------------------------------------------
# ARG PARSING
# ------------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --arch)         ARCH="$2";         shift 2 ;;
            --type)         BUILD_TYPE="$2";   shift 2 ;;
            --variant)      VARIANT="$2";      shift 2 ;;
            --branch)       BRANCH="$2";       shift 2 ;;
            --output)       OUTPUT_DIR="$2";   shift 2 ;;
            --build-dir)    BUILD_DIR="$2";    shift 2 ;;
            --extra-pkgs)   EXTRA_PKGS="$2";   shift 2 ;;
            --no-preseed)   PRESEED="false";   shift ;;
            --cache-mirror) CACHE_MIRROR="$2"; shift 2 ;;
            --clean)        CLEAN_BUILD="true"; shift ;;
            --tz)           TZ="$2";           shift 2 ;;
            -h|--help)      usage; exit 0 ;;
            *) error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# STEP 1 — OS & ROOT CHECK
# ------------------------------------------------------------------------------
check_environment() {
    step "[1/${TOTAL_STEPS}] 🔍 Environment Check"

    # Must be Linux
    if [[ "$(uname -s)" == "Darwin" ]]; then
        error "This script must run inside a Linux environment, not macOS."
        echo
        echo -e "${YELLOW}${BOLD}You have two options:${NC}"
        echo
        echo -e "  ${BOLD}Option A (Recommended):${NC}"
        echo -e "  Run this script from INSIDE your existing Kali VM in VMware Fusion:"
        echo -e "  ${CYAN}  git clone https://github.com/heyfinal/scripts && \\"
        echo -e "    sudo ./scripts/system-tools/kali_fusion_vm_builder.sh${NC}"
        echo
        echo -e "  ${BOLD}Option B:${NC} Spin up an ARM64 or x86 Linux VM via UTM/Parallels/cloud"
        echo -e "  then run this script inside it."
        echo
        echo -e "  ${DIM}Note: live-build requires loop devices and chroot — cannot run in"
        echo -e "  Docker Desktop on macOS.${NC}"
        echo
        exit 1
    fi

    # Must be root
    if [[ $EUID -ne 0 ]]; then
        error "Root required: sudo ./kali_fusion_vm_builder.sh"
        exit 1
    fi

    # Must be Debian-based
    if ! command -v apt-get &>/dev/null; then
        error "apt-get not found — this script requires a Debian/Ubuntu/Kali system."
        exit 1
    fi

    # Disk space check (need at least 60GB free)
    local free_gb
    free_gb=$(df -BG / | awk 'NR==2 {gsub("G",""); print $4}')
    if [[ "$free_gb" -lt 60 ]]; then
        warn "Only ${free_gb}GB free — recommend 60GB+ for a full build"
        warn "Proceeding anyway; build may fail if disk fills up"
    else
        info "Disk space: ${free_gb}GB free ✔"
    fi

    success "Environment: Linux, root, Debian-based ✔"
}

# ------------------------------------------------------------------------------
# STEP 2 — ARCHITECTURE DETECTION
# ------------------------------------------------------------------------------
detect_arch() {
    step "[2/${TOTAL_STEPS}] 🏗️  Architecture Detection"

    local host_arch; host_arch=$(uname -m)

    if [[ "$ARCH" == "auto" ]]; then
        case "$host_arch" in
            x86_64)
                ARCH="amd64"
                success "Host: x86_64 → Target ISO: ${BOLD}amd64${NC} (Intel MacBook / Fusion)"
                ;;
            aarch64|arm64)
                ARCH="arm64"
                success "Host: arm64 → Target ISO: ${BOLD}arm64${NC} (Apple Silicon MacBook M1/M2/M3/M4 / Fusion)"
                ;;
            *)
                warn "Unknown host arch '${host_arch}' — defaulting to amd64"
                ARCH="amd64"
                ;;
        esac
    else
        info "Forced target arch: ${BOLD}${ARCH}${NC}"
        if [[ "$ARCH" == "arm64" && "$host_arch" == "x86_64" ]]; then
            warn "Cross-building arm64 on x86_64 host — QEMU binfmt will be installed (slow!)"
        fi
        if [[ "$ARCH" == "amd64" && "$host_arch" == "aarch64" ]]; then
            warn "Cross-building amd64 on arm64 host — QEMU binfmt will be installed"
        fi
    fi

    # Fusion compatibility note
    echo
    if [[ "$ARCH" == "arm64" ]]; then
        echo -e "  ${CYAN}ℹ️  Apple Silicon Note:${NC}"
        echo -e "  VMware Fusion on M-series Macs is an ARM-only hypervisor."
        echo -e "  The arm64 ISO will work natively. An amd64 ISO will ${RED}NOT${NC} boot."
    else
        echo -e "  ${CYAN}ℹ️  Intel Mac Note:${NC}"
        echo -e "  VMware Fusion on Intel Macs supports x86_64 guests."
        echo -e "  The amd64 ISO is correct for your hardware."
    fi
    echo
}

# ------------------------------------------------------------------------------
# STEP 3 — INSTALL DEPENDENCIES
# ------------------------------------------------------------------------------
install_dependencies() {
    step "[3/${TOTAL_STEPS}] 📦 Installing Build Dependencies"

    local deps=(
        git
        live-build
        simple-cdd
        cdebootstrap
        curl
        wget
        devscripts
        squashfs-tools
        xorriso
        isolinux
        syslinux-common
        rsync
        apt-utils
        ca-certificates
        gnupg
    )

    info "Updating apt package lists..."
    apt-get update -qq 2>&1 | tail -5 | tee -a "$LOGFILE"

    local to_install=()
    for dep in "${deps[@]}"; do
        if ! dpkg -l "$dep" 2>/dev/null | grep -q "^ii"; then
            to_install+=("$dep")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        info "Installing missing packages: ${to_install[*]}"
        DEBIAN_FRONTEND=noninteractive apt-get install -y "${to_install[@]}" 2>&1 | tee -a "$LOGFILE"
    else
        info "All build dependencies already installed"
    fi

    # QEMU for cross-arch builds
    local host_arch; host_arch=$(uname -m)
    local need_qemu=false
    [[ "$ARCH" == "arm64" && "$host_arch" == "x86_64" ]] && need_qemu=true
    [[ "$ARCH" == "amd64" && "$host_arch" == "aarch64" ]] && need_qemu=true

    if [[ "$need_qemu" == "true" ]]; then
        info "Installing QEMU binfmt for cross-arch build..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
            qemu-user-static binfmt-support 2>&1 | tee -a "$LOGFILE"
        update-binfmts --enable qemu-aarch64 2>/dev/null || true
        update-binfmts --enable qemu-x86_64  2>/dev/null || true
        success "QEMU cross-build support enabled ✔"
    fi

    # Kali-specific: ensure we have the right version of live-build
    local lb_ver; lb_ver=$(lb --version 2>/dev/null || echo "unknown")
    info "live-build version: ${lb_ver}"

    success "Dependencies ready ✔"
}

# ------------------------------------------------------------------------------
# STEP 4 — CLONE / UPDATE BUILD REPO
# ------------------------------------------------------------------------------
setup_build_repo() {
    step "[4/${TOTAL_STEPS}] 📥 Kali live-build-config Repository"

    mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

    if [[ -d "${BUILD_DIR}/live-build-config/.git" ]]; then
        info "Updating existing repo..."
        git -C "${BUILD_DIR}/live-build-config" pull --rebase 2>&1 | tee -a "$LOGFILE"
    else
        info "Cloning Kali live-build-config from GitLab..."
        git clone --depth=1 "$REPO_URL" "${BUILD_DIR}/live-build-config" 2>&1 | tee -a "$LOGFILE"
    fi

    local commit; commit=$(git -C "${BUILD_DIR}/live-build-config" log -1 --format="%h %s")
    info "HEAD: ${commit}"
    success "Kali build scripts ready ✔"
}

# ------------------------------------------------------------------------------
# STEP 5 — CONFIGURE: Packages, Hooks, VMware Optimization
# ------------------------------------------------------------------------------
configure_build() {
    step "[5/${TOTAL_STEPS}] ⚙️  Configuring VMware Fusion Build"

    local lb_dir="${BUILD_DIR}/live-build-config"
    cd "$lb_dir"

    # --- Package list ---
    local pkg_file
    if [[ "$BUILD_TYPE" == "live" ]]; then
        local pkg_dir="kali-config/variant-${VARIANT}/package-lists"
        mkdir -p "$pkg_dir"
        pkg_file="${pkg_dir}/kali-vmware-fusion.list.chroot"
    else
        local pkg_dir="kali-config/installer-default/packages"
        mkdir -p "$pkg_dir"
        pkg_file="${pkg_dir}/kali-vmware-fusion"
    fi

    info "Writing VMware Fusion optimized package list → ${pkg_file}"
    cat > "$pkg_file" << 'PKGEOF'
# Kali default toolset
kali-linux-default

# VMware Fusion Guest Tools
# NOTE: "Install VMware Tools" in Fusion is greyed out for Linux guests.
# open-vm-tools from the repo is the correct/official approach.
open-vm-tools
open-vm-tools-desktop
fuse
fuse3

# Essentials
net-tools
curl
wget
git
nano
vim-tiny
htop
PKGEOF

    # Append user-defined extra packages
    if [[ -n "$EXTRA_PKGS" ]]; then
        echo "" >> "$pkg_file"
        echo "# User-defined extra packages" >> "$pkg_file"
        for pkg in $EXTRA_PKGS; do
            echo "$pkg" >> "$pkg_file"
        done
        info "Extra packages added: ${EXTRA_PKGS}"
    fi

    # --- VMware guest tools systemd hook ---
    local hooks_dir="kali-config/common/hooks/live"
    mkdir -p "$hooks_dir"

    cat > "${hooks_dir}/99-vmware-fusion-setup.hook.chroot" << 'HOOKEOF'
#!/bin/bash
# Configure open-vm-tools for VMware Fusion
set -e

# Enable open-vm-tools service
systemctl enable open-vm-tools.service 2>/dev/null || true

# Fix vmware-user-suid-wrapper permissions
if [[ -f /usr/bin/vmware-user-suid-wrapper ]]; then
    chmod 4755 /usr/bin/vmware-user-suid-wrapper
fi

# FUSE support for shared folders
modprobe fuse 2>/dev/null || true
grep -qxF 'fuse' /etc/modules || echo 'fuse' >> /etc/modules

echo "[✔] VMware Fusion guest tools configured"
HOOKEOF
    chmod +x "${hooks_dir}/99-vmware-fusion-setup.hook.chroot"

    # --- VM performance tuning hook ---
    cat > "${hooks_dir}/98-vm-perf-tuning.hook.chroot" << 'PERFEOF'
#!/bin/bash
# Tune system for VM guest use
set -e

# Disable services irrelevant in a VM
for svc in bluetooth ModemManager; do
    systemctl disable "$svc" 2>/dev/null || true
done

# NTP time sync (VMware provides its own sync but keep NTP as fallback)
cat > /etc/systemd/timesyncd.conf << 'NTP'
[Time]
NTP=
FallbackNTP=0.debian.pool.ntp.org 1.debian.pool.ntp.org
NTP

# Faster boot: reduce GRUB timeout
if [[ -f /etc/default/grub ]]; then
    sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
    update-grub 2>/dev/null || true
fi

echo "[✔] VM performance tuning applied"
PERFEOF
    chmod +x "${hooks_dir}/98-vm-perf-tuning.hook.chroot"

    success "Package list, VMware hooks, and performance tuning configured ✔"
}

# ------------------------------------------------------------------------------
# STEP 6 — PRESEED (Unattended Installer for VMware Fusion)
# ------------------------------------------------------------------------------
configure_preseed() {
    if [[ "$PRESEED" != "true" || "$BUILD_TYPE" != "installer" ]]; then
        info "Preseed skipped (BUILD_TYPE=${BUILD_TYPE}, PRESEED=${PRESEED})"
        return
    fi

    step "[6/${TOTAL_STEPS}] 📋 Generating Preseed — Unattended VMware Install"

    local lb_dir="${BUILD_DIR}/live-build-config"
    local preseed_dir="${lb_dir}/kali-config/common/includes.installer"
    mkdir -p "$preseed_dir"

    # Build the package include string
    local pkgs="kali-linux-default open-vm-tools open-vm-tools-desktop fuse"
    [[ -n "$EXTRA_PKGS" ]] && pkgs="${pkgs} ${EXTRA_PKGS}"

    cat > "${preseed_dir}/preseed.cfg" << PRESEEDEOF
# ===========================================================================
# Kali Linux Preseed — VMware Fusion on MacBook
# Auto-generated by kali_fusion_vm_builder.sh
# ===========================================================================

# Locale + Keyboard
d-i debian-installer/locale string en_US
d-i keyboard-configuration/xkb-keymap select us

# Network — DHCP auto
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string kali
d-i netcfg/get_domain string local.lan
d-i netcfg/wireless_wep string

# Kali Mirror
d-i mirror/country string manual
d-i mirror/http/hostname string http.kali.org
d-i mirror/http/directory string /kali
d-i mirror/http/proxy string

# Clock
d-i clock-setup/utc boolean true
d-i time/zone string ${TZ}

# Disk — entire disk, LVM, single atomic partition
d-i partman-auto/method string lvm
d-i partman-auto/choose_recipe select atomic
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-auto-lvm/guided_size string max
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman-partitioning/confirm_write_new_label boolean true

# User — default kali/kali (CHANGE AFTER INSTALL!)
d-i passwd/root-login boolean false
d-i passwd/user-fullname string Kali
d-i passwd/username string kali
d-i passwd/user-password password kali
d-i passwd/user-password-again password kali

# Packages
tasksel tasksel/first multiselect standard
d-i pkgsel/include string ${pkgs}
popularity-contest popularity-contest/participate boolean false

# GRUB
d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string default
d-i grub-installer/with_other_os boolean true

# Finish + reboot
d-i finish-install/reboot_in_progress note
d-i cdrom-detect/eject boolean true
PRESEEDEOF

    warn "Default credentials set in preseed: ${BOLD}kali / kali${NC} — change immediately after install!"
    success "Preseed written → ${preseed_dir}/preseed.cfg ✔"
}

# ------------------------------------------------------------------------------
# STEP 7 — BUILD
# ------------------------------------------------------------------------------
run_build() {
    step "[7/${TOTAL_STEPS}] 🔨 Building Kali ISO"

    local lb_dir="${BUILD_DIR}/live-build-config"
    cd "$lb_dir"

    echo
    divider
    echo -e "  ${BOLD}Build Configuration Summary${NC}"
    divider
    echo -e "  Architecture   : ${BOLD}${ARCH}${NC}"
    echo -e "  Build type     : ${BOLD}${BUILD_TYPE}${NC}"
    echo -e "  Variant        : ${BOLD}${VARIANT}${NC}"
    echo -e "  Branch         : ${BOLD}${BRANCH}${NC}"
    echo -e "  Output dir     : ${BOLD}${OUTPUT_DIR}${NC}"
    echo -e "  Build dir      : ${BOLD}${lb_dir}${NC}"
    echo -e "  Preseed        : ${BOLD}${PRESEED}${NC}"
    [[ -n "$CACHE_MIRROR" ]] && echo -e "  APT mirror     : ${BOLD}${CACHE_MIRROR}${NC}"
    [[ -n "$EXTRA_PKGS" ]]  && echo -e "  Extra packages : ${BOLD}${EXTRA_PKGS}${NC}"
    divider
    echo

    # Clean previous build artifacts
    if [[ "$CLEAN_BUILD" == "true" ]] || [[ -d ".build" ]]; then
        info "Cleaning previous build artifacts..."
        lb clean --purge 2>&1 | tee -a "$LOGFILE" || true
    fi

    # Build arguments
    local args=(
        "--verbose"
        "--distribution" "${BRANCH}"
        "--arch" "${ARCH}"
    )
    [[ "$BUILD_TYPE" == "installer" ]] && args+=("--installer")
    [[ -n "$CACHE_MIRROR" ]] && args+=("--mirror" "$CACHE_MIRROR")

    warn "Starting build — this takes 45–120 min depending on network + CPU speed"
    warn "Follow along: ${BOLD}tail -f ${LOGFILE}${NC}"
    echo

    if ./build.sh "${args[@]}" 2>&1 | tee -a "$LOGFILE"; then
        success "Build process completed ✔"
    else
        error "Build failed — check log: ${LOGFILE}"
        exit 1
    fi

    # Locate output ISO
    local iso_src; iso_src=$(find "${lb_dir}/images" -name "*.iso" 2>/dev/null | head -1)
    if [[ -z "$iso_src" ]]; then
        error "No .iso found in ${lb_dir}/images/ — build may have failed silently"
        exit 1
    fi

    # Rename and move to output dir
    local iso_name="kali-fusion-${ARCH}-$(date +%Y%m%d).iso"
    local iso_dest="${OUTPUT_DIR}/${iso_name}"
    mkdir -p "$OUTPUT_DIR"
    mv "$iso_src" "$iso_dest"

    success "ISO moved to: ${BOLD}${iso_dest}${NC}"
}

# ------------------------------------------------------------------------------
# STEP 8 — POST-BUILD SUMMARY
# ------------------------------------------------------------------------------
post_build_summary() {
    step "[8/${TOTAL_STEPS}] ✅ Build Complete"

    local iso_file; iso_file=$(find "$OUTPUT_DIR" -name "kali-fusion-*.iso" | sort | tail -1)

    if [[ -z "$iso_file" ]]; then
        warn "Cannot locate output ISO in ${OUTPUT_DIR}"
        return
    fi

    local iso_size; iso_size=$(du -sh "$iso_file" | cut -f1)
    local iso_sha256; iso_sha256=$(sha256sum "$iso_file" | awk '{print $1}')
    local elapsed=$(( $(date +%s) - BUILD_START ))
    local mins=$(( elapsed / 60 ))
    local secs=$(( elapsed % 60 ))

    echo
    echo -e "${CYAN}${BOLD}"
    echo -e "╔══════════════════════════════════════════════════════════════════════╗"
    echo -e "║  🎉  BUILD SUCCESSFUL                                               ║"
    echo -e "╠══════════════════════════════════════════════════════════════════════╣"
    echo -e "║  ISO File   : $(basename "$iso_file")$(printf '%*s' $((50 - ${#iso_file##*/})) '')║"
    echo -e "║  Full Path  : ${iso_file}"
    echo -e "║  Size       : ${iso_size}"
    echo -e "║  Arch       : ${ARCH}"
    echo -e "║  Build Time : ${mins}m ${secs}s"
    echo -e "║  SHA256     : ${iso_sha256:0:40}..."
    echo -e "╠══════════════════════════════════════════════════════════════════════╣"
    echo -e "║  VMware Fusion Setup Steps:                                         ║"
    echo -e "║                                                                     ║"
    echo -e "║  1. Copy the .iso to your Mac                                       ║"
    echo -e "║  2. VMware Fusion → New Virtual Machine → Install from image        ║"
    echo -e "║  3. Select the .iso file above                                      ║"
    if [[ "$ARCH" == "arm64" ]]; then
    echo -e "║  4. ⚠️  OS Type = Debian 12.x 64-bit Arm  (CRITICAL for M-series)   ║"
    else
    echo -e "║  4. OS Type = Debian 12.x 64-bit                                   ║"
    fi
    echo -e "║  5. RAM: 4–8GB  |  CPUs: 2–4  |  Disk: 60–80GB  |  NVMe           ║"
    echo -e "║  6. Enable: Drag & Drop, Copy & Paste (Isolation settings)          ║"
    echo -e "║  7. Default login: kali / kali  →  CHANGE THIS PASSWORD!            ║"
    echo -e "║                                                                     ║"
    echo -e "║  Post-Install (if shared folders not working):                      ║"
    echo -e "║    kali-tweaks → Virtualization → VMware extra packages             ║"
    echo -e "║    sudo mount-shared-folders                                        ║"
    echo -e "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  📋 Full build log saved to: ${LOGFILE}"
    echo
}

# ------------------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------------------
main() {
    parse_args "$@"
    show_banner
    check_environment
    detect_arch
    install_dependencies
    setup_build_repo
    configure_build
    configure_preseed
    run_build
    post_build_summary
}

main "$@"
