COSC3500 Major Project - Game of Life
By Christopher Bailey

How to build:
Load appropriate modules ('module load gnu', 'module load cuda')
Type make and the makefile should build all three targets.

How to run:
Invidual programs can be run using ./gol-<variant> <height> <width> <turns>

Slurm scripts are provided for each version and can be run via 'sbatch slurm-<variant>'

To verify:
Once serial variant has been run for a given set of inputs you can verify the other
two varitions with:
'diff output-serial.txt output-cuda.txt'
'diff output-serial.txt output-openmp.txt'
If no differences are detected (ie the output is the same and correct)
 the diff command will not give any output.