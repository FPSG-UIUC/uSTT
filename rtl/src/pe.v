//=========================================================================
// Priority Encoder
//-------------------------------------------------------------------------

// Description: A parameterized priority encoder that supports any number of
// inputs. The module assumes that the MSB of the input is highest priority.
// The output will return the index of first 1 plus 1 => if the input is all
// zeros, then we output 0.

module priority_encoder #(
    parameter NUM_INPUTS = 4,
    parameter OUT_WIDTH = $clog2(NUM_INPUTS+1)
)(
    input [NUM_INPUTS-1:0] in,
    output reg [OUT_WIDTH-1:0] out
);
    integer i;

    always @(*) begin
        out <= 0;
        for (i = NUM_INPUTS-1; i >= 0; i = i-1) begin
            if (in[i]) begin
                out <= i+1;
                break;
            end
        end
    end
endmodule

module priority_encoder_1 #(
    parameter NUM_INPUTS = 4,
    parameter OUT_WIDTH = $clog2(NUM_INPUTS)
)(
    input [NUM_INPUTS-1:0] in,
    output reg [OUT_WIDTH-1:0] out
);
    integer i;

    always @(*) begin
        out <= 0;
        for (i = NUM_INPUTS-1; i >= 0; i = i-1) begin
            if (in[i]) begin
                out <= i;
                break;
            end
        end
    end
endmodule

module param_decoder #(
    parameter IN_WIDTH = 3,
    parameter OUT_WIDTH = 1 << IN_WIDTH
)(
    input  [IN_WIDTH-1:0] in,
    input en,
    output reg [OUT_WIDTH-1:0] out
);

always @(*) begin
    out = {OUT_WIDTH{1'b0}};
    if (en) begin
        out[in] = 1'b1;
    end
end

endmodule
