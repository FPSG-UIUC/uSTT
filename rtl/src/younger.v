//=========================================================================
// Younger than operator
//-------------------------------------------------------------------------

// Description: A parameterized younger than operator.
// Given two Yrot, outputs the Yrot that is younger.
// input:
// - yrot1
// - yrot2
// - wrap_bit: wrap bit (indicate the MSB for wraparound or not)
// output:
// - output_yrot

module younger #(
    parameter YROT_WIDTH = 9
) (
    input [YROT_WIDTH:0] yrot1,
    input [YROT_WIDTH:0] yrot2,
    input wrap_bit,
    output reg [YROT_WIDTH:0] output_yrot
);
    // younger than comparator -> yrot selector
    wire younger_sel;

    younger_than #(
        .YROT_WIDTH(YROT_WIDTH)
    ) younger_than_inst (
        .yrot1(yrot1),
        .yrot2(yrot2),
        .wrap_bit(wrap_bit),
        .younger_sel(younger_sel)
    );

    mux2to1 #(
        .WIDTH(YROT_WIDTH+1)
    ) mux2to1_inst (
        .in1(yrot1),
        .in2(yrot2),
        .sel(younger_sel),
        .out(output_yrot)
    );
endmodule

// younger than comparator
module younger_than #(
    parameter YROT_WIDTH = 9
) (
    input [YROT_WIDTH:0] yrot1,
    input [YROT_WIDTH:0] yrot2,
    input wrap_bit,
    output reg younger_sel
);
    wire same_side;
    assign same_side = ~(yrot1[YROT_WIDTH] ^ yrot2[YROT_WIDTH]);
    always @(*) begin
        // both yrot on the same side
        if (same_side) begin
            younger_sel = yrot1[YROT_WIDTH-1:0] < yrot2[YROT_WIDTH-1:0];
        end else begin
            younger_sel = wrap_bit ? yrot2[YROT_WIDTH] : yrot1[YROT_WIDTH];
        end
    end
endmodule


module younger_og #(
    parameter YROT_WIDTH = 9
) (
    input [YROT_WIDTH:0] yrot1,
    input [YROT_WIDTH:0] yrot2,
    input [YROT_WIDTH-1:0] branch_head,
    output reg [YROT_WIDTH:0] output_yrot
);
    // younger than comparator -> yrot selector
    wire younger_sel;

    younger_than_og #(
        .YROT_WIDTH(YROT_WIDTH)
    ) younger_than_inst (
        .yrot1(yrot1),
        .yrot2(yrot2),
        .branch_head(branch_head),
        .younger_sel(younger_sel)
    );

    mux2to1 #(
        .WIDTH(YROT_WIDTH+1)
    ) mux2to1_inst (
        .in1(yrot1),
        .in2(yrot2),
        .sel(younger_sel),
        .out(output_yrot)
    );
endmodule

module younger_than_og #(
    parameter YROT_WIDTH = 9
) (
    input [YROT_WIDTH-1:0] yrot1,
    input [YROT_WIDTH-1:0] yrot2,
    input [YROT_WIDTH-1:0] branch_head,
    output reg younger_sel
);
    wire yrot1_side = yrot1 >= branch_head;
    wire yrot2_side = yrot2 >= branch_head;

    always @(*) begin
        if (yrot1_side == yrot2_side) 
            younger_sel = yrot1 < yrot2;
        else 
            younger_sel = yrot1_side;
    end
endmodule

// bulk younger than comparator
module younger_than_bulk #(
    parameter YROT_WIDTH = 9,
    parameter NUM_ENTRIES = 4
) (
    input [YROT_WIDTH:0] yrot_arr [NUM_ENTRIES-1:0],
    input wrap_bit,
    output [NUM_ENTRIES-1:0] younger_sel_arr [NUM_ENTRIES-1:0]
);
    genvar i, j;
    generate
        for (i = 0; i < NUM_ENTRIES; i = i+1) begin
            for (j = 0; j < NUM_ENTRIES; j = j+1) begin
                if (j < i) begin
                    assign younger_sel_arr[i][j] = ~younger_sel_arr[j][i];
                end else if (i != j) begin
                    younger_than #(
                        .YROT_WIDTH(YROT_WIDTH)
                    ) younger_than_inst (
                        .yrot1(yrot_arr[i]),
                        .yrot2(yrot_arr[j]),
                        .wrap_bit(wrap_bit),
                        .younger_sel(younger_sel_arr[i][j])
                    );
                end else begin
                    assign younger_sel_arr[i][j] = 1'b0;
                end
            end
        end
    endgenerate
endmodule

// 2-to-1 mux
module mux2to1 #(
    parameter WIDTH = 9
) (
    input [WIDTH-1:0] in1,
    input [WIDTH-1:0] in2,
    input sel,
    output [WIDTH-1:0] out
);
    assign out = sel ? in2 : in1;
endmodule

module or_reduction #(
    parameter WIDTH = 9,
    parameter NUM_ENTRIES = 4
) (
    input [WIDTH-1:0] in_arr [NUM_ENTRIES-1:0],
    output reg [WIDTH-1:0] or_out
);
    integer i;
    always @(*) begin
        or_out = 0;
        for (i = 0; i < NUM_ENTRIES; i = i+1) begin
            or_out = or_out | in_arr[i];
        end
    end
endmodule

//=========================================================================
// Branch Epoch Gen
//-------------------------------------------------------------------------

// Description: A parameterized branch epoch generator.
// Given branch tail and inst branch bits, generate branch epoch array.
// input:
// - last time branch epoch
// - branch tail
// - branch bit vec
// output:
// - branch_epochs
module branch_epoch_gen #(
    parameter YROT_WIDTH = 9,
    parameter NUM_DECODE = 4
) (
    input [(YROT_WIDTH+1)-1:0] last_epoch,
    input [YROT_WIDTH-1:0] branch_tail,
    input wrap_bit,
    input [NUM_DECODE-1:0] branch_bit_vec,
    output reg [(YROT_WIDTH+1)-1:0] branch_epochs [NUM_DECODE-1:0]
);
    // ROB index vector
    reg [YROT_WIDTH-1:0] rob_index_vec [NUM_DECODE-1:0];
    always @(*) begin
        rob_index_vec[0] = branch_tail;
        for (integer i = 1; i < NUM_DECODE; i = i+1) begin
            rob_index_vec[i] = rob_index_vec[i-1] + {{YROT_WIDTH-1{1'b0}}, 1'b1};
        end
    end

    genvar i;
    // wrap bit vector (flip it if wrap around)
    wire wrap_bit_vec [NUM_DECODE-1:0];
    wire [NUM_DECODE-1:0] index_zero_vec;
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            assign index_zero_vec[i] = (rob_index_vec[i] == {YROT_WIDTH{1'b0}});
            assign wrap_bit_vec[i] = (|index_zero_vec[i:0]) ? ~wrap_bit : wrap_bit;
        end
    endgenerate

    // assign speculation epoch
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            // priority encoder to select the most recent branch
            wire [$clog2(i+1)+1-1:0] pri_out;
            priority_encoder #(
                .NUM_INPUTS(i+1)
            ) pe (
                .in(branch_bit_vec[i:0]),
                .out(pri_out)
            );
            // if pri_out is 0, then it is the last epoch
            // else, use pri_out-1 to select from rob_index_vec
            assign branch_epochs[i] = (pri_out == 0) ? last_epoch : {wrap_bit_vec[pri_out-1], rob_index_vec[pri_out-1]};
        end
                
    endgenerate
endmodule

// OG-STT does not use speculation epoch, so it will be each instruction ROB Index
module branch_epoch_gen_og #(
    parameter YROT_WIDTH = 9,
    parameter NUM_DECODE = 4
) (
    input [YROT_WIDTH-1:0] branch_tail,
    output reg [YROT_WIDTH-1:0] branch_epochs [NUM_DECODE-1:0]
);

    genvar i;
    generate
        for (i = 0; i < NUM_DECODE; i = i+1) begin
            integer j;
            always @(*) begin
                branch_epochs[i] = branch_tail;
                for (j = 0; j < i; j = j+1) begin
                    branch_epochs[i] = branch_epochs[i]
                        + {{YROT_WIDTH-1{1'b0}}, 1'b1};
                end
            end
        end
    endgenerate

endmodule