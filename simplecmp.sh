#!/bin/sh

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Comparing output against reference results..."

# Get current directory
path=$(pwd)

# Initialize counters
total=0
passed=0
failed=0
passed_both=0
passed_wb_only=0
passed_mem_only=0
failed_both=0
skipped=0  # <== NEW

# Loop through .s and .c files
for source_file in programs/*.[sc]; do
    filename=$(basename "$source_file")
    
    # Skip crt.s
    if [ "$filename" = "crt.s" ]; then
        continue
    fi

    # Remove extension to get program name
    program="${filename%.*}"

    wb1="$path/output/${program}.wb"
    wb2="$path/p3output/${program}.wb"
    out1="$path/output/${program}.out"
    out2="$path/p3output/${program}.out"

    # Skip if either file is missing
    if [ ! -f "$wb1" ] || [ ! -f "$wb2" ] || [ ! -f "$out1" ] || [ ! -f "$out2" ]; then
        echo -e "${YELLOW}Skipping $program (missing output files)${NC}"
        skipped=$((skipped + 1))  # <== NEW
        continue
    fi

    total=$((total + 1))

    echo "========================="
    echo "Comparing results for $program"

    # Compare .wb files
    wb_diff=$(diff "$wb1" "$wb2")

    # Compare filtered .out files (only lines starting with @@@)
    grep "^@@@" "$out1" > temp_out1.txt
    grep "^@@@" "$out2" > temp_out2.txt
    mem_diff=$(diff temp_out1.txt temp_out2.txt)

    # Output comparison results
    if [ -z "$wb_diff" ]; then
        echo "Writeback matches"
    else
        echo "Writeback doesn't match"
    fi

    if [ -z "$mem_diff" ]; then
        echo "Memory matches"
    else
        echo "Memory doesn't match"
    fi

    # Classification
    if [ -z "$wb_diff" ] && [ -z "$mem_diff" ]; then
        echo -e "${GREEN}$program : passed (wb + mem)${NC}"
        passed=$((passed + 1))
        passed_both=$((passed_both + 1))
    elif [ -z "$wb_diff" ]; then
        echo -e "${YELLOW}$program : partial pass (wb only)${NC}"
        passed=$((passed + 1))
        passed_wb_only=$((passed_wb_only + 1))
    elif [ -z "$mem_diff" ]; then
        echo -e "${YELLOW}$program : partial pass (mem only)${NC}"
        passed=$((passed + 1))
        passed_mem_only=$((passed_mem_only + 1))
    else
        echo -e "${RED}$program : failed (wb + mem)${NC}"
        failed=$((failed + 1))
        failed_both=$((failed_both + 1))
    fi
done

rm -f temp_out1.txt temp_out2.txt

# Final summary
echo "========================="
echo -e "Total programs checked: $total"
echo -e "${GREEN}Passed both     : $passed_both${NC}"
echo -e "${YELLOW}Passed wb only  : $passed_wb_only${NC}"
echo -e "${YELLOW}Passed mem only : $passed_mem_only${NC}"
echo -e "${RED}Failed both     : $failed_both${NC}"
echo ""
echo -e "${GREEN}Total passed    : $passed out of $total${NC}"
echo -e "${RED}Total failed    : $failed out of $total${NC}"
echo -e "${YELLOW}Total skipped   : $skipped${NC}"  # <== NEW
