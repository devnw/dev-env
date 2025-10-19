#!/usr/bin/env python3
"""
License management script for adding license headers to source files.

Automatically discovers supported source files and adds appropriate license headers.
Handles missing LICENSE and LICENSE_HEADER files gracefully.
"""

import os
import sys
import subprocess
import tempfile
from pathlib import Path

# Define lists of supported file types and directories to ignore
supported = [
    "go",
    "py",
    "js",
    "ts",
    "sh",
    "c",
    "h",
    "cpp",
    "hpp",
    "rs",
    "zig",
    "hcl",
    "zir",
]
ignored_dirs = [
    "scripts",
    "vendor",
    "node_modules",
    ".git",
    ".github",
    ".vscode",
    ".idea",
    ".terraform",
    ".act",
    ".circleci",
    ".gitlab",
    ".venv",
    ".cache",
]


# Function to check if a file should be ignored based on its path
def is_file_in_ignored_dir(file_path, ignored_dirs):
    return any(ignored_dir in file_path for ignored_dir in ignored_dirs)


def find_license_header():
    """Find LICENSE_HEADER file using multiple search strategies."""
    # Check environment variable first
    env_path = os.getenv('LICENSE_HEADER_PATH')
    if env_path and os.path.exists(env_path):
        return env_path
    
    # Search in current directory
    candidates = ['./LICENSE_HEADER', './LICENSE.header', './license.header']
    for candidate in candidates:
        if os.path.exists(candidate):
            return candidate
    
    # Search in git repository root
    try:
        repo_root = subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], text=True).strip()
        for candidate in ['LICENSE_HEADER', 'LICENSE.header', 'license.header']:
            path = os.path.join(repo_root, candidate)
            if os.path.exists(path):
                return path
    except Exception:
        pass
    
    return None


def find_license_file():
    """Find LICENSE file using multiple search strategies."""
    # Check environment variable first
    env_path = os.getenv('LICENSE_FILE_PATH')
    if env_path and os.path.exists(env_path):
        return env_path
    
    # Search in current directory
    candidates = ['./LICENSE', './LICENSE.txt', './license', './license.txt']
    for candidate in candidates:
        if os.path.exists(candidate):
            return candidate
    
    # Search in git repository root
    try:
        repo_root = subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], text=True).strip()
        for candidate in ['LICENSE', 'LICENSE.txt', 'license', 'license.txt']:
            path = os.path.join(repo_root, candidate)
            if os.path.exists(path):
                return path
    except Exception:
        pass
    
    return None


def create_default_header():
    """Create a default license header when none is found."""
    # Get project name from git or directory
    project_name = "this project"
    try:
        repo_root = subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], text=True).strip()
        project_name = os.path.basename(repo_root)
    except Exception:
        project_name = os.path.basename(os.getcwd())
    
    # Get current year
    from datetime import datetime
    current_year = datetime.now().year
    
    # Create default header content
    default_header = f"""Copyright (c) {current_year} {project_name}.

This software is licensed under the terms of the license agreement
you have entered into with the project maintainers.

For more details, see the LICENSE file in the root directory of this
source code repository.
"""
    
    # Write to temporary file
    temp_fd, temp_path = tempfile.mkstemp(suffix='.header', prefix='license_')
    try:
        with os.fdopen(temp_fd, 'w') as f:
            f.write(default_header)
        return temp_path
    except Exception:
        os.close(temp_fd)
        raise


def print_help():
    """Print usage information."""
    print("""
license - License Header Management Tool

USAGE:
    license [files...]

DESCRIPTION:
    Automatically adds license headers to source files. If no files are specified,
    discovers and processes all supported source files in the current directory.

SUPPORTED FILE TYPES:
    Go, Python, JavaScript, TypeScript, Shell, C/C++, Rust, Zig, HCL

ENVIRONMENT VARIABLES:
    LICENSE_HEADER_PATH    Path to license header template file
    LICENSE_FILE_PATH      Path to license file
    LICENSE_CONFIG_DIR     Configuration directory

EXAMPLES:
    license                    # Process all files in current directory
    license src/main.go        # Process specific file
    license src/*.py          # Process specific pattern

FILES SEARCHED (in order):
    LICENSE_HEADER, LICENSE.header, license.header
    LICENSE, LICENSE.txt, license, license.txt

The script will create a default header if no LICENSE_HEADER is found.
""")


# Check for help flag
if len(sys.argv) > 1 and sys.argv[1] in ['-h', '--help', 'help']:
    print_help()
    sys.exit(0)

# Gather target files: if args provided, use them; otherwise traverse repo
if len(sys.argv) > 1:
    target_files = sys.argv[1:]
else:
    target_files = []
    for root, dirs, files in os.walk('.', topdown=True):
        # skip ignored directories
        # respect .gitignore and skip hidden directories
        dirs[:] = [d for d in dirs if d not in ignored_dirs and not d.startswith('.')]
        for f in files:
            # skip hidden files
            if f.startswith('.'):
                continue
            ext = os.path.splitext(f)[1].lstrip('.')
            if ext in supported:
                target_files.append(os.path.join(root, f))

# Track statistics
processed_count = 0
success_count = 0
error_count = 0
temp_headers = []  # Track temporary header files for cleanup

print(f"Found {len(target_files)} files to process")

# Iterate over target files
for file_path in target_files:
    # Extract the file extension
    extension = os.path.splitext(file_path)[1].lstrip(".")

    # Check if the extension is supported
    if extension not in supported:
        continue

    # Check if the file is in an ignored directory
    if is_file_in_ignored_dir(file_path, ignored_dirs) or '/.' in file_path:
        continue

    # Skip hidden files
    base = os.path.basename(file_path)
    if base.startswith('.'):
        continue

    processed_count += 1
    print(f"Processing {file_path}")
    
    # Find header and license files with multiple fallback strategies
    header_path = find_license_header()
    license_path = find_license_file()
    
    if not header_path:
        print(f"Warning: No LICENSE_HEADER found, creating default header")
        try:
            header_path = create_default_header()
            temp_headers.append(header_path)  # Track for cleanup
        except Exception as e:
            print(f"✗ Failed to create default header: {e}")
            error_count += 1
            continue
    
    if not license_path:
        print(f"Info: No LICENSE file found, proceeding with header-only")
    
    try:
        # Run addlicense with appropriate options
        cmd = ['addlicense', '-f', header_path, '-v', file_path]
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        
        if result.returncode == 0:
            print(f"✓ Successfully processed {file_path}")
            success_count += 1
        else:
            print(f"✗ Failed to process {file_path}: {result.stderr.strip()}")
            error_count += 1
            
    except Exception as e:
        print(f"✗ Error processing {file_path}: {e}")
        error_count += 1
        continue

# Cleanup temporary header files
for temp_header in temp_headers:
    try:
        os.unlink(temp_header)
    except Exception:
        pass  # Ignore cleanup errors

# Print summary
print(f"\nLicense processing complete:")
print(f"  Files processed: {processed_count}")
print(f"  Successful: {success_count}")
print(f"  Errors: {error_count}")

# Exit with appropriate code
if error_count > 0:
    print(f"\nSome files failed to process. Check the output above for details.")
    sys.exit(1)
else:
    print(f"\nAll files processed successfully!")
    sys.exit(0)
