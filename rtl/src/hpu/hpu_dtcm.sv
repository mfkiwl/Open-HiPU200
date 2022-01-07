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
// FILE NAME  : hpu_dtcm.sv
// DEPARTMENT : CAG of IAIR
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
import dm::*;
module hpu_dtcm(
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   lsu_dtcm__wr_en_i,
    input   logic                                   lsu_dtcm__wr_rls_lock_i,
    input   pc_t                                    lsu_dtcm__waddr_i,
    output  logic                                   dtcm_lsu__wr_suc_o,
    input   data_t                                  lsu_dtcm__wdata_i,
    input   data_strobe_t                           lsu_dtcm__wstrb_i,
    input   logic                                   lsu_dtcm__rd_en_i,
    input   logic                                   lsu_dtcm__rd_acq_lock_i,
    input   pc_t                                    lsu_dtcm__raddr_i,
    output  logic                                   dtcm_lsu__rd_suc_o,
    output  data_t                                  dtcm_lsu__rdata_o,
    input   logic                                   lcarb_dtcm__mem_re_i,
    input   logic[13:0]                             lcarb_dtcm__mem_raddr_i,
    output  logic                                   dtcm_lcarb__mem_rdata_act_o,
    output  logic[255:0]                            dtcm_lcarb__mem_rdata_o,
    input   logic                                   lcarb_dtcm__mem_we_i,
    input   logic[13:0]                             lcarb_dtcm__mem_waddr_i,
    input   logic[255:0]                            lcarb_dtcm__mem_wdata_i,
    input   logic[7:0]                              lcarb_dtcm__mem_wstrb_i,
    output  logic                                   dtcm_lcarb__mem_atom_ready_o,
    input   logic                                   dm_dtcm__sba_req_i,
    input   pc_t                                    dm_dtcm__sba_addr_i,
    input   logic                                   dm_dtcm__sba_we_i,
    input   data_t                                  dm_dtcm__sba_wdata_i,
    input   data_strobe_t                           dm_dtcm__sba_be_i,
    output  logic                                   dtcm_dm__sba_gnt_o,
    output  data_t                                  dtcm_dm__sba_rdata_o,
    output  logic                                   dtcm_dm__sba_rdata_act_o,
    output  logic                                   hpu_sys__sig_req_o,
    input   logic                                   sys_hpu__sig_rsp_i,
    output  logic[255:0]                            dtcm_lcarb__node_map_o,
    output  logic[255:0]                            dtcm_lcarb__mem_map_o,
    input   pc_t                                    safemd_arc_pc_i,
    output  logic                                   safemd_ndma_single_cmd_o,
    output  logic                                   safemd_rcov_disable_o,
    output  logic                                   safemd_safe_fl_o
);
    logic                                   bus_lock;
    logic[31 : 0]                           real_ndma_wstrb;
    logic[31 : 0]                           real_dm_wstrb;
    logic[31 : 0]                           real_lsu_wstrb;
    logic[0 : 0]                            dtcm_we;
    logic[8 : 0]                            dtcm_waddr;
    logic[255 : 0]                          dtcm_wdata;
    logic[31 : 0]                           dtcm_wstrb;
    logic                                   dtcm_re;
    logic[8 : 0]                            dtcm_raddr;
    logic[255 : 0]                          dtcm_rdata;
    logic[1 : 0]                            sig_req_dlychain;
    logic[13 : 0]                           lsu_raddr;
    logic[13 : 0]                           ndma_raddr;
    logic[13 : 0]                           dm_raddr;
    logic                                   lcarb_rd_suc;
    logic                                   dm_acc_en;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            bus_lock <= 1'b0;
        end else begin
            if(lsu_dtcm__rd_acq_lock_i && lsu_dtcm__rd_en_i) begin
                bus_lock <= 1'b1;
            end
            if(lsu_dtcm__wr_rls_lock_i && lsu_dtcm__wr_en_i) begin
                bus_lock <= 1'b0;
            end
        end
    end
    always_comb begin
        for(integer i=0; i<8; i=i+1) begin
            real_ndma_wstrb[i*4 +: 4] = {4{lcarb_dtcm__mem_wstrb_i[i]}};
            real_lsu_wstrb[i*4 +: 4] = (lsu_dtcm__waddr_i[4:2] == $unsigned(i)) ? lsu_dtcm__wstrb_i : 4'h0;
            real_dm_wstrb[i*4 +: 4] = (dm_dtcm__sba_addr_i[4:2] == $unsigned(i)) ? dm_dtcm__sba_be_i : 4'h0;
        end
    end
    assign dtcm_we = lcarb_dtcm__mem_we_i | lsu_dtcm__wr_en_i | (dm_dtcm__sba_req_i & dm_dtcm__sba_we_i);
    assign dtcm_waddr = lcarb_dtcm__mem_we_i ? lcarb_dtcm__mem_waddr_i[13 : 5]
                      : lsu_dtcm__wr_en_i ? lsu_dtcm__waddr_i[13 : 5]
                      : dm_dtcm__sba_addr_i[13 : 5];
    assign dtcm_wdata = lcarb_dtcm__mem_we_i ? lcarb_dtcm__mem_wdata_i
                      : lsu_dtcm__wr_en_i ? {8{lsu_dtcm__wdata_i}}
                      : {8{dm_dtcm__sba_wdata_i}};
    assign dtcm_wstrb = lcarb_dtcm__mem_we_i ? real_ndma_wstrb
                      : lsu_dtcm__wr_en_i ? real_lsu_wstrb
                      : real_dm_wstrb;
    assign dtcm_re = lcarb_dtcm__mem_re_i | lsu_dtcm__rd_en_i | (dm_dtcm__sba_req_i & ~dm_dtcm__sba_we_i);
    assign dtcm_raddr = lcarb_dtcm__mem_re_i ? lcarb_dtcm__mem_raddr_i[13 : 5]
                      : lsu_dtcm__rd_en_i ? lsu_dtcm__raddr_i[13 : 5]
                      : dm_dtcm__sba_addr_i[13 : 5];
    logic[255 : 0] amo_mem[1 : 0];
    logic[255 : 0] nmap_mem;
    logic[255 : 0] mmap_mem;
    logic          sys_sig;
    logic[7 : 0]   safe_mode;
    logic[8 : 0]   raddr_d;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<2; i=i+1) begin
                amo_mem[i] <= 256'h0;
            end
            for(integer i=0; i<32; i=i+1) begin
                nmap_mem[i*8 +: 8] <= 8'h0;
                mmap_mem[i*8 +: 8] <= 8'h0;
            end
            sys_sig <= 1'b0;
            safe_mode <= 8'h0;
            raddr_d <= 9'h0;
        end else begin
            if(dtcm_we) begin
                for(integer i=0; i<32; i=i+1) begin
                    if(dtcm_wstrb[i]) begin
                        if(dtcm_waddr >= AMO_ADDR_S[13:5] && dtcm_waddr <= AMO_ADDR_E[13:5]) begin
                            amo_mem[dtcm_waddr[0]][i*8 +: 8] <= dtcm_wdata[i*8 +: 8];
                        end
                        if(dtcm_waddr == NMAP_ADDR[13:5]) begin
                            nmap_mem[i*8 +: 8] <= dtcm_wdata[i*8 +: 8];
                        end
                        if(dtcm_waddr == MMAP_ADDR[13:5]) begin
                            mmap_mem[i*8 +: 8] <= dtcm_wdata[i*8 +: 8];
                        end
                    end
                end
                if((dtcm_waddr == SSIG_ADDR[13:5]) && dtcm_wstrb[0]) begin
                    sys_sig <= dtcm_wdata[0];
                end else if(sig_req_dlychain[1]) begin
                    sys_sig <= 1'b0;
                end
                if((dtcm_waddr == SSIG_ADDR[13:5]) && dtcm_wstrb[0]) begin
                    safe_mode <= dtcm_wdata[7:0];
                end
            end
            raddr_d <= dtcm_raddr;
        end
    end
    assign dtcm_rdata = (raddr_d >= AMO_ADDR_S[13:5] && raddr_d <= AMO_ADDR_E[13:5]) ? amo_mem[raddr_d[0]]
                      : (raddr_d == NMAP_ADDR[13:5]) ? nmap_mem
                      : (raddr_d == MMAP_ADDR[13:5]) ? mmap_mem
                      : (raddr_d == APC_ADDR[13:5]) ? {224'h0, safemd_arc_pc_i}
                      : (raddr_d == SFMD_ADDR[13:5]) ? {248'h0, safe_mode}
                      : {255'h0, sys_sig};
    assign hpu_sys__sig_req_o = sys_sig;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            sig_req_dlychain <= 2'h0;
        end else begin
            sig_req_dlychain <= {sig_req_dlychain[0], sys_hpu__sig_rsp_i};
        end
    end
    assign safemd_ndma_single_cmd_o = safe_mode[0];
    assign safemd_rcov_disable_o = safe_mode[1];
    assign safemd_safe_fl_o = safe_mode[2];
    assign dtcm_lcarb__node_map_o = nmap_mem;
    assign dtcm_lcarb__mem_map_o = mmap_mem;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            lsu_raddr <= 14'h0;
            dtcm_lsu__rdata_o <= data_t'(0);
            ndma_raddr <= 14'h0;
            dtcm_lcarb__mem_rdata_o <= 256'h0;
            dm_raddr <= 14'h0;
            dtcm_dm__sba_rdata_o <= data_t'(0);
        end else begin
            lsu_raddr <= lsu_dtcm__raddr_i[13 : 0];
            dtcm_lsu__rdata_o <= dtcm_rdata[lsu_raddr[4:2]*32 +: 32];
            ndma_raddr <= lcarb_dtcm__mem_raddr_i[13 : 0];
            dtcm_lcarb__mem_rdata_o <= dtcm_rdata;
            dm_raddr <= dm_dtcm__sba_addr_i[13 : 0];
            dtcm_dm__sba_rdata_o <= dtcm_rdata[dm_raddr[4:2]*32 +: 32];
        end
    end
    assign dtcm_lcarb__mem_atom_ready_o = !bus_lock;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            dtcm_lsu__wr_suc_o <= 1'b0;
            dtcm_lsu__rd_suc_o <= 1'b0;
        end else begin
            dtcm_lsu__wr_suc_o <= !lcarb_dtcm__mem_we_i;
            dtcm_lsu__rd_suc_o <= !lcarb_dtcm__mem_re_i;
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            lcarb_rd_suc <= 1'b0;
            dtcm_lcarb__mem_rdata_act_o <= 1'b0;
        end else begin
            lcarb_rd_suc <= lcarb_dtcm__mem_re_i;
            dtcm_lcarb__mem_rdata_act_o <= lcarb_rd_suc;
        end
    end
    assign dtcm_dm__sba_gnt_o = !(lcarb_dtcm__mem_re_i || lcarb_dtcm__mem_we_i);
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            dm_acc_en <= 1'b0;
            dtcm_dm__sba_rdata_act_o <= 1'b0;
        end else begin
            dm_acc_en <= dm_dtcm__sba_req_i & dtcm_dm__sba_gnt_o;
            dtcm_dm__sba_rdata_act_o <= dm_acc_en;
        end
    end
endmodule : hpu_dtcm
