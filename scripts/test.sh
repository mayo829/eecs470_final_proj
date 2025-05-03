echo "Testing own processor"

cd ~/Documents/eecs470/proj/p3-w25.lbrzozow

# # This iterates through *.s and *.c files.
# for source_file in programs/*.s programs/*.c; do
#     if [[ "$source_file" = "programs/crt.s" || "$source_file" =~ ^programs/test.*\.s$ ]]
#     then
#         continue
#     fi
#     program=$(echo "$source_file" | cut -d '.' -f1 | cut -d '/' -f 2)
#     echo "Running $program"
#     make $program.out
# done

echo "Testing write back files"
for correct_file in output/*.wb; do
    file_name=$(echo "$correct_file" | cut -d '/' -f 2)
    diff correct_out/$file_name output/$file_name > /dev/null

    if [ $? -eq 0 ]; then
        echo "!!!$file_name passed wb test!!!"
    else
        echo "===$file_name failed wb test==="
    fi
done

# echo "Testing memory files"
# for correct_file in correct_out/*.out; do
#     file_name=$(echo "$correct_file" | cut -d '/' -f 2)
#     diff <(grep '^@@@' correct_out/$file_name) <(grep '^@@@' output/$file_name) > /dev/null

#     if [ $? -eq 0 ]; then
#         echo "$file_name Passed mem test"
#     else
#         echo "$file_name Failed mem test"
#     fi
# done