//=========================================================================
// OG STT (baseline) Test Bench
//-------------------------------------------------------------------------
`define TESTSYN
`define CLOCK_PERIOD    28.00
// test config
`define NUM_DECODE      10
`define NUM_ARCH        31
`define NUM_PHY         380
`define DECODE_WIDTH    4
`define PHY_WIDTH       9
`define ARCH_WIDTH      5
`define NUM_ROB         512
`define YROT_WIDTH      9

module stt_testbench;

    // test case
    reg reset;
    wire [`PHY_WIDTH*`NUM_DECODE-1:0] phyreg_flatten;
    wire [(3*`ARCH_WIDTH+2)*`NUM_DECODE-1:0] insts_flatten;
    wire [`PHY_WIDTH*`NUM_ARCH-1:0] rat_flatten;
    wire [4*`PHY_WIDTH*`NUM_DECODE-1:0] out_insts_flatten;
    wire [`YROT_WIDTH*`NUM_ARCH-1:0] yrot_table_flatten;
    wire [`YROT_WIDTH*`NUM_DECODE-1:0] younger_outputs_flatten;
    wire [4*`PHY_WIDTH*`NUM_DECODE-1:0] out_insts_ref_flatten;
    wire [`YROT_WIDTH*`NUM_DECODE-1:0] younger_outputs_ref_flatten;
    wire [`PHY_WIDTH-1:0] phyreg [`NUM_DECODE-1:0];
    wire [3*`ARCH_WIDTH+1:0] insts [`NUM_DECODE-1:0];
    wire [`PHY_WIDTH-1:0] rat [`NUM_ARCH-1:0];
    wire [`YROT_WIDTH-1:0] yrot_table [`NUM_ARCH-1:0];
    wire [2*`YROT_WIDTH-1:0] branch_ptr;
    wire [4*`PHY_WIDTH-1:0] out_insts [`NUM_DECODE-1:0];
    wire [`YROT_WIDTH-1:0] younger_outputs [`NUM_DECODE-1:0];
    wire [4*`PHY_WIDTH-1:0] out_insts_ref [`NUM_DECODE-1:0];
    wire [`YROT_WIDTH-1:0] younger_outputs_ref [`NUM_DECODE-1:0];
    

    //--------------------------------------------------------------------
    // Setup a clock
    //--------------------------------------------------------------------
    reg clk = 0;
    always #(`CLOCK_PERIOD/2) clk = ~clk;

    //--------------------------------------------------------------------
    // Check procedure
    //--------------------------------------------------------------------
`ifdef TESTSYN
    task checkOutput;
        if ((out_insts !== out_insts_ref)
            || (younger_outputs !== younger_outputs_ref)) begin
            integer k;
            $display("[FAIL]");
            // dump input
            $display("[+] Input:");
            // Branch pointer
            $display("Branch head: %d, Branch tail: %d",
                branch_ptr[2*`YROT_WIDTH-1:`YROT_WIDTH],
                branch_ptr[`YROT_WIDTH-1:0]);
            // insts
            $display("input insts:");
            for (k = 0; k < `NUM_DECODE; k = k+1) begin
                $display("(%b) dest: %d -> %d (%d), src1: %d -> %d (%d), src2: %d -> %d (%d)",
                    insts[k][3*`ARCH_WIDTH+1:3*`ARCH_WIDTH],
                    insts[k][3*`ARCH_WIDTH-1:2*`ARCH_WIDTH],
                    rat[insts[k][3*`ARCH_WIDTH-1:2*`ARCH_WIDTH]],
                    yrot_table[insts[k][3*`ARCH_WIDTH-1:2*`ARCH_WIDTH]],
                    insts[k][2*`ARCH_WIDTH-1:`ARCH_WIDTH],
                    rat[insts[k][2*`ARCH_WIDTH-1:`ARCH_WIDTH]],
                    yrot_table[insts[k][2*`ARCH_WIDTH-1:`ARCH_WIDTH]],
                    insts[k][`ARCH_WIDTH-1:0],
                    rat[insts[k][`ARCH_WIDTH-1:0]],
                    yrot_table[insts[k][`ARCH_WIDTH-1:0]]);
            end
            // allocated phyiscal reg
            $display("phy reg pool:");
            for (k = 0; k < `NUM_DECODE; k = k+1) begin
                $display("%d", phyreg[k]);
            end
            // dump output
            $display("[+] Output:");
            // out_insts
            $display("out_insts:");
            for (k = 0; k < `NUM_DECODE; k = k+1) begin
                $display("dest: %d/%d, src1: %d/%d, src2: %d/%d, yrot: %d/%d", 
                    out_insts[k][3*`PHY_WIDTH-1:2*`PHY_WIDTH],
                    out_insts_ref[k][3*`PHY_WIDTH-1:2*`PHY_WIDTH],
                    out_insts[k][2*`PHY_WIDTH-1:`PHY_WIDTH],
                    out_insts_ref[k][2*`PHY_WIDTH-1:`PHY_WIDTH],
                    out_insts[k][`PHY_WIDTH-1:0],
                    out_insts_ref[k][`PHY_WIDTH-1:0],
                    younger_outputs[k],
                    younger_outputs_ref[k]);
            end
            $finish();
        end
        else begin
            $display("[PASS]");
        end
    endtask
`else
    task checkOutput;
        if ((out_insts !== out_insts_ref) || (rat != dut.rat) || (yrot_table !== dut.yrot_table)
            || (younger_outputs !== younger_outputs_ref)) begin
            integer k;
            $display("[FAIL]");
            // dump input
            $display("[+] Input:");
            // rat
            $display("rat:");
            for (k = 0; k < `NUM_ARCH; k = k+1) begin
                $display("%d/%d", dut.rat[k], rat[k]);
            end
            // yrot table
            $display("yrot table:");
            for (k = 0; k < `NUM_ARCH; k = k+1) begin
                $display("[%b]%d/[%b]%d", 
                    dut.yrot_table[k][`YROT_WIDTH],
                    dut.yrot_table[k][`YROT_WIDTH-1:0],
                    yrot_table[k][`YROT_WIDTH],
                    yrot_table[k][`YROT_WIDTH-1:0]);
            end
            // Branch pointer
            $display("Branch head: %d, Branch tail: %d",
                branch_ptr[2*`YROT_WIDTH-1:`YROT_WIDTH],
                branch_ptr[`YROT_WIDTH-1:0]);
            // insts
            $display("input insts:");
            for (k = 0; k < `NUM_DECODE; k = k+1) begin
                $display("(%b) dest: %d -> %d (%d), src1: %d -> %d (%d), src2: %d -> %d (%d)",
                    insts[k][3*`ARCH_WIDTH+1:3*`ARCH_WIDTH],
                    insts[k][3*`ARCH_WIDTH-1:2*`ARCH_WIDTH],
                    rat[insts[k][3*`ARCH_WIDTH-1:2*`ARCH_WIDTH]],
                    yrot_table[insts[k][3*`ARCH_WIDTH-1:2*`ARCH_WIDTH]],
                    insts[k][2*`ARCH_WIDTH-1:`ARCH_WIDTH],
                    rat[insts[k][2*`ARCH_WIDTH-1:`ARCH_WIDTH]],
                    yrot_table[insts[k][2*`ARCH_WIDTH-1:`ARCH_WIDTH]],
                    insts[k][`ARCH_WIDTH-1:0],
                    rat[insts[k][`ARCH_WIDTH-1:0]],
                    yrot_table[insts[k][`ARCH_WIDTH-1:0]]);
            end
            // allocated phyiscal reg
            $display("phy reg pool:");
            for (k = 0; k < `NUM_DECODE; k = k+1) begin
                $display("%d", phyreg[k]);
            end
            // dump output
            $display("[+] Output:");
            // out_insts
            $display("out_insts:");
            for (k = 0; k < `NUM_DECODE; k = k+1) begin
                $display("dest: %d/%d, src1: %d/%d, src2: %d/%d, yrot: %d/%d", 
                    out_insts[k][3*`PHY_WIDTH-1:2*`PHY_WIDTH],
                    out_insts_ref[k][3*`PHY_WIDTH-1:2*`PHY_WIDTH],
                    out_insts[k][2*`PHY_WIDTH-1:`PHY_WIDTH],
                    out_insts_ref[k][2*`PHY_WIDTH-1:`PHY_WIDTH],
                    out_insts[k][`PHY_WIDTH-1:0],
                    out_insts_ref[k][`PHY_WIDTH-1:0],
                    younger_outputs[k],
                    younger_outputs_ref[k]);
            end
            $finish();
        end
        else begin
            $display("[PASS]");
        end
    endtask
`endif
    //--------------------------------------------------------------------
    // Setup a DUT
    //--------------------------------------------------------------------
    stt_og #(
        .NUM_DECODE(`NUM_DECODE),
        .NUM_PHY(`NUM_PHY),
        .NUM_ARCH(`NUM_ARCH),
        .NUM_ROB(`NUM_ROB)
    ) dut (
        .clk(clk),
        .rst(reset),
        .phyreg_flatten(phyreg_flatten),
        .insts_flatten(insts_flatten),
        .branch_ptr(branch_ptr),
        .out_insts_flatten_buf(out_insts_flatten),
        .younger_outputs_flatten_buf(younger_outputs_flatten)
    );

    // test vector
    // [rat[0],...,rat[NUM_ARCH-1],phyreg[0],...,phyreg[NUM_DECODE-1],
    // instr[0],...,instr[NUM_DECODE-1],out_insts[0],...,out_insts[NUM_DECODE-1],
    // yrot_table[0],...,yrot_table[NUM_ARCH-1],branch_ptr[0],branch_ptr[1],
    // younger_outputs[0],...,younger_outputs[NUM_DECODE-1]]
    localparam testcases = 51;
    localparam testveclen = `NUM_ARCH*`PHY_WIDTH + `NUM_DECODE*`PHY_WIDTH
        + `NUM_DECODE*(2+3*`ARCH_WIDTH) + 3*`PHY_WIDTH*`NUM_DECODE
        + `YROT_WIDTH*`NUM_ARCH + 2*`YROT_WIDTH + `YROT_WIDTH*`NUM_DECODE;
    localparam rat_base = `NUM_DECODE*`PHY_WIDTH
        + `NUM_DECODE*(2+3*`ARCH_WIDTH) + 3*`PHY_WIDTH*`NUM_DECODE
        + `YROT_WIDTH*`NUM_ARCH + 2*`YROT_WIDTH + `YROT_WIDTH*`NUM_DECODE;
    localparam phyreg_base = `NUM_DECODE*(2+3*`ARCH_WIDTH) + 3*`PHY_WIDTH*`NUM_DECODE
        + `YROT_WIDTH*`NUM_ARCH + 2*`YROT_WIDTH + `YROT_WIDTH*`NUM_DECODE;
    localparam instr_base = 3*`PHY_WIDTH*`NUM_DECODE
        + `YROT_WIDTH*`NUM_ARCH + 2*`YROT_WIDTH + `YROT_WIDTH*`NUM_DECODE;
    localparam out_insts_base = `YROT_WIDTH*`NUM_ARCH + 2*`YROT_WIDTH + `YROT_WIDTH*`NUM_DECODE;
    localparam yrot_table_base = 2*`YROT_WIDTH + `YROT_WIDTH*`NUM_DECODE;
    localparam branch_ptr_base = `YROT_WIDTH*`NUM_DECODE;
    reg [testveclen-1:0] testvector [0:testcases-1];
    reg [testveclen-1:0] curr_testvector;

    genvar i;
    assign rat_flatten = curr_testvector[testveclen-1:rat_base];
    assign phyreg_flatten = curr_testvector[rat_base-1:phyreg_base];
    assign insts_flatten = curr_testvector[phyreg_base-1:instr_base];
    assign out_insts_ref_flatten = curr_testvector[instr_base-1:out_insts_base];
    assign yrot_table_flatten = curr_testvector[out_insts_base-1:yrot_table_base];
    assign branch_ptr = curr_testvector[yrot_table_base-1:branch_ptr_base];
    assign younger_outputs_ref_flatten = curr_testvector[branch_ptr_base-1:0];
    // unflatten
    generate
        for (i = 0; i < `NUM_DECODE; i = i+1) begin
            assign phyreg[i] = phyreg_flatten[`PHY_WIDTH*`NUM_DECODE-i*`PHY_WIDTH-1:`PHY_WIDTH*`NUM_DECODE-(i+1)*`PHY_WIDTH];
            assign insts[i] = insts_flatten[(3*`ARCH_WIDTH+2)*`NUM_DECODE-i*(3*`ARCH_WIDTH+2)-1:(3*`ARCH_WIDTH+2)*`NUM_DECODE-(i+1)*(3*`ARCH_WIDTH+2)];
            assign out_insts[i] = out_insts_flatten[3*`PHY_WIDTH*`NUM_DECODE-i*3*`PHY_WIDTH-1:3*`PHY_WIDTH*`NUM_DECODE-(i+1)*3*`PHY_WIDTH];
            assign out_insts_ref[i] = out_insts_ref_flatten[3*`PHY_WIDTH*`NUM_DECODE-i*3*`PHY_WIDTH-1:3*`PHY_WIDTH*`NUM_DECODE-(i+1)*3*`PHY_WIDTH];
            assign younger_outputs[i] = younger_outputs_flatten[`YROT_WIDTH*`NUM_DECODE-i*`YROT_WIDTH-1:`YROT_WIDTH*`NUM_DECODE-(i+1)*`YROT_WIDTH];
            assign younger_outputs_ref[i] = younger_outputs_ref_flatten[`YROT_WIDTH*`NUM_DECODE-i*`YROT_WIDTH-1:`YROT_WIDTH*`NUM_DECODE-(i+1)*`YROT_WIDTH];
        end
    endgenerate
    generate
        for (i = 0; i < `NUM_ARCH; i = i+1) begin
            assign rat[i] = rat_flatten[`PHY_WIDTH*`NUM_ARCH-i*`PHY_WIDTH-1:`PHY_WIDTH*`NUM_ARCH-(i+1)*`PHY_WIDTH];
            assign yrot_table[i] = yrot_table_flatten[`YROT_WIDTH*`NUM_ARCH-i*`YROT_WIDTH-1:`YROT_WIDTH*`NUM_ARCH-(i+1)*`YROT_WIDTH];
        end
    endgenerate

    //--------------------------------------------------------------------
    // Start test
    //--------------------------------------------------------------------
    integer j;
    initial begin
        $vcdpluson;
        $vcdplusmemon;
        $readmemb("/scratch/boru/STT-Rename/test/stt_og_10_9.input", testvector);
        repeat (5) @(negedge clk) reset = 1;
        reset = 0;
        for (j = 0; j < testcases; j = j+1) begin
            curr_testvector = testvector[j];
            @(posedge clk);  // buffer input
            @(negedge clk) checkOutput();
        end
        $display("\n\nALL TESTS PASSED!");
        $vcdplusoff;
        $finish;
    end
    
endmodule