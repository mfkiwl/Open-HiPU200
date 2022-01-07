`timescale 1ns/1ps
/*
 * N-bit 8-length array
 */
module decoder
(
    input [1:0] in,
    output logic d0,
    output logic d1,
    output logic d2,
    output logic d3
);

always_comb
begin
    if (in == 2'b00)
    begin
        d0 = 1'b1;
        d1 = 1'b0;
        d2 = 1'b0;
        d3 = 1'b0;
    end

    else if (in == 2'b01)
    begin
        d0 = 1'b0;
        d1 = 1'b1;
        d2 = 1'b0;
        d3 = 1'b0;
    end

    else if (in == 2'b10)
    begin
        d0 = 1'b0;
        d1 = 1'b0;
        d2 = 1'b1;
        d3 = 1'b0;
    end

    else if (in == 2'b11)
    begin
        d0 = 1'b0;
        d1 = 1'b0;
        d2 = 1'b0;
        d3 = 1'b1;
    end

    else
    begin
        d0 = 1'b0;
        d1 = 1'b0;
        d2 = 1'b0;
        d3 = 1'b0;
    end
end

endmodule : decoder
