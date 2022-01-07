`timescale 1ns/1ps
/*
 * N-bit comparator
 */
module comparator #(parameter WTH = 9)
(
    input en,
    input [WTH-1:0] a, b,
    output logic out
);
//logic a_d,b_d;
//assign a_d = | a;
//assign b_d = | b;

//assign out = en ?  (a_d === 1'bx || b_d=== 1'bx) ?  0 : (a == b)   : 0;
assign out = en ?  (a == b)   : 0;
       
endmodule : comparator
