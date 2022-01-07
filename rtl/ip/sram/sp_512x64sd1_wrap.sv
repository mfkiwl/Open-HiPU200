// ---------------------------------------------------------------------------------------------------------------------
// Copyright (c) 1986 - 2020, CAG team, Institute of AI and Robotics, Xi'an Jiaotong University
// All Rights Reserved. You may not use this file in commerce unless acquired the permmission of CAG team.
// ---------------------------------------------------------------------------------------------------------------------
// FILE NAME  : sp_512x64sd1_wrap.sv
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns/1ps

// `define PLATFORM_ASIC
`include "glb_def.svh"

module sp_512x64sd1_wrap (
    input           clk_i,
    input           cs_i,
    input           we_i,
    input [8:0]     addr_i,
    input [63:0]    wdata_i,
    input [7:0]     wdata_strob_i,
    output[63:0]    rdata_o
);

`ifdef PLATFORM_SIM
    sp_sram_with_strobe #(
        .ADDR_WTH       (9),
        .DATA_WTH       (64),
        .RD_DELAY       (1)
    ) sp_512x64d1_inst (
        .clk_i          (clk_i),
        .we_i           (we_i),
        .addr_i         (addr_i),
        .wdata_i        (wdata_i),
        .wdata_strob_i  (wdata_strob_i),
        .rdata_o        (rdata_o)
    );
`endif

`ifdef PLATFORM_XILINX
    sp_512x64d1 sp_512x64d1_inst (
        .clka           (clk_i),
        .ena            (cs_i),
        .wea            ({8{we_i}} & wdata_strob_i),
        .addra          (addr_i),
        .dina           (wdata_i),
        .douta          (rdata_o)
    );
`endif

`ifdef PLATFORM_ASIC
    logic[63 : 0]   bweb;
    logic           web;
    logic           ceb;

    always_comb begin
        for(integer i=0; i<8; i=i+1) begin
            bweb[i*8 +: 8] = ~{8{wdata_strob_i[i]}};
        end
    end
    assign web = ~we_i;
    assign ceb = ~cs_i;

    TS1N28HPCPUHDSVTB512X64M4SW 
    #(
        .numStuckAt (0)
    )
    sp_512x64d1_inst (
        .WTSEL          (2'b00),
        .RTSEL          (2'b01),
        //.VDD            (1'b1),
        //.VSS            (1'b0),
        //.SLP            (1'b0),
        //.SD             (1'b0),
        // port
        .CLK            (clk_i),
        .A              (addr_i),
        .D              (wdata_i),
        .BWEB           (bweb),
        .WEB            (web),
        .CEB            (ceb),
        .Q              (rdata_o)
        // BIST
        //.BIST           (1'b0),
        //.AM             (9'h0),
        //.DM             (64'h0),
        //.WEBM           (1'b0),
        //.CEBM           (1'b1),
        //.BWEBM          (64'h0)
    );
`endif

endmodule : sp_512x64sd1_wrap
