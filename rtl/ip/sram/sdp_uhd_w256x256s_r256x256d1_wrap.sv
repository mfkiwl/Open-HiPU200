// ---------------------------------------------------------------------------------------------------------------------
// Copyright (c) 1986 - 2020, CAG team, Institute of AI and Robotics, Xi'an Jiaotong University
// All Rights Reserved. You may not use this file in commerce unless acquired the permmission of CAG team.
// ---------------------------------------------------------------------------------------------------------------------
// FILE NAME  : sdp_uhd_w256x256s_r256x256d1_wrap.sv
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns/1ps

// `define PLATFORM_ASIC
`include "glb_def.svh"

module sdp_uhd_w256x256s_r256x256d1_wrap (
    input           clk_i,
    input           we_i,
    input [7:0]     waddr_i,
    input [255:0]   wdata_i,
    input [31:0]    wdata_strob_i,
    input           re_i,
    input [7:0]     raddr_i,
    output[255:0]   rdata_o
);

`ifdef PLATFORM_SIM
    sdp_sram_with_strobe #(
        .WR_ADDR_WTH    (8),
        .WR_DATA_WTH    (256),
        .RD_ADDR_WTH    (8),
        .RD_DATA_WTH    (256),
        .RD_DELAY       (1)
    ) sdp_w256x256_r256x256d1_inst (
        .wr_clk_i       (clk_i),
        .we_i           (we_i),
        .waddr_i        (waddr_i),
        .wdata_i        (wdata_i),
        .wdata_strob_i  (wdata_strob_i),
        .rd_clk_i       (clk_i),
        .re_i           (re_i),
        .raddr_i        (raddr_i),
        .rdata_o        (rdata_o)
    );
`endif

`ifdef PLATFORM_XILINX
    logic[255 : 0]  bwebb;
    logic           webb;
    logic[255 : 0]  wmask_dly1;
    logic[255 : 0]  wdata_dly1, qa;

    always_comb begin
        for(integer i=0; i<32; i=i+1) begin
            bwebb[i*8 +: 8] = ~{8{wdata_strob_i[i]}};
        end
    end

    assign webb = ~we_i;

    for(genvar gi = 0; gi < 256; gi=gi+1) begin
        always_ff @(posedge clk_i) begin
            wmask_dly1[gi] <= (waddr_i == raddr_i) && we_i && !bwebb[gi];
            wdata_dly1[gi] <= wdata_i[gi];
        end
        assign rdata_o[gi] = wmask_dly1[gi]? wdata_dly1[gi] : qa[gi];
    end

    sdp_w256x256_r256x256d1 sdp_w256x256_r256x256d1_inst (
        .clka           (clk_i),
        .ena            (1'b1),
        .wea            ({32{we_i}} & wdata_strob_i),
        .addra          (waddr_i),
        .dina           (wdata_i),
        .clkb           (clk_i),
        .enb            (1'b1),
        .addrb          (raddr_i),
        .doutb          (qa)
    );
`endif

`ifdef PLATFORM_ASIC
    logic[255 : 0]  bwebb;
    logic           webb;
    logic[255 : 0]  wmask_dly1;
    logic[255 : 0]  wdata_dly1, qa;

    always_comb begin
        for(integer i=0; i<32; i=i+1) begin
            bwebb[i*8 +: 8] = ~{8{wdata_strob_i[i]}};
        end
    end

    assign webb = ~we_i;

    for(genvar gi = 0; gi < 256; gi=gi+1) begin
        always_ff @(posedge clk_i) begin
            wmask_dly1[gi] <= (waddr_i == raddr_i) && we_i && !bwebb[gi];
            wdata_dly1[gi] <= wdata_i[gi];
        end
        assign rdata_o[gi] = wmask_dly1[gi]? wdata_dly1[gi] : qa[gi];
    end

    TSDN28HPCPUHDB256X64M4MW sdp_w256x64_r256x64d1_inst[3:0] (
        // mode
        //.AWT            ({4{1'b0}}),
        //.VDD            ({4{1'b1}}),
        //.VSS            ({4{1'b0}}),
        .CLK            ({4{clk_i}}),
        // debug
        .RTSEL          ({4{2'h0}}),
        .WTSEL          ({4{2'h0}}),
        .PTSEL          ({4{2'h0}}),
        //.VDD            ({4{1'b1}}),
        //.VSS            ({4{1'b0}}),
        // port A
        .AA             ({4{raddr_i}}),
        .DA             (256'h0),
        .BWEBA          (256'h0),
        .WEBA           ({4{1'b1}}),
        .CEBA           ({4{1'b0}}),
        .QA             (qa),
        // port B
        .AB             ({4{waddr_i}}),
        .DB             (wdata_i),
        .BWEBB          (bwebb),
        .WEBB           ({4{webb}}),
        .CEBB           ({4{1'b0}}),
        .QB             ()
    );
`endif

endmodule : sdp_uhd_w256x256s_r256x256d1_wrap
