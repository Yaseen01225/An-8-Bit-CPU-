# 8-Bit CPU — Functionality and Simulation README

**Developer:** Ghulam Yaseen Nangraj  
**HDL:** Verilog-2005  
**Simulation Tool:** Xilinx Vivado 2025.2.1  
**Clock:** 100 MHz (10 ns period)  
**Date:** 13 October 2026  

## 1. Project Overview

This project demonstrates the functional verification of an educational 8-bit CPU using a Verilog testbench. The supplied file, `tb_cpu8.v`, creates a clock, applies reset, monitors processor activity, checks instruction results and register/memory values, and confirms that the CPU reaches its halted state.

> **Important:** `tb_cpu8.v` is a simulation-only testbench. It requires the CPU design module `cpu8` (normally in `cpu8.v`) to be added to the Vivado project. The CPU implementation source was not included with the supplied file, so the instruction behavior below is documented from the test sequence in the testbench.

## 2. Main Testbench Signals

| Signal | Width | Purpose |
|---|---:|---|
| `clk` | 1 bit | CPU clock, toggles every 5 ns |
| `reset` | 1 bit | Active-high synchronous reset |
| `result` | 8 bits | Value reported by a `RETURN` instruction |
| `result_valid` | 1 bit | Indicates a valid return result for one clock cycle |
| `halted` | 1 bit | Indicates that the CPU has executed `HLT` |
| `pc_debug` | 8 bits | Program counter exposed for debugging |
| `R0`, `R1` | 8 bits each | General-purpose register values monitored by the testbench |

The testbench instantiates `cpu8` as `uut` (Unit Under Test) and connects these signals to its ports.

## 3. Clock and Reset

- The clock starts at `0` and changes state every `5 ns`.
- The full clock period is `10 ns`, corresponding to `100 MHz`.
- The testbench asserts `reset = 1` for `20 ns`, then deasserts it to start program execution.
- The CPU is expected to sample the synchronous reset on rising clock edges.

## 4. Demonstration Program and Expected Behavior

The testbench expects the CPU's demonstration program to execute the following sequence:

| Program Counter (PC) | Instruction | Expected effect |
|---:|---|---|
| 0 | `LDI R0, 10` | Load decimal 10 into `R0` |
| 1 | `LDI R1, 2` | Load decimal 2 into `R1` |
| 2 | `ADD R0, R1` | `R0 = 10 + 2 = 12` |
| 3 | `RETURN` | Report result `12`; PC advances to 4 |
| 4 | `SWAP R0, R1` | Exchange the values: `R0 = 2`, `R1 = 12` |
| 5 | `SUB R1, R0` | `R1 = 12 - 2 = 10` |
| 6 | `RETURN` | Report result `10` |
| 7 | `STA 0x30` | Store `R0` (value `2`) at RAM address `0x30` |
| 8 | `LDA R1, 0x30` | Load `RAM[0x30]` into `R1`, so `R1 = 2` |
| 9 | `OR R0, R1` | `R0 = 2 OR 2 = 2` |
| 10 | `HLT` | Stop CPU execution; PC is expected to remain at 10 |

The exact instruction encoding and implementation details must be confirmed in `cpu8.v`.

## 5. Verification Checks

The testbench automatically checks:

1. `LDI` loads `R0 = 10` and `R1 = 2`.
2. The first `RETURN` reports `12` after `ADD`.
3. After `ADD`, `R0 = 12` and `R1 = 2`.
4. The program counter advances to `4` after the first `RETURN`.
5. The second `RETURN` reports `10` after `SWAP` and `SUB`.
6. After `SUB`, `R0 = 2` and `R1 = 10`.
7. The CPU eventually asserts `halted`.
8. The CPU halts at `PC = 10`.
9. Final register values are `R0 = 2` and `R1 = 2`.
10. `RAM[0x30] = 2`, verifying the store operation; the final `R1` check also supports the expected load result.
11. The CPU has halted before the `2000 ns` timeout.

The testbench uses `$display` to show progress and signal values. It uses `$fatal` to stop the simulation when a checked condition fails, and `$finish` when all checks pass.

## 6. Simulation Console Output

At every rising clock edge, the testbench prints a monitoring line containing:

- Simulation time and reset state
- Program counter
- Current instruction and opcode
- `R0` and `R1`
- Most recent result
- `result_valid`
- `halted`

After successful verification, the console should display `ALL CPU TESTS PASSED` and the final result, register, RAM, PC, and halt values. If the CPU does not halt in time, the testbench reports a timeout with the current PC.

## 7. How to Run in Vivado

1. Open **Xilinx Vivado 2025.2.1**.
2. Create or open the CPU project.
3. Add the CPU design source, normally `cpu8.v`.
4. Add `tb_cpu8.v` as a simulation source.
5. Set `tb_cpu8` as the simulation top module.
6. Run **Run Simulation → Run Behavioral Simulation**.
7. Review the waveform and Tcl Console messages.
8. Confirm that the console reports `ALL CPU TESTS PASSED`.

If Vivado reports that `cpu8` is undefined or cannot be elaborated, check that the CPU source is included and that its module name and port names match the testbench.

## 8. Expected Final State

After the program completes:

| Item | Expected value |
|---|---:|
| First `RETURN` result | 12 (`0x0C`) |
| Second `RETURN` result | 10 (`0x0A`) |
| `RAM[0x30]` | 2 (`0x02`) |
| Final `R0` | 2 (`0x02`) |
| Final `R1` | 2 (`0x02`) |
| Final PC | 10 (`0x0A`) |
| `halted` | 1 |

## 9. Notes and Limitations

- This README describes the supplied testbench, not the complete internal CPU architecture.
- The CPU design source (`cpu8.v`) is required to run the simulation but was not part of the supplied upload.
- The testbench accesses `uut.instruction`, `uut.opcode`, and `uut.data_ram[8'h30]` hierarchically. These names must exist in the CPU module as written, or the testbench must be updated to match the design.
- The testbench is for simulation and should not be selected as the synthesizable FPGA top module.
- Passing this test sequence demonstrates the checked behaviors; it does not prove every possible input or instruction case.

## 10. Project Purpose

The purpose of this project is to learn how a simple processor fetches and executes instructions, updates registers, performs arithmetic and logical operations, accesses data memory, reports results, and halts. The testbench provides repeatable checks so that expected behavior can be compared with actual simulation behavior before hardware implementation.
