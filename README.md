# TT09 — VGA Slot Machine

An 8-bit VGA Slot Machine game written in Verilog, designed for Tiny Tapeout. It renders a complete slot machine layout directly via a 2-bit per channel RGB VGA interface without relying on hardware multipliers or external display controllers.

## Overview

The design implements a digital slot machine featuring:
- **640x480 @ ~60Hz VGA Output**: Custom lightweight graphics generator.
- **Pseudo-Random Number Generator (PRNG)**: A 16-bit Linear Feedback Shift Register (LFSR) with custom hardware mod-7 lookup logic to select reel outcomes.
- **3-Reel Display**: Interactive reel animations displaying classic slot symbols (Cherry, Lemon, Orange, Seven, Diamond, Bar, Bell).
- **Animated Lever & Win Light**: Real-time visual feedback for spin states, jackpots, partial matches, and loss outcomes.

---

## Technical Specifications

### Hardware Pinout

| Pin Name | Direction | Function |
| :--- | :--- | :--- |
| `clk` | Input | System / Pixel Clock (25 MHz) |
| `rst_n` | Input | Active-Low Reset |
| `ena` | Input | Design Enable (Tiny Tapeout wrapper control) |
| `ui_in[5]` | Input | Start / Spin Button (Active High) |
| `uo_out[7:0]` | Output | VGA Video & Sync Signals (Tiny Tapeout VGA Pmod) |

### VGA Output Bit Mapping (`uo_out`)

The video signal uses the standard Tiny Tapeout VGA Pmod 2-bit color pin mapping:

| Bit | Signal | Description |
| :---: | :--- | :--- |
| **7** | `HSYNC` | Horizontal Sync (Active Low) |
| **6** | `B[0]` | Blue LSB |
| **5** | `G[0]` | Green LSB |
| **4** | `R[0]` | Red LSB |
| **3** | `VSYNC` | Vertical Sync (Active Low) |
| **2** | `B[1]` | Blue MSB |
| **1** | `G[1]` | Green MSB |
| **0** | `R[1]` | Red MSB |

---

## VGA Timing Parameters

The design generates standard 640x480 video timing with a custom 752-cycle horizontal line footprint optimized for minimal gate usage:

- **Pixel Clock**: 25 MHz (40 ns period)
- **Horizontal Line**: 752 cycles
  - Visible Video + Front Porch: Pixels `0..655` (`HSYNC = 1`)
  - Sync Pulse: Pixels `656..751` (`HSYNC = 0`, 96 cycles)
- **Vertical Frame**: 525 lines
  - Visible Video: Lines `0..479`
  - Sync Pulse: Lines `490..491` (`VSYNC = 0`)

---

## Repository Structure

```text
├── src/
│   ├── project.v           # Top-level module (tt_um_vga_slot_machine) & graphics logic
│   └── hvsync_generator.v  # VGA timing and sync generator
├── test/
│   ├── tb.v                # Verilog testbench wrapper
│   ├── test.py             # Cocotb test suite
│   └── Makefile            # Cocotb build configuration
├── info.yaml               # Tiny Tapeout metadata
└── README.md               # Project documentation
