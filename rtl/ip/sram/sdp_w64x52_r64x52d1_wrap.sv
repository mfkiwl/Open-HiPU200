// ---------------------------------------------------------------------------------------------------------------------
// Copyright (c) 1986 - 2020, CAG team, Institute of AI and Robotics, Xi'an Jiaotong University
// All Rights Reserved. You may not use this file in commerce unless acquired the permmission of CAG team.
// ---------------------------------------------------------------------------------------------------------------------
// FILE NAME  : sdp_w64x52_r64x52d1_wrap.sv
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns/1ps

// `define PLATFORM_ASIC
`include "glb_def.svh"

module sdp_w64x52_r64x52d1_wrap (
    input           wr_clk_i,
    input           we_i,
    input [5:0]     waddr_i,
    input [51:0]    wdata_i,
    input [51:0]    wdata_bwe_i,
    input           rd_clk_i,
    input           re_i,
    input [5:0]     raddr_i,
    output[51:0]    rdata_o
);

`ifdef PLATFORM_SIM
    sdp_sram_with_bwe #(
        .WR_ADDR_WTH    (6),
        .WR_DATA_WTH    (52),
        .RD_ADDR_WTH    (6),
        .RD_DATA_WTH    (52),
        .RD_DELAY       (1)
    ) sdp_w64x52_r64x52d1_inst (
        .wr_clk_i       (wr_clk_i),
        .we_i           (we_i),
        .waddr_i        (waddr_i),
        .wdata_i        (wdata_i),
        .wdata_bwe_i    (wdata_bwe_i),
        .rd_clk_i       (rd_clk_i),
        .re_i           (re_i),
        .raddr_i        (raddr_i),
        .rdata_o        (rdata_o)
    );
`endif

`ifdef PLATFORM_XILINX
    sdp_w64x56_r64x56d1 sdp_w64x56_r64x56d1_inst (
        .clka           (wr_clk_i),
        .ena            (1'b1),
        .wea            ({7{we_i}}),
        .addra          (waddr_i),
        .dina           (wdata_i),
        .clkb           (rd_clk_i),
        .enb            (1'b1),
        .addrb          (raddr_i),
        .doutb          (rdata_o)
    );
`endif

`ifdef PLATFORM_ASIC
    logic[51 : 0]   bweb;
    logic           web;
    logic           reb, reb_dly1;
    logic[51 : 0]   wdata_dly1, q;

    assign bweb = ~wdata_bwe_i;

    assign web = ~we_i;

    assign reb = (waddr_i == raddr_i) && we_i;

    always_ff @(posedge rd_clk_i) begin
        reb_dly1 <= reb;
        wdata_dly1 <= wdata_i;
    end
    assign rdata_o = reb_dly1 ? wdata_dly1 : q;

    TS6N28HPCPSVTA64X52M4FW sdp_w64x52_r64x52d1_inst (
        // mode
        //.SLP            (1'b0),
        //.SD             (1'b0),
        //.VDD            (1'b1),
        //.VSS            (1'b0),
        // port A (Write)
        .CLKW           (wr_clk_i),
        .AA             (waddr_i),
        .D              (wdata_i),
        .BWEB           (bweb),
        .WEB            (web),
        // port B (Read)
        .CLKR           (rd_clk_i),
        .AB             (raddr_i),
        .REB            (reb),
        .Q              (q)
        // BIST
        //.BIST           (1'b0),
        //.AMA            (6'h0),
        //.DM             (52'h0),
        //.BWEBM          (52'h0),
        //.WEBM           (1'b0),
        //.AMB            (6'h0),
        //.REBM           (1'b0)
    );
`endif

endmodule : sdp_w64x52_r64x52d1_wrap
