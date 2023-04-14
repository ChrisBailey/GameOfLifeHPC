/**
 * @file gol-cuda.cu
 *
 * @brief A finite 2-D NxM toroidal implementation of Conway's Game of Life using CUDA.
 *
 * @author Christopher Bailey
 * @date 2022
 * 
 * THIS PROGRAM IS WRITTEN USING CUDA AND REQUIRES
 * USING "module load cuda" ON GETAFIX
 * 
 * FOR CONSOLE OUTPUT UNCOMMENT THE MARKED LINES IN THE RUN METHOD
 */

#include <algorithm>
#include <chrono>
#include <fstream>
#include <functional>
#include <iostream>
#include <random>
#include <string>
#include <vector>

/***
 * CUDA error checking function used from sumarrays-gpu-v1.cu in course git
 */
void checkError(cudaError_t e)
{
   if (e != cudaSuccess)
   {
      std::cerr << "CUDA error: " << int(e) << " : " << cudaGetErrorString(e) << '\n';
      abort();
   }
}

/***
 * Implementation of the neighbour count and and ruleset on a CUDA device
 * 
 * Code will run on device but can be called from the CPU
 */
__global__
void cudaRun(int n, int w, int h, int* current, int* next) {
    int index = blockIdx.x*blockDim.x + threadIdx.x;
    int stride = blockDim.x*gridDim.x;

    for (int i = index; i < n; i+= stride) {
        const int x = i % w;
        const int y = i / w;

        // count neighbours
        const int neighbours =
            current[((x - 1 + w) % w) + (((y - 1 + h) % h) * w)] // top left
            + current[(x) + (((y - 1 + h) % h) * w)] // top
            + current[((x + 1) % w) + (((y - 1 + h) % h) * w)] // top right;
            + current[((x - 1 + w) % w) + y*w] // left
            + current[((x + 1) % w) + y*w] // right
            + current[((x - 1 + w) % w) + (((y + 1) % h) * w)] // bottom left
            + current[(x) + (((y + 1) % h) * w)] // bottom
            + current[((x + 1) % w) + (((y + 1) % h) * w)]; // bottom right;

        // ruleset implementation logic
        if (neighbours == 2 ) {  // maintain
            next[i] = current[i];
        } else if (neighbours == 3) {  // live
            next[i] = 1;
        } else {  // die
            next[i] = 0;
        }
    }
}


/***
 * Implements the Game of Life
 */
class Life {
public:
    /***
    * Constructor for initialising
    */
    Life(const unsigned h, const unsigned w) {
        height = h;
        width = w;

        cells.resize(height*width);
        nextcells.resize(height*width);

        // init device memory
        checkError(cudaMalloc(&cellsDevice, cells.size()*sizeof(int)));
        checkError(cudaMalloc(&nextcellsDevice, cells.size()*sizeof(int)));

        // set board pattern here
        init_random();

        // copy cells from host to device
        checkError(cudaMemcpy(cellsDevice, cells.data(), cells.size()*sizeof(int), cudaMemcpyHostToDevice));
    }

    /***
     * Simulates the Game of Life
     */
    void run(const unsigned numTurns) {
        // uncomment below line to print to console
        //output_print();

        // we want to use the max number of CUDA threads per CUDA thread block for performance
        // we want to make sure we can use as many blocks as the problem and device will fit
        // this is device dependent on number of cuda cores and cuda streaming multiprocessors
        const int threads = 256;
        const int blocks = (cells.size()+threads-1)/threads;

        for (unsigned t = 0; t < numTurns; t++) {
            // run the computation on the device
            cudaRun<<<blocks, threads>>>(cells.size(), width, height, cellsDevice, nextcellsDevice); // asychronous
            checkError(cudaDeviceSynchronize());
            
            // swap between the grids so we dont have to do expensive copies
            int* temp = cellsDevice;
            cellsDevice = nextcellsDevice;
            nextcellsDevice = temp;

            // copy nextcells from device to host
            // this is only necessary for console output and can be moved outside the loop to save io time
            checkError(cudaMemcpy(cells.data(), cellsDevice, cells.size()*sizeof(int), cudaMemcpyDeviceToHost));

            // uncomment below lines to print to console
            //std::cout << "t:" << t << std::endl;
            //output_print();
        }
    }

    /***
     * Writes the current board state to a file called output.txt
     */
    void output_file() const {
        std::ofstream outFile("output-cuda.txt");
        for (unsigned y = 0; y < height; y++) {
            for (unsigned x = 0; x < width; x++) {
                outFile << (unsigned)cells[y*width + x];
            }
            outFile << std::endl;
        }
        outFile.close();
    }

    /***
     * Writes the current board state to the console
     */
    void output_print() const {
        std::cout << std::string(width, '-') << std::endl;
        for (unsigned y = 0; y < height; y++) {
            for (unsigned x = 0; x < width; x++) {
                std::cout << (unsigned)cells[y*width + x];
            }
            std::cout << std::endl;
        }
        std::cout << std::string(width, '-') << std::endl << std::endl;
    }

private:
    // tunable model parameters
    unsigned height;
    unsigned width;

    // non-tunable model parameters
    const int alive = 1;
    const int dead = 0;
    std::vector<int> cells;
    std::vector<int> nextcells;
    int* cellsDevice;
    int* nextcellsDevice;

    /***
     * Fills the board with random dead/alive cells
     */
    void init_random() {
        std::uniform_int_distribution<int> distribution(0,1);
        std::mt19937 engine;
        auto generator = std::bind(distribution, engine);
        std::generate(cells.begin(), cells.end(), generator);
    }

    /***
     * Fills the board with a single glider in the top left corner
     */
    void init_glider() {
        std::fill(cells.begin(), cells.end(), dead);

        cells[0+2] = alive;
        cells[0+width] = alive;
        cells[0+width+2] = alive;
        cells[0+width+width+1] = alive;
        cells[0+width+width+2] = alive;
    }

    /***
     * Fills the board with a provided pattern file in x format
     */
    void init_pattern() {
        // TODO: implement pattern loading
    }
};


/***
 * Program entry point
 */
int main(int argc, char *argv[]) {
    auto totalStartTime = std::chrono::steady_clock::now();
    // command line argument handling
    std::vector<std::string> args(argv, argv+argc);
    unsigned height, width, turns;
    if (args.size() == 4) {
        height = std::stoi(args[1]);
        width = std::stoi(args[2]);
        turns = std::stoi(args[3]);
    } else {
        std::cout << "Usage: ./gol-cuda <height> <width> <turns>" << std::endl;
        return 1;
    }

    Life l(height, width);

    // time and run the simulation
    auto modelStartTime = std::chrono::steady_clock::now();
    l.run(turns);
    auto modelFinishTime = std::chrono::steady_clock::now();
    auto modelTime = std::chrono::duration_cast<std::chrono::microseconds>(modelFinishTime - modelStartTime);
    std::cout << "Model run time: " << modelTime.count() << " us\n";

    // output and cleanup
    l.output_file();
    auto totalFinishTime = std::chrono::steady_clock::now();
    auto totalTime = std::chrono::duration_cast<std::chrono::microseconds>(totalFinishTime - totalStartTime);
    std::cout << "Total time: " << totalTime.count() << " us\n";
}
