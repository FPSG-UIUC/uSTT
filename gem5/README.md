# Evaluation: Impede Micro-op Scheme

This work proposes the **impede micro-op** mechanism, which reuses existing processor hardware to realize an instruction delaying mechanism in [Speculative Taint Tracking (STT)](https://dl.acm.org/doi/10.1145/3352460.3358274).
Our evaluation is conducted using the [Gem5 simulator](https://github.com/gem5/gem5), forked from commit `0b2fa99` on the stable branch.

# Modification over Gem5 Simulator
```
.
├── stt_config    # Scripts for running Gem5 simulations with STT-related configurations
├── src/cpu/o3    # Out-of-order CPU model modified to support STT-related features
└── src/arch/arm/ # ARM ISA modifications to support impede micro-ops
    ├── insts
    └── isa
```

# Quick Start Guide
## Compile the Gem5 Simulator
```
scons build/ARM/gem5.fast -j <num_cores>
```
## Run the Simulation
```
build/ARM/gem5.debug -re ./stt_config/stt_test.py <options>
```
This command runs the design specified by `<options>` on the bubblesort test program provided by Gem5 resources.
The simulation results (including statistics) will be written to the `m5out` directory.

## Simulation Options
### Main Scheme Switch
We implement four major schemes:

1. **OG-STT** (Enable flag: `--enable-stt`): Original STT that supports expensive CAM-style instruction delaying.
2. **Delay Access** (Enable flag: `--enable-delay-acc`): No taint tracking. Delay the execution of unsafe loads. 
3. **Delay Execute** (Enable flag: `--enable-delay-exec`): Naive taint tracking. Delay the execution of tainted load/stores and the resolution of tainted branches until there is no unresolved branch older than them. 
4. **Impede Micro-ops** (Enable flag: `--impede-uop`): Introduce impede micro-ops to delay transmitters. Configuration of which instruction types are protected is described below.

### Impede Micro-ops (Extended Configuration)
The `--impede-uop` flag internally enables delaying the execution of impede micro-ops, which further delays the transmitters depending on them.
To configure which instruction types will be decoded into impede micro-ops, additional modifications are required:

- **Load/Store instructions**  
  - Modify `src/arch/arm/isa/templates/templates.isa` to include `mem64stt.isa`.  
  - Modify `src/arch/arm/isa/insts/insts.isa` to include `mem64stt.isa`, `ldr64stt.isa`, and `str64stt.isa`.  
  - In `src/arch/arm/insts/macromem.hh`, set the macros `IMPEDE_UOP_LOAD` and `IMPEDE_UOP_STORE` to `1`.

- **Branch instructions**  
  - Modify `src/arch/arm/isa/templates/templates.isa` to include `branch64stt.isa`.  
  - Modify `src/arch/arm/isa/insts/insts.isa` to include `branch64stt.isa`.  
  - In `src/arch/arm/insts/branch64.hh`, set the macro `IMPEDE_UOP_BRANCH` to `1`.

The µSTT paper introduces two optimizations to improve the performance of the impede micro-op scheme:

1. Speculation Epoch (Enable flag: `--spec-epoch`): Groups loads that become non-speculative at the same time into a *speculation epoch*. This reduces the number of distinct in-flight yrots. As a result, contention on the common data bus decreases.
2. Delay resolution (Enable flag: `--delay-reso`): Instead of using impede micro-ops for branches, this scheme delays the *resolution* of branch instructions until they become the oldest unresolved branch. This approach leverages high branch prediction accuracy to minimize performance impact. ⚠️ Note: To avoid redundant protection, do **not** configure branches to decode into impede micro-ops when using this optimization.

### Micro-architectural Parameters
This work uses the **Firestorm microarchitecture** as the reference model.  
The default parameter set is specified in `stt_config/m1_processor.py`.

The following flags can be used to customize key micro-architectural parameters:
- `--wb-width` — writeback width  
- `--decoder-width` — decode width  
- `--fu` — number of integer functional units  
- `--iq-size` — instruction queue size  

Additional flags can be added to sweep other micro-architectural parameters if needed.

### Other Options
See `stt_config/CustomOptions.py` for additional simulation options.

# Run Simulation on SPEC CPU 2017 Benchmarks
The reference input sets of SPEC CPU 2017 benchmarks are too large to be simulated in Gem5 within a reasonable time.  
To address this, we applied **SimPoint analysis** to divide each program into up to 30 representative segments.  

- Each segment contains **100 million instructions**.  
- Each segment is preceded by a **10 million–instruction warm-up period**.

## Benchmark Folder Structure
An example directory structure for one benchmark is shown below:
```
cpu2017
└── 500.perlbench_r
    ├── run           # Run folder
    ├── command.txt   # Command to run the benchmark
    └── cpt_<num>     # <num>-th reference input
        └── cpt_<id>  # checkpoint <id>
            ├── m5.cpt  # Gem5 register checkpoint
            └── *.pmem  # Gem5 memory checkpoint
```

## Restoring and Parsing
- Use `stt_config/ray_simpoint_restore.py` to **restore checkpoints** for simulation.  
- Use `stt_config/parse_spec_ray.py` to **parse simulation statistics**.
