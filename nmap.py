#!/usr/bin/env python3
"""
Nmap GUI for macOS
A modern GUI wrapper for nmap using customtkinter
Author: Created for legitimate network administration and security testing
Warning: Only use on networks you own or have explicit permission to scan
"""

import customtkinter as ctk
import tkinter as tk
from tkinter import scrolledtext, messagebox, filedialog
import subprocess
import threading
import json
import os
from datetime import datetime

# Set appearance mode and color theme
ctk.set_appearance_mode("dark")  # Modes: "System" (standard), "Dark", "Light"
ctk.set_default_color_theme("blue")  # Themes: "blue" (standard), "green", "dark-blue"

class NmapGUI:
    def __init__(self):
        self.root = ctk.CTk()
        self.root.title("Nmap GUI - Network Scanner")
        self.root.geometry("1000x800")
        
        # Mac-specific window settings
        self.root.resizable(True, True)
        
        # Variables
        self.target_var = tk.StringVar()
        self.scan_type_var = tk.StringVar(value="Basic Scan")
        self.port_range_var = tk.StringVar(value="1-65535")
        self.timing_var = tk.StringVar(value="T3 (Normal)")
        self.output_format_var = tk.StringVar(value="Normal")
        
        # Scan options
        self.ping_scan_var = tk.BooleanVar()
        self.service_detection_var = tk.BooleanVar()
        self.os_detection_var = tk.BooleanVar()
        self.aggressive_var = tk.BooleanVar()
        self.stealth_var = tk.BooleanVar()
        self.no_ping_var = tk.BooleanVar()
        self.traceroute_var = tk.BooleanVar()
        
        # Scan presets
        self.scan_presets = {
            "Basic Scan": {
                "description": "Simple host discovery and port scan",
                "command": "-sS",
                "ports": "1-1000"
            },
            "Quick Scan": {
                "description": "Fast scan of common ports",
                "command": "-sS -F",
                "ports": ""
            },
            "Comprehensive Scan": {
                "description": "Thorough scan with service detection",
                "command": "-sS -sV -O -A",
                "ports": "1-65535"
            },
            "Stealth Scan": {
                "description": "SYN stealth scan",
                "command": "-sS -T2",
                "ports": "1-1000"
            },
            "UDP Scan": {
                "description": "UDP port scan",
                "command": "-sU",
                "ports": "53,67,68,69,123,135,137,138,139,161,162"
            },
            "Ping Sweep": {
                "description": "Host discovery only",
                "command": "-sn",
                "ports": ""
            },
            "Version Detection": {
                "description": "Service version detection",
                "command": "-sV",
                "ports": "1-1000"
            },
            "OS Detection": {
                "description": "Operating system detection",
                "command": "-O",
                "ports": "1-1000"
            },
            "Vulnerability Scan": {
                "description": "Basic vulnerability scanning",
                "command": "--script vuln",
                "ports": "1-1000"
            }
        }
        
        self.create_widgets()
        self.show_warning()
        
    def show_warning(self):
        """Show ethical usage warning"""
        warning_msg = """
IMPORTANT: Ethical Usage Notice

This tool is for legitimate network administration and security testing only.

• Only scan networks you own or have explicit written permission to scan
• Unauthorized network scanning may violate local laws and regulations
• Be respectful of network resources and avoid disruptive scans
• Consider the impact on network performance

By continuing, you acknowledge these responsibilities.
        """
        messagebox.showwarning("Ethical Usage", warning_msg)
    
    def create_widgets(self):
        """Create and layout GUI widgets"""
        
        # Main container with padding
        main_frame = ctk.CTkFrame(self.root)
        main_frame.pack(fill="both", expand=True, padx=20, pady=20)
        
        # Title
        title_label = ctk.CTkLabel(main_frame, text="Nmap Network Scanner", 
                                 font=ctk.CTkFont(size=24, weight="bold"))
        title_label.pack(pady=(20, 30))
        
        # Create notebook-style tabs
        self.create_target_frame(main_frame)
        self.create_scan_options_frame(main_frame)
        self.create_control_frame(main_frame)
        self.create_output_frame(main_frame)
        
    def create_target_frame(self, parent):
        """Create target input frame"""
        target_frame = ctk.CTkFrame(parent)
        target_frame.pack(fill="x", padx=10, pady=(0, 10))
        
        # Target input
        target_label = ctk.CTkLabel(target_frame, text="Target (IP/hostname/range):", 
                                  font=ctk.CTkFont(size=14, weight="bold"))
        target_label.pack(anchor="w", padx=20, pady=(20, 5))
        
        target_entry = ctk.CTkEntry(target_frame, textvariable=self.target_var,
                                  placeholder_text="e.g., 192.168.1.1, scanme.nmap.org, 10.0.0.0/24",
                                  width=400, height=35)
        target_entry.pack(padx=20, pady=(0, 20))
        
    def create_scan_options_frame(self, parent):
        """Create scan options frame"""
        options_frame = ctk.CTkFrame(parent)
        options_frame.pack(fill="both", expand=True, padx=10, pady=(0, 10))
        
        # Create two columns
        left_column = ctk.CTkFrame(options_frame, fg_color="transparent")
        left_column.pack(side="left", fill="both", expand=True, padx=(20, 10), pady=20)
        
        right_column = ctk.CTkFrame(options_frame, fg_color="transparent")
        right_column.pack(side="right", fill="both", expand=True, padx=(10, 20), pady=20)
        
        # Left column - Presets and basic options
        preset_label = ctk.CTkLabel(left_column, text="Scan Presets:", 
                                  font=ctk.CTkFont(size=14, weight="bold"))
        preset_label.pack(anchor="w", pady=(0, 10))
        
        preset_dropdown = ctk.CTkOptionMenu(left_column, variable=self.scan_type_var,
                                          values=list(self.scan_presets.keys()),
                                          command=self.on_preset_change,
                                          width=250, height=35)
        preset_dropdown.pack(anchor="w", pady=(0, 15))
        
        # Preset description
        self.preset_desc_label = ctk.CTkLabel(left_column, text="", 
                                            font=ctk.CTkFont(size=12),
                                            wraplength=250)
        self.preset_desc_label.pack(anchor="w", pady=(0, 20))
        
        # Port range
        port_label = ctk.CTkLabel(left_column, text="Port Range:", 
                                font=ctk.CTkFont(size=14, weight="bold"))
        port_label.pack(anchor="w", pady=(0, 5))
        
        port_entry = ctk.CTkEntry(left_column, textvariable=self.port_range_var,
                                placeholder_text="e.g., 1-1000, 80,443,8080",
                                width=250, height=35)
        port_entry.pack(anchor="w", pady=(0, 15))
        
        # Timing template
        timing_label = ctk.CTkLabel(left_column, text="Timing Template:", 
                                  font=ctk.CTkFont(size=14, weight="bold"))
        timing_label.pack(anchor="w", pady=(0, 5))
        
        timing_options = ["T0 (Paranoid)", "T1 (Sneaky)", "T2 (Polite)", 
                         "T3 (Normal)", "T4 (Aggressive)", "T5 (Insane)"]
        timing_dropdown = ctk.CTkOptionMenu(left_column, variable=self.timing_var,
                                          values=timing_options,
                                          width=250, height=35)
        timing_dropdown.pack(anchor="w", pady=(0, 15))
        
        # Right column - Advanced options
        advanced_label = ctk.CTkLabel(right_column, text="Advanced Options:", 
                                    font=ctk.CTkFont(size=14, weight="bold"))
        advanced_label.pack(anchor="w", pady=(0, 10))
        
        # Checkboxes for additional options
        options_list = [
            (self.service_detection_var, "Service Version Detection (-sV)"),
            (self.os_detection_var, "OS Detection (-O)"),
            (self.aggressive_var, "Aggressive Scan (-A)"),
            (self.stealth_var, "Stealth Scan (-sS)"),
            (self.ping_scan_var, "Ping Scan Only (-sn)"),
            (self.no_ping_var, "Skip Host Discovery (-Pn)"),
            (self.traceroute_var, "Traceroute (--traceroute)")
        ]
        
        for var, text in options_list:
            checkbox = ctk.CTkCheckBox(right_column, text=text, variable=var)
            checkbox.pack(anchor="w", pady=5)
        
        # Output format
        output_label = ctk.CTkLabel(right_column, text="Output Format:", 
                                  font=ctk.CTkFont(size=14, weight="bold"))
        output_label.pack(anchor="w", pady=(20, 5))
        
        output_options = ["Normal", "XML", "Grepable", "All Formats"]
        output_dropdown = ctk.CTkOptionMenu(right_column, variable=self.output_format_var,
                                          values=output_options,
                                          width=250, height=35)
        output_dropdown.pack(anchor="w")
        
        # Update preset description initially
        self.on_preset_change(self.scan_type_var.get())
        
    def create_control_frame(self, parent):
        """Create control buttons frame"""
        control_frame = ctk.CTkFrame(parent)
        control_frame.pack(fill="x", padx=10, pady=(0, 10))
        
        button_frame = ctk.CTkFrame(control_frame, fg_color="transparent")
        button_frame.pack(pady=20)
        
        # Control buttons
        self.scan_button = ctk.CTkButton(button_frame, text="Start Scan", 
                                       command=self.start_scan,
                                       font=ctk.CTkFont(size=14, weight="bold"),
                                       width=120, height=40)
        self.scan_button.pack(side="left", padx=10)
        
        self.stop_button = ctk.CTkButton(button_frame, text="Stop Scan", 
                                       command=self.stop_scan,
                                       font=ctk.CTkFont(size=14, weight="bold"),
                                       width=120, height=40,
                                       state="disabled")
        self.stop_button.pack(side="left", padx=10)
        
        clear_button = ctk.CTkButton(button_frame, text="Clear Output", 
                                   command=self.clear_output,
                                   font=ctk.CTkFont(size=14, weight="bold"),
                                   width=120, height=40)
        clear_button.pack(side="left", padx=10)
        
        save_button = ctk.CTkButton(button_frame, text="Save Results", 
                                  command=self.save_results,
                                  font=ctk.CTkFont(size=14, weight="bold"),
                                  width=120, height=40)
        save_button.pack(side="left", padx=10)
        
        # Command preview
        cmd_label = ctk.CTkLabel(control_frame, text="Command Preview:", 
                               font=ctk.CTkFont(size=12, weight="bold"))
        cmd_label.pack(anchor="w", padx=20, pady=(0, 5))
        
        self.command_text = ctk.CTkTextbox(control_frame, height=60)
        self.command_text.pack(fill="x", padx=20, pady=(0, 20))
        
        # Update command preview when options change
        self.update_command_preview()
        
    def create_output_frame(self, parent):
        """Create output display frame"""
        output_frame = ctk.CTkFrame(parent)
        output_frame.pack(fill="both", expand=True, padx=10)
        
        output_label = ctk.CTkLabel(output_frame, text="Scan Results:", 
                                  font=ctk.CTkFont(size=14, weight="bold"))
        output_label.pack(anchor="w", padx=20, pady=(20, 10))
        
        # Create output text area with scrollbar
        self.output_text = ctk.CTkTextbox(output_frame, wrap="word")
        self.output_text.pack(fill="both", expand=True, padx=20, pady=(0, 20))
        
        # Status bar
        self.status_label = ctk.CTkLabel(output_frame, text="Ready", 
                                       font=ctk.CTkFont(size=12))
        self.status_label.pack(anchor="w", padx=20, pady=(0, 10))
        
    def on_preset_change(self, preset_name):
        """Handle preset selection change"""
        if preset_name in self.scan_presets:
            preset = self.scan_presets[preset_name]
            self.preset_desc_label.configure(text=preset["description"])
            if preset["ports"]:
                self.port_range_var.set(preset["ports"])
        self.update_command_preview()
        
    def update_command_preview(self):
        """Update the command preview based on current settings"""
        try:
            command = self.build_nmap_command()
            self.command_text.delete("1.0", "end")
            self.command_text.insert("1.0", command)
        except Exception as e:
            pass  # Ignore errors during preview update
        
    def build_nmap_command(self):
        """Build the nmap command based on current settings"""
        command_parts = ["nmap"]
        
        # Get preset command
        preset_name = self.scan_type_var.get()
        if preset_name in self.scan_presets:
            preset_cmd = self.scan_presets[preset_name]["command"]
            if preset_cmd:
                command_parts.extend(preset_cmd.split())
        
        # Add timing template
        timing = self.timing_var.get()
        if timing:
            timing_code = timing.split()[0]  # Extract T0, T1, etc.
            command_parts.append(f"-{timing_code}")
        
        # Add port range
        port_range = self.port_range_var.get().strip()
        if port_range and not self.ping_scan_var.get():
            command_parts.extend(["-p", port_range])
        
        # Add advanced options
        if self.service_detection_var.get():
            command_parts.append("-sV")
        if self.os_detection_var.get():
            command_parts.append("-O")
        if self.aggressive_var.get():
            command_parts.append("-A")
        if self.stealth_var.get() and "-sS" not in command_parts:
            command_parts.append("-sS")
        if self.ping_scan_var.get():
            command_parts.append("-sn")
        if self.no_ping_var.get():
            command_parts.append("-Pn")
        if self.traceroute_var.get():
            command_parts.append("--traceroute")
        
        # Add output format
        output_format = self.output_format_var.get()
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        if output_format == "XML":
            command_parts.extend(["-oX", f"nmap_scan_{timestamp}.xml"])
        elif output_format == "Grepable":
            command_parts.extend(["-oG", f"nmap_scan_{timestamp}.gnmap"])
        elif output_format == "All Formats":
            command_parts.extend(["-oA", f"nmap_scan_{timestamp}"])
        
        # Add target
        target = self.target_var.get().strip()
        if target:
            command_parts.append(target)
        else:
            command_parts.append("<TARGET>")
        
        return " ".join(command_parts)
    
    def start_scan(self):
        """Start the nmap scan"""
        target = self.target_var.get().strip()
        if not target:
            messagebox.showerror("Error", "Please enter a target to scan.")
            return
        
        # Confirm scan
        confirm_msg = f"Are you sure you want to scan {target}?\n\nEnsure you have permission to scan this target."
        if not messagebox.askyesno("Confirm Scan", confirm_msg):
            return
        
        self.scan_button.configure(state="disabled")
        self.stop_button.configure(state="normal")
        self.status_label.configure(text="Scanning...")
        
        # Clear previous output
        self.output_text.delete("1.0", "end")
        
        # Start scan in separate thread
        self.scan_thread = threading.Thread(target=self.run_scan)
        self.scan_thread.daemon = True
        self.scan_thread.start()
    
    def run_scan(self):
        """Run the actual nmap scan"""
        try:
            command = self.build_nmap_command()
            
            # Log command
            self.output_text.insert("end", f"Executing: {command}\n")
            self.output_text.insert("end", "="*80 + "\n\n")
            self.output_text.see("end")
            
            # Execute nmap
            self.process = subprocess.Popen(
                command.split(),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                bufsize=1
            )
            
            # Read output in real-time
            for line in iter(self.process.stdout.readline, ''):
                if line:
                    self.output_text.insert("end", line)
                    self.output_text.see("end")
                    self.root.update_idletasks()
            
            # Wait for process to complete
            self.process.wait()
            
            # Update status
            if self.process.returncode == 0:
                self.status_label.configure(text="Scan completed successfully")
                self.output_text.insert("end", "\n" + "="*80 + "\n")
                self.output_text.insert("end", "Scan completed successfully!\n")
            else:
                self.status_label.configure(text=f"Scan failed (exit code: {self.process.returncode})")
                self.output_text.insert("end", f"\nScan failed with exit code: {self.process.returncode}\n")
            
        except FileNotFoundError:
            self.output_text.insert("end", "Error: nmap not found. Please install nmap first.\n")
            self.output_text.insert("end", "Install with: brew install nmap\n")
            self.status_label.configure(text="Error: nmap not found")
        except Exception as e:
            self.output_text.insert("end", f"Error: {str(e)}\n")
            self.status_label.configure(text=f"Error: {str(e)}")
        finally:
            # Re-enable controls
            self.scan_button.configure(state="normal")
            self.stop_button.configure(state="disabled")
            self.output_text.see("end")
    
    def stop_scan(self):
        """Stop the current scan"""
        if hasattr(self, 'process') and self.process:
            self.process.terminate()
            self.status_label.configure(text="Scan stopped by user")
            self.output_text.insert("end", "\n\nScan stopped by user.\n")
            self.scan_button.configure(state="normal")
            self.stop_button.configure(state="disabled")
    
    def clear_output(self):
        """Clear the output text area"""
        self.output_text.delete("1.0", "end")
        self.status_label.configure(text="Output cleared")
    
    def save_results(self):
        """Save scan results to file"""
        content = self.output_text.get("1.0", "end-1c")
        if not content.strip():
            messagebox.showwarning("Warning", "No results to save.")
            return
        
        filename = filedialog.asksaveasfilename(
            defaultextension=".txt",
            filetypes=[("Text files", "*.txt"), ("All files", "*.*")],
            title="Save Scan Results"
        )
        
        if filename:
            try:
                with open(filename, 'w') as f:
                    f.write(content)
                messagebox.showinfo("Success", f"Results saved to {filename}")
            except Exception as e:
                messagebox.showerror("Error", f"Failed to save file: {str(e)}")
    
    def run(self):
        """Start the GUI"""
        # Bind events for real-time command preview updates
        for var in [self.target_var, self.port_range_var, self.timing_var, self.output_format_var]:
            var.trace_add("write", lambda *args: self.update_command_preview())
        
        for var in [self.ping_scan_var, self.service_detection_var, self.os_detection_var, 
                   self.aggressive_var, self.stealth_var, self.no_ping_var, self.traceroute_var]:
            var.trace_add("write", lambda *args: self.update_command_preview())
        
        self.root.mainloop()

def main():
    """Main function"""
    try:
        # Check if nmap is installed
        subprocess.run(["nmap", "--version"], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        root = ctk.CTk()
        root.withdraw()  # Hide the main window
        messagebox.showerror("Error", 
                           "nmap is not installed or not found in PATH.\n\n"
                           "Please install nmap first:\n"
                           "brew install nmap")
        return
    
    app = NmapGUI()
    app.run()

if __name__ == "__main__":
    main()
