
`timescale 1ns/1ps
/*
 * N-bit 8-length array
 */
module encoder
(
    input a,
    input b,
    input c,
    input d,
    output logic [1:0] out
);

always_comb
begin
    if (a)
        out = 2'b00;

    else if (b)
        out = 2'b01;

    else if (c)
        out = 2'b10;

    else if (d)
        out = 2'b11;

    else
        out = 2'b00;
end

endmodule : encoder
