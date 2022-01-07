`timescale 1ns/1ps

`include "hpu_head.sv"

import hpu_pkg::*;

module array_d1 #(parameter DWTH = 18,parameter AWTH = 3,parameter DEPTH = 8) (
    input   logic                       clk_i,
    input   logic                       rst_i,
    input   logic                       wen_i,
    input   logic[AWTH-1:0]             waddr_i,
    input   logic[DWTH-1:0]             wdata_i,
    input   logic[AWTH-1:0]             raddr_i,
    output  logic[DWTH-1:0]             rdata_o
);

//======================================================================================================================
// Wire & Reg declaration
//======================================================================================================================

    logic[AWTH-1:0]                    raddr_d0;
    integer i;
    logic [DWTH-1:0] data [DEPTH-1:0] ;   

    always_ff@(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            raddr_d0 <= {AWTH{1'b0}};
        end else begin
            raddr_d0 <= raddr_i;
         end
    end

    always_ff@(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for (i=0; i<DEPTH; i++) begin
                data[i] <= {(DWTH-1){1'b0}};
            end
        end else if(wen_i == 1'b1) begin
            data[waddr_i] <= wdata_i;
        end
    end

    assign rdata_o = data[raddr_d0];

endmodule : array_d1
