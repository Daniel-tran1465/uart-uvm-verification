# UART UVM Verification Project

## Overview
UART design + SystemVerilog/UVM verification environment, verified against
Verification Plan in docs/. Simulated on Synopsys VCS via EDA Playground.

## Architecture
[sơ đồ testbench — có thể dùng ASCII hoặc ảnh]

## Status
- Feature covered: X/15 (xem docs/UART_Verification_Plan.md)
- Functional coverage: XX%
- Known bugs: 0 open

## How to run
1. Copy rtl/*.sv into design.sv on EDA Playground
2. Copy tb/*.sv into testbench.sv (theo đúng thứ tự include)
3. Enable UVM 1.2, select VCS, Run
