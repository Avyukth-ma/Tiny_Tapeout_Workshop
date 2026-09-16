import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


@cocotb.test()
async def test_tinyrv32(dut):

    dut._log.info("Starting TinyRV32 CPU test")

    # ------------------------------------------------------------
    # Start clock
    # ------------------------------------------------------------

    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # ------------------------------------------------------------
    # Initial inputs
    # ------------------------------------------------------------

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # ------------------------------------------------------------
    # Reset
    # ------------------------------------------------------------

    dut.rst_n.value = 0

    # Hold reset for two complete clock cycles
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # Release reset
    dut.rst_n.value = 1

    # ------------------------------------------------------------
    # Program execution
    #
    # 0: NOP
    # 1: ADDI x1, x0, 5
    # 2: ADDI x2, x0, 10
    # 3: ADD  x3, x1, x2
    # 4: SUB  x4, x2, x1
    # 5: AND  x5, x1, x2
    # 6: OR   x6, x1, x2
    # 7: XOR  x7, x1, x2
    # ------------------------------------------------------------

    # Execute NOP
    await RisingEdge(dut.clk)

    # Execute ADDI x1, x0, 5
    await RisingEdge(dut.clk)

    assert int(dut.user_project.registers[1].value) == 5, \
        "ADDI x1 failed"

    # Execute ADDI x2, x0, 10
    await RisingEdge(dut.clk)

    assert int(dut.user_project.registers[2].value) == 10, \
        "ADDI x2 failed"

    # Execute ADD x3, x1, x2
    await RisingEdge(dut.clk)

    assert int(dut.user_project.registers[3].value) == 15, \
        "ADD failed"

    # Execute SUB x4, x2, x1
    await RisingEdge(dut.clk)

    assert int(dut.user_project.registers[4].value) == 5, \
        "SUB failed"

    # Execute AND x5, x1, x2
    await RisingEdge(dut.clk)

    assert int(dut.user_project.registers[5].value) == (5 & 10), \
        "AND failed"

    # Execute OR x6, x1, x2
    await RisingEdge(dut.clk)

    assert int(dut.user_project.registers[6].value) == (5 | 10), \
        "OR failed"

    # Execute XOR x7, x1, x2
    await RisingEdge(dut.clk)

    assert int(dut.user_project.registers[7].value) == (5 ^ 10), \
        "XOR failed"

    # ------------------------------------------------------------
    # Check x0
    # ------------------------------------------------------------

    assert int(dut.user_project.registers[0].value) == 0, \
        "x0 is not zero"

    # ------------------------------------------------------------
    # Check debug output
    # x3 = 15
    # ------------------------------------------------------------

    assert int(dut.uo_out.value) == 15, \
        "Debug output does not match x3"

    dut._log.info("TinyRV32 basic instruction test passed!")
