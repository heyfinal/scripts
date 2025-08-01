#!/usr/bin/env python3
"""
Advanced Netstat Security Scanner with Active Response Capabilities
Monitors network connections and can automatically respond to threats

Features:
- Comprehensive connection intelligence gathering
- Active response: terminate, suspend, or block suspicious connections
- Firewall integration for IP/port blocking
- Startup service integration
- Whitelist/blacklist management
- Automated response rules
- Audit logging and recovery mechanisms

Author: Advanced Security Response Tool
Usage: python netstat.py [options]
WARNING: This tool can disrupt network services. Use with extreme caution.
"""

import re
import sys
import json
import argparse
import subprocess
import time
import socket
import ipaddress
import ssl
import requests
import dns.resolver
import dns.reversename
import whois
import geoip2.database
import geoip2.errors
import signal
import os
import platform
import logging
from datetime import datetime, timedelta
from collections import defaultdict, Counter
from pathlib import Path
import csv
import base64
import hashlib
import psutil
import threading
from urllib.parse import urlparse
import urllib3
from concurrent.futures import ThreadPoolExecutor, as_completed
import sqlite3
import shutil

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class SecurityResponseManager:
    """Manages security responses: terminate, suspend, block"""
    
    def __init__(self, config):
        self.config = config
        self.blocked_ips = set()
        self.blocked_ports = set()
        self.suspended_processes = set()
        self.audit_log = []
        
        # Initialize logging
        self.setup_logging()
        
        # Initialize database for persistent storage
        self.init_database()
        
        # Load existing blocks and suspensions
        self.load_persistent_state()
        
    def setup_logging(self):
        """Setup audit logging"""
        log_dir = Path("/var/log/netstat_security") if os.name == 'posix' else Path("./logs")
        log_dir.mkdir(exist_ok=True)
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_dir / "security_responses.log"),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def init_database(self):
        """Initialize SQLite database for persistent storage"""
        db_path = Path("/var/lib/netstat_security/responses.db") if os.name == 'posix' else Path("./responses.db")
        db_path.parent.mkdir(exist_ok=True)
        
        self.db_conn = sqlite3.connect(str(db_path), check_same_thread=False)
        self.db_conn.execute('''
            CREATE TABLE IF NOT EXISTS blocked_ips (
                ip TEXT PRIMARY KEY,
                reason TEXT,
                timestamp TEXT,
                auto_unblock_time TEXT
            )
        ''')
        
        self.db_conn.execute('''
            CREATE TABLE IF NOT EXISTS suspended_processes (
                pid INTEGER PRIMARY KEY,
                name TEXT,
                reason TEXT,
                timestamp TEXT
            )
        ''')
        
        self.db_conn.execute('''
            CREATE TABLE IF NOT EXISTS response_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                action TEXT,
                target TEXT,
                reason TEXT,
                timestamp TEXT,
                success BOOLEAN
            )
        ''')
        
        self.db_conn.commit()
    
    def load_persistent_state(self):
        """Load previously blocked IPs and suspended processes"""
        try:
            # Load blocked IPs
            cursor = self.db_conn.execute("SELECT ip FROM blocked_ips")
            self.blocked_ips.update(row[0] for row in cursor.fetchall())
            
            # Load suspended processes (check if still exist)
            cursor = self.db_conn.execute("SELECT pid FROM suspended_processes")
            for row in cursor.fetchall():
                pid = row[0]
                if psutil.pid_exists(pid):
                    self.suspended_processes.add(pid)
                else:
                    # Clean up dead processes
                    self.db_conn.execute("DELETE FROM suspended_processes WHERE pid = ?", (pid,))
            
            self.db_conn.commit()
            
        except Exception as e:
            self.logger.error(f"Error loading persistent state: {e}")
    
    def is_whitelisted_process(self, process_name, pid):
        """Check if process is whitelisted and should not be terminated"""
        if not process_name:
            return False
        
        # Critical system processes that should never be terminated
        critical_processes = {
            'systemd', 'kernel', 'kthreadd', 'migration', 'rcu_', 'watchdog',
            'sshd', 'init', 'dbus', 'networkmanager', 'systemd-', 'cron',
            'rsyslog', 'ntpd', 'chronyd', 'apache2', 'nginx', 'mysql',
            'postgresql', 'redis-server', 'mongodb', 'docker', 'kubelet'
        }
        
        # Check against critical processes
        process_name_lower = process_name.lower()
        for critical in critical_processes:
            if critical in process_name_lower:
                return True
        
        # Check user-defined whitelist
        whitelist = self.config.get('response', {}).get('process_whitelist', [])
        if process_name in whitelist:
            return True
        
        # Check if it's PID 1 or other low PIDs (system processes)
        if pid and pid <= 10:
            return True
        
        return False
    
    def is_whitelisted_ip(self, ip):
        """Check if IP is whitelisted"""
        if not ip:
            return False
        
        try:
            ip_obj = ipaddress.ip_address(ip)
            
            # Never block localhost or private networks by default
            if ip_obj.is_loopback or ip_obj.is_private:
                return True
            
            # Check user-defined whitelist
            whitelist = self.config.get('response', {}).get('ip_whitelist', [])
            for whitelisted_range in whitelist:
                try:
                    if ip_obj in ipaddress.ip_network(whitelisted_range):
                        return True
                except ValueError:
                    if ip == whitelisted_range:
                        return True
            
        except ValueError:
            pass
        
        return False
    
    def terminate_process(self, pid, reason="Suspicious activity detected"):
        """Terminate a process"""
        if not pid:
            return False, "No PID provided"
        
        try:
            proc = psutil.Process(pid)
            process_name = proc.name()
            
            # Check whitelist
            if self.is_whitelisted_process(process_name, pid):
                message = f"Process {process_name} (PID: {pid}) is whitelisted - termination blocked"
                self.logger.warning(message)
                return False, message
            
            # Log the action
            self.logger.warning(f"TERMINATING process {process_name} (PID: {pid}) - Reason: {reason}")
            
            # Try graceful termination first
            proc.terminate()
            
            # Wait for graceful termination
            try:
                proc.wait(timeout=5)
            except psutil.TimeoutExpired:
                # Force kill if graceful termination fails
                self.logger.warning(f"Force killing process {process_name} (PID: {pid})")
                proc.kill()
                proc.wait(timeout=3)
            
            # Log successful termination
            self.log_response("terminate_process", f"PID:{pid}:{process_name}", reason, True)
            
            return True, f"Successfully terminated process {process_name} (PID: {pid})"
            
        except psutil.NoSuchProcess:
            return False, f"Process {pid} not found"
        except psutil.AccessDenied:
            return False, f"Access denied - insufficient privileges to terminate PID {pid}"
        except Exception as e:
            self.log_response("terminate_process", f"PID:{pid}", reason, False)
            return False, f"Error terminating process {pid}: {e}"
    
    def suspend_process(self, pid, reason="Suspicious activity detected"):
        """Suspend a process"""
        if not pid:
            return False, "No PID provided"
        
        try:
            proc = psutil.Process(pid)
            process_name = proc.name()
            
            # Check whitelist
            if self.is_whitelisted_process(process_name, pid):
                message = f"Process {process_name} (PID: {pid}) is whitelisted - suspension blocked"
                self.logger.warning(message)
                return False, message
            
            # Check if already suspended
            if pid in self.suspended_processes:
                return False, f"Process {pid} is already suspended"
            
            # Suspend the process
            proc.suspend()
            self.suspended_processes.add(pid)
            
            # Store in database
            self.db_conn.execute(
                "INSERT OR REPLACE INTO suspended_processes (pid, name, reason, timestamp) VALUES (?, ?, ?, ?)",
                (pid, process_name, reason, datetime.now().isoformat())
            )
            self.db_conn.commit()
            
            # Log the action
            self.logger.warning(f"SUSPENDED process {process_name} (PID: {pid}) - Reason: {reason}")
            self.log_response("suspend_process", f"PID:{pid}:{process_name}", reason, True)
            
            return True, f"Successfully suspended process {process_name} (PID: {pid})"
            
        except psutil.NoSuchProcess:
            return False, f"Process {pid} not found"
        except psutil.AccessDenied:
            return False, f"Access denied - insufficient privileges to suspend PID {pid}"
        except Exception as e:
            self.log_response("suspend_process", f"PID:{pid}", reason, False)
            return False, f"Error suspending process {pid}: {e}"
    
    def resume_process(self, pid):
        """Resume a suspended process"""
        try:
            if pid not in self.suspended_processes:
                return False, f"Process {pid} is not suspended"
            
            proc = psutil.Process(pid)
            proc.resume()
            
            self.suspended_processes.remove(pid)
            self.db_conn.execute("DELETE FROM suspended_processes WHERE pid = ?", (pid,))
            self.db_conn.commit()
            
            self.logger.info(f"RESUMED process {proc.name()} (PID: {pid})")
            self.log_response("resume_process", f"PID:{pid}:{proc.name()}", "Manual resume", True)
            
            return True, f"Successfully resumed process {pid}"
            
        except psutil.NoSuchProcess:
            return False, f"Process {pid} not found"
        except Exception as e:
            return False, f"Error resuming process {pid}: {e}"
    
    def block_ip(self, ip, reason="Suspicious activity detected", duration_hours=24):
        """Block an IP address using firewall rules"""
        if not ip or self.is_whitelisted_ip(ip):
            return False, f"IP {ip} is whitelisted or invalid"
        
        if ip in self.blocked_ips:
            return False, f"IP {ip} is already blocked"
        
        try:
            # Determine the appropriate firewall command based on OS
            success = False
            command = None
            
            system = platform.system().lower()
            
            if system == "linux":
                # Use iptables on Linux
                command = f"iptables -A INPUT -s {ip} -j DROP"
                result = subprocess.run(command.split(), capture_output=True, text=True)
                success = result.returncode == 0
                
                if success:
                    # Also block outbound connections
                    outbound_cmd = f"iptables -A OUTPUT -d {ip} -j DROP"
                    subprocess.run(outbound_cmd.split(), capture_output=True)
                
            elif system == "darwin":  # macOS
                # Use pfctl on macOS
                # First, create a pfctl rule file
                rule_file = f"/tmp/block_{ip.replace('.', '_')}.conf"
                with open(rule_file, 'w') as f:
                    f.write(f"block in from {ip} to any\n")
                    f.write(f"block out from any to {ip}\n")
                
                command = f"pfctl -f {rule_file}"
                result = subprocess.run(command.split(), capture_output=True, text=True)
                success = result.returncode == 0
                
            elif system == "windows":
                # Use Windows Firewall
                rule_name = f"NetstatSecurity_Block_{ip.replace('.', '_')}"
                command = f'netsh advfirewall firewall add rule name="{rule_name}" dir=in action=block remoteip={ip}'
                result = subprocess.run(command, shell=True, capture_output=True, text=True)
                success = result.returncode == 0
                
                if success:
                    # Also block outbound
                    outbound_cmd = f'netsh advfirewall firewall add rule name="{rule_name}_OUT" dir=out action=block remoteip={ip}'
                    subprocess.run(outbound_cmd, shell=True, capture_output=True)
            
            if success:
                self.blocked_ips.add(ip)
                
                # Calculate auto-unblock time
                auto_unblock_time = datetime.now() + timedelta(hours=duration_hours)
                
                # Store in database
                self.db_conn.execute(
                    "INSERT OR REPLACE INTO blocked_ips (ip, reason, timestamp, auto_unblock_time) VALUES (?, ?, ?, ?)",
                    (ip, reason, datetime.now().isoformat(), auto_unblock_time.isoformat())
                )
                self.db_conn.commit()
                
                self.logger.warning(f"BLOCKED IP {ip} - Reason: {reason} (Auto-unblock: {auto_unblock_time})")
                self.log_response("block_ip", ip, reason, True)
                
                return True, f"Successfully blocked IP {ip} (expires: {auto_unblock_time})"
            else:
                error_msg = f"Failed to execute firewall command: {command}"
                if result:
                    error_msg += f" - {result.stderr}"
                self.log_response("block_ip", ip, reason, False)
                return False, error_msg
                
        except Exception as e:
            self.log_response("block_ip", ip, reason, False)
            return False, f"Error blocking IP {ip}: {e}"
    
    def unblock_ip(self, ip):
        """Unblock an IP address"""
        if ip not in self.blocked_ips:
            return False, f"IP {ip} is not currently blocked"
        
        try:
            system = platform.system().lower()
            success = False
            
            if system == "linux":
                # Remove iptables rules
                commands = [
                    f"iptables -D INPUT -s {ip} -j DROP",
                    f"iptables -D OUTPUT -d {ip} -j DROP"
                ]
                for cmd in commands:
                    subprocess.run(cmd.split(), capture_output=True)
                success = True
                
            elif system == "darwin":  # macOS
                # Remove pfctl rules (reload without the blocked IP)
                rule_file = f"/tmp/block_{ip.replace('.', '_')}.conf"
                if os.path.exists(rule_file):
                    os.remove(rule_file)
                # Reload pfctl (this is simplified - in practice you'd need to manage the full ruleset)
                success = True
                
            elif system == "windows":
                # Remove Windows Firewall rules
                rule_name = f"NetstatSecurity_Block_{ip.replace('.', '_')}"
                commands = [
                    f'netsh advfirewall firewall delete rule name="{rule_name}"',
                    f'netsh advfirewall firewall delete rule name="{rule_name}_OUT"'
                ]
                for cmd in commands:
                    subprocess.run(cmd, shell=True, capture_output=True)
                success = True
            
            if success:
                self.blocked_ips.remove(ip)
                self.db_conn.execute("DELETE FROM blocked_ips WHERE ip = ?", (ip,))
                self.db_conn.commit()
                
                self.logger.info(f"UNBLOCKED IP {ip}")
                self.log_response("unblock_ip", ip, "Manual unblock", True)
                
                return True, f"Successfully unblocked IP {ip}"
            else:
                return False, f"Failed to unblock IP {ip}"
                
        except Exception as e:
            return False, f"Error unblocking IP {ip}: {e}"
    
    def auto_unblock_expired(self):
        """Automatically unblock IPs that have expired"""
        try:
            now = datetime.now()
            cursor = self.db_conn.execute(
                "SELECT ip, auto_unblock_time FROM blocked_ips WHERE auto_unblock_time IS NOT NULL"
            )
            
            for ip, auto_unblock_time_str in cursor.fetchall():
                try:
                    auto_unblock_time = datetime.fromisoformat(auto_unblock_time_str)
                    if now >= auto_unblock_time:
                        success, message = self.unblock_ip(ip)
                        if success:
                            self.logger.info(f"Auto-unblocked expired IP: {ip}")
                except Exception as e:
                    self.logger.error(f"Error processing auto-unblock for {ip}: {e}")
                    
        except Exception as e:
            self.logger.error(f"Error in auto-unblock process: {e}")
    
    def log_response(self, action, target, reason, success):
        """Log response action to database and audit log"""
        try:
            self.db_conn.execute(
                "INSERT INTO response_log (action, target, reason, timestamp, success) VALUES (?, ?, ?, ?, ?)",
                (action, target, reason, datetime.now().isoformat(), success)
            )
            self.db_conn.commit()
            
            # Also add to in-memory audit log
            self.audit_log.append({
                'action': action,
                'target': target,
                'reason': reason,
                'timestamp': datetime.now(),
                'success': success
            })
            
            # Keep only last 1000 entries in memory
            if len(self.audit_log) > 1000:
                self.audit_log = self.audit_log[-1000:]
                
        except Exception as e:
            self.logger.error(f"Error logging response: {e}")
    
    def get_status(self):
        """Get current status of blocks and suspensions"""
        return {
            'blocked_ips': list(self.blocked_ips),
            'suspended_processes': list(self.suspended_processes),
            'recent_actions': self.audit_log[-20:] if self.audit_log else []
        }

def print_banner():
    """Print Matrix-style banner"""
    banner = """
╔╗╔┌─┐┌┬┐┌─┐┌┬┐┌─┐┌┬┐  ┌─┐┌─┐┌─┐┬ ┬┬─┐┬┌┬┐┬ ┬
║║║├┤  │ └─┐ │ ├─┤ │   └─┐├┤ │  │ │├┬┘│ │ └┬┘
╝╚╝└─┘ ┴ └─┘ ┴ ┴ ┴ ┴   └─┘└─┘└─┘└─┘┴└─┴ ┴  ┴ 
                                                
    ▄▀█ █▀▄ █░█ ▄▀█ █▄░█ █▀▀ █▀▀ █▀▄           
    █▀█ █▄▀ ▀▄▀ █▀█ █░▀█ █▄▄ ██▄ █▄▀           
                                                
        ████████╗██╗  ██╗██████╗ ███████╗ █████╗ ████████╗
        ╚══██╔══╝██║  ██║██╔══██╗██╔════╝██╔══██╗╚══██╔══╝
           ██║   ███████║██████╔╝█████╗  ███████║   ██║   
           ██║   ██╔══██║██╔══██╗██╔══╝  ██╔══██║   ██║   
           ██║   ██║  ██║██║  ██║███████╗██║  ██║   ██║   
           ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   
                                                          
        ┌─┐┌─┐┌─┐┌┐┌┌┐┌┌─┐┬─┐  ┬  ┬┌─┐ ┌─┐ ┌─┐            
        └─┐│  ├─┤││││││├┤ ├┬┘  └┐┌┘ │  │ ┌┴ │ │            
        └─┘└─┘┴ ┴┘└┘┘└┘└─┘┴└─   └┘ └─┘ └─┘└─┘ └─┘            
"""
    print(banner)

class AdvancedNetstatScanner:
    def __init__(self, config_file=None):
        """Initialize the advanced scanner with response capabilities"""
        
        # Default configuration
        self.config = {
            # Suspicious ports
            "suspicious_ports": {
                1337, 31337, 12345, 54321, 9999, 6667, 6697,
                4444, 5555, 7777, 8888, 9090, 1234, 2222, 3333, 6666, 8080,
                1080, 1081, 5900, 5901, 3389, 23, 2323, 2332,
                4899, 5000, 5001, 8291, 50050, 50051,
            },
            
            # Legitimate ports
            "legitimate_ports": {
                22, 25, 53, 80, 110, 143, 443, 465, 587, 993, 995,
                21, 990, 123, 161, 162, 636, 3306, 5432, 1433,
                6379, 27017, 9200, 9300, 9092, 2181, 5672, 15672
            },
            
            # Response configuration
            "response": {
                "enabled": False,
                "auto_response": False,
                "require_confirmation": True,
                "ip_whitelist": [
                    "127.0.0.0/8",
                    "192.168.0.0/16", 
                    "10.0.0.0/8",
                    "172.16.0.0/12"
                ],
                "process_whitelist": [
                    "sshd", "systemd", "kernel", "init", "cron",
                    "apache2", "nginx", "mysql", "postgresql"
                ],
                "auto_block_threshold": 80,  # Risk score threshold for auto-block
                "auto_terminate_threshold": 90,  # Risk score threshold for auto-terminate
                "default_block_duration_hours": 24,
                "max_auto_blocks_per_hour": 10
            },
            
            # Analysis settings
            "analysis": {
                "enable_geolocation": True,
                "enable_whois": True,
                "enable_dns_lookup": True,
                "enable_banner_grab": True,
                "enable_ssl_analysis": True,
                "enable_threat_intel": True,
                "enable_process_analysis": True,
                "max_banner_length": 1024,
                "connection_timeout": 5,
                "max_concurrent_lookups": 10,
                "cache_duration_hours": 24
            },
            
            # Threat intelligence APIs
            "threat_intel_apis": {
                "virustotal": {
                    "enabled": False,
                    "api_key": "",
                    "url": "https://www.virustotal.com/vtapi/v2/ip-address/report"
                },
                "abuseipdb": {
                    "enabled": False,
                    "api_key": "",
                    "url": "https://api.abuseipdb.com/api/v2/check"
                },
                "threatcrowd": {
                    "enabled": True,
                    "url": "https://www.threatcrowd.org/searchApi/v2/ip/report/"
                }
            },
            
            # Risk scoring weights
            "risk_weights": {
                "suspicious_port": 30,
                "suspicious_country": 25,
                "threat_intel_hit": 40,
                "suspicious_process": 35,
                "ssl_issues": 20,
                "reverse_dns_mismatch": 15,
                "new_domain": 10,
                "tor_exit_node": 45
            }
        }
        
        # Load custom config
        if config_file and Path(config_file).exists():
            self.load_config(config_file)
        
        # Initialize response manager
        self.response_manager = SecurityResponseManager(self.config)
        
        # Initialize tracking
        self.connection_history = defaultdict(list)
        self.alerts = []
        self.auto_block_count = 0
        self.last_auto_block_reset = datetime.now()
    
    def load_config(self, config_file):
        """Load configuration from JSON file"""
        try:
            with open(config_file, 'r') as f:
                custom_config = json.load(f)
                # Deep merge the configuration
                self.deep_merge_config(self.config, custom_config)
        except Exception as e:
            print(f"Warning: Could not load config file {config_file}: {e}")
    
    def deep_merge_config(self, base, update):
        """Deep merge configuration dictionaries"""
        for key, value in update.items():
            if key in base and isinstance(base[key], dict) and isinstance(value, dict):
                self.deep_merge_config(base[key], value)
            else:
                base[key] = value
    
    def save_config(self, config_file):
        """Save current configuration to JSON file"""
        try:
            with open(config_file, 'w') as f:
                json.dump(self.config, f, indent=2, default=str)
            print(f"Configuration saved to {config_file}")
        except Exception as e:
            print(f"Error saving config: {e}")
    
    def check_auto_block_limits(self):
        """Check if auto-block limits have been exceeded"""
        now = datetime.now()
        
        # Reset counter if an hour has passed
        if now - self.last_auto_block_reset > timedelta(hours=1):
            self.auto_block_count = 0
            self.last_auto_block_reset = now
        
        max_blocks = self.config['response']['max_auto_blocks_per_hour']
        return self.auto_block_count < max_blocks
    
    def handle_suspicious_connection(self, connection, alerts):
        """Handle suspicious connection with configurable responses"""
        if not self.config['response']['enabled']:
            return
        
        risk_score = connection.get('risk_score', 0)
        foreign_ip = connection.get('foreign_ip')
        pid = connection.get('pid')
        
        # Auto-response logic
        if self.config['response']['auto_response'] and self.check_auto_block_limits():
            
            # Auto-terminate for very high risk
            if (risk_score >= self.config['response']['auto_terminate_threshold'] and 
                pid and not self.response_manager.is_whitelisted_process(connection.get('program'), pid)):
                
                success, message = self.response_manager.terminate_process(
                    pid, f"Auto-terminate: Risk score {risk_score}"
                )
                if success:
                    print(f"🔥 AUTO-TERMINATED: {message}")
                else:
                    print(f"❌ Failed to auto-terminate: {message}")
            
            # Auto-block for high risk IPs
            elif (risk_score >= self.config['response']['auto_block_threshold'] and 
                  foreign_ip and not self.response_manager.is_whitelisted_ip(foreign_ip)):
                
                success, message = self.response_manager.block_ip(
                    foreign_ip, 
                    f"Auto-block: Risk score {risk_score}",
                    self.config['response']['default_block_duration_hours']
                )
                if success:
                    self.auto_block_count += 1
                    print(f"🚫 AUTO-BLOCKED: {message}")
                else:
                    print(f"❌ Failed to auto-block: {message}")
        
        # Interactive response for manual confirmation
        elif self.config['response']['require_confirmation'] and risk_score > 50:
            self.prompt_manual_response(connection, alerts)
    
    def prompt_manual_response(self, connection, alerts):
        """Prompt user for manual response to suspicious connection"""
        print(f"\n🚨 SUSPICIOUS CONNECTION DETECTED!")
        print(f"Risk Score: {connection.get('risk_score', 0)}")
        print(f"Connection: {connection['foreign_ip']}:{connection['foreign_port']}")
        print(f"Process: {connection.get('program', 'Unknown')} (PID: {connection.get('pid', 'Unknown')})")
        
        # Show alerts
        if alerts:
            print(f"Alerts:")
            for alert in alerts[:3]:  # Show top 3 alerts
                print(f"  - {alert['message']}")
        
        print(f"\nAvailable actions:")
        print(f"1. Block IP ({connection['foreign_ip']})")
        print(f"2. Suspend Process (PID: {connection.get('pid', 'N/A')})")
        print(f"3. Terminate Process (PID: {connection.get('pid', 'N/A')})")
        print(f"4. Ignore")
        print(f"5. Show detailed intelligence")
        
        try:
            choice = input("Choose action (1-5): ").strip()
            
            if choice == '1' and connection['foreign_ip']:
                success, message = self.response_manager.block_ip(
                    connection['foreign_ip'], 
                    f"Manual block: Risk score {connection.get('risk_score', 0)}"
                )
                print(f"{'✅' if success else '❌'} {message}")
                
            elif choice == '2' and connection.get('pid'):
                success, message = self.response_manager.suspend_process(
                    connection['pid'], 
                    f"Manual suspend: Risk score {connection.get('risk_score', 0)}"
                )
                print(f"{'✅' if success else '❌'} {message}")
                
            elif choice == '3' and connection.get('pid'):
                confirm = input(f"⚠️  Really terminate process {connection.get('program')} (PID: {connection['pid']})? [y/N]: ")
                if confirm.lower() == 'y':
                    success, message = self.response_manager.terminate_process(
                        connection['pid'], 
                        f"Manual terminate: Risk score {connection.get('risk_score', 0)}"
                    )
                    print(f"{'✅' if success else '❌'} {message}")
                else:
                    print("Termination cancelled")
                    
            elif choice == '4':
                print("Ignoring connection")
                
            elif choice == '5':
                self.show_detailed_intelligence(connection)
                
        except KeyboardInterrupt:
            print("\nAction cancelled")
    
    def show_detailed_intelligence(self, connection):
        """Show detailed intelligence about a connection"""
        print(f"\n" + "="*60)
        print(f"DETAILED INTELLIGENCE: {connection['foreign_ip']}")
        print(f"="*60)
        
        intel = connection.get('foreign_intel', {})
        
        # Geolocation
        geo = intel.get('geolocation', {})
        if geo:
            print(f"🌍 Location: {geo.get('city', 'Unknown')}, {geo.get('country', 'Unknown')} ({geo.get('country_code', 'XX')})")
            print(f"🏢 ASN: {geo.get('asn', 'Unknown')} - {geo.get('asn_org', 'Unknown')}")
        
        # Risk factors
        risk_factors = intel.get('risk_factors', [])
        if risk_factors:
            print(f"⚠️  Risk Factors:")
            for factor in risk_factors:
                print(f"   - {factor}")
        
        # Threat intelligence
        threat_intel = intel.get('threat_intel', {})
        if threat_intel:
            print(f"🚨 Threat Intelligence:")
            for source, data in threat_intel.items():
                print(f"   {source}: {data}")
        
        # SSL info
        ssl_info = intel.get('ssl_info', {})
        if ssl_info:
            print(f"🔒 SSL Certificate:")
            print(f"   Subject: {ssl_info.get('subject', {})}")
            print(f"   Self-signed: {ssl_info.get('is_self_signed', False)}")
            print(f"   Expired: {ssl_info.get('is_expired', False)}")
        
        print(f"="*60)
    
    def get_netstat_output(self):
        """Get current netstat output"""
        try:
            commands = [
                ['netstat', '-tulpn'],  # Linux
                ['netstat', '-an'],     # Basic fallback
                ['ss', '-tulpn'],       # Modern Linux alternative
            ]
            
            for cmd in commands:
                try:
                    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
                    if result.returncode == 0:
                        return result.stdout
                except (subprocess.TimeoutExpired, FileNotFoundError):
                    continue
            
            raise Exception("No working netstat command found")
            
        except Exception as e:
            raise Exception(f"Failed to get netstat output: {e}")
    
    def parse_netstat_line(self, line):
        """Parse a single netstat output line with enhanced analysis"""
        parts = line.strip().split()
        
        if len(parts) < 4:
            return None
        
        try:
            protocol = parts[0]
            local_address = parts[3] if len(parts) > 3 else ""
            foreign_address = parts[4] if len(parts) > 4 else ""
            state = parts[5] if len(parts) > 5 else ""
            
            pid_program = parts[6] if len(parts) > 6 else ""
            pid, program = self.extract_pid_program(pid_program)
            
            local_ip, local_port = self.parse_address(local_address)
            foreign_ip, foreign_port = self.parse_address(foreign_address)
            
            # Enhanced connection object
            connection = {
                'timestamp': datetime.now(),
                'protocol': protocol,
                'local_ip': local_ip,
                'local_port': local_port,
                'foreign_ip': foreign_ip,
                'foreign_port': foreign_port,
                'state': state,
                'pid': pid,
                'program': program,
                'raw_line': line.strip(),
                'process_details': {},
                'foreign_intel': {},
                'local_intel': {},
                'risk_score': 0,
                'alerts': []
            }
            
            return connection
            
        except Exception as e:
            return None
    
    def extract_pid_program(self, pid_program_str):
        """Extract PID and program name from netstat output"""
        if not pid_program_str or pid_program_str == '-':
            return None, None
        
        if '/' in pid_program_str:
            parts = pid_program_str.split('/', 1)
            try:
                pid = int(parts[0])
                program = parts[1] if len(parts) > 1 else None
                return pid, program
            except ValueError:
                return None, pid_program_str
        
        try:
            pid = int(pid_program_str)
            return pid, None
        except ValueError:
            return None, pid_program_str
    
    def parse_address(self, address):
        """Parse IP address and port from netstat address format"""
        if not address or address == '*':
            return None, None
        
        # Handle IPv6 addresses
        if address.startswith('['):
            match = re.match(r'\[([^\]]+)\]:(\d+)', address)
            if match:
                return match.group(1), int(match.group(2))
        
        # Handle IPv4 addresses
        if ':' in address:
            parts = address.rsplit(':', 1)
            if len(parts) == 2:
                try:
                    ip = parts[0] if parts[0] != '0.0.0.0' else None
                    port = int(parts[1])
                    return ip, port
                except ValueError:
                    pass
        
        return address, None
    
    def analyze_netstat_comprehensive(self, netstat_output):
        """Comprehensive analysis of netstat output"""
        connections = []
        all_alerts = []
        
        print("🚀 Starting comprehensive netstat analysis...")
        
        lines = netstat_output.strip().split('\n')
        connection_lines = []
        
        # Parse all connections first
        for line in lines:
            if any(header in line.lower() for header in ['proto', 'active', 'local address', 'netid']):
                continue
            
            conn = self.parse_netstat_line(line)
            if conn:
                connection_lines.append(conn)
        
        print(f"📊 Found {len(connection_lines)} connections to analyze")
        
        # Analyze connections (simplified version for now)
        for i, conn in enumerate(connection_lines, 1):
            try:
                # Basic risk assessment
                risk_score = self.calculate_basic_risk_score(conn)
                conn['risk_score'] = risk_score
                
                # Generate alerts for high-risk connections
                if risk_score > 50:
                    alert = {
                        'type': 'suspicious_connection',
                        'severity': 'high' if risk_score > 80 else 'medium',
                        'message': f"Suspicious connection detected (Risk: {risk_score})",
                        'connection': conn
                    }
                    conn['alerts'] = [alert]
                    all_alerts.append(alert)
                
                connections.append(conn)
                
                if i % 10 == 0:
                    print(f"✅ Analyzed connection {i}/{len(connection_lines)}")
                    
            except Exception as e:
                print(f"❌ Error analyzing connection: {e}")
                connections.append(conn)
        
        return connections, all_alerts
    
    def calculate_basic_risk_score(self, connection):
        """Calculate basic risk score for a connection"""
        score = 0
        
        # Check for suspicious ports
        if connection.get('foreign_port') in self.config['suspicious_ports']:
            score += 30
        
        if connection.get('local_port') in self.config['suspicious_ports']:
            score += 25
        
        # Check for external connections
        foreign_ip = connection.get('foreign_ip')
        if foreign_ip and not self.is_internal_ip(foreign_ip):
            score += 20
        
        # Check for suspicious process names
        program = connection.get('program', '')
        if program and any(pattern in program.lower() for pattern in ['temp', 'tmp', 'unknown']):
            score += 15
        
        return min(score, 100)
    
    def is_internal_ip(self, ip):
        """Check if IP is internal/private"""
        if not ip:
            return True
        
        try:
            ip_obj = ipaddress.ip_address(ip)
            return ip_obj.is_private or ip_obj.is_loopback
        except ValueError:
            return False
    
    def gather_comprehensive_intel(self, ip, port=None):
        """Simplified intelligence gathering (placeholder for full implementation)"""
        # Basic placeholder - in full version this would do geolocation, whois, etc.
        return {
            'ip': ip,
            'port': port,
            'timestamp': datetime.now(),
            'geolocation': {},
            'reputation_score': 0,
            'risk_factors': []
        }
    
    def print_comprehensive_report(self, connections, alerts):
        """Print comprehensive analysis report"""
        print("\n" + "="*100)
        print("🔍 NETSTAT SECURITY ANALYSIS REPORT")
        print("="*100)
        
        print(f"📅 Analysis Timestamp: {datetime.now()}")
        print(f"🔗 Total Connections Analyzed: {len(connections)}")
        print(f"🚨 Total Security Alerts: {len(alerts)}")
        
        if alerts:
            print(f"\n🚨 SECURITY ALERTS BY SEVERITY:")
            severity_counts = Counter(alert['severity'] for alert in alerts)
            for severity in ['high', 'medium', 'low']:
                count = severity_counts[severity]
                if count > 0:
                    color = '\033[91m' if severity == 'high' else '\033[93m' if severity == 'medium' else '\033[92m'
                    print(f"  {color}{severity.upper()}: {count}\033[0m")
            
            print(f"\n🔍 TOP ALERTS:")
            for i, alert in enumerate(alerts[:10], 1):
                conn = alert.get('connection', {})
                print(f"{i}. [{alert['severity'].upper()}] {alert['message']}")
                if conn:
                    print(f"   🔗 {conn.get('foreign_ip', 'Unknown')}:{conn.get('foreign_port', 'Unknown')} "
                          f"({conn.get('program', 'Unknown process')})")
        
        # Connection statistics
        foreign_ips = [conn['foreign_ip'] for conn in connections if conn.get('foreign_ip')]
        if foreign_ips:
            print(f"\nTop Foreign IPs:")
            for ip, count in Counter(foreign_ips).most_common(5):
                print(f"  {ip}: {count} connections")
        
        print("="*100)
    
    def save_comprehensive_report(self, connections, alerts, filename):
        """Save comprehensive report to JSON file"""
        report = {
            'metadata': {
                'timestamp': datetime.now().isoformat(),
                'total_connections': len(connections),
                'total_alerts': len(alerts),
                'analysis_version': '3.0'
            },
            'summary': {
                'alert_breakdown': dict(Counter(alert['type'] for alert in alerts)),
                'severity_breakdown': dict(Counter(alert['severity'] for alert in alerts))
            },
            'alerts': alerts,
            'connections': connections
        }
        
        try:
            with open(filename, 'w') as f:
                json.dump(report, f, indent=2, default=str)
            print(f"📄 Report saved to {filename}")
        except Exception as e:
            print(f"❌ Error saving report: {e}")
    
    def create_startup_service(self):
        """Create startup service/daemon for continuous monitoring"""
        system = platform.system().lower()
        
        if system == "linux":
            self.create_systemd_service()
        elif system == "darwin":
            self.create_launchd_service()
        elif system == "windows":
            self.create_windows_service()
    
    def create_systemd_service(self):
        """Create systemd service for Linux"""
        service_content = f"""[Unit]
Description=Netstat Security Scanner
After=network.target

[Service]
Type=simple
User=root
ExecStart={sys.executable} {os.path.abspath(__file__)} --monitor --auto-response
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
"""
        
        service_path = "/etc/systemd/system/netstat-security.service"
        try:
            with open(service_path, 'w') as f:
                f.write(service_content)
            
            # Enable and start service
            subprocess.run(["systemctl", "daemon-reload"], check=True)
            subprocess.run(["systemctl", "enable", "netstat-security"], check=True)
            
            print(f"✅ Systemd service created at {service_path}")
            print("Start with: sudo systemctl start netstat-security")
            print("Check status: sudo systemctl status netstat-security")
            
        except Exception as e:
            print(f"❌ Error creating systemd service: {e}")
    
    def create_launchd_service(self):
        """Create launchd service for macOS"""
        plist_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.security.netstat-scanner</string>
    <key>ProgramArguments</key>
    <array>
        <string>{sys.executable}</string>
        <string>{os.path.abspath(__file__)}</string>
        <string>--monitor</string>
        <string>--auto-response</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/var/log/netstat-security.err</string>
    <key>StandardOutPath</key>
    <string>/var/log/netstat-security.out</string>
</dict>
</plist>
"""
        
        plist_path = "/Library/LaunchDaemons/com.security.netstat-scanner.plist"
        try:
            with open(plist_path, 'w') as f:
                f.write(plist_content)
            
            # Load the service
            subprocess.run(["launchctl", "load", plist_path], check=True)
            
            print(f"✅ LaunchDaemon created at {plist_path}")
            print("Start with: sudo launchctl start com.security.netstat-scanner")
            
        except Exception as e:
            print(f"❌ Error creating LaunchDaemon: {e}")
    
    def real_time_monitor_with_response(self, interval=30):
        """Real-time monitoring with automated response capabilities"""
        print_banner()
        print(f"🚀 Starting advanced real-time monitoring with response capabilities")
        print(f"⚙️  Auto-response: {'Enabled' if self.config['response']['auto_response'] else 'Disabled'}")
        print(f"🔄 Monitoring interval: {interval}s")
        print("Press Ctrl+C to stop")
        
        try:
            while True:
                try:
                    # Auto-unblock expired IPs
                    self.response_manager.auto_unblock_expired()
                    
                    # Get and analyze current connections
                    netstat_output = self.get_netstat_output()
                    connections, alerts = self.analyze_netstat_comprehensive(netstat_output)
                    
                    # Handle suspicious connections
                    for connection in connections:
                        if connection.get('alerts'):
                            self.handle_suspicious_connection(connection, connection['alerts'])
                    
                    if alerts:
                        print(f"\n[{datetime.now()}] Found {len(alerts)} alerts")
                        # Show summary of high-severity alerts
                        high_alerts = [a for a in alerts if a['severity'] == 'high']
                        if high_alerts:
                            print(f"🚨 {len(high_alerts)} HIGH severity alerts")
                    else:
                        print(f"[{datetime.now()}] No suspicious activity detected")
                    
                    time.sleep(interval)
                    
                except KeyboardInterrupt:
                    print("\n🛑 Monitoring stopped by user")
                    break
                except Exception as e:
                    print(f"❌ Error during monitoring: {e}")
                    time.sleep(interval)
                    
        except Exception as e:
            print(f"💥 Fatal error in monitoring: {e}")
    
    def show_response_status(self):
        """Show current response manager status"""
        status = self.response_manager.get_status()
        
        print(f"\n" + "="*60)
        print(f"🛡️  SECURITY RESPONSE STATUS")
        print(f"="*60)
        
        print(f"🚫 Blocked IPs ({len(status['blocked_ips'])}):")
        for ip in status['blocked_ips'][:10]:  # Show first 10
            print(f"   - {ip}")
        if len(status['blocked_ips']) > 10:
            print(f"   ... and {len(status['blocked_ips']) - 10} more")
        
        print(f"\n⏸️  Suspended Processes ({len(status['suspended_processes'])}):")
        for pid in status['suspended_processes']:
            try:
                proc = psutil.Process(pid)
                print(f"   - PID {pid}: {proc.name()}")
            except:
                print(f"   - PID {pid}: (process no longer exists)")
        
        print(f"\n📊 Recent Actions ({len(status['recent_actions'])}):")
        for action in status['recent_actions'][-5:]:  # Show last 5
            timestamp = action['timestamp'].strftime("%H:%M:%S") if isinstance(action['timestamp'], datetime) else action['timestamp']
            status_icon = "✅" if action['success'] else "❌"
            print(f"   {status_icon} {timestamp} - {action['action']}: {action['target']}")
        
        print(f"="*60)

# [Additional methods would be included here - abbreviated for space]
# Including all the intelligence gathering methods from the previous version

def main():
    parser = argparse.ArgumentParser(description="Advanced Netstat Security Scanner with Response Capabilities")
    parser.add_argument("-f", "--file", help="Analyze netstat log file")
    parser.add_argument("-m", "--monitor", action="store_true", help="Real-time monitoring mode")
    parser.add_argument("-i", "--interval", type=int, default=30, help="Monitoring interval in seconds")
    parser.add_argument("-c", "--config", help="Custom configuration file")
    parser.add_argument("-o", "--output", help="Output comprehensive report file (JSON)")
    parser.add_argument("--save-config", help="Save current config to file")
    parser.add_argument("--auto-response", action="store_true", help="Enable automatic response mode")
    parser.add_argument("--create-service", action="store_true", help="Create startup service/daemon")
    parser.add_argument("--status", action="store_true", help="Show response manager status")
    parser.add_argument("--unblock-ip", help="Unblock a specific IP address")
    parser.add_argument("--resume-pid", type=int, help="Resume a suspended process")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    
    args = parser.parse_args()
    
    # Check for required privileges
    if os.name == 'posix' and os.geteuid() != 0:
        print("⚠️  Warning: Running without root privileges. Some features may not work.")
        print("   For full functionality, run with: sudo python3 advanced_netstat_scanner.py")
    
            print("🚀 Advanced Netstat Security Scanner with Response Capabilities v3.0")
    print("⚠️  WARNING: This tool can terminate processes and block network traffic")
    print("📋 Only use on systems you own or have explicit permission to manage\n")
    
    # Initialize scanner
    scanner = AdvancedNetstatScanner(args.config)
    
    # Enable auto-response if requested
    if args.auto_response:
        scanner.config['response']['enabled'] = True
        scanner.config['response']['auto_response'] = True
        print("🤖 Auto-response mode enabled")
    
    try:
        if args.save_config:
            scanner.save_config(args.save_config)
            return
        
        if args.create_service:
            scanner.create_startup_service()
            return
        
        if args.status:
            scanner.show_response_status()
            return
        
        if args.unblock_ip:
            success, message = scanner.response_manager.unblock_ip(args.unblock_ip)
            print(f"{'✅' if success else '❌'} {message}")
            return
        
        if args.resume_pid:
            success, message = scanner.response_manager.resume_process(args.resume_pid)
            print(f"{'✅' if success else '❌'} {message}")
            return
        
        if args.monitor:
            scanner.real_time_monitor_with_response(args.interval)
        elif args.file:
            print(f"📁 Analyzing netstat log file: {args.file}")
            with open(args.file, 'r') as f:
                netstat_output = f.read()
            connections, alerts = scanner.analyze_netstat_comprehensive(netstat_output)
            scanner.print_comprehensive_report(connections, alerts)
            
            if args.output:
                scanner.save_comprehensive_report(connections, alerts, args.output)
        else:
            print("🔍 Analyzing current network connections...")
            netstat_output = scanner.get_netstat_output()
            connections, alerts = scanner.analyze_netstat_comprehensive(netstat_output)
            scanner.print_comprehensive_report(connections, alerts)
            
            if args.output:
                scanner.save_comprehensive_report(connections, alerts, args.output)
    
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
