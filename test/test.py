import cocotb
from cocotb.triggers import Timer


async def apply_inputs(dut, A, B, OP):
    """Apply ALU inputs."""

    # ui_in[3:0] = A
    # ui_in[7:4] = B
    dut.ui_in.value = (B << 4) | A

    # uio_in[2:0] = OP
    dut.uio_in.value = OP

    # Allow combinational logic to settle
    await Timer(1, units="ns")


def expected_result(A, B, OP):
    """Calculate expected ALU result and carry."""

    if OP == 0:          # ADD
        value = A + B
        result = value & 0xF
        carry = (value >> 4) & 1

    elif OP == 1:        # SUB
        value = (A - B) & 0x1F
        result = value & 0xF
        carry = (value >> 4) & 1

    elif OP == 2:        # AND
        result = A & B
        carry = 0

    elif OP == 3:        # OR
        result = A | B
        carry = 0

    elif OP == 4:        # XOR
        result = A ^ B
        carry = 0

    elif OP == 5:        # NOT A
        result = (~A) & 0xF
        carry = 0

    elif OP == 6:        # INC A
        value = A + 1
        result = value & 0xF
        carry = (value >> 4) & 1

    elif OP == 7:        # DEC A
        value = (A - 1) & 0x1F
        result = value & 0xF
        carry = (value >> 4) & 1

    return result, carry


@cocotb.test()
async def test_alu(dut):

    dut._log.info("Starting 4-bit ALU test")

    # Enable the design
    dut.ena.value = 1

    # These are unused by our combinational ALU
    dut.clk.value = 0
    dut.rst_n.value = 1

    # Test all 8 operations
    for OP in range(8):

        # Test all possible 4-bit A values
        for A in range(16):

            # Test all possible 4-bit B values
            for B in range(16):

                await apply_inputs(dut, A, B, OP)

                expected, expected_carry = expected_result(A, B, OP)

                # Read ALU result
                actual = int(dut.uo_out.value)

                actual_result = actual & 0xF
                actual_carry = (actual >> 4) & 1
                actual_zero = (actual >> 5) & 1

                # Check result
                assert actual_result == expected, (
                    f"OP={OP:03b}, A={A:04b}, B={B:04b}: "
                    f"Expected result={expected:04b}, "
                    f"Got result={actual_result:04b}"
                )

                # Check carry
                assert actual_carry == expected_carry, (
                    f"OP={OP:03b}, A={A:04b}, B={B:04b}: "
                    f"Expected carry={expected_carry}, "
                    f"Got carry={actual_carry}"
                )

                # Check zero flag
                expected_zero = 1 if expected == 0 else 0

                assert actual_zero == expected_zero, (
                    f"OP={OP:03b}, A={A:04b}, B={B:04b}: "
                    f"Expected zero={expected_zero}, "
                    f"Got zero={actual_zero}"
                )

    dut._log.info("All 2048 ALU test cases passed!")
