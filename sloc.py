#!/usr/bin/env python3
# filepath: count_roc_lines.py

import os
import sys
from pathlib import Path

def count_lines_in_file(file_path):
    """Count the number of lines in a file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            return len(file.readlines())
    except Exception as e:
        print(f"Error reading {file_path}: {e}", file=sys.stderr)
        return 0

def main():
    current_dir = Path('.')
    roc_files = list(current_dir.glob('**/*.roc'))
    
    if not roc_files:
        print("No .roc files found in the current directory or subdirectories.")
        return
    
    total_lines = 0
    results = []
    
    for file_path in roc_files:
        line_count = count_lines_in_file(file_path)
        total_lines += line_count
        results.append((str(file_path), line_count))
    
    # Sort by line count (descending)
    results.sort(key=lambda x: x[1], reverse=True)
    
    # Print results in a table format
    print("\nLines of code in .roc files:")
    print("-" * 60)
    print(f"{'File':<45} | {'Lines':<10}")
    print("-" * 60)
    
    for file_path, line_count in results:
        print(f"{file_path:<45} | {line_count:<10}")
    
    print("-" * 60)
    print(f"{'Total':<45} | {total_lines:<10}")
    print(f"\nFound {len(roc_files)} .roc files with a total of {total_lines} lines")

if __name__ == "__main__":
    main()