// ---------------------------------------------------------------------------------------------------------------------
// Copyright (c) 1986 - 2020, CAG team, Institute of AI and Robotics, Xi'an Jiaotong University. Proprietary and
// Confidential All Rights Reserved.
// ---------------------------------------------------------------------------------------------------------------------
// NOTICE: All information contained herein is, and remains the property of CAG team, Institute of AI and Robotics,
// Xi'an Jiaotong University. The intellectual and technical concepts contained herein are proprietary to CAG team, and
// may be covered by P.R.C. and Foreign Patents, patents in process, and are protected by trade secret or copyright law.
//
// This work may not be copied, modified, re-published, uploaded, executed, or distributed in any way, in any time, in
// any medium, whether in whole or in part, without prior written permission from CAG team, Institute of AI and
// Robotics, Xi'an Jiaotong University.
//
// The copyright notice above does not evidence any actual or intended publication or disclosure of this source code,
// which includes information that is confidential and/or proprietary, and is a trade secret, of CAG team.
// ---------------------------------------------------------------------------------------------------------------------
// FILE NAME  : hpu_lmro.sv
// DEPARTMENT : CAG of IAIR
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_lmro(
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   vmu_lmro__mtx_rd_en_i,
    input   logic                                   vmu_lmro__mtx_vm_mode_i,
    input   logic[LM_ADDR_WTH-1 : 0]                vmu_lmro__mtx_raddr_i,
    output  mtx_t[VEC_SIZE-1 : 0]                   lmro_vmu__mtx_rdata_o,
    output  mtx_t[VEC_SIZE*VEC_SIZE_V-1 : 0]        lmro_vmu__mtx_vm_rdata_o,
    input   logic                                   lcarb_lmro__mem_re_i,
    input   logic[17:0]                             lcarb_lmro__mem_raddr_i,
    output  logic                                   lmro_lcarb__mem_rdata_act_o,
    output  logic[255:0]                            lmro_lcarb__mem_rdata_o,
    input   logic                                   lcarb_lmro__mem_we_i,
    input   logic[17:0]                             lcarb_lmro__mem_waddr_i,
    input   logic[255:0]                            lcarb_lmro__mem_wdata_i,
    input   logic[7:0]                              lcarb_lmro__mem_wstrb_i
);
    localparam TOT_DLY = 1;
    logic[VEC_SIZE_N-1 : 0]                 ndma_windex_onehot;
    logic                                   ndma_wr_en;
    logic[VEC_SIZE_H-1 : 0]                 ndma_wdata_strobe_h_temp;
    logic[VEC_SIZE_H-1 : 0]                 ndma_wdata_strobe_h;
    logic[VEC_SIZE_V-1 : 0]                 ndma_wdata_strobe_v;
    logic[VEC_SIZE_N-1 : 0]                 mtx_rindex_onehot;
    logic[VEC_SIZE_N-1 : 0]                 ndma_rindex_onehot;
    logic                                   mtx_rd_en;
    logic                                   ndma_rd_en;
    logic                                   lmro_we[VEC_SIZE_N-1 : 0];
    logic[LM_OFFSET_WTH-1 : 0]              lmro_waddr[VEC_SIZE_N-1 : 0];
    mtx_t[VEC_SIZE-1 : 0]                   lmro_wdata[VEC_SIZE_N-1 : 0];
    logic                                   lmro_re[VEC_SIZE_N-1 : 0];
    logic[LM_OFFSET_WTH-1 : 0]              lmro_raddr[VEC_SIZE_N-1 : 0];
    mtx_t[VEC_SIZE-1 : 0]                   lmro_rdata[VEC_SIZE_N-1 : 0];
    logic[MTX_WTH*VEC_SIZE-1 : 0]           mem_rdata;
    logic[LM_OFFSET_WTH-1 : 0]              lmro_addr[VEC_SIZE_N-1 : 0];
    logic[LM_ADDR_WTH-1 : 0]                mtx_raddr;
    logic[17 : 0]                           ndma_raddr;
    logic[TOT_DLY : 0]                      ndma_re_dlychain;
    dec_bin_to_onehot #(3, 8) ndma_windex_inst (lcarb_lmro__mem_waddr_i[8 : 6], ndma_windex_onehot);
    assign ndma_wr_en = lcarb_lmro__mem_we_i;
    dec_bin_to_onehot #(3, 8) ndma_wdata_strobe_h_inst(lcarb_lmro__mem_waddr_i[5:3], ndma_wdata_strobe_h_temp);
    assign ndma_wdata_strobe_h = (lcarb_lmro__mem_wstrb_i != 8'hff) ? ndma_wdata_strobe_h_temp
                               : (lcarb_lmro__mem_waddr_i[5]) ? 8'hf0 : 8'h0f;
    assign ndma_wdata_strobe_v = (lcarb_lmro__mem_wstrb_i == 8'hff) ? 8'hff
                               : (lcarb_lmro__mem_waddr_i[2]) ? 8'hf0 : 8'h0f;
    dec_bin_to_onehot #(3, 8) mtx_rindex_inst (vmu_lmro__mtx_raddr_i[LM_IND_WTH-1 : 0], mtx_rindex_onehot);
    dec_bin_to_onehot #(3, 8) ndma_rindex_inst (lcarb_lmro__mem_raddr_i[8 : 6], ndma_rindex_onehot);
    assign mtx_rd_en = vmu_lmro__mtx_rd_en_i & vmu_lmro__mtx_raddr_i[LM_ADDR_WTH-1];
    assign ndma_rd_en = lcarb_lmro__mem_re_i;
    for(genvar gi = 0; gi<VEC_SIZE_N; gi=gi+1) begin : lmro_row
        assign lmro_we[gi] = (ndma_wr_en & ndma_windex_onehot[gi]);
        assign lmro_waddr[gi] = lcarb_lmro__mem_waddr_i[17 : 9];
        assign lmro_wdata[gi] = {2{lcarb_lmro__mem_wdata_i}};
        assign lmro_re[gi] = (mtx_rd_en & (mtx_rindex_onehot[gi] | vmu_lmro__mtx_vm_mode_i))
                           | (ndma_rd_en & ndma_rindex_onehot[gi]);
        assign lmro_raddr[gi] =(mtx_rd_en & (mtx_rindex_onehot[gi] | vmu_lmro__mtx_vm_mode_i)) ?
            vmu_lmro__mtx_raddr_i[LM_IND_WTH +: LM_OFFSET_WTH] : lcarb_lmro__mem_raddr_i[17 : 9];
        assign lmro_addr[gi] = lmro_we[gi] ? lmro_waddr[gi] : lmro_raddr[gi];
        sp_512x64sd1_wrap lmro_inst[VEC_SIZE_H-1 : 0] (
            .clk_i                          ({VEC_SIZE_H{clk_i}}),
            .cs_i                           ({VEC_SIZE_H{lmro_we[gi] | lmro_re[gi]}}),
            .we_i                           ({VEC_SIZE_H{lmro_we[gi]}} & ndma_wdata_strobe_h),
            .addr_i                         ({VEC_SIZE_H{lmro_addr[gi]}}),
            .wdata_i                        (lmro_wdata[gi]),
            .wdata_strob_i                  ({VEC_SIZE_H{ndma_wdata_strobe_v}}),
            .rdata_o                        (lmro_rdata[gi])
        );
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            mtx_raddr <= 'h0;
            ndma_raddr <= 'h0;
        end else begin
            mtx_raddr <= vmu_lmro__mtx_raddr_i;
            ndma_raddr <= lcarb_lmro__mem_raddr_i;
        end
    end
    always_comb begin
        for(integer i=0; i<VEC_SIZE; i=i+1) begin
            mem_rdata[i*MTX_WTH +: MTX_WTH] = lmro_rdata[ndma_raddr[8:6]][i];
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            lmro_vmu__mtx_rdata_o <= 'h0;
            lmro_lcarb__mem_rdata_o <= 'h0;
            for(integer i=0; i<VEC_SIZE_V; i=i+1) begin
                lmro_vmu__mtx_vm_rdata_o[i*VEC_SIZE +: VEC_SIZE] <= 'h0;
            end
        end else begin
            lmro_vmu__mtx_rdata_o <= lmro_rdata[mtx_raddr[LM_IND_WTH-1 : 0]];
            lmro_lcarb__mem_rdata_o <= (ndma_raddr[5]) ? mem_rdata[511 : 256] : mem_rdata[255 : 0];
            for(integer i=0; i<VEC_SIZE_V; i=i+1) begin
                lmro_vmu__mtx_vm_rdata_o[i*VEC_SIZE +: VEC_SIZE] <= lmro_rdata[i];
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ndma_re_dlychain <= {(TOT_DLY+1){1'b0}};
        end else begin
            ndma_re_dlychain <= {ndma_re_dlychain[TOT_DLY-1 : 0], lcarb_lmro__mem_re_i};
        end
    end
    assign lmro_lcarb__mem_rdata_act_o = ndma_re_dlychain[TOT_DLY];
endmodule : hpu_lmro
