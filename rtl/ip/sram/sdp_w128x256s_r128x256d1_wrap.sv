// ---------------------------------------------------------------------------------------------------------------------
// Copyright (c) 1986 - 2020, CAG team, Institute of AI and Robotics, Xi'an Jiaotong University
// All Rights Reserved. You may not use this file in commerce unless acquired the permmission of CAG team.
// ---------------------------------------------------------------------------------------------------------------------
// FILE NAME  : sdp_w128x256s_r128x256d1_wrap.sv
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns/1ps

// `define PLATFORM_ASIC
`include "glb_def.svh"

module sdp_w128x256s_r128x256d1_wrap (
    input           wr_clk_i,
    input           we_i,
    input [6:0]     waddr_i,
    input [255:0]   wdata_i,
    input [31:0]    wdata_strob_i,
    input           rd_clk_i,
    input           re_i,
    input [6:0]     raddr_i,
    output[255:0]   rdata_o
);

`ifdef PLATFORM_SIM
    sdp_sram_with_strobe #(
        .WR_ADDR_WTH    (7),
        .WR_DATA_WTH    (256),
        .RD_ADDR_WTH    (7),
        .RD_DATA_WTH    (256),
        .RD_DELAY       (1)
    ) sdp_w128x256s_r128x256d1_inst (
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
    sdp_w128x256s_r128x256d1 sdp_w128x256_r128x256d1_inst (
        .clka           (wr_clk_i),
        .ena            (1'b1),
        .wea            ({32{we_i}} & wdata_strob_i),
        .addra          (waddr_i),
        .dina           (wdata_i),
        .clkb           (rd_clk_i),
        .enb            (1'b1),
        .addrb          (raddr_i),
        .doutb          (rdata_o)
    );
`endif

`ifdef PLATFORM_ASIC
    logic[255 : 0]  bwebb;
    logic           webb;
    logic           ceba, ceba_dly1;
    logic[255 : 0]  wdata_dly1, qa;

    always_comb begin
        for(integer i=0; i<32; i=i+1) begin
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
    TSDN28HPCPA128X64M4MW sdp_w128x64_r128x64d1_inst[3:0] (
        // mode
        //.SLP            ({4{1'b0}}),
        //.SD             ({4{1'b0}}),
        //.AWT            ({4{1'b0}}),
        // debug
        .WTSEL          ({4{2'b01}}),
        .RTSEL          ({4{2'b01}}),
        //.VDD            ({4{1'b1}}),
        //.VSS            ({4{1'b0}}),
        .VG             ({4{1'b1}}),
        .VS             ({4{1'b1}}),
        // port A
        .CLKA           ({4{rd_clk_i}}),
        .AA             ({4{raddr_i}}),
        .DA             (256'h0),
        .BWEBA          (256'h0),
        .WEBA           (4'hf),
        .CEBA           ({4{ceba}}),
        .QA             (qa),
        // port B
        .CLKB           ({4{wr_clk_i}}),
        .AB             ({4{waddr_i}}),
        .DB             (wdata_i),
        .BWEBB          (bwebb),
        .WEBB           ({4{webb}}),
        .CEBB           (4'h0),
        .QB             ()
        // BIST
        //.BIST           ({4{1'b0}}),
        //.CLKM           ({4{1'b0}}),
        //.AMA            ({4{9'h0}}),
        //.DMA            ({4{64'h0}}),
        //.BWEBMA         ({4{64'h0}}),
        //.WEBMA          ({4{1'h0}}),
        //.CEBMA          ({4{1'h0}}),
        //.AMB            ({4{9'h0}}),
        //.DMB            ({4{64'h0}}),
        //.BWEBMB         ({4{64'h0}}),
        //.WEBMB          ({4{1'h0}}),
        //.CEBMB          ({4{1'h0}})
    );

`endif

endmodule : sdp_w128x256s_r128x256d1_wrap
