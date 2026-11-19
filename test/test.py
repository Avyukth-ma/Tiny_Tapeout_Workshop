import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def tick(dut):
    await RisingEdge(dut.clk)
    await Timer(20, unit="ns")


async def check_register(dut, register, expected, context):
    dut.ui_in.value = register
    await Timer(10, unit="ns")
    actual = int(dut.uo_out.value)
    assert actual == expected, (
        f"{context}, x{register}: expected 0x{expected:02x}, got 0x{actual:02x}"
    )


@cocotb.test()
async def test_simple_cpu(dut):
    dut.rst_n.value = 0
    dut.ena.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    cocotb.start_soon(Clock(dut.clk, 100, unit="ns").start())

    await tick(dut)
    await tick(dut)
    await check_register(dut, 1, 0, "initial reset")
    assert int(dut.uio_oe.value) == 0
    assert int(dut.uio_out.value) == 0

    dut.rst_n.value = 1
    dut.ena.value = 1
    await tick(dut)  # ROM word 0: NOP

    # One result per ROM word, via the public pins in RTL and gate-level simulation.
    expected = (
        (1, 5, "ADDI x1, x0, 5"),
        (2, 10, "ADDI x2, x0, 10"),
        (3, 15, "ADD x3, x1, x2"),
        (4, 5, "SUB x4, x2, x1"),
        (5, 0, "AND x5, x1, x2"),
        (6, 15, "OR x6, x1, x2"),
        (7, 15, "XOR x7, x1, x2"),
        (8, 20, "ADDI x8, x0, 20"),
        (9, 1, "SLTI x9, x8, 30"),
        (10, 0, "SLTIU x10, x8, 10"),
        (11, 27, "XORI x11, x8, 15"),
        (12, 23, "ORI x12, x8, 3"),
        (13, 4, "ANDI x13, x8, 7"),
        (14, 80, "SLLI x14, x8, 2"),
        (15, 5, "SRLI x15, x8, 2"),
        (8, 248, "ADDI x8, x0, -8"),
        (3, 1, "SLT x3, x8, x1"),
        (4, 0, "SLTU x4, x8, x1"),
        (5, 160, "SLL x5, x1, x1"),
        (2, 31, "ADDI x2, x0, 31"),
        (6, 1, "SRL x6, x8, x2"),
        (7, 255, "SRA x7, x8, x2"),
        (9, 255, "SRAI x9, x8, 31"),
        (10, 1, "SLTI x10, x8, -1"),
        (11, 1, "SLTIU x11, x1, -1"),
        (0, 0, "ADDI x0, x0, 7"),
        (2, 34, "ADDI x2, x0, 34"),
        (12, 20, "SLL x12, x1, x2"),
        (13, 0, "SLTIU x13, x8, 10"),
        (13, 1, "SRLI x13, x8, 31"),
        (1, 5, "Unsupported OP encoding, no write"),
    )
    for word, (reg, value, instruction) in enumerate(expected, start=1):
        await tick(dut)
        await check_register(dut, reg, value, f"ROM word {word}: {instruction}")
        if word == 1:
            dut.ena.value = 0
            for _ in range(3):
                await tick(dut)
                await check_register(dut, 1, 5, "disabled: register holds")
                await check_register(dut, 2, 0, "disabled: next instruction not executed")
            dut.ena.value = 1

    # Counter wraps after 32 instructions and starts the same program again.
    await tick(dut)
    await check_register(dut, 2, 34, "wrapped NOP")
    await tick(dut)
    await tick(dut)
    await check_register(dut, 2, 10, "wrapped ADDI")

    # Reset works with enable low and clears every visible slot.
    dut.rst_n.value = 0
    dut.ena.value = 0
    await tick(dut)
    for reg in range(16):
        await check_register(dut, reg, 0, "reset while disabled")
    dut.rst_n.value = 1
    dut.ena.value = 1
    await tick(dut)
    await check_register(dut, 1, 0, "reset returned to NOP")
    await tick(dut)
    await check_register(dut, 1, 5, "restart after reset")
