// ---------------------------------------------------------------------------------------------------------------------
// Copyright (c) 1986 - 2020, CAG team, Institute of AI and Robotics, Xi'an Jiaotong University
// All Rights Reserved. You may not use this file in commerce unless acquired the permmission of CAG team.
// ---------------------------------------------------------------------------------------------------------------------
// FILE NAME  : sdp_uhd_w64x20b_r64x20d1_wrap.sv
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns/1ps

// `define PLATFORM_ASIC
`include "glb_def.svh"

module sdp_uhd_w64x20b_r64x20d1_wrap (
    input           clk_i,
    input           we_i,
    input [5:0]     waddr_i,
    input [19:0]    wdata_i,
    input [19:0]    wdata_bwe_i,
    input           re_i,
    input [5:0]     raddr_i,
    output[19:0]    rdata_o
);

`ifdef PLATFORM_SIM
    sdp_sram_with_bwe #(
        .WR_ADDR_WTH    (6),
        .WR_DATA_WTH    (20),
        .RD_ADDR_WTH    (6),
        .RD_DATA_WTH    (20),
        .RD_DELAY       (1)
    ) sdp_w64x20_r64x32d1_inst (
        .wr_clk_i       (clk_i),
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
    logic[19 : 0]   bwebb;
    logic           webb;
    logic[19 : 0]   wmask_dly1;
    logic[19 : 0]   wdata_dly1, qa;

    assign bwebb = ~wdata_bwe_i;

    assign webb = ~we_i;

    for(genvar gi = 0; gi < 20; gi=gi+1) begin
        always_ff @(posedge clk_i) begin
            wmask_dly1[gi] <= (waddr_i == raddr_i) && we_i && !bwebb[gi];
            wdata_dly1[gi] <= wdata_i[gi];
        end
        assign rdata_o[gi] = wmask_dly1[gi]? wdata_dly1[gi] : qa[gi];
    end

    sdp_w64x20_r64x20d1 sdp_w64x20_r64x20d1_inst (
        .clka           (clk_i),
        .ena            (1'b1),
        .wea            ({3{we_i}}),
        .addra          (waddr_i),
        .dina           (wdata_i),
        .clkb           (rd_clk_i),
        .enb            (1'b1),
        .addrb          (raddr_i),
        .doutb          (qa)
    );
`endif

`ifdef PLATFORM_ASIC
    logic[19 : 0]   bwebb;
    logic           webb;
    logic[19 : 0]   wmask_dly1;
    logic[19 : 0]   wdata_dly1, qa;

    assign bwebb = ~wdata_bwe_i;

    assign webb = ~we_i;

    for(genvar gi = 0; gi < 20; gi=gi+1) begin
        always_ff @(posedge clk_i) begin
            wmask_dly1[gi] <= (waddr_i == raddr_i) && we_i && !bwebb[gi];
            wdata_dly1[gi] <= wdata_i[gi];
        end
        assign rdata_o[gi] = wmask_dly1[gi]? wdata_dly1[gi] : qa[gi];
    end

    TSDN28HPCPUHDB64X20M4MW sdp_w64x20_r64x20d1_inst (
        // mode
        // .AWT            (1'b0),
        //.VDD            (1'b1),
        //.VSS            (1'b0),
        .CLK            (clk_i),
        // debug
        .RTSEL          (2'h0),
        .WTSEL          (2'h0),
        .PTSEL          (2'h0),
        //.VDD            (1'b1),
        //.VSS            (1'b0),
        // port A
        .AA             (raddr_i),
        .DA             (20'h0),
        .BWEBA          (20'h0),
        .WEBA           (1'b1),
        .CEBA           (1'b0),
        .QA             (qa),
        // port B
        .AB             (waddr_i),
        .DB             (wdata_i),
        .BWEBB          (bwebb),
        .WEBB           (webb),
        .CEBB           (1'b0),
        .QB             ()
    );
`endif

endmodule : sdp_uhd_w64x20b_r64x20d1_wrap