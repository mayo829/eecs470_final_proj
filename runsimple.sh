#!/bin/sh

# Run `make <program>.out` for all programs that were NOT skipped

make btest1.out
make btest2.out
make copy_long.out
make copy.out
make evens_long.out
make evens.out
make fc_forward.out
make fib_long.out
make fib.out
make haha.out
make halt.out
make insertion.out
make mult_no_lsq.out
make no_hazard.out
make omegalul.out
make parallel.out
make saxpy.out
make sampler.out
make basic_malloc.out

./simplecmp.sh
