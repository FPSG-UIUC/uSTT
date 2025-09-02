//=========================================================================
// Priority equality comparator
//-------------------------------------------------------------------------

// Description: Given an ID and a array of ID, return the closest ID match.
// input:
// - id: ID to be compared
// - id_array: an array of ID to do equality check with the id
// output:
// - pri_out: priority encoder output
// - eq_out: equality check output vector


module eq_comp #(
    parameter ID_WIDTH,
    parameter NUM_ID,
    parameter OUTPUT_WIDTH = $clog2(NUM_ID+1)
) (
    input [ID_WIDTH-1:0] id,
    input [ID_WIDTH-1:0] id_array [NUM_ID-1:0],
    output [OUTPUT_WIDTH-1:0] pri_out,
    output [NUM_ID-1:0] eq_out
);
    genvar i;
    generate
        for (i = 0; i < NUM_ID; i = i+1) begin
            assign eq_out[i] = id == id_array[i];
        end
    endgenerate

    priority_encoder #(
        .NUM_INPUTS(NUM_ID)
    ) pe (
        .in(eq_out),
        .out(pri_out)
    );
    
endmodule