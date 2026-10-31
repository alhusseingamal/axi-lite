# AXI4-Lite Slave Register File with SVA

A compact 32-bit AXI4-Lite slave register file verified with concurrent SystemVerilog Assertions (SVA) in Verilator.

### Features
* **Protocol:** 32-bit AXI4-Lite with byte-strobe write masking (`s_axi_wstrb`).
* **Architecture:** 8 local 32-bit registers (`0x00`–`0x1C`) with independent `AW` and `W` channel latching.
* **SVA Protocol Checks:**
  * Post-reset state verification.
  * Handshake stability (`VALID` and payload stability until `READY`).
  * Handshake deassertion and clean cycle termination.
  * Single-cycle `READY` pulse compliance.
  * Unknown (`'X'`) value detection on active control lines.

### Simulation
Requires `verilator`:
```bash
make clean && make all
```

## TODOs
- Replace directed test sequences with automatic randomized stimulus generation.
- Decouple the register file backend from the bus interface.