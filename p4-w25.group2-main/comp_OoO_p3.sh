#!/bin/sh

## mult_no_lsq.wb

# Save the current directory path to a variable
path=$(pwd)

program="mult_no_lsq"

echo "Running $program"
##make "${program}.out"

echo "Comparing writeback output for $program"

# Ensure the directories and files exist
if [ ! -f "$path/output/${program}.wb" ]; then
    echo "Error: File $path/output/${program}.wb does not exist."
    exit 1
fi

if [ ! -f "$path/p3output/${program}.wb" ]; then
    echo "Error: File $path/p3output/${program}.wb does not exist."
    exit 1
fi

# Compare the files
diff "$path/output/${program}.wb" "$path/p3output/${program}.wb"
wb_status=$?

if [ $wb_status -eq 0 ]; then
    echo "Test $program: Passed" ##>  "cmp/$program.passed"
else
    echo "Test $program: Failed" ##>  "cmp/$program.failed"
fi