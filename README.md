# AXI3 UVM Testbench & Slave IP (`AXI3_testbench`)

An AMBA AXI3 Universal Verification Methodology (UVM) verification environment and Verilog AXI3 Slave Design Under Test (DUT), complete with functional and error-injection test suites, functional coverage, a scoreboard, a Compliance Test Suite (CTS) plan, and an IP User Manual.

---

## Repository Structure

```text
AXI3_testbench/
├── AXI_SLAVE.v                                                       # AXI3 Slave DUT (Verilog)
├── AXI_SLAVE IP User Manual — Architecture, Verification & SoC Integration.pdf
├── AXI3_CTS_List.xlsx                                                # Compliance & Coverage Test Plan
│
├── AXI_tb.sv                                                         # Top-level testbench module
├── AXI_intf.sv                                                       # SystemVerilog AXI3 interface
├── AXI_Include_pkg.sv                                                # Package including all UVM components & tests
├── AXI_Env.sv                                                        # Top-level UVM verification environment
│
├── AXI_seq_item.sv                                                   # AXI3 transaction sequence item
├── AXI_sequencer.sv                                                  # UVM sequencer
├── AXI_master_agent.sv                                               # Active Master UVM agent
├── AXI_master_driver.sv                                              # Master driver (drives AXI3 channels)
├── AXI_master_monitor.sv                                             # Master monitor (samples interface signals)
├── AXI_slave_agent.sv                                                # Passive/monitoring Slave UVM agent
├── AXI_slave_monitor.sv                                              # Slave monitor
├── AXI_driver_config.sv                                              # Driver configuration object
├── AXI_monitor_config.sv                                             # Monitor configuration object
│
├── AXI_Scoreboard.sv                                                 # Reference checking & data integrity scoreboard
├── AXI_Coverage.sv                                                   # Functional covergroups & cross-coverage
│
├── AXI_Base_Sequence.sv                                              # Base UVM sequence
├── AXI_Functional_Sequences.sv                                       # Functional stimulus sequences
├── AXI_Err_sequences.sv                                              # Error-injection & corner-case sequences
│
├── AXI_Base_Test.sv                                                  # Base UVM test class
├── AXI_Functional_Tests.sv                                           # Functional test cases
├── AXI_ERR_tests.sv                                                  # Negative / error-response test cases
└── AXI_CTS_Regression_list.sv                                        # Regression test suite list
```

---

## Architecture Overview

### 1. Design Under Test (`AXI_SLAVE.v`)
* Implements an **AMBA AXI3-compliant slave** handling the five standard AXI3 channels:
  * Write Address (`AW`)
  * Write Data (`W`)** — including AXI3 write interleaving / `WID` support
  * Write Response (`B`)
  * Read Address (`AR`)
  * Read Data (`R`)
* Detailed register maps, timing diagrams, burst support, and SoC integration guidelines are documented in `AXI_SLAVE IP User Manual — Architecture, Verification & SoC Integration.pdf`.

### 2. UVM Verification Environment (`AXI_Env.sv`)
* Interface (`AXI_intf.sv`): Connects `AXI_tb.sv` to `AXI_SLAVE.v` using clocking blocks and modports for race-free driving and sampling.
* Master Agent (`AXI_master_agent.sv`): Active agent containing `AXI_sequencer`, `AXI_master_driver`, and `AXI_master_monitor`, configured via `AXI_driver_config` and `AXI_monitor_config`.
* Slave Agent (`AXI_slave_agent.sv`): Houses `AXI_slave_monitor` to observe slave-side protocol activity and feed analysis ports.
* Scoreboard (`AXI_Scoreboard.sv`): Compares observed write and read transactions against an internal reference memory/model to verify data integrity, burst ordering, and response codes (`OKAY`, `SLVERR`, `DECERR`).
* Coverage Collector (`AXI_Coverage.sv`): Tracks functional coverage across burst types (`FIXED`, `INCR`, `WRAP`), burst lengths, transfer sizes, address alignment, and response types.

---

## Verification Plan & Test Suite

| File | Role |
| :--- | :--- |
| `AXI3_CTS_List.xlsx` | Master verification plan mapping AXI3 protocol features to test cases and coverage goals. |
| `AXI_Base_Test.sv` / `AXI_Base_Sequence.sv` | Foundational test setup (environment build, config DB setup, objection handling) and base sequence utilities. |
| `AXI_Functional_Tests.sv` / `AXI_Functional_Sequences.sv` | Normal operational scenarios: single/burst reads & writes, `FIXED`/`INCR`/`WRAP` bursts, back-to-back transfers, and byte-strobe variations. |
| `AXI_ERR_tests.sv` / `AXI_Err_sequences.sv` | Negative and boundary testing: invalid addresses, error responses, reset-on-the-fly, and protocol corner cases. |
| `AXI_CTS_Regression_list.sv` | Consolidated list of tests for full regression runs. |

---

## Getting Started

### Prerequisites
* An IEEE 1800 SystemVerilog & UVM 1.1d / 1.2 compliant simulator (e.g., Siemens QuestaSim, Synopsys VCS, Cadence Xcelium, or AMD Vivado XSim).

### Compiling and Running a Simulation

Compile the package, interface, DUT, and top-level testbench, then invoke `run_test()` via `+UVM_TESTNAME`:

#### Siemens QuestaSim / ModelSim
```bash
vlib work
vlog -sv +acc +incdir+. AXI_tb.sv
vsim -c work.AXI_tb +UVM_TESTNAME=<test_name> +UVM_VERBOSITY=UVM_MEDIUM -do "run -all; quit"
```

#### Synopsys VCS
```bash
vcs -sverilog -ntb_opts uvm-1.2 +incdir+. AXI_tb.sv -o simv
./simv +UVM_TESTNAME=<test_name> +UVM_VERBOSITY=UVM_MEDIUM
```

#### Cadence Xcelium
```bash
xrun -sv -uvm +incdir+. AXI_tb.sv +UVM_TESTNAME=<test_name>
```

> **Note:** Replace `<test_name>` with a test class defined in `AXI_Functional_Tests.sv` or `AXI_ERR_tests.sv` (for example, `AXI3_Sanity_test`).

---

## Documentation

* `AXI_SLAVE IP User Manual — Architecture, Verification & SoC Integration.pdf` — Complete architectural specification, handshake timing, and SoC integration instructions.
* `AXI3_CTS_List.xlsx` — Feature-by-feature compliance checklist and regression tracking sheet.
