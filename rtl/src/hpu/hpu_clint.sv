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
// FILE NAME  : hpu_clint.svh
// DEPARTMENT : Architecture
// AUTHOR     : chenfei
// AUTHOR'S EMAIL : fei.chen@xjtu.edu.cn
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_clint (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   clk_rtc_i,
    input   logic                                   sys_hpu__ext_intr_i,
    input   logic                                   ic_clint__intr_i,
    input   logic                                   dc_clint__intr_i,
    input   logic                                   l2c_clint__intr_i,
    input   logic                                   lcarb_clint__ndma_intr_i,
    input   logic                                   lcarb_clint__slv_wr_intr_i,
    input   logic                                   lcarb_clint__slv_rd_intr_i,
    input   logic                                   lcarb_clint__slv_swap_intr_i,
    input   logic                                   csr_clint__cop_intr_i,
    output  csr_mip_t                               clint_ctrl__intr_act_o,
    input   logic                                   lsu_clint__wr_en_i,
    input   pc_t                                    lsu_clint__waddr_i,
    input   data_t                                  lsu_clint__wdata_i,
    input   data_strobe_t                           lsu_clint__wstrb_i,
    input   logic                                   lsu_clint__rd_en_i,
    input   pc_t                                    lsu_clint__raddr_i,
    output  data_t                                  clint_lsu__rdata_o
);
    data_t                                  lcm_mtime;
    data_t                                  lcm_mtimeh;
    data_t                                  lcm_mtimecmp;
    data_t                                  lcm_mtimecmph;
    logic                                   lcm_msip;
    data_t                                  lcm_rdata;
    logic                                   clk_rtc;
    logic[1 : 0]                            rtc;
    logic                                   rtc_pulse;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            lcm_mtime <= data_t'(0);
            lcm_mtimeh <= data_t'(0);
            lcm_mtimecmp <= {DATA_WTH{1'b1}};
            lcm_mtimecmph <= {DATA_WTH{1'b1}};
            lcm_msip <= 1'b0;
        end else begin
            if(rtc_pulse) begin
                {lcm_mtimeh, lcm_mtime} <= {lcm_mtimeh, lcm_mtime} + 1'b1;
            end
            if(lsu_clint__wr_en_i) begin
                case(lsu_clint__waddr_i)
                    LCM_TIME: lcm_mtime <= lsu_clint__wdata_i;
                    LCM_TIMEH: lcm_mtimeh <= lsu_clint__wdata_i;
                    LCM_TIMECMP: lcm_mtimecmp <= lsu_clint__wdata_i;
                    LCM_TIMECMPH: lcm_mtimecmph <= lsu_clint__wdata_i;
                    LCM_CSIP: lcm_msip <= lsu_clint__wdata_i[0];
                endcase
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            lcm_rdata <= data_t'(0);
            clint_lsu__rdata_o <= data_t'(0);
        end else begin
            if(lsu_clint__rd_en_i) begin
                case(lsu_clint__raddr_i)
                    LCM_TIME: lcm_rdata <= lcm_mtime;
                    LCM_TIMEH: lcm_rdata <= lcm_mtimeh;
                    LCM_TIMECMP: lcm_rdata <= lcm_mtimecmp;
                    LCM_TIMECMPH: lcm_rdata <= lcm_mtimecmph;
                    LCM_CSIP: lcm_rdata <= data_t'(lcm_msip);
                endcase
            end
            clint_lsu__rdata_o <= lcm_rdata;
        end
    end
    sig_sync #(.SIG_WTH(1)) rtc_sync_inst (.clk_i(clk_i), .rst_i(rst_i), .data_i(clk_rtc_i), .data_o(clk_rtc));
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            rtc <= 2'h0;
            rtc_pulse <= 1'b0;
        end else begin
            rtc <= {rtc[0], clk_rtc};
            rtc_pulse <= rtc[0] & ~rtc[1];
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            clint_ctrl__intr_act_o <= csr_mip_t'(0);
        end else begin
            clint_ctrl__intr_act_o <= csr_mip_t'(0);
            clint_ctrl__intr_act_o.L2CIP <= l2c_clint__intr_i ;
            clint_ctrl__intr_act_o.DCIP <= dc_clint__intr_i ;
            clint_ctrl__intr_act_o.ICIP <= ic_clint__intr_i;
            clint_ctrl__intr_act_o.NDMAIP <= lcarb_clint__ndma_intr_i ;
            clint_ctrl__intr_act_o.SWRIP <= lcarb_clint__slv_wr_intr_i ;
            clint_ctrl__intr_act_o.SRDIP <= lcarb_clint__slv_rd_intr_i ;
            clint_ctrl__intr_act_o.SSWAPIP <= lcarb_clint__slv_swap_intr_i ;
            clint_ctrl__intr_act_o.COPIP <= csr_clint__cop_intr_i ;
            clint_ctrl__intr_act_o.MEIP <= sys_hpu__ext_intr_i ;
            clint_ctrl__intr_act_o.MSIP <= lcm_msip ;
            clint_ctrl__intr_act_o.MTIP <= {lcm_mtimeh, lcm_mtime} >= {lcm_mtimecmph, lcm_mtimecmp};
        end
    end
endmodule : hpu_clint
