# Simple CPU (TinyRV32)

## How it works

This is a clocked, fixed-program Tiny Tapeout demo using a subset of RISC-V integer ALU encodings. It is not a general-purpose or RV32I-compliant processor. It has no branches, jumps, data memory, or external instruction-loading interface.

A five-bit word counter fetches one 32-bit instruction per enabled rising edge from a 32-word ROM. The 32-bit ALU implements ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT and SLTU, plus the corresponding supported immediate forms (ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI and SLTIU). Only x1, x2 and x8 are full-width operand registers and are loaded using ADDI from x0. The other nonzero x0–x15 selections are write-only, 8-bit result slots for the demo. x0 always reads zero. Unsupported instructions do not write state.

## How to test

1. Assert active-low reset (`rst_n = 0`) through a rising clock edge, then release it. Reset clears the word counter and all results, even with `ena = 0`.
2. Set `ena = 1` and clock the design. Start counting at the first enabled rising edge after reset. ROM word 0 is a NOP.
3. After 16 enabled rising edges, select a result using `ui_in[3:0]`. For example, select 3 for 15 on `uo_out`, or 14 for 80. The first 16 results for x0–x15 are 0, 5, 10, 15, 5, 0, 15, 15, 20, 1, 0, 27, 23, 4, 80, 5.
4. The second half of the ROM reuses some result slots to demonstrate signed and unsigned comparisons, sign extension and shifts. The program repeats after 32 enabled cycles. Set `ena = 0` to pause at any point while reading results.

The cocotb test reads the same public pins used on hardware. It checks the two program phases, reset, enable stalls, ROM wraparound, a discarded write to x0 and an unsupported encoding. The pin interface exposes the low byte only.

## External hardware

Use the Tiny Tapeout clock, reset and enable signals, four digital inputs to select x0–x15, and eight digital outputs to read the selected byte. The other dedicated inputs and all bidirectional pins are unused.
