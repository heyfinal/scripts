#!/usr/bin/env python3
"""
AI-Powered Packet Analyzer — Captures traffic with tshark and uses AI to analyze it.

Features:
  - Auto-detects and installs all dependencies
  - Captures live traffic or analyzes existing pcap files
  - AI-powered analysis via OpenRouter, Ollama, or LiteLLM
  - Device identification, protocol analysis, anomaly detection
  - Supports target filtering, duration, and interface selection

Usage:
  # Live capture + AI analysis (5 min, specific targets)
  sudo python3 ai-packet-analyzer.py --targets 192.168.1.127,192.168.1.134 --duration 300

  # Analyze existing pcap
  python3 ai-packet-analyzer.py --pcap capture.pcap

  # Full subnet capture with AI summary
  sudo python3 ai-packet-analyzer.py --subnet 192.168.1.0/24 --duration 120

  # Device identification mode
  sudo python3 ai-packet-analyzer.py --targets 192.168.1.127 --mode identify --duration 60
"""

import argparse
import json
import os
import platform
import shutil
import signal
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

# ── Auto-install Python dependencies ──────────────────────────────────────────

REQUIRED_PACKAGES = {"requests": "requests", "rich": "rich"}

def ensure_python_deps():
    missing = []
    for module, pkg in REQUIRED_PACKAGES.items():
        try:
            __import__(module)
        except ImportError:
            missing.append(pkg)
    if missing:
        print(f"[*] Installing missing Python packages: {', '.join(missing)}")
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "--break-system-packages", "-q"] + missing,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )

ensure_python_deps()

import requests
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich import box

console = Console()

# ── Auto-detect and install tshark ────────────────────────────────────────────

def ensure_tshark():
    if shutil.which("tshark"):
        return True
    system = platform.system()
    console.print("[yellow][*] tshark not found — installing...[/yellow]")
    try:
        if system == "Darwin":
            subprocess.check_call(["brew", "install", "wireshark"], stdout=subprocess.DEVNULL)
        elif system == "Linux":
            if shutil.which("apt-get"):
                subprocess.check_call(["sudo", "apt-get", "install", "-y", "tshark"],
                                      stdout=subprocess.DEVNULL)
            elif shutil.which("dnf"):
                subprocess.check_call(["sudo", "dnf", "install", "-y", "wireshark-cli"],
                                      stdout=subprocess.DEVNULL)
        if shutil.which("tshark"):
            console.print("[green][✓] tshark installed successfully[/green]")
            return True
    except Exception as e:
        console.print(f"[red][✗] Failed to install tshark: {e}[/red]")
    console.print("[red][✗] Please install Wireshark/tshark manually[/red]")
    return False

# ── AI Backend ────────────────────────────────────────────────────────────────

class AIAnalyzer:
    """Handles AI inference via multiple backends."""

    def __init__(self, backend="auto"):
        self.backend = backend
        self.api_url = None
        self.api_key = None
        self.model = None
        self._detect_backend()

    def _detect_backend(self):
        """Auto-detect the best available AI backend."""
        if self.backend != "auto":
            self._configure(self.backend)
            return

        # Priority: OpenRouter > LiteLLM > Ollama
        # Check OpenRouter
        key = os.environ.get("OPENROUTER_API_KEY")
        if not key:
            env_file = Path.home() / ".env_secrets"
            if env_file.exists():
                for line in env_file.read_text().splitlines():
                    if line.startswith("OPENROUTER_API_KEY="):
                        key = line.split("=", 1)[1].strip().strip("'\"")
                        break
            if not key:
                env2 = Path.home() / "tmp" / "netbreach" / "configs" / ".env"
                if env2.exists():
                    for line in env2.read_text().splitlines():
                        if line.startswith("OPENROUTER_API_KEY="):
                            key = line.split("=", 1)[1].strip().strip("'\"")
                            break
        if key:
            self.api_url = "https://openrouter.ai/api/v1/chat/completions"
            self.api_key = key
            self.model = "openrouter/auto"
            self.backend = "openrouter"
            return

        # Check LiteLLM local proxy
        try:
            r = requests.get("http://127.0.0.1:4000/v1/models", timeout=2)
            if r.status_code == 200:
                self.api_url = "http://127.0.0.1:4000/v1/chat/completions"
                self.api_key = "sk-litellm-vertex-local"
                self.model = "gemini-2.5-flash"
                self.backend = "litellm"
                return
        except Exception:
            pass

        # Check Ollama (local)
        try:
            r = requests.get("http://127.0.0.1:11434/api/tags", timeout=2)
            if r.status_code == 200:
                models = r.json().get("models", [])
                if models:
                    self.api_url = "http://127.0.0.1:11434/api/chat"
                    self.model = models[0]["name"]
                    self.backend = "ollama"
                    return
        except Exception:
            pass

        # Check Ollama on Kali box
        try:
            r = requests.get("http://192.168.1.230:11434/api/tags", timeout=2)
            if r.status_code == 200:
                models = r.json().get("models", [])
                if models:
                    self.api_url = "http://192.168.1.230:11434/api/chat"
                    self.model = models[0]["name"]
                    self.backend = "ollama-kali"
                    return
        except Exception:
            pass

        self.backend = "none"

    def _configure(self, backend):
        if backend == "openrouter":
            self.api_url = "https://openrouter.ai/api/v1/chat/completions"
            self.api_key = os.environ.get("OPENROUTER_API_KEY", "")
            self.model = "openrouter/auto"
        elif backend == "litellm":
            self.api_url = "http://127.0.0.1:4000/v1/chat/completions"
            self.api_key = "sk-litellm-vertex-local"
            self.model = "gemini-2.5-flash"
        elif backend == "ollama":
            self.api_url = "http://127.0.0.1:11434/api/chat"
            self.model = "qwen3-coder-abliterated:3b"

    def analyze(self, prompt, system_prompt=None):
        """Send analysis request to AI backend."""
        if self.backend == "none":
            return "[AI unavailable — no backend detected. Set OPENROUTER_API_KEY or run Ollama.]"

        if self.backend in ("openrouter", "litellm"):
            return self._openai_compatible(prompt, system_prompt)
        elif self.backend in ("ollama", "ollama-kali"):
            return self._ollama(prompt, system_prompt)
        return "[Unknown AI backend]"

    def _openai_compatible(self, prompt, system_prompt=None):
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})

        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"

        body = {"model": self.model, "messages": messages, "max_tokens": 4096}

        try:
            r = requests.post(self.api_url, json=body, headers=headers, timeout=60)
            r.raise_for_status()
            return r.json()["choices"][0]["message"]["content"]
        except Exception as e:
            return f"[AI error: {e}]"

    def _ollama(self, prompt, system_prompt=None):
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})

        body = {"model": self.model, "messages": messages, "stream": False}

        try:
            r = requests.post(self.api_url, json=body, timeout=120)
            r.raise_for_status()
            return r.json()["message"]["content"]
        except Exception as e:
            return f"[AI error: {e}]"

# ── Packet Capture ────────────────────────────────────────────────────────────

class PacketCapture:
    """Manages tshark packet capture."""

    def __init__(self, interface=None, targets=None, subnet=None,
                 duration=300, pcap_out=None, bpf_filter=None):
        self.interface = interface or self._detect_interface()
        self.targets = targets or []
        self.subnet = subnet
        self.duration = duration
        self.pcap_out = pcap_out or self._default_pcap_path()
        self.bpf_filter = bpf_filter or self._build_filter()
        self.process = None

    def _detect_interface(self):
        """Auto-detect the active network interface."""
        system = platform.system()
        try:
            if system == "Darwin":
                out = subprocess.check_output(
                    ["route", "get", "default"], text=True, stderr=subprocess.DEVNULL
                )
                for line in out.splitlines():
                    if "interface:" in line:
                        return line.split(":")[-1].strip()
            elif system == "Linux":
                out = subprocess.check_output(
                    ["ip", "route", "show", "default"], text=True, stderr=subprocess.DEVNULL
                )
                parts = out.split()
                if "dev" in parts:
                    return parts[parts.index("dev") + 1]
        except Exception:
            pass
        return "en0" if system == "Darwin" else "eth0"

    def _default_pcap_path(self):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        out_dir = Path.home() / "tmp" / "captures"
        out_dir.mkdir(parents=True, exist_ok=True)
        return str(out_dir / f"capture_{ts}.pcap")

    def _build_filter(self):
        if self.bpf_filter:
            return self.bpf_filter
        parts = []
        for t in self.targets:
            parts.append(f"host {t}")
        if self.subnet:
            parts.append(f"net {self.subnet}")
        return " or ".join(parts) if parts else ""

    def capture(self):
        """Run tshark capture."""
        cmd = [
            "tshark",
            "-i", self.interface,
            "-a", f"duration:{self.duration}",
            "-w", self.pcap_out,
            "-q",
        ]
        if self.bpf_filter:
            cmd += ["-f", self.bpf_filter]

        console.print(f"[cyan]Interface:[/cyan] {self.interface}")
        console.print(f"[cyan]Filter:[/cyan]    {self.bpf_filter or '(none — all traffic)'}")
        console.print(f"[cyan]Duration:[/cyan]  {self.duration}s")
        console.print(f"[cyan]Output:[/cyan]    {self.pcap_out}")
        console.print()

        try:
            self.process = subprocess.Popen(
                cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE
            )
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                console=console,
            ) as progress:
                task = progress.add_task(
                    f"Capturing packets ({self.duration}s)...", total=None
                )
                self.process.wait()
                progress.update(task, description="Capture complete.")

            if not Path(self.pcap_out).exists() or Path(self.pcap_out).stat().st_size == 0:
                console.print("[yellow]⚠ No packets captured. Device may be idle.[/yellow]")
                return False
            return True

        except KeyboardInterrupt:
            if self.process:
                self.process.terminate()
                self.process.wait()
            console.print("\n[yellow]Capture interrupted.[/yellow]")
            return Path(self.pcap_out).exists() and Path(self.pcap_out).stat().st_size > 0

    def stop(self):
        if self.process:
            self.process.terminate()

# ── Packet Analysis ───────────────────────────────────────────────────────────

class PacketAnalyzer:
    """Extracts structured data from pcap files using tshark."""

    def __init__(self, pcap_path):
        self.pcap = pcap_path

    def get_stats(self):
        """Get capture statistics."""
        out = subprocess.check_output(
            ["tshark", "-r", self.pcap, "-q", "-z", "io,stat,0"],
            text=True, stderr=subprocess.DEVNULL,
        )
        return out.strip()

    def get_conversations(self):
        """Get IP conversations."""
        out = subprocess.check_output(
            ["tshark", "-r", self.pcap, "-q", "-z", "conv,ip"],
            text=True, stderr=subprocess.DEVNULL,
        )
        return out.strip()

    def get_dns_queries(self):
        """Extract all DNS queries."""
        out = subprocess.check_output(
            ["tshark", "-r", self.pcap, "-Y", "dns.qr==0",
             "-T", "fields", "-e", "ip.src", "-e", "dns.qry.name",
             "-e", "frame.time"],
            text=True, stderr=subprocess.DEVNULL,
        )
        return out.strip()

    def get_tls_handshakes(self):
        """Extract TLS SNI (Server Name Indication)."""
        out = subprocess.check_output(
            ["tshark", "-r", self.pcap, "-Y", "tls.handshake.type==1",
             "-T", "fields", "-e", "ip.src", "-e", "tls.handshake.extensions_server_name",
             "-e", "frame.time"],
            text=True, stderr=subprocess.DEVNULL,
        )
        return out.strip()

    def get_http_hosts(self):
        """Extract HTTP Host headers and User-Agents."""
        out = subprocess.check_output(
            ["tshark", "-r", self.pcap, "-Y", "http.request",
             "-T", "fields", "-e", "ip.src", "-e", "http.host",
             "-e", "http.user_agent", "-e", "http.request.uri",
             "-e", "frame.time"],
            text=True, stderr=subprocess.DEVNULL,
        )
        return out.strip()

    def get_endpoints(self):
        """Get endpoint statistics."""
        out = subprocess.check_output(
            ["tshark", "-r", self.pcap, "-q", "-z", "endpoints,ip"],
            text=True, stderr=subprocess.DEVNULL,
        )
        return out.strip()

    def get_protocol_hierarchy(self):
        """Protocol hierarchy statistics."""
        out = subprocess.check_output(
            ["tshark", "-r", self.pcap, "-q", "-z", "io,phs"],
            text=True, stderr=subprocess.DEVNULL,
        )
        return out.strip()

    def get_expert_info(self):
        """Get Wireshark expert info (errors, warnings)."""
        out = subprocess.check_output(
            ["tshark", "-r", self.pcap, "-q", "-z", "expert"],
            text=True, stderr=subprocess.DEVNULL,
        )
        return out.strip()

    def get_packet_sample(self, count=50):
        """Get decoded packet sample for AI context."""
        out = subprocess.check_output(
            ["tshark", "-r", self.pcap, "-c", str(count), "-V"],
            text=True, stderr=subprocess.DEVNULL,
        )
        # Truncate if too long for AI context
        if len(out) > 30000:
            out = out[:30000] + "\n[...truncated...]"
        return out.strip()

    def get_unique_ips(self):
        """Get unique source and destination IPs."""
        out = subprocess.check_output(
            ["tshark", "-r", self.pcap,
             "-T", "fields", "-e", "ip.src", "-e", "ip.dst"],
            text=True, stderr=subprocess.DEVNULL,
        )
        ips = set()
        for line in out.strip().splitlines():
            parts = line.split("\t")
            for p in parts:
                if p:
                    ips.add(p)
        return sorted(ips)

    def get_mac_addresses(self):
        """Extract MAC addresses and their associated IPs."""
        out = subprocess.check_output(
            ["tshark", "-r", self.pcap,
             "-T", "fields", "-e", "eth.src", "-e", "ip.src",
             "-e", "eth.dst", "-e", "ip.dst"],
            text=True, stderr=subprocess.DEVNULL,
        )
        mac_ip = {}
        for line in out.strip().splitlines():
            parts = line.split("\t")
            if len(parts) >= 4:
                if parts[0] and parts[1]:
                    mac_ip[parts[0]] = parts[1]
                if parts[2] and parts[3]:
                    mac_ip[parts[2]] = parts[3]
        return mac_ip

    def build_summary(self):
        """Build a structured summary dict for AI analysis."""
        summary = {}
        try:
            summary["stats"] = self.get_stats()
        except Exception:
            summary["stats"] = "(unavailable)"
        try:
            summary["dns"] = self.get_dns_queries()
        except Exception:
            summary["dns"] = "(none)"
        try:
            summary["tls_sni"] = self.get_tls_handshakes()
        except Exception:
            summary["tls_sni"] = "(none)"
        try:
            summary["http"] = self.get_http_hosts()
        except Exception:
            summary["http"] = "(none)"
        try:
            summary["conversations"] = self.get_conversations()
        except Exception:
            summary["conversations"] = "(unavailable)"
        try:
            summary["protocols"] = self.get_protocol_hierarchy()
        except Exception:
            summary["protocols"] = "(unavailable)"
        try:
            summary["expert"] = self.get_expert_info()
        except Exception:
            summary["expert"] = "(unavailable)"
        try:
            summary["endpoints"] = self.get_endpoints()
        except Exception:
            summary["endpoints"] = "(unavailable)"
        try:
            summary["macs"] = self.get_mac_addresses()
        except Exception:
            summary["macs"] = {}
        return summary

# ── Analysis Modes ────────────────────────────────────────────────────────────

SYSTEM_PROMPTS = {
    "identify": """You are a network forensics expert specializing in device identification.
Given packet capture data (DNS queries, TLS SNI, HTTP headers, traffic patterns), identify each
device on the network. For each unique IP/MAC, determine:
1. Device type (Fire TV, Chromecast, smart speaker, phone, laptop, IoT sensor, etc.)
2. Manufacturer (Amazon, Google, Apple, Samsung, etc.)
3. Specific model if determinable from User-Agent or traffic patterns
4. Confidence level (high/medium/low)
5. Evidence supporting your identification

Pay special attention to:
- DNS domains (e.g., device-metrics-us.amazon.com → Amazon device, clients3.google.com → Google)
- TLS SNI hostnames
- HTTP User-Agent strings
- Traffic volume and patterns
- Port usage patterns

Format your response as a clear report with a table of identified devices.""",

    "security": """You are a network security analyst performing traffic analysis.
Given packet capture data, identify:
1. Any suspicious or anomalous traffic patterns
2. Unencrypted sensitive data transmission
3. Connections to known malicious or unusual domains
4. DNS exfiltration attempts
5. Unauthorized devices or rogue access points
6. Protocol anomalies or malformed packets
7. Potential C2 (command and control) traffic indicators
8. Any cleartext credentials or tokens

Rate each finding by severity (Critical/High/Medium/Low/Info).
Provide actionable remediation steps for any issues found.""",

    "general": """You are a network traffic analyst. Given packet capture summary data,
provide a comprehensive analysis including:
1. Traffic overview (protocols, volume, top talkers)
2. Notable connections and their purposes
3. Any anomalies or interesting patterns
4. Device behavior summary
5. Recommendations if any issues are found

Be concise and actionable. Use tables where appropriate.""",

    "troubleshoot": """You are a network troubleshooting expert. Given packet capture data,
identify potential network issues:
1. Retransmissions, timeouts, and connection failures
2. DNS resolution problems
3. High latency connections
4. Bandwidth hogs
5. Protocol errors (from Wireshark expert info)
6. MTU issues
7. Connection reset patterns

For each issue found, explain the likely cause and suggest fixes.""",
}


def run_analysis(pcap_path, mode, ai, targets=None):
    """Run full analysis pipeline on a pcap file."""

    console.print(Panel(f"[bold]Analyzing: {pcap_path}[/bold]\nMode: {mode} | AI: {ai.backend} ({ai.model})",
                        title="AI Packet Analyzer", border_style="cyan"))

    analyzer = PacketAnalyzer(pcap_path)

    with Progress(SpinnerColumn(), TextColumn("[progress.description]{task.description}"),
                  console=console) as progress:
        task = progress.add_task("Extracting packet data...", total=None)
        summary = analyzer.build_summary()
        progress.update(task, description="Extraction complete.")

    # Display raw findings tables
    console.print()

    # DNS table
    if summary["dns"] and summary["dns"] != "(none)":
        dns_table = Table(title="DNS Queries", box=box.ROUNDED, show_lines=False)
        dns_table.add_column("Source IP", style="cyan")
        dns_table.add_column("Domain", style="green")
        dns_table.add_column("Time", style="dim")
        seen = set()
        for line in summary["dns"].splitlines()[:30]:
            parts = line.split("\t")
            if len(parts) >= 2:
                key = f"{parts[0]}:{parts[1]}"
                if key not in seen:
                    seen.add(key)
                    dns_table.add_row(parts[0], parts[1], parts[2] if len(parts) > 2 else "")
        console.print(dns_table)

    # TLS SNI table
    if summary["tls_sni"] and summary["tls_sni"] != "(none)":
        tls_table = Table(title="TLS Connections (SNI)", box=box.ROUNDED)
        tls_table.add_column("Source IP", style="cyan")
        tls_table.add_column("Server Name", style="yellow")
        seen = set()
        for line in summary["tls_sni"].splitlines()[:30]:
            parts = line.split("\t")
            if len(parts) >= 2:
                key = f"{parts[0]}:{parts[1]}"
                if key not in seen:
                    seen.add(key)
                    tls_table.add_row(parts[0], parts[1])
        console.print(tls_table)

    # HTTP table
    if summary["http"] and summary["http"] != "(none)":
        http_table = Table(title="HTTP Requests", box=box.ROUNDED)
        http_table.add_column("Source IP", style="cyan")
        http_table.add_column("Host", style="green")
        http_table.add_column("User-Agent", style="dim", max_width=60)
        for line in summary["http"].splitlines()[:20]:
            parts = line.split("\t")
            if len(parts) >= 2:
                http_table.add_row(
                    parts[0], parts[1],
                    parts[2][:60] if len(parts) > 2 else ""
                )
        console.print(http_table)

    # MAC addresses
    if summary["macs"]:
        mac_table = Table(title="MAC ↔ IP Mapping", box=box.ROUNDED)
        mac_table.add_column("MAC Address", style="cyan")
        mac_table.add_column("IP Address", style="green")
        for mac, ip in sorted(summary["macs"].items(), key=lambda x: x[1]):
            mac_table.add_row(mac, ip)
        console.print(mac_table)

    # Build AI prompt
    target_str = f"Target devices: {', '.join(targets)}\n" if targets else ""

    ai_prompt = f"""{target_str}
== CAPTURE STATISTICS ==
{summary['stats']}

== DNS QUERIES ==
{summary['dns'][:5000]}

== TLS SERVER NAMES (SNI) ==
{summary['tls_sni'][:3000]}

== HTTP REQUESTS ==
{summary['http'][:3000]}

== IP CONVERSATIONS ==
{summary['conversations'][:3000]}

== PROTOCOL HIERARCHY ==
{summary['protocols']}

== EXPERT INFO (WARNINGS/ERRORS) ==
{summary['expert'][:2000]}

== ENDPOINT STATISTICS ==
{summary['endpoints'][:2000]}

== MAC ADDRESS MAPPING ==
{json.dumps(summary['macs'], indent=2)[:2000]}

Analyze this packet capture data according to your role. Be specific and actionable.
"""

    # Run AI analysis
    console.print()
    system_prompt = SYSTEM_PROMPTS.get(mode, SYSTEM_PROMPTS["general"])

    with Progress(SpinnerColumn(), TextColumn("[progress.description]{task.description}"),
                  console=console) as progress:
        task = progress.add_task(f"AI analyzing ({ai.backend})...", total=None)
        ai_result = ai.analyze(ai_prompt, system_prompt)
        progress.update(task, description="AI analysis complete.")

    console.print()
    console.print(Panel(ai_result, title=f"AI Analysis ({mode})", border_style="green",
                        padding=(1, 2)))

    # Save report
    report_dir = Path.home() / "tmp" / "captures" / "reports"
    report_dir.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_path = report_dir / f"analysis_{mode}_{ts}.md"
    report_path.write_text(
        f"# Packet Analysis Report — {mode}\n"
        f"**Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
        f"**PCAP:** {pcap_path}\n"
        f"**AI Backend:** {ai.backend} ({ai.model})\n\n"
        f"## Raw Data\n\n"
        f"### DNS Queries\n```\n{summary['dns'][:5000]}\n```\n\n"
        f"### TLS SNI\n```\n{summary['tls_sni'][:3000]}\n```\n\n"
        f"### HTTP\n```\n{summary['http'][:3000]}\n```\n\n"
        f"### Conversations\n```\n{summary['conversations'][:3000]}\n```\n\n"
        f"## AI Analysis\n\n{ai_result}\n"
    )
    console.print(f"\n[dim]Report saved: {report_path}[/dim]")
    return str(report_path)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="AI-Powered Packet Analyzer — Capture + AI analysis",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Identify unknown devices
  sudo python3 ai-packet-analyzer.py -t 192.168.1.127,192.168.1.134 -m identify -d 120

  # Security audit on a subnet
  sudo python3 ai-packet-analyzer.py --subnet 192.168.1.0/24 -m security -d 300

  # Analyze existing pcap file
  python3 ai-packet-analyzer.py --pcap capture.pcap -m general

  # Troubleshoot network issues
  sudo python3 ai-packet-analyzer.py -t 192.168.1.50 -m troubleshoot -d 60

  # Custom BPF filter
  sudo python3 ai-packet-analyzer.py --bpf "tcp port 443" -d 30 -m security
        """,
    )

    parser.add_argument("-t", "--targets", type=str, default=None,
                        help="Comma-separated target IPs to monitor")
    parser.add_argument("--subnet", type=str, default=None,
                        help="Subnet to capture (e.g., 192.168.1.0/24)")
    parser.add_argument("-d", "--duration", type=int, default=300,
                        help="Capture duration in seconds (default: 300)")
    parser.add_argument("-i", "--interface", type=str, default=None,
                        help="Network interface (default: auto-detect)")
    parser.add_argument("-p", "--pcap", type=str, default=None,
                        help="Analyze existing pcap file (skip capture)")
    parser.add_argument("-o", "--output", type=str, default=None,
                        help="Output pcap file path")
    parser.add_argument("-m", "--mode", type=str, default="general",
                        choices=["identify", "security", "general", "troubleshoot"],
                        help="Analysis mode (default: general)")
    parser.add_argument("--bpf", type=str, default=None,
                        help="Custom BPF capture filter")
    parser.add_argument("--ai-backend", type=str, default="auto",
                        choices=["auto", "openrouter", "litellm", "ollama", "none"],
                        help="AI backend (default: auto-detect)")
    parser.add_argument("--no-ai", action="store_true",
                        help="Skip AI analysis, just extract and display data")

    args = parser.parse_args()

    console.print(Panel("[bold cyan]AI Packet Analyzer[/bold cyan]",
                        subtitle="tshark + AI", border_style="bright_blue"))

    # Ensure tshark
    if not args.pcap and not ensure_tshark():
        sys.exit(1)

    # Parse targets
    targets = [t.strip() for t in args.targets.split(",")] if args.targets else []

    # AI setup
    if args.no_ai:
        ai = None
    else:
        ai = AIAnalyzer(args.ai_backend)
        console.print(f"[dim]AI Backend: {ai.backend} ({ai.model})[/dim]")

    pcap_path = args.pcap

    # Capture phase
    if not pcap_path:
        if not ensure_tshark():
            sys.exit(1)

        cap = PacketCapture(
            interface=args.interface,
            targets=targets,
            subnet=args.subnet,
            duration=args.duration,
            pcap_out=args.output,
            bpf_filter=args.bpf,
        )

        def sig_handler(sig, frame):
            console.print("\n[yellow]Stopping capture...[/yellow]")
            cap.stop()

        signal.signal(signal.SIGINT, sig_handler)

        console.print()
        if not cap.capture():
            console.print("[red]No packets captured — nothing to analyze.[/red]")
            sys.exit(1)

        pcap_path = cap.pcap_out

    # Analysis phase
    if not Path(pcap_path).exists():
        console.print(f"[red]PCAP file not found: {pcap_path}[/red]")
        sys.exit(1)

    size_mb = Path(pcap_path).stat().st_size / (1024 * 1024)
    console.print(f"\n[green]PCAP: {pcap_path} ({size_mb:.1f} MB)[/green]")

    if ai:
        run_analysis(pcap_path, args.mode, ai, targets)
    else:
        # No AI — just show extracted data
        analyzer = PacketAnalyzer(pcap_path)
        summary = analyzer.build_summary()
        console.print(Panel(summary["stats"], title="Capture Stats"))
        if summary["dns"] != "(none)":
            console.print(Panel(summary["dns"][:3000], title="DNS Queries"))
        if summary["tls_sni"] != "(none)":
            console.print(Panel(summary["tls_sni"][:3000], title="TLS SNI"))
        if summary["http"] != "(none)":
            console.print(Panel(summary["http"][:3000], title="HTTP Requests"))
        console.print(Panel(summary["conversations"][:3000], title="Conversations"))


if __name__ == "__main__":
    main()
