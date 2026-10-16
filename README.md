# SAARTHI Hardware Security RTL

**Phase 2 | SystemVerilog RTL, HSM Integration, AXI4-Lite Verification**

This repository contains the RTL and simulation testbenches for the SAARTHI hardware-security work. The project uses a simulation-first workflow with **Xilinx Vivado 2023.1 / XSim**. No physical FPGA-board testing is claimed.

## Project Scope

- Security monitoring for SPI, I²C, and CAN interfaces.
- SystemVerilog assertions (SVA) for security-related behavior.
- HSM control and register-interface RTL.
- A common security-event path that can lock the HSM.
- AXI4-Lite register access and channel-ordering verification.
- Simulation evidence, synthesis utilization, lint, and timing review.

## Repository Layout

```text
.
├── bus1/
│   ├── CAN/
│   ├── I2C/
│   └── SPI/
├── HSM/
├── SVA/
├── rtl/
├── testbench/
├── constraints/
├── README.md
└── VLSI Hardware Security.xpr
```

Folder and file names may be adjusted to match the files actually committed. Keep synthesizable RTL, simulation-only testbenches, and generated Vivado outputs clearly separated.

## Main RTL and Testbenches

### RTL
- `hsm_regs_pkg.sv` — register offsets and related constants.
- `security_event_if.sv` — combines security-event inputs and models sticky HSM lock behavior.
- `hsm_axi_lite_regs.sv` — AXI4-Lite register block and security-related access behavior.
- `hsm_security_integration.sv` — integration wrapper for the event interface and register block.

### Verification
- `tb_hsm_axi_lite_regs.sv` — AXI4-Lite register tests, including AW-before-W and W-before-AW ordering with follow-up reads.
- `tb_hsm_security_integration.sv` — integration scenarios for SPI, I²C, CAN, HSM events, reset recovery, and locked key-slot write rejection.
- `tb_security_event_if.sv` — common security-event and reset behavior.
- `tb_sva_failure_injection.sv` — positive assertion check and an intentionally incorrect negative expectation.

Other protocol-specific SVA and testbench files are organized under the `bus1/`, `HSM/`, and `SVA/` directories where present.

## Verification Results

The following results are based on the supplied Vivado/XSim console logs:

| Testbench / check | Observed result | Simulation finish |
|---|---|---:|
| `tb_hsm_axi_lite_regs` | 10/10 predefined tests passed, including both write-channel orderings and follow-up reads | 550 ns |
| `tb_hsm_security_integration` | 6/6 predefined functional scenarios passed | 380 ns |
| `tb_security_event_if` | Listed event-lock and reset-clear checks passed | 251 ns |
| `tb_sva_failure_injection` | Positive property passed; injected negative expectation was detected as expected | 80 ns |

These are counts of predefined functional scenarios, **not** full RTL code-coverage percentages or proof of exhaustive protocol compliance.

## Synthesis and Lint Notes

Previously supplied synthesis evidence reported:

- Slice LUTs: **140 / 134,600** (about **0.10%**)
- Flip-flops / slice registers: **144 / 269,200** (about **0.05%**)
- Bonded I/O resources: **223 / 400** (**55.75%**)

The supplied lint summary was reported as **0 violations and 0 waived violations**. Confirm the final lint and synthesis reports correspond to the exact source revision being submitted.

A 100 MHz clock target (10 ns period) is specified in the project context. The earlier timing evidence indicated missing input/output delay constraints, and the setup-slack sign needs confirmation from one final Timing Summary. Therefore, this README does **not** claim timing closure.

## Register Map

The current RTL package defines these offsets:

| Register constant | Offset |
|---|---:|
| `HSM_CTRL_OFFSET` | `0x00` |
| `HSM_STATUS_OFFSET` | `0x04` |
| `HSM_ERROR_OFFSET` | `0x08` |
| `HSM_LOCK_OFFSET` | `0x0C` |
| `HSM_KEY_SLOT_OFFSET` | `0x10` |
| `HSM_NONCE_STATUS_OFFSET` | `0x14` |
| `HSM_VERSION_OFFSET` | `0x18` |

The version read was observed as `0x00010000`. The key-slot register represents a handle in the tested model, not raw key material. Confirm these offsets against the final committed RTL.

## Tools and Target

- **HDL:** SystemVerilog
- **Simulation:** Xilinx Vivado 2023.1 / XSim
- **Target device:** Artix-7 `xc7a200tfbg676-2` (as specified in the project context)
- **Clock target:** 100 MHz (10 ns period)
- **Reset:** Active-low `rst_n` (as specified in the project context)

## Limitations

- Verification is simulation-first; no physical FPGA board result is claimed.
- The test counts represent the scenarios explicitly exercised by the supplied testbenches, not exhaustive code coverage.
- The current HSM model demonstrates control, lock, and register behavior; it does not establish production cryptographic implementation, secure key storage, secure boot, side-channel resistance, or key lifecycle management.
- AXI4-Lite verification covers the tested register operations and two write-channel orderings. Broader protocol stress, byte-strobe combinations, and formal compliance require separate evidence.
- Timing closure should not be claimed until the final Timing Summary and external I/O constraints have been reviewed.

## Build and Run

1. Open `VLSI Hardware Security.xpr` in Vivado 2023.1.
2. Confirm that all required RTL and testbench files are present in the project.
3. Select the required simulation top (for example, `tb_hsm_axi_lite_regs` or `tb_hsm_security_integration`).
4. Run **Run Behavioral Simulation**.
5. Review the console for the expected PASS messages and final test summary.
6. Run synthesis and lint on the final RTL revision, and save the reports as submission evidence.

Exact Vivado source-set paths may differ from the repository layout. Check the committed project configuration before relying on automatic source discovery.

## Author

**K. Mohan Krishna**  
Electronics Lead — VLSI & Hardware Security  
SAARTHI Project — Phase 2

---


