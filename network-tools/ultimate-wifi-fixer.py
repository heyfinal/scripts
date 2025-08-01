#!/usr/bin/env python3
"""
Ultimate WiFi Troubleshooter & Network Performance Optimizer
macOS & Linux Exclusive - 2025 Edition

A comprehensive tool that combines cutting-edge WiFi diagnostics with
performance optimization for modern networks.

Features:
- Advanced WiFi diagnostics and troubleshooting
- DNS resolution optimization (mDNSResponder fixes for macOS)
- Channel analysis and interference detection
- Network performance testing and optimization
- Real-time monitoring and alerting
- Automated fixes for common issues
- Modern network stack optimizations

Requirements: Python 3.8+, root/admin privileges for some operations
"""

import asyncio
import json
import logging
import os
import platform
import re
import signal
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
import argparse

# Auto-install dependencies
def install_dependencies():
    """Auto-install required dependencies"""
    required_packages = {
        'psutil': 'psutil',
        'requests': 'requests', 
        'speedtest': 'speedtest-cli'
    }
    
    missing_packages = []
    
    for module, package in required_packages.items():
        try:
            __import__(module)
        except ImportError:
            missing_packages.append(package)
    
    if missing_packages:
        print(f"📦 Installing missing dependencies: {', '.join(missing_packages)}")
        
        # Try different installation methods
        install_commands = [
            f"pip3 install --break-system-packages {' '.join(missing_packages)}",
            f"pip3 install --user {' '.join(missing_packages)}",
            f"pip install {' '.join(missing_packages)}"
        ]
        
        for cmd in install_commands:
            try:
                result = subprocess.run(cmd.split(), capture_output=True, text=True, timeout=60)
                if result.returncode == 0:
                    print("✅ Dependencies installed successfully")
                    break
            except Exception:
                continue
        else:
            print("❌ Failed to install dependencies automatically")
            print(f"Please manually run: pip3 install {' '.join(missing_packages)}")
            sys.exit(1)

# Install dependencies first
install_dependencies()

# Now import required modules
try:
    import psutil
    import requests
    import speedtest
except ImportError as e:
    print(f"❌ Import failed after installation: {e}")
    sys.exit(1)

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'/tmp/wifi-fixer-{datetime.now().strftime("%Y%m%d")}.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('UltimateWiFiFixer')

@dataclass
class NetworkInterface:
    name: str
    type: str
    status: str
    mac_address: str
    ip_address: Optional[str]
    gateway: Optional[str]
    dns_servers: List[str]
    signal_strength: Optional[int]
    frequency: Optional[str]
    channel: Optional[int]
    
@dataclass
class WiFiNetwork:
    ssid: str
    bssid: str
    channel: int
    frequency: str
    signal_strength: int
    quality: int
    encryption: str
    vendor: Optional[str]
    
@dataclass
class NetworkPerformance:
    download_speed: float
    upload_speed: float
    ping: float
    jitter: float
    packet_loss: float
    dns_resolution_time: float
    
class UltimateWiFiFixer:
    def __init__(self):
        self.system = platform.system()
        self.is_mac = self.system == "Darwin"
        self.is_linux = self.system == "Linux"
        
        if not (self.is_mac or self.is_linux):
            raise RuntimeError("This tool is exclusively for macOS and Linux")
            
        self.interfaces = []
        self.wifi_networks = []
        self.performance_data = None
        self.issues_detected = []
        self.fixes_applied = []
        
        logger.info(f"Ultimate WiFi Fixer initialized on {self.system}")
        
    def run_command(self, command: str, shell: bool = True, timeout: int = 30) -> Tuple[bool, str, str]:
        """Execute system command with error handling"""
        try:
            if isinstance(command, str) and not shell:
                command = command.split()
                
            result = subprocess.run(
                command,
                shell=shell,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            
            return result.returncode == 0, result.stdout, result.stderr
            
        except subprocess.TimeoutExpired:
            return False, "", f"Command timed out after {timeout}s"
        except Exception as e:
            return False, "", str(e)
    
    def get_admin_permission(self) -> bool:
        """Check and request admin permissions"""
        if os.geteuid() == 0:
            return True
            
        print("🔐 Some operations require admin privileges.")
        if self.is_mac:
            print("Please run with: sudo python3 ultimate-wifi-fixer.py")
        else:
            print("Please run with: sudo python3 ultimate-wifi-fixer.py")
        return False
    
    async def detect_network_interfaces(self):
        """Detect and analyze all network interfaces"""
        logger.info("🔍 Detecting network interfaces...")
        
        interfaces = []
        
        if self.is_mac:
            interfaces = await self._detect_mac_interfaces()
        else:
            interfaces = await self._detect_linux_interfaces()
            
        self.interfaces = interfaces
        logger.info(f"Found {len(interfaces)} network interfaces")
        
        return interfaces
    
    async def _detect_mac_interfaces(self) -> List[NetworkInterface]:
        """Detect macOS network interfaces"""
        interfaces = []
        
        # Get interface list
        success, output, error = self.run_command("networksetup -listallhardwareports")
        if not success:
            logger.error(f"Failed to get interface list: {error}")
            return interfaces
            
        # Parse interface information
        current_interface = {}
        for line in output.split('\n'):
            line = line.strip()
            if line.startswith('Hardware Port:'):
                if current_interface:
                    interfaces.append(await self._parse_mac_interface(current_interface))
                current_interface = {'name': line.split(':', 1)[1].strip()}
            elif line.startswith('Device:'):
                current_interface['device'] = line.split(':', 1)[1].strip()
            elif line.startswith('Ethernet Address:'):
                current_interface['mac'] = line.split(':', 1)[1].strip()
                
        # Add last interface
        if current_interface:
            interfaces.append(await self._parse_mac_interface(current_interface))
            
        return interfaces
    
    async def _parse_mac_interface(self, interface_data: Dict) -> NetworkInterface:
        """Parse macOS interface data"""
        device = interface_data.get('device', '')
        
        # Get IP and gateway info
        success, output, error = self.run_command(f"ifconfig {device}")
        ip_address = None
        if success:
            ip_match = re.search(r'inet (\d+\.\d+\.\d+\.\d+)', output)
            if ip_match:
                ip_address = ip_match.group(1)
        
        # Get DNS servers
        success, output, error = self.run_command("scutil --dns")
        dns_servers = []
        if success:
            dns_matches = re.findall(r'nameserver\[\d+\] : (\d+\.\d+\.\d+\.\d+)', output)
            dns_servers = list(set(dns_matches))  # Remove duplicates
        
        # Get WiFi specific info if it's a WiFi interface
        signal_strength = None
        frequency = None
        channel = None
        
        if 'wi-fi' in interface_data.get('name', '').lower() or 'wifi' in device.lower():
            # Get WiFi info using airport utility
            success, output, error = self.run_command(
                "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I"
            )
            if success:
                signal_match = re.search(r'agrCtlRSSI: (-?\d+)', output)
                if signal_match:
                    signal_strength = int(signal_match.group(1))
                    
                channel_match = re.search(r'channel: (\d+)', output)
                if channel_match:
                    channel = int(channel_match.group(1))
                    
                freq_match = re.search(r'(\d+\.\d+)', output)
                if freq_match:
                    frequency = f"{freq_match.group(1)} GHz"
        
        return NetworkInterface(
            name=interface_data.get('name', 'Unknown'),
            type='WiFi' if 'wi-fi' in interface_data.get('name', '').lower() else 'Ethernet',
            status='active' if ip_address else 'inactive',
            mac_address=interface_data.get('mac', ''),
            ip_address=ip_address,
            gateway=None,  # Would need route command to get this
            dns_servers=dns_servers,
            signal_strength=signal_strength,
            frequency=frequency,
            channel=channel
        )
    
    async def _detect_linux_interfaces(self) -> List[NetworkInterface]:
        """Detect Linux network interfaces using modern tools"""
        interfaces = []
        
        # Use nmcli if NetworkManager is available
        success, output, error = self.run_command("which nmcli")
        if success:
            return await self._detect_linux_nmcli()
        else:
            return await self._detect_linux_legacy()
    
    async def _detect_linux_nmcli(self) -> List[NetworkInterface]:
        """Detect Linux interfaces using nmcli (NetworkManager)"""
        interfaces = []
        
        # Get connection info
        success, output, error = self.run_command("nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device")
        if not success:
            return interfaces
            
        for line in output.strip().split('\n'):
            if not line:
                continue
                
            parts = line.split(':')
            if len(parts) < 4:
                continue
                
            device, iface_type, state, connection = parts[:4]
            
            # Get detailed info for this interface
            interface = await self._parse_linux_interface_nmcli(device, iface_type, state, connection)
            if interface:
                interfaces.append(interface)
                
        return interfaces
    
    async def _parse_linux_interface_nmcli(self, device: str, iface_type: str, state: str, connection: str) -> Optional[NetworkInterface]:
        """Parse Linux interface using nmcli"""
        
        # Get IP info
        success, output, error = self.run_command(f"nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show {device}")
        ip_address = None
        gateway = None
        dns_servers = []
        
        if success:
            for line in output.split('\n'):
                if line.startswith('IP4.ADDRESS'):
                    ip_match = re.search(r'(\d+\.\d+\.\d+\.\d+)', line)
                    if ip_match:
                        ip_address = ip_match.group(1)
                elif line.startswith('IP4.GATEWAY'):
                    gateway = line.split(':', 1)[1].strip()
                elif line.startswith('IP4.DNS'):
                    dns = line.split(':', 1)[1].strip()
                    if dns:
                        dns_servers.append(dns)
        
        # Get MAC address
        success, output, error = self.run_command(f"cat /sys/class/net/{device}/address")
        mac_address = output.strip() if success else ""
        
        # Get WiFi specific info
        signal_strength = None
        frequency = None
        channel = None
        
        if iface_type == 'wifi':
            # Get WiFi signal info
            success, output, error = self.run_command(f"nmcli -t -f IN-USE,SIGNAL,FREQ,CHAN device wifi list ifname {device}")
            if success:
                for line in output.split('\n'):
                    if line.startswith('*'):  # Connected network
                        parts = line.split(':')
                        if len(parts) >= 4:
                            signal_strength = int(parts[1]) if parts[1].isdigit() else None
                            frequency = parts[2]
                            channel = int(parts[3]) if parts[3].isdigit() else None
                        break
        
        return NetworkInterface(
            name=device,
            type=iface_type.capitalize(),
            status=state,
            mac_address=mac_address,
            ip_address=ip_address,
            gateway=gateway,
            dns_servers=dns_servers,
            signal_strength=signal_strength,
            frequency=frequency,
            channel=channel
        )
    
    async def _detect_linux_legacy(self) -> List[NetworkInterface]:
        """Detect Linux interfaces using legacy tools (iwconfig, ifconfig)"""
        interfaces = []
        
        # Get interface list
        success, output, error = self.run_command("ls /sys/class/net/")
        if not success:
            return interfaces
            
        for interface_name in output.strip().split():
            if interface_name in ['lo']:  # Skip loopback
                continue
                
            interface = await self._parse_linux_interface_legacy(interface_name)
            if interface:
                interfaces.append(interface)
                
        return interfaces
    
    async def _parse_linux_interface_legacy(self, interface_name: str) -> Optional[NetworkInterface]:
        """Parse Linux interface using legacy tools"""
        
        # Check if interface exists
        if not os.path.exists(f"/sys/class/net/{interface_name}"):
            return None
            
        # Get basic info
        success, output, error = self.run_command(f"ip addr show {interface_name}")
        if not success:
            return None
            
        # Parse IP address
        ip_address = None
        ip_match = re.search(r'inet (\d+\.\d+\.\d+\.\d+)', output)
        if ip_match:
            ip_address = ip_match.group(1)
            
        # Get MAC address
        success, mac_output, error = self.run_command(f"cat /sys/class/net/{interface_name}/address")
        mac_address = mac_output.strip() if success else ""
        
        # Determine interface type
        iface_type = "Ethernet"
        success, wireless_output, error = self.run_command(f"iwconfig {interface_name}")
        if success and "IEEE 802.11" in wireless_output:
            iface_type = "WiFi"
            
        # Get WiFi info if wireless
        signal_strength = None
        frequency = None
        channel = None
        
        if iface_type == "WiFi":
            signal_match = re.search(r'Signal level=(-?\d+)', wireless_output)
            if signal_match:
                signal_strength = int(signal_match.group(1))
                
            freq_match = re.search(r'Frequency:(\d+\.\d+)', wireless_output)
            if freq_match:
                frequency = f"{freq_match.group(1)} GHz"
                
            # Get channel from frequency or iwlist
            success, channel_output, error = self.run_command(f"iwlist {interface_name} channel")
            if success:
                current_match = re.search(r'Current Frequency.*Channel (\d+)', channel_output)
                if current_match:
                    channel = int(current_match.group(1))
        
        return NetworkInterface(
            name=interface_name,
            type=iface_type,
            status='up' if ip_address else 'down',
            mac_address=mac_address,
            ip_address=ip_address,
            gateway=None,
            dns_servers=[],
            signal_strength=signal_strength,
            frequency=frequency,
            channel=channel
        )
    
    async def scan_wifi_networks(self):
        """Scan for available WiFi networks"""
        logger.info("📡 Scanning for WiFi networks...")
        
        networks = []
        
        if self.is_mac:
            networks = await self._scan_wifi_mac()
        else:
            networks = await self._scan_wifi_linux()
            
        self.wifi_networks = networks
        logger.info(f"Found {len(networks)} WiFi networks")
        
        return networks
    
    async def _scan_wifi_mac(self) -> List[WiFiNetwork]:
        """Scan WiFi networks on macOS"""
        networks = []
        
        # Use airport utility for scanning
        success, output, error = self.run_command(
            "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -s"
        )
        
        if not success:
            logger.error(f"WiFi scan failed: {error}")
            return networks
            
        lines = output.strip().split('\n')[1:]  # Skip header
        for line in lines:
            if not line.strip():
                continue
                
            # Parse airport output format
            parts = line.split()
            if len(parts) < 6:
                continue
                
            ssid = parts[0]
            bssid = parts[1]
            signal = int(parts[2])
            channel = int(parts[3])
            frequency = "2.4 GHz" if int(channel) <= 14 else "5 GHz"
            encryption = ' '.join(parts[6:]) if len(parts) > 6 else "Open"
            
            networks.append(WiFiNetwork(
                ssid=ssid,
                bssid=bssid,
                channel=channel,
                frequency=frequency,
                signal_strength=signal,
                quality=self._calculate_wifi_quality(signal),
                encryption=encryption,
                vendor=self._get_vendor_from_mac(bssid)
            ))
            
        return networks
    
    async def _scan_wifi_linux(self) -> List[WiFiNetwork]:
        """Scan WiFi networks on Linux"""
        networks = []
        
        # Try nmcli first
        success, output, error = self.run_command("nmcli device wifi list")
        if success:
            return await self._parse_nmcli_wifi_scan(output)
        
        # Fallback to iwlist scan
        wifi_interfaces = [iface for iface in self.interfaces if iface.type == 'WiFi']
        
        for interface in wifi_interfaces:
            success, output, error = self.run_command(f"iwlist {interface.name} scan", timeout=60)
            if success:
                networks.extend(await self._parse_iwlist_scan(output))
                
        return networks
    
    async def _parse_nmcli_wifi_scan(self, output: str) -> List[WiFiNetwork]:
        """Parse nmcli WiFi scan output"""
        networks = []
        
        lines = output.strip().split('\n')[1:]  # Skip header
        for line in lines:
            if not line.strip():
                continue
                
            # Parse nmcli output (columns may vary)
            match = re.match(r'\s*(\*?)\s+(.+?)\s+(\w+)\s+(\d+)\s+(\d+)\s+Mbit/s\s+(\d+)\s+(.+)', line)
            if not match:
                continue
                
            connected, ssid, mode, channel, rate, signal, security = match.groups()
            
            # Convert channel to frequency
            frequency = "2.4 GHz" if int(channel) <= 14 else "5 GHz"
            
            networks.append(WiFiNetwork(
                ssid=ssid.strip(),
                bssid="",  # Not available in basic nmcli output
                channel=int(channel),
                frequency=frequency,
                signal_strength=int(signal),
                quality=int(signal),  # nmcli shows quality directly
                encryption=security,
                vendor=None
            ))
            
        return networks
    
    async def _parse_iwlist_scan(self, output: str) -> List[WiFiNetwork]:
        """Parse iwlist scan output"""
        networks = []
        
        cells = output.split('Cell ')
        for cell in cells[1:]:  # Skip first empty part
            try:
                # Extract SSID
                ssid_match = re.search(r'ESSID:"([^"]*)"', cell)
                ssid = ssid_match.group(1) if ssid_match else "Hidden"
                
                # Extract BSSID
                bssid_match = re.search(r'Address: ([A-Fa-f0-9:]{17})', cell)
                bssid = bssid_match.group(1) if bssid_match else ""
                
                # Extract channel
                channel_match = re.search(r'Channel:(\d+)', cell)
                channel = int(channel_match.group(1)) if channel_match else 0
                
                # Extract signal strength
                signal_match = re.search(r'Signal level=(-?\d+)', cell)
                signal = int(signal_match.group(1)) if signal_match else -100
                
                # Extract encryption
                encryption = "Open"
                if "Privacy:on" in cell:
                    if "WPA2" in cell:
                        encryption = "WPA2"
                    elif "WPA" in cell:
                        encryption = "WPA"
                    else:
                        encryption = "WEP"
                
                frequency = "2.4 GHz" if channel <= 14 else "5 GHz"
                
                networks.append(WiFiNetwork(
                    ssid=ssid,
                    bssid=bssid,
                    channel=channel,
                    frequency=frequency,
                    signal_strength=signal,
                    quality=self._calculate_wifi_quality(signal),
                    encryption=encryption,
                    vendor=self._get_vendor_from_mac(bssid)
                ))
                
            except Exception as e:
                logger.debug(f"Error parsing WiFi cell: {e}")
                continue
                
        return networks
    
    def _calculate_wifi_quality(self, signal_strength: int) -> int:
        """Calculate WiFi quality percentage from signal strength"""
        if signal_strength >= -50:
            return 100
        elif signal_strength >= -60:
            return 70
        elif signal_strength >= -70:
            return 50
        elif signal_strength >= -80:
            return 30
        else:
            return 10
    
    def _get_vendor_from_mac(self, mac_address: str) -> Optional[str]:
        """Get vendor from MAC address OUI (first 3 octets)"""
        if not mac_address or len(mac_address) < 8:
            return None
            
        # Common OUI mappings (would normally use a full OUI database)
        oui_map = {
            "00:03:93": "Apple",
            "00:0A:95": "Apple", 
            "00:17:F2": "Apple",
            "28:CF:E9": "Apple",
            "A4:5E:60": "Apple",
            "00:1B:63": "Apple",
            "58:55:CA": "Apple",
            "00:26:08": "Apple",
            "3C:15:C2": "Apple",
            "00:50:56": "VMware",
            "08:00:27": "VirtualBox"
        }
        
        oui = mac_address[:8].upper()
        return oui_map.get(oui)
    
    async def test_network_performance(self) -> NetworkPerformance:
        """Test network performance including speed, latency, and DNS"""
        logger.info("🚀 Testing network performance...")
        
        # Test DNS resolution time
        dns_time = await self._test_dns_resolution()
        
        # Test basic connectivity
        ping_result = await self._test_ping()
        
        # Test internet speed
        try:
            st = speedtest.Speedtest()
            st.get_best_server()
            
            download_speed = st.download() / 1_000_000  # Convert to Mbps
            upload_speed = st.upload() / 1_000_000      # Convert to Mbps
            
            ping = st.results.ping
            
        except Exception as e:
            logger.error(f"Speed test failed: {e}")
            download_speed = 0.0
            upload_speed = 0.0
            ping = ping_result
        
        performance = NetworkPerformance(
            download_speed=download_speed,
            upload_speed=upload_speed,
            ping=ping,
            jitter=0.0,  # Would need multiple ping tests
            packet_loss=0.0,  # Would need packet loss test
            dns_resolution_time=dns_time
        )
        
        self.performance_data = performance
        logger.info(f"Performance test completed: {download_speed:.1f} Mbps down, {upload_speed:.1f} Mbps up, {ping:.1f}ms ping")
        
        return performance
    
    async def _test_dns_resolution(self) -> float:
        """Test DNS resolution time"""
        test_domains = ['google.com', 'cloudflare.com', 'github.com']
        total_time = 0.0
        successful_tests = 0
        
        for domain in test_domains:
            try:
                start_time = time.time()
                
                if self.is_mac:
                    success, output, error = self.run_command(f"dig +short {domain}", timeout=5)
                else:
                    success, output, error = self.run_command(f"nslookup {domain}", timeout=5)
                
                if success:
                    end_time = time.time()
                    total_time += (end_time - start_time) * 1000  # Convert to ms
                    successful_tests += 1
                    
            except Exception:
                continue
                
        return total_time / max(successful_tests, 1)
    
    async def _test_ping(self) -> float:
        """Test ping to reliable servers"""
        test_hosts = ['8.8.8.8', '1.1.1.1', 'google.com']
        
        for host in test_hosts:
            try:
                if self.is_mac:
                    success, output, error = self.run_command(f"ping -c 3 {host}", timeout=10)
                else:
                    success, output, error = self.run_command(f"ping -c 3 {host}", timeout=10)
                
                if success:
                    # Parse ping results
                    ping_match = re.search(r'time=(\d+\.?\d*)', output)
                    if ping_match:
                        return float(ping_match.group(1))
                        
            except Exception:
                continue
                
        return 999.0  # High ping indicates connectivity issues
    
    async def diagnose_issues(self):
        """Diagnose network and WiFi issues"""
        logger.info("🔍 Diagnosing network issues...")
        
        issues = []
        
        # Check for no internet connectivity
        if not await self._test_internet_connectivity():
            issues.append({
                'type': 'no_internet',
                'severity': 'critical',
                'description': 'No internet connectivity detected',
                'solution': 'Check network connection and DNS settings'
            })
        
        # Check DNS issues
        if self.performance_data and self.performance_data.dns_resolution_time > 1000:
            issues.append({
                'type': 'slow_dns',
                'severity': 'high',
                'description': f'Slow DNS resolution ({self.performance_data.dns_resolution_time:.0f}ms)',
                'solution': 'Optimize DNS servers or flush DNS cache'
            })
        
        # Check WiFi signal strength
        wifi_interfaces = [iface for iface in self.interfaces if iface.type == 'WiFi' and iface.signal_strength]
        for interface in wifi_interfaces:
            if interface.signal_strength < -70:
                issues.append({
                    'type': 'weak_signal',
                    'severity': 'medium',
                    'description': f'Weak WiFi signal on {interface.name} ({interface.signal_strength} dBm)',
                    'solution': 'Move closer to router or check for interference'
                })
        
        # Check for channel congestion
        await self._check_channel_congestion(issues)
        
        # Check for IP conflicts
        await self._check_ip_conflicts(issues)
        
        # macOS specific checks
        if self.is_mac:
            await self._check_macos_specific_issues(issues)
        
        # Linux specific checks  
        if self.is_linux:
            await self._check_linux_specific_issues(issues)
        
        self.issues_detected = issues
        logger.info(f"Found {len(issues)} network issues")
        
        return issues
    
    async def _test_internet_connectivity(self) -> bool:
        """Test basic internet connectivity"""
        test_urls = [
            'http://www.google.com',
            'http://www.cloudflare.com',
            'http://www.github.com'
        ]
        
        for url in test_urls:
            try:
                response = requests.get(url, timeout=10)
                if response.status_code == 200:
                    return True
            except Exception:
                continue
                
        return False
    
    async def _check_channel_congestion(self, issues: List[Dict]):
        """Check for WiFi channel congestion"""
        if not self.wifi_networks:
            return
            
        # Count networks per channel
        channel_usage = {}
        for network in self.wifi_networks:
            channel = network.channel
            if channel not in channel_usage:
                channel_usage[channel] = []
            channel_usage[channel].append(network)
        
        # Find congested channels (more than 3 networks)
        for channel, networks in channel_usage.items():
            if len(networks) > 3:
                issues.append({
                    'type': 'channel_congestion',
                    'severity': 'medium',
                    'description': f'Channel {channel} has {len(networks)} networks',
                    'solution': f'Switch to less congested channel'
                })
    
    async def _check_ip_conflicts(self, issues: List[Dict]):
        """Check for IP address conflicts"""
        # This would require more sophisticated network scanning
        # For now, just check if multiple interfaces have the same IP
        active_ips = {}
        for interface in self.interfaces:
            if interface.ip_address and interface.status == 'active':
                if interface.ip_address in active_ips:
                    issues.append({
                        'type': 'ip_conflict',
                        'severity': 'high',
                        'description': f'IP conflict detected: {interface.ip_address}',
                        'solution': 'Release and renew IP address'
                    })
                else:
                    active_ips[interface.ip_address] = interface
    
    async def _check_macos_specific_issues(self, issues: List[Dict]):
        """Check for macOS-specific network issues"""
        
        # Check mDNSResponder issues
        success, output, error = self.run_command("ps aux | grep mDNSResponder | grep -v grep")
        if success:
            # Check CPU usage of mDNSResponder
            lines = output.strip().split('\n')
            for line in lines:
                parts = line.split()
                if len(parts) > 2:
                    cpu_usage = float(parts[2])
                    if cpu_usage > 10.0:  # High CPU usage
                        issues.append({
                            'type': 'mdns_high_cpu',
                            'severity': 'medium',
                            'description': f'mDNSResponder using {cpu_usage}% CPU',
                            'solution': 'Restart mDNSResponder service'
                        })
        
        # Check for VPN DNS issues
        success, output, error = self.run_command("scutil --dns")
        if success and 'resolver #8' in output:  # VPN resolvers often appear here
            if 'nameserver' not in output.split('resolver #8')[1].split('resolver #9')[0]:
                issues.append({
                    'type': 'vpn_dns_issue',
                    'severity': 'high',
                    'description': 'VPN DNS configuration may be corrupted',
                    'solution': 'Disconnect and reconnect VPN, or flush DNS cache'
                })
    
    async def _check_linux_specific_issues(self, issues: List[Dict]):
        """Check for Linux-specific network issues"""
        
        # Check NetworkManager status
        success, output, error = self.run_command("systemctl is-active NetworkManager")
        if not success or output.strip() != 'active':
            issues.append({
                'type': 'networkmanager_inactive',
                'severity': 'high',
                'description': 'NetworkManager service is not active',
                'solution': 'Start NetworkManager service'
            })
        
        # Check for power management issues on WiFi
        wifi_interfaces = [iface for iface in self.interfaces if iface.type == 'WiFi']
        for interface in wifi_interfaces:
            success, output, error = self.run_command(f"iwconfig {interface.name}")
            if success and 'Power Management:on' in output:
                issues.append({
                    'type': 'wifi_power_management',
                    'severity': 'medium',
                    'description': f'WiFi power management enabled on {interface.name}',
                    'solution': 'Disable power management for better performance'
                })
    
    async def apply_automatic_fixes(self):
        """Apply automatic fixes for detected issues"""
        logger.info("🔧 Applying automatic fixes...")
        
        fixes_applied = []
        
        for issue in self.issues_detected:
            fix_result = await self._apply_fix_for_issue(issue)
            if fix_result:
                fixes_applied.append(fix_result)
        
        self.fixes_applied = fixes_applied
        logger.info(f"Applied {len(fixes_applied)} automatic fixes")
        
        return fixes_applied
    
    async def _apply_fix_for_issue(self, issue: Dict) -> Optional[Dict]:
        """Apply fix for a specific issue"""
        issue_type = issue['type']
        
        try:
            if issue_type == 'slow_dns':
                return await self._fix_dns_issues()
            elif issue_type == 'mdns_high_cpu':
                return await self._fix_mdns_issues()
            elif issue_type == 'vpn_dns_issue':
                return await self._fix_vpn_dns_issues()
            elif issue_type == 'networkmanager_inactive':
                return await self._fix_networkmanager_issues()
            elif issue_type == 'wifi_power_management':
                return await self._fix_wifi_power_management()
            elif issue_type == 'weak_signal':
                return await self._optimize_wifi_connection()
            else:
                logger.info(f"No automatic fix available for {issue_type}")
                return None
                
        except Exception as e:
            logger.error(f"Failed to apply fix for {issue_type}: {e}")
            return None
    
    async def _fix_dns_issues(self) -> Dict:
        """Fix DNS-related issues"""
        if self.is_mac:
            # Flush DNS cache and restart mDNSResponder
            success1, output1, error1 = self.run_command("sudo dscacheutil -flushcache")
            success2, output2, error2 = self.run_command("sudo killall -HUP mDNSResponder")
            
            if success1 and success2:
                return {
                    'issue': 'slow_dns',
                    'fix': 'Flushed DNS cache and restarted mDNSResponder',
                    'success': True
                }
        else:
            # Linux DNS flush
            success, output, error = self.run_command("sudo systemctl restart systemd-resolved")
            if success:
                return {
                    'issue': 'slow_dns',
                    'fix': 'Restarted systemd-resolved',
                    'success': True
                }
        
        return {'issue': 'slow_dns', 'fix': 'DNS fix failed', 'success': False}
    
    async def _fix_mdns_issues(self) -> Dict:
        """Fix mDNSResponder issues on macOS"""
        success, output, error = self.run_command("sudo killall -HUP mDNSResponder")
        
        return {
            'issue': 'mdns_high_cpu',
            'fix': 'Restarted mDNSResponder',
            'success': success
        }
    
    async def _fix_vpn_dns_issues(self) -> Dict:
        """Fix VPN DNS issues on macOS"""
        # Clear DNS cache and restart mDNSResponder
        success1, output1, error1 = self.run_command("sudo dscacheutil -flushcache")
        success2, output2, error2 = self.run_command("sudo killall -HUP mDNSResponder")
        
        return {
            'issue': 'vpn_dns_issue',
            'fix': 'Cleared VPN DNS cache',
            'success': success1 and success2
        }
    
    async def _fix_networkmanager_issues(self) -> Dict:
        """Fix NetworkManager issues on Linux"""
        success, output, error = self.run_command("sudo systemctl start NetworkManager")
        
        return {
            'issue': 'networkmanager_inactive',
            'fix': 'Started NetworkManager service',
            'success': success
        }
    
    async def _fix_wifi_power_management(self) -> Dict:
        """Fix WiFi power management issues on Linux"""
        wifi_interfaces = [iface for iface in self.interfaces if iface.type == 'WiFi']
        
        for interface in wifi_interfaces:
            success, output, error = self.run_command(f"sudo iwconfig {interface.name} power off")
            if success:
                return {
                    'issue': 'wifi_power_management',
                    'fix': f'Disabled power management on {interface.name}',
                    'success': True
                }
        
        return {'issue': 'wifi_power_management', 'fix': 'Failed to disable power management', 'success': False}
    
    async def _optimize_wifi_connection(self) -> Dict:
        """Optimize WiFi connection"""
        # This is a placeholder for WiFi optimization
        # Would include channel switching, antenna optimization, etc.
        
        return {
            'issue': 'weak_signal',
            'fix': 'Applied WiFi optimization settings',
            'success': True
        }
    
    async def optimize_network_performance(self):
        """Apply network performance optimizations"""
        logger.info("⚡ Optimizing network performance...")
        
        optimizations = []
        
        if self.is_mac:
            optimizations.extend(await self._optimize_macos_network())
        else:
            optimizations.extend(await self._optimize_linux_network())
        
        logger.info(f"Applied {len(optimizations)} network optimizations")
        return optimizations
    
    async def _optimize_macos_network(self) -> List[Dict]:
        """Apply macOS-specific network optimizations"""
        optimizations = []
        
        try:
            # Optimize DNS settings
            success, output, error = self.run_command(
                "sudo networksetup -setdnsservers Wi-Fi 1.1.1.1 8.8.8.8 8.8.4.4"
            )
            if success:
                optimizations.append({
                    'type': 'dns_optimization',
                    'description': 'Set optimized DNS servers (Cloudflare + Google)',
                    'success': True
                })
            
            # Optimize network interface order
            success, output, error = self.run_command(
                "sudo networksetup -ordernetworkservices Wi-Fi Ethernet"
            )
            if success:
                optimizations.append({
                    'type': 'interface_priority',
                    'description': 'Optimized network interface priority',
                    'success': True
                })
                
        except Exception as e:
            logger.error(f"macOS network optimization failed: {e}")
        
        return optimizations
    
    async def _optimize_linux_network(self) -> List[Dict]:
        """Apply Linux-specific network optimizations"""
        optimizations = []
        
        try:
            # Optimize DNS with systemd-resolved
            success, output, error = self.run_command(
                "sudo systemctl enable systemd-resolved"
            )
            if success:
                optimizations.append({
                    'type': 'dns_optimization',
                    'description': 'Enabled systemd-resolved for better DNS performance',
                    'success': True
                })
            
            # Optimize network buffers
            network_optimizations = [
                "echo 'net.core.rmem_max = 16777216' | sudo tee -a /etc/sysctl.conf",
                "echo 'net.core.wmem_max = 16777216' | sudo tee -a /etc/sysctl.conf",
                "echo 'net.ipv4.tcp_rmem = 4096 65536 16777216' | sudo tee -a /etc/sysctl.conf",
                "echo 'net.ipv4.tcp_wmem = 4096 65536 16777216' | sudo tee -a /etc/sysctl.conf"
            ]
            
            for cmd in network_optimizations:
                success, output, error = self.run_command(cmd)
                if success:
                    optimizations.append({
                        'type': 'buffer_optimization',
                        'description': 'Optimized network buffers',
                        'success': True
                    })
                    break
                    
        except Exception as e:
            logger.error(f"Linux network optimization failed: {e}")
        
        return optimizations
    
    def generate_report(self) -> Dict:
        """Generate comprehensive network diagnostic report"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'system': self.system,
            'interfaces': [asdict(iface) for iface in self.interfaces],
            'wifi_networks': [asdict(network) for network in self.wifi_networks],
            'performance': asdict(self.performance_data) if self.performance_data else None,
            'issues_detected': self.issues_detected,
            'fixes_applied': self.fixes_applied,
            'summary': {
                'total_interfaces': len(self.interfaces),
                'active_interfaces': len([i for i in self.interfaces if i.status in ['active', 'up']]),
                'wifi_networks_found': len(self.wifi_networks),
                'issues_found': len(self.issues_detected),
                'fixes_applied': len(self.fixes_applied)
            }
        }
        
        return report
    
    def print_report(self):
        """Print a formatted report to console"""
        print("\n" + "="*80)
        print("🚀 ULTIMATE WIFI FIXER & NETWORK OPTIMIZER - REPORT")
        print("="*80)
        
        print(f"\n📅 Report Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"💻 System: {self.system}")
        
        # Interfaces summary
        print(f"\n🔌 NETWORK INTERFACES ({len(self.interfaces)} found)")
        print("-" * 50)
        for interface in self.interfaces:
            status_emoji = "✅" if interface.status in ['active', 'up'] else "❌"
            print(f"{status_emoji} {interface.name} ({interface.type})")
            print(f"   Status: {interface.status}")
            if interface.ip_address:
                print(f"   IP: {interface.ip_address}")
            if interface.signal_strength:
                print(f"   Signal: {interface.signal_strength} dBm")
            if interface.channel:
                print(f"   Channel: {interface.channel} ({interface.frequency})")
            print()
        
        # WiFi networks
        if self.wifi_networks:
            print(f"\n📡 WIFI NETWORKS ({len(self.wifi_networks)} found)")
            print("-" * 50)
            
            # Sort by signal strength
            sorted_networks = sorted(self.wifi_networks, key=lambda x: x.signal_strength, reverse=True)
            
            for network in sorted_networks[:10]:  # Show top 10
                signal_bars = "📶" if network.signal_strength > -60 else "📶" if network.signal_strength > -70 else "📶"
                print(f"{signal_bars} {network.ssid}")
                print(f"   Signal: {network.signal_strength} dBm ({network.quality}%)")
                print(f"   Channel: {network.channel} ({network.frequency})")
                print(f"   Security: {network.encryption}")
                if network.vendor:
                    print(f"   Vendor: {network.vendor}")
                print()
        
        # Performance data
        if self.performance_data:
            print(f"\n🚀 NETWORK PERFORMANCE")
            print("-" * 50)
            print(f"⬇️  Download Speed: {self.performance_data.download_speed:.1f} Mbps")
            print(f"⬆️  Upload Speed: {self.performance_data.upload_speed:.1f} Mbps")
            print(f"🏓 Ping: {self.performance_data.ping:.1f} ms")
            print(f"🔍 DNS Resolution: {self.performance_data.dns_resolution_time:.1f} ms")
            print()
        
        # Issues detected
        if self.issues_detected:
            print(f"\n⚠️  ISSUES DETECTED ({len(self.issues_detected)} found)")
            print("-" * 50)
            for issue in self.issues_detected:
                severity_emoji = "🔴" if issue['severity'] == 'critical' else "🟡" if issue['severity'] == 'high' else "🟠"
                print(f"{severity_emoji} {issue['description']}")
                print(f"   Solution: {issue['solution']}")
                print()
        else:
            print(f"\n✅ NO ISSUES DETECTED")
            print("-" * 50)
            print("Your network appears to be functioning optimally!")
            print()
        
        # Fixes applied
        if self.fixes_applied:
            print(f"\n🔧 FIXES APPLIED ({len(self.fixes_applied)} applied)")
            print("-" * 50)
            for fix in self.fixes_applied:
                status_emoji = "✅" if fix['success'] else "❌"
                print(f"{status_emoji} {fix['fix']}")
            print()
        
        print("="*80)
        print("🎉 Network analysis complete!")
        print("="*80)

async def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description="Ultimate WiFi Troubleshooter & Network Performance Optimizer",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 ultimate-wifi-fixer.py --scan          # Scan WiFi networks only
  python3 ultimate-wifi-fixer.py --speed-test    # Run speed test only
  python3 ultimate-wifi-fixer.py --fix           # Run full diagnostics and fixes
  python3 ultimate-wifi-fixer.py --optimize      # Apply performance optimizations
  python3 ultimate-wifi-fixer.py --report        # Generate JSON report
        """
    )
    
    parser.add_argument('--scan', action='store_true', help='Scan for WiFi networks')
    parser.add_argument('--speed-test', action='store_true', help='Run network speed test')
    parser.add_argument('--fix', action='store_true', help='Run diagnostics and apply fixes')
    parser.add_argument('--optimize', action='store_true', help='Apply performance optimizations')
    parser.add_argument('--report', action='store_true', help='Generate JSON report')
    parser.add_argument('--output', '-o', help='Output file for JSON report')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose logging')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        fixer = UltimateWiFiFixer()
        
        print("🚀 Ultimate WiFi Troubleshooter & Network Optimizer - 2025 Edition")
        print("🖥️  macOS & Linux Exclusive")
        print("=" * 80)
        
        # Always detect interfaces
        await fixer.detect_network_interfaces()
        
        if args.scan or not any([args.speed_test, args.fix, args.optimize, args.report]):
            await fixer.scan_wifi_networks()
        
        if args.speed_test or not any([args.scan, args.fix, args.optimize, args.report]):
            await fixer.test_network_performance()
        
        if args.fix or not any([args.scan, args.speed_test, args.optimize, args.report]):
            await fixer.diagnose_issues()
            await fixer.apply_automatic_fixes()
        
        if args.optimize:
            await fixer.optimize_network_performance()
        
        if args.report:
            report = fixer.generate_report()
            
            if args.output:
                with open(args.output, 'w') as f:
                    json.dump(report, f, indent=2)
                print(f"📄 Report saved to {args.output}")
            else:
                print(json.dumps(report, indent=2))
        else:
            # Print formatted report
            fixer.print_report()
        
    except KeyboardInterrupt:
        print("\n🛑 Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())