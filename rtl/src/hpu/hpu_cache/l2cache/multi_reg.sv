`timescale 1ns/1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module multi_reg #(parameter DWTH = 8,AWTH=3)
(
    input   logic                     clk_i,
    input   logic                     rst_i,
    input   logic                     all_srst_i,
    input   logic                     w_en_set_i,
    input   logic                     w_en_reset_i,    
    input   logic [  AWTH-1:0   ]     waddr_i,
    input   logic [  AWTH-1:0   ]     raddr_i,
    output  logic                     rdata_o
);

logic [DWTH-1:0] data;
integer i;

always_ff@(posedge clk_i, `RST_DECL(rst_i))
begin
if(`RST_TRUE(rst_i))
    begin
        for (i=1'b0; i<DWTH; i++) 
            data[i] <= 1'b0;
    end
    else if(all_srst_i) // the global sync reset for all bit
        begin
        for (i=1'b0; i<DWTH; i++) 
            data[i] <= 1'b0;
        end
    else 
        begin
            if(w_en_set_i)  // each set bit set data to 1
                data[waddr_i] <= 1'b1;
            else if(w_en_reset_i)  // each reset bit set data to 0
                data[waddr_i] <= 1'b0;
        end
end

always_comb
begin
    rdata_o = data[raddr_i];
end

endmodule : multi_reg
