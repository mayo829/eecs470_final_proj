echo "Generating ground truth outputs to new processor"

# cd ~/Documents/eecs470/labs/lab4

#for source_file in programs/*.s programs/*.c; do

for source_file in programs/*.s; do
    if [ "$source_file" = "programs/crt.s" ]
    then
        continue
    fi
    program=$(echo "$source_file" | cut -d '.' -f1 | cut -d '/' -f2)
    
    echo "Running $program..."
    
    timeout 30s make $program.out
    if [ $? -eq 124 ]; then
        echo "Timeout occurred for $program, skipping..."
        continue
    fi


    wb_diff=$(diff "/home/balaboud/eecs470/p4-w25.group2/output/$program.wb" "/home/balaboud/eecs470/p4-w25.group2/p3output/$program.wb")

    grep "^@@@" "/home/balaboud/eecs470/p4-w25.group2/output/$program.out" > temp_out1.txt

    grep "^@@@" "/home/balaboud/eecs470/p4-w25.group2/p3output/$program.out" > temp_out.txt

    mem_diff=$(diff temp_out.txt temp_out1.txt)

    echo "comparing writeback output for $program"
    if [[ -z "$wb_diff" ]]; then
        echo "Writeback matches!"
    else
        echo "Writeback doesn't match"
    fi

    echo "comparing memory output for $program"
    if [[ -z "$mem_diff" ]]; then
        echo "Memory matches!"
    else
        echo "Memory doesn't match"
    fi

    echo "Printing Pass or Fail"
    if [[ -z "$wb_diff" && -z "$mem_diff" ]]; then
        echo "$program : passed"
    else
        echo "$program : failed"
    fi

    echo "-----------------were done here...----------------"
done