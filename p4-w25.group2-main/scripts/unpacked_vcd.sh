#!/bin/bash

# if you have problems running this, try changing the directory of the vcdplusfile to a absolute path. If anything, reference verilog on eecs website and look vpd, instructions are there.

# Check if an argument was provided
if [ -z "$1" ]; then
    echo "Use: ./scripts/unpacked_vcd.sh <program_name>  ::  example: ./scripts/unpacked_vcd.sh mult_no_lsq"
    echo 'Also be sure to run this in the main directory, and that your testbench file name is cpu_test.sv, and have this in testbench, ex for cpu_test: $vcdplusfile("../dump/cpu_test.vpd"); $vcdpluson();'
fi

##make $1.out

export VCS_HOME='/opt/caen/synopsys/vcs-2023.12-SP2-1'

/opt/caen/synopsys/vcs-2023.12-SP2-1/bin/vpd2vcd +splitpacked /home/tongsing/eecs470/p4-w25.group2/dump/cpu_test.vpd /home/tongsing/eecs470/p4-w25.group2/dump/"$1"_test.vcd
