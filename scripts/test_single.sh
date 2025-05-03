program=($1)

cd /home/lbrzozow/Documents/eecs470/proj/p3-w25.lbrzozow-GT
make $program.out
cp output/$program.out /home/lbrzozow/Documents/eecs470/proj/p3-w25.lbrzozow/correct_out

cd /home/lbrzozow/Documents/eecs470/proj/p3-w25.lbrzozow
make $program.out

diff "correct_out/$program.wb" "output/$program.wb" > /dev/null

if [ $? -eq 0 ]; then
    echo "!!!$program passed wb test!!!"
else
    echo "===$program failed wb test==="
fi