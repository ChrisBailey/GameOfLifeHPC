/**
 * @file gol-openmp.cpp
 *
 * @brief A finite 2-D NxM toroidal implementation of Conway's Game of Life using OpenMP.
 *
 * @author Christopher Bailey
 * @date 2022
 * 
 * THIS PROGRAM IS WRITTEN USING C++2017 FEATURES AND REQUIRES
 * USING "module load gnu" ON GETAFIX
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
#include <omp.h>

/***
 * Implements the Game of Life
 */
class Life {
public:
    /***
    * Default constructor
    */
    Life(const unsigned h, const unsigned w) {
        height = h;
        width = w;

        cells.resize(height*width);
        nextcells.resize(height*width);

        // set board pattern here
        init_random();
    }

    /***
     * Simulates the Game of Life
     */
    void run(const unsigned int numTurns) {
        // uncomment below line to print to console
        //output_print();

        for (unsigned int t = 0; t < numTurns; t++) {
            #pragma omp parallel for
            for (unsigned int y = 0; y < height; y++) {
                for (unsigned int x = 0; x < width; x++) {
                    const unsigned int index = (y * height) + x;

                    // count_neighbours inlined here
                    const uint8_t neighbours = cells[((x - 1 + width) % width) + (((y - 1 + height) % height) * width)] // top left
                    + cells[(x) + (((y - 1 + height) % height) * width)] // top
                    + cells[((x + 1) % width) + (((y - 1 + height) % height) * width)] // top right;
                    + cells[((x - 1 + width) % width) + y*width] // left
                    + cells[((x + 1) % width) + y*width] // right
                    + cells[((x - 1 + width) % width) + (((y + 1) % height) * width)] // bottom left
                    + cells[(x) + (((y + 1) % height) * width)] // bottom
                    + cells[((x + 1) % width) + (((y + 1) % height) * width)]; // bottom right;

                    // ruleset implementation logic
                    if (neighbours == 2 ) {  // maintain
                        nextcells[index] = cells[index];
                    } else if (neighbours == 3) {  // live
                        nextcells[index] = alive;
                    } else {  // die
                        nextcells[index] = dead;
                    }
                }
            }

            #pragma omp single
            cells.swap(nextcells);

            // uncomment below lines to print to console
            //std::cout << "t:" << t << std::endl;
            //output_print();
        }
    }

    /***
     * Writes the current board state to a file called output.txt
     */
    void output_file() const {
        std::ofstream outFile("output-openmp.txt");
        for (unsigned int y = 0; y < height; y++) {
            for (unsigned int x = 0; x < width; x++) {
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
        for (unsigned int y = 0; y < height; y++) {
            for (unsigned int x = 0; x < width; x++) {
                std::cout << (unsigned)cells[y*width + x];
            }
            std::cout << std::endl;
        }
        std::cout << std::string(width, '-') << std::endl << std::endl;
    }

private:
    // tunable model parameters
    unsigned height = 20000;
    unsigned width = 20000;

    // non-tunable model parameters
    const uint8_t alive = 1;
    const uint8_t dead = 0;
    std::vector<uint8_t> cells;
    std::vector<uint8_t> nextcells;

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
     * Fills the board with a provided pattern file in Run Length Ecoded format
     * 
     * This method only does limited error checking and assumes correct input
     */
    void init_pattern(std::string filename) {
        // TODO: implement pattern loading
        // std::ifstream inFile(filename);
        // std::string line;
        // int patternWidth;
        // int patternHeight;
        // bool headerFound = false;

        // // find header line
        // while (std::getline(inFile, line)) {
        //     if(line.at(0) == '#') {
        //         // consume hash lines
        //     } else if (line.rfind("x = ", 0) == std::string::npos) {
        //         // found header
        //         headerFound = true;
        //     } else if (headerFound) {
        //         // probably pattern line
        //     } else {
        //         // probably invalid file
        //         std::cout << "Invalid input pattern format" << std::endl;
        //         std::exit; // this is bad and should use exceptions instead
        //     }
        // }
    }
};


/***
 * Program entry point
 */
int main(int argc, char *argv[]) {
    auto totalStartTime = std::chrono::high_resolution_clock::now();
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
    auto modelStartTime = std::chrono::high_resolution_clock::now();
    l.run(turns);
    auto modelFinishTime = std::chrono::high_resolution_clock::now();
    auto modelTime = std::chrono::duration_cast<std::chrono::microseconds>(modelFinishTime - modelStartTime);
    std::cout << "Model run time: " << modelTime.count() << " us\n";

    // output and cleanup
    l.output_file();
    auto totalFinishTime = std::chrono::high_resolution_clock::now();
    auto totalTime = std::chrono::duration_cast<std::chrono::microseconds>(totalFinishTime - totalStartTime);
    std::cout << "Total time: " << totalTime.count() << " us\n";
}
