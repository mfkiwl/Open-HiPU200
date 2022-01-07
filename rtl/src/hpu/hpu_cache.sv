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
// FILE NAME  : hpu_cache.sv
// DEPARTMENT : CAG of IAIR
// AUTHOR     : Boran
// AUTHOR'S EMAIL : boran.zhao@stu.xjtu.edu.cn
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_cache (
    input  logic                                   clk_i,
    input  logic                                   rst_i,
    input  logic                                   lsu_dc__dcache_nonblk_wr_en_i,
    input  pc_t                                    lsu_dc__dcache_waddr_i,
    output logic                                   dc_lsu__dcache_wr_suc_o,
    input  data_t                                  lsu_dc__dcache_wdata_i,
    input  data_strobe_t                           lsu_dc__dcache_wdata_strobe_i,
    input  logic                                   lsu_dc__dcache_nonblk_rd_en_i,
    input  pc_t                                    lsu_dc__dcache_raddr_i,
    output logic                                   dc_lsu__dcache_rd_suc_o,
    output data_t                                  dc_lsu__dcache_rdata_o,
    output ndma_cmd_t                              l2c_lcarb__cmd_o,
    output logic                                   l2c_lcarb__cmd_valid_o,
    input  logic                                   lcarb_l2c__cmd_ready_i,
    input  logic                                   lcarb_l2c__cmd_done_i,
    input  ndma_mem_req_t                          lcarb_l2c__mem_req_i,
    output ndma_mem_rsp_t                          l2c_lcarb__mem_rsp_o,
    output logic                                   dc_clint__intr_o,
    output logic                                   l2c_clint__intr_o,
    output  logic                                  ic_clint__intr_o,
    input   csr_bus_req_t                          csr_ic__bus_req_i, 
    output  csr_bus_rsp_t                          ic_csr__bus_rsp_o,
    input   csr_bus_req_t                          csr_dc__bus_req_i, 
    output  csr_bus_rsp_t                          dc_csr__bus_rsp_o,
    input   csr_bus_req_t                          csr_l2c__bus_req_i, 
    output  csr_bus_rsp_t                          l2c_csr__bus_rsp_o,
    input   logic                                  if_ic__npc_en_i,
    input   pc_t                                   if_ic__npc_i,
    output  logic                                  ic_if__suc_o,
    output  inst_t[INST_FETCH_PARAL-1 : 0]         ic_if__inst_o,
    input logic                                    ctrl_ic__flush_req_i
);
    parameter L1_L2_AWT                            = 32  ;
    parameter L1_L2_DWT                            = 4 *8;
    parameter L2_L1_DWT                            = 32*8;
    parameter IO_REG_CMD_WTH                       = 2   ;
    parameter IO_REG_DATASIZE_WTH                  = 19  ;
    parameter IO_REG_DESTX_WTH                     = 3   ;
    parameter IO_REG_DESTY_WTH                     = 3   ;
    parameter IO_REG_LOCALADDR_WTH                 = 32  ;
    parameter IO_REG_REMOTEADDR_WTH                = 32  ;                                         
    parameter IO_NOC_RADDR_WTH                     = 12  ; 
    parameter IO_NOC_RDATA_WTH                     = 256 ; 
    parameter IO_NOC_WADDR_WTH                     = 12  ; 
    parameter IO_NOC_WDATA_WTH                     = 256 ; 
    parameter IO_NOC_WDATA_STROBE_WTH              = 32  ;
    parameter CSR_L2C__ADDR_WTH                    = 12  ;
    parameter CSR_L2C__DATA_WTH                    = 32  ;
    logic											l1i_l2__rd_en;
    logic[L1_L2_AWT-1:0]	                        l1i_l2__addr;      
    logic 				                            l2_l1i__suc;          
    logic 				                            l2_l1i__suc_act;      
    logic[L2_L1_DWT-1:0]	                        l2_l1i__rdata;
    logic 				                            l2_l1i__rdata_act;
    
    logic                                           l2_l1d__suc_act;
    logic                                           l2_l1d__suc;
    logic                                           l1d_l2__wr_en;
    logic                                           l1d_l2__rd_en;
    logic[L1_L2_AWT-1:0]                            l1d_l2__addr;              
    logic[L2_L1_DWT-1:0]                            l2_l1d__rdata;       
    logic                                           l2_l1d__rdata_act;        
    logic[L1_L2_DWT-1:0]                            l1d_l2__wdata;        
    logic                                           l1d_l2__wdata_act; 
    logic[3:0]                                      l1d_l2__wstrb;    
icache l1icache_inst
(
    .clk_i                                          (clk_i),                             
    .rst_i                                          (rst_i),                        
    .if_ic__npc_en_i                                (if_ic__npc_en_i),                                            
    .if_ic__npc_i                                   (if_ic__npc_i),                                      
    .ic_if__suc_o                                   (ic_if__suc_o),                                      
    .ic_if__inst_o                                  (ic_if__inst_o),                           
    .l1i_l2__rd_en_o                                (l1i_l2__rd_en),         
    .l1i_l2__addr_o                                 (l1i_l2__addr),        
    .l2_l1i__suc_i                                  (l2_l1i__suc),       
    .l2_l1i__suc_act_i                              (l2_l1i__suc_act),          
    .l2_l1i__rdata_i                                (l2_l1i__rdata),        
    .l2_l1i__rdata_act_i                            (l2_l1i__rdata_act),                           
    .csr_ic__bus_req                                (csr_ic__bus_req_i),
    .ic_csr__bus_rsp                                (ic_csr__bus_rsp_o),
    .ic_csr__csr_finish_o                           (ic_clint__intr_o),
    .ctrl_ic__flush_req_i                           (ctrl_ic__flush_req_i)
);
dcache_top l1dcache_inst
(
    .clk_i                                          (clk_i),                             
    .rst_i                                          (rst_i),   
    .lsu_dc__dcache_nonblk_wr_en_i                  (lsu_dc__dcache_nonblk_wr_en_i),     
    .lsu_dc__dcache_waddr_i                         (lsu_dc__dcache_waddr_i),    
    .lsu_dc__dcache_nonblk_rd_en_i                  (lsu_dc__dcache_nonblk_rd_en_i),     
    .lsu_dc__dcache_raddr_i                         (lsu_dc__dcache_raddr_i),    
    .lsu_dc__dcache_wdata_i                         (lsu_dc__dcache_wdata_i),    
    .lsu_dc__dcache_wdata_strobe_i                  (lsu_dc__dcache_wdata_strobe_i),
    .dc_lsu__dcache_rd_suc_o                        (dc_lsu__dcache_rd_suc_o),     
    .dc_lsu__dcache_wr_suc_o                        (dc_lsu__dcache_wr_suc_o),     
    .dc_lsu__dcache_rdata_o                         (dc_lsu__dcache_rdata_o),    
    .l2_l1d__suc_act_i                              (l2_l1d__suc_act),                                         
    .l2_l1d__suc_i                                  (l2_l1d__suc),                                 
    .l2_l1d__rdata_act_i                            (l2_l1d__rdata_act),                                             
    .l2_l1d__rdata_i                                (l2_l1d__rdata),                                     
    .l1d_l2__wr_en_o                                (l1d_l2__wr_en),                                   
    .l1d_l2__rd_en_o                                (l1d_l2__rd_en),                                   
    .l1d_l2__addr_o                                 (l1d_l2__addr),                                   
    .l1d_l2__wdata_act_o                            (l1d_l2__wdata_act),                                             
    .l1d_l2__wdata_o                                (l1d_l2__wdata),                                    
    .l1d_l2__wdata_strobe_o                         (l1d_l2__wstrb),
    .csr_dc__bus_req                                (csr_dc__bus_req_i),  
    .dc_csr__bus_rsp                                (dc_csr__bus_rsp_o),
    .csr_finish_o                                   (dc_clint__intr_o) 
);
l2_cache
#
(
    .L1_L2_AWT                                      (L1_L2_AWT),
    .L1_L2_DWT                                      (L1_L2_DWT),
    .L2_L1_DWT                                      (L2_L1_DWT),
    .CSR_L2C__ADDR_WTH                              (CSR_L2C__ADDR_WTH),
    .CSR_L2C__DATA_WTH                              (CSR_L2C__DATA_WTH       )
) 
l2_cache_inst
(
    .clk_i                                          (clk_i),
    .rst_i                                          (rst_i),
    .l1d_l2__rd_en_i                                (l1d_l2__rd_en),
    .l1d_l2__wr_en_i                                (l1d_l2__wr_en),       
    .l1d_l2__addr_i                                 (l1d_l2__addr),        
    .l2_l1d__suc_o                                  (l2_l1d__suc),       
    .l2_l1d__suc_act_o                              (l2_l1d__suc_act),      
    .l2_l1d__rdata_o                                (l2_l1d__rdata),      
    .l2_l1d__rdata_act_o                            (l2_l1d__rdata_act),       
    .l1d_l2__wdata_i                                (l1d_l2__wdata),       
    .l1d_l2__wdata_act_i                            (l1d_l2__wdata_act),       
    .l1d_l2__wstrb_i                                (l1d_l2__wstrb),       
    .l1i_l2__rd_en_i                                (l1i_l2__rd_en),
    .l1i_l2__addr_i                                 (l1i_l2__addr),     
    .l2_l1i__suc_o                                  (l2_l1i__suc),         
    .l2_l1i__suc_act_o                              (l2_l1i__suc_act),     
    .l2_l1i__rdata_o                                (l2_l1i__rdata),
    .l2_l1i__rdata_act_o                            (l2_l1i__rdata_act),    
    .l2c_lcarb__cmd_o                               (l2c_lcarb__cmd_o),
    .l2c_lcarb__cmd_valid_o                         (l2c_lcarb__cmd_valid_o),
    .lcarb_l2c__cmd_ready_i                         (lcarb_l2c__cmd_ready_i),
    .lcarb_l2c__cmd_done_i                          (lcarb_l2c__cmd_done_i),
    .lcarb_l2c__mem_req_i                           (lcarb_l2c__mem_req_i),
    .l2c_lcarb__mem_rsp_o                           (l2c_lcarb__mem_rsp_o),  
    .csr_l2c__bus_req                               (csr_l2c__bus_req_i),              
    .l2c_csr__bus_rsp                               (l2c_csr__bus_rsp_o),  
    .l2c_csr__csr_finish_o                          (l2c_clint__intr_o)
);
endmodule
