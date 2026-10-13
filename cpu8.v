
`timescale 1ns / 1ps

// ============================================================================
// Project       : Design and FPGA Implementation of an 8-Bit CPU
// Module        : cpu8
// File Name     : cpu8.v
//
// Description   :
// This module implements a simple educational 8-bit Central Processing Unit
// (CPU) using synthesizable Verilog HDL constructs.
//
// Main Features:
//   1. 8-bit data processing capability.
//   2. 16-bit instruction format.
//   3. 16-word program ROM containing machine instructions.
//   4. Two 8-bit general-purpose registers: R0 and R1.
//   5. 256-byte data RAM for storing program data.
//   6. Arithmetic operations: ADD and SUB.
//   7. Logical operations: AND and OR.
//   8. Data transfer operations: LDI, LDA, STA, and SWAP.
//   9. RETURN instruction for reporting a register value.
//  10. HLT instruction for stopping processor execution.
//  11. Debug outputs for the program counter and general-purpose registers.
//
// Supported Instructions:
//   LDI    : Load an 8-bit immediate value into a register.
//   ADD    : Add two register values.
//   SUB    : Subtract one register value from another.
//   AND    : Perform a bitwise AND operation.
//   OR     : Perform a bitwise OR operation.
//   LDA    : Load data from RAM into a register.
//   STA    : Store the contents of R0 into RAM.
//   SWAP   : Exchange the contents of R0 and R1.
//   RETURN : Report the contents of the selected register.
//   HLT    : Halt instruction execution.
//
// Instruction Format:
//   Bits [15:12] : 4-bit operation code (opcode).
//   Bits [11:10] : 2-bit destination register field (rd).
//   Bits [9:8]   : 2-bit source register field (rs).
//   Bits [7:0]   : 8-bit immediate value or RAM address.
//
// Register Encoding:
//   2'b00 : R0
//   2'b01 : R1
//   2'b10 : Invalid register encoding.
//   2'b11 : Invalid register encoding.
//
// FPGA Target   : Artix-7 XC7A100T-CSG324-1
// Development Tool: Xilinx Vivado 2025.2.1
// HDL Version   : Verilog-2005
// Developer     : Ghulam Yaseen Nangraj
// Date          : 13 October 2026
//
// Educational Purpose:
//   To demonstrate instruction fetching, instruction decoding, register
//   operations, memory access, program-counter control, synchronous reset,
//   and sequential execution in a basic CPU architecture.
//
// ============================================================================


// ============================================================================
// MODULE DECLARATION
// ============================================================================

module cpu8 (

    // ------------------------------------------------------------------------
    // INPUT SIGNALS
    // ------------------------------------------------------------------------

    input wire clk,       // System clock; CPU state changes on its rising edge.
    input wire reset,     // Active-high synchronous reset; resets CPU state.

    // ------------------------------------------------------------------------
    // OUTPUT SIGNALS
    // ------------------------------------------------------------------------

    output reg [7:0] result,       // Holds the most recently returned 8-bit value.
    output reg result_valid,       // One-clock-cycle pulse indicating valid result.
    output reg halted,             // Becomes 1 when the HLT instruction executes.
    output reg [7:0] pc_debug,     // Exposes the program counter for debugging.

    output wire [7:0] R0,          // Debug output showing the contents of R0.
    output wire [7:0] R1           // Debug output showing the contents of R1.

);


// ============================================================================
// 1. INTERNAL REGISTERS AND MEMORY
// ============================================================================

// Create two 8-bit general-purpose registers.
//
// regs[0] represents R0.
// regs[1] represents R1.
//
// These registers store operands and intermediate calculation results.
//
// The array contains two entries, each 8 bits wide.
reg [7:0] regs [0:1];


// Remember which register should supply the next RETURN result.
//
// last_rd = 0 selects R0.
// last_rd = 1 selects R1.
//
// This is a one-bit register because the CPU has two general-purpose registers.
reg last_rd;


// ---------------------------------------------------------------------------
// INSTRUCTION REGISTER AND DECODED FIELDS
// ---------------------------------------------------------------------------

// Holds the complete 16-bit instruction fetched from program ROM.
reg [15:0] instruction;

// Holds the upper four instruction bits that identify the operation to execute.
reg [3:0] opcode;

// Holds the two-bit destination register encoding.
reg [1:0] rd;

// Holds the two-bit source register encoding.
reg [1:0] rs;

// Holds the lower eight instruction bits.
//
// Depending on the opcode, these bits represent an immediate value or
// an address in data RAM.
reg [7:0] immediate;


// ---------------------------------------------------------------------------
// PROGRAM ROM
// ---------------------------------------------------------------------------

// Declare a program memory containing 16 instructions.
//
// Each instruction is 16 bits wide.
//
// Valid array indices are 0 through 15.
//
// The initial block below loads the demonstration program into this ROM.
reg [15:0] program_rom [0:15];


// ---------------------------------------------------------------------------
// DATA RAM
// ---------------------------------------------------------------------------

// Declare a data memory containing 256 bytes.
//
// Each memory location stores one 8-bit value.
//
// Valid addresses range from 0x00 through 0xFF.
//
// The LDA and STA instructions use this memory.
reg [7:0] data_ram [0:255];


// ---------------------------------------------------------------------------
// DEBUG OUTPUT CONNECTIONS
// ---------------------------------------------------------------------------

// Connect the internal R0 register to the external R0 output.
//
// The output allows the register value to be observed in simulation,
// an FPGA logic analyzer, or external display logic.
assign R0 = regs[0];


// Connect the internal R1 register to the external R1 output.
assign R1 = regs[1];


// ============================================================================
// 2. PROGRAM ROM INITIALIZATION
// ============================================================================
//
// The following instructions form a demonstration program.
//
// PC   Machine Code   Instruction       Expected Operation
// ---------------------------------------------------------------------------
//  0   16'h100A       LDI R0, 10        R0 = 10
//  1   16'h1402       LDI R1, 2         R1 = 2
//  2   16'h2100       ADD R0, R1        R0 = 10 + 2 = 12
//  3   16'hC000       RETURN            result = R0 = 12
//  4   16'hA100       SWAP R0, R1       R0 = 2, R1 = 12
//  5   16'h3400       SUB R1, R0        R1 = 12 - 2 = 10
//  6   16'hC000       RETURN            result = R1 = 10
//  7   16'h9030       STA 0x30          RAM[0x30] = R0 = 2
//  8   16'h8430       LDA R1, 0x30      R1 = RAM[0x30] = 2
//  9   16'h5100       OR R0, R1         R0 = 2 OR 2 = 2
// 10   16'hF000       HLT               Stop instruction execution
//
// NOTE:
// The program counter is exposed through pc_debug. Only its lowest four
// bits select a program ROM entry. Consequently, the ROM address wraps
// around after every 16 instruction locations.
//
// ---------------------------------------------------------------------------


// Declare an integer variable for use in procedural initialization or loops.
//
// This variable is not required by the current program because every ROM
// location is initialized explicitly below.
integer i;


// Execute the initialization block at simulation startup.
//
// FPGA synthesis tools can support initial memory values for suitable
// FPGA memory resources, including inferred ROM or RAM, depending on the
// target device and synthesis implementation.
initial begin

    // PC 0: Load decimal 10 into R0.
    // Machine code: opcode 1, destination R0, immediate value 10.
    program_rom[0]  = 16'h100A;

    // PC 1: Load decimal 2 into R1.
    // Machine code: opcode 1, destination R1, immediate value 2.
    program_rom[1]  = 16'h1402;

    // PC 2: Add R1 to R0 and store the result in R0.
    // Expected result: R0 = 10 + 2 = 12.
    program_rom[2]  = 16'h2100;

    // PC 3: Report the contents of the register selected by last_rd.
    // At this point, last_rd selects R0.
    program_rom[3]  = 16'hC000;

    // PC 4: Exchange the contents of R0 and R1.
    // Expected result: R0 = 2 and R1 = 12.
    program_rom[4]  = 16'hA100;

    // PC 5: Subtract R0 from R1 and store the result in R1.
    // Expected result: R1 = 12 - 2 = 10.
    program_rom[5]  = 16'h3400;

    // PC 6: Report the contents of the register selected by last_rd.
    // The SUB instruction selects R1, so the reported value is 10.
    program_rom[6]  = 16'hC000;

    // PC 7: Store the contents of R0 at RAM address 0x30.
    // After SWAP, R0 contains decimal 2.
    program_rom[7]  = 16'h9030;

    // PC 8: Load RAM address 0x30 into R1.
    // R1 receives the value previously stored at that address.
    program_rom[8]  = 16'h8430;

    // PC 9: Perform a bitwise OR between R0 and R1.
    // Expected result: R0 = 2 OR 2 = 2.
    program_rom[9]  = 16'h5100;

    // PC 10: Halt the CPU.
    program_rom[10] = 16'hF000;

    // Initialize unused ROM locations with HLT instructions.
    // This prevents unintended execution of uninitialized ROM entries.
    program_rom[11] = 16'hF000;
    program_rom[12] = 16'hF000;
    program_rom[13] = 16'hF000;
    program_rom[14] = 16'hF000;
    program_rom[15] = 16'hF000;

end


// ============================================================================
// 3. INSTRUCTION FETCH AND DECODING
// ============================================================================
//
// This combinational block fetches the instruction addressed by the program
// counter and separates the instruction into its individual fields.
//
// Combinational logic responds to input changes without waiting for a clock.
//
// The CPU uses pc_debug[3:0] as the ROM address because the ROM contains
// exactly 16 instruction locations.

always @(*) begin

    // FETCH:
    // Read the 16-bit instruction stored at the current ROM address.
    instruction = program_rom[pc_debug[3:0]];


    // DECODE:
    // Extract the four-bit opcode from instruction bits [15:12].
    opcode = instruction[15:12];


    // Extract the destination register field from bits [11:10].
    rd = instruction[11:10];


    // Extract the source register field from bits [9:8].
    rs = instruction[9:8];


    // Extract the lower eight bits.
    // These bits are interpreted according to the decoded opcode.
    immediate = instruction[7:0];

end


// ============================================================================
// 4. INSTRUCTION EXECUTION
// ============================================================================
//
// The CPU executes one instruction on each rising edge of the clock.
//
// This is a sequential logic block because its state changes are triggered
// by the positive edge of clk.
//
// Nonblocking assignments (<=) are used for sequential state updates.
//
// RESET BEHAVIOR:
//   reset = 1: Initialize the CPU state.
//   reset = 0: Execute instructions unless the CPU is halted.
//
// IMPORTANT:
// The reset is synchronous because it is checked only inside
// always @(posedge clk).

always @(posedge clk) begin

    // ========================================================================
    // 4.1 SYNCHRONOUS RESET
    // ========================================================================

    if (reset) begin

        // Restart program execution at ROM address zero.
        pc_debug <= 8'd0;

        // Clear the reported result.
        result <= 8'd0;

        // Indicate that no new result is being reported.
        result_valid <= 1'b0;

        // Release the halted state so the CPU can execute after reset.
        halted <= 1'b0;

        // Initialize general-purpose register R0.
        regs[0] <= 8'd0;

        // Initialize general-purpose register R1.
        regs[1] <= 8'd0;

        // Select R0 as the initial RETURN source.
        last_rd <= 1'b0;

    end


    // ========================================================================
    // 4.2 NORMAL INSTRUCTION EXECUTION
    // ========================================================================
    //
    // Execute an instruction only when reset is inactive and halted is zero.
    // Once halted becomes one, the CPU stops fetching new instructions.

    else if (!halted) begin

        // Clear the result-valid flag at the beginning of each active cycle.
        //
        // A RETURN instruction sets it to one later in this block.
        // This creates a one-clock-cycle result notification pulse.
        result_valid <= 1'b0;


        // Select the instruction operation using the decoded opcode.
        case (opcode)


            // =================================================================
            // OPCODE 1: LDI - LOAD IMMEDIATE
            // =================================================================
            //
            // PURPOSE:
            // Load an 8-bit constant directly into a general-purpose register.
            //
            // OPERATION:
            // regs[rd] = immediate
            //
            // EXAMPLE:
            // LDI R0, 10
            // R0 = 8'd10

            4'h1: begin

                // Accept only valid register indices: 0 and 1.
                if (rd < 2) begin

                    // Load the immediate value into the selected register.
                    regs[rd] <= immediate;

                    // Remember the destination register for RETURN.
                    last_rd <= rd[0];

                end

                // Advance to the next instruction.
                pc_debug <= pc_debug + 8'd1;

            end


            // =================================================================
            // OPCODE 2: ADD - REGISTER ADDITION
            // =================================================================
            //
            // PURPOSE:
            // Add the source register to the destination register.
            //
            // OPERATION:
            // regs[rd] = regs[rd] + regs[rs]
            //
            // EXAMPLE:
            // ADD R0, R1
            // R0 = R0 + R1
            //
            // The result is 8 bits wide. Any carry beyond bit 7 is discarded.

            4'h2: begin

                // Ensure both register fields refer to R0 or R1.
                if ((rd < 2) && (rs < 2)) begin

                    // Add the two register values and store the result.
                    regs[rd] <= regs[rd] + regs[rs];

                    // Remember the destination register for RETURN.
                    last_rd <= rd[0];

                end

                // Advance the program counter.
                pc_debug <= pc_debug + 8'd1;

            end


            // =================================================================
            // OPCODE 3: SUB - REGISTER SUBTRACTION
            // =================================================================
            //
            // PURPOSE:
            // Subtract the source register from the destination register.
            //
            // OPERATION:
            // regs[rd] = regs[rd] - regs[rs]
            //
            // EXAMPLE:
            // SUB R1, R0
            // R1 = R1 - R0
            //
            // Arithmetic uses 8-bit results. Underflow wraps modulo 256.

            4'h3: begin

                // Check that both register fields are valid.
                if ((rd < 2) && (rs < 2)) begin

                    // Subtract the source value from the destination value.
                    regs[rd] <= regs[rd] - regs[rs];

                    // Remember the destination register for RETURN.
                    last_rd <= rd[0];

                end

                // Advance to the next instruction.
                pc_debug <= pc_debug + 8'd1;

            end


            // =================================================================
            // OPCODE 4: AND - BITWISE LOGICAL AND
            // =================================================================
            //
            // PURPOSE:
            // Perform a bit-by-bit AND operation between two registers.
            //
            // OPERATION:
            // regs[rd] = regs[rd] & regs[rs]
            //
            // A result bit is one only when both corresponding operand bits
            // are one.

            4'h4: begin

                // Confirm that the destination and source registers are valid.
                if ((rd < 2) && (rs < 2)) begin

                    // Apply the bitwise AND operator.
                    regs[rd] <= regs[rd] & regs[rs];

                    // Remember the destination register for RETURN.
                    last_rd <= rd[0];

                end

                // Advance to the next instruction.
                pc_debug <= pc_debug + 8'd1;

            end


            // =================================================================
            // OPCODE 5: OR - BITWISE LOGICAL OR
            // =================================================================
            //
            // PURPOSE:
            // Perform a bit-by-bit OR operation between two registers.
            //
            // OPERATION:
            // regs[rd] = regs[rd] | regs[rs]
            //
            // A result bit is one when either corresponding operand bit is one.
            //
            // EXAMPLE:
            // 00000010 OR 00000010 = 00000010

            4'h5: begin

                // Confirm that the destination and source registers are valid.
                if ((rd < 2) && (rs < 2)) begin

                    // Apply the bitwise OR operator.
                    regs[rd] <= regs[rd] | regs[rs];

                    // Remember the destination register for RETURN.
                    last_rd <= rd[0];

                end

                // Advance to the next instruction.
                pc_debug <= pc_debug + 8'd1;

            end


            // =================================================================
            // OPCODE 8: LDA - LOAD FROM DATA RAM
            // =================================================================
            //
            // PURPOSE:
            // Read one byte from data RAM and place it in a register.
            //
            // OPERATION:
            // regs[rd] = data_ram[immediate]
            //
            // EXAMPLE:
            // LDA R1, 0x30
            // R1 = data_ram[8'h30]
            //
            // The immediate field supplies the 8-bit memory address.

            4'h8: begin

                // Ensure the destination register is valid.
                if (rd < 2) begin

                    // Read the addressed RAM byte into the destination register.
                    regs[rd] <= data_ram[immediate];

                    // Remember the destination register for RETURN.
                    last_rd <= rd[0];

                end

                // Advance the program counter.
                pc_debug <= pc_debug + 8'd1;

            end


            // =================================================================
            // OPCODE 9: STA - STORE R0 INTO DATA RAM
            // =================================================================
            //
            // PURPOSE:
            // Write the contents of R0 into the selected RAM location.
            //
            // OPERATION:
            // data_ram[immediate] = regs[0]
            //
            // EXAMPLE:
            // STA 0x30
            // data_ram[8'h30] = R0
            //
            // This instruction always stores R0; it does not use rd.

            4'h9: begin

                // Write the current value of R0 to the addressed RAM location.
                data_ram[immediate] <= regs[0];

                // Advance the program counter.
                pc_debug <= pc_debug + 8'd1;

            end


            // =================================================================
            // OPCODE A: SWAP - EXCHANGE R0 AND R1
            // =================================================================
            //
            // PURPOSE:
            // Exchange the values stored in R0 and R1.
            //
            // OPERATION:
            // R0 = old R1
            // R1 = old R0
            //
            // Nonblocking assignments evaluate their right-hand sides using
            // the values present before the current clock edge.
            //
            // Therefore, both original register values are exchanged correctly.

            4'hA: begin

                // Copy the original R1 value into R0.
                regs[0] <= regs[1];

                // Copy the original R0 value into R1.
                regs[1] <= regs[0];

                // By convention, select R0 as the RETURN source after SWAP.
                last_rd <= 1'b0;

                // Advance to the next instruction.
                pc_debug <= pc_debug + 8'd1;

            end


            // =================================================================
            // OPCODE C: RETURN - REPORT A REGISTER VALUE
            // =================================================================
            //
            // PURPOSE:
            // Copy the selected register value to the result output.
            //
            // OPERATION:
            // result = regs[last_rd]
            //
            // last_rd = 0 selects R0.
            // last_rd = 1 selects R1.
            //
            // result_valid indicates that the output contains a newly
            // reported result for the current clock cycle.

            4'hC: begin

                // Copy the selected register value to the output register.
                result <= regs[last_rd];

                // Assert the result-valid flag for one clock cycle.
                result_valid <= 1'b1;

                // Advance to the instruction following RETURN.
                pc_debug <= pc_debug + 8'd1;

            end


            // =================================================================
            // OPCODE F: HLT - HALT PROCESSOR
            // =================================================================
            //
            // PURPOSE:
            // Stop instruction execution.
            //
            // When halted becomes one, the normal execution condition
            // (else if (!halted)) is no longer satisfied.
            //
            // The program counter is not updated here, so it remains at
            // the address containing the HLT instruction.

            4'hF: begin

                // Set the halted flag to stop further instruction execution.
                halted <= 1'b1;

            end


            // =================================================================
            // DEFAULT: INVALID OR UNSUPPORTED OPCODE
            // =================================================================
            //
            // PURPOSE:
            // Skip an unsupported instruction and continue program execution.
            //
            // This prevents an unknown opcode from permanently blocking the
            // processor at the same ROM location.

            default: begin

                // Move to the next instruction.
                pc_debug <= pc_debug + 8'd1;

            end

        endcase

    end


    // ========================================================================
    // 4.3 HALTED STATE
    // ========================================================================
    //
    // This branch executes when halted is already one and reset is inactive.
    //
    // No register, memory, or program-counter updates are requested here.
    // Consequently, their values remain unchanged.
    //
    // The result-valid signal is explicitly cleared so it does not remain
    // asserted after the processor stops.

    else begin

        // Indicate that no new RETURN result is being reported.
        result_valid <= 1'b0;

    end

end


// ============================================================================
// END OF MODULE
// ============================================================================

endmodule

// ============================================================================
// END OF FILE: cpu8.v
// ============================================================================