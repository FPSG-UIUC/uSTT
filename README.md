# µSTT
This repository contains the open-source code for our ICCD 2025 paper: *µSTT: Microarchitecture Design for Speculative Taint Tracking*.

## Introduction
µSTT analyzes the hardware complexity of the state-of-the-art hardware-based Spectre mitigation, [Speculative Taint Tracking (STT)](https://dl.acm.org/doi/10.1145/3352460.3358274), and identifies two key challenges:  
1. Logic delay in taint propagation  
2. Area overhead from instruction delaying  

To address these challenges, µSTT introduces two new mechanisms: **Age Matrix** and **impede micro-op**.

## Source Code Overview
This repository comprises the following artifacts:
```
.
├── gem5: Impede Micro-op evaluation in Gem5.
└── rtl: Age Matrix evaluation in RTL.
```

## Citation
If you use this repository in your work, please cite:

```bibtex
@inproceedings{chen2025ustt,
    title={µSTT: Microarchitecture Design for Speculative Taint Tracking},
    author={Boru Chen and Rutvik Choudhary and Kaustubh Khulbe and Archie Lee and Adam Morrison and Christopher W. Fletcher},
    booktitle={2024 IEEE 42nd International Conference on Computer Design (ICCD)},
    year={2024}
}
```
    