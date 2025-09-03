"""
firestorm p core

Dougall Johnson(DJ): https://dougallj.github.io/applecpu/firestorm.html
Maynard Handley(MH) (Vol1: M1 Explainer): https://github.com/name99-org/AArch64-Explore/blob/main/vol1%20M1%20Explainer.nb.pdf
Maynard Handley(MH) (Vol4: Instruction Fetch): https://github.com/name99-org/AArch64-Explore/blob/main/Vol4%20Instruction%20Fetch.nb.pdf
Dougall Johnson(DJ) blog: https://dougallj.wordpress.com/2021/04/08/apple-m1-load-and-store-queue-measurements/
S2C paper: https://www.usenix.org/system/files/usenixsecurity23-yu-jiyong.pdf
"""

from m5.objects import (
    TAGE,
    ArmO3CPU,
    BadAddr,
    BaseXBar,
    Cache,
    DefaultFUPool,
    L2XBar,
    Port,
    SystemXBar,
)

from gem5.components.boards.abstract_board import AbstractBoard
from gem5.components.cachehierarchies.abstract_cache_hierarchy import (
    AbstractCacheHierarchy,
)
from gem5.components.cachehierarchies.classic.abstract_classic_cache_hierarchy import (
    AbstractClassicCacheHierarchy,
)
from gem5.components.cachehierarchies.classic.caches.l1dcache import L1DCache
from gem5.components.cachehierarchies.classic.caches.l1icache import L1ICache
from gem5.components.cachehierarchies.classic.caches.l2cache import L2Cache
from gem5.components.cachehierarchies.classic.caches.mmu_cache import MMUCache
from gem5.components.processors.base_cpu_core import BaseCPUCore
from gem5.components.processors.base_cpu_processor import BaseCPUProcessor
from gem5.isas import ISA
from gem5.utils.override import *


class M1FirestormCore(BaseCPUCore):
    def __init__(self):
        super().__init__(ArmO3CPU(), ISA.ARM)
        backend_capacity_factor = 1
        # DJ, "pipeline overview" diagram shows decode width is 8 --> reasonable to have a fetch width that is similar
        self.core.fetchWidth = 8
        # DJ, "pipeline overview" diagram shows decode width is 8
        self.core.decodeWidth = 8
        # DJ, "pipeline overview" diagram shows "Map and Rename" takes in 8 uops
        # MH page 30, rename and decode has same width
        self.core.renameWidth = 8
        # DJ,  "pipeline overview" diagram 6 uop integer instr, 4 uop memory instr, 4 for SIMD,FP
        self.core.dispatchWidth = 8
        # DJ, "pipeline overview" allows Firestorm to sustain 11 issues per cycle in contrived cases
        self.core.issueWidth = 8
        # Consistent with commit width
        self.core.wbWidth = 8
        # DJ, "Completion, and the Reorder Buffer(ROB)" section mentions uops are coalesces into retire groups up to 8 uops
        self.core.commitWidth = 8
        # checked FuncUnitConfig.py file and count is relatively the same as the number of functional units in dj
        self.core.fuPool = DefaultFUPool()
        self.core.fuPool.FUList[0].count = self.core.fuPool.FUList[0].count * backend_capacity_factor
        # increased time buffer to 40 as increase in size of other stages require a larger time buffer size
        self.core.backComSize = 40
        self.core.forwardComSize = 40
        # DJ Blog, "Fighting Stores with Square-Roots" section mentions load queues were measured to have 130 entries
        self.core.LQEntries = 130
        # DJ Blog, "Fighting Stores with Square-Roots" section mentions store queues were measured to have 60 entries
        self.core.SQEntries = 60
        # DJ, "Completion, and the Reorder Buffer(ROB)" mentions that Firestorm uses an unconventional reorder buffer
        self.core.numRobs = 1
        # DJ, "Other limits" section mentions the integer physical register file size is 380-394
        self.core.numPhysIntRegs = 380 * backend_capacity_factor
        # DJ, "Other limits" section mentions FP/SIMD physical register file is 432 --> divided into 2
        self.core.numPhysFloatRegs = 216 * backend_capacity_factor
        # DJ, "Other limits" section mentions FP/SIMD physical register file is 432 --> divided into 2
        self.core.numPhysVecRegs = 216 * backend_capacity_factor
        # DJ, "Other limits" section mentions flags physical register file size is 128
        self.core.numPhysCCRegs = 128 * backend_capacity_factor
        # MH Vol4 page 5, mentions 120 entries for the instruction queue
        self.core.numIQEntries = 120 * backend_capacity_factor
        # MH Vol1 page 113, mentions ROB has 330 rows with 7 instructions each, but only one slot is used
        self.core.numROBEntries = 330 * backend_capacity_factor
        # S2C paper page 4, mentions m1 doesn't implement smt --> left as default
        self.core.smtNumFetchingThreads = 1
        # MH Vol4 page 53, explains about a reduced power TAGE branch predictor
        self.core.branchPred = TAGE()


class M1Processor(BaseCPUProcessor):
    def __init__(self, num_cores: int):
        cores = [M1FirestormCore() for i in range(num_cores)]
        super().__init__(cores)


class M1CacheHierarchy(AbstractClassicCacheHierarchy):
    """
    A cache setup where each core has a private L1 Data and Instruction Cache,
    and a L2 cache is shared with all cores. The shared L2 cache is mostly
    inclusive with respect to the split I/D L1 and MMU caches.
    """

    @staticmethod
    def _get_default_membus() -> SystemXBar:
        """
        A method used to obtain the default memory bus of 64 bit in width for
        the PrivateL1SharedL2 CacheHierarchy.

        :returns: The default memory bus for the PrivateL1SharedL2
                  CacheHierarchy.

        :rtype: SystemXBar
        """
        membus = SystemXBar(width=64)
        membus.badaddr_responder = BadAddr()
        membus.default = membus.badaddr_responder.pio
        return membus

    def __init__(
        self,
        membus: BaseXBar = _get_default_membus.__func__(),
    ) -> None:
        AbstractClassicCacheHierarchy.__init__(self=self)
        # parameters from PACMAN and S2C paper
        self._l1i_size = "192kB"
        self._l1i_assoc = 6
        self._l1d_size = "128kB"
        self._l1d_assoc = 8
        self._l1_tag_latency = 2
        self._l1_data_latency = 2
        self._l1_response_latency = 2
        self._l1_mshrs = 4
        self._l1_tgts_per_mshr = 20
        self._l2_size = "12MB"
        self._l2_assoc = 12
        self._l2_tag_latency = 20
        self._l2_data_latency = 20
        self._l2_response_latency = 20
        self._l2_mshrs = 20
        self._l2_tgts_per_mshr = 12
        self.membus = membus

    @overrides(AbstractClassicCacheHierarchy)
    def get_mem_side_port(self) -> Port:
        return self.membus.mem_side_ports

    @overrides(AbstractClassicCacheHierarchy)
    def get_cpu_side_port(self) -> Port:
        return self.membus.cpu_side_ports

    @overrides(AbstractCacheHierarchy)
    def incorporate_cache(self, board: AbstractBoard) -> None:
        # Set up the system port for functional access from the simulator.
        board.connect_system_port(self.membus.cpu_side_ports)

        for _, port in board.get_memory().get_mem_ports():
            self.membus.mem_side_ports = port

        self.l1icaches = [
            L1ICache(
                size=self._l1i_size,
                assoc=self._l1i_assoc,
                tag_latency=self._l1_tag_latency,
                data_latency=self._l1_data_latency,
                response_latency=self._l1_response_latency,
                mshrs=self._l1_mshrs,
                tgts_per_mshr=self._l1_tgts_per_mshr,
                writeback_clean=False,
            )
            for i in range(board.get_processor().get_num_cores())
        ]
        self.l1dcaches = [
            L1DCache(
                size=self._l1d_size,
                assoc=self._l1d_assoc,
                tag_latency=self._l1_tag_latency,
                data_latency=self._l1_data_latency,
                response_latency=self._l1_response_latency,
                mshrs=self._l1_mshrs,
                tgts_per_mshr=self._l1_tgts_per_mshr,
                writeback_clean=False,
            )
            for i in range(board.get_processor().get_num_cores())
        ]
        self.l2bus = L2XBar()
        self.l2cache = L2Cache(
            size=self._l2_size,
            assoc=self._l2_assoc,
            tag_latency=self._l2_tag_latency,
            data_latency=self._l2_data_latency,
            response_latency=self._l2_response_latency,
            mshrs=self._l2_mshrs,
            tgts_per_mshr=self._l2_tgts_per_mshr,
        )
        # ITLB Page walk caches
        self.iptw_caches = [
            MMUCache(size="8KiB", writeback_clean=False)
            for _ in range(board.get_processor().get_num_cores())
        ]
        # DTLB Page walk caches
        self.dptw_caches = [
            MMUCache(size="8KiB", writeback_clean=False)
            for _ in range(board.get_processor().get_num_cores())
        ]

        if board.has_coherent_io():
            self._setup_io_cache(board)

        for i, cpu in enumerate(board.get_processor().get_cores()):
            cpu.connect_icache(self.l1icaches[i].cpu_side)
            cpu.connect_dcache(self.l1dcaches[i].cpu_side)

            self.l1icaches[i].mem_side = self.l2bus.cpu_side_ports
            self.l1dcaches[i].mem_side = self.l2bus.cpu_side_ports
            self.iptw_caches[i].mem_side = self.l2bus.cpu_side_ports
            self.dptw_caches[i].mem_side = self.l2bus.cpu_side_ports

            cpu.connect_walker_ports(
                self.iptw_caches[i].cpu_side, self.dptw_caches[i].cpu_side
            )

            if board.get_processor().get_isa() == ISA.X86:
                int_req_port = self.membus.mem_side_ports
                int_resp_port = self.membus.cpu_side_ports
                cpu.connect_interrupt(int_req_port, int_resp_port)
            else:
                cpu.connect_interrupt()

        self.l2bus.mem_side_ports = self.l2cache.cpu_side
        self.membus.cpu_side_ports = self.l2cache.mem_side

    def _setup_io_cache(self, board: AbstractBoard) -> None:
        """Create a cache for coherent I/O connections"""
        self.iocache = Cache(
            assoc=8,
            tag_latency=50,
            data_latency=50,
            response_latency=50,
            mshrs=20,
            size="1kB",
            tgts_per_mshr=12,
            addr_ranges=board.mem_ranges,
        )
        self.iocache.mem_side = self.membus.cpu_side_ports
        self.iocache.cpu_side = board.get_mem_side_coherent_io_port()
