Game of Life
By Christopher Bailey

This project implements Conway's Game of Life using various HPC methods in C++.

How to build:
Ensure you have a suitable environment (gcc and nvcc) and dependencies.
Type make and the makefile should build all three targets.

How to run:
Invidual programs can be run using ./gol-<variant> <height> <width> <turns>

To verify:
Once serial variant has been run for a given set of inputs you can verify the other
two varitions with:
'diff output-serial.txt output-cuda.txt'
'diff output-serial.txt output-openmp.txt'
If no differences are detected (ie the output is the same and correct)
 the diff command will not give any output.
