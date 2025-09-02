//=========================================================================
// OG-STT
//-------------------------------------------------------------------------

// Description: A parameterized OG-STT rename circuit. 
// input:
// - phyreg: free physical register allocated for new dest reg
// - insts: Input instructions ([branch_bit,load_bit,dest,src1,src2])
// ----- load_bit = 1 -> this is a load instr
// ----- branch_bit = 1 -> this is a branch instr
// - branch_ptr: [branch_head, branch_tail]
// output:
// - out_insts: Output inst, which will be added into ROB ([p_dest,old_p_dest,p_src1,p_src2])
// - younger_outputs: Output yrot for each instruction


module stt_og #(
    parameter NUM_DECODE = 10,
    parameter DECODE_WIDTH = $clog2(NUM_DECODE),
    parameter NUM_PHY = 380,
    parameter PHY_WIDTH = $clog2(NUM_PHY),
    parameter NUM_ARCH = 31,
    parameter ARCH_WIDTH = $clog2(NUM_ARCH),
    parameter NUM_ROB = 512,
    parameter YROT_WIDTH = $clog2(NUM_ROB)
) (
    input clk,
    input rst,
    input [PHY_WIDTH*NUM_DECODE-1:0] phyreg_flatten,
    input [(3*ARCH_WIDTH+2)*NUM_DECODE-1:0] insts_flatten,
    input [2*YROT_WIDTH-1:0] branch_ptr,
    output [3*PHY_WIDTH*NUM_DECODE-1:0] out_insts_flatten_buf,
    output [YROT_WIDTH*NUM_DECODE-1:0] younger_outputs_flatten_buf
);
    // buffer inputs and outputs
    wire [PHY_WIDTH*NUM_DECODE-1:0] phyreg_flatten_buf;
    wire [(3*ARCH_WIDTH+2)*NUM_DECODE-1:0] insts_flatten_buf;
    wire [2*YROT_WIDTH-1:0] branch_ptr_buf;
    wire [3*PHY_WIDTH*NUM_DECODE-1:0] out_insts_flatten;
    wire [YROT_WIDTH*NUM_DECODE-1:0] younger_outputs_flatten;
    REGISTER_R #(
        .N(PHY_WIDTH*NUM_DECODE)
    ) phyreg_flatten_reg (
        .q(phyreg_flatten_buf),
        .d(phyreg_flatten),
        .rst(rst),
        .clk(clk)
    );
    REGISTER_R #(
        .N((3*ARCH_WIDTH+2)*NUM_DECODE)
    ) insts_flatten_reg (
        .q(insts_flatten_buf),
        .d(insts_flatten),
        .rst(rst),
        .clk(clk)
    );
    REGISTER_R #(
        .N(2*YROT_WIDTH)
    ) branch_ptr_reg (
        .q(branch_ptr_buf),
        .d(branch_ptr),
        .rst(rst),
        .clk(clk)
    );
    REGISTER_R #(
        .N(3*PHY_WIDTH*NUM_DECODE)
    ) out_insts_flatten_reg (
        .q(out_insts_flatten_buf),
        .d(out_insts_flatten),
        .rst(rst),
        .clk(clk)
    );
    REGISTER_R #(
        .N(YROT_WIDTH*NUM_DECODE)
    ) younger_outputs_flatten_reg (
        .q(younger_outputs_flatten_buf),
        .d(younger_outputs_flatten),
        .rst(rst),
        .clk(clk)
    );

    wire [PHY_WIDTH-1:0] phyreg [NUM_DECODE-1:0];
    wire [3*ARCH_WIDTH+1:0] insts [NUM_DECODE-1:0];
    wire [NUM_DECODE-1:0] write_en;
    wire [PHY_WIDTH-1:0] rat [NUM_ARCH-1:0];
    wire [YROT_WIDTH-1:0] yrot_table [NUM_ARCH-1:0];
    wire [3*PHY_WIDTH-1:0] out_insts [NUM_DECODE-1:0];
    wire [YROT_WIDTH-1:0] output_yrots [NUM_DECODE-1:0];
    wire [YROT_WIDTH-1:0] younger_outputs [NUM_DECODE-1:0];

    genvar i;
    // unflatten
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            assign phyreg[i] = phyreg_flatten_buf[PHY_WIDTH*NUM_DECODE-i*PHY_WIDTH-1:PHY_WIDTH*NUM_DECODE-(i+1)*PHY_WIDTH];
            assign insts[i] = insts_flatten_buf[(3*ARCH_WIDTH+2)*NUM_DECODE-i*(3*ARCH_WIDTH+2)-1:(3*ARCH_WIDTH+2)*NUM_DECODE-(i+1)*(3*ARCH_WIDTH+2)];
            assign out_insts_flatten[3*PHY_WIDTH*NUM_DECODE-i*3*PHY_WIDTH-1:3*PHY_WIDTH*NUM_DECODE-(i+1)*3*PHY_WIDTH] = out_insts[i];
            assign younger_outputs_flatten[YROT_WIDTH*NUM_DECODE-i*YROT_WIDTH-1:YROT_WIDTH*NUM_DECODE-(i+1)*YROT_WIDTH] = younger_outputs[i];
        end
    endgenerate

    // allocate branch epoch entries
    wire [YROT_WIDTH-1:0] branch_head;
    wire [YROT_WIDTH-1:0] branch_tail;
    assign branch_head = branch_ptr_buf[2*YROT_WIDTH-1:YROT_WIDTH];
    assign branch_tail = branch_ptr_buf[YROT_WIDTH-1:0];

    stt_og_comb #(
        .NUM_DECODE(NUM_DECODE),
        .NUM_PHY(NUM_PHY),
        .NUM_ARCH(NUM_ARCH),
        .NUM_ROB(NUM_ROB)
    ) stt_og_comb (
        .phyreg(phyreg),
        .insts(insts),
        .rat(rat),
        .yrot_table(yrot_table),
        .branch_head(branch_head),
        .branch_tail(branch_tail),
        .write_en(write_en),
        .out_insts(out_insts),
        .output_yrots(output_yrots),
        .younger_outputs(younger_outputs)
    );

    stt_og_update #(
        .NUM_DECODE(NUM_DECODE),
        .NUM_PHY(NUM_PHY),
        .NUM_ARCH(NUM_ARCH),
        .NUM_ROB(NUM_ROB)
    ) stt_og_update (
        .clk(clk),
        .rst(rst),
        .write_en(write_en),
        .out_insts(out_insts),
        .output_yrots(output_yrots),
        .insts(insts),
        .rat(rat),
        .yrot_table(yrot_table)
    );
endmodule

module stt_og_update #(
    parameter NUM_DECODE = 4,
    parameter DECODE_WIDTH = $clog2(NUM_DECODE),
    parameter NUM_PHY = 380,
    parameter PHY_WIDTH = $clog2(NUM_PHY),
    parameter NUM_ARCH = 31,
    parameter ARCH_WIDTH = $clog2(NUM_ARCH),
    parameter NUM_ROB = 512,
    parameter YROT_WIDTH = $clog2(NUM_ROB)
) (
    input clk,
    input rst,
    input [NUM_DECODE-1:0] write_en,
    input [3*PHY_WIDTH-1:0] out_insts [NUM_DECODE-1:0],
    input [YROT_WIDTH-1:0] output_yrots [NUM_DECODE-1:0],
    input [3*ARCH_WIDTH+1:0] insts [NUM_DECODE-1:0],
    output reg [PHY_WIDTH-1:0] rat [NUM_ARCH-1:0],
    output reg [YROT_WIDTH-1:0] yrot_table [NUM_ARCH-1:0]
);
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < NUM_ARCH; i++) begin
                rat[i] <= (PHY_WIDTH)'(i);
                yrot_table[i][YROT_WIDTH-1:0] <= (YROT_WIDTH)' (NUM_ROB / 2);
            end
        end else begin
            for (int i = 0; i < NUM_DECODE; i++) begin
                if (write_en[i]) begin
                    rat[insts[i][3*ARCH_WIDTH-1:2*ARCH_WIDTH]] <= out_insts[i][3*PHY_WIDTH-1:2*PHY_WIDTH];
                    yrot_table[insts[i][3*ARCH_WIDTH-1:2*ARCH_WIDTH]] <= output_yrots[i];
                end
            end
        end
    end
endmodule

module stt_og_comb #(
    parameter NUM_DECODE = 4,
    parameter DECODE_WIDTH = $clog2(NUM_DECODE),
    parameter NUM_PHY = 380,
    parameter PHY_WIDTH = $clog2(NUM_PHY),
    parameter NUM_ARCH = 31,
    parameter ARCH_WIDTH = $clog2(NUM_ARCH),
    parameter NUM_ROB = 512,
    parameter YROT_WIDTH = $clog2(NUM_ROB)
) (
    input [PHY_WIDTH-1:0] phyreg [NUM_DECODE-1:0],
    input [3*ARCH_WIDTH+1:0] insts [NUM_DECODE-1:0],
    input [PHY_WIDTH-1:0] rat [NUM_ARCH-1:0],
    input [YROT_WIDTH-1:0] yrot_table [NUM_ARCH-1:0],
    input [YROT_WIDTH-1:0] branch_head,
    input [YROT_WIDTH-1:0] branch_tail,
    output reg [NUM_DECODE-1:0] write_en,
    output [3*PHY_WIDTH-1:0] out_insts [NUM_DECODE-1:0],
    output [YROT_WIDTH-1:0] output_yrots [NUM_DECODE-1:0],
    output [YROT_WIDTH-1:0] younger_outputs [NUM_DECODE-1:0]
);
    genvar i;
    wire [DECODE_WIDTH-1:0] raw_pri_out_matrix [2*(NUM_DECODE-1)-1:0];
    // parse insts to get load/branch bit vector
    wire load_bit_vec [NUM_DECODE-1:0];
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            assign load_bit_vec[i] = insts[i][3*ARCH_WIDTH];
        end
    endgenerate

    // old_yrots: yrot for each input register
    wire [YROT_WIDTH-1:0] old_yrots [2*NUM_DECODE-1:0];
    rename_stt_comb #(
        .NUM_DECODE(NUM_DECODE),
        .NUM_PHY(NUM_PHY),
        .NUM_ARCH(NUM_ARCH),
        .YROT_WIDTH(YROT_WIDTH-1)
    ) rename_stt_comb (
        .phyreg(phyreg),
        .insts(insts),
        .rat(rat),
        .yrot_table(yrot_table),
        .write_en(write_en),
        .out_insts(out_insts),
        .raw_pri_out_matrix(raw_pri_out_matrix),
        .yrot_arr(old_yrots)
    );

    // branch epoch
    wire [YROT_WIDTH-1:0] branch_epochs [NUM_DECODE-1:0];
    branch_epoch_gen_og #(
        .YROT_WIDTH(YROT_WIDTH),
        .NUM_DECODE(NUM_DECODE)
    ) bepoch_gen (
        .branch_tail(branch_tail),
        .branch_epochs(branch_epochs)
    );

    // compute yrot
    // first instr takes two old yrots to compute younger one
    younger_og #(
        .YROT_WIDTH(YROT_WIDTH)
    ) younger_than_inst (
        .yrot1(old_yrots[1]),
        .yrot2(old_yrots[0]),
        .branch_head(branch_head),
        .output_yrot(younger_outputs[0])
    );

    // for other instrs, select yrot from equality check output
    // raw_eq_out_matrix[2*(i-1)+1][i-1:0]
    generate
        for (i = 1; i < NUM_DECODE; i = i+1) begin
            wire [YROT_WIDTH-1:0] yrot1;
            wire [YROT_WIDTH-1:0] yrot2;
            assign yrot1 = (raw_pri_out_matrix[2*(i-1)+1][$clog2(i+1)-1:0] == 0)
                ? old_yrots[2*i+1]
                : output_yrots[raw_pri_out_matrix[2*(i-1)+1][$clog2(i+1)-1:0]-1];
            assign yrot2 = (raw_pri_out_matrix[2*(i-1)][$clog2(i+1)-1:0] == 0)
                ? old_yrots[2*i]
                : output_yrots[raw_pri_out_matrix[2*(i-1)][$clog2(i+1)-1:0]-1];
            younger_og #(
                .YROT_WIDTH(YROT_WIDTH)
            ) younger_than_inst (
                .yrot1(yrot1),
                .yrot2(yrot2),
                .branch_head(branch_head),
                .output_yrot(younger_outputs[i])
            );
        end
    endgenerate

    // pick branch epoch if load, otherwise compute yrot
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            assign output_yrots[i] = (load_bit_vec[i] == 1'b0) ? younger_outputs[i] : branch_epochs[i];
        end
    endgenerate

endmodule