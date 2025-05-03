#!/bin/bash

SCALARS=(1 2 3 4)
ROB_SZS=(8 16 32 54)

# Get the current directory (i.e., the workspace folder)
WORKSPACE_DIR=$(pwd)

# Define the Verilog file in the current directory
VERILOG_FILE="$WORKSPACE_DIR/test/rob_test.sv"

for SCALAR in "${SCALARS[@]}"; do
  for ROB_SZ in "${ROB_SZS[@]}"; do
    # Print the current configuration
    echo "Testing with SCALAR = $SCALAR and ROB_SZ = $ROB_SZ"
    
    # Use sed to change the parameters in the Verilog file
    sed -i "s/localparam integer SCALAR        = [0-9]\+/localparam integer SCALAR        = $SCALAR/" $VERILOG_FILE
    sed -i "s/localparam integer ROB_SZ        = [0-9]\+/localparam integer ROB_SZ        = $ROB_SZ/" $VERILOG_FILE
    
    # Optionally, you can print the modified file's first few lines to verify
    echo "Updated Verilog file for SCALAR = $SCALAR, ROB_SZ = $ROB_SZ:"
    head -n 10 $VERILOG_FILE
    
    # Here, you could run simulation commands if needed
    # For example: `vcs -f filelist.f` or any other simulator command
    
    # Optionally, you can save results in a separate directory or log
    # For example: `mv $VERILOG_FILE "ROB_test_SCALAR${SCALAR}_ROB_SZ${ROB_SZ}.v"`

    make rob.out
  done
done

echo "Parameter update and testing completed!"