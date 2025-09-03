import pdb
import subprocess
import os
import argparse
import CustomOptions
import ray
import shutil

GEM5_BUILD = "../../../../STTplusplus/build/ARM/gem5.fast"
SIMPOINT_CONFIG = "../../../../STTplusplus/stt_config/simpoint_restore.py"

def get_file_paths(root_folder):
    file_paths = []
    for root, dirs, files in os.walk(root_folder):
        for file in files:
            file_paths.append(os.path.join(root, file))
    return file_paths

ray.init()
@ray.remote
def gem5_worker(test_name, count, sp_idx, cmd):
    os.chdir(f"../cpu2017/{test_name}/run_{count}_{sp_idx}/run_base_refrate_static-64.0000")
    print(f"Simulating {test_name}_{count} (simpoint {sp_idx})")
    old_files = get_file_paths(".")
    process = subprocess.Popen(cmd, shell=True)
    _, stderr = process.communicate()
    return_code = process.returncode
    if return_code != 0:
        print(f"gem5 simulation error {test_name} (simpoint {sp_idx})")
        print(stderr)
    else:
        print(f"gem5 simulation finished {test_name} (simpoint {sp_idx})")
    new_files = get_file_paths(".")
    for file in new_files:
        if file not in old_files:
            os.remove(file)
    os.chdir("../../../../STTplusplus")

parser = argparse.ArgumentParser()
parser.add_argument('-m', '--mem-size', type=int, default=8,
                    help='Memory size in GB')
parser.add_argument("--cpu", nargs='+', type=int, default=[], help="Specific list of CPU")
parser.add_argument("--ncpu", type=int, default=1, help="Number of avaiable CPU")
parser.add_argument("--warm", type=int, default=10000000, help="Number of warmup instructions")
parser.add_argument("--interval", type=int, default=100000000, help="Interval of simulation")
parser.add_argument("--ben", nargs='+', type=str, default=[])
parser.add_argument("--firstrun", action="store_true", help="Only run the first input")
parser.add_argument("--name", type=str, default="", help="Name of the experiment")
CustomOptions.addSTTOptions(parser)
args = parser.parse_args()

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

# exam all inputs bench
if len(args.ben) == 0:
    print("Test All benchmarks!")
else:
    for ben in args.ben:
        if ben[:-2] not in spec2017_list:
            pdb.set_trace()
            print(f"Bench {ben[:-2]} does not match any in SPEC CPU 2017!")
            exit(1) 

# collect all tasks
task_list = []

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

# grabe the test commands
# format
# (test_name, count, [(sp_idx,cmd1), ...])
for test_name in spec2017_list:
    base_path = f"../cpu2017/{test_name}"
    # open command file
    with open(f"{base_path}/command.txt", "r") as f_cmd:
        cmd_file_lines = f_cmd.readlines()
    count = 0
    # traverse inputs of each benchmark
    for cmd_line in cmd_file_lines:
        if cmd_line.startswith("../"):
            # open simpoint file
            with open(f"{base_path}/{test_name}_{count}.simpoints", "r") as f_sp:
                sp_lines = f_sp.readlines()
            # traverse simpoints
            for sp_line in sp_lines:
                sp_idx = int(sp_line.split()[0])
                cmd_tmp = f"{GEM5_BUILD} -re --outdir=../../{out_dir}/out_{count}/out_{sp_idx} " \
                    + f"{SIMPOINT_CONFIG} --commands '{cmd_line.strip()}' " \
                    + f"--cpt-path=../../cpt_{count}/cpt_{sp_idx}  --warm {args.warm} " \
                    + f"--interval {args.interval} --mem-size {args.mem_size}"
                cmd_tmp += cmd_suffix
                # create a run for each simpoint
                # src_path = f"{base_path}/run"
                # dst_path = f"{base_path}/run_{count}_{sp_idx}"
                # try:
                #     shutil.copytree(src_path, dst_path)
                # except FileExistsError:
                #     print(f"Directory {dst_path} already exists. Skipping copy.")
            
                # comment out below ray worker if just to copy folders
                if len(args.ben) == 0:
                    task_list.append(gem5_worker.remote(test_name, count, sp_idx, cmd_tmp))
                else:
                    if f"{test_name}_{count}" in args.ben:
                        task_list.append(gem5_worker.remote(test_name, count, sp_idx, cmd_tmp))
            if args.firstrun:
                break
            count += 1

ray.get(task_list)
