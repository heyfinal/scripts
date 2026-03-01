#!/usr/bin/env bash
# =============================================================================
# Custom Kali Linux ISO Builder for iMac Systems
# =============================================================================
# Version: 2.1 (Refactored & Optimized)
# Date: February 17, 2026
# Purpose: Build a custom Kali ISO with GNOME, OpenClaw, Claude Code,
#          Signal Desktop, Ollama, and modern CLI tools for iMac hardware.
#
# REQUIREMENTS:
#   - Must be run on a Debian-based system (Kali Linux preferred)
#   - Root/sudo access required
#   - ~60GB free disk space
#   - Internet connection for package downloads
#
# USAGE:
#   chmod +x imac_kali_iso_build_2026.sh
#   sudo ./imac_kali_iso_build_2026.sh [--arch amd64|arm64] [--installer]
#
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# ANSI Colors & Glyphs
# -----------------------------------------------------------------------------
R='\033[0;31m'    G='\033[0;32m'    Y='\033[0;33m'
B='\033[0;34m'    M='\033[0;35m'    C='\033[0;36m'
W='\033[1;37m'    DIM='\033[2m'     BOLD='\033[1m'
BLINK='\033[5m'   RST='\033[0m'
OK="${G}[+]${RST}"  WARN="${Y}[!]${RST}"  ERR_="${R}[x]${RST}"  INFO="${C}[*]${RST}"

trap 'echo -e "\n${ERR_} ${R}BUILD FAILED at line $LINENO.${RST} Check output above."; stop_music; exit 1' ERR
trap 'stop_music' EXIT

# -----------------------------------------------------------------------------
# Progress Bar
# -----------------------------------------------------------------------------
TOTAL_PHASES=7
CURRENT_PHASE=0

phase_banner() {
    CURRENT_PHASE=$((CURRENT_PHASE + 1))
    local pct=$((CURRENT_PHASE * 100 / TOTAL_PHASES))
    local filled=$((pct / 5))
    local empty=$((20 - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    echo ""
    echo -e "${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    echo -e "${W}  PHASE ${CURRENT_PHASE}/${TOTAL_PHASES}  ${C}${bar}${RST}  ${W}${pct}%%${RST}  ${G}$1${RST}"
    echo -e "${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    echo ""
}

spinner() {
    local pid=$1
    local msg="${2:-Working...}"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${C}${frames[$((i % ${#frames[@]}))]}${RST} ${DIM}%s${RST}" "$msg"
        sleep 0.1
        i=$((i + 1))
    done
    printf "\r  ${G}✓${RST} %-60s\n" "$msg"
}

# -----------------------------------------------------------------------------
# MIDI Music Player (old school h4x0r vibes)
# -----------------------------------------------------------------------------
MUSIC_PID=""

generate_midi() {
    # Generate a MIDI file using Python - Megaman 2 Dr. Wily Stage 1 inspired melody
    local midi_file="/tmp/kali-build-bgm.mid"
    python3 - "$midi_file" << 'PYEOF'
import struct, sys

def write_midi(filename):
    """Generate an old-school chiptune MIDI - inspired by classic NES boss themes."""

    def var_len(val):
        result = []
        result.append(val & 0x7F)
        val >>= 7
        while val:
            result.append((val & 0x7F) | 0x80)
            val >>= 7
        return bytes(reversed(result))

    def note_on(delta, ch, note, vel=100):
        return var_len(delta) + bytes([0x90 | ch, note, vel])

    def note_off(delta, ch, note, vel=0):
        return var_len(delta) + bytes([0x80 | ch, note, vel])

    def program_change(ch, prog):
        return var_len(0) + bytes([0xC0 | ch, prog])

    def set_tempo(bpm):
        uspb = int(60_000_000 / bpm)
        return var_len(0) + b'\xFF\x51\x03' + uspb.to_bytes(3, 'big')

    tpq = 480  # ticks per quarter note
    q = tpq
    e = tpq // 2   # eighth
    s = tpq // 4   # sixteenth
    dt = tpq // 8  # demisemiquaver

    track_data = bytearray()
    track_data += set_tempo(160)

    # Channel 0: Lead - Square wave (program 80 = square lead)
    track_data += program_change(0, 80)
    # Channel 1: Bass - Sawtooth (program 81)
    track_data += program_change(1, 81)
    # Channel 2: Arpeggio - Pulse (program 80)
    track_data += program_change(2, 80)
    # Channel 9: Drums (GM percussion)

    # --- Dr. Wily-inspired melody (2 loops) ---
    melody = [
        # Intro riff (iconic rising pattern)
        (64, e), (67, e), (69, e), (71, s), (72, s),
        (74, e), (72, e), (71, q),
        (69, e), (67, e), (64, e), (67, e),
        (69, q+e), (67, s), (64, s),

        # Second phrase
        (60, e), (64, e), (67, e), (69, s), (71, s),
        (72, e), (74, e), (76, q),
        (74, e), (72, e), (71, e), (69, e),
        (67, q+e), (0, e),

        # Descending power phrase
        (76, s), (74, s), (72, s), (71, s),
        (69, e), (67, e), (64, q),
        (72, s), (71, s), (69, s), (67, s),
        (64, e), (60, e), (57, q),

        # Climax
        (69, e), (71, e), (72, e), (74, e),
        (76, q), (79, q),
        (76, e), (74, e), (72, e), (69, e),
        (71, q+e), (0, e),
    ]

    # Bass pattern
    bass_notes = [
        (40, q), (40, e), (47, e), (45, q), (45, e), (43, e),
        (40, q), (40, e), (47, e), (48, q), (47, e), (45, e),
        (43, q), (43, e), (40, e), (45, q), (45, e), (43, e),
        (40, q), (40, e), (43, e), (45, q), (47, q),
    ]

    # Drum pattern (kick, snare, hihat)
    kick = 36; snare = 38; hh_c = 42; hh_o = 46; crash = 49

    for loop in range(3):  # Loop 3x for ~90 seconds
        # Lead melody
        for note, dur in melody:
            if note == 0:
                track_data += note_on(0, 0, 60, 0)
                track_data += note_off(dur, 0, 60)
            else:
                track_data += note_on(0, 0, note, 95)
                track_data += note_off(dur - dt, 0, note)
                track_data += var_len(dt)  # tiny gap

        # Rewind timing for bass (play simultaneously via delta=0 trick)
        # Actually we need to interleave - let's just write bass after lead
        # For simplicity, overlay with channel 1 in a second track pass

    # --- Build bass track separately and merge ---
    bass_data = bytearray()
    bass_data += set_tempo(160)
    bass_data += program_change(1, 81)

    for loop in range(3):
        for note, dur in bass_notes:
            bass_data += note_on(0, 1, note, 80)
            bass_data += note_off(dur - dt, 1, note)
            bass_data += var_len(dt)
        # Pad bass to match melody length
        total_melody_ticks = sum(d for _, d in melody)
        total_bass_ticks = sum(d for _, d in bass_notes)
        if total_bass_ticks < total_melody_ticks:
            bass_data += var_len(total_melody_ticks - total_bass_ticks)

    # --- Drum track ---
    drum_data = bytearray()
    drum_data += set_tempo(160)

    drum_pattern = [
        (kick, s), (hh_c, s), (hh_c, s), (hh_c, s),
        (snare, s), (hh_c, s), (hh_o, s), (hh_c, s),
        (kick, s), (kick, s), (hh_c, s), (hh_c, s),
        (snare, s), (hh_c, s), (hh_c, s), (hh_o, s),
    ]

    for loop in range(3):
        total_melody_ticks = sum(d for _, d in melody)
        ticks_done = 0
        while ticks_done < total_melody_ticks:
            for hit, dur in drum_pattern:
                if ticks_done >= total_melody_ticks:
                    break
                drum_data += note_on(0, 9, hit, 90)
                drum_data += note_off(dur, 9, hit)
                ticks_done += dur

    # End of track markers
    eot = var_len(0) + b'\xFF\x2F\x00'
    track_data += eot
    bass_data += eot
    drum_data += eot

    def make_track_chunk(data):
        return b'MTrk' + struct.pack('>I', len(data)) + bytes(data)

    # MIDI header: format 1, 3 tracks
    header = b'MThd' + struct.pack('>I', 6) + struct.pack('>HHH', 1, 3, tpq)

    with open(filename, 'wb') as f:
        f.write(header)
        f.write(make_track_chunk(track_data))
        f.write(make_track_chunk(bass_data))
        f.write(make_track_chunk(drum_data))

    print(f"MIDI written to {filename}")

write_midi(sys.argv[1])
PYEOF
    echo "$midi_file"
}

start_music() {
    if ! command -v python3 &>/dev/null; then
        echo -e "${WARN} python3 not found, skipping BGM generation."
        return
    fi

    echo -e "${INFO} Generating MIDI file..."
    local midi_file
    midi_file=$(generate_midi)

    if [[ ! -f "$midi_file" ]]; then
        echo -e "${ERR_} MIDI file generation failed. File not found: $midi_file"
        return
    fi
    echo -e "${OK} MIDI file generated at: $midi_file"

    echo -e "${INFO} Searching for a MIDI player..."

    # --- Try Timidity ---
    if command -v timidity &>/dev/null; then
        echo -e "${INFO} Found MIDI player: timidity"
        echo -e "${DIM}   Attempting to play with command: timidity -idq '$midi_file' -Od --volume=60 &"
        timidity -idq "$midi_file" -Od --volume=60 &
        MUSIC_PID=$!
        sleep 1
        if ! kill -0 "$MUSIC_PID" 2>/dev/null; then
            echo -e "${WARN} timidity process exited immediately. It might have failed. Trying next player..."
            MUSIC_PID=""
        fi
    else
        echo -e "${DIM}   Player 'timidity' not found."
    fi

    # --- Try FluidSynth (if timidity failed) ---
    if [[ -z "$MUSIC_PID" ]] && command -v fluidsynth &>/dev/null; then
        echo -e "${INFO} Found MIDI player: fluidsynth"
        local sf2=""
        for f in /usr/share/sounds/sf2/*.sf2 /usr/share/soundfonts/*.sf2; do
            [[ -f "$f" ]] && sf2="$f" && break
        done
        if [[ -n "$sf2" ]]; then
            echo -e "${INFO} Found SoundFont: $sf2"
            echo -e "${DIM}   Attempting to play with command: fluidsynth -a alsa -g 0.5 -ni '$sf2' '$midi_file' &"
            fluidsynth -a alsa -g 0.5 -ni "$sf2" "$midi_file" &
            MUSIC_PID=$!
            sleep 1
            if ! kill -0 "$MUSIC_PID" 2>/dev/null; then
                echo -e "${WARN} fluidsynth process exited immediately. It might have failed. Trying next player..."
                MUSIC_PID=""
            fi
        else
            echo -e "${WARN} fluidsynth found, but no SoundFont (.sf2) file was found. Skipping."
        fi
    elif [[ -z "$MUSIC_PID" ]]; then
        echo -e "${DIM}   Player 'fluidsynth' not found."
    fi

    # --- Try aplaymidi (if above failed) ---
    if [[ -z "$MUSIC_PID" ]] && command -v aplaymidi &>/dev/null; then
        echo -e "${INFO} Found MIDI player: aplaymidi"
        local port
        port=$(aplaymidi -l 2>/dev/null | awk 'NR>1 && /TiMidity|FluidSynth/{print $1; exit}')
        if [[ -n "$port" ]]; then
            echo -e "${INFO} Found synthesizer on ALSA port: $port"
            echo -e "${DIM}   Attempting to play with command: aplaymidi -p '$port' '$midi_file' &"
            aplaymidi -p "$port" "$midi_file" &
            MUSIC_PID=$!
            sleep 1
            if ! kill -0 "$MUSIC_PID" 2>/dev/null; then
                echo -e "${WARN} aplaymidi process exited immediately. It might have failed. Trying next player..."
                MUSIC_PID=""
            fi
        else
            echo -e "${WARN} aplaymidi found, but no active synthesizer port (like TiMidity or FluidSynth) was detected. Skipping."
        fi
    elif [[ -z "$MUSIC_PID" ]]; then
        echo -e "${DIM}   Player 'aplaymidi' not found."
    fi

    # --- Try VLC (if above failed) ---
    if [[ -z "$MUSIC_PID" ]] && command -v vlc &>/dev/null; then
        echo -e "${INFO} Found MIDI player: vlc"
        echo -e "${DIM}   Attempting to play with command: cvlc --play-and-exit --no-video --volume 180 '$midi_file' &"
        cvlc --play-and-exit --no-video --volume 180 "$midi_file" &
        MUSIC_PID=$!
        sleep 1
        if ! kill -0 "$MUSIC_PID" 2>/dev/null; then
            echo -e "${WARN} vlc process exited immediately. It might have failed. Trying next player..."
            MUSIC_PID=""
        fi
    elif [[ -z "$MUSIC_PID" ]]; then
        echo -e "${DIM}   Player 'vlc' not found."
    fi
    
    # --- Try mpv (if above failed) ---
    if [[ -z "$MUSIC_PID" ]] && command -v mpv &>/dev/null; then
        echo -e "${INFO} Found MIDI player: mpv"
        echo -e "${DIM}   Attempting to play with command: mpv --no-video --volume=50 --loop=inf '$midi_file' &"
        mpv --no-video --volume=50 --loop=inf "$midi_file" &
        MUSIC_PID=$!
        sleep 1
        if ! kill -0 "$MUSIC_PID" 2>/dev/null; then
            echo -e "${WARN} mpv process exited immediately. It might have failed."
            MUSIC_PID=""
        fi
    elif [[ -z "$MUSIC_PID" ]]; then
        echo -e "${DIM}   Player 'mpv' not found."
    fi

    if [[ -n "$MUSIC_PID" ]]; then
        echo -e "${OK} ${M}♪ BGM: NES-style chiptune loaded (PID: $MUSIC_PID) ♪${RST}"
    else
        echo -e "${ERR_} No functional MIDI player could be started."
        echo -e "${Y}   Suggestions:${RST}"
        echo -e "${Y}   1. Ensure you are on a system with a configured audio output.${RST}"
        echo -e "${Y}   2. Install a MIDI player and soundfont: apt install timidity fluid-soundfont-gm${RST}"
        echo -e "${Y}   3. Check the build log for specific errors from the players above.${RST}"
    fi
}

stop_music() {
    if [[ -n "${MUSIC_PID:-}" ]] && kill -0 "$MUSIC_PID" 2>/dev/null; then
        kill "$MUSIC_PID" 2>/dev/null
        wait "$MUSIC_PID" 2>/dev/null
    fi
    rm -f /tmp/kali-build-bgm.mid
}

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
BUILD_ARCH="amd64" # Default architecture
INSTALLER_FLAG=""
BUILD_DIR="/opt/kali-build"
LOG_FILE="/var/log/kali-iso-build-$(date +%Y%m%d-%H%M%S).log"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            if [[ -n "$2" && "$2" != --* ]]; then
                BUILD_ARCH="$2"
                shift 2
            else
                echo "ERROR: --arch requires an argument (amd64 or arm64)."
                exit 1
            fi
            ;;
        --installer)
            INSTALLER_FLAG="--installer"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--arch amd64|arm64] [--installer]"
            echo ""
            echo "Options:"
            echo "  --arch        Target architecture (default: amd64)"
            echo "  --installer   Build installer ISO (not just live)"
            echo ""
            echo "This script must be run on Debian/Kali with root privileges."
            exit 0
            ;;
        *)
            echo "WARNING: Unknown argument '$1' (ignored)."
            shift
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Preflight Checks
# -----------------------------------------------------------------------------
clear 2>/dev/null || true
echo ""
echo -e "${R}    ██╗  ██╗ █████╗ ██╗     ██╗    ██████╗ ██╗   ██╗██╗██╗     ██████╗ ${RST}"
echo -e "${R}    ██║ ██╔╝██╔══██╗██║     ██║    ██╔══██╗██║   ██║██║██║     ██╔══██╗${RST}"
echo -e "${R}    █████╔╝ ███████║██║     ██║    ██████╔╝██║   ██║██║██║     ██║  ██║${RST}"
echo -e "${R}    ██╔═██╗ ██╔══██║██║     ██║    ██╔══██╗██║   ██║██║██║     ██║  ██║${RST}"
echo -e "${R}    ██║  ██╗██║  ██║███████╗██║    ██████╔╝╚██████╔╝██║███████╗██████╔╝${RST}"
echo -e "${R}    ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝    ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝ ${RST}"
echo ""
echo -e "${C}    ██╗███╗   ███╗ █████╗  ██████╗    ███████╗██████╗ ██╗████████╗██╗ ██████╗ ███╗   ██╗${RST}"
echo -e "${C}    ██║████╗ ████║██╔══██╗██╔════╝    ██╔════╝██╔══██╗██║╚══██╔══╝██║██╔═══██╗████╗  ██║${RST}"
echo -e "${C}    ██║██╔████╔██║███████║██║         █████╗  ██║  ██║██║   ██║   ██║██║   ██║██╔██╗ ██║${RST}"
echo -e "${C}    ██║██║╚██╔╝██║██╔══██║██║         ██╔══╝  ██║  ██║██║   ██║   ██║██║   ██║██║╚██╗██║${RST}"
echo -e "${C}    ██║██║ ╚═╝ ██║██║  ██║╚██████╗    ███████╗██████╔╝██║   ██║   ██║╚██████╔╝██║ ╚████║${RST}"
echo -e "${C}    ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝    ╚══════╝╚═════╝ ╚═╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝${RST}"
echo ""
echo -e "${DIM}    ┌──────────────────────────────────────────────────────────────────────┐${RST}"
echo -e "${DIM}    │${RST}  ${G}>>>${RST} ${W}Custom ISO Builder v2.1${RST}           ${DIM}Target:${RST} ${Y}iMac (${BUILD_ARCH})${RST}          ${DIM}│${RST}"
echo -e "${DIM}    │${RST}  ${G}>>>${RST} ${W}GNOME + OpenClaw + Claude Code${RST}    ${DIM}Date:${RST}   ${Y}$(date '+%Y-%m-%d %H:%M')${RST}   ${DIM}│${RST}"
echo -e "${DIM}    │${RST}  ${G}>>>${RST} ${W}Signal + Ollama + CLI Tools${RST}       ${DIM}PID:${RST}    ${Y}$$${RST}                ${DIM}│${RST}"
echo -e "${DIM}    └──────────────────────────────────────────────────────────────────────┘${RST}"
echo ""
echo -e "    ${DIM}\"${M}There is no spoon.${DIM}\"  ${DIM}-- The Matrix, 1999${RST}"
echo ""
sleep 1

# Must be root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (use sudo)."
    exit 1
fi

# Must be Debian-based
if ! command -v apt &>/dev/null; then
    echo "ERROR: This script must be run on a Debian-based system."
    echo "       Kali Linux is recommended. macOS is NOT supported."
    echo ""
    echo "Options:"
    echo "  1. Run on your Kali server (ssh daniel@192.168.1.151)"
    echo "  2. Use a Kali VM or Docker container"
    echo "  3. Use a cloud Debian/Kali instance"
    exit 1
fi

# Check disk space (need ~60GB)
AVAIL_KB=$(df --output=avail /opt 2>/dev/null | tail -1 || df -k / | awk 'NR==2{print $4}')
AVAIL_GB=$((AVAIL_KB / 1048576))
if [[ $AVAIL_GB -lt 40 ]]; then
    echo "WARNING: Only ${AVAIL_GB}GB free space available. Recommend 60GB+."
    echo "         Build may fail if space runs out."
    read -rp "Continue anyway? [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]] || exit 1
fi

echo -e "${OK} Preflight checks passed."
echo -e "${OK} Build log: ${W}$LOG_FILE${RST}"
echo ""

# Fire up the chiptune BGM
start_music
BUILD_START=$(date +%s)
sleep 0.5

# Tee output to log
exec > >(tee -a "$LOG_FILE") 2>&1

# -----------------------------------------------------------------------------
# Phase 1: Install Prerequisites
# -----------------------------------------------------------------------------
phase_banner "Installing build prerequisites"

apt update
apt install -y \
    git \
    live-build \
    simple-cdd \
    cdebootstrap \
    curl \
    wget \
    debootstrap

# If not on Kali, install the Kali archive keyring and setup repository
if ! dpkg -l kali-archive-keyring &>/dev/null; then
    echo -e "${OK} Installing Kali archive keyring and repository..."
    # Add Kali repository
    echo "deb http://http.kali.org/kali kali-rolling main contrib non-free" | tee /etc/apt/sources.list.d/kali.list
    apt update
    apt install -y kali-archive-keyring
fi

# Ensure debootstrap knows about Kali mirrors if running on non-Kali Debian
if ! grep -q "kali" /usr/share/debootstrap/scripts/kali &>/dev/null; then
    echo -e "${OK} Configuring debootstrap for Kali..."
    (echo "default_mirror http://http.kali.org/kali"; cat /usr/share/debootstrap/scripts/sid) > /tmp/kali_debootstrap_script
    mv /tmp/kali_debootstrap_script /usr/share/debootstrap/scripts/kali
    chmod +x /usr/share/debootstrap/scripts/kali
    ln -sf kali /usr/share/debootstrap/scripts/kali-rolling
fi

echo -e "${OK} Prerequisites installed."

# -----------------------------------------------------------------------------
# Phase 2: Clone live-build-config
# -----------------------------------------------------------------------------
phase_banner "Setting up live-build-config"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [[ -d live-build-config/.git ]]; then
    echo -e "${OK} live-build-config already cloned, updating..."
    cd live-build-config
    git pull --ff-only
else
    echo -e "${OK} Cloning official Kali live-build-config..."
    git clone https://gitlab.com/kalilinux/build-scripts/live-build-config.git
    cd live-build-config
fi

echo -e "${OK} Working directory: $(pwd)"

# -----------------------------------------------------------------------------
# Phase 3: Configure Package Lists
# -----------------------------------------------------------------------------
phase_banner "Configuring package lists"

# Ensure the GNOME variant directory exists
mkdir -p kali-config/variant-gnome/package-lists/

# Create comprehensive package list for the GNOME variant
cat > kali-config/variant-gnome/package-lists/kali.list.chroot << PKGEOF
# ===========================================
# Kali Linux iMac Custom Build - Package List
# ===========================================

# --- Desktop Environment: GNOME ---
kali-desktop-gnome
kali-defaults
kali-root-login
kali-themes

# --- Kali Tool Metapackages ---
kali-linux-default
kali-tools-top10
kali-tools-web
kali-tools-exploitation
kali-tools-information-gathering
kali-tools-passwords
kali-tools-wireless
kali-tools-sniffing-spoofing
kali-tools-forensics
kali-tools-crypto-stego
kali-tools-reporting

# --- System Essentials ---
openssh-server
openssh-client
network-manager
network-manager-gnome
firmware-linux
firmware-linux-nonfree
firmware-misc-nonfree
firmware-realtek

# --- iMac Hardware Support ---
# Broadcom WiFi (covers BCM43xx, BCM4360, BCM943602)
broadcom-sta-dkms
firmware-b43-installer
firmware-brcm80211
# Intel WiFi (2020+ Intel iMacs)
firmware-iwlwifi
# GPU support
xserver-xorg-video-amdgpu
xserver-xorg-video-radeon
xserver-xorg-video-intel
# Apple hardware utilities
linux-headers-${BUILD_ARCH:-amd64}
dkms
efibootmgr
grub-efi-amd64
# HiDPI / Retina display support
gnome-tweaks
dconf-editor

# --- Modern CLI Tools ---
zsh
zsh-autosuggestions
zsh-syntax-highlighting
tmux
fzf
ripgrep
fd-find
bat
eza
htop
btop
ncdu
duf
procs
dust
neofetch
grc
jq
yq
httpie
tldr
tree
unzip
p7zip-full
rsync
curl
wget
git
git-lfs

# --- Development Tools ---
build-essential
gcc
g++
make
cmake
python3
python3-pip
python3-venv
python3-dev
nodejs
npm
golang
rustc
cargo

# --- Container & Orchestration ---
docker.io
docker-compose

# --- Networking Tools ---
nmap
netcat-openbsd
tcpdump
wireshark
traceroute
dnsutils
whois
net-tools
iproute2
iptables

# --- Editors ---
nano
vim

# --- Custom Applications ---
signal-desktop

# --- Misc Utilities ---
source-highlight
pv
pigz
strace
lsof
sysstat
iotop
gnupg
pass
xclip
PKGEOF

echo -e "${OK} Package list created."

# Also create a custom additions list for packages not in Kali repos
cat > kali-config/variant-gnome/package-lists/custom.list.chroot << 'CUSTEOF'
# Additional packages for custom tools
apt-transport-https
ca-certificates
gnupg2
software-properties-common
nodejs
CUSTEOF

echo -e "${OK} Custom package list created."

# -----------------------------------------------------------------------------
# Phase 4: Create Build Hooks
# -----------------------------------------------------------------------------
phase_banner "Creating build hooks"

# Hooks go in kali-config/common/hooks/live/ with .hook.chroot suffix
mkdir -p kali-config/common/hooks/live/

# --- Hook 01: System Configuration ---
cat > kali-config/common/hooks/live/01-system-config.hook.chroot << 'HOOKEOF'
#!/bin/sh
set -e
echo ">>> [Hook 01] System configuration..."

# SSH: Enable and harden for key-only access from control machine
systemctl enable ssh

mkdir -p /etc/ssh/sshd_config.d/
cat > /etc/ssh/sshd_config.d/hardened.conf << 'SSHCONF'
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
X11Forwarding yes
AllowAgentForwarding yes
ClientAliveInterval 60
ClientAliveCountMax 10
MaxSessions 10
SSHCONF

# Set default shell to zsh for root
chsh -s /usr/bin/zsh root

# Configure GDM for auto HiDPI (Retina displays)
mkdir -p /etc/dconf/db/gdm.d/
cat > /etc/dconf/db/gdm.d/01-hidpi << 'DCONF'
[org/gnome/desktop/interface]
scaling-factor=uint32 2
text-scaling-factor=1.25
DCONF

# GNOME terminal profile for dark mode
mkdir -p /etc/dconf/db/local.d/
cat > /etc/dconf/db/local.d/01-gnome-settings << 'DCONF'
[org/gnome/desktop/interface]
color-scheme='prefer-dark'
gtk-theme='Kali-Dark'
icon-theme='Flat-Remix-Blue-Dark'
monospace-font-name='JetBrains Mono 11'

[org/gnome/desktop/peripherals/touchpad]
tap-to-click=true
natural-scroll=true

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'

[org/gnome/terminal/legacy]
default-show-menubar=false
theme-variant='dark'
DCONF

# Apply dconf settings
dconf update

echo ">>> [Hook 01] System configuration complete."
HOOKEOF

# --- Hook 02: External Repos & Tools ---
cat > kali-config/common/hooks/live/02-external-repos-tools.hook.chroot << 'HOOKEOF'
#!/bin/sh
set -e
echo ">>> [Hook 02] Configuring external repositories and tools..."

# --- Signal Desktop Repo ---
echo "--> Adding Signal Desktop repository..."
wget -qO- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > /usr/share/keyrings/signal-desktop-keyring.gpg
# The 'xenial' distribution is used for historical reasons but works on modern Debian derivatives.
cat > /etc/apt/sources.list.d/signal-desktop.list << 'SIGNAL'
deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main
SIGNAL

# --- Node.js 22 LTS Repo ---
echo "--> Adding Node.js v22 repository..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -

# --- Update sources after adding new repos ---
echo "--> Updating package lists from new repositories..."
apt-get update

# --- Install Global NPM Packages ---
echo "--> Installing global NPM packages and AI tools..."
# Configure npm global directory (no sudo needed for global installs)
mkdir -p /root/.npm-global
npm config set prefix /root/.npm-global
export PATH="/root/.npm-global/bin:$PATH"

# Install Claude Code, open-codex, and other tools
npm install -g \
    @anthropic-ai/claude-code \
    open-codex \
    tsx \
    typescript \
    pnpm \
    yarn \
    nodemon \
    serve \
    pm2 \
    zx

echo ">>> [Hook 02] External repos and tools setup complete."
HOOKEOF

# --- Hook 03: OpenClaw ---
cat > kali-config/common/hooks/live/03-openclaw.hook.chroot << 'HOOKEOF'
#!/bin/sh
set -e
echo ">>> [Hook 03] Installing OpenClaw AI OS..."

# Install OpenClaw via npm (primary method)
export PATH="/root/.npm-global/bin:$PATH"

npm install -g openclaw || \
    # Fallback: install via pip if npm fails
    pip3 install openclaw

# Install clawhub CLI
npm install -g clawhub

# Create default OpenClaw config directory
mkdir -p /root/.openclaw/
cat > /root/.openclaw/openclaw.json << 'OCCONF'
{
    "gateway": {
        "port": 18789,
        "auth": {
            "enabled": false
        }
    },
    "models": {
        "primary": "ollama/llama3:8b",
        "fallback": "ollama/deepseek-coder:6.7b"
    },
    "skills": {
        "autoload": true,
        "sources": ["clawhub"]
    }
}
OCCONF

echo ">>> [Hook 03] OpenClaw installation done."
HOOKEOF

# --- Hook 04: Ollama (binary only, no model pulls) ---
cat > kali-config/common/hooks/live/04-ollama.hook.chroot << 'HOOKEOF'
#!/bin/sh
set -e
echo ">>> [Hook 04] Installing Ollama..."

# Install Ollama binary only - models are too large for ISO
curl -fsSL https://ollama.com/install.sh | sh

# Disable auto-start (user enables when needed)
systemctl disable ollama

# Create a first-boot model pull script
cat > /usr/local/bin/ollama-setup << 'SCRIPT'
#!/bin/bash
echo "=== Ollama Model Setup ==="
echo "This will download AI models (~15GB total). Ensure you have space and bandwidth."
echo ""
read -rp "Continue? [y/N] " response
[[ "$response" =~ ^[Yy]$ ]] || exit 0

# Start Ollama
sudo systemctl start ollama
sleep 5

echo "[1/4] Pulling llama3:8b (general purpose)..."
ollama pull llama3:8b

echo "[2/4] Pulling deepseek-coder:6.7b (coding)..."
ollama pull deepseek-coder:6.7b

echo "[3/4] Pulling codellama:7b (code completion)..."
ollama pull codellama:7b

echo "[4/4] Pulling nomic-embed-text (embeddings)..."
ollama pull nomic-embed-text

echo ""
echo "=== Done! Models installed. ==="
echo "Enable auto-start: sudo systemctl enable --now ollama"
SCRIPT
chmod +x /usr/local/bin/ollama-setup

echo ">>> [Hook 04] Ollama installed. Run 'ollama-setup' after boot to pull models."
HOOKEOF

# --- Hook 05: iMac Hardware Tweaks ---
cat > kali-config/common/hooks/live/05-imac-hardware.hook.chroot << 'HOOKEOF'
#!/bin/sh
set -e
echo ">>> [Hook 05] Configuring iMac hardware support..."

# Broadcom WiFi module loading
cat > /etc/modprobe.d/broadcom-wifi.conf << 'MODCONF'
# Blacklist conflicting drivers for Broadcom cards
blacklist b43
blacklist bcma
blacklist brcmsmac
blacklist ssb
# Use broadcom-sta (wl) driver
# Uncomment below if using broadcom-sta-dkms:
# install wl /sbin/modprobe --ignore-install wl
MODCONF

# Apple keyboard function key defaults
cat > /etc/modprobe.d/apple-hid.conf << 'MODCONF'
# Use F1-F12 as standard function keys (not media keys)
options hid_apple fnmode=2
# Swap Option/Command keys to match standard keyboard layout
options hid_apple swap_opt_cmd=1
MODCONF

# T2 Mac workaround for wpa_supplicant regression
cat > /etc/modprobe.d/brcmfmac-t2.conf << 'MODCONF'
# Fix for wpa_supplicant 2.11+ regression on T2 Macs
# Disable 802.11r and SAE offload
options brcmfmac feature_disable=0x82000
MODCONF

# EFI boot configuration
mkdir -p /etc/default/
if [ -f /etc/default/grub ]; then
    # Ensure GRUB works with Mac EFI
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub
    # Add video mode for Retina displays
    sed -i 's/^#*GRUB_GFXMODE=.*/GRUB_GFXMODE=1920x1080/' /etc/default/grub
fi

# Power management for iMac (no battery, disable laptop features)
cat > /etc/udev/rules.d/99-imac-power.rules << 'UDEV'
# iMac is always on AC power - optimize for performance
SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="/usr/bin/cpupower frequency-set -g performance"
UDEV

echo ">>> [Hook 06] iMac hardware configuration done."
HOOKEOF

# Make all hooks executable
chmod +x kali-config/common/hooks/live/*.hook.chroot

echo -e "${OK} All build hooks created and made executable."

# -----------------------------------------------------------------------------
# Phase 5: Custom File Overlays (includes.chroot)
# -----------------------------------------------------------------------------
phase_banner "Creating file overlays"

# Files placed in includes.chroot mirror the filesystem
mkdir -p kali-config/common/includes.chroot/etc/skel/
mkdir -p kali-config/common/includes.chroot/root/
mkdir -p kali-config/common/includes.chroot/usr/local/bin/

# --- SSH Authorized Keys (passwordless access from control Mac) ---
mkdir -p kali-config/common/includes.chroot/root/.ssh/
chmod 700 kali-config/common/includes.chroot/root/.ssh/

cat > kali-config/common/includes.chroot/root/.ssh/authorized_keys << 'AUTHEOF'
# daniel's Mac mini (ed25519 - primary)
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFtHRzK6TTCG3H/br0GG5WXCA6fxnCfdHHwI12NLXDvy daniel@dmgs-Mac-mini
# daniel's Mac (RSA - fallback)
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC6jN8UwNALGL9UYpAZRM04ZKm00+8j0tvPikbrrj2Yj2TbXaZ4HhkTnP0lgO3drsZVVe+EEciLP+PTtGhdDHNRN7wyY6jcDgyf5rZO13HEgDlz4X3cxVUVZHzrQWcPG9JG3CHPk8RP7otCJ/31scRs5Pq7QLLB8gM8zJjM5FevmFN6clJ7GHxLJ/aKsr+TgNc5gcfBy90PXe5DjQPs7HXbDSDs3CRnmYKAQIok3QH/fqaxzPD42RLgNrsgZy4tzx0IdgiQHPzigEDPPPSxR9QAQe5DdPMoghrvhsIHYaeUhGwL+51/d2V4nuKhhRmokGHd84Oy+m6lRiin2aAwFcmGn526JftHpd9hlSTsLfm68wUvEiyZ1P0eXkPdw5MXXBm4EdDK8Ln85E0dfJSxYBpOSDrdUpDyp5HLJhuThl0W1fYjXwbZ7ZmWbf5VVDF8I+kxLmIu61Mh0AeGEPGJzdDKaE78xdVkpJoxgb/yTkIYKlYMVx5Xllhpc8vmzImndlixV/X8+PiobfrCvs73j+sIArQGSeLzdUdnEreGpzg3vBLoJZN0kwJtYFE/rc7ejK4k+Bsa6zgrV1PtYIFMzWZHl+g5/lHnXCB/fjPFlaUq5YgQxhjkuutPWdIDdAkmoHCLuBFn8P0+QN/jdL7rEu4+SbgoByKtSAZPOz7vDellew== daniel@Mac.attlocal.net
AUTHEOF
chmod 600 kali-config/common/includes.chroot/root/.ssh/authorized_keys

# Copy to skel so any new user also gets the keys
mkdir -p kali-config/common/includes.chroot/etc/skel/.ssh/
cp kali-config/common/includes.chroot/root/.ssh/authorized_keys \
   kali-config/common/includes.chroot/etc/skel/.ssh/authorized_keys
chmod 700 kali-config/common/includes.chroot/etc/skel/.ssh/
chmod 600 kali-config/common/includes.chroot/etc/skel/.ssh/authorized_keys

echo -e "${OK} SSH authorized keys baked in (passwordless access from control Mac)."

# --- Custom .zshrc ---
cat > kali-config/common/includes.chroot/etc/skel/.zshrc << 'ZSHEOF'
# ============================================
# KALI LINUX iMAC - ZSH CONFIGURATION
# Modern CLI replacements + AI tool integration
# ============================================

# ============================================
# ZSH PLUGIN CONFIGURATION (managed by apt)
# ============================================

# Source plugins installed via apt.
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Set a simple, clean prompt theme.
PROMPT='%F{blue}%~%f %F{red}$%f '

# ============================================
# MODERN CLI ALIASES
# ============================================

# Modern replacements (check if installed before aliasing)
command -v eza    &>/dev/null && alias ls='eza --icons --group-directories-first'
command -v eza    &>/dev/null && alias ll='eza -l --icons --git'
command -v eza    &>/dev/null && alias la='eza -la --icons --git'
command -v eza    &>/dev/null && alias lt='eza --tree --level=2 --icons'
# Prefer batcat (Debian) over bat
if command -v batcat &>/dev/null; then
  alias cat='batcat --paging=never'
elif command -v bat &>/dev/null; then
  alias cat='bat --paging=never'
fi
command -v rg     &>/dev/null && alias grep='rg'
command -v fdfind &>/dev/null && alias fd='fdfind'
command -v htop   &>/dev/null && alias top='htop'
command -v procs  &>/dev/null && alias ps='procs'
command -v dust   &>/dev/null && alias du='dust'
command -v duf    &>/dev/null && alias df='duf'
command -v grc    &>/dev/null && alias ping='grc ping'
command -v grc    &>/dev/null && alias traceroute='grc traceroute'
command -v grc    &>/dev/null && alias nmap='grc nmap'

# Safe defaults
alias mkdir='mkdir -p'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -i'
alias ip='ip --color=auto'
alias diff='diff --color=auto'

# Git shortcuts
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --all'
alias gd='git diff'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gb='git branch'

# Docker shortcuts
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlogs='docker logs -f'

# Kubernetes shortcuts
alias k='kubectl'
alias kg='kubectl get'
alias kgp='kubectl get pods'
alias kaf='kubectl apply -f'

# AI tool aliases
alias cc='claude'
alias codex='open-codex'
alias claw='clawhub'
alias oc='openclaw'
alias o='ollama'
alias ols='ollama list'
alias orun='ollama run'

# Network tools
alias ports='ss -tulanp'
alias myip='curl -s ifconfig.me'
alias localip="ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}'"

# System monitoring
alias meminfo='free -h'
alias cpuinfo='lscpu'
alias diskinfo='df -h'
alias sysinfo='neofetch'

# fzf + bat preview
command -v fzf &>/dev/null && command -v batcat &>/dev/null && \
    alias f='fzf --preview "batcat --color=always {}"'

# ============================================
# PATH CONFIGURATION
# ============================================
typeset -U path  # Deduplicate PATH entries (zsh feature)

path=(
    $HOME/.local/bin
    $HOME/bin
    $HOME/.npm-global/bin
    $HOME/.cargo/bin
    $HOME/go/bin
    /usr/local/bin
    /usr/local/sbin
    $path
)

export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export GOPATH="$HOME/go"

# ============================================
# ENVIRONMENT VARIABLES
# ============================================
export EDITOR=nano
export VISUAL=nano
export PAGER=less
export LESS='-R -F -X -i'
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Zsh history
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY

# Man pages with color
export MANPAGER="less -R"

# ============================================
# CUSTOM FUNCTIONS
# ============================================

# Create directory and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# Extract any archive
extract() {
    if [[ ! -f "$1" ]]; then
        echo "Error: '$1' is not a valid file."
        return 1
    fi
    case "$1" in
        *.tar.bz2)  tar xjf "$1"    ;;
        *.tar.gz)   tar xzf "$1"    ;;
        *.tar.xz)   tar xJf "$1"    ;;
        *.tar.zst)  tar --zstd -xf "$1" ;;
        *.bz2)      bunzip2 "$1"    ;;
        *.rar)      unrar x "$1"    ;;
        *.gz)       gunzip "$1"     ;;
        *.tar)      tar xf "$1"     ;;
        *.tbz2)     tar xjf "$1"    ;;
        *.tgz)      tar xzf "$1"    ;;
        *.zip)      unzip "$1"      ;;
        *.Z)        uncompress "$1" ;;
        *.7z)       7z x "$1"       ;;
        *.deb)      ar x "$1"       ;;
        *.xz)       xz -d "$1"      ;;
        *)          echo "Cannot extract '$1' - unknown format." ;;
    esac
}

# Quick HTTP server
serve-dir() { python3 -m http.server "${1:-8000}"; }

# Docker shell into container
dsh() { docker exec -it "$1" /bin/bash; }

# ============================================
# TMUX AUTO-ATTACH (only in interactive non-SSH sessions)
# ============================================
if command -v tmux &>/dev/null && [[ -z "$TMUX" ]] && [[ -z "$SSH_CONNECTION" ]] && [[ -z "$NOTMUX" ]] && [[ $- == *i* ]]; then
    tmux attach -t main 2>/dev/null || tmux new -s main
fi
# Escape hatch: run `NOTMUX=1 zsh` to get a plain shell
ZSHEOF

# Copy .zshrc to root as well
cp kali-config/common/includes.chroot/etc/skel/.zshrc \
   kali-config/common/includes.chroot/root/.zshrc

# --- First-boot welcome script ---
cat > kali-config/common/includes.chroot/usr/local/bin/kali-imac-setup << 'SETUPEOF'
#!/bin/bash
# ===========================================
# Kali Linux iMac - First Boot Setup
# ===========================================
echo ""
echo "=========================================="
echo "  Kali Linux iMac Edition - First Boot"
echo "=========================================="
echo ""
echo "Post-installation steps:"
echo ""
echo "  1. Pull Ollama models:    ollama-setup"
echo "  2. Start OpenClaw:        openclaw gateway start"
echo "  3. Configure Claude Code: claude-code --configure"
echo "  4. Install ClawHub skills: clawhub search security"
echo ""
echo "Hardware tips for iMac:"
echo "  - WiFi: If Broadcom WiFi not working, try:"
echo "      sudo modprobe wl"
echo "    or for T2 Macs:"
echo "      sudo modprobe brcmfmac"
echo ""
echo "  - HiDPI: If text is too small on Retina display:"
echo "      gsettings set org.gnome.desktop.interface scaling-factor 2"
echo ""
echo "  - Apple keyboard function keys:"
echo "      Already configured (F1-F12 mode)"
echo ""
echo "=========================================="
SETUPEOF
chmod +x kali-config/common/includes.chroot/usr/local/bin/kali-imac-setup

# --- tmux config ---
cat > kali-config/common/includes.chroot/etc/skel/.tmux.conf << 'TMUXEOF'
# Modern tmux configuration
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"
set -g mouse on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -s escape-time 0

# Prefix: Ctrl-a (easier than Ctrl-b)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Split panes with | and -
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# Vim-style pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Reload config
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Status bar
set -g status-style bg=black,fg=white
set -g status-left "#[fg=green]#S "
set -g status-right "#[fg=cyan]%H:%M #[fg=yellow]%Y-%m-%d"
TMUXEOF
cp kali-config/common/includes.chroot/etc/skel/.tmux.conf \
   kali-config/common/includes.chroot/root/.tmux.conf

echo -e "${OK} File overlays created."

# -----------------------------------------------------------------------------
# Phase 6: Build the ISO
# -----------------------------------------------------------------------------
phase_banner "Building the ISO (this is the big one)"
echo -e "  ${INFO} Architecture: ${W}$BUILD_ARCH${RST}"
echo -e "  ${INFO} Variant:      ${W}gnome${RST}"
echo -e "  ${INFO} Installer:    ${W}${INSTALLER_FLAG:-live only}${RST}"
echo ""
echo -e "  ${Y}⏳ This will take 30-90 minutes. Grab a coffee. The chiptune's got you.${RST}"
echo ""

# Clean any previous build artifacts
./build.sh --clean 2>/dev/null || true

# Build!
./build.sh \
    --verbose \
    --variant gnome \
    --arch "$BUILD_ARCH" \
    ${INSTALLER_FLAG:+"$INSTALLER_FLAG"}

# -----------------------------------------------------------------------------
# Phase 7: Output Results
# -----------------------------------------------------------------------------
phase_banner "Complete"

# Stop the tunes
stop_music

BUILD_END=$(date +%s)
BUILD_DURATION=$(( (BUILD_END - BUILD_START) / 60 ))

echo ""
echo -e "${G}    ╔══════════════════════════════════════════════════════════════════╗${RST}"
echo -e "${G}    ║${RST}                                                                  ${G}║${RST}"
echo -e "${G}    ║${RST}   ${W}██████╗  ██████╗ ███╗   ██╗███████╗██╗${RST}                       ${G}║${RST}"
echo -e "${G}    ║${RST}   ${W}██╔══██╗██╔═══██╗████╗  ██║██╔════╝██║${RST}                       ${G}║${RST}"
echo -e "${G}    ║${RST}   ${W}██║  ██║██║   ██║██╔██╗ ██║█████╗  ██║${RST}                       ${G}║${RST}"
echo -e "${G}    ║${RST}   ${W}██║  ██║██║   ██║██║╚██╗██║██╔══╝  ╚═╝${RST}                       ${G}║${RST}"
echo -e "${G}    ║${RST}   ${W}██████╔╝╚██████╔╝██║ ╚████║███████╗██╗${RST}                       ${G}║${RST}"
echo -e "${G}    ║${RST}   ${W}╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝${RST}                       ${G}║${RST}"
echo -e "${G}    ║${RST}                                                                  ${G}║${RST}"
echo -e "${G}    ║${RST}   ${C}BUILD SUCCESSFUL${RST}  ${DIM}//  ${Y}${BUILD_DURATION} minutes elapsed${RST}                    ${G}║${RST}"
echo -e "${G}    ║${RST}                                                                  ${G}║${RST}"
echo -e "${G}    ╚══════════════════════════════════════════════════════════════════╝${RST}"
echo ""

ISO_PATH=$(find images/ -name "*.iso" -type f 2>/dev/null | head -1)
if [[ -n "$ISO_PATH" ]]; then
    ISO_SIZE=$(du -h "$ISO_PATH" | cut -f1)
    echo -e "  ${OK} ${W}ISO Location:${RST} $(pwd)/$ISO_PATH"
    echo -e "  ${OK} ${W}ISO Size:${RST}     $ISO_SIZE"
    echo ""
    echo -e "  ${M}┌─ Write to USB ─────────────────────────────────────────────────┐${RST}"
    echo -e "  ${M}│${RST}  sudo dd if=$(pwd)/$ISO_PATH of=/dev/sdX bs=4M status=progress ${M}│${RST}"
    echo -e "  ${M}└────────────────────────────────────────────────────────────────┘${RST}"
    echo ""
    echo -e "  ${C}┌─ Test with QEMU ───────────────────────────────────────────────┐${RST}"
    echo -e "  ${C}│${RST}  qemu-img create -f qcow2 /tmp/kali-test.img 40G             ${C}│${RST}"
    echo -e "  ${C}│${RST}  qemu-system-x86_64 -enable-kvm -m 4G \\                      ${C}│${RST}"
    echo -e "  ${C}│${RST}    -drive if=virtio,format=qcow2,file=/tmp/kali-test.img \\   ${C}│${RST}"
    echo -e "  ${C}│${RST}    -drive if=pflash,format=raw,readonly=on,\\                 ${C}│${RST}"
    echo -e "  ${C}│${RST}          file=/usr/share/OVMF/OVMF_CODE.fd \\                 ${C}│${RST}"
    echo -e "  ${C}│${RST}    -cdrom $(pwd)/$ISO_PATH -boot once=d   ${C}│${RST}"
    echo -e "  ${C}└────────────────────────────────────────────────────────────────┘${RST}"
else
    echo -e "  ${WARN} No ISO found in images/ directory."
    echo -e "  ${WARN} Check the build log: $LOG_FILE"
fi

echo ""
echo -e "  ${G}┌─ SSH Access (pre-configured) ──────────────────────────────────┐${RST}"
echo -e "  ${G}│${RST}  ${W}Root key-only login:${RST} ed25519 + RSA keys baked in             ${G}│${RST}"
echo -e "  ${G}│${RST}  ${W}Password auth:${RST}       disabled (key-only)                     ${G}│${RST}"
echo -e "  ${G}│${RST}  ${W}Connect:${RST}             ssh root@<imac-ip>                      ${G}│${RST}"
echo -e "  ${G}│${RST}  ${W}Find iMac:${RST}           nmap -p 22 --open 192.168.1.0/24       ${G}│${RST}"
echo -e "  ${G}└────────────────────────────────────────────────────────────────┘${RST}"
echo ""
echo -e "  ${DIM}Add to ~/.ssh/config on your Mac for easy access:${RST}"
echo -e "  ${Y}Host kali-imac"
echo -e "    HostName <imac-ip>"
echo -e "    User root"
echo -e "    IdentityFile ~/.ssh/id_ed25519"
echo -e "    ForwardAgent yes"
echo -e "    ForwardX11 yes"
echo -e "    StrictHostKeyChecking accept-new"
echo -e "    ServerAliveInterval 60"
echo -e "    ServerAliveCountMax 10${RST}"
echo ""
echo -e "  ${DIM}Build log: $LOG_FILE${RST}"
echo ""
echo -e "${DIM}    ─────────────────────────────────────────────────────────────────${RST}"
echo -e "    ${M}\"Hack the planet.\"${RST}  ${DIM}-- Hackers, 1995${RST}"
echo -e "${DIM}    ─────────────────────────────────────────────────────────────────${RST}"
echo ""
