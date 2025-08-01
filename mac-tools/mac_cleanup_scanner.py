#!/usr/bin/env python3
"""
Mac Cleanup Scanner
A safe file cleanup utility that identifies potential cleanup targets
but requires user confirmation before deletion.
"""

import os
import hashlib
import json
from pathlib import Path
from collections import defaultdict
import subprocess
import sys
from datetime import datetime, timedelta

class MacCleanupScanner:
    def __init__(self):
        self.home_dir = Path.home()
        self.trash_patterns = [
            '.DS_Store',
            '.localized',
            'Thumbs.db',
            '.Trashes',
            '.fseventsd',
            '.Spotlight-V100',
            '.TemporaryItems',
            'Icon\r',  # Custom folder icons
        ]
        
        # Directories to scan for cleanup (safely restricted)
        self.scan_dirs = [
            self.home_dir / 'Downloads',
            self.home_dir / 'Desktop', 
            self.home_dir / 'Documents',
            self.home_dir / 'Pictures',
            self.home_dir / 'Movies',
            Path('/tmp'),
        ]
        
        # Directories to NEVER touch (safety)
        self.protected_dirs = {
            '/System', '/usr', '/bin', '/sbin', '/etc', '/var',
            str(self.home_dir / 'Library' / 'Application Support'),
            str(self.home_dir / 'Library' / 'Preferences'),
        }
        
        self.findings = {
            'trash_files': [],
            'duplicates': [],
            'large_files': [],
            'old_downloads': [],
            'cache_files': []
        }

    def is_safe_to_scan(self, path):
        """Check if a path is safe to scan"""
        path_str = str(path.resolve())
        for protected in self.protected_dirs:
            if path_str.startswith(protected):
                return False
        return True

    def calculate_file_hash(self, filepath):
        """Calculate MD5 hash of a file"""
        try:
            hash_md5 = hashlib.md5()
            with open(filepath, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_md5.update(chunk)
            return hash_md5.hexdigest()
        except (OSError, IOError):
            return None

    def scan_trash_files(self):
        """Scan for common trash/junk files"""
        print("🔍 Scanning for trash files...")
        
        for scan_dir in self.scan_dirs:
            if not scan_dir.exists() or not self.is_safe_to_scan(scan_dir):
                continue
                
            try:
                for root, dirs, files in os.walk(scan_dir):
                    # Skip hidden directories for safety
                    dirs[:] = [d for d in dirs if not d.startswith('.') or d in ['.Trash']]
                    
                    for file in files:
                        if any(pattern in file for pattern in self.trash_patterns):
                            filepath = Path(root) / file
                            try:
                                size = filepath.stat().st_size
                                self.findings['trash_files'].append({
                                    'path': str(filepath),
                                    'size': size,
                                    'type': 'trash_file'
                                })
                            except OSError:
                                continue
            except (PermissionError, OSError):
                continue

    def scan_duplicates(self):
        """Scan for duplicate files"""
        print("🔍 Scanning for duplicate files...")
        
        file_hashes = defaultdict(list)
        
        for scan_dir in self.scan_dirs:
            if not scan_dir.exists() or not self.is_safe_to_scan(scan_dir):
                continue
                
            try:
                for root, dirs, files in os.walk(scan_dir):
                    # Skip hidden directories and system directories
                    dirs[:] = [d for d in dirs if not d.startswith('.')]
                    
                    for file in files:
                        if file.startswith('.'):
                            continue
                            
                        filepath = Path(root) / file
                        try:
                            # Only check files larger than 1KB to avoid tiny files
                            if filepath.stat().st_size > 1024:
                                file_hash = self.calculate_file_hash(filepath)
                                if file_hash:
                                    file_hashes[file_hash].append({
                                        'path': str(filepath),
                                        'size': filepath.stat().st_size,
                                        'modified': filepath.stat().st_mtime
                                    })
                        except (OSError, IOError):
                            continue
            except (PermissionError, OSError):
                continue
        
        # Find duplicates
        for file_hash, files in file_hashes.items():
            if len(files) > 1:
                # Sort by modification time, keep the newest
                files.sort(key=lambda x: x['modified'], reverse=True)
                for duplicate in files[1:]:  # Skip the first (newest) file
                    duplicate['type'] = 'duplicate'
                    self.findings['duplicates'].append(duplicate)

    def scan_large_files(self, min_size_mb=100):
        """Scan for large files that might be cleanup candidates"""
        print("🔍 Scanning for large files...")
        
        min_size = min_size_mb * 1024 * 1024  # Convert to bytes
        
        for scan_dir in self.scan_dirs:
            if not scan_dir.exists() or not self.is_safe_to_scan(scan_dir):
                continue
                
            try:
                for root, dirs, files in os.walk(scan_dir):
                    dirs[:] = [d for d in dirs if not d.startswith('.')]
                    
                    for file in files:
                        if file.startswith('.'):
                            continue
                            
                        filepath = Path(root) / file
                        try:
                            size = filepath.stat().st_size
                            if size > min_size:
                                self.findings['large_files'].append({
                                    'path': str(filepath),
                                    'size': size,
                                    'size_mb': round(size / (1024 * 1024), 2),
                                    'type': 'large_file'
                                })
                        except OSError:
                            continue
            except (PermissionError, OSError):
                continue

    def scan_old_downloads(self, days_old=30):
        """Scan for old files in Downloads folder"""
        print("🔍 Scanning for old downloads...")
        
        downloads_dir = self.home_dir / 'Downloads'
        if not downloads_dir.exists():
            return
            
        cutoff_date = datetime.now() - timedelta(days=days_old)
        
        try:
            for item in downloads_dir.iterdir():
                if item.is_file() and not item.name.startswith('.'):
                    try:
                        modified_time = datetime.fromtimestamp(item.stat().st_mtime)
                        if modified_time < cutoff_date:
                            self.findings['old_downloads'].append({
                                'path': str(item),
                                'size': item.stat().st_size,
                                'modified': modified_time.strftime('%Y-%m-%d'),
                                'type': 'old_download'
                            })
                    except OSError:
                        continue
        except (PermissionError, OSError):
            pass

    def scan_cache_files(self):
        """Scan for cache files (safely)"""
        print("🔍 Scanning for cache files...")
        
        cache_dirs = [
            self.home_dir / 'Library' / 'Caches',
        ]
        
        for cache_dir in cache_dirs:
            if not cache_dir.exists():
                continue
                
            try:
                # Only scan user-level caches, not system caches
                for app_cache in cache_dir.iterdir():
                    if app_cache.is_dir() and not app_cache.name.startswith('com.apple'):
                        try:
                            total_size = sum(f.stat().st_size for f in app_cache.rglob('*') if f.is_file())
                            if total_size > 10 * 1024 * 1024:  # Only report caches > 10MB
                                self.findings['cache_files'].append({
                                    'path': str(app_cache),
                                    'size': total_size,
                                    'size_mb': round(total_size / (1024 * 1024), 2),
                                    'type': 'cache_dir'
                                })
                        except (OSError, PermissionError):
                            continue
            except (PermissionError, OSError):
                continue

    def run_full_scan(self):
        """Run all scans"""
        print("🚀 Starting Mac cleanup scan...")
        print("⚠️  This scanner only identifies files - you choose what to delete!")
        print()
        
        self.scan_trash_files()
        self.scan_duplicates()
        self.scan_large_files()
        self.scan_old_downloads()
        self.scan_cache_files()
        
        self.display_results()

    def format_size(self, size_bytes):
        """Format file size in human readable format"""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size_bytes < 1024.0:
                return f"{size_bytes:.1f} {unit}"
            size_bytes /= 1024.0
        return f"{size_bytes:.1f} TB"

    def display_results(self):
        """Display scan results"""
        print("\n" + "="*60)
        print("📊 SCAN RESULTS")
        print("="*60)
        
        total_files = 0
        total_size = 0
        
        for category, items in self.findings.items():
            if items:
                print(f"\n📁 {category.replace('_', ' ').title()}: {len(items)} items")
                category_size = sum(item['size'] for item in items)
                total_size += category_size
                total_files += len(items)
                print(f"   Total size: {self.format_size(category_size)}")
                
                # Show first few items as examples
                for i, item in enumerate(items[:3]):
                    print(f"   • {item['path']} ({self.format_size(item['size'])})")
                    
                if len(items) > 3:
                    print(f"   ... and {len(items) - 3} more")
        
        print(f"\n🎯 SUMMARY:")
        print(f"   Total items found: {total_files}")
        print(f"   Total potential space: {self.format_size(total_size)}")
        
        if total_files > 0:
            print(f"\n⚠️  SAFETY REMINDER:")
            print(f"   - Review each file before deletion")
            print(f"   - This scanner avoids system files, but be careful")
            print(f"   - Consider moving files to Trash instead of permanent deletion")
            
            self.offer_cleanup_options()

    def offer_cleanup_options(self):
        """Offer cleanup options with safety checks"""
        print(f"\n🛠️  CLEANUP OPTIONS:")
        print(f"1. Export findings to JSON file")
        print(f"2. Delete trash files only (safest)")
        print(f"3. Move duplicates to Trash")
        print(f"4. Exit (recommended - review manually)")
        
        try:
            choice = input(f"\nChoose an option (1-4): ").strip()
            
            if choice == "1":
                self.export_findings()
            elif choice == "2":
                self.delete_trash_files()
            elif choice == "3":
                self.move_duplicates_to_trash()
            elif choice == "4":
                print("👍 Wise choice! Review the findings manually.")
            else:
                print("Invalid choice. Exiting for safety.")
        except KeyboardInterrupt:
            print("\n👋 Cleanup cancelled.")

    def export_findings(self):
        """Export findings to JSON file"""
        output_file = self.home_dir / 'Desktop' / f'cleanup_scan_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json'
        
        try:
            with open(output_file, 'w') as f:
                json.dump(self.findings, f, indent=2)
            print(f"✅ Findings exported to: {output_file}")
        except IOError as e:
            print(f"❌ Failed to export findings: {e}")

    def delete_trash_files(self):
        """Delete only obvious trash files (safest option)"""
        trash_files = self.findings['trash_files']
        
        if not trash_files:
            print("No trash files found.")
            return
            
        print(f"\n⚠️  About to delete {len(trash_files)} trash files:")
        for item in trash_files[:5]:
            print(f"   • {item['path']}")
        if len(trash_files) > 5:
            print(f"   ... and {len(trash_files) - 5} more")
            
        confirm = input(f"\nConfirm deletion? (type 'DELETE' to confirm): ")
        
        if confirm == "DELETE":
            deleted_count = 0
            for item in trash_files:
                try:
                    os.remove(item['path'])
                    deleted_count += 1
                except OSError as e:
                    print(f"Failed to delete {item['path']}: {e}")
            
            print(f"✅ Deleted {deleted_count} trash files.")
        else:
            print("Deletion cancelled.")

    def move_duplicates_to_trash(self):
        """Move duplicate files to Trash (safer than permanent deletion)"""
        duplicates = self.findings['duplicates']
        
        if not duplicates:
            print("No duplicates found.")
            return
            
        print(f"\n⚠️  About to move {len(duplicates)} duplicate files to Trash:")
        for item in duplicates[:5]:
            print(f"   • {item['path']}")
        if len(duplicates) > 5:
            print(f"   ... and {len(duplicates) - 5} more")
            
        confirm = input(f"\nConfirm moving to Trash? (type 'TRASH' to confirm): ")
        
        if confirm == "TRASH":
            moved_count = 0
            for item in duplicates:
                try:
                    # Use macOS Trash
                    subprocess.run(['osascript', '-e', f'tell app "Finder" to delete POSIX file "{item["path"]}"'], 
                                 check=True, capture_output=True)
                    moved_count += 1
                except (subprocess.CalledProcessError, OSError) as e:
                    print(f"Failed to move {item['path']}: {e}")
            
            print(f"✅ Moved {moved_count} duplicate files to Trash.")
        else:
            print("Operation cancelled.")


def main():
    """Main function"""
    print("🧹 Mac Cleanup Scanner")
    print("=" * 30)
    
    try:
        scanner = MacCleanupScanner()
        scanner.run_full_scan()
    except KeyboardInterrupt:
        print("\n👋 Scan interrupted by user.")
    except Exception as e:
        print(f"❌ An error occurred: {e}")
        print("Please check permissions and try again.")


if __name__ == "__main__":
    main()