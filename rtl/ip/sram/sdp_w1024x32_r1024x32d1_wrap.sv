// ---------------------------------------------------------------------------------------------------------------------
// Copyright (c) 1986 - 2020, CAG team, Institute of AI and Robotics, Xi'an Jiaotong University
// All Rights Reserved. You may not use this file in commerce unless acquired the permmission of CAG team.
// ---------------------------------------------------------------------------------------------------------------------
// FILE NAME  : sdp_w1024x32_r1024x32d1_wrap.sv
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns/1ps

// `define PLATFORM_ASIC
`include "glb_def.svh"

module sdp_w1024x32_r1024x32d1_wrap (
    input           wr_clk_i,
    input           we_i,
    input [9:0]     waddr_i,
    input [31:0]    wdata_i,
    input [3:0]     wdata_strob_i,
    input           rd_clk_i,
    input           re_i,
    input [9:0]     raddr_i,
    output[31:0]    rdata_o
);

`ifdef PLATFORM_SIM
    sdp_sram_with_strobe #(
        .WR_ADDR_WTH    (10),
        .WR_DATA_WTH    (32),
        .RD_ADDR_WTH    (10),
        .RD_DATA_WTH    (32),
        .RD_DELAY       (1)
    ) sdp_w1024x32_r1024x32d1_inst (
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
    sdp_w1024x32_r1024x32d1 sdp_w1024x32_r1024x32d1_inst (
        .clka           (wr_clk_i),
        .ena            (1'b1),
        .wea            ({3{we_i}} & wdata_strob_i),
        .addra          (waddr_i),
        .dina           (wdata_i),
        .clkb           (rd_clk_i),
        .enb            (1'b1),
        .addrb          (raddr_i),
        .doutb          (rdata_o)
    );
`endif

`ifdef PLATFORM_ASIC
    logic[31 : 0]   bweba;
    logic           weba;
    logic           cebb, cebb_dly1;
    logic[31 : 0]   wdata_dly1, qb;

    always_comb begin
        for(integer i=0; i<3; i=i+1) begin
            bweba[i*8 +: 8] = ~{8{wdata_strob_i[i]}};
        end
    end

    assign weba = ~we_i;

    assign cebb = (waddr_i == raddr_i) && we_i;

    always_ff @(posedge rd_clk_i) begin
        cebb_dly1 <= cebb;
        wdata_dly1 <= wdata_i;
    end
    assign rdata_o = cebb_dly1 ? wdata_dly1 : qb;
    TSDN28HPCPA1024X32M8FW sdp_w1024x32_r1024x32d1_inst (
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
        .CLKA           (wr_clk_i),
        .AA             (waddr_i),
        .DA             (wdata_i),
        .BWEBA          (bweba),
        .WEBA           (weba),
        .CEBA           (1'b0),
        .QA             (),
        // port B
        .CLKB           (rd_clk_i),
        .AB             (raddr_i),
        .DB             ('h0),
        .BWEBB          ('h0),
        .WEBB           (1'b1),
        .CEBB           (cebb),
        .QB             (qb)
        // BIST
        //.BIST           (1'b0),
        //.CLKM           (1'b0),
        //.AMA            (10'h0),
        //.DMA            (32'h0),
        //.BWEBMA         (32'h0),
        //.WEBMA          (1'h0),
        //.CEBMA          (1'h0),
        //.AMB            (10'h0),
        //.DMB            (32'h0),
        //.BWEBMB         (32'h0),
        //.WEBMB          (1'h0),
        //.CEBMB          (1'h0)
    );
`endif

endmodule : sdp_w1024x32_r1024x32d1_wrap
