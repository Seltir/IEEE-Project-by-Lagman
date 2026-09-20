import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ReadOnly, RisingEdge


async def wait_for_line_start(dut):
    """Wait for HSYNC to transition from low to high (pixel 0 start)."""
    await RisingEdge(dut.clk)
    await ReadOnly()
    previous_hsync = (int(dut.uo_out.value) >> 7) & 1

    while True:
        await RisingEdge(dut.clk)
        await ReadOnly()
        current_hsync = (int(dut.uo_out.value) >> 7) & 1

        if previous_hsync == 0 and current_hsync == 1:
            return

        previous_hsync = current_hsync


async def capture_line(dut):
    """
    Captures one full horizontal line (752 cycles).
    Bit mapping expected:
    uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]}
    """
    line = []
    for _ in range(752):
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

        await RisingEdge(dut.clk)
        await ReadOnly()

    return line


async def measure_hsync_period(dut):
    """
    Measures the exact high and low duration of HSYNC in clock cycles.
    """
    # 1. Wait for HSYNC to enter the active-low pulse state
    while True:
        await RisingEdge(dut.clk)
        await ReadOnly()
        if ((int(dut.uo_out.value) >> 7) & 1) == 0:
            break

    # 2. Count low cycles
    low_count = 0
    while True:
        low_count += 1
        await RisingEdge(dut.clk)
        await ReadOnly()
        if ((int(dut.uo_out.value) >> 7) & 1) == 1:
            break

    # 3. Count high cycles
    high_count = 0
    while True:
        high_count += 1
        await RisingEdge(dut.clk)
        await ReadOnly()
        if ((int(dut.uo_out.value) >> 7) & 1) == 0:
            break

    return high_count, low_count


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

    # Measure exact HSYNC pulse widths directly
    high_count, low_count = await measure_hsync_period(dut)

    assert high_count == 656, (
        f"Expected 656 HSYNC-high cycles, got {high_count}"
    )
    assert low_count == 96, (
        f"Expected 96 HSYNC-low cycles, got {low_count}"
    )

    # Synchronize capture to line start (0 -> 1 HSYNC edge)
    await wait_for_line_start(dut)
    line = await capture_line(dut)

    # Verify line length and exact pattern alignment
    assert len(line) == 752, f"Expected 752 pixels per line, got {len(line)}"

    hsync_pattern = [p[0] for p in line]
    expected_hsync = [1] * 656 + [0] * 96

    assert hsync_pattern == expected_hsync, (
        f"Unexpected hsync pattern. First 10: {hsync_pattern[:10]}, "
        f"around pulse: {hsync_pattern[650:660]}"
    )

    dut._log.info("VGA timing test passed successfully!")
