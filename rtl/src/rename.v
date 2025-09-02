//=========================================================================
// Rename circuit (baseline)
//-------------------------------------------------------------------------

// Description: A parameterized rename circuit. 
// input:
// - phyreg: free physical register allocated for new dest reg
// - insts: Input instructions ([branch_bit,load_bit,dest,src1,src2])
// ----- load_bit = 1 -> this is a load instr
// ----- branch_bit = 1 -> this is a branch instr
// output:
// - out_insts: Output inst, which will be added into ROB ([p_dest,p_src1,p_src2])

module rename #(
    parameter NUM_DECODE = 4,
    parameter DECODE_WIDTH = $clog2(NUM_DECODE),
    parameter NUM_PHY = 380,
    parameter PHY_WIDTH = $clog2(NUM_PHY),
    parameter NUM_ARCH = 31,
    parameter ARCH_WIDTH = $clog2(NUM_ARCH)
) (
    input clk,
    input rst,
    input [PHY_WIDTH*NUM_DECODE-1:0] phyreg_flatten,
    input [(3*ARCH_WIDTH+2)*NUM_DECODE-1:0] insts_flatten,
    output [3*PHY_WIDTH*NUM_DECODE-1:0] out_insts_flatten_buf
);
    // buffer inputs and outputs
    wire [PHY_WIDTH*NUM_DECODE-1:0] phyreg_flatten_buf;
    wire [(3*ARCH_WIDTH+2)*NUM_DECODE-1:0] insts_flatten_buf;
    wire [3*PHY_WIDTH*NUM_DECODE-1:0] out_insts_flatten;
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
        .N(3*PHY_WIDTH*NUM_DECODE)
    ) out_insts_flatten_reg (
        .q(out_insts_flatten_buf),
        .d(out_insts_flatten),
        .rst(rst),
        .clk(clk)
    );

    wire [PHY_WIDTH-1:0] phyreg [NUM_DECODE-1:0];
    wire [3*ARCH_WIDTH+1:0] insts [NUM_DECODE-1:0];
    wire [PHY_WIDTH-1:0] rat [NUM_ARCH-1:0];
    wire [3*PHY_WIDTH-1:0] out_insts [NUM_DECODE-1:0];
    wire [NUM_DECODE-1:0] write_en;

    genvar i;

    // unflatten
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            assign phyreg[i] = phyreg_flatten_buf[PHY_WIDTH*NUM_DECODE-i*PHY_WIDTH-1:PHY_WIDTH*NUM_DECODE-(i+1)*PHY_WIDTH];
            assign insts[i] = insts_flatten_buf[(3*ARCH_WIDTH+2)*NUM_DECODE-i*(3*ARCH_WIDTH+2)-1:(3*ARCH_WIDTH+2)*NUM_DECODE-(i+1)*(3*ARCH_WIDTH+2)];
            assign out_insts_flatten[3*PHY_WIDTH*NUM_DECODE-i*3*PHY_WIDTH-1:3*PHY_WIDTH*NUM_DECODE-(i+1)*3*PHY_WIDTH] = out_insts[i];
        end
    endgenerate

    rename_comb #(
        .NUM_DECODE(NUM_DECODE),
        .NUM_PHY(NUM_PHY),
        .NUM_ARCH(NUM_ARCH)
    ) rename_comb (
        .phyreg(phyreg),
        .insts(insts),
        .rat(rat),
        .write_en(write_en),
        .out_insts(out_insts)
    );

    rat_update #(
        .NUM_DECODE(NUM_DECODE),
        .NUM_PHY(NUM_PHY),
        .NUM_ARCH(NUM_ARCH)
    ) rat_update_inst (
        .clk(clk),
        .rst(rst),
        .rat(rat),
        .write_en(write_en),
        .out_insts(out_insts),
        .insts(insts)
    );
endmodule

// =========================================================================
// rat rename circuit
// if write_en is true, then update the rat to the new phyreg
// if reset, set rat[ARCHREG] = ARCHREG
//-------------------------------------------------------------------------
module rat_update #(
    parameter NUM_DECODE = 4,
    parameter DECODE_WIDTH = $clog2(NUM_DECODE),
    parameter NUM_PHY = 380,
    parameter PHY_WIDTH = $clog2(NUM_PHY),
    parameter NUM_ARCH = 31,
    parameter ARCH_WIDTH = $clog2(NUM_ARCH)
) (
    input clk,
    input rst,
    input [NUM_DECODE-1:0] write_en,
    input [3*PHY_WIDTH-1:0] out_insts [NUM_DECODE-1:0],
    input [3*ARCH_WIDTH+1:0] insts [NUM_DECODE-1:0],
    output reg [PHY_WIDTH-1:0] rat [NUM_ARCH-1:0]
);

always_ff @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < NUM_ARCH; i++) begin
            rat[i] <= (PHY_WIDTH)'(i);
        end
    end else begin        
        for (int i = 0; i < NUM_DECODE; i++) begin
            if (write_en[i]) begin
                rat[insts[i][3*ARCH_WIDTH-1:2*ARCH_WIDTH]] <= out_insts[i][3*PHY_WIDTH-1:2*PHY_WIDTH];
            end
        end
    end
end
endmodule

module rename_comb #(
    parameter NUM_DECODE = 4,
    parameter DECODE_WIDTH = $clog2(NUM_DECODE),
    parameter NUM_PHY = 380,
    parameter PHY_WIDTH = $clog2(NUM_PHY),
    parameter NUM_ARCH = 31,
    parameter ARCH_WIDTH = $clog2(NUM_ARCH)
) (
    input [PHY_WIDTH-1:0] phyreg [NUM_DECODE-1:0],
    input [3*ARCH_WIDTH+1:0] insts [NUM_DECODE-1:0],
    input [PHY_WIDTH-1:0] rat [NUM_ARCH-1:0],
    output reg [NUM_DECODE-1:0] write_en,
    output [3*PHY_WIDTH-1:0] out_insts [NUM_DECODE-1:0]
);
    genvar i;
    // parse insts to get all arch dest regs
    wire [ARCH_WIDTH-1:0] dest_archreg [NUM_DECODE-1:0];
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            assign dest_archreg[i] = insts[i][3*ARCH_WIDTH-1:2*ARCH_WIDTH];
        end
    endgenerate

    // parse insts to get all arch src regs
    wire [2*ARCH_WIDTH-1:0] src_archreg [NUM_DECODE-1:0];
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            assign src_archreg[i] = insts[i][2*ARCH_WIDTH-1:0];
        end
    endgenerate

    /* WAW check*/
    // matrices for equality check result and corresponding priority output
    wire [NUM_DECODE-2:0] waw_eq_out_matrix [NUM_DECODE-2:0];
    wire [DECODE_WIDTH-1:0] waw_pri_out_matrix [NUM_DECODE-2:0];
    generate
        for (i = 1; i < NUM_DECODE; i = i+1) begin
            eq_comp #(
                .ID_WIDTH(ARCH_WIDTH),
                .NUM_ID(i)
            ) eq_comp_waw (
                .id(dest_archreg[i]),
                .id_array(dest_archreg[i-1:0]),
                .pri_out(waw_pri_out_matrix[i-1][$clog2(i+1)-1:0]),
                .eq_out(waw_eq_out_matrix[i-1][i-1:0])
            );
        end
    endgenerate
    // Newly allocated phy dest reg
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            assign out_insts[i][3*PHY_WIDTH-1:2*PHY_WIDTH] = phyreg[i];
        end
    endgenerate
    // write_en
    // if preceding inst has the same dest reg, then write_en is false
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            integer j;
            always @(*) begin
                write_en[i] = 1'b1;
                for (j = i; j < NUM_DECODE-1; j = j+1) begin
                    write_en[i] = write_en[i] & (!waw_eq_out_matrix[j][i]);
                end
            end
        end
    endgenerate

    /* RAW check */
    // first src reg
    // read rat to get phy reg -> out_insts
    assign out_insts[0][2*PHY_WIDTH-1:0] = {rat[src_archreg[0][2*ARCH_WIDTH-1:ARCH_WIDTH]],
                                            rat[src_archreg[0][ARCH_WIDTH-1:0]]};
    // for other src reg
    // matrices for equality check result and corresponding priority output
    wire [NUM_DECODE-2:0] raw_eq_out_matrix [2*(NUM_DECODE-1)-1:0];
    wire [DECODE_WIDTH-1:0] raw_pri_out_matrix [2*(NUM_DECODE-1)-1:0];
    generate
        for (i = 1; i < NUM_DECODE; i = i+1) begin
            eq_comp #(
                .ID_WIDTH(ARCH_WIDTH),
                .NUM_ID(i)
            ) eq_comp_raw1 (
                .id(src_archreg[i][2*ARCH_WIDTH-1:ARCH_WIDTH]),
                .id_array(dest_archreg[i-1:0]),
                .pri_out(raw_pri_out_matrix[2*(i-1)+1][$clog2(i+1)-1:0]),
                .eq_out(raw_eq_out_matrix[2*(i-1)+1][i-1:0])
            );
            eq_comp #(
                .ID_WIDTH(ARCH_WIDTH),
                .NUM_ID(i)
            ) eq_comp_raw2 (
                .id(src_archreg[i][ARCH_WIDTH-1:0]),
                .id_array(dest_archreg[i-1:0]),
                .pri_out(raw_pri_out_matrix[2*(i-1)][$clog2(i+1)-1:0]),
                .eq_out(raw_eq_out_matrix[2*(i-1)][i-1:0])
            );
        end
    endgenerate
    // out_insts src phy reg
    // if pri_out is 0, then read from rat; otherwise get pri_out's phy reg
    generate
        for (i = 1; i < NUM_DECODE; i = i+1) begin
            assign out_insts[i][PHY_WIDTH-1:0]
                = (raw_pri_out_matrix[2*(i-1)][$clog2(i+1)-1:0] == 0)
                ? rat[src_archreg[i][ARCH_WIDTH-1:0]]
                : phyreg[raw_pri_out_matrix[2*(i-1)][$clog2(i+1)-1:0]-1];
            assign out_insts[i][2*PHY_WIDTH-1:PHY_WIDTH]
                = (raw_pri_out_matrix[2*(i-1)+1][$clog2(i+1)-1:0] == 0)
                ? rat[src_archreg[i][2*ARCH_WIDTH-1:ARCH_WIDTH]]
                : phyreg[raw_pri_out_matrix[2*(i-1)+1][$clog2(i+1)-1:0]-1];
        end
    endgenerate
endmodule

module rename_stt_comb #(
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
    input [(YROT_WIDTH+1)-1:0] yrot_table [NUM_ARCH-1:0],
    output reg [NUM_DECODE-1:0] write_en,
    output [3*PHY_WIDTH-1:0] out_insts [NUM_DECODE-1:0],
    output [DECODE_WIDTH-1:0] raw_pri_out_matrix [2*(NUM_DECODE-1)-1:0],
    output [(YROT_WIDTH+1)-1:0] yrot_arr [2*NUM_DECODE-1:0]
);
    genvar i;
    // parse insts to get all arch dest regs
    wire [ARCH_WIDTH-1:0] dest_archreg [NUM_DECODE-1:0];
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            assign dest_archreg[i] = insts[i][3*ARCH_WIDTH-1:2*ARCH_WIDTH];
        end
    endgenerate

    // parse insts to get all arch src regs
    wire [2*ARCH_WIDTH-1:0] src_archreg [NUM_DECODE-1:0];
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            assign src_archreg[i] = insts[i][2*ARCH_WIDTH-1:0];
        end
    endgenerate

    // lookup rat and yrot_table with src regs
    wire [(YROT_WIDTH+1)+PHY_WIDTH-1:0] aug_rat [NUM_ARCH-1:0];
    wire [PHY_WIDTH-1:0] phyreg_arr [2*NUM_DECODE-1:0];
    generate
        for (i = 0; i < NUM_ARCH; i = i+1) begin
            assign aug_rat[i] = {rat[i], yrot_table[i]};
        end
    endgenerate
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            assign {phyreg_arr[2*i], yrot_arr[2*i]} = aug_rat[src_archreg[i][ARCH_WIDTH-1:0]];
            assign {phyreg_arr[2*i+1], yrot_arr[2*i+1]} = aug_rat[src_archreg[i][2*ARCH_WIDTH-1:ARCH_WIDTH]];
        end
    endgenerate

    /* WAW check*/
    // matrices for equality check result and corresponding priority output
    wire [NUM_DECODE-2:0] waw_eq_out_matrix [NUM_DECODE-2:0];
    wire [DECODE_WIDTH-1:0] waw_pri_out_matrix [NUM_DECODE-2:0];
    generate
        for (i = 1; i < NUM_DECODE; i = i+1) begin
            eq_comp #(
                .ID_WIDTH(ARCH_WIDTH),
                .NUM_ID(i)
            ) eq_comp_waw (
                .id(dest_archreg[i]),
                .id_array(dest_archreg[i-1:0]),
                .pri_out(waw_pri_out_matrix[i-1][$clog2(i+1)-1:0]),
                .eq_out(waw_eq_out_matrix[i-1][i-1:0])
            );
        end
    endgenerate
    // Newly allocated phy dest reg
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            assign out_insts[i][3*PHY_WIDTH-1:2*PHY_WIDTH] = phyreg[i];
        end
    endgenerate
    // write_en
    // if preceding inst has the same dest reg, then write_en is false
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            integer j;
            always @(*) begin
                write_en[i] = 1'b1;
                for (j = i; j < NUM_DECODE-1; j = j+1) begin
                    write_en[i] = write_en[i] & (!waw_eq_out_matrix[j][i]);
                end
            end
        end
    endgenerate

    /* RAW check */
    // first src reg
    // read rat to get phy reg -> out_insts
    assign out_insts[0][2*PHY_WIDTH-1:0] = {phyreg_arr[1],
                                            phyreg_arr[0]};
    // for other src reg
    // matrices for equality check result and corresponding priority output
    wire [NUM_DECODE-2:0] raw_eq_out_matrix [2*(NUM_DECODE-1)-1:0];
    generate
        for (i = 1; i < NUM_DECODE; i = i+1) begin
            eq_comp #(
                .ID_WIDTH(ARCH_WIDTH),
                .NUM_ID(i)
            ) eq_comp_raw1 (
                .id(src_archreg[i][2*ARCH_WIDTH-1:ARCH_WIDTH]),
                .id_array(dest_archreg[i-1:0]),
                .pri_out(raw_pri_out_matrix[2*(i-1)+1][$clog2(i+1)-1:0]),
                .eq_out(raw_eq_out_matrix[2*(i-1)+1][i-1:0])
            );
            eq_comp #(
                .ID_WIDTH(ARCH_WIDTH),
                .NUM_ID(i)
            ) eq_comp_raw2 (
                .id(src_archreg[i][ARCH_WIDTH-1:0]),
                .id_array(dest_archreg[i-1:0]),
                .pri_out(raw_pri_out_matrix[2*(i-1)][$clog2(i+1)-1:0]),
                .eq_out(raw_eq_out_matrix[2*(i-1)][i-1:0])
            );
        end
    endgenerate
    // out_insts src phy reg
    // if pri_out is 0, then read from rat; otherwise get pri_out's phy reg
    generate
        for (i = 1; i < NUM_DECODE; i = i+1) begin
            assign out_insts[i][PHY_WIDTH-1:0]
                = (raw_pri_out_matrix[2*(i-1)][$clog2(i+1)-1:0] == 0)
                ? phyreg_arr[2*i]
                : phyreg[raw_pri_out_matrix[2*(i-1)][$clog2(i+1)-1:0]-1];
            assign out_insts[i][2*PHY_WIDTH-1:PHY_WIDTH]
                = (raw_pri_out_matrix[2*(i-1)+1][$clog2(i+1)-1:0] == 0)
                ? phyreg_arr[2*i+1]
                : phyreg[raw_pri_out_matrix[2*(i-1)+1][$clog2(i+1)-1:0]-1];
        end
    endgenerate
endmodule
