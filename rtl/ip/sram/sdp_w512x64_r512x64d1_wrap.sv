// ---------------------------------------------------------------------------------------------------------------------
// Copyright (c) 1986 - 2020, CAG team, Institute of AI and Robotics, Xi'an Jiaotong University
// All Rights Reserved. You may not use this file in commerce unless acquired the permmission of CAG team.
// ---------------------------------------------------------------------------------------------------------------------
// FILE NAME  : sdp_w512x64_r512x64d1_wrap.sv
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns/1ps

// `define PLATFORM_ASIC
`include "glb_def.svh"

module sdp_w512x64_r512x64d1_wrap (
    input           wr_clk_i,
    input           we_i,
    input [8:0]     waddr_i,
    input [63:0]    wdata_i,
    input [7:0]     wdata_strob_i,
    input           rd_clk_i,
    input           re_i,
    input [8:0]     raddr_i,
    output[63:0]    rdata_o
);

`ifdef PLATFORM_SIM
    sdp_sram_with_strobe #(
        .WR_ADDR_WTH    (9),
        .WR_DATA_WTH    (64),
        .RD_ADDR_WTH    (9),
        .RD_DATA_WTH    (64),
        .RD_DELAY       (1)
    ) sdp_w512x64_r512x64d1_inst (
        .wr_clk_i       (wr_clk_i),
        .we_i           (we_i),
        .waddr_i        (waddr_i),
        .wdata_i        (wdata_i),
        .wdata_strob_i  (wdata_strob_i),
        .rd_clk_i       (rd_clk_i),
        .re_i           (re_i),
        .raddr_i        (raddr_i),
        .rdata_o        (rdata_o)
    );
`endif

`ifdef PLATFORM_XILINX
    sdp_w512x64_r512x64d1 sdp_w512x64_r512x64d1_inst (
        .clka           (wr_clk_i),
        .ena            (1'b1),
        .wea            ({8{we_i}} & wdata_strob_i),
        .addra          (waddr_i),
        .dina           (wdata_i),
        .clkb           (rd_clk_i),
        .enb            (1'b1),
        .addrb          (raddr_i),
        .doutb          (rdata_o)
    );
`endif

`ifdef PLATFORM_ASIC
    logic[63 : 0]   bwebb;
    logic           webb;
    logic           ceba, ceba_dly1;
    logic[63 : 0]   wdata_dly1, qa;

    always_comb begin
        for(integer i=0; i<8; i=i+1) begin
            bwebb[i*8 +: 8] = ~{8{wdata_strob_i[i]}};
        end
    end

    assign webb = ~we_i;

    assign ceba = (waddr_i == raddr_i) && we_i;

    always_ff @(posedge rd_clk_i) begin
        ceba_dly1 <= ceba;
        wdata_dly1 <= wdata_i;
    end
    assign rdata_o = ceba_dly1 ? wdata_dly1 : qa;
    TSDN28HPCPA512X64M4MW sdp_w512x64_r512x64d1_inst (
        // mode
        //.SLP            (1'b0),
        //.SD             (1'b0),
        //.AWT            (1'b0),
        // debug
        .WTSEL          (2'b01),
        .RTSEL          (2'b01),
        //.VDD            (1'b1),
        //.VSS            (1'b0),
        .VG             (1'b1),
        .VS             (1'b1),
        // port A
        .CLKA           (rd_clk_i),
        .AA             (raddr_i),
        .DA             (64'h0),
        .BWEBA          (64'h0),
        .WEBA           (1'b1),
        .CEBA           (ceba),
        .QA             (qa),
        // port B
        .CLKB           (wr_clk_i),
        .AB             (waddr_i),
        .DB             (wdata_i),
        .BWEBB          (bwebb),
        .WEBB           (webb),
        .CEBB           (1'b0),
        .QB             ()
        // BIST
        //.BIST           (1'b0),
        //.CLKM           (1'b0),
        //.AMA            (9'h0),
        //.DMA            (64'h0),
        //.BWEBMA         (64'h0),
        //.WEBMA          (1'h0),
        //.CEBMA          (1'h0),
        //.AMB            (9'h0),
        //.DMB            (64'h0),
        //.BWEBMB         (64'h0),
        //.WEBMB          (1'h0),
        //.CEBMB          (1'h0)
    );

`endif

endmodule : sdp_w512x64_r512x64d1_wrap
