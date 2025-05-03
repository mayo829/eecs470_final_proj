echo "Comparing ground truth outputs to new processor"

path=$(pwd)
# Loop through both .s and .c files
for source_file in programs/*.{s,c}; do
    if [ "$source_file" = "programs/crt.s" ]
    then
        continue
    fi
    
    program=$(basename "$source_file" | cut -d '.' -f1)
    
    echo "Running $program"
    # Run the program: replace `make run` with your actual target
    make SOURCE="$source_file" 
    
    # Compare writeback output
    echo "Comparing writeback output for $program"
    diff "$path/output/$program.wb" "$path/p3output/$program.wb"
    wb_status=$?

    # # Compare memory output and record differences
    # echo "Comparing memory output for $program"
    # grep '^@@@' "$path/p3-w25.tongsing/output/$program.out" > "current_memory.out"
    # grep '^@@@' "$path/p3-w25.tongsing/p3output/$program.out" > "ground_memory.out"
    # # Record differences to memory.out
    # diff "$path/p3-w25.tongsing/current_memory.out" "$path/p3-w25.tongsing/ground_memory.out" ## > "cmp/$program.memory.out"
    # mem_status=$?

    if [ $wb_status -eq 0 ]; then ## && [ $mem_status -eq 0 ]; then
        echo "Test $program: Passed" ##>  "cmp/$program.passed"
    else
        echo "Test $program: Failed" ##>  "cmp/$program.failed"
    fi
    
    # Clean-up temporary files
    ## rm "current_memory.out" "ground_memory.out"
done