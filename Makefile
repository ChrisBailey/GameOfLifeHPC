CXX?=g++
CXXFLAGS?=-std=c++17 -O2 -Wall
NVCC?=nvcc
NVFLAGS?=-O2 --gpu-architecture=sm_35 -Wno-deprecated-gpu-targets

TARGETS = gol-serial gol-avx gol-openmp gol-cuda

default : all

$(TARGETS) :

CXXFLAGS_gol-openmp = -fopenmp
CXXFLAGS_gol-avx = -mavx2

%.o : %.cu
	$(NVCC) $(NVFLAGS) -c $< -o $@

% : %.cu
	$(NVCC) $(NVFLAGS) $(filter %.o %.cu, $^) -o $@

%.o : %.cpp
	$(CXX) $(CXXFLAGS)  -c $< -o $@

% : %.cpp
	$(CXX) $(CXXFLAGS) $(CXXFLAGS_$@) $(filter %.o %.cpp, $^) -o $@

all : $(TARGETS)

clean:
	rm -f $(TARGETS) *.o

.PHONY: clean default all
