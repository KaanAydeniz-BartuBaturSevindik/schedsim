# SchedSim - CPU Scheduling Simulator

## 👨‍💻 Authors
* Kaan Aydeniz
* Bartu Batur Sevindik

## 📜 About the Project
SchedSim is a CPU process scheduling simulator written entirely in **GNU Assembly (x86-64, AT&T syntax)**. The program operates at a low level of abstraction, managing memory buffers, register states, and string parsing manually **without using any external C libraries** or standard library functions.

The simulator reads a list of processes and simulates their execution clock cycle by clock cycle, producing a strict execution timeline string.

## ⚙️ Supported Scheduling Algorithms
The program simulates five distinct scheduling algorithms:
* **FCFS (First-Come First-Served):** A non-preemptive algorithm that schedules processes in order of their arrival time.
* **SJF (Shortest Job First):** A non-preemptive algorithm selecting the process with the least total burst time.
* **SRTF (Shortest Remaining Time First):** A preemptive version of SJF that dynamically switches to the process with the least amount of time left to run.
* **PF (Priority First):** A preemptive scheduling algorithm based on a given priority value (lower value indicates higher priority).
* **RR (Round Robin):** A preemptive algorithm that allocates CPU time in fixed slices (quantum) using a custom circular queue.

## ✨ Technical Highlights
* **Pure System Calls:** All input/output operations are handled directly via Linux `syscall` (`sys_read`, `sys_write`, `sys_exit`).
* **Custom Memory Layout:** Instead of parallel arrays, processes are stored in a contiguous 5-byte manual struct format within the `.bss` section (Process ID, Burst Time, Arrival Time, Remaining Time, Priority) to optimize memory traversal.
* **Library-Free Parsing:** The program features a custom ASCII-to-Integer parser that scans the input buffer byte by byte, using pointer arithmetic and register manipulation to extract multi-digit integers and delimiters.
* **Strict Register Management:** Critical state variables are anchored in memory, while specific registers (`%ecx` for loop counting, `%rsi` / `%rdi` for pointer traversal) are strictly scoped to prevent data corruption during complex algorithm loops.

## 🛠️ Build and Execution

The project includes a `Makefile` for compilation using the GNU Assembler (`as`) and Linker (`ld`).

**To build the executable:**
```bash
make
```

**To run the simulator:**
```bash
./schedsim
```

**To test the program with provided cases:**
```bash
make testcases
```

**To clean the build files:**
```bash
make clean
```

## 🎮 Sample Interaction

**Input (FCFS):**
```text
FCFS A-3-1 B-2-2
```

**Output:**
```text
XAAABB
```
*(Explanation: The CPU is idle (X) at cycle 0. Process A arrives at cycle 1 and runs for 3 cycles. Process B arrives at cycle 2 but waits for A to finish, then runs for 2 cycles.)*

## 🗂️ Project Structure
* `src/schedsim.s`: The main Assembly source code containing the parsing logic, clock cycle engine, and algorithm implementations.
* `Makefile`: Automates the build and testing process.
* `test/`: Contains Python grader and checker scripts alongside `.txt` input/output test cases.