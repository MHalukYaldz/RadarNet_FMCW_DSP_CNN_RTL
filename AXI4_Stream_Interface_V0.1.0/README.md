# AXI4-Stream Interface — UVM Verification

This RadarNet RTL block is a 32-bit, single-beat AXI4-Stream buffer written in VHDL. It passes `TDATA` and `TLAST` from input to output using `TVALID`/`TREADY` handshakes.

## UVM Testbench

The SystemVerilog UVM environment (`axis_uvm_pkg`) contains a source agent, a sink agent, and a FIFO scoreboard. The source agent's sequencer and driver apply stimulus, while the two monitors publish transfers sampled on rising clock edges when `TVALID` and `TREADY` are both high.

`axis_ab_test` runs a directed sequence after startup reset is released.

1. **Send a two-beat packet.** The sequence drives `32'hAAAA_0001` with `TLAST=0`, then `32'hBBBB_0002` with `TLAST=1`. The source driver holds each beat until the DUT accepts it.
2. **Apply three-cycle backpressure per beat.** After detecting `M_AXIS_TVALID`, the sink driver holds `M_AXIS_TREADY` low for three rising edges, then raises it to accept the beat. The sink monitor checks that `TVALID` remains asserted and that `TDATA` and `TLAST` remain stable through the handshake.
3. **Check delivery in order.** The scoreboard queues accepted input beats and compares `TDATA` and `TLAST` against each output beat. It flags unexpected, missing, or mismatched transfers. Both monitors check transferred `TDATA` and `TLAST` for X/Z values.

## Pass Criteria

- Exactly two input transfers, two output transfers, and two matches, with no pending beats.
- At least six observed stall cycles in total and no protocol-check errors.
- Completion before the 200-clock-cycle watchdog expires.

**Simulation tool** — Vivado 2025.2 / XSim.
