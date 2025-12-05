#!/usr/bin/env python3
"""
Script to fix const errors by removing const keyword from widgets with scalify extensions.
"""

import re
import sys
from pathlib import Path

def remove_const_from_scalify_widgets(content):
    """Remove const keyword from widgets that use scalify extensions."""
    
    # Pattern to match const Text/Icon/etc with .fz, .s, .r extensions
    patterns = [
        # const Text with .fz
        (r'const\s+(Text\([^)]*?\.fz[^)]*?\))', r'\1'),
        # const Icon with .s
        (r'const\s+(Icon\([^)]*?\.s[^)]*?\))', r'\1'),
        # const TextStyle with .fz
        (r'const\s+(TextStyle\([^)]*?\.fz[^)]*?\))', r'\1'),
        # const BorderRadius with .r
        (r'const\s+(BorderRadius\.[^(]*?\([^)]*?\.r[^)]*?\))', r'\1'),
        # const Radius with .r
        (r'const\s+(Radius\.[^(]*?\([^)]*?\.r[^)]*?\))', r'\1'),
        # const EdgeInsets with .w or .h
        (r'const\s+(EdgeInsets\.[^(]*?\([^)]*?\.[wh][^)]*?\))', r'\1'),
        # const SizedBox with .w or .h
        (r'const\s+(SizedBox\([^)]*?\.[wh][^)]*?\))', r'\1'),
    ]
    
    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    return content

def process_file(filepath):
    """Process a single Dart file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        content = remove_const_from_scalify_widgets(content)
        
        if content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✓ Fixed const errors in: {filepath}")
            return True
        else:
            print(f"- No const errors found in: {filepath}")
            return False
    except Exception as e:
        print(f"✗ Error processing {filepath}: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 fix_const_errors.py <file_or_directory>")
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
        
        print(f"\nTotal: {total} files, Fixed: {processed} files")
    else:
        print(f"Error: {target} is not a valid file or directory")
        sys.exit(1)

if __name__ == '__main__':
    main()
