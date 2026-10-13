`timescale 1ns / 1ps

// ============================================================================
// Project       : Design and FPGA Implementation of an 8-Bit CPU
// Module        : tb_cpu8
// File Name     : tb_cpu8.v
//
// Description   :
// This testbench verifies the functional behavior of the cpu8 processor.
//
// A testbench is a simulation-only module used to apply input signals to a
// Design Under Test (DUT) and check whether its outputs match expectations.
//
// The testbench generates a clock, applies reset, monitors CPU execution,
// checks instruction results, verifies register and RAM contents, and confirms
// that the processor eventually enters the halted state.
//
// TEST OBJECTIVES:
//   1. Verify synchronous active-high reset.
//   2. Verify LDI: R0 = 10 and R1 = 2.
//   3. Verify ADD: R0 = 10 + 2 = 12.
//   4. Verify first RETURN result = 12.
//   5. Verify SWAP exchanges R0 and R1.
//   6. Verify SUB: R1 = 12 - 2 = 10.
//   7. Verify second RETURN result = 10.
//   8. Verify STA stores 2 at RAM address 0x30.
//   9. Verify LDA loads RAM[0x30] into R1.
//  10. Verify OR: R0 = 2 OR 2 = 2.
//  11. Verify final registers and HALT at PC 10.
//  12. Stop simulation if the CPU fails to halt before the timeout.
//
// SIMULATION TOOL : Xilinx Vivado 2025.2.1
// HDL             : Verilog-2005
// Clock Period    : 10 ns
// Clock Frequency : 100 MHz
// Time Zone       : Pakistan Standard Time (PKT, UTC+05:00)
//
// Developer       : Ghulam Yaseen Nangraj
// Date            : 13 October 2026
//
// IMPORTANT:
// This is a simulation testbench. It is not intended to be synthesized
// into FPGA hardware.
//
// ============================================================================


// ============================================================================
// TESTBENCH MODULE DECLARATION
// ============================================================================

// Declare the testbench module.
//
// Unlike the CPU module, this module has no external input or output ports.
// All stimulus and monitoring signals are generated internally.
module tb_cpu8;


// ============================================================================
// 1. TESTBENCH SIGNAL DECLARATIONS
// ============================================================================
//
// Signals connected to DUT inputs are declared as reg because the testbench
// assigns values to them procedurally.
//
// Signals connected to DUT outputs are declared as wire because their values
// are driven by the instantiated CPU module.


// ---------------------------------------------------------------------------
// INPUT SIGNALS
// ---------------------------------------------------------------------------

// Clock signal supplied to the CPU.
//
// The clock-generation block below toggles this signal every 5 ns.
reg clk;

// Active-high synchronous reset signal.
//
// When reset is high at a rising clock edge, the CPU initializes its state.
reg reset;


// ---------------------------------------------------------------------------
// CPU RESULT AND STATUS OUTPUTS
// ---------------------------------------------------------------------------

// Receives the 8-bit value reported by the CPU's RETURN instruction.
wire [7:0] result;

// Indicates that a new RETURN result is available.
//
// The CPU asserts this signal for one clock cycle when RETURN executes.
wire result_valid;

// Indicates that the CPU has executed the HLT instruction.
wire halted;

// Receives the CPU program counter for execution monitoring.
//
// The testbench uses this output to check the instruction execution sequence.
wire [7:0] pc_debug;


// ---------------------------------------------------------------------------
// GENERAL-PURPOSE REGISTER OUTPUTS
// ---------------------------------------------------------------------------

// Receives the current contents of CPU register R0.
wire [7:0] R0;

// Receives the current contents of CPU register R1.
wire [7:0] R1;


// ============================================================================
// 2. DEVICE UNDER TEST (DUT)
// ============================================================================
//
// DUT means Design Under Test.
//
// Instantiate the cpu8 module so that its behavior can be verified in
// simulation.
//
// The instance name is uut, meaning Unit Under Test.
//
// Named port connections explicitly associate each testbench signal with
// the corresponding CPU module port.

cpu8 uut (

    // Connect the testbench clock to the CPU clock input.
    .clk          (clk),

    // Connect the testbench reset to the CPU reset input.
    .reset        (reset),

    // Observe the CPU result output.
    .result       (result),

    // Observe the CPU result-valid indicator.
    .result_valid (result_valid),

    // Observe the CPU halted status.
    .halted       (halted),

    // Observe the CPU program counter.
    .pc_debug     (pc_debug),

    // Observe the internal R0 register through its debug output.
    .R0           (R0),

    // Observe the internal R1 register through its debug output.
    .R1           (R1)

);


// ============================================================================
// 3. CLOCK GENERATION
// ============================================================================
//
// PURPOSE:
// Generate a continuous clock signal for the CPU.
//
// Clock Period = 10 ns
// Half Period  = 5 ns
// Frequency    = 1 / (10 ns) = 100 MHz
//
// The initial block starts the clock at logic zero.
//
// The forever statement repeatedly waits for 5 ns and inverts the clock.
// This creates a periodic square-wave clock for simulation.

initial begin

    // Initialize the clock to logic zero.
    clk = 1'b0;

    // Toggle the clock every 5 ns for the entire simulation.
    forever #5 clk = ~clk;

end


// ============================================================================
// 4. WAVEFORM DEBUG MONITOR
// ============================================================================
//
// PURPOSE:
// Display important CPU signals in the Vivado simulation console.
//
// The monitor runs on every rising edge of the clock.
//
// The #1 delay allows the CPU's nonblocking assignments to update before
// the displayed register values and status signals are sampled.
//
// This small delay is for simulation observation only; it does not add
// hardware delay to the synthesized CPU.

always @(posedge clk) begin

    // Wait 1 ns after the rising clock edge so sequential updates settle.
    #1;

    // Print the current CPU state in a single readable line.
    $display(

        // Format string:
        // %0t = simulation time.
        // %b  = binary value.
        // %0d = decimal value without unnecessary leading spaces.
        // %h  = hexadecimal value.
        "TIME=%0t | RESET=%b | PC=%0d | INSTR=%h | OPCODE=%h | R0=%0d | R1=%0d | RESULT=%0d | VALID=%b | HALTED=%b",

        // Supply the signal values corresponding to the format fields.
        $time,                  // Current simulation time.
        reset,                  // Current reset status.
        pc_debug,               // Current program counter.
        uut.instruction,        // Instruction fetched by the CPU.
        uut.opcode,             // Decoded instruction opcode.
        R0,                     // Current contents of R0.
        R1,                     // Current contents of R1.
        result,                 // Most recently reported result.
        result_valid,           // Indicates a newly reported result.
        halted                  // Indicates whether execution has stopped.

    );

end


// ============================================================================
// 5. MAIN TEST SEQUENCE
// ============================================================================
//
// PURPOSE:
// Apply reset, allow the CPU to execute its demonstration program, and
// automatically check expected register values, results, RAM contents,
// program-counter values, and the final halted state.
//
// The $fatal system task terminates the simulation with an error when
// a verification condition fails.
//
// The $display system task prints test progress and PASS messages.
//
// The wait statement suspends the testbench process until its expression
// becomes true.

initial begin


    // ========================================================================
    // STEP 1: APPLY SYNCHRONOUS RESET
    // ========================================================================

    // Assert the active-high reset signal.
    reset = 1'b1;

    // Keep reset asserted for 20 ns.
    //
    // With a 10 ns clock period, this spans two rising clock edges:
    // approximately 5 ns and 15 ns.
    //
    // The CPU samples reset at those rising edges and initializes its state.
    #20;

    // Deassert reset so that the CPU can begin executing instructions.
    reset = 1'b0;


    // ------------------------------------------------------------------------
    // DISPLAY TEST START INFORMATION
    // ------------------------------------------------------------------------

    // Print a blank line to separate the test output from previous messages.
    $display("");

    // Print a separator line for readability.
    $display("==================================================");

    // Announce the beginning of the functional verification sequence.
    $display("STARTING 8-BIT CPU FUNCTIONAL TEST");

    // Print the closing separator line.
    $display("==================================================");


    // ========================================================================
    // TEST 1: VERIFY LDI INSTRUCTIONS
    // ========================================================================
    //
    // The program executes:
    //
    // PC 0: LDI R0, 10
    // PC 1: LDI R1, 2
    //
    // Expected register values:
    // R0 = 10
    // R1 = 2
    //
    // The wait statement pauses the test sequence until both conditions
    // are true simultaneously.

    wait ((R0 === 8'd10) && (R1 === 8'd2));

    // Report that both immediate-load operations have passed verification.
    $display("PASS: LDI loaded R0 = 10 and R1 = 2.");


    // ========================================================================
    // TEST 2: VERIFY ADD AND FIRST RETURN
    // ========================================================================
    //
    // The CPU executes:
    //
    // PC 2: ADD R0, R1
    //      R0 = 10 + 2 = 12
    //
    // PC 3: RETURN
    //      result = R0 = 12
    //
    // The result_valid signal identifies the clock cycle in which RETURN
    // reports the result.

    // Wait until the CPU asserts result_valid.
    wait (result_valid === 1'b1);

    // Allow the monitor and sequential updates to settle before checking.
    #1;


    // ------------------------------------------------------------------------
    // CHECK FIRST RETURN RESULT
    // ------------------------------------------------------------------------

    // Compare the reported result against decimal 12.
    //
    // The case inequality operator !== detects mismatches, including
    // unknown X and high-impedance Z values.
    if (result !== 8'd12) begin

        // Stop simulation and report the expected and actual values.
        $fatal(
            1,
            "FAIL: First RETURN expected 12, actual = %0d",
            result
        );

    end
    else begin

        // Report successful verification of ADD and the first RETURN.
        $display("PASS: ADD and first RETURN produced 12.");

    end


    // ------------------------------------------------------------------------
    // CHECK REGISTER VALUES AFTER ADD
    // ------------------------------------------------------------------------

    // Verify that ADD updated R0 without changing R1.
    //
    // Expected:
    // R0 = 12
    // R1 = 2
    if ((R0 !== 8'd12) || (R1 !== 8'd2)) begin

        // Terminate simulation if either register contains an incorrect value.
        $fatal(1, "FAIL: Register values after ADD are incorrect.");

    end


    // ------------------------------------------------------------------------
    // CHECK PROGRAM COUNTER AFTER FIRST RETURN
    // ------------------------------------------------------------------------

    // The first RETURN instruction is stored at PC 3.
    //
    // The CPU increments the program counter when RETURN executes.
    // Therefore, the expected PC value after execution is 4.
    if (pc_debug !== 8'd4) begin

        // Report the expected and actual program-counter values.
        $fatal(
            1,
            "FAIL: Expected PC=4 after first RETURN, actual PC=%0d",
            pc_debug
        );

    end

    // Report successful verification of the program counter.
    $display("PASS: PC advanced to 4 after first RETURN.");


    // ========================================================================
    // TEST 3: VERIFY SWAP, SUB AND SECOND RETURN
    // ========================================================================
    //
    // The CPU executes:
    //
    // PC 4: SWAP R0, R1
    //      R0 = 2
    //      R1 = 12
    //
    // PC 5: SUB R1, R0
    //      R1 = 12 - 2 = 10
    //
    // PC 6: RETURN
    //      result = R1 = 10
    //
    // The testbench first waits for the first result-valid pulse to clear.
    // It then waits for the next RETURN pulse.

    // Wait until result_valid becomes zero after the first RETURN.
    wait (result_valid === 1'b0);

    // Wait for the second RETURN instruction to assert result_valid.
    wait (result_valid === 1'b1);

    // Allow the result and associated sequential updates to settle.
    #1;


    // ------------------------------------------------------------------------
    // CHECK SECOND RETURN RESULT
    // ------------------------------------------------------------------------

    // Verify that the second RETURN instruction reports decimal 10.
    if (result !== 8'd10) begin

        // Stop simulation if the reported result does not match expectation.
        $fatal(
            1,
            "FAIL: Second RETURN expected 10, actual = %0d",
            result
        );

    end
    else begin

        // Report successful SWAP, SUB and second RETURN verification.
        $display("PASS: SWAP, SUB and second RETURN produced 10.");

    end


    // ------------------------------------------------------------------------
    // CHECK REGISTERS AFTER SUB
    // ------------------------------------------------------------------------

    // Verify the expected register values after SWAP and SUB.
    //
    // Expected:
    // R0 = 2
    // R1 = 10
    if ((R0 !== 8'd2) || (R1 !== 8'd10)) begin

        // Terminate simulation if either register is incorrect.
        $fatal(
            1,
            "FAIL: Expected R0=2, R1=10 after SUB."
        );

    end

    // Report successful verification of the register values.
    $display("PASS: Register values after SUB are correct.");


    // ========================================================================
    // TEST 4: WAIT FOR HALT
    // ========================================================================
    //
    // The processor continues with:
    //
    // PC 7: STA 0x30
    // PC 8: LDA R1, 0x30
    // PC 9: OR R0, R1
    // PC 10: HLT
    //
    // The wait statement suspends the test sequence until the CPU asserts
    // its halted output.

    // Wait for the HLT instruction to stop processor execution.
    wait (halted === 1'b1);

    // Allow the resulting state to settle before checking it.
    #1;


    // ------------------------------------------------------------------------
    // CHECK HALT PROGRAM COUNTER
    // ------------------------------------------------------------------------

    // The HLT instruction resides at program address 10.
    //
    // The CPU intentionally does not increment the PC when HLT executes.
    // Therefore, pc_debug must remain at decimal 10.
    if (pc_debug !== 8'd10) begin

        // Report an error if the CPU halted at an unexpected address.
        $fatal(
            1,
            "FAIL: Expected HALT at PC=10, actual PC=%0d",
            pc_debug
        );

    end

    // Report successful verification of the halt address.
    $display("PASS: CPU halted at PC 10.");


    // ========================================================================
    // TEST 5: VERIFY FINAL REGISTER VALUES
    // ========================================================================
    //
    // The final instructions perform these operations:
    //
    // STA 0x30:
    //   RAM[0x30] = R0 = 2
    //
    // LDA R1, 0x30:
    //   R1 = RAM[0x30] = 2
    //
    // OR R0, R1:
    //   R0 = 2 OR 2 = 2
    //
    // Expected final register values:
    // R0 = 2
    // R1 = 2

    // Check both registers using case inequality.
    if ((R0 !== 8'd2) || (R1 !== 8'd2)) begin

        // Report expected and actual register values if verification fails.
        $fatal(
            1,
            "FAIL: Expected final R0=2, R1=2; actual R0=%0d, R1=%0d",
            R0,
            R1
        );

    end

    // Report successful verification of the final registers.
    $display("PASS: Final registers are R0=2 and R1=2.");


    // ========================================================================
    // TEST 6: VERIFY DATA RAM
    // ========================================================================
    //
    // The testbench accesses the internal RAM hierarchically through uut.
    //
    // uut.data_ram[8'h30] refers to memory address 0x30 inside the instantiated
    // cpu8 module.
    //
    // This type of hierarchical access is useful in simulation but is not
    // a physical external interface of the synthesized processor.

    // Verify that STA stored decimal 2 at RAM address 0x30.
    if (uut.data_ram[8'h30] !== 8'd2) begin

        // Report the expected and actual memory contents if they differ.
        $fatal(
            1,
            "FAIL: RAM[30H] expected 2, actual = %0d",
            uut.data_ram[8'h30]
        );

    end

    // Report successful verification of the STA instruction.
    $display("PASS: STA stored 2 at RAM address 30H.");

    // Report that the final register check also confirms the expected
    // value loaded into R1 by the LDA instruction.
    $display("PASS: LDA loaded RAM[30H] into R1.");


    // ========================================================================
    // TEST 7: VERIFY HALT STATUS AND PRINT FINAL REPORT
    // ========================================================================

    // Confirm that the halted output is definitely logic one.
    if (halted !== 1'b1) begin

        // Stop simulation if the processor is not halted.
        $fatal(1, "FAIL: CPU did not assert halted.");

    end


    // ------------------------------------------------------------------------
    // PRINT FINAL TEST SUMMARY
    // ------------------------------------------------------------------------

    // Print a blank line before the summary.
    $display("");

    // Print the summary header.
    $display("==================================================");

    // Report that all programmed verification checks completed successfully.
    $display("ALL CPU TESTS PASSED");

    // Print the summary separator.
    $display("==================================================");

    // Report the expected first RETURN result.
    $display("First RETURN result  : %0d", 8'd12);

    // Report the expected second RETURN result.
    $display("Second RETURN result : %0d", 8'd10);

    // Report the actual RAM contents at address 0x30.
    $display("RAM[30H]             : %0d", uut.data_ram[8'h30]);

    // Report the actual final value of R0.
    $display("Final R0             : %0d", R0);

    // Report the actual final value of R1.
    $display("Final R1             : %0d", R1);

    // Report the final program counter.
    $display("Final PC             : %0d", pc_debug);

    // Report the final halt status.
    $display("CPU halted           : %b", halted);
 
    // Print the closing separator.
    $display("==================================================");


    // ------------------------------------------------------------------------
    // END SIMULATION
    // ------------------------------------------------------------------------

    // Terminate the simulation normally after all checks pass.
    $finish;

end


// ============================================================================
// 6. SIMULATION TIMEOUT
// ============================================================================
//
// PURPOSE:
// Prevent the simulation from running indefinitely if the CPU never reaches
// its expected halted state.
//
// The timeout is set to 2000 ns.
//
// At a 100 MHz clock frequency, 2000 ns corresponds to 200 clock periods.
//
// If the CPU has not halted by the timeout, $fatal terminates the simulation
// and reports the current program counter.
//
// If the CPU has already halted, this block does not issue an error.

initial begin

    // Wait until the maximum allowed simulation time has elapsed.
    #2000;

    // Check whether the CPU reached the expected halted state.
    if (halted !== 1'b1) begin

        // Terminate simulation and display the program counter at timeout.
        $fatal(
            1,
            "TIMEOUT: CPU failed to halt. Current PC=%0d",
            pc_debug
        );

    end

end


// ============================================================================
// END OF TESTBENCH MODULE
// ============================================================================

endmodule

// ============================================================================
// END OF FILE: tb_cpu8.v
// ============================================================================