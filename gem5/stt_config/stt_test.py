# Copyright (c) 2021 The Regents of the University of California
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met: redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer;
# redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution;
# neither the name of the copyright holders nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

"""
This gem5 configuation script creates a simple board to run an ARM
"hello world" binary.

This is setup is the close to the simplest setup possible using the gem5
library. It does not contain any kind of caching, IO, or any non-essential
components.
"""

import argparse

import CustomOptions
from m1_processor import (
    M1CacheHierarchy,
    M1Processor,
)

from gem5.components.boards.simple_board import SimpleBoard
from gem5.components.cachehierarchies.classic.no_cache import NoCache
from gem5.components.memory import DualChannelDDR4_2400
from gem5.isas import ISA
from gem5.resources.resource import (
    BinaryResource,
    obtain_resource,
)
from gem5.simulate.simulator import Simulator
from gem5.utils.requires import requires

# This check ensures the gem5 binary is compiled to the ARM ISA target. If not,
# an exception will be thrown.
requires(isa_required=ISA.ARM)

parser = argparse.ArgumentParser()
CustomOptions.addSTTOptions(parser)
args = parser.parse_args()

cache_hierarchy = M1CacheHierarchy()

# Wikipedia, M1 uses LPDDR4X, the closest I found was DDR4 after comparing bandwidth
memory = DualChannelDDR4_2400(size="32MB")

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

# The gem5 library simble board which can be used to run simple SE-mode
# simulations.
board = SimpleBoard(
    clk_freq="3.2GHz",
    processor=processor,
    memory=memory,
    cache_hierarchy=cache_hierarchy,
)

# Simplest test workload
board.set_se_binary_workload(
    # obtain_resource("arm-bubblesort")
    obtain_resource("arm-hello64-static")
)

# Lastly we run the simulation.
simulator = Simulator(board=board)
simulator.run()

print(
    "Exiting @ tick {} because {}.".format(
        simulator.get_current_tick(), simulator.get_last_exit_event_cause()
    )
)
