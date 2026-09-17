import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def clock_cycle(dut):
    """Wait for a complete clock edge and allow sequential logic to settle."""
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")


async def read_register(dut, register_number):
    """Select a register through ui_in and read its low 8 bits."""
    dut.ui_in.value = register_number
    await Timer(1, unit="ns")
    return int(dut.uo_out.value)


@cocotb.test()
async def test_tinyrv32(dut):

    dut._log.info("Starting TinyRV32 extended ALU test")

    # ============================================================
    # START CLOCK
    # ============================================================

    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # ============================================================
    # INITIAL INPUTS
    # ============================================================

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # ============================================================
    # RESET
    # ============================================================

    dut.rst_n.value = 0

    await clock_cycle(dut)
    await clock_cycle(dut)

    dut.rst_n.value = 1

    # ============================================================
    # BASIC ALU INSTRUCTIONS
    # ============================================================

    # 0: NOP
    await clock_cycle(dut)

    # 1: ADDI x1, x0, 5
    await clock_cycle(dut)
    x1 = await read_register(dut, 1)
    assert x1 == 5, f"ADDI x1 failed: expected 5, got {x1}"

    # 2: ADDI x2, x0, 10
    await clock_cycle(dut)
    x2 = await read_register(dut, 2)
    assert x2 == 10, f"ADDI x2 failed: expected 10, got {x2}"

    # 3: ADD x3, x1, x2
    await clock_cycle(dut)
    x3 = await read_register(dut, 3)
    assert x3 == 15, f"ADD failed: expected 15, got {x3}"

    # 4: SUB x4, x2, x1
    await clock_cycle(dut)
    x4 = await read_register(dut, 4)
    assert x4 == 5, f"SUB failed: expected 5, got {x4}"

    # 5: AND x5, x1, x2
    await clock_cycle(dut)
    x5 = await read_register(dut, 5)
    assert x5 == (5 & 10), f"AND failed: expected {5 & 10}, got {x5}"

    # 6: OR x6, x1, x2
    await clock_cycle(dut)
    x6 = await read_register(dut, 6)
    assert x6 == (5 | 10), f"OR failed: expected {5 | 10}, got {x6}"

    # 7: XOR x7, x1, x2
    await clock_cycle(dut)
    x7 = await read_register(dut, 7)
    assert x7 == (5 ^ 10), f"XOR failed: expected {5 ^ 10}, got {x7}"

    # ============================================================
    # EXTENDED IMMEDIATE INSTRUCTIONS
    # ============================================================

    # 8: ADDI x8, x0, 20
    await clock_cycle(dut)
    x8 = await read_register(dut, 8)
    assert x8 == 20, f"ADDI x8 failed: expected 20, got {x8}"

    # 9: SLTI x9, x8, 30
    await clock_cycle(dut)
    x9 = await read_register(dut, 9)
    assert x9 == 1, f"SLTI x9 failed: expected 1, got {x9}"

    # 10: SLTIU x10, x8, 10
    await clock_cycle(dut)
    x10 = await read_register(dut, 10)
    assert x10 == 0, f"SLTIU x10 failed: expected 0, got {x10}"

    # 11: XORI x11, x8, 15
    await clock_cycle(dut)
    x11 = await read_register(dut, 11)
    assert x11 == 27, f"XORI x11 failed: expected 27, got {x11}"

    # 12: ORI x12, x8, 3
    await clock_cycle(dut)
    x12 = await read_register(dut, 12)
    assert x12 == 23, f"ORI x12 failed: expected 23, got {x12}"

    # 13: ANDI x13, x8, 7
    await clock_cycle(dut)
    x13 = await read_register(dut, 13)
    assert x13 == 4, f"ANDI x13 failed: expected 4, got {x13}"

    # 14: SLLI x14, x8, 2
    await clock_cycle(dut)
    x14 = await read_register(dut, 14)
    assert x14 == 80, f"SLLI x14 failed: expected 80, got {x14}"

    # 15: SRLI x15, x8, 2
    await clock_cycle(dut)
    x15 = await read_register(dut, 15)
    assert x15 == 5, f"SRLI x15 failed: expected 5, got {x15}"

    # ============================================================
    # CHECK x0
    # ============================================================

    x0 = await read_register(dut, 0)
    assert x0 == 0, f"x0 is not zero: got {x0}"

    # ============================================================
    # FINAL LOG
    # ============================================================

    dut._log.info("TinyRV32 extended ALU test passed!")
    dut._log.info("x0  = %d", x0)
    dut._log.info("x1  = %d", x1)
    dut._log.info("x2  = %d", x2)
    dut._log.info("x3  = %d", x3)
    dut._log.info("x4  = %d", x4)
    dut._log.info("x5  = %d", x5)
    dut._log.info("x6  = %d", x6)
    dut._log.info("x7  = %d", x7)
    dut._log.info("x8  = %d", x8)
    dut._log.info("x9  = %d", x9)
    dut._log.info("x10 = %d", x10)
    dut._log.info("x11 = %d", x11)
    dut._log.info("x12 = %d", x12)
    dut._log.info("x13 = %d", x13)
    dut._log.info("x14 = %d", x14)
    dut._log.info("x15 = %d", x15)
