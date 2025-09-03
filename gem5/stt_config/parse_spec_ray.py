import json
import argparse
import CustomOptions
import os
import ray
import pdb

GEM5_BUILD = "../../../../STTplusplus/build/ARM/gem5.fast"
SIMPOINT_CONFIG = "../../../../STTplusplus/stt_config/simpoint_restore.py"

stats_list = [
    "board.processor.cores.core.numCycles",
    "board.processor.cores.core.memInstsDelayed",
    "board.processor.cores.core.ctrlInstsDelayed",
    "board.processor.cores.core.impedeUopDelayed",
    "board.processor.cores.core.commitStats0.numLoadInsts",
    "board.processor.cores.core.commitStats0.numStoreInsts",
    "board.processor.cores.core.commitStats0.numImpedeUop",
    "board.processor.cores.core.commitStats0.committedControl::IsControl",
    "board.processor.cores.core.iew.maxSpecEpochListSize",
    "board.processor.cores.core.statFuBusy::IntAlu",
    "board.processor.cores.core.iew.wbRate",
    "board.processor.cores.core.branchPred.condPredicted",
    "board.processor.cores.core.branchPred.condIncorrect",
    "board.processor.cores.core.iew.memOrderViolationEvents",
    "board.processor.cores.core.rename.IQFullEvents",
    "board.processor.cores.core.commitStats0.numOps"
]

# spec 2017 workload list
spec2017_list = [
    "500.perlbench_r","502.gcc_r", \
    "503.bwaves_r", "505.mcf_r", "507.cactuBSSN_r", "508.namd_r", \
    "510.parest_r", "511.povray_r", "519.lbm_r", "520.omnetpp_r", \
    "521.wrf_r", "523.xalancbmk_r", "525.x264_r", "526.blender_r", \
    "527.cam4_r", "531.deepsjeng_r", "538.imagick_r", "541.leela_r", \
    "544.nab_r", "548.exchange2_r", "549.fotonik3d_r", "554.roms_r", \
    "557.xz_r"
]

# function to print the stats
def extract_stats(path: str):
    stats = {}
    with open(path, 'r') as f:
        for line in f:
            if any(stat in line for stat in stats_list):
                key, value = line.split()[:2]
                stats[key.split('.')[-1]] = float(value)
    return stats

ray.init()
@ray.remote
def parse_worker(args, base_path, out_dir, test_name, count, cmd_line, cmd_suffix):
    # open simpoint file
    with open(f"{base_path}/{test_name}_{count}.simpoints", "r") as f_sp:
        sp_lines = f_sp.readlines()
    with open(f"{base_path}/{test_name}_{count}.weights", "r") as f_wt:
        wt_lines = f_wt.readlines()
    sum_weights = 0
    json_out = {}
    json_out["error"] = []
    json_out["error_cmd"] = []
    # traverse simpoints
    for sp_line, wt_line in zip(sp_lines, wt_lines):
        sp_idx = int(sp_line.split()[0])
        sp_wt = float(wt_line.split()[0])
        # extract stats
        stats_path = f"{base_path}/{out_dir}/out_{count}/out_{sp_idx}/stats.txt"
        simerr_path = f"{base_path}/{out_dir}/out_{count}/out_{sp_idx}/simerr.txt"
        # check if stats file exists
        if not os.path.exists(stats_path):
            print(f"Stats file not found: {stats_path}")
            continue
        stats = extract_stats(f"{base_path}/{out_dir}/out_{count}/out_{sp_idx}/stats.txt")
        # check if errors
        if len(stats) == 0:
            cmd_tmp = f"{GEM5_BUILD} -re --outdir=../../{out_dir}/out_{count}/out_{sp_idx} " \
                + f"{SIMPOINT_CONFIG} --commands '{cmd_line.strip()}' " \
                + f"--cpt-path=../../cpt_{count}/cpt_{sp_idx}  --warm {args.warm} " \
                + f"--interval {args.interval} --mem-size {args.mem_size}"
            cmd_tmp += cmd_suffix
            json_out["error_cmd"].append(cmd_tmp)
            json_out["error"].append(sp_idx)
            # check simerr for unknown errors
            with open(simerr_path, 'r') as f:
                simerr_lines = f.readlines()
            known_error_flag = False
            for line in simerr_lines:
                if "Page table fault when accessing virtual address 0xfffff7ffd000" in line:
                    known_error_flag = True
                    break
            if not known_error_flag:
                print(f"Unknown error for {test_name}_{count} {sp_idx}")
        else:
            sum_weights += sp_wt
            # add stats to json
            for key in stats.keys():
                if key not in json_out:
                    json_out[key] = 0
                json_out[key] += stats[key] * sp_wt
    # normalize json
    for key in json_out.keys():
        if key not in ["error", "error_cmd"]:
            json_out[key] /= sum_weights
    with open(f"{base_path}/{out_dir}/out_{count}/stats.json", 'w') as f:
        json.dump(json_out, f, indent=4)

parser = argparse.ArgumentParser()
parser.add_argument('-m', '--mem-size', type=int, default=8,
                    help='Memory size in GB')
parser.add_argument("--warm", type=int, default=10000000, help="Number of warmup instructions")
parser.add_argument("--interval", type=int, default=100000000, help="Interval of simulation")
parser.add_argument("--ben", nargs='+', type=str, default=[])
parser.add_argument("--firstrun", action="store_true", help="Only run the first input")
parser.add_argument("--name", type=str, default="", help="Name of the experiment")
CustomOptions.addSTTOptions(parser)
args = parser.parse_args()

# parse gem5 config
out_dir = "result"
cmd_suffix = ""
if args.enable_stt:
    cmd_suffix += " --enable-stt"
    out_dir += "_stt"
if args.impede_uop:
    cmd_suffix += " --impede-uop"
    out_dir += "_impede"
if args.enable_delay_acc:
    cmd_suffix += " --enable-delay-acc"
    out_dir += "_delayacc"
if args.enable_delay_exec:
    cmd_suffix += " --enable-delay-exec"
    out_dir += "_delayexec"
if args.spec_epoch:
    cmd_suffix += " --spec-epoch"
    out_dir += "_specepoch"
if args.delay_reso:
    cmd_suffix += " --delay-reso"
    out_dir += "_delayreso"
if args.futuristic_threat_model:
    cmd_suffix += " --futuristic-threat-model"
    out_dir += "_future"
if args.print_taint_prop:
    cmd_suffix += " --print-taint-prop"
if args.print_rob:
    cmd_suffix += " --print-rob"
if args.print_DelayInst:
    cmd_suffix += " --print-DelayInst"
cmd_suffix += f" --wb-width {args.wb_width}"
cmd_suffix += f" --decoder-width {args.decoder_width}"
cmd_suffix += f" --fu {args.fu}"
cmd_suffix += f" --iq-size {args.iq_size}"
out_dir += f"_fu{args.fu}"
out_dir += f"_wb{args.wb_width}"
out_dir += f"_dec{args.decoder_width}"
out_dir += f"_iq{args.iq_size}"
if args.name != "":
    out_dir += f"_{args.name}"

# parse_worker(args, base_path, out_dir, test_name, count, cmd_line, cmd_suffix)
task_list = []
for test_name in spec2017_list:
    base_path = f"../cpu2017/{test_name}"
    # open command file
    with open(f"{base_path}/command.txt", "r") as f_cmd:
        cmd_file_lines = f_cmd.readlines()
    count = 0
    # traverse inputs of each benchmark
    for cmd_line in cmd_file_lines:
        if cmd_line.startswith("../"):
            task_list.append(parse_worker.remote(args, base_path, out_dir, test_name, count, cmd_line, cmd_suffix))
            if args.firstrun:
                break
            count += 1

ray.get(task_list)
