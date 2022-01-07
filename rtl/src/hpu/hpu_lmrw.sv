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
// FILE NAME  : hpu_lmrw.sv
// DEPARTMENT : CAG of IAIR
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_lmrw(
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   lsu_lmrw__wr_en_i,
    input   pc_t                                    lsu_lmrw__waddr_i,
    output  logic                                   lmrw_lsu__wr_suc_o,
    input   data_t                                  lsu_lmrw__wdata_i,
    input   data_strobe_t                           lsu_lmrw__wstrb_i,
    input   logic                                   lsu_lmrw__rd_en_i,
    input   data_t                                  lsu_lmrw__raddr_i,
    output  data_t                                  lmrw_lsu__rdata_o,
    output  logic                                   lmrw_lsu__rd_suc_o,
    input   logic                                   vmu_lmrw__vec_wr_en_i,
    input   logic[LM_ADDR_WTH-1 : 0]                vmu_lmrw__vec_waddr_i,
    input   mtx_t[VEC_SIZE-1 : 0]                   vmu_lmrw__vec_wdata_i,
    input   logic                                   vmu_lmrw__vec_rd_en_i,
    input   logic[LM_ADDR_WTH-1 : 0]                vmu_lmrw__vec_raddr_i,
    output  mtx_t[VEC_SIZE-1 : 0]                   lmrw_vmu__vec_rdata_o,
    input   logic                                   vmu_lmrw__mtx_rd_en_i,
    input   logic                                   vmu_lmrw__mtx_algup_en_i,
    input   logic                                   vmu_lmrw__mtx_algdn_en_i,
    input   logic[LM_ADDR_WTH-1 : 0]                vmu_lmrw__mtx_raddr_i,
    output  mtx_t[VEC_SIZE-1 : 0]                   lmrw_vmu__mtx_rdata_o,
    input   logic                                   lcarb_lmrw__mem_re_i,
    input   logic[17:0]                             lcarb_lmrw__mem_raddr_i,
    output  logic[255:0]                            lmrw_lcarb__mem_rdata_o,
    output  logic                                   lmrw_lcarb__mem_rdata_act_o,
    input   logic                                   lcarb_lmrw__mem_we_i,
    input   logic[17:0]                             lcarb_lmrw__mem_waddr_i,
    input   logic[255:0]                            lcarb_lmrw__mem_wdata_i,
    input   logic[7:0]                              lcarb_lmrw__mem_wstrb_i
);
    localparam TOT_DLY = 1;
    logic[VEC_SIZE_N-1 : 0]                 vec_windex_onehot;
    logic[VEC_SIZE_N-1 : 0]                 ndma_windex_onehot;
    logic[VEC_SIZE_N-1 : 0]                 lsu_windex_onehot;
    logic                                   vec_wr_en;
    logic                                   ndma_wr_en;
    logic                                   lsu_wr_en;
    logic[VEC_SIZE_H-1 : 0]                 ndma_wdata_strobe_h_temp;
    logic[VEC_SIZE_H-1 : 0]                 ndma_wdata_strobe_h;
    logic[VEC_SIZE_V-1 : 0]                 ndma_wdata_strobe_v;
    logic[VEC_SIZE_H-1 : 0]                 lsu_wdata_strobe_h;
    logic[VEC_SIZE_V-1 : 0]                 lsu_wdata_strobe_v;
    logic[VEC_SIZE_N-1 : 0]                 vec_rindex_onehot;
    logic[VEC_SIZE_N-1 : 0]                 mtx_rindex_onehot;
    logic[VEC_SIZE_N-1 : 0]                 ndma_rindex_onehot;
    logic[VEC_SIZE_N-1 : 0]                 lsu_rindex_onehot;
    logic                                   vec_rd_en;
    logic                                   mtx_rd_en;
    logic                                   ndma_rd_en;
    logic                                   lsu_rd_en;
    logic[VEC_SIZE_N-1 : 0]                 lsu_wr_fail;
    logic                                   lmrw_we[VEC_SIZE_N-1 : 0];
    logic[LM_OFFSET_WTH-1 : 0]              lmrw_waddr[VEC_SIZE_N-1 : 0];
    mtx_t[VEC_SIZE-1 : 0]                   lmrw_wdata[VEC_SIZE_N-1 : 0];
    logic[VEC_SIZE_H-1 : 0]                 lmrw_wdata_strobe_h[VEC_SIZE_N-1 : 0];
    logic[VEC_SIZE_V-1 : 0]                 lmrw_wdata_strobe_v[VEC_SIZE_N-1 : 0];
    logic[VEC_SIZE_N-1 : 0]                 lsu_rd_fail;
    logic                                   lmrw_re[VEC_SIZE_N-1 : 0];
    logic[LM_OFFSET_WTH-1 : 0]              lmrw_raddr[VEC_SIZE_N-1 : 0];
    logic[LM_OFFSET_WTH-1 : 0]              lmrw_addr[VEC_SIZE_N-1 : 0];
    logic[VEC_SIZE*MTX_WTH-1 : 0]           lmrw_rdata_bit[VEC_SIZE_N-1 : 0];
    logic[VEC_SIZE*MTX_WTH-1 : 0]           lmrw_wdata_bit[VEC_SIZE_N-1 : 0];
    mtx_t[VEC_SIZE-1 : 0]                   lmrw_rdata[VEC_SIZE_N-1 : 0];
    logic[LM_ADDR_WTH-1 : 0]                vec_raddr;
    logic[LM_ADDR_WTH-1 : 0]                mtx_raddr;
    logic                                   mtx_algup_en;
    logic                                   mtx_algdn_en;
    logic[17 : 0]                           ndma_raddr;
    pc_t                                    lsu_raddr;
    logic[LM_ADDR_WTH-1 : 0]                vec_raddr_r2;
    logic[LM_ADDR_WTH-1 : 0]                mtx_raddr_r2;
    logic                                   mtx_algup_en_r2;
    logic                                   mtx_algdn_en_r2;
    logic[17 : 0]                           ndma_raddr_r2;
    pc_t                                    lsu_raddr_r2;
    mtx_t[VEC_SIZE-1 : 0]                   lmrw_rdata_r2[VEC_SIZE_N-1 : 0];
    logic[MTX_WTH*VEC_SIZE-1 : 0]           ndma_rdata_r2;
    logic[MTX_WTH*VEC_SIZE-1 : 0]           lsu_rdata_r2;
    logic[TOT_DLY : 0]                      ndma_re_dlychain;
    dec_bin_to_onehot #(3, 8) vec_windex_inst (vmu_lmrw__vec_waddr_i[LM_OFFSET_WTH +: LM_IND_WTH], vec_windex_onehot);
    dec_bin_to_onehot #(3, 8) ndma_windex_inst (lcarb_lmrw__mem_waddr_i[6+9 +: LM_IND_WTH], ndma_windex_onehot);
    dec_bin_to_onehot #(3, 8) lsu_windex_inst (lsu_lmrw__waddr_i[6+9 +: LM_IND_WTH], lsu_windex_onehot);
    assign vec_wr_en = vmu_lmrw__vec_wr_en_i && (vmu_lmrw__vec_waddr_i[LM_ADDR_WTH-1] == 1'b0);
    assign ndma_wr_en = lcarb_lmrw__mem_we_i;
    assign lsu_wr_en = lsu_lmrw__wr_en_i && (lsu_lmrw__waddr_i[18] == 1'b0);
    dec_bin_to_onehot #(3, 8) ndma_wdata_strobe_h_inst(lcarb_lmrw__mem_waddr_i[5:3], ndma_wdata_strobe_h_temp);
    assign ndma_wdata_strobe_h = (lcarb_lmrw__mem_wstrb_i!=8'hff) ? ndma_wdata_strobe_h_temp
                               : (lcarb_lmrw__mem_waddr_i[5]) ? 8'hf0 : 8'h0f;
    assign ndma_wdata_strobe_v = (lcarb_lmrw__mem_wstrb_i==8'hff) ? 8'hff
                               : lcarb_lmrw__mem_waddr_i[2] ? 8'hf0 : 8'h0f;
    dec_bin_to_onehot #(3, 8) lsu_wdata_strobe_h_inst(lsu_lmrw__waddr_i[5:3], lsu_wdata_strobe_h);
    assign lsu_wdata_strobe_v = lsu_lmrw__waddr_i[2] ? {lsu_lmrw__wstrb_i, 4'h0} : {4'h0, lsu_lmrw__wstrb_i};
    dec_bin_to_onehot #(3, 8) vec_rindex_inst (vmu_lmrw__vec_raddr_i[LM_OFFSET_WTH +: LM_IND_WTH], vec_rindex_onehot);
    dec_bin_to_onehot #(3, 8) mtx_rindex_inst (vmu_lmrw__mtx_raddr_i[LM_OFFSET_WTH +: LM_IND_WTH], mtx_rindex_onehot);
    dec_bin_to_onehot #(3, 8) ndma_rindex_inst (lcarb_lmrw__mem_raddr_i[6+9 +: LM_IND_WTH], ndma_rindex_onehot);
    dec_bin_to_onehot #(3, 8) lsu_rindex_inst (lsu_lmrw__raddr_i[6+9 +: LM_IND_WTH], lsu_rindex_onehot);
    assign vec_rd_en = vmu_lmrw__vec_rd_en_i & (vmu_lmrw__vec_raddr_i[LM_ADDR_WTH-1] == 1'b0);
    assign mtx_rd_en = vmu_lmrw__mtx_rd_en_i & (vmu_lmrw__mtx_raddr_i[LM_ADDR_WTH-1] == 1'b0);
    assign ndma_rd_en = lcarb_lmrw__mem_re_i;
    assign lsu_rd_en = lsu_lmrw__rd_en_i && (lsu_lmrw__raddr_i[18] == 1'b0);
    for(genvar gi = 0; gi<VEC_SIZE_N; gi=gi+1) begin : lmrw_row
        assign lsu_wr_fail[gi] = ((vec_wr_en & vec_windex_onehot[gi])
            | (ndma_wr_en & ndma_windex_onehot[gi]))
            & (lsu_wr_en & lsu_windex_onehot[gi]);
        assign lmrw_we[gi] = (vec_wr_en & vec_windex_onehot[gi])
            | (ndma_wr_en & ndma_windex_onehot[gi])
            | (lsu_wr_en & lsu_windex_onehot[gi]);
        assign lmrw_waddr[gi] = (vec_wr_en & vec_windex_onehot[gi]) ? vmu_lmrw__vec_waddr_i[LM_OFFSET_WTH-1 : 0]
            : (ndma_wr_en & ndma_windex_onehot[gi]) ? lcarb_lmrw__mem_waddr_i[14 : 6]
            : lsu_lmrw__waddr_i[14 : 6];
        assign lmrw_wdata[gi] = (vec_wr_en & vec_windex_onehot[gi]) ? vmu_lmrw__vec_wdata_i
            : (ndma_wr_en & ndma_windex_onehot[gi]) ? {2{lcarb_lmrw__mem_wdata_i}}
            : {16{lsu_lmrw__wdata_i}};
        assign lmrw_wdata_strobe_h[gi] = (vec_wr_en & vec_windex_onehot[gi]) ? 8'hff
            : (ndma_wr_en & ndma_windex_onehot[gi]) ? ndma_wdata_strobe_h
            : lsu_wdata_strobe_h;
        assign lmrw_wdata_strobe_v[gi] = (vec_wr_en & vec_windex_onehot[gi]) ? 8'hff
            : (ndma_wr_en & ndma_windex_onehot[gi]) ? ndma_wdata_strobe_v
            : lsu_wdata_strobe_v;
        assign lsu_rd_fail[gi] = ((vec_rd_en & vec_rindex_onehot[gi])
            | (mtx_rd_en & mtx_rindex_onehot[gi])
            | (ndma_rd_en & ndma_rindex_onehot[gi])
            | (vec_wr_en & vec_windex_onehot[gi])
            | (ndma_wr_en & ndma_windex_onehot[gi])
            | (lsu_wr_en & lsu_windex_onehot[gi]))
            & (lsu_rd_en & lsu_rindex_onehot[gi]);
        assign lmrw_re[gi] = (vec_rd_en & vec_rindex_onehot[gi])
            | (mtx_rd_en & mtx_rindex_onehot[gi])
            | (ndma_rd_en & ndma_rindex_onehot[gi])
            | (lsu_rd_en & lsu_rindex_onehot[gi]);
        assign lmrw_raddr[gi] = (vec_rd_en & vec_rindex_onehot[gi]) ? vmu_lmrw__vec_raddr_i[LM_OFFSET_WTH-1 : 0]
            : (mtx_rd_en & mtx_rindex_onehot[gi]) ? vmu_lmrw__mtx_raddr_i[LM_OFFSET_WTH-1 : 0]
            : (ndma_rd_en & ndma_rindex_onehot[gi]) ? lcarb_lmrw__mem_raddr_i[14 : 6]
            : lsu_lmrw__raddr_i[14 : 6];
        assign lmrw_addr[gi] = lmrw_we[gi] ? lmrw_waddr[gi] : lmrw_raddr[gi];
        sp_512x64sd1_wrap lmrw_inst[VEC_SIZE_H-1 : 0] (
            .clk_i                          ({VEC_SIZE_H{clk_i}}),
            .cs_i                           ({VEC_SIZE_H{lmrw_we[gi] | lmrw_re[gi]}}),
            .we_i                           ({VEC_SIZE_H{lmrw_we[gi]}} & lmrw_wdata_strobe_h[gi]),
            .addr_i                         ({VEC_SIZE_H{lmrw_addr[gi]}}),
            .wdata_i                        (lmrw_wdata_bit[gi]),
            .wdata_strob_i                  ({VEC_SIZE_H{lmrw_wdata_strobe_v[gi]}}),
            .rdata_o                        (lmrw_rdata_bit[gi])
        );
        always_comb begin
            for(integer j=0; j<VEC_SIZE; j=j+1) begin
                lmrw_wdata_bit[gi][j*MTX_WTH +: MTX_WTH] = lmrw_wdata[gi][j];
                lmrw_rdata[gi][j] = lmrw_rdata_bit[gi][j*MTX_WTH +: MTX_WTH];
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            lmrw_lsu__wr_suc_o <= 1'b0;
            vec_raddr <= LM_ADDR_WTH'(0);
            mtx_raddr <= LM_ADDR_WTH'(0);
            mtx_algup_en <= 1'b0;
            mtx_algdn_en <= 1'b0;
            ndma_raddr <= 18'h0;
            lsu_raddr <= pc_t'(0);
            lmrw_lsu__rd_suc_o <= 1'b0;
        end else begin
            lmrw_lsu__wr_suc_o <= !(|lsu_wr_fail);
            vec_raddr <= vmu_lmrw__vec_raddr_i;
            mtx_raddr <= vmu_lmrw__mtx_raddr_i;
            mtx_algup_en <= vmu_lmrw__mtx_algup_en_i;
            mtx_algdn_en <= vmu_lmrw__mtx_algdn_en_i;
            ndma_raddr <= lcarb_lmrw__mem_raddr_i;
            lsu_raddr <= lsu_lmrw__raddr_i;
            lmrw_lsu__rd_suc_o <= !(|lsu_rd_fail);
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            vec_raddr_r2 <= LM_ADDR_WTH'(0);
            mtx_raddr_r2 <= LM_ADDR_WTH'(0);
            mtx_algup_en_r2 <= 1'b0;
            mtx_algdn_en_r2 <= 1'b0;
            ndma_raddr_r2 <= 18'h0;
            lsu_raddr_r2 <= pc_t'(0);
            for(integer i=0; i<VEC_SIZE_N; i=i+1) begin
                lmrw_rdata_r2[i] <= {VEC_SIZE{mtx_t'(0)}};
            end
        end else begin
            vec_raddr_r2 <= vec_raddr;
            mtx_raddr_r2 <= mtx_raddr;
            mtx_algup_en_r2 <= mtx_algup_en;
            mtx_algdn_en_r2 <= mtx_algdn_en;
            ndma_raddr_r2 <= ndma_raddr;
            lsu_raddr_r2 <= lsu_raddr;
            for(integer i=0; i<VEC_SIZE_N; i=i+1) begin
                lmrw_rdata_r2[i] <= lmrw_rdata[i];
            end
        end
    end
    always_comb begin
        for(integer i=0; i<VEC_SIZE; i=i+1) begin
            ndma_rdata_r2[i*MTX_WTH +: MTX_WTH] = lmrw_rdata_r2[ndma_raddr_r2[17:15]][i];
            lsu_rdata_r2[i*MTX_WTH +: MTX_WTH] = lmrw_rdata_r2[lsu_raddr_r2[17:15]][i];
        end
    end
    assign lmrw_vmu__vec_rdata_o = lmrw_rdata_r2[vec_raddr_r2[LM_ADDR_WTH-2 : LM_OFFSET_WTH]];
    assign lmrw_vmu__mtx_rdata_o =
    mtx_algdn_en_r2 ?
        {lmrw_rdata_r2[mtx_raddr_r2[LM_ADDR_WTH-2 : LM_OFFSET_WTH]][0 +: (VEC_SIZE_H-1)*MTX_WTH],
        {(VEC_SIZE_V*MTX_WTH){1'b0}}}
    : mtx_algup_en_r2 ?
        {{(VEC_SIZE_V*MTX_WTH){1'b0}},
        lmrw_rdata_r2[mtx_raddr_r2[LM_ADDR_WTH-2 : LM_OFFSET_WTH]][MTX_WTH +: (VEC_SIZE_H-1)*MTX_WTH]}
    : lmrw_rdata_r2[mtx_raddr_r2[LM_ADDR_WTH-2 : LM_OFFSET_WTH]];
    assign lmrw_lcarb__mem_rdata_o = (ndma_raddr_r2[5]) ? ndma_rdata_r2[511 : 256] : ndma_rdata_r2[255 : 0];
    assign lmrw_lsu__rdata_o = lsu_rdata_r2[lsu_raddr_r2[5:2]*DATA_WTH +: DATA_WTH];
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ndma_re_dlychain <= {(TOT_DLY+1){1'b0}};
        end else begin
            ndma_re_dlychain <= {ndma_re_dlychain[TOT_DLY-1 : 0], lcarb_lmrw__mem_re_i};
        end
    end
    assign lmrw_lcarb__mem_rdata_act_o = ndma_re_dlychain[TOT_DLY];
endmodule : hpu_lmrw
