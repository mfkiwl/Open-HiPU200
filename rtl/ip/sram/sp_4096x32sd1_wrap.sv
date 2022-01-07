// ---------------------------------------------------------------------------------------------------------------------
// Copyright (c) 1986 - 2020, CAG team, Institute of AI and Robotics, Xi'an Jiaotong University
// All Rights Reserved. You may not use this file in commerce unless acquired the permmission of CAG team.
// ---------------------------------------------------------------------------------------------------------------------
// FILE NAME  : sp_4096x32sd1_wrap.sv
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns/1ps

// `define PLATFORM_ASIC
`include "glb_def.svh"

module sp_4096x32sd1_wrap (
    input           clk_i,
    input           cs_i,
    input           we_i,
    input [11:0]    addr_i,
    input [31:0]    wdata_i,
    input [3:0]     wdata_strob_i,
    output[31:0]    rdata_o
);

`ifdef PLATFORM_SIM
    sp_sram_with_strobe #(
        .ADDR_WTH       (12),
        .DATA_WTH       (32),
        .RD_DELAY       (1)
    ) sp_1024x32d1_inst (
        .clk_i          (clk_i),
        .we_i           (we_i),
        .waddr_i        (addr_i),
        .wdata_i        (wdata_i),
        .wdata_strob_i  (wdata_strob_i),
        .rdata_o        (rdata_o)
    );
`endif

`ifdef PLATFORM_XILINX
    sp_4096x32d1 sp_4096x32d1_inst (
        .clka           (clk_i),
        .ena            (cs_i),
        .wea            ({4{we_i}} & wdata_strob_i),
        .addra          (addr_i),
        .dina           (wdata_i),
        .douta          (rdata_o)
    );
`endif

`ifdef PLATFORM_ASIC
    logic[31 : 0]   bweb;
    logic           web;
    logic           ceb0, ceb1;
    logic[11 : 0]   addr_reg;
    logic[31 : 0]   rdata0, rdata1;

    always_comb begin
        for(integer i=0; i<4; i=i+1) begin
            bweb[i*8 +: 8] = ~{8{wdata_strob_i[i]}};
        end
    end
    assign web = ~we_i;
    assign ceb0 = ~(cs_i & ~addr_i[11]);
    assign ceb1 = ~(cs_i & addr_i[11]);

    always_ff @(posedge clk_i) begin
        addr_reg <= addr_i;
    end
    assign rdata_o = addr_reg[11] ? rdata1 : rdata0;

    TS1N28HPCPUHDSVTB2048X32M4SW 
    #(
        .numStuckAt (0)
    )
    sp_2048x32d1_inst0 (
        .WTSEL          (2'b00),
        .RTSEL          (2'b00),
        //.VDD            (1'b1),
        //.VSS            (1'b0),
        //.SLP            (1'b0),
        //.SD             (1'b0),
        // port
        .CLK            (clk_i),
        .A              (addr_i[10 : 0]),
        .D              (wdata_i),
        .BWEB           (bweb),
        .WEB            (web),
        .CEB            (ceb0),
        .Q              (rdata0)
        // BIST
        //.BIST           (1'b0),
        //.AM             (10'h0),
        //.DM             (32'h0),
        //.WEBM           (1'b0),
        //.CEBM           (1'b1),
        //.BWEBM          (32'h0)
    );
    TS1N28HPCPUHDSVTB2048X32M4SW 
    #(
        .numStuckAt (0)
    )
    sp_2048x32d1_inst1 (
        .WTSEL          (2'b00),
        .RTSEL          (2'b00),
        //.VDD            (1'b1),
        //.VSS            (1'b0),
        //.SLP            (1'b0),
        //.SD             (1'b0),
        // port
        .CLK            (clk_i),
        .A              (addr_i[10 : 0]),
        .D              (wdata_i),
        .BWEB           (bweb),
        .WEB            (web),
        .CEB            (ceb1),
        .Q              (rdata1)
        // BIST
        //.BIST           (1'b0),
        //.AM             (10'h0),
        //.DM             (32'h0),
        //.WEBM           (1'b0),
        //.CEBM           (1'b1),
        //.BWEBM          (32'h0)
    );
`endif

endmodule : sp_4096x32sd1_wrap
