# Evaluation: Age Matrix Scheme

This work proposes a shallow taint propagation circuit, called the **Age Matrix**, which eliminates much of the logic delay overhead in prior STT designs.  

This repository includes the Verilog source code for:
- The baseline Rename circuit  
- The original STT taint propagation circuit  
- The proposed Age Matrix circuit  

# Overview of Files

## Source Code
The `src` directory contains Verilog source code for the three circuits:

- **Rename Circuit**
  - `pe.v`: Priority Encoder module  
  - `eq_comp.v`: Equality Comparator network with priority encoder  
  - `reg.v`: Register module  
  - `rename.v`: Rename circuit module  
  - `rename_testbench.v`: Testbench for the Rename circuit  

- **Original STT Circuit**
  - `stt_og.v`: Original STT taint propagation circuit module  
  - `younger.v`: "Younger-than" comparators and speculation epoch generator  
  - `stt_og_testbench.v`: Testbench for the original STT circuit  
  - Rename circuit modules (same as above)  

- **Age Matrix Circuit**
  - `stt_age.v`: Age Matrix taint propagation circuit module  
  - `stt_control.v`: Yrot Dependency Graph generator  
  - `stt_age_testbench.v`: Testbench for the Age Matrix circuit  
  - Rename circuit modules (same as above)  

## Test Generator
The `test` directory contains Python scripts for generating random test cases (`*.input` files), which are loaded by the Verilog testbenches:

- `test/RenameTestGen.py`: Generates tests for the Rename circuit  
- `test/OGSTTTestGen.py`: Generates tests for the original STT circuit  
- `test/STTTestGen.py`: Generates tests for the Age Matrix circuit  
