import argparse
import pdb

from m5.stats import (
    dump,
    reset,
)

import CustomOptions
from m1_processor import (
    M1CacheHierarchy,
    M1Processor,
)

from gem5.components.boards.simple_board import SimpleBoard
from gem5.components.memory import DualChannelDDR4_2400
from gem5.isas import ISA
from gem5.resources.resource import (
    BinaryResource,
    CheckpointResource
)
from gem5.simulate.exit_event import ExitEvent
from gem5.simulate.simulator import Simulator
from gem5.utils.requires import requires

requires(isa_required=ISA.ARM)

parser = argparse.ArgumentParser()
parser.add_argument("--warm", type=int, default=10000000, help="Number of warmup instructions")
parser.add_argument("--interval", type=int, default=100000000, help="Interval of simulation")
parser.add_argument("--mem-size", type=int, default=8, help="Size of main memory (8GB)")
parser.add_argument("--commands", type=str, help="simulation command")
parser.add_argument("--cpt-path", type=str, help="the path to checkpoint")
CustomOptions.addSTTOptions(parser)
args = parser.parse_args()

cache_hierarchy = M1CacheHierarchy()

# Wikipedia, M1 uses LPDDR4X, the closest I found was DDR4 after comparing bandwidth
memory = DualChannelDDR4_2400(size=f"{args.mem_size} GiB")

# We use estimated M1 processor with one Firestorm core.
processor = M1Processor(num_cores=1)

# Pass options to CPU
if args.enable_stt:
    processor.cores[0].core.enableSTT = args.enable_stt
if args.impede_uop:
    processor.cores[0].core.impedeUop = args.impede_uop
if args.enable_delay_acc:
    processor.cores[0].core.enableDelayAcc = args.enable_delay_acc
if args.enable_delay_exec:
    processor.cores[0].core.enableDelayExec = args.enable_delay_exec
if args.spec_epoch:
    processor.cores[0].core.specEpoch = args.spec_epoch
if args.delay_reso:
    processor.cores[0].core.delayReso = args.delay_reso
if args.futuristic_threat_model:
    processor.cores[
        0
    ].core.futuristicThreatModel = args.futuristic_threat_model
if args.print_taint_prop:
    processor.cores[0].core.printTaintProp = args.print_taint_prop
if args.print_rob:
    processor.cores[0].core.printROB = args.print_rob
if args.print_DelayInst:
    processor.cores[0].core.printDelayInst = args.print_DelayInst
# set the writeback width
processor.cores[0].core.wbWidth = args.wb_width
# set the decoder width
processor.cores[0].core.decodeWidth = args.decoder_width
# set the number of integer function units
processor.cores[0].core.fuPool.FUList[0].count = args.fu
# set the number of instruction queue entries
processor.cores[0].core.numIQEntries = args.iq_size

board = SimpleBoard(
    clk_freq="3.2GHz",
    processor=processor,
    memory=memory,
    cache_hierarchy=cache_hierarchy,
)

# parse command
command = args.commands
command = command.split(' >')[0]  # remove stdout and stderr
command = command.split(' ')
binary_path = command[0]
binary_args = command[1:]

board.set_se_binary_workload(
    binary=BinaryResource(local_path=binary_path),
    arguments=binary_args,
    checkpoint=CheckpointResource(local_path=args.cpt_path),
)


def max_inst():
    warmed_up = False
    while True:
        if warmed_up:
            dump()
            print("end of SimPoint interval")
            yield True
        else:
            print("end of warmup, starting to simulate SimPoint")
            warmed_up = True
            # Schedule a MAX_INSTS exit event during the simulation
            simulator.schedule_max_insts(
                args.interval
            )
            # dump()
            reset()
            yield False


simulator = Simulator(
    board=board,
    on_exit_event={ExitEvent.MAX_INSTS: max_inst()},
)

# Schedule a MAX_INSTS exit event before the simulation begins the
# schedule_max_insts function only schedule event when the instruction length
# is greater than 0.
# In here, it schedules an exit event for the first SimPoint's warmup
# instructions
simulator.schedule_max_insts(args.warm)
simulator.run()
