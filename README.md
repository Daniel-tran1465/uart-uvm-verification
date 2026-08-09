# UART UVM Verification Project

## Overview
UART design + SystemVerilog/UVM verification environment, verified against
Verification Plan in docs/. Simulated on Synopsys VCS via EDA Playground.

## Architecture
[sơ đồ testbench — có thể dùng ASCII hoặc ảnh]

## Status
🔧 **Currently starting verification phase**

- [x] RTL design completed (TX, RX, baud rate generator)
- [ ] Directed testbench (in progress)
- [ ] UVM environment (driver, monitor, scoreboard)
- [ ] Functional coverage
- [ ] SVA assertions
- [ ] Full regression + coverage closure

Functional coverage: not started yet
Known bugs: N/A (verification not started)

See [Verification Plan](docs/UART_Verification_Plan.md) for full test plan and sign-off criteria.

## How to run
1. Copy rtl/*.sv into design.sv on EDA Playground
2. Copy tb/*.sv into testbench.sv (theo đúng thứ tự include)
3. Enable UVM 1.2, select VCS, Run
