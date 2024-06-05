#!/bin/bash

# Initialize variables
sloc=0
nfiles=0

# Function to count lines in a file
file_len() {
    wc -l < "$1" | tr -d ' '
}

# Traverse the directory tree and count lines in .roc files
for file in $(find . -type f -name '*.roc'); do
    length=$(file_len "$file")
    echo "$length lines in $file"
    sloc=$((sloc + length))
    nfiles=$((nfiles + 1))
done

# Calculate average lines per file
if [ $nfiles -gt 0 ]; then
    avg=$(echo "scale=1; $sloc / $nfiles" | bc)
else
    avg=0
fi

# Output results
echo -e "\n=========== SLOC ==========="
echo "  $sloc lines in $nfiles files"
echo "  avg. file: $avg lines"
echo "============================"
