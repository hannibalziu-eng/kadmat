#!/usr/bin/env python3
"""
Script to automatically refactor Flutter files to use flutter_scalify responsive units.
"""

import re
import sys
from pathlib import Path

def add_scalify_import(content):
    """Add flutter_scalify import if not present."""
    if 'flutter_scalify' in content:
        return content
    
    # Find the last import statement
    import_pattern = r"(import ['\"].*?['\"];)"
    imports = list(re.finditer(import_pattern, content))
    
    if imports:
        last_import = imports[-1]
        insert_pos = last_import.end()
        return content[:insert_pos] + "\nimport 'package:flutter_scalify/flutter_scalify.dart';" + content[insert_pos:]
    
    return content

def refactor_values(content):
    """Replace hardcoded values with responsive units."""
    
    # Replace const EdgeInsets with responsive EdgeInsets
    content = re.sub(r'const EdgeInsets\.all\(([0-9.]+)\)', r'EdgeInsets.all(\1.w)', content)
    content = re.sub(r'const EdgeInsets\.symmetric\(horizontal: ([0-9.]+), vertical: ([0-9.]+)\)',r'EdgeInsets.symmetric(horizontal: \1.w, vertical: \2.h)', content)
    content = re.sub(r'const EdgeInsets\.symmetric\(horizontal: ([0-9.]+)\)', r'EdgeInsets.symmetric(horizontal: \1.w)', content)
    content = re.sub(r'const EdgeInsets\.symmetric\(vertical: ([0-9.]+)\)', r'EdgeInsets.symmetric(vertical: \1.h)', content)
    content = re.sub(r'const EdgeInsets\.only\(([^)]+)\)', lambda m: refactor_edge_insets_only(m.group(1)), content)
    
    # Replace const SizedBox with responsive SizedBox
    content = re.sub(r'const SizedBox\(height: ([0-9.]+)\)', r'SizedBox(height: \1.h)', content)
    content = re.sub(r'const SizedBox\(width: ([0-9.]+)\)', r'SizedBox(width: \1.w)', content)
    
    # Replace fontSize values
    content = re.sub(r'fontSize:\s*([0-9.]+)(?![.a-zA-Z])', r'fontSize: \1.fz', content)
    
    # Replace size values for icons
    content = re.sub(r'size:\s*([0-9.]+)(?![.a-zA-Z])', r'size: \1.s', content)
    
    # Replace BorderRadius.circular
    content = re.sub(r'BorderRadius\.circular\(([0-9.]+)\)', r'BorderRadius.circular(\1.r)', content)
    content = re.sub(r'Radius\.circular\(([0-9.]+)\)', r'Radius.circular(\1.r)', content)
    
    # Replace width and height in Container widgets
    content = re.sub(r'width:\s*([0-9.]+)(?![.a-zA-Z]),', r'width: \1.w,', content)
    content = re.sub(r'height:\s*([0-9.]+)(?![.a-zA-Z]),', r'height: \1.h,', content)
    
    # Replace blurRadius
    content = re.sub(r'blurRadius:\s*([0-9.]+)(?![.a-zA-Z])', r'blurRadius: \1.r', content)
    
    return content

def refactor_edge_insets_only(params_str):
    """Refactor EdgeInsets.only parameters."""
    params = params_str.split(',')
    new_params = []
    for param in params:
        param = param.strip()
        if 'left:' in param or 'right:' in param:
            param = re.sub(r'([a-z]+):\s*([0-9.]+)', r'\1: \2.w', param)
        elif 'top:' in param or 'bottom:' in param:
            param = re.sub(r'([a-z]+):\s*([0-9.]+)', r'\1: \2.h', param)
        new_params.append(param)
    return f'EdgeInsets.only({", ".join(new_params)})'

def process_file(filepath):
    """Process a single Dart file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Add import
        content = add_scalify_import(content)
        
        # Refactor values
        content = refactor_values(content)
        
        # Only write if changed
        if content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✓ Refactored: {filepath}")
            return True
        else:
            print(f"- Skipped (no changes): {filepath}")
            return False
    except Exception as e:
        print(f"✗ Error processing {filepath}: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 refactor_scalify.py <file_or_directory>")
        sys.exit(1)
    
    target = Path(sys.argv[1])
    
    if target.is_file():
        process_file(target)
    elif target.is_dir():
        dart_files = list(target.rglob('*.dart'))
        total = len(dart_files)
        processed = 0
        
        for dart_file in dart_files:
            if process_file(dart_file):
                processed += 1
        
        print(f"\nTotal: {total} files, Processed: {processed} files")
    else:
        print(f"Error: {target} is not a valid file or directory")
        sys.exit(1)

if __name__ == '__main__':
    main()
