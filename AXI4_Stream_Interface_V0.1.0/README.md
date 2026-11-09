# AXI4-Stream Interface

A 32-bit AXI4-Stream interface developed in SystemVerilog as part of the Radar DSP–CNN FPGA project.

## RTL Design

The design implements a single-clock, single-entry AXI4-Stream buffer.

- Uses `TVALID` and `TREADY` for data transfer.
- Transfers 32-bit `TDATA` and preserves `TLAST`.
- Holds output data stable during backpressure.
- Supports simultaneous input and output handshakes.
- Supports a maximum throughput of one word per clock cycle.

## Testbench

A SystemVerilog testbench verifies the AXI4-Stream interface using directed and randomized tests.

- Reset behavior
- Transfer of 1,000 data words
- Randomized `TVALID` and `TREADY` conditions
- Data integrity and transfer ordering using a scoreboard
- `TLAST` propagation
- Backpressure stability and timeout detection

**Simulation Result:** PASS

## Tools

- SystemVerilog
- AMD Vivado 2025.2
- XSim

## Project Status

AXI4-Stream interface implemented and functionally verified. Integration with the radar DSP processing pipeline is planned.
