RadarNet — FMCW Radar DSP–CNN FPGA Accelerator
RadarNet is an FPGA project targeting the PYNQ-Z2 (Zynq-7000 SoC). The goal is to implement an FMCW radar signal-processing and CNN inference pipeline in programmable logic. This repository tracks the RTL design and its functional verification as the pipeline is built.
Current Implementation
The first hardware block is a 32-bit AXI4-Stream register slice written in VHDL. A structural top-level module instantiates the slice, which buffers one beat, preserves TDATA and TLAST under backpressure, and can accept a new beat while delivering the buffered beat on the same clock edge.

A SystemVerilog UVM testbench exercises randomized payloads, source gaps, and sink backpressure. In the recorded XSim run, all 100 beats matched in order, with no UVM errors or fatals.
- [AXI4-Stream Register Slice — RTL Design and UVM Verification](AXI4_Stream_Interface_V0.1.0/)

Planned Integration
Range and Doppler FFT processing, frame buffering and reordering, and CNN acceleration are planned stages of the RadarNet RTL pipeline. This repository does not yet document a complete on-board accelerator.
