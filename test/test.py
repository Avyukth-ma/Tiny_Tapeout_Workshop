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

    dut._log.info("Starting TinyRV32 CPU test")

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

    # Release reset
    dut.rst_n.value = 1

    # ============================================================
    # PROGRAM
    #
    # 0: NOP
    # 1: ADDI x1, x0, 5
    # 2: ADDI x2, x0, 10
    # 3: ADD  x3, x1, x2
    # 4: SUB  x4, x2, x1
    # 5: AND  x5, x1, x2
    # 6: OR   x6, x1, x2
    # 7: XOR  x7, x1, x2
    #
    # ============================================================

    # ------------------------------------------------------------
    # Execute NOP
    # ------------------------------------------------------------

    await clock_cycle(dut)

    # ------------------------------------------------------------
    # Execute ADDI x1, x0, 5
    # ------------------------------------------------------------

    await clock_cycle(dut)

    x1 = await read_register(dut, 1)

    assert x1 == 5, (
        f"ADDI x1 failed: expected 5, got {x1}"
    )

    # ------------------------------------------------------------
    # Execute ADDI x2, x0, 10
    # ------------------------------------------------------------

    await clock_cycle(dut)

    x2 = await read_register(dut, 2)

    assert x2 == 10, (
        f"ADDI x2 failed: expected 10, got {x2}"
    )

    # ------------------------------------------------------------
    # Execute ADD x3, x1, x2
    # ------------------------------------------------------------

    await clock_cycle(dut)

    x3 = await read_register(dut, 3)

    assert x3 == 15, (
        f"ADD failed: expected 15, got {x3}"
    )

    # ------------------------------------------------------------
    # Execute SUB x4, x2, x1
    # ------------------------------------------------------------

    await clock_cycle(dut)

    x4 = await read_register(dut, 4)

    assert x4 == 5, (
        f"SUB failed: expected 5, got {x4}"
    )

    # ------------------------------------------------------------
    # Execute AND x5, x1, x2
    # ------------------------------------------------------------

    await clock_cycle(dut)

    x5 = await read_register(dut, 5)

    assert x5 == (5 & 10), (
        f"AND failed: expected {5 & 10}, got {x5}"
    )

    # ------------------------------------------------------------
    # Execute OR x6, x1, x2
    # ------------------------------------------------------------

    await clock_cycle(dut)

    x6 = await read_register(dut, 6)

    assert x6 == (5 | 10), (
        f"OR failed: expected {5 | 10}, got {x6}"
    )

    # ------------------------------------------------------------
    # Execute XOR x7, x1, x2
    # ------------------------------------------------------------

    await clock_cycle(dut)

    x7 = await read_register(dut, 7)

    assert x7 == (5 ^ 10), (
        f"XOR failed: expected {5 ^ 10}, got {x7}"
    )

    # ============================================================
    # CHECK x0
    # ============================================================

    x0 = await read_register(dut, 0)

    assert x0 == 0, (
        f"x0 is not zero: got {x0}"
    )

    # ============================================================
    # FINAL CHECK
    # ============================================================

    dut._log.info("TinyRV32 basic instruction test passed!")
    dut._log.info("x0 = %d", x0)
    dut._log.info("x1 = %d", x1)
    dut._log.info("x2 = %d", x2)
    dut._log.info("x3 = %d", x3)
    dut._log.info("x4 = %d", x4)
    dut._log.info("x5 = %d", x5)
    dut._log.info("x6 = %d", x6)
    dut._log.info("x7 = %d", x7)
