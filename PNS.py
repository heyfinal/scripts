#!/usr/bin/env python3
"""
Professional Network Scanner - Full Featured Python GUI
Requires: pip install scapy python-nmap psutil netifaces
"""

import tkinter as tk
from tkinter import ttk, messagebox, filedialog, scrolledtext
import socket
import subprocess
import threading
import json
import csv
import os
import sys
import time
import ipaddress
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import queue

# Try importing advanced networking libraries
try:
    import scapy.all as scapy
    from scapy.layers.l2 import ARP, Ether
    from scapy.layers.inet import IP, TCP, UDP, ICMP
    SCAPY_AVAILABLE = True
except ImportError:
    SCAPY_AVAILABLE = False
    print("Warning: Scapy not available. Some advanced features disabled.")

try:
    import nmap
    NMAP_AVAILABLE = True
except ImportError:
    NMAP_AVAILABLE = False
    print("Warning: python-nmap not available. Nmap integration disabled.")

try:
    import psutil
    import netifaces
    SYSTEM_INFO_AVAILABLE = True
except ImportError:
    SYSTEM_INFO_AVAILABLE = False
    print("Warning: psutil/netifaces not available. System info features disabled.")


class NetworkScanner:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("NetScope Pro - Professional Network Scanner")
        self.root.geometry("1400x900")
        self.root.configure(bg='#1e1e1e')
        
        # Configure style
        self.style = ttk.Style()
        self.style.theme_use('clam')
        self.configure_styles()
        
        # Variables
        self.scan_running = False
        self.scan_thread = None
        self.discovered_hosts = {}
        self.scan_results = []
        self.log_queue = queue.Queue()
        
        # Create GUI
        self.create_widgets()
        self.setup_menu()
        
        # Start log processor
        self.process_log_queue()
        
    def configure_styles(self):
        """Configure dark theme styles"""
        self.style.configure('Title.TLabel', 
                           background='#1e1e1e', 
                           foreground='#ffffff', 
                           font=('Arial', 16, 'bold'))
        
        self.style.configure('Heading.TLabel', 
                           background='#1e1e1e', 
                           foreground='#00ff88', 
                           font=('Arial', 12, 'bold'))
        
        self.style.configure('Dark.TFrame', background='#1e1e1e')
        self.style.configure('Dark.TLabel', background='#1e1e1e', foreground='#ffffff')
        self.style.configure('Dark.TEntry', background='#333333', foreground='#ffffff')
        
    def create_widgets(self):
        """Create main GUI widgets"""
        # Main container
        main_frame = ttk.Frame(self.root, style='Dark.TFrame')
        main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # Title
        title_label = ttk.Label(main_frame, 
                               text="🛡️ NetScope Pro - Professional Network Scanner", 
                               style='Title.TLabel')
        title_label.pack(pady=(0, 10))
        

        
        # Create notebook for tabs
        self.notebook = ttk.Notebook(main_frame)
        self.notebook.pack(fill=tk.BOTH, expand=True)
        
        # Create tabs
        self.create_scan_config_tab()
        self.create_host_discovery_tab()
        self.create_port_scan_tab()
        self.create_vulnerability_tab()
        self.create_logs_tab()
        
    def create_scan_config_tab(self):
        """Create scan configuration tab"""
        config_frame = ttk.Frame(self.notebook)
        self.notebook.add(config_frame, text="📋 Scan Configuration")
        
        # Scan configuration
        config_label = ttk.Label(config_frame, text="Scan Configuration", style='Heading.TLabel')
        config_label.pack(anchor=tk.W, pady=(10, 5))
        
        # Target configuration
        target_frame = ttk.LabelFrame(config_frame, text="Target Configuration", padding=10)
        target_frame.pack(fill=tk.X, padx=10, pady=5)
        
        # Target network
        ttk.Label(target_frame, text="Target Network/Range:", style='Dark.TLabel').grid(row=0, column=0, sticky=tk.W, pady=2)
        self.target_entry = ttk.Entry(target_frame, width=30, style='Dark.TEntry')
        self.target_entry.insert(0, "192.168.1.0/24")
        self.target_entry.grid(row=0, column=1, padx=(10, 0), pady=2)
        
        # Auto-detect button
        auto_detect_btn = ttk.Button(target_frame, text="Auto-Detect Network", 
                                   command=self.auto_detect_network)
        auto_detect_btn.grid(row=0, column=2, padx=(10, 0), pady=2)
        
        # Port range
        ttk.Label(target_frame, text="Port Range:", style='Dark.TLabel').grid(row=1, column=0, sticky=tk.W, pady=2)
        self.port_entry = ttk.Entry(target_frame, width=30, style='Dark.TEntry')
        self.port_entry.insert(0, "1-1000")
        self.port_entry.grid(row=1, column=1, padx=(10, 0), pady=2)
        
        # Scan options
        options_frame = ttk.LabelFrame(config_frame, text="Scan Options", padding=10)
        options_frame.pack(fill=tk.X, padx=10, pady=5)
        
        # Scan type
        ttk.Label(options_frame, text="Scan Type:", style='Dark.TLabel').grid(row=0, column=0, sticky=tk.W, pady=2)
        self.scan_type = ttk.Combobox(options_frame, values=[
            "TCP Connect", "TCP SYN (Stealth)", "UDP Scan", "Comprehensive", "Quick Discovery"
        ], state="readonly", width=25)
        self.scan_type.set("Comprehensive")
        self.scan_type.grid(row=0, column=1, padx=(10, 0), pady=2)
        
        # Thread count
        ttk.Label(options_frame, text="Concurrent Threads:", style='Dark.TLabel').grid(row=1, column=0, sticky=tk.W, pady=2)
        self.thread_var = tk.StringVar(value="100")
        thread_spin = ttk.Spinbox(options_frame, from_=1, to=500, textvariable=self.thread_var, width=25)
        thread_spin.grid(row=1, column=1, padx=(10, 0), pady=2)
        
        # Timeout
        ttk.Label(options_frame, text="Timeout (seconds):", style='Dark.TLabel').grid(row=2, column=0, sticky=tk.W, pady=2)
        self.timeout_var = tk.StringVar(value="2")
        timeout_spin = ttk.Spinbox(options_frame, from_=1, to=30, textvariable=self.timeout_var, width=25)
        timeout_spin.grid(row=2, column=1, padx=(10, 0), pady=2)
        
        # Advanced options
        advanced_frame = ttk.LabelFrame(config_frame, text="Advanced Options", padding=10)
        advanced_frame.pack(fill=tk.X, padx=10, pady=5)
        
        # Checkboxes for advanced features
        self.os_detection_var = tk.BooleanVar(value=True)
        self.service_detection_var = tk.BooleanVar(value=True)
        self.vulnerability_scan_var = tk.BooleanVar(value=False)
        self.aggressive_scan_var = tk.BooleanVar(value=False)
        
        ttk.Checkbutton(advanced_frame, text="OS Detection", variable=self.os_detection_var).grid(row=0, column=0, sticky=tk.W)
        ttk.Checkbutton(advanced_frame, text="Service Detection", variable=self.service_detection_var).grid(row=0, column=1, sticky=tk.W)
        ttk.Checkbutton(advanced_frame, text="Vulnerability Scanning", variable=self.vulnerability_scan_var).grid(row=1, column=0, sticky=tk.W)
        ttk.Checkbutton(advanced_frame, text="Aggressive Scan", variable=self.aggressive_scan_var).grid(row=1, column=1, sticky=tk.W)
        
        # Control buttons
        control_frame = ttk.Frame(config_frame)
        control_frame.pack(fill=tk.X, padx=10, pady=10)
        
        self.start_btn = ttk.Button(control_frame, text="🚀 Start Scan", command=self.start_scan)
        self.start_btn.pack(side=tk.LEFT, padx=(0, 5))
        
        self.stop_btn = ttk.Button(control_frame, text="⏹️ Stop Scan", command=self.stop_scan, state=tk.DISABLED)
        self.stop_btn.pack(side=tk.LEFT, padx=(0, 5))
        
        self.export_btn = ttk.Button(control_frame, text="📊 Export Results", command=self.export_results)
        self.export_btn.pack(side=tk.LEFT, padx=(0, 5))
        
        # Progress bar
        self.progress = ttk.Progressbar(control_frame, mode='indeterminate')
        self.progress.pack(side=tk.RIGHT, fill=tk.X, expand=True, padx=(10, 0))
        
    def create_host_discovery_tab(self):
        """Create host discovery results tab"""
        hosts_frame = ttk.Frame(self.notebook)
        self.notebook.add(hosts_frame, text="🌐 Host Discovery")
        
        # Host discovery results
        hosts_label = ttk.Label(hosts_frame, text="Discovered Hosts", style='Heading.TLabel')
        hosts_label.pack(anchor=tk.W, pady=(10, 5), padx=10)
        
        # Treeview for hosts
        columns = ('IP', 'Hostname', 'MAC', 'Vendor', 'OS', 'Status', 'Response Time')
        self.hosts_tree = ttk.Treeview(hosts_frame, columns=columns, show='headings', height=15)
        
        for col in columns:
            self.hosts_tree.heading(col, text=col)
            self.hosts_tree.column(col, width=120)
        
        # Scrollbars
        hosts_scroll_y = ttk.Scrollbar(hosts_frame, orient=tk.VERTICAL, command=self.hosts_tree.yview)
        hosts_scroll_x = ttk.Scrollbar(hosts_frame, orient=tk.HORIZONTAL, command=self.hosts_tree.xview)
        self.hosts_tree.configure(yscrollcommand=hosts_scroll_y.set, xscrollcommand=hosts_scroll_x.set)
        
        # Pack treeview and scrollbars
        hosts_scroll_y.pack(side=tk.RIGHT, fill=tk.Y)
        hosts_scroll_x.pack(side=tk.BOTTOM, fill=tk.X)
        self.hosts_tree.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        # Host details frame
        details_frame = ttk.LabelFrame(hosts_frame, text="Host Details", padding=10)
        details_frame.pack(fill=tk.X, padx=10, pady=5)
        
        self.host_details_text = scrolledtext.ScrolledText(details_frame, height=6, background='#333333', foreground='#ffffff')
        self.host_details_text.pack(fill=tk.BOTH, expand=True)
        
        # Bind selection event
        self.hosts_tree.bind('<<TreeviewSelect>>', self.on_host_select)
        
    def create_port_scan_tab(self):
        """Create port scan results tab"""
        ports_frame = ttk.Frame(self.notebook)
        self.notebook.add(ports_frame, text="🔍 Port Scan")
        
        ports_label = ttk.Label(ports_frame, text="Port Scan Results", style='Heading.TLabel')
        ports_label.pack(anchor=tk.W, pady=(10, 5), padx=10)
        
        # Port scan results
        port_columns = ('Host', 'Port', 'Protocol', 'State', 'Service', 'Version', 'Banner')
        self.ports_tree = ttk.Treeview(ports_frame, columns=port_columns, show='headings', height=20)
        
        for col in port_columns:
            self.ports_tree.heading(col, text=col)
            self.ports_tree.column(col, width=100)
        
        # Scrollbars
        ports_scroll_y = ttk.Scrollbar(ports_frame, orient=tk.VERTICAL, command=self.ports_tree.yview)
        ports_scroll_x = ttk.Scrollbar(ports_frame, orient=tk.HORIZONTAL, command=self.ports_tree.xview)
        self.ports_tree.configure(yscrollcommand=ports_scroll_y.set, xscrollcommand=ports_scroll_x.set)
        
        ports_scroll_y.pack(side=tk.RIGHT, fill=tk.Y)
        ports_scroll_x.pack(side=tk.BOTTOM, fill=tk.X)
        self.ports_tree.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
    def create_vulnerability_tab(self):
        """Create vulnerability scan results tab"""
        vuln_frame = ttk.Frame(self.notebook)
        self.notebook.add(vuln_frame, text="🚨 Vulnerabilities")
        
        vuln_label = ttk.Label(vuln_frame, text="Vulnerability Assessment", style='Heading.TLabel')
        vuln_label.pack(anchor=tk.W, pady=(10, 5), padx=10)
        
        # Vulnerability results
        vuln_columns = ('Host', 'Port', 'Vulnerability', 'Severity', 'Description', 'Solution')
        self.vuln_tree = ttk.Treeview(vuln_frame, columns=vuln_columns, show='headings', height=20)
        
        for col in vuln_columns:
            self.vuln_tree.heading(col, text=col)
            self.vuln_tree.column(col, width=120)
        
        # Scrollbars
        vuln_scroll_y = ttk.Scrollbar(vuln_frame, orient=tk.VERTICAL, command=self.vuln_tree.yview)
        vuln_scroll_x = ttk.Scrollbar(vuln_frame, orient=tk.HORIZONTAL, command=self.vuln_tree.xview)
        self.vuln_tree.configure(yscrollcommand=vuln_scroll_y.set, xscrollcommand=vuln_scroll_x.set)
        
        vuln_scroll_y.pack(side=tk.RIGHT, fill=tk.Y)
        vuln_scroll_x.pack(side=tk.BOTTOM, fill=tk.X)
        self.vuln_tree.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
    def create_logs_tab(self):
        """Create scan logs tab"""
        logs_frame = ttk.Frame(self.notebook)
        self.notebook.add(logs_frame, text="📋 Scan Logs")
        
        logs_label = ttk.Label(logs_frame, text="Scan Logs", style='Heading.TLabel')
        logs_label.pack(anchor=tk.W, pady=(10, 5), padx=10)
        
        # Log text area
        self.log_text = scrolledtext.ScrolledText(logs_frame, 
                                                 background='#000000', 
                                                 foreground='#00ff00',
                                                 font=('Courier', 10))
        self.log_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        # Log control buttons
        log_control_frame = ttk.Frame(logs_frame)
        log_control_frame.pack(fill=tk.X, padx=10, pady=5)
        
        ttk.Button(log_control_frame, text="Clear Logs", command=self.clear_logs).pack(side=tk.LEFT)
        ttk.Button(log_control_frame, text="Save Logs", command=self.save_logs).pack(side=tk.LEFT, padx=(5, 0))
        
    def setup_menu(self):
        """Setup application menu"""
        menubar = tk.Menu(self.root)
        self.root.config(menu=menubar)
        
        # File menu
        file_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="File", menu=file_menu)
        file_menu.add_command(label="Export Results", command=self.export_results)
        file_menu.add_command(label="Save Logs", command=self.save_logs)
        file_menu.add_separator()
        file_menu.add_command(label="Exit", command=self.root.quit)
        
        # Tools menu
        tools_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Tools", menu=tools_menu)
        tools_menu.add_command(label="Network Interfaces", command=self.show_network_interfaces)
        tools_menu.add_command(label="System Information", command=self.show_system_info)
        
        # Help menu
        help_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Help", menu=help_menu)
        help_menu.add_command(label="About", command=self.show_about)
        
    def log_message(self, message, level="INFO"):
        """Add message to log queue"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        formatted_message = f"[{timestamp}] [{level}] {message}\n"
        self.log_queue.put(formatted_message)
        
    def process_log_queue(self):
        """Process log queue and update GUI"""
        try:
            while True:
                message = self.log_queue.get_nowait()
                self.log_text.insert(tk.END, message)
                self.log_text.see(tk.END)
        except queue.Empty:
            pass
        finally:
            self.root.after(100, self.process_log_queue)
            
    def auto_detect_network(self):
        """Auto-detect local network"""
        try:
            if SYSTEM_INFO_AVAILABLE:
                interfaces = netifaces.interfaces()
                for interface in interfaces:
                    addresses = netifaces.ifaddresses(interface)
                    if netifaces.AF_INET in addresses:
                        for addr_info in addresses[netifaces.AF_INET]:
                            ip = addr_info.get('addr')
                            netmask = addr_info.get('netmask')
                            if ip and netmask and not ip.startswith('127.'):
                                try:
                                    network = ipaddress.IPv4Network(f"{ip}/{netmask}", strict=False)
                                    self.target_entry.delete(0, tk.END)
                                    self.target_entry.insert(0, str(network))
                                    self.log_message(f"Auto-detected network: {network}")
                                    return
                                except:
                                    continue
            else:
                # Fallback method
                hostname = socket.gethostname()
                ip = socket.gethostbyname(hostname)
                network = ".".join(ip.split(".")[:-1]) + ".0/24"
                self.target_entry.delete(0, tk.END)
                self.target_entry.insert(0, network)
                self.log_message(f"Auto-detected network (fallback): {network}")
                
        except Exception as e:
            self.log_message(f"Failed to auto-detect network: {e}", "ERROR")
            
    def start_scan(self):
        """Start network scan"""
        if self.scan_running:
            return
            
        # Validate inputs
        target = self.target_entry.get().strip()
        if not target:
            messagebox.showerror("Error", "Please specify a target network")
            return
            
        # Clear previous results
        self.clear_results()
        
        # Update UI
        self.scan_running = True
        self.start_btn.config(state=tk.DISABLED)
        self.stop_btn.config(state=tk.NORMAL)
        self.progress.start()
        
        self.log_message("=== Starting Network Scan ===")
        self.log_message(f"Target: {target}")
        self.log_message(f"Scan Type: {self.scan_type.get()}")
        
        # Start scan in separate thread
        self.scan_thread = threading.Thread(target=self.run_scan, args=(target,))
        self.scan_thread.daemon = True
        self.scan_thread.start()
        
    def stop_scan(self):
        """Stop network scan"""
        self.scan_running = False
        self.log_message("Scan stopped by user", "WARNING")
        self.scan_complete()
        
    def scan_complete(self):
        """Handle scan completion"""
        self.scan_running = False
        self.start_btn.config(state=tk.NORMAL)
        self.stop_btn.config(state=tk.DISABLED)
        self.progress.stop()
        self.log_message("=== Scan Complete ===")
        
    def run_scan(self, target):
        """Main scan execution method"""
        try:
            # Parse target network
            try:
                network = ipaddress.IPv4Network(target, strict=False)
                hosts = list(network.hosts())
                if not hosts:  # Single host
                    hosts = [network.network_address]
            except:
                # Try parsing as single IP or hostname
                try:
                    hosts = [ipaddress.IPv4Address(target)]
                except:
                    try:
                        ip = socket.gethostbyname(target)
                        hosts = [ipaddress.IPv4Address(ip)]
                    except:
                        self.log_message(f"Invalid target: {target}", "ERROR")
                        self.scan_complete()
                        return
            
            self.log_message(f"Scanning {len(hosts)} hosts...")
            
            # Host discovery
            live_hosts = self.discover_hosts(hosts)
            
            if not live_hosts:
                self.log_message("No live hosts found", "WARNING")
                self.scan_complete()
                return
                
            self.log_message(f"Found {len(live_hosts)} live hosts")
            
            # Port scanning
            if self.scan_type.get() != "Quick Discovery":
                self.port_scan(live_hosts)
                
            # OS detection
            if self.os_detection_var.get():
                self.os_detection(live_hosts)
                
            # Service detection
            if self.service_detection_var.get():
                self.service_detection(live_hosts)
                
            # Vulnerability scanning
            if self.vulnerability_scan_var.get():
                self.vulnerability_scan(live_hosts)
                
        except Exception as e:
            self.log_message(f"Scan error: {e}", "ERROR")
        finally:
            self.root.after(0, self.scan_complete)
            
    def discover_hosts(self, hosts):
        """Discover live hosts using ping and ARP"""
        live_hosts = []
        max_threads = min(int(self.thread_var.get()), len(hosts))
        
        self.log_message("Starting host discovery...")
        
        with ThreadPoolExecutor(max_workers=max_threads) as executor:
            future_to_host = {executor.submit(self.check_host_alive, str(host)): host for host in hosts}
            
            for future in as_completed(future_to_host):
                if not self.scan_running:
                    break
                    
                host = future_to_host[future]
                try:
                    result = future.result()
                    if result:
                        live_hosts.append(str(host))
                        self.discovered_hosts[str(host)] = result
                        self.add_host_to_tree(str(host), result)
                        self.log_message(f"Host {host} is alive")
                except Exception as e:
                    self.log_message(f"Error checking {host}: {e}", "ERROR")
                    
        return live_hosts
        
    def check_host_alive(self, host):
        """Check if host is alive using multiple methods"""
        host_info = {
            'ip': host,
            'hostname': '',
            'mac': '',
            'vendor': '',
            'os': '',
            'status': 'down',
            'response_time': 0,
            'method': ''
        }
        
        start_time = time.time()
        
        # Try ping first
        if self.ping_host(host):
            host_info['status'] = 'up'
            host_info['method'] = 'ping'
            host_info['response_time'] = int((time.time() - start_time) * 1000)
            
            # Try to get hostname
            try:
                hostname = socket.gethostbyaddr(host)[0]
                host_info['hostname'] = hostname
                self.log_message(f"Resolved hostname for {host}: {hostname}")
            except:
                host_info['hostname'] = ''
                
            # Try MAC address lookup with multiple methods
            self.log_message(f"Looking up MAC address for {host}...")
            mac = self.get_mac_address(host)
            if mac:
                host_info['mac'] = mac
                vendor = self.get_vendor_from_mac(mac)
                host_info['vendor'] = vendor
                self.log_message(f"Found MAC {mac} for {host} -> {vendor}")
            else:
                self.log_message(f"Could not determine MAC address for {host}")
                host_info['mac'] = ''
                host_info['vendor'] = ''
                    
            return host_info
            
        # If ping fails, try TCP connect to common ports
        common_ports = [22, 23, 25, 53, 80, 110, 443, 993, 995, 3389]
        for port in common_ports:
            if not self.scan_running:
                break
            if self.tcp_connect(host, port, 2):  # 2 second timeout for port checks
                host_info['status'] = 'up'
                host_info['method'] = f'tcp/{port}'
                host_info['response_time'] = int((time.time() - start_time) * 1000)
                
                # Still try to get MAC and hostname even if ping failed
                try:
                    hostname = socket.gethostbyaddr(host)[0]
                    host_info['hostname'] = hostname
                except:
                    pass
                    
                mac = self.get_mac_address(host)
                if mac:
                    host_info['mac'] = mac
                    host_info['vendor'] = self.get_vendor_from_mac(mac)
                    
                return host_info
                
        return None
        
    def ping_host(self, host):
        """Ping host using system ping command with fast timeout"""
        try:
            if os.name == 'nt':  # Windows
                result = subprocess.run(['ping', '-n', '1', '-w', '1000', host], 
                                      capture_output=True, timeout=3)
            else:  # Unix/Linux
                result = subprocess.run(['ping', '-c', '1', '-W', '1', host], 
                                      capture_output=True, timeout=3)
            return result.returncode == 0
        except:
            return False
            
    def get_mac_address(self, ip):
        """Get MAC address using multiple methods"""
        if not SCAPY_AVAILABLE:
            return self.get_mac_address_fallback(ip)
            
        try:
            # Method 1: ARP request using scapy
            arp_request = ARP(pdst=ip)
            broadcast = Ether(dst="ff:ff:ff:ff:ff:ff")
            arp_request_broadcast = broadcast / arp_request
            answered_list = scapy.srp(arp_request_broadcast, timeout=1, verbose=False)[0]
            
            if answered_list:
                mac = answered_list[0][1].hwsrc
                self.log_message(f"Found MAC for {ip}: {mac}")
                return mac.upper()
        except Exception as e:
            self.log_message(f"Scapy ARP failed for {ip}: {e}")
            
        # Method 2: Fallback methods
        return self.get_mac_address_fallback(ip)
        
    def get_mac_address_fallback(self, ip):
        """Fallback MAC address detection methods"""
        try:
            # Method 1: Parse ARP table on Windows
            if os.name == 'nt':
                result = subprocess.run(['arp', '-a', ip], capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    for line in result.stdout.split('\n'):
                        if ip in line and 'dynamic' in line.lower():
                            parts = line.split()
                            for part in parts:
                                if '-' in part and len(part) == 17:  # MAC format xx-xx-xx-xx-xx-xx
                                    return part.replace('-', ':').upper()
            else:
                # Method 2: Parse ARP table on Unix/Linux
                result = subprocess.run(['arp', '-n', ip], capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    for line in result.stdout.split('\n'):
                        if ip in line:
                            parts = line.split()
                            for part in parts:
                                if ':' in part and len(part) == 17:  # MAC format xx:xx:xx:xx:xx:xx
                                    return part.upper()
                                    
            # Method 3: Ping then check ARP table
            self.ping_host(ip)
            if os.name == 'nt':
                result = subprocess.run(['arp', '-a'], capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    for line in result.stdout.split('\n'):
                        if ip in line:
                            parts = line.split()
                            for part in parts:
                                if '-' in part and len(part) == 17:
                                    return part.replace('-', ':').upper()
            else:
                result = subprocess.run(['arp', '-a'], capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    for line in result.stdout.split('\n'):
                        if ip in line:
                            parts = line.split()
                            for part in parts:
                                if ':' in part and len(part) == 17:
                                    return part.upper()
        except Exception as e:
            self.log_message(f"MAC detection failed for {ip}: {e}")
            
        return ''
        
    def get_vendor_from_mac(self, mac):
        """Get vendor from MAC address OUI (Organizationally Unique Identifier)"""
        if not mac or len(mac) < 8:
            return 'Unknown'
            
        # Extract OUI (first 3 bytes)
        oui = mac[:8].upper()  # Format: XX:XX:XX
        
        # Comprehensive vendor database (OUI to vendor mapping)
        vendor_db = {
            # Major Network Equipment Vendors
            '00:50:56': 'VMware', '00:0C:29': 'VMware', '00:05:69': 'VMware', '00:1C:14': 'VMware',
            '08:00:27': 'Oracle VirtualBox', '0A:00:27': 'Oracle VirtualBox',
            '00:15:5D': 'Microsoft Hyper-V', '00:03:FF': 'Microsoft',
            '52:54:00': 'QEMU/KVM Virtual Machine',
            
            # Cisco Systems
            '00:01:42': 'Cisco', '00:01:43': 'Cisco', '00:01:63': 'Cisco', '00:01:64': 'Cisco',
            '00:01:96': 'Cisco', '00:01:97': 'Cisco', '00:01:C7': 'Cisco', '00:01:C9': 'Cisco',
            '00:02:16': 'Cisco', '00:02:17': 'Cisco', '00:02:3D': 'Cisco', '00:02:4A': 'Cisco',
            '00:02:4B': 'Cisco', '00:02:B9': 'Cisco', '00:02:BA': 'Cisco', '00:02:FC': 'Cisco',
            '00:02:FD': 'Cisco', '00:03:6B': 'Cisco', '00:03:6C': 'Cisco', '00:03:A0': 'Cisco',
            '00:03:E3': 'Cisco', '00:03:FD': 'Cisco', '00:03:FE': 'Cisco', '00:04:27': 'Cisco',
            '00:04:28': 'Cisco', '00:04:4D': 'Cisco', '00:04:6D': 'Cisco', '00:04:9A': 'Cisco',
            '00:04:C0': 'Cisco', '00:04:C1': 'Cisco', '00:04:DD': 'Cisco', '00:05:00': 'Cisco',
            '00:05:01': 'Cisco', '00:05:31': 'Cisco', '00:05:32': 'Cisco', '00:05:5E': 'Cisco',
            '00:05:73': 'Cisco', '00:05:74': 'Cisco', '00:05:DC': 'Cisco', '00:05:DD': 'Cisco',
            '00:06:28': 'Cisco', '00:06:2A': 'Cisco', '00:06:52': 'Cisco', '00:06:53': 'Cisco',
            '00:06:C1': 'Cisco', '00:06:D6': 'Cisco', '00:06:D7': 'Cisco', '00:07:0D': 'Cisco',
            '00:07:0E': 'Cisco', '00:07:4F': 'Cisco', '00:07:50': 'Cisco', '00:07:7D': 'Cisco',
            '00:07:84': 'Cisco', '00:07:85': 'Cisco', '00:07:B3': 'Cisco', '00:07:B4': 'Cisco',
            '00:07:EB': 'Cisco', '00:07:EC': 'Cisco', '00:08:20': 'Cisco', '00:08:21': 'Cisco',
            '00:08:30': 'Cisco', '00:08:31': 'Cisco', '00:08:7C': 'Cisco', '00:08:7D': 'Cisco',
            '00:08:A3': 'Cisco', '00:08:A4': 'Cisco', '00:08:C2': 'Cisco', '00:08:E2': 'Cisco',
            
            # Intel Corporation
            '00:02:B3': 'Intel', '00:03:47': 'Intel', '00:04:23': 'Intel', '00:05:3C': 'Intel',
            '00:07:E9': 'Intel', '00:0D:3A': 'Intel', '00:0E:0C': 'Intel', '00:12:F0': 'Intel',
            '00:13:02': 'Intel', '00:13:20': 'Intel', '00:13:CE': 'Intel', '00:15:00': 'Intel',
            '00:15:17': 'Intel', '00:16:76': 'Intel', '00:16:EA': 'Intel', '00:16:EB': 'Intel',
            '00:18:DE': 'Intel', '00:19:D1': 'Intel', '00:19:D2': 'Intel', '00:1B:21': 'Intel',
            '00:1C:BF': 'Intel', '00:1D:E0': 'Intel', '00:1D:E1': 'Intel', '00:1E:64': 'Intel',
            '00:1E:65': 'Intel', '00:1E:67': 'Intel', '00:1F:3A': 'Intel', '00:1F:3B': 'Intel',
            '00:1F:3C': 'Intel', '00:21:6A': 'Intel', '00:21:6B': 'Intel', '00:22:FA': 'Intel',
            '00:23:15': 'Intel', '00:24:D6': 'Intel', '00:24:D7': 'Intel', '00:25:64': 'Intel',
            '00:25:65': 'Intel', '00:26:C6': 'Intel', '00:26:C7': 'Intel', '00:27:0E': 'Intel',
            '00:27:10': 'Intel', '18:03:73': 'Intel', '18:5E:0F': 'Intel', '1C:69:7A': 'Intel',
            '1C:B7:2C': 'Intel', '20:16:B9': 'Intel', '24:77:03': 'Intel', '28:D2:44': 'Intel',
            '2C:44:FD': 'Intel', '2C:59:E5': 'Intel', '30:85:A9': 'Intel', '34:13:E8': 'Intel',
            '34:CF:F6': 'Intel', '38:2C:4A': 'Intel', '3C:A9:F4': 'Intel', '40:B0:34': 'Intel',
            '44:85:00': 'Intel', '48:51:B7': 'Intel', '4C:79:6E': 'Intel', '50:7A:55': 'Intel',
            
            # Apple Inc.
            '00:03:93': 'Apple', '00:05:02': 'Apple', '00:0A:27': 'Apple', '00:0A:95': 'Apple',
            '00:0D:93': 'Apple', '00:11:24': 'Apple', '00:14:51': 'Apple', '00:16:CB': 'Apple',
            '00:17:F2': 'Apple', '00:19:E3': 'Apple', '00:1B:63': 'Apple', '00:1E:C2': 'Apple',
            '00:1F:5B': 'Apple', '00:1F:F3': 'Apple', '00:21:E9': 'Apple', '00:22:41': 'Apple',
            '00:23:12': 'Apple', '00:23:32': 'Apple', '00:23:DF': 'Apple', '00:24:36': 'Apple',
            '00:25:00': 'Apple', '00:25:4B': 'Apple', '00:25:BC': 'Apple', '00:26:08': 'Apple',
            '00:26:4A': 'Apple', '00:26:B0': 'Apple', '00:26:BB': 'Apple', '04:0C:CE': 'Apple',
            '04:15:52': 'Apple', '04:1E:64': 'Apple', '04:54:53': 'Apple', '04:69:F8': 'Apple',
            '04:DB:56': 'Apple', '04:E5:36': 'Apple', '08:74:02': 'Apple', '0C:30:21': 'Apple',
            '0C:3E:9F': 'Apple', '0C:4D:E9': 'Apple', '0C:77:1A': 'Apple', '10:40:F3': 'Apple',
            '10:93:E9': 'Apple', '10:9A:DD': 'Apple', '14:10:9F': 'Apple', '14:20:5E': 'Apple',
            '14:5A:05': 'Apple', '14:7D:DA': 'Apple', '14:BD:61': 'Apple', '18:34:51': 'Apple',
            '18:AF:61': 'Apple', '1C:1A:C0': 'Apple', '1C:AB:A7': 'Apple', '20:78:F0': 'Apple',
            '24:A0:74': 'Apple', '24:AB:81': 'Apple', '28:37:37': 'Apple', '28:CF:DA': 'Apple',
            '28:CF:E9': 'Apple', '28:E0:2C': 'Apple', '2C:B4:3A': 'Apple', '30:90:AB': 'Apple',
            '34:15:9E': 'Apple', '34:36:3B': 'Apple', '34:A3:95': 'Apple', '34:C0:59': 'Apple',
            '38:B5:4D': 'Apple', '3C:07:54': 'Apple', '3C:15:C2': 'Apple', '40:31:3C': 'Apple',
            '44:D8:84': 'Apple', '48:43:7C': 'Apple', '48:60:BC': 'Apple', '4C:8D:79': 'Apple',
            '50:ED:3C': 'Apple', '58:55:CA': 'Apple', '5C:59:48': 'Apple', '5C:95:AE': 'Apple',
            '60:33:4B': 'Apple', '60:C5:47': 'Apple', '64:B9:E8': 'Apple', '68:AB:BC': 'Apple',
            '6C:40:08': 'Apple', '6C:72:20': 'Apple', '6C:8D:C1': 'Apple', '70:11:24': 'Apple',
            '70:48:0F': 'Apple', '70:CD:60': 'Apple', '74:E2:F5': 'Apple', '78:31:C1': 'Apple',
            '78:4F:43': 'Apple', '78:67:D0': 'Apple', '78:7B:8A': 'Apple', '78:A3:E4': 'Apple',
            '7C:11:BE': 'Apple', '7C:6D:62': 'Apple', '7C:C3:A1': 'Apple', '7C:D1:C3': 'Apple',
            '80:92:9F': 'Apple', '84:38:35': 'Apple', '84:B1:53': 'Apple', '88:63:DF': 'Apple',
            '8C:58:77': 'Apple', '8C:7C:92': 'Apple', '90:27:E4': 'Apple', '90:72:40': 'Apple',
            '94:F6:A3': 'Apple', '98:01:A7': 'Apple', '98:5A:EB': 'Apple', '9C:04:EB': 'Apple',
            '9C:20:7B': 'Apple', 'A0:99:9B': 'Apple', 'A4:5E:60': 'Apple', 'A8:20:66': 'Apple',
            'A8:86:DD': 'Apple', 'A8:96:75': 'Apple', 'AC:1F:74': 'Apple', 'AC:7F:3E': 'Apple',
            'AC:BC:32': 'Apple', 'B0:19:C6': 'Apple', 'B4:F0:AB': 'Apple', 'B8:09:8A': 'Apple',
            'B8:17:C2': 'Apple', 'B8:53:AC': 'Apple', 'B8:63:BC': 'Apple', 'B8:78:2E': 'Apple',
            'B8:C7:5D': 'Apple', 'B8:E8:56': 'Apple', 'BC:3B:AF': 'Apple', 'BC:52:B7': 'Apple',
            'BC:67:78': 'Apple', 'BC:92:6B': 'Apple', 'C0:33:5E': 'Apple', 'C0:7C:D1': 'Apple',
            'C4:2C:03': 'Apple', 'C8:2A:14': 'Apple', 'C8:69:CD': 'Apple', 'C8:BC:C8': 'Apple',
            'CC:08:8D': 'Apple', 'D0:23:DB': 'Apple', 'D0:A6:37': 'Apple', 'D4:61:9D': 'Apple',
            'D4:9A:20': 'Apple', 'D8:30:62': 'Apple', 'D8:8F:76': 'Apple', 'D8:96:95': 'Apple',
            'D8:A2:5E': 'Apple', 'DC:2B:2A': 'Apple', 'DC:2B:61': 'Apple', 'DC:37:45': 'Apple',
            'DC:A9:04': 'Apple', 'E0:AC:CB': 'Apple', 'E4:8B:7F': 'Apple', 'E4:CE:8F': 'Apple',
            'E8:8D:28': 'Apple', 'EC:35:86': 'Apple', 'F0:18:98': 'Apple', 'F0:DB:E2': 'Apple',
            'F4:37:B7': 'Apple', 'F4:F1:5A': 'Apple', 'F8:1E:DF': 'Apple', 'F8:27:93': 'Apple',
            'F8:2F:A8': 'Apple', 'FC:25:3F': 'Apple',
            
            # Dell Inc.
            '00:06:5B': 'Dell', '00:08:74': 'Dell', '00:0B:DB': 'Dell', '00:0D:56': 'Dell',
            '00:0F:1F': 'Dell', '00:11:43': 'Dell', '00:12:3F': 'Dell', '00:13:72': 'Dell',
            '00:14:22': 'Dell', '00:15:C5': 'Dell', '00:16:F0': 'Dell', '00:18:8B': 'Dell',
            '00:19:B9': 'Dell', '00:1A:A0': 'Dell', '00:1C:23': 'Dell', '00:1D:09': 'Dell',
            '00:1E:4F': 'Dell', '00:21:70': 'Dell', '00:21:9B': 'Dell', '00:22:19': 'Dell',
            '00:23:AE': 'Dell', '00:24:E8': 'Dell', '00:25:64': 'Dell', '00:26:B9': 'Dell',
            '18:03:73': 'Dell', '18:A9:05': 'Dell', '18:FB:7B': 'Dell', '24:B6:FD': 'Dell',
            '2C:76:8A': 'Dell', '34:17:EB': 'Dell', '44:A8:42': 'Dell', '50:9A:4C': 'Dell',
            '5C:F9:DD': 'Dell', '74:86:7A': 'Dell', '78:2B:CB': 'Dell', '78:45:C4': 'Dell',
            '84:8F:69': 'Dell', '90:B1:1C': 'Dell', 'A4:1F:72': 'Dell', 'B0:83:FE': 'Dell',
            'B8:2A:72': 'Dell', 'B8:CA:3A': 'Dell', 'C8:1F:66': 'Dell', 'D0:67:E5': 'Dell',
            'D4:AE:52': 'Dell', 'D4:BE:D9': 'Dell', 'E0:DB:55': 'Dell', 'F0:1F:AF': 'Dell',
            'F8:B1:56': 'Dell', 'F8:BC:12': 'Dell', 'F8:CA:B8': 'Dell',
            
            # Hewlett-Packard (HP)
            '00:01:E6': 'Hewlett-Packard', '00:01:E7': 'Hewlett-Packard', '00:02:A5': 'Hewlett-Packard',
            '00:04:EA': 'Hewlett-Packard', '00:08:02': 'Hewlett-Packard', '00:0B:CD': 'Hewlett-Packard',
            '00:0D:9D': 'Hewlett-Packard', '00:0E:7F': 'Hewlett-Packard', '00:10:83': 'Hewlett-Packard',
            '00:11:0A': 'Hewlett-Packard', '00:11:85': 'Hewlett-Packard', '00:12:79': 'Hewlett-Packard',
            '00:13:21': 'Hewlett-Packard', '00:14:38': 'Hewlett-Packard', '00:14:C2': 'Hewlett-Packard',
            '00:15:60': 'Hewlett-Packard', '00:16:35': 'Hewlett-Packard', '00:17:08': 'Hewlett-Packard',
            '00:17:A4': 'Hewlett-Packard', '00:18:FE': 'Hewlett-Packard', '00:19:BB': 'Hewlett-Packard',
            '00:1A:4B': 'Hewlett-Packard', '00:1B:78': 'Hewlett-Packard', '00:1C:C4': 'Hewlett-Packard',
            '00:1D:31': 'Hewlett-Packard', '00:1E:0B': 'Hewlett-Packard', '00:1F:28': 'Hewlett-Packard',
            '00:1F:29': 'Hewlett-Packard', '00:21:5A': 'Hewlett-Packard', '00:22:64': 'Hewlett-Packard',
            '00:23:7D': 'Hewlett-Packard', '00:24:81': 'Hewlett-Packard', '00:25:B3': 'Hewlett-Packard',
            '00:26:55': 'Hewlett-Packard', '00:26:F1': 'Hewlett-Packard', '00:30:6E': 'Hewlett-Packard',
            '00:60:B0': 'Hewlett-Packard', '08:2E:5F': 'Hewlett-Packard', '08:9E:01': 'Hewlett-Packard',
            '10:1F:74': 'Hewlett-Packard', '14:02:EC': 'Hewlett-Packard', '14:58:D0': 'Hewlett-Packard',
            '18:A9:05': 'Hewlett-Packard', '1C:C1:DE': 'Hewlett-Packard', '28:92:4A': 'Hewlett-Packard',
            '2C:27:D7': 'Hewlett-Packard', '2C:41:38': 'Hewlett-Packard', '2C:44:FD': 'Hewlett-Packard',
            '30:8D:99': 'Hewlett-Packard', '34:64:A9': 'Hewlett-Packard', '38:EA:A7': 'Hewlett-Packard',
            '3C:4A:92': 'Hewlett-Packard', '3C:52:82': 'Hewlett-Packard', '40:A8:F0': 'Hewlett-Packard',
            '44:31:92': 'Hewlett-Packard', '48:0F:CF': 'Hewlett-Packard', '4C:39:09': 'Hewlett-Packard',
            '50:65:F3': 'Hewlett-Packard', '5C:B9:01': 'Hewlett-Packard', '64:31:50': 'Hewlett-Packard',
            '6C:3B:E5': 'Hewlett-Packard', '70:10:6F': 'Hewlett-Packard', '78:E3:B5': 'Hewlett-Packard',
            '78:E7:D1': 'Hewlett-Packard', '7C:C3:A1': 'Hewlett-Packard', '80:C1:6E': 'Hewlett-Packard',
            '9C:8E:99': 'Hewlett-Packard', 'A0:1D:48': 'Hewlett-Packard', 'A0:B3:CC': 'Hewlett-Packard',
            'A4:5D:36': 'Hewlett-Packard', 'B4:39:D6': 'Hewlett-Packard', 'B4:99:BA': 'Hewlett-Packard',
            'C8:CB:B8': 'Hewlett-Packard', 'CC:3E:5F': 'Hewlett-Packard', 'D0:7E:28': 'Hewlett-Packard',
            'D4:85:64': 'Hewlett-Packard', 'D8:9D:67': 'Hewlett-Packard', 'E8:39:35': 'Hewlett-Packard',
            'EC:B1:D7': 'Hewlett-Packard', 'F0:92:1C': 'Hewlett-Packard', 'F4:CE:46': 'Hewlett-Packard',
            
            # Samsung Electronics
            '00:07:AB': 'Samsung', '00:09:18': 'Samsung', '00:0D:E5': 'Samsung', '00:12:FB': 'Samsung',
            '00:13:77': 'Samsung', '00:15:99': 'Samsung', '00:16:32': 'Samsung', '00:17:C9': 'Samsung',
            '00:17:D5': 'Samsung', '00:18:AF': 'Samsung', '00:1A:8A': 'Samsung', '00:1B:98': 'Samsung',
            '00:1D:25': 'Samsung', '00:1E:7D': 'Samsung', '00:1F:CC': 'Samsung', '00:21:19': 'Samsung',
            '00:23:39': 'Samsung', '00:24:54': 'Samsung', '00:26:37': 'Samsung', '04:18:D6': 'Samsung',
            '04:FE:7F': 'Samsung', '08:08:C2': 'Samsung', '08:37:3D': 'Samsung', '08:EC:A9': 'Samsung',
            '0C:14:20': 'Samsung', '0C:89:10': 'Samsung', '10:30:47': 'Samsung', '14:49:E0': 'Samsung',
            '18:3A:2D': 'Samsung', '18:42:2F': 'Samsung', '1C:5A:3E': 'Samsung', '20:64:32': 'Samsung',
            '20:A1:7C': 'Samsung', '24:4B:81': 'Samsung', '28:BA:B5': 'Samsung', '28:E3:1F': 'Samsung',
            '2C:8A:72': 'Samsung', '30:07:4D': 'Samsung', '30:19:66': 'Samsung', '34:BE:00': 'Samsung',
            '34:E2:FD': 'Samsung', '38:AA:3C': 'Samsung', '3C:BD:3E': 'Samsung', '40:0E:85': 'Samsung',
            '40:4E:36': 'Samsung', '44:00:10': 'Samsung', '44:5E:F3': 'Samsung', '48:5A:3F': 'Samsung',
            '4C:3C:16': 'Samsung', '4C:66:41': 'Samsung', '50:32:37': 'Samsung', '50:CC:F8': 'Samsung',
            '5C:0E:8B': 'Samsung', '5C:51:4F': 'Samsung', '60:6B:BD': 'Samsung', '64:B8:53': 'Samsung',
            '68:A8:B2': 'Samsung', '68:EB:C5': 'Samsung', '6C:2F:2C': 'Samsung', '6C:94:66': 'Samsung',
            '70:F9:27': 'Samsung', '74:45:8A': 'Samsung', '78:1F:DB': 'Samsung', '78:25:AD': 'Samsung',
            '78:47:1D': 'Samsung', '7C:61:66': 'Samsung', '7C:B0:C2': 'Samsung', '80:18:A7': 'Samsung',
            '84:11:9E': 'Samsung', '84:25:3F': 'Samsung', '88:32:9B': 'Samsung', '8C:77:12': 'Samsung',
            '90:18:7C': 'Samsung', '94:51:03': 'Samsung', '98:52:3D': 'Samsung', '9C:02:98': 'Samsung',
            '9C:3A:AF': 'Samsung', 'A0:0B:BA': 'Samsung', 'A0:21:B7': 'Samsung', 'A4:EB:D3': 'Samsung',
            'A8:F2:74': 'Samsung', 'AC:36:13': 'Samsung', 'AC:5A:14': 'Samsung', 'B4:62:93': 'Samsung',
            'B8:5E:7B': 'Samsung', 'BC:14:85': 'Samsung', 'BC:20:A4': 'Samsung', 'BC:72:B1': 'Samsung',
            'BC:F5:AC': 'Samsung', 'C0:BD:D1': 'Samsung', 'C4:42:02': 'Samsung', 'C8:19:F7': 'Samsung',
            'CC:07:AB': 'Samsung', 'CC:FE:3C': 'Samsung', 'D0:17:C2': 'Samsung', 'D0:22:BE': 'Samsung',
            'D0:DF:9A': 'Samsung', 'D4:87:D8': 'Samsung', 'D4:E8:B2': 'Samsung', 'DC:71:96': 'Samsung',
            'E8:50:8B': 'Samsung', 'E8:E5:D6': 'Samsung', 'EC:1F:72': 'Samsung', 'F0:25:B7': 'Samsung',
            'F4:0F:24': 'Samsung', 'F8:04:2E': 'Samsung', 'F8:E6:1A': 'Samsung', 'FC:00:12': 'Samsung',
            
            # Netgear
            '00:09:5B': 'Netgear', '00:0F:B5': 'Netgear', '00:14:6C': 'Netgear', '00:18:4D': 'Netgear',
            '00:1B:2F': 'Netgear', '00:1E:2A': 'Netgear', '00:22:3F': 'Netgear', '00:24:B2': 'Netgear',
            '00:26:F2': 'Netgear', '04:A1:51': 'Netgear', '08:BD:43': 'Netgear', '10:0D:7F': 'Netgear',
            '10:DA:43': 'Netgear', '14:59:C0': 'Netgear', '20:4E:7F': 'Netgear', '28:C6:8E': 'Netgear',
            '2C:30:33': 'Netgear', '30:46:9A': 'Netgear', '44:94:FC': 'Netgear', '4C:60:DE': 'Netgear',
            '5C:D9:98': 'Netgear', '6C:B0:CE': 'Netgear', '74:44:01': 'Netgear', '84:1B:5E': 'Netgear',
            '9C:3D:CF': 'Netgear', 'A0:04:60': 'Netgear', 'A0:40:A0': 'Netgear', 'B0:39:56': 'Netgear',
            'C0:3F:0E': 'Netgear', 'C4:04:15': 'Netgear', 'CC:40:D0': 'Netgear', 'E0:46:9A': 'Netgear',
            'E4:F4:C6': 'Netgear', 'E8:FC:AF': 'Netgear',
            
            # TP-Link
            '00:25:86': 'TP-Link', '04:DA:D2': 'TP-Link', '08:57:00': 'TP-Link', '0C:80:63': 'TP-Link',
            '10:BF:48': 'TP-Link', '14:CF:92': 'TP-Link', '18:D6:C7': 'TP-Link', '1C:BD:B9': 'TP-Link',
            '20:F4:78': 'TP-Link', '24:05:0F': 'TP-Link', '28:6C:07': 'TP-Link', '2C:F0:5D': 'TP-Link',
            '30:B5:C2': 'TP-Link', '34:2D:0D': 'TP-Link', '38:94:ED': 'TP-Link', '3C:84:6A': 'TP-Link',
            '40:4A:03': 'TP-Link', '44:D1:FA': 'TP-Link', '48:8F:5A': 'TP-Link', '4C:E1:73': 'TP-Link',
            '50:64:2B': 'TP-Link', '54:04:A6': 'TP-Link', '58:D5:6E': 'TP-Link', '5C:E9:31': 'TP-Link',
            '60:E3:27': 'TP-Link', '64:70:02': 'TP-Link', '68:FF:7B': 'TP-Link', '6C:5A:B0': 'TP-Link',
            '70:4F:57': 'TP-Link', '74:DA:88': 'TP-Link', '78:8A:20': 'TP-Link', '7C:8B:CA': 'TP-Link',
            '80:EA:07': 'TP-Link', '84:16:F9': 'TP-Link', '88:25:2C': 'TP-Link', '8C:21:0A': 'TP-Link',
            '90:F6:52': 'TP-Link', '94:D9:B3': 'TP-Link', '98:DA:C4': 'TP-Link', '9C:A2:F4': 'TP-Link',
            'A0:F3:C1': 'TP-Link', 'A4:2B:B0': 'TP-Link', 'A8:40:41': 'TP-Link', 'AC:84:C6': 'TP-Link',
            'B0:48:7A': 'TP-Link', 'B4:B0:24': 'TP-Link', 'B8:A3:86': 'TP-Link', 'BC:46:99': 'TP-Link',
            'C0:25:5C': 'TP-Link', 'C4:E9:84': 'TP-Link', 'C8:0E:14': 'TP-Link', 'CC:32:E5': 'TP-Link',
            'D0:76:E7': 'TP-Link', 'D4:6E:0E': 'TP-Link', 'D8:07:B6': 'TP-Link', 'DC:9F:DB': 'TP-Link',
            'E0:28:6D': 'TP-Link', 'E4:C7:22': 'TP-Link', 'E8:DE:27': 'TP-Link', 'EC:08:6B': 'TP-Link',
            'F0:2F:74': 'TP-Link', 'F4:EC:38': 'TP-Link', 'F8:1A:67': 'TP-Link', 'FC:EC:DA': 'TP-Link',
            
            # D-Link
            '00:05:5D': 'D-Link', '00:0D:88': 'D-Link', '00:0F:3D': 'D-Link', '00:11:95': 'D-Link',
            '00:13:46': 'D-Link', '00:15:E9': 'D-Link', '00:17:9A': 'D-Link', '00:19:5B': 'D-Link',
            '00:1B:11': 'D-Link', '00:1C:F0': 'D-Link', '00:1E:58': 'D-Link', '00:21:91': 'D-Link',
            '00:22:B0': 'D-Link', '00:24:01': 'D-Link', '00:26:5A': 'D-Link', '14:D6:4D': 'D-Link',
            '1C:7E:E5': 'D-Link', '1C:AF:F7': 'D-Link', '28:10:7B': 'D-Link', '2C:B0:5D': 'D-Link',
            '34:08:04': 'D-Link', '50:46:5D': 'D-Link', '5C:D9:98': 'D-Link', '78:54:2E': 'D-Link',
            '84:C9:B2': 'D-Link', '90:94:E4': 'D-Link', 'B8:A3:86': 'D-Link', 'C8:BE:19': 'D-Link',
            'C8:D3:A3': 'D-Link', 'CC:B2:55': 'D-Link', 'F0:7D:68': 'D-Link',
            
            # Raspberry Pi Foundation
            'B8:27:EB': 'Raspberry Pi', 'DC:A6:32': 'Raspberry Pi', 'E4:5F:01': 'Raspberry Pi',
            '28:CD:C1': 'Raspberry Pi', 'B8:27:EB': 'Raspberry Pi', 'DC:A6:32': 'Raspberry Pi',
            
            # Ubiquiti Networks
            '00:15:6D': 'Ubiquiti', '00:27:22': 'Ubiquiti', '04:18:D6': 'Ubiquiti', '24:A4:3C': 'Ubiquiti',
            '44:D9:E7': 'Ubiquiti', '68:72:51': 'Ubiquiti', '74:83:C2': 'Ubiquiti', '78:8A:20': 'Ubiquiti',
            '80:2A:A8': 'Ubiquiti', 'B4:FB:E4': 'Ubiquiti', 'DC:9F:DB': 'Ubiquiti', 'F0:9F:C2': 'Ubiquiti',
            'F4:92:BF': 'Ubiquiti',
            
            # ASUS
            '00:0E:A6': 'ASUSTeK', '00:11:2F': 'ASUSTeK', '00:13:D4': 'ASUSTeK', '00:15:F2': 'ASUSTeK',
            '00:17:31': 'ASUSTeK', '00:19:DB': 'ASUSTeK', '00:1B:FC': 'ASUSTeK', '00:1D:60': 'ASUSTeK',
            '00:1F:C6': 'ASUSTeK', '00:22:15': 'ASUSTeK', '00:23:54': 'ASUSTeK', '00:24:8C': 'ASUSTeK',
            '00:26:18': 'ASUSTeK', '04:D4:C4': 'ASUSTeK', '08:60:6E': 'ASUSTeK', '0C:9D:92': 'ASUSTeK',
            '10:BF:48': 'ASUSTeK', '14:DD:A9': 'ASUSTeK', '18:31:BF': 'ASUSTeK', '1C:87:2C': 'ASUSTeK',
            '20:CF:30': 'ASUSTeK', '24:4B:FE': 'ASUSTeK', '28:28:5D': 'ASUSTeK', '2C:FD:A1': 'ASUSTeK',
            '30:5A:3A': 'ASUSTeK', '34:97:F6': 'ASUSTeK', '38:D5:47': 'ASUSTeK', '3C:7C:3F': 'ASUSTeK',
            '40:16:7E': 'ASUSTeK', '44:85:00': 'ASUSTeK', '48:EE:0C': 'ASUSTeK', '4C:ED:FB': 'ASUSTeK',
            '50:46:5D': 'ASUSTeK', '54:A0:50': 'ASUSTeK', '58:11:22': 'ASUSTeK', '5C:33:8E': 'ASUSTeK',
            '60:45:CB': 'ASUSTeK', '64:D1:54': 'ASUSTeK', '68:1C:A2': 'ASUSTeK', '6C:62:6D': 'ASUSTeK',
            '70:8B:CD': 'ASUSTeK', '74:D0:2B': 'ASUSTeK', '78:24:AF': 'ASUSTeK', '7C:10:C9': 'ASUSTeK',
            '80:1F:02': 'ASUSTeK', '84:A4:23': 'ASUSTeK', '88:D7:F6': 'ASUSTeK', '8C:10:D4': 'ASUSTeK',
            '90:48:9A': 'ASUSTeK', '94:DE:80': 'ASUSTeK', '98:5F:D3': 'ASUSTeK', '9C:5C:8E': 'ASUSTeK',
            'A0:1B:29': 'ASUSTeK', 'A4:2B:8C': 'ASUSTeK', 'A8:5E:45': 'ASUSTeK', 'AC:9E:17': 'ASUSTeK',
            'B0:6E:BF': 'ASUSTeK', 'B4:2E:99': 'ASUSTeK', 'B8:AE:ED': 'ASUSTeK', 'BC:EE:7B': 'ASUSTeK',
            'C0:56:27': 'ASUSTeK', 'C4:04:15': 'ASUSTeK', 'C8:60:00': 'ASUSTeK', 'CC:2F:71': 'ASUSTeK',
            'D0:17:C2': 'ASUSTeK', 'D4:5D:64': 'ASUSTeK', 'D8:50:E6': 'ASUSTeK', 'DC:85:DE': 'ASUSTeK',
            'E0:3F:49': 'ASUSTeK', 'E4:70:B8': 'ASUSTeK', 'E8:94:F6': 'ASUSTeK', 'EC:08:6B': 'ASUSTeK',
            'F0:79:59': 'ASUSTeK', 'F4:6D:04': 'ASUSTeK', 'F8:32:E4': 'ASUSTeK', 'FC:34:97': 'ASUSTeK',
            
            # Common Router/Network Equipment Vendors
            '00:1A:2B': 'Juniper Networks', '00:05:85': 'Juniper Networks', '00:12:1E': 'Juniper Networks',
            '00:90:69': 'Juniper Networks', '2C:6B:F5': 'Juniper Networks', '3C:61:04': 'Juniper Networks',
            '50:C5:8D': 'Juniper Networks', '5C:5E:AB': 'Juniper Networks', '78:19:F7': 'Juniper Networks',
            '84:B5:9C': 'Juniper Networks', '80:AC:AC': 'Juniper Networks', '9C:CC:83': 'Juniper Networks',
            
            '00:04:96': 'Linksys', '00:06:25': 'Linksys', '00:0C:41': 'Linksys', '00:0E:08': 'Linksys',
            '00:12:17': 'Linksys', '00:13:10': 'Linksys', '00:14:BF': 'Linksys', '00:16:B6': 'Linksys',
            '00:18:39': 'Linksys', '00:18:F8': 'Linksys', '00:1A:70': 'Linksys', '00:1C:10': 'Linksys',
            '00:1D:7E': 'Linksys', '00:1E:E5': 'Linksys', '00:20:A6': 'Linksys', '00:21:29': 'Linksys',
            '00:22:6B': 'Linksys', '00:23:69': 'Linksys', '00:25:9C': 'Linksys', '08:86:3B': 'Linksys',
            '14:91:82': 'Linksys', '20:AA:4B': 'Linksys', '24:F5:A2': 'Linksys', '30:23:03': 'Linksys',
            '48:F8:B3': 'Linksys', '58:6D:8F': 'Linksys', '60:38:E0': 'Linksys', '98:01:A7': 'Linksys',
            'C0:56:27': 'Linksys', 'C4:41:1E': 'Linksys',
        }
        
        vendor = vendor_db.get(oui, 'Unknown')
        if vendor == 'Unknown':
            # Try first 6 characters (XX:XX:X format)
            short_oui = mac[:5].upper()
            vendor = vendor_db.get(short_oui, 'Unknown')
            
        return vendor
        
    def tcp_connect(self, host, port, timeout=3):
        """TCP connect scan"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(timeout)
            result = sock.connect_ex((host, port))
            sock.close()
            return result == 0
        except:
            return False
            
    def fast_tcp_scan(self, host, port, timeout=1):
        """Optimized TCP connect scan with shorter timeout"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(timeout)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            result = sock.connect_ex((host, port))
            sock.close()
            return result == 0
        except:
            return False
            
    def port_scan(self, hosts):
        """Perform high-speed port scanning on live hosts"""
        self.log_message("Starting high-speed port scan...")
        
        # Parse port range
        port_range = self.port_entry.get().strip()
        ports = self.parse_port_range(port_range)
        
        max_threads = int(self.thread_var.get())
        timeout = max(1, int(self.timeout_var.get()) // 2)  # Faster timeout for port scanning
        
        # Create all host/port combinations for concurrent scanning
        scan_targets = [(host, port) for host in hosts for port in ports]
        total_targets = len(scan_targets)
        completed = 0
        
        self.log_message(f"Scanning {len(ports)} ports on {len(hosts)} hosts ({total_targets} total checks)")
        
        # Use a single thread pool for all scanning
        with ThreadPoolExecutor(max_workers=max_threads) as executor:
            # Submit all scan jobs at once
            future_to_target = {
                executor.submit(self.fast_tcp_scan, host, port, timeout): (host, port)
                for host, port in scan_targets
            }
            
            for future in as_completed(future_to_target):
                if not self.scan_running:
                    break
                    
                host, port = future_to_target[future]
                completed += 1
                
                # Update progress every 50 scans
                if completed % 50 == 0:
                    progress = (completed / total_targets) * 100
                    self.log_message(f"Port scan progress: {completed}/{total_targets} ({progress:.1f}%)")
                
                try:
                    is_open = future.result()
                    if is_open:
                        service = self.get_service_name(port)
                        banner = self.get_banner(host, port) if port in [21, 22, 25, 80, 110, 143, 443] else ''
                        self.add_port_to_tree(host, port, 'tcp', 'open', service, '', banner)
                        self.log_message(f"Open: {host}:{port}/tcp ({service})")
                except Exception as e:
                    pass
                    
        self.log_message(f"Port scan completed. Scanned {completed} targets.")
                        
    def parse_port_range(self, port_range):
        """Parse port range string"""
        ports = []
        try:
            if '-' in port_range:
                start, end = map(int, port_range.split('-'))
                ports = list(range(start, end + 1))
            elif ',' in port_range:
                ports = [int(p.strip()) for p in port_range.split(',')]
            else:
                ports = [int(port_range)]
        except:
            ports = list(range(1, 1001))  # Default range
        return ports
        
    def get_service_name(self, port):
        """Get service name for port"""
        services = {
            21: 'FTP', 22: 'SSH', 23: 'Telnet', 25: 'SMTP', 53: 'DNS',
            80: 'HTTP', 110: 'POP3', 143: 'IMAP', 443: 'HTTPS', 993: 'IMAPS',
            995: 'POP3S', 3389: 'RDP', 3306: 'MySQL', 5432: 'PostgreSQL',
            1433: 'MSSQL', 27017: 'MongoDB'
        }
        return services.get(port, 'Unknown')
        
    def get_banner(self, host, port):
        """Get service banner with fast timeout"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(1)  # Fast 1-second timeout for banner grabbing
            sock.connect((host, port))
            
            # Send HTTP request for web services
            if port in [80, 443, 8080, 8443]:
                sock.send(b"HEAD / HTTP/1.1\r\nHost: " + host.encode() + b"\r\n\r\n")
            elif port == 21:  # FTP
                pass  # FTP sends banner automatically
            elif port == 22:  # SSH
                pass  # SSH sends banner automatically
            elif port == 25:  # SMTP
                pass  # SMTP sends banner automatically
            
            banner = sock.recv(1024).decode('utf-8', errors='ignore').strip()
            sock.close()
            
            # Clean up banner - take first line and limit length
            if banner:
                first_line = banner.split('\n')[0].split('\r')[0]
                return first_line[:100]  # Limit banner length
            return ''
        except:
            return ''
            
    def os_detection(self, hosts):
        """Basic OS detection"""
        self.log_message("Starting OS detection...")
        
        for host in hosts:
            if not self.scan_running:
                break
                
            os_guess = self.guess_os(host)
            if os_guess and host in self.discovered_hosts:
                self.discovered_hosts[host]['os'] = os_guess
                self.update_host_in_tree(host)
                
    def guess_os(self, host):
        """Simple OS detection based on open ports and TTL"""
        # This is a simplified version - real OS detection is much more complex
        common_ports = {
            'Windows': [135, 139, 445, 3389],
            'Linux': [22, 111],
            'macOS': [22, 548, 631]
        }
        
        open_ports = []
        for port in [22, 135, 139, 445, 548, 631, 3389]:
            if self.tcp_connect(host, port, 2):
                open_ports.append(port)
                
        # Simple heuristics
        if 3389 in open_ports or 135 in open_ports:
            return 'Windows'
        elif 22 in open_ports and 548 not in open_ports:
            return 'Linux'
        elif 548 in open_ports:
            return 'macOS'
        else:
            return 'Unknown'
            
    def service_detection(self, hosts):
        """Enhanced service detection"""
        self.log_message("Starting service detection...")
        # This would be expanded with more sophisticated service detection
        
    def vulnerability_scan(self, hosts):
        """Basic vulnerability scanning"""
        self.log_message("Starting vulnerability scan...")
        
        for host in hosts:
            if not self.scan_running:
                break
                
            # Check for common vulnerabilities
            vulns = self.check_common_vulnerabilities(host)
            for vuln in vulns:
                self.add_vulnerability_to_tree(*vuln)
                
    def check_common_vulnerabilities(self, host):
        """Check for common vulnerabilities"""
        vulnerabilities = []
        
        # Check for open Telnet (insecure)
        if self.tcp_connect(host, 23, 2):
            vulnerabilities.append((
                host, 23, 'Insecure Telnet Service', 'Medium',
                'Telnet transmits data in plaintext', 'Use SSH instead'
            ))
            
        # Check for open FTP (potentially insecure)
        if self.tcp_connect(host, 21, 2):
            vulnerabilities.append((
                host, 21, 'Potentially Insecure FTP', 'Low',
                'FTP may transmit credentials in plaintext', 'Use SFTP or FTPS'
            ))
            
        # Check for open RDP
        if self.tcp_connect(host, 3389, 2):
            vulnerabilities.append((
                host, 3389, 'RDP Service Exposed', 'Medium',
                'RDP exposed to network', 'Restrict access and use strong authentication'
            ))
            
        return vulnerabilities
        
    def add_host_to_tree(self, ip, host_info):
        """Add host to discovery tree"""
        self.root.after(0, lambda: self.hosts_tree.insert('', tk.END, values=(
            ip,
            host_info.get('hostname', ''),
            host_info.get('mac', ''),
            host_info.get('vendor', ''),
            host_info.get('os', ''),
            host_info.get('status', ''),
            f"{host_info.get('response_time', 0)}ms"
        )))
        
    def update_host_in_tree(self, ip):
        """Update host information in tree"""
        # Implementation for updating existing tree items
        pass
        
    def add_port_to_tree(self, host, port, protocol, state, service, version, banner):
        """Add port to ports tree"""
        self.root.after(0, lambda: self.ports_tree.insert('', tk.END, values=(
            host, port, protocol, state, service, version, banner
        )))
        
    def add_vulnerability_to_tree(self, host, port, vuln, severity, desc, solution):
        """Add vulnerability to tree"""
        self.root.after(0, lambda: self.vuln_tree.insert('', tk.END, values=(
            host, port, vuln, severity, desc, solution
        )))
        
    def on_host_select(self, event):
        """Handle host selection in tree"""
        selection = self.hosts_tree.selection()
        if not selection:
            return
            
        item = self.hosts_tree.item(selection[0])
        values = item['values']
        
        if values:
            ip = values[0]
            if ip in self.discovered_hosts:
                host_info = self.discovered_hosts[ip]
                details = f"IP Address: {ip}\n"
                details += f"Hostname: {host_info.get('hostname', 'N/A')}\n"
                details += f"MAC Address: {host_info.get('mac', 'N/A')}\n"
                details += f"Vendor: {host_info.get('vendor', 'N/A')}\n"
                details += f"Operating System: {host_info.get('os', 'N/A')}\n"
                details += f"Status: {host_info.get('status', 'N/A')}\n"
                details += f"Detection Method: {host_info.get('method', 'N/A')}\n"
                
                self.host_details_text.delete(1.0, tk.END)
                self.host_details_text.insert(1.0, details)
                
    def clear_results(self):
        """Clear all results"""
        self.hosts_tree.delete(*self.hosts_tree.get_children())
        self.ports_tree.delete(*self.ports_tree.get_children())
        self.vuln_tree.delete(*self.vuln_tree.get_children())
        self.host_details_text.delete(1.0, tk.END)
        self.discovered_hosts.clear()
        self.scan_results.clear()
        
    def clear_logs(self):
        """Clear log text"""
        self.log_text.delete(1.0, tk.END)
        
    def save_logs(self):
        """Save logs to file"""
        filename = filedialog.asksaveasfilename(
            defaultextension=".txt",
            filetypes=[("Text files", "*.txt"), ("All files", "*.*")]
        )
        if filename:
            with open(filename, 'w') as f:
                f.write(self.log_text.get(1.0, tk.END))
            self.log_message(f"Logs saved to {filename}")
            
    def export_results(self):
        """Export scan results"""
        if not self.discovered_hosts and not self.scan_results:
            messagebox.showwarning("Warning", "No results to export")
            return
            
        filename = filedialog.asksaveasfilename(
            defaultextension=".json",
            filetypes=[("JSON files", "*.json"), ("CSV files", "*.csv"), ("All files", "*.*")]
        )
        
        if filename:
            try:
                if filename.endswith('.json'):
                    export_data = {
                        'scan_timestamp': datetime.now().isoformat(),
                        'target': self.target_entry.get(),
                        'scan_type': self.scan_type.get(),
                        'discovered_hosts': self.discovered_hosts,
                        'scan_results': self.scan_results
                    }
                    with open(filename, 'w') as f:
                        json.dump(export_data, f, indent=2)
                else:  # CSV
                    with open(filename, 'w', newline='') as f:
                        writer = csv.writer(f)
                        writer.writerow(['IP', 'Hostname', 'MAC', 'Vendor', 'OS', 'Status'])
                        for ip, info in self.discovered_hosts.items():
                            writer.writerow([
                                ip, info.get('hostname', ''), info.get('mac', ''),
                                info.get('vendor', ''), info.get('os', ''), info.get('status', '')
                            ])
                            
                self.log_message(f"Results exported to {filename}")
                messagebox.showinfo("Success", f"Results exported to {filename}")
            except Exception as e:
                self.log_message(f"Export failed: {e}", "ERROR")
                messagebox.showerror("Error", f"Export failed: {e}")
                
    def show_network_interfaces(self):
        """Show network interfaces"""
        if not SYSTEM_INFO_AVAILABLE:
            messagebox.showinfo("Info", "Network interface detection requires psutil and netifaces")
            return
            
        interfaces_info = "Network Interfaces:\n\n"
        interfaces = netifaces.interfaces()
        
        for interface in interfaces:
            interfaces_info += f"Interface: {interface}\n"
            addresses = netifaces.ifaddresses(interface)
            
            if netifaces.AF_INET in addresses:
                for addr in addresses[netifaces.AF_INET]:
                    interfaces_info += f"  IPv4: {addr.get('addr', 'N/A')}\n"
                    interfaces_info += f"  Netmask: {addr.get('netmask', 'N/A')}\n"
                    
            if netifaces.AF_LINK in addresses:
                for addr in addresses[netifaces.AF_LINK]:
                    interfaces_info += f"  MAC: {addr.get('addr', 'N/A')}\n"
                    
            interfaces_info += "\n"
            
        messagebox.showinfo("Network Interfaces", interfaces_info)
        
    def show_system_info(self):
        """Show system information"""
        info = f"System Information:\n\n"
        info += f"Platform: {sys.platform}\n"
        info += f"Python Version: {sys.version}\n"
        
        if SYSTEM_INFO_AVAILABLE:
            info += f"CPU Count: {psutil.cpu_count()}\n"
            info += f"Memory: {psutil.virtual_memory().total // (1024**3)} GB\n"
            
        info += f"\nLibrary Status:\n"
        info += f"Scapy: {'Available' if SCAPY_AVAILABLE else 'Not Available'}\n"
        info += f"python-nmap: {'Available' if NMAP_AVAILABLE else 'Not Available'}\n"
        info += f"System Info: {'Available' if SYSTEM_INFO_AVAILABLE else 'Not Available'}\n"
        
        messagebox.showinfo("System Information", info)
        
    def show_about(self):
        """Show about dialog"""
        about_text = """NetScope Pro - Professional Network Scanner

A comprehensive network security assessment tool for network administration and security testing.

Features:
• Host Discovery (Ping, ARP, TCP)
• Port Scanning (TCP Connect, SYN)
• Service Detection and Banner Grabbing
• Operating System Detection
• Basic Vulnerability Assessment
• Comprehensive Reporting

Requirements:
• Python 3.6+
• scapy (for advanced features)
• python-nmap (optional)
• psutil, netifaces (for system info)

Version: 1.0
"""
        messagebox.showinfo("About NetScope Pro", about_text)
        
    def run(self):
        """Start the application"""
        self.root.mainloop()


if __name__ == "__main__":
    print("NetScope Pro - Professional Network Scanner")
    print("==========================================")
    
    # Check for required libraries
    missing_libs = []
    if not SCAPY_AVAILABLE:
        missing_libs.append("scapy")
    if not NMAP_AVAILABLE:
        missing_libs.append("python-nmap")
    if not SYSTEM_INFO_AVAILABLE:
        missing_libs.append("psutil netifaces")
        
    if missing_libs:
        print("Note: Some optional libraries are missing.")
        print("For full functionality, install:")
        print(f"pip install {' '.join(missing_libs)}")
        print()
        
    # Check if running as administrator/root for some features
    if os.name != 'nt' and os.geteuid() != 0:
        print("Note: Some advanced features require root privileges")
        print("Run with: sudo python3 network_scanner.py")
        print()
        
    # Start the application
    app = NetworkScanner()
    app.run()