#!/usr/bin/python

import random
import os
import copy

NUM_DECODE = 4
NUM_ARCH = 31
NUM_PHY = 380
DECODE_WIDTH = 2
PHY_WIDTH = 9
ARCH_WIDTH = 5
NUM_TESTS = 100
NUM_USED_REG = min(NUM_ARCH, 3*NUM_DECODE)
DEBUG = True

random.seed(os.urandom(32))
file = open(f'rename_{NUM_DECODE}.input', 'w')

def bin(x, width):
    if x < 0: x = (~x) + 1
    return ''.join([(x & (1 << i)) and '1' or '0' for i in range(width-1, -1, -1)])

def rename_logic(rat_list, phyreg_list, instrs_list):
    # extract write reg
    write_reg = []
    for inst in instrs_list:
        write_reg.append(inst[1])
    # WAW check
    write_en_list = []
    for inst_idx in range(NUM_DECODE):
        # write_en = 1 if there is no dest with same reg id
        if write_reg[inst_idx] in write_reg[inst_idx+1:NUM_DECODE]:
            write_en_list.append('0')
        else:
            write_en_list.append('1')
    write_en_list.reverse()
    write_en = ''.join(write_en_list)

    # generate output instrs
    out_insts = []
    for inst_idx in range(NUM_DECODE):
        p_dest = phyreg_list[inst_idx]
        # old dest phy
        # check if older instr in the same group
        if write_reg[inst_idx] in write_reg[0:inst_idx]:
            # take youngest collison's phyreg
            match_idx = list(reversed(write_reg[0:inst_idx])).index(write_reg[inst_idx])
            old_p_dest = phyreg_list[inst_idx-1-match_idx]
        else:
            # read from rat
            old_p_dest = rat_list[write_reg[inst_idx]]
        # src phy
        src1 = instrs_list[inst_idx][2]
        src2 = instrs_list[inst_idx][3]
        if src1 in write_reg[0:inst_idx]:
            match_idx = list(reversed(write_reg[0:inst_idx])).index(src1)
            p_src1 = phyreg_list[inst_idx-1-match_idx]
        else:
            p_src1 = rat_list[src1]
        if src2 in write_reg[0:inst_idx]:
            match_idx = list(reversed(write_reg[0:inst_idx])).index(src2)
            p_src2 = phyreg_list[inst_idx-1-match_idx]
        else:
            p_src2 = rat_list[src2]

        # out_insts.append([p_dest, old_p_dest, p_src1, p_src2])
        out_insts.append([p_dest, p_src1, p_src2])

    return write_en, out_insts

def update_rat_list(rat_list, instrs_list, out_insts, write_en):
    rat_list_updated = copy.deepcopy(rat_list)

    num_ones = write_en.count("1")

    for i in range(NUM_DECODE):
        # print(write_en[NUM_DECODE - i - 1])
        if write_en[NUM_DECODE - i - 1] == "1": # 1110
            dst = instrs_list[i][1]
            phyreg = out_insts[i][0]
            rat_list_updated[dst] = phyreg # update rat with dst if write en

    num_changed = 0
    for i in range(len(rat_list_updated)):
        if rat_list[i] != rat_list_updated[i]:
            num_changed += 1
    assert num_changed == num_ones, f"num_changed: {num_changed}, num_ones: {num_ones}"

    return rat_list_updated


"""
Generate Rename test vector
Test i+1 stores Test i's output
"""
rat_list = []
last_out_inst = []

# initialize rat with 0~NUM_ARCH-1
for i in range(NUM_ARCH):
    rat_list.append(i)

# initialize last out_inst with 0
for i in range(NUM_DECODE):
    last_out_inst.append([0, 0, 0])
      
for _ in range(NUM_TESTS):
    # randomly generate phyreg
    phyreg_list = []
    phyreg_idx = 0
    while phyreg_idx < NUM_DECODE:
        rand_phyreg = random.randint(0, NUM_PHY-1)
        # avoid duplication (new allocated phyregs should not in rat)
        if rand_phyreg in rat_list or rand_phyreg in phyreg_list:
            continue
        phyreg_list.append(rand_phyreg)
        phyreg_idx += 1
    # randomly generate instr
    instrs_list = []
    for _ in range(NUM_DECODE):
        # [{branch_bit load_bit},dest,src1,src2]
        # branch, load, or others (0~2)
        rand_instr_type = random.randint(0, 2)
        # reg
        dest = random.randint(0, NUM_USED_REG-1)
        src1 = random.randint(0, NUM_USED_REG-1)
        src2 = random.randint(0, NUM_USED_REG-1)
        instr_list = [rand_instr_type, dest, src1, src2]
        # generate instr bit string
        instrs_list.append(instr_list)

    # call rename logic for write_en and out_insts
    write_en, out_insts = rename_logic(rat_list, phyreg_list, instrs_list)
    rat_list_updated = update_rat_list(rat_list, instrs_list, out_insts, write_en)
    if DEBUG:
        print("[+] Input")
        print("input insts:")
        for inst_idx in range(NUM_DECODE):
            rand_instr_type, dest, src1, src2 = instrs_list[inst_idx]
            print(f"({bin(rand_instr_type,2)}) dest: {dest}->{rat_list[dest]}, ",
                  f"src1: {src1}->{rat_list[src1]}, src2: {src2}->{rat_list[src2]}")
        print("phy reg pool:")
        for inst_idx in range(NUM_DECODE):
            print(phyreg_list[inst_idx])
        print("[+] Output:")
        print(f"write_en: {write_en}")
        print("out_insts:")
        for inst_idx in range(NUM_DECODE):
            p_dest, p_src1, p_src2 = out_insts[inst_idx]
            print(f"dest: {p_dest}, src1: {p_src1}, src2: {p_src2}")
        print("updated rat:")
        print(rat_list_updated)
    
    # create bit string
    # test vector
    # [rat[0],...,rat[NUM_ARCH-1],phyreg[0],...,phyreg[NUM_DECODE-1],
    # instr[0],...,instr[NUM_DECODE-1],out_insts[0],...,out_insts[NUM_DECODE-1]]
    rat_bitstr = []
    for reg_idx in range(NUM_ARCH):
        rat_bitstr.append(bin(rat_list[reg_idx], width=PHY_WIDTH))
    rat_bitstr = "".join(rat_bitstr)
    phyreg_bitstr = []
    for inst_idx in range(NUM_DECODE):
        phyreg_bitstr.append(bin(phyreg_list[inst_idx], width=PHY_WIDTH))
    phyreg_bitstr = "".join(phyreg_bitstr)
    instrs_bitstr = []
    for inst_idx in range(NUM_DECODE):
        instr_bitstr = []
        instr_bitstr.append(bin(instrs_list[inst_idx][0], width=2))
        instr_bitstr.append(bin(instrs_list[inst_idx][1], width=ARCH_WIDTH))
        instr_bitstr.append(bin(instrs_list[inst_idx][2], width=ARCH_WIDTH))
        instr_bitstr.append(bin(instrs_list[inst_idx][3], width=ARCH_WIDTH))
        instrs_bitstr.append("".join(instr_bitstr))
    instrs_bitstr = "".join(instrs_bitstr)
    out_insts_bitstr = []
    for inst_idx in range(NUM_DECODE):
        out_inst_bitstr = []
        out_inst_bitstr.append(bin(last_out_inst[inst_idx][0], width=PHY_WIDTH))
        out_inst_bitstr.append(bin(last_out_inst[inst_idx][1], width=PHY_WIDTH))
        out_inst_bitstr.append(bin(last_out_inst[inst_idx][2], width=PHY_WIDTH))
        out_insts_bitstr.append("".join(out_inst_bitstr))
    out_insts_bitstr = "".join(out_insts_bitstr)
    file.write("".join([rat_bitstr, phyreg_bitstr, instrs_bitstr, out_insts_bitstr]) + '\n')

    # update output
    rat_list = rat_list_updated
    last_out_inst = copy.deepcopy(out_insts)

file.close()
