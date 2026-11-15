# AXI4-Stream Register Slice — RTL Design and UVM Verification

This RadarNet milestone implements and tests a **32-bit, single-beat AXI4-Stream register slice** in VHDL. It forwards `TDATA` and `TLAST` using the `TVALID`/`TREADY` handshake. It does not perform radar DSP or CNN processing.

## RTL Design

- `radar_dsp_cnn_top.vhd` is the structural top level. It instantiates `axis_register_slice` as the input buffer.
- `axis_register_slice.vhd` stores one 32-bit beat and its `TLAST` flag. It holds the output stable while the downstream receiver is not ready and clears the buffered beat on an active-low asynchronous reset.
- When the downstream receiver accepts a buffered beat, the slice can accept the next input beat on that same clock edge. This supports **one beat per clock cycle** when the source continuously presents valid beats and the sink stays ready. Upstream `TREADY` depends combinationally on downstream `TREADY` when the buffer is full.

## SystemVerilog UVM Testbench

The UVM environment includes source and sink agents, monitors on both interfaces, and a FIFO-based scoreboard. The simulation top, `tb_radar_dsp_cnn_top_uvm`, provides a 50 MHz clock, applies startup reset, and runs `axis_random_test` by default.

- **Stimulus.** The sequence sends **100 randomized 32-bit payloads** in **10 packets of 10 beats**. `TLAST` marks each packet boundary. The source inserts **0–3 additional idle cycles** before presenting a beat. The sink selects a **0–7-cycle random wait** after detecting valid output, then asserts ready on a falling edge.
- **Protocol checks.** Both monitors check that `TVALID` stays asserted and that `TDATA` and `TLAST` remain stable following a stalled cycle, including on the edge that completes the handshake. Both monitors reject X/Z values on transferred `TDATA` or `TLAST`. The test requires stalls to be observed on both interfaces.
- **End-to-end checks.** The scoreboard compares accepted input beats with delivered output beats in order. It checks data, packet-end flags, transfer counts, and that no expected beats remain queued. The random test has a **2,000-cycle watchdog**.
- **Directed stimulus.** The earlier two-beat A/B sequence remains available as `axis_ab_test`. It is not the default run. The current shared sink driver uses randomized delays, so it does not enforce a fixed three-cycle stall per beat.

## Simulation Result

**PASS — Vivado 2025.2 / XSim, UVM 1.2.** In the recorded `axis_random_test` run, the scoreboard reported **100 input beats, 100 output beats, 100 matches, and 0 pending beats**. The monitors observed **207 input stall cycles** and **417 output stall cycles**, with **0 UVM errors and 0 UVM fatals**. These are simulation results for this run, not board measurements.

## Simulation Setup

Use `axis_register_slice.vhd` and `radar_dsp_cnn_top.vhd` as design sources. Add `axis_uvm_if.sv`, `axis_uvm_pkg.sv` (named `axis_transaction.sv` in the original Vivado sources), and `tb_radar_dsp_cnn_top_uvm.sv` as simulation sources. Include only one copy of `axis_uvm_pkg`. Set `tb_radar_dsp_cnn_top_uvm` as the simulation top. The older non-UVM testbench is not required.
