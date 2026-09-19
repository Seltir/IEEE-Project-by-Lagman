import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, ClockCycles


async def capture_line(dut):
    """
    Captures one full horizontal line (752 cycles).
    Bit mapping expected:
    uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]}
    """
    line = []
    for _ in range(752):
        await RisingEdge(dut.clk)
        await ReadOnly()

        val = int(dut.uo_out.value)
        hsync = (val >> 7) & 1
        b0 = (val >> 6) & 1
        g0 = (val >> 5) & 1
        r0 = (val >> 4) & 1
        vsync = (val >> 3) & 1
        b1 = (val >> 2) & 1
        g1 = (val >> 1) & 1
        r1 = val & 1

        r = (r1 << 1) | r0
        g = (g1 << 1) | g0
        b = (b1 << 1) | b0

        line.append((hsync, vsync, r, g, b))

    return line


@cocotb.test()
async def test_project(dut):
    dut._log.info("Starting VGA Slot Machine Test")

    # Start 25 MHz clock (40 ns period)
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize inputs
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.ena.value = 1

    # Reset DUT
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Capture first line immediately after reset settling
    line = await capture_line(dut)

    # Verify line length
    assert len(line) == 752, f"Expected 752 pixels per line, got {len(line)}"

    # Check HSYNC behavior
    # Pixels 0..655 -> HSYNC = 1 (active video + front porch)
    # Pixels 656..751 -> HSYNC = 0 (sync pulse = 96 pixels)
    hsync_pattern = [p[0] for p in line]
    expected_hsync = [1] * 656 + [0] * 96

    assert hsync_pattern == expected_hsync, (
        f"Unexpected hsync pattern. First 10: {hsync_pattern[:10]}, "
        f"around pulse: {hsync_pattern[650:660]}"
    )

    dut._log.info("VGA timing test passed successfully!")
