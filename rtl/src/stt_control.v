//=========================================================================
// STT Control Path
//-------------------------------------------------------------------------

// Description: A parameterized STT Control Path Circuit.
// Given the equality check result, compute the yrot dependency graph.
// input:
// - raw_eq_out_matrix: RAW dependency check matrix (direct dependency graph)
// ----- raw_eq_out_matrix[2*(i-1)][i-1:0] is the dependency from first src reg of instr i
// ----- to previous dest reg [i-1:0]
// output:
// - yrot_ctrl: yrot dependency graph (points from source registers to dest instr)
// - trans_graph: transitive closure of the direct dependency graph

module stt_ctrl #(
    parameter NUM_DECODE = 8,
    parameter DECODE_WIDTH = $clog2(NUM_DECODE)
) (
    input [NUM_DECODE-2:0] raw_eq_out_matrix [2*(NUM_DECODE-1)-1:0],
    output [2*NUM_DECODE-1:0] yrot_ctrl [NUM_DECODE-2:0]
);
    wire [2*NUM_DECODE-1:0] free_bit;
    wire [NUM_DECODE-1:0] trans_graph [NUM_DECODE-2:0];
    genvar i, j, k;
    // compute transitive closure
    generate
        for (i = 1; i < NUM_DECODE; i = i+1) begin
            // i for the distance between two instrs
            for (j = i; j < NUM_DECODE; j = j+1) begin
                // check connectivity between instr j-i and j
                if (i == 1) begin
                    // distance = 1
                    assign trans_graph[j-1][j-i] = 
                        raw_eq_out_matrix[2*(j-1)][j-i]
                        | raw_eq_out_matrix[2*(j-1)+1][j-i];
                end else begin
                    // check direct connectivity
                    wire direct_connect;
                    assign direct_connect = 
                        raw_eq_out_matrix[2*(j-1)][j-i]
                        | raw_eq_out_matrix[2*(j-1)+1][j-i];
                    // check intermediate connectivity
                    wire [i-2:0] inter_connect;
                    for (k = 1; k < i; k = k+1) begin
                        wire bridge1, bridge2;
                        assign inter_connect[k-1] = bridge1 & bridge2;

                        assign bridge1 = trans_graph[j-i+k-1][j-i];
                        assign bridge2 = trans_graph[j-1][j-i+k];
                    end
                    assign trans_graph[j-1][j-i] = 
                        | {inter_connect, direct_connect};
                end
            end
        end
    endgenerate

    // compute yrot dependency graph
    generate
        for (i = 1; i < NUM_DECODE; i = i+1) begin
            for (j = 0; j <= i; j = j+1) begin
                if (i == j) begin
                    assign yrot_ctrl[i-1][2*j] = free_bit[2*j];
                    assign yrot_ctrl[i-1][2*j+1] = free_bit[2*j+1];
                end else begin
                    assign yrot_ctrl[i-1][2*j] = trans_graph[i-1][j] & free_bit[2*j];
                    assign yrot_ctrl[i-1][2*j+1] = trans_graph[i-1][j] & free_bit[2*j+1];
                end
            end
        end
    endgenerate

    // identify free reg
    assign free_bit[0] = 1'b1;
    assign free_bit[1] = 1'b1;
    generate
        for (i = 1; i < NUM_DECODE; i = i+1) begin
            wire depend1;
            wire depend2;
            assign depend1 = | raw_eq_out_matrix[2*(i-1)+1][i-1:0];
            assign depend2 = | raw_eq_out_matrix[2*(i-1)][i-1:0];
            assign free_bit[2*i+1] = ~depend1;
            assign free_bit[2*i] = ~depend2;
        end
    endgenerate
endmodule

// load dependency graph comp
module stt_load_ctrl #(
    parameter NUM_DECODE = 8,
    parameter DECODE_WIDTH = $clog2(NUM_DECODE)
) (
    input [NUM_DECODE-2:0] raw_eq_out_matrix [2*(NUM_DECODE-1)-1:0],
    input [NUM_DECODE-1:0] load_bit_vec,
    output [NUM_DECODE-1:0] load_depend_graph [NUM_DECODE-2:0]
);
    wire [NUM_DECODE-1:0] trans_graph [NUM_DECODE-2:0];
    genvar i, j, k;
    // compute transitive closure
    generate
        for (i = 1; i < NUM_DECODE; i = i+1) begin
            // i for the distance between two instrs
            for (j = i; j < NUM_DECODE; j = j+1) begin
                // check connectivity between instr j-i and j
                if (i == 1) begin
                    // distance = 1
                    assign trans_graph[j-1][j-i] = 
                        raw_eq_out_matrix[2*(j-1)][j-i]
                        | raw_eq_out_matrix[2*(j-1)+1][j-i];
                end else begin
                    // check direct connectivity
                    wire direct_connect;
                    assign direct_connect = 
                        raw_eq_out_matrix[2*(j-1)][j-i]
                        | raw_eq_out_matrix[2*(j-1)+1][j-i];
                    // check intermediate connectivity
                    wire [i-2:0] inter_connect;
                    for (k = 1; k < i; k = k+1) begin
                        wire bridge1, bridge2;
                        assign inter_connect[k-1] = bridge1 & bridge2;

                        assign bridge1 = trans_graph[j-i+k-1][j-i];
                        assign bridge2 = trans_graph[j-1][j-i+k];
                    end
                    assign trans_graph[j-1][j-i] = 
                        | {inter_connect, direct_connect};
                end
            end
        end
    endgenerate

    // compute load dependency graph
    generate
        for (i = 1; i < NUM_DECODE; i = i+1) begin
            for (j = 0; j < i; j = j+1) begin
                assign load_depend_graph[i-1][j] = trans_graph[i-1][j] & load_bit_vec[j];
            end
        end
    endgenerate
endmodule

// Deprecated
module stt_ctrl_recur #(
    parameter NUM_DECODE = 8,
    parameter DECODE_WIDTH = $clog2(NUM_DECODE)
) (
    input [NUM_DECODE-2:0] raw_eq_out_matrix [2*(NUM_DECODE-1)-1:0],
    output [NUM_DECODE-1:0] yrot_ctrl [NUM_DECODE-2:0],
    output [NUM_DECODE-1:0] trans_graph [NUM_DECODE-2:0],
    output [NUM_DECODE-1:0] color_bit,
    output [2*(NUM_DECODE-1)-1:0] free_bit
);

    genvar i, j;
    // compute transitive closure
    generate
        for (i = 1; i < NUM_DECODE; i = i+1) begin
            for (j = 0; j <= i; j = j+1) begin
                comp_trans #(
                    .NUM_DECODE(NUM_DECODE),
                    .DISTANCE(i-j)
                ) trans (
                    .raw_eq_out_matrix(raw_eq_out_matrix),
                    .src_inst(j),
                    .dest_inst(i),
                    .connect_bit(trans_graph[i-1][j])
                );
                assign yrot_ctrl[i-1][j] = trans_graph[i-1][j]
                                            & color_bit[j];
            end
        end
    endgenerate

    // compute color inst and free reg
    assign color_bit[0] = 1'b1;
    generate
        for (i = 1; i < NUM_DECODE; i = i+1) begin
            wire [i-1:0] depend1;
            wire [i-1:0] depend2;
            assign depend1 = | raw_eq_out_matrix[2*(i-1)+1][i-1:0];
            assign depend2 = | raw_eq_out_matrix[2*(i-1)][i-1:0];
            assign free_bit[2*(i-1)+1] = ~depend1;
            assign free_bit[2*(i-1)] = ~depend2;
            assign color_bit[i] = ~(depend1 & depend2);
        end
    endgenerate
    
endmodule

// Deprecated
// Recurrsively check connectivity
// input:
// - raw_eq_out_matrix: RAW dependency check matrix (direct dependency graph)
// ----- raw_eq_out_matrix[2*(i-1)][i-1:0] is the dependency from first src reg of instr i
// ----- to previous dest reg [i-1:0]
// - src_inst
// - dest_inst
// output:
// - connect_bit
module comp_trans #(
    parameter NUM_DECODE = 8,
    parameter DECODE_WIDTH = $clog2(NUM_DECODE),
    parameter DISTANCE = 1
) (
    input [NUM_DECODE-2:0] raw_eq_out_matrix [2*(NUM_DECODE-1)-1:0],
    input [DECODE_WIDTH-1:0] src_inst,
    input [DECODE_WIDTH-1:0] dest_inst,
    output connect_bit
);

    genvar i;
    generate
        if (DISTANCE == 1) begin
            // if two instructions are adjacent
            // then check if one of the src regs of dest inst
            // depend on the dest reg of src inst
            assign connect_bit = 
                raw_eq_out_matrix[2*(dest_inst-1)][src_inst]
                | raw_eq_out_matrix[2*(dest_inst-1)+1][src_inst];
        end else if (DISTANCE == 0) begin
            // DISTANCE = 0 means the same inst
            // return true because every inst src depends on itself
            assign connect_bit = 1'b1;
        end else begin
            // check direct connectivity
            wire direct_connect;
            assign direct_connect = 
                raw_eq_out_matrix[2*(dest_inst-1)][src_inst]
                | raw_eq_out_matrix[2*(dest_inst-1)+1][src_inst];
            // check intermediate connectivity
            wire [DISTANCE-2:0] inter_connect;
            for (i = 1; i < DISTANCE; i = i+1) begin
                wire bridge1, bridge2;
                assign inter_connect[i-1] = bridge1 & bridge2;

                comp_trans #(
                    .NUM_DECODE(NUM_DECODE),
                    .DISTANCE(i)
                ) comp_trans1 (
                    .raw_eq_out_matrix(raw_eq_out_matrix),
                    .src_inst(src_inst),
                    .dest_inst(src_inst+i),
                    .connect_bit(bridge1)
                );

                comp_trans #(
                    .NUM_DECODE(NUM_DECODE),
                    .DISTANCE(DISTANCE-i)
                ) comp_trans2 (
                    .raw_eq_out_matrix(raw_eq_out_matrix),
                    .src_inst(src_inst+i),
                    .dest_inst(dest_inst),
                    .connect_bit(bridge2)
                );
            end
            // OR all the possible cases
            assign connect_bit = | {inter_connect, direct_connect};
        end
    endgenerate
endmodule