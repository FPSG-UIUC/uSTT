//=========================================================================
// STT AGE
//-------------------------------------------------------------------------

// Description: A parameterized STT rename circuit (age matrix). 
// input:
// - phyreg: free physical register allocated for new dest reg
// - insts: Input instructions ([branch_bit,load_bit,dest,src1,src2])
// ----- load_bit = 1 -> this is a load instr
// ----- branch_bit = 1 -> this is a branch instr
// - branch_tail
// - wrap_bit
// output:
// - out_insts: Output inst, which will be added into ROB ([p_dest,old_p_dest,p_src1,p_src2])
// - younger_outputs: Output yrot for each instruction

module stt_age #(
    parameter NUM_DECODE = 8,
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
    input [YROT_WIDTH-1:0] branch_tail,
    input wrap_bit,
    output [3*PHY_WIDTH*NUM_DECODE-1:0] out_insts_flatten_buf,
    output [(YROT_WIDTH+1)*NUM_DECODE-1:0] younger_outputs_flatten_buf
);
    // buffer inputs and outputs
    wire [PHY_WIDTH*NUM_DECODE-1:0] phyreg_flatten_buf;
    wire [(3*ARCH_WIDTH+2)*NUM_DECODE-1:0] insts_flatten_buf;
    wire [YROT_WIDTH-1:0] branch_tail_buf;
    wire [3*PHY_WIDTH*NUM_DECODE-1:0] out_insts_flatten;
    wire [(YROT_WIDTH+1)*NUM_DECODE-1:0] younger_outputs_flatten;
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
        .N(YROT_WIDTH)
    ) branch_tail_reg (
        .q(branch_tail_buf),
        .d(branch_tail),
        .rst(rst),
        .clk(clk)
    );
    REGISTER_R #(
        .N(1)
    ) wrap_bit_reg (
        .q(wrap_bit_buf),
        .d(wrap_bit),
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
        .N((YROT_WIDTH+1)*NUM_DECODE)
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
    wire [(YROT_WIDTH+1)-1:0] yrot_table [NUM_ARCH-1:0];
    wire [(YROT_WIDTH+1)-1:0] last_epoch;
    wire [(YROT_WIDTH+1)-1:0] last_epoch_new;
    wire [3*PHY_WIDTH-1:0] out_insts [NUM_DECODE-1:0];
    wire [(YROT_WIDTH+1)-1:0] output_yrots [NUM_DECODE-1:0];
    wire [(YROT_WIDTH+1)-1:0] younger_outputs [NUM_DECODE-1:0];

    genvar i;
    // unflatten
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            assign phyreg[i] = phyreg_flatten_buf[PHY_WIDTH*NUM_DECODE-i*PHY_WIDTH-1:PHY_WIDTH*NUM_DECODE-(i+1)*PHY_WIDTH];
            assign insts[i] = insts_flatten_buf[(3*ARCH_WIDTH+2)*NUM_DECODE-i*(3*ARCH_WIDTH+2)-1:(3*ARCH_WIDTH+2)*NUM_DECODE-(i+1)*(3*ARCH_WIDTH+2)];
            assign out_insts_flatten[3*PHY_WIDTH*NUM_DECODE-i*3*PHY_WIDTH-1:3*PHY_WIDTH*NUM_DECODE-(i+1)*3*PHY_WIDTH] = out_insts[i];
            assign younger_outputs_flatten[(YROT_WIDTH+1)*NUM_DECODE-i*(YROT_WIDTH+1)-1:(YROT_WIDTH+1)*NUM_DECODE-(i+1)*(YROT_WIDTH+1)] = younger_outputs[i];
        end
    endgenerate

    // instantiate the STT age combinational logic
    stt_age_comb #(
        .NUM_DECODE(NUM_DECODE),
        .NUM_PHY(NUM_PHY),
        .NUM_ARCH(NUM_ARCH),
        .NUM_ROB(NUM_ROB)
    ) stt_age_comb_inst (
        .phyreg(phyreg),
        .insts(insts),
        .rat(rat),
        .yrot_table(yrot_table),
        .last_epoch(last_epoch),
        .last_epoch_new(last_epoch_new),
        .branch_tail(branch_tail_buf),
        .wrap_bit(wrap_bit_buf),
        .write_en(write_en),
        .out_insts(out_insts),
        .output_yrots(output_yrots),
        .younger_outputs(younger_outputs)
    );

    stt_age_update #(
        .NUM_DECODE(NUM_DECODE),
        .NUM_ARCH(NUM_ARCH),
        .NUM_PHY(NUM_PHY),
        .NUM_ROB(NUM_ROB)
    ) stt_age_update_inst (
        .clk(clk),
        .rst(rst),
        .write_en(write_en),
        .rat(rat),
        .yrot_table(yrot_table),
        .last_epoch(last_epoch),
        .last_epoch_new(last_epoch_new),
        .out_insts(out_insts),
        .output_yrots(output_yrots),
        .insts(insts)
    );
endmodule

module stt_age_update #(
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
    input [(YROT_WIDTH+1)-1:0] output_yrots [NUM_DECODE-1:0],
    input [3*ARCH_WIDTH+1:0] insts [NUM_DECODE-1:0],
    input [(YROT_WIDTH+1)-1:0] last_epoch_new,
    output reg [PHY_WIDTH-1:0] rat [NUM_ARCH-1:0],
    output reg [(YROT_WIDTH+1)-1:0] yrot_table [NUM_ARCH-1:0],
    output reg [(YROT_WIDTH+1)-1:0] last_epoch
);
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < NUM_ARCH; i++) begin
                rat[i] <= (PHY_WIDTH)'(i);
                yrot_table[i][YROT_WIDTH] <= 1'b0;
                yrot_table[i][YROT_WIDTH-1:0] <= (YROT_WIDTH)' (NUM_ROB / 2);
            end
            last_epoch[YROT_WIDTH-1:0] <= (YROT_WIDTH)' (NUM_ROB / 2);
            last_epoch[YROT_WIDTH] <= 1'b0;
        end else begin
            for (int i = 0; i < NUM_DECODE; i++) begin
                if (write_en[i]) begin
                    rat[insts[i][3*ARCH_WIDTH-1:2*ARCH_WIDTH]] <= out_insts[i][3*PHY_WIDTH-1:2*PHY_WIDTH];
                    yrot_table[insts[i][3*ARCH_WIDTH-1:2*ARCH_WIDTH]] <= output_yrots[i];
                end
            end
            last_epoch <= last_epoch_new;
        end
    end
endmodule

module stt_age_comb #(
    parameter NUM_DECODE = 2,
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
    input [(YROT_WIDTH+1)-1:0] last_epoch,
    input [YROT_WIDTH-1:0] branch_tail,
    input wrap_bit,
    output [NUM_DECODE-1:0] write_en,
    output [(YROT_WIDTH+1)-1:0] last_epoch_new,
    output [3*PHY_WIDTH-1:0] out_insts [NUM_DECODE-1:0],
    output [(YROT_WIDTH+1)-1:0] output_yrots [NUM_DECODE-1:0],
    output [(YROT_WIDTH+1)-1:0] younger_outputs [NUM_DECODE-1:0]
);
    genvar i, j;
    wire [2*NUM_DECODE-1:0] yrot_ctrl [NUM_DECODE-2:0];
    wire [NUM_DECODE-1:0] load_depend_graph [NUM_DECODE-2:0];
    wire [NUM_DECODE-1:0] color_bit;
    wire [NUM_DECODE-1:0] load_bit_vec;
    wire [NUM_DECODE-1:0] branch_bit_vec;
    wire [DECODE_WIDTH-1:0] raw_pri_out_matrix [2*(NUM_DECODE-1)-1:0];
    // parse insts to get load bit vector
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            assign load_bit_vec[i] = insts[i][3*ARCH_WIDTH];
            assign branch_bit_vec[i] = insts[i][3*ARCH_WIDTH+1];
        end
    endgenerate

    // yrot_arr: yrot for each input register
    wire [(YROT_WIDTH+1)-1:0] yrot_arr [2*NUM_DECODE-1:0];
    rename_stt_comb #(
        .NUM_DECODE(NUM_DECODE),
        .NUM_PHY(NUM_PHY),
        .NUM_ARCH(NUM_ARCH),
        .NUM_ROB(NUM_ROB)
    ) rename_stt_comb (
        .phyreg(phyreg),
        .insts(insts),
        .rat(rat),
        .yrot_table(yrot_table),
        .write_en(write_en),
        .out_insts(out_insts),
        .raw_pri_out_matrix(raw_pri_out_matrix),
        .yrot_arr(yrot_arr)
    );

    // STT Control Path
    wire [NUM_DECODE-2:0] decoded_raw_matrix [2*(NUM_DECODE-1)-1:0];
    wire [NUM_DECODE-2:0] decoded_raw_matrix_noload [2*(NUM_DECODE-1)-1:0];
    // decode the raw_pri_out_matrix
    pe_decoder #(
        .NUM_DECODE(NUM_DECODE)
    ) pe_decoder (
        .raw_pri_out_matrix(raw_pri_out_matrix),
        .load_bit_vec(load_bit_vec),
        .decoded_raw_matrix(decoded_raw_matrix),
        .decoded_raw_matrix_noload(decoded_raw_matrix_noload)
    );
    // compute yrot dependency graph (cut load edges)
    stt_ctrl #(
        .NUM_DECODE(NUM_DECODE)
    ) ctrl (
        .raw_eq_out_matrix(decoded_raw_matrix),
        .yrot_ctrl(yrot_ctrl)
    );
    // generate load dependendcy graph
    stt_load_ctrl #(
        .NUM_DECODE(NUM_DECODE)
    ) ctrl_noload (
        .raw_eq_out_matrix(decoded_raw_matrix_noload),
        .load_bit_vec(load_bit_vec),
        .load_depend_graph(load_depend_graph)
    );

    // branch epoch
    wire [YROT_WIDTH:0] branch_epochs [NUM_DECODE-1:0];
    branch_epoch_gen #(
        .YROT_WIDTH(YROT_WIDTH),
        .NUM_DECODE(NUM_DECODE)
    ) bepoch_gen (
        .last_epoch(last_epoch),
        .branch_tail(branch_tail),
        .wrap_bit(wrap_bit),
        .branch_bit_vec(branch_bit_vec),
        .branch_epochs(branch_epochs)
    );
    // Next last epoch is the spec epoch of the last instruction
    assign last_epoch_new = branch_epochs[NUM_DECODE-1];

    // construct age matrix
    wire [2*NUM_DECODE-1:0] age_matrix [2*NUM_DECODE-1:0];
    younger_than_bulk #(
        .YROT_WIDTH(YROT_WIDTH),
        .NUM_ENTRIES(2*NUM_DECODE)
    ) ytb (
        .yrot_arr(yrot_arr),
        .wrap_bit(wrap_bit),
        .younger_sel_arr(age_matrix)
    );

    // compute yrot for each instr
    yrot_sel #(
        .NUM_DECODE(NUM_DECODE),
        .NUM_ROB(NUM_ROB)
    ) yrot_sel (
        .age_matrix(age_matrix),
        .yrot_arr(yrot_arr),
        .load_depend_graph(load_depend_graph),
        .branch_epochs(branch_epochs),
        .yrot_ctrl(yrot_ctrl),
        .younger_outputs(younger_outputs)
    );

    // switch between branch epochs and younger_output
    get_output_yrots #(
        .NUM_DECODE(NUM_DECODE),
        .NUM_ROB(NUM_ROB)
    ) get_output_yrots (
        .branch_epochs(branch_epochs),
        .load_bit_vec(load_bit_vec),
        .younger_outputs(younger_outputs),
        .output_yrots(output_yrots)
    );
endmodule


// PE Decoder
// Decode the PE output
module pe_decoder #(
    parameter NUM_DECODE = 4,
    parameter DECODE_WIDTH = $clog2(NUM_DECODE)
) (
    input [DECODE_WIDTH-1:0] raw_pri_out_matrix [2*(NUM_DECODE-1)-1:0],
    input [NUM_DECODE-1:0] load_bit_vec,
    output [NUM_DECODE-2:0] decoded_raw_matrix [2*(NUM_DECODE-1)-1:0],
    output [NUM_DECODE-2:0] decoded_raw_matrix_noload [2*(NUM_DECODE-1)-1:0]
);
    genvar i;
    generate
        for (i = 1; i < NUM_DECODE; i = i+1) begin
            wire [i-1:0] src1_decoded_raw_matrix, src2_decoded_raw_matrix;
            assign decoded_raw_matrix[2*(i-1)][i-1:0]
                = src2_decoded_raw_matrix & (~load_bit_vec[i-1:0]);
            assign decoded_raw_matrix[2*(i-1)+1][i-1:0]
                = src1_decoded_raw_matrix & (~load_bit_vec[i-1:0]);
            assign decoded_raw_matrix_noload[2*(i-1)][i-1:0]
                = src2_decoded_raw_matrix;
            assign decoded_raw_matrix_noload[2*(i-1)+1][i-1:0]
                = src1_decoded_raw_matrix;

            // Decode for the src2
            param_decoder #(
                .IN_WIDTH($clog2(i))
            ) src2_decoder (
                .in(raw_pri_out_matrix[2*(i-1)][$clog2(i+1)-1:0]-1),
                .en(| raw_pri_out_matrix[2*(i-1)][$clog2(i+1)-1:0]),
                .out(src2_decoded_raw_matrix)
            );
            // Decode for the src1
            param_decoder #(
                .IN_WIDTH($clog2(i))
            ) src1_decoder (
                .in(raw_pri_out_matrix[2*(i-1)+1][$clog2(i+1)-1:0]-1),
                .en(| raw_pri_out_matrix[2*(i-1)+1][$clog2(i+1)-1:0]),
                .out(src1_decoded_raw_matrix)
            );
        end
    endgenerate

endmodule

// Yrot selection Logic
module yrot_sel #(
    parameter NUM_DECODE = 4,
    parameter DECODE_WIDTH = $clog2(NUM_DECODE),
    parameter NUM_ROB = 512,
    parameter YROT_WIDTH = $clog2(NUM_ROB)
) (
    input [2*NUM_DECODE-1:0] age_matrix [2*NUM_DECODE-1:0],
    input [(YROT_WIDTH+1)-1:0] yrot_arr [2*NUM_DECODE-1:0],
    input [NUM_DECODE-1:0] load_depend_graph [NUM_DECODE-2:0],
    input [YROT_WIDTH:0] branch_epochs [NUM_DECODE-1:0],
    input [2*NUM_DECODE-1:0] yrot_ctrl [NUM_DECODE-2:0],
    output [(YROT_WIDTH+1)-1:0] younger_outputs [NUM_DECODE-1:0]
);
    genvar i, j, k;
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            // no load part (check age matrix) [2*i+1:0]
            // sel array for each yrot reg
            wire [2*i+1:0] yrot_sel [2*i+1:0];
            // yrot array for masked potential yrot
            wire [(YROT_WIDTH+1)-1:0] yrot_masked [2*i+1:0];
            for (j = 0; j < 2*i+2; j = j+1) begin
                for (k = 0; k < 2*i+2; k = k+1) begin
                    if (i >= 1) begin
                        assign yrot_sel[j][k]
                            = age_matrix[j][k]
                            & yrot_ctrl[i-1][k];
                    end else begin
                        assign yrot_sel[j][k] = age_matrix[j][k];
                    end
                end
                if (i >= 1) begin
                    assign yrot_masked[j]
                        = {(YROT_WIDTH+1){~(|yrot_sel[j]) & yrot_ctrl[i-1][j]}}
                        & yrot_arr[j];
                end else begin
                    assign yrot_masked[j]
                        = {(YROT_WIDTH+1){~(|yrot_sel[j])}}
                        & yrot_arr[j];
                end
            end
            // get yrot from age matrix
            wire [(YROT_WIDTH+1)-1:0] yrot_age;
            or_reduction #(
                .WIDTH((YROT_WIDTH+1)),
                .NUM_ENTRIES(2*i+2)
            ) or_reduction_inst (
                .in_arr(yrot_masked),
                .or_out(yrot_age)
            );

            if (i >= 1) begin
                // get yrot from branch epoch
                wire [$clog2(i)-1:0] yrot_epoch_idx;
                priority_encoder_1 #(
                    .NUM_INPUTS(i)
                ) pe_yrot (
                    .in(load_depend_graph[i-1][i-1:0]),
                    .out(yrot_epoch_idx)
                );
                // select between age matrix and branch epoch
                assign younger_outputs[i]
                    = (| load_depend_graph[i-1][i-1:0] == 1'b1)
                    ? branch_epochs[yrot_epoch_idx]
                    : yrot_age;
            end else begin
                assign younger_outputs[i] = yrot_age;
            end
        end
    endgenerate
endmodule

// generate output yrots for dest archreg
module get_output_yrots #(
    parameter NUM_DECODE = 4,
    parameter NUM_ROB = 512,
    parameter YROT_WIDTH = $clog2(NUM_ROB)
) (
    input [YROT_WIDTH:0] branch_epochs [NUM_DECODE-1:0],
    input [NUM_DECODE-1:0] load_bit_vec,
    input [(YROT_WIDTH+1)-1:0] younger_outputs [NUM_DECODE-1:0],
    output [(YROT_WIDTH+1)-1:0] output_yrots [NUM_DECODE-1:0]
);
    genvar i;
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            assign output_yrots[i]
                = (load_bit_vec[i] == 1)
                ? branch_epochs[i]
                : younger_outputs[i];
        end
    endgenerate
endmodule