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
// FILE NAME  : hpu_pipeline.sv
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

module hpu (
    // =============================================
    // clock & reset
    input   logic                                   tck_i,                  // JTAG clock
    input   logic                                   trst_ni,                // JTAG reset
    input   logic                                   clk_i,                  // HPU clock
    input   logic                                   clk_rtc_i,              // RTC clock
    input   logic                                   rst_i,                  // asynchronized reset
    input   logic                                   rst_debug_i,            // asynchronized reset for debug module
    // input   logic                                   testmode_i,             // in test mode, clk gating'd be closed.
    output  logic                                   dm_rst__ndmreset_o,     // indicating the DM caused reset request
    // =============================================
    // control signal from SYS_REG
    input   logic[3:0]                              sys_hpu__id_i,          // HPU id, equals {node.x[1:0], node.y[1:0}
    input   logic                                   sys_hpu__restart_i,     // HPU works until this signal is low.
    input   logic                                   sys_hpu__mode_single_step_i,// HPU works as a FSM processor.
    input   logic                                   sys_hpu__mode_scalar_i, // HPU works as a scalar processor.
    input   logic                                   sys_hpu__mode_super_scalar_i, // HPU works as a super scalar proc.
    input   pc_t                                    sys_hpu__init_pc_i,     // the initial PC when restart signal falls.
    output  logic                                   hpu_sys__wfi_act_o,     // The WFI signal of HPU
    input   logic                                   sys_hpu__eint_i,        // Clear the WFI signal of HPU
    output  logic                                   hpu_sys__sig_req_o,     // The signal request of HPU
    input   logic                                   sys_hpu__sig_rsp_i,     // The signal response of HPU
    // =============================================
    // NoC DMA
    output  logic[3 : 0]                            ndma_cmd_op_o,          // command: write=4'h0;read=4'h1;swap=4'h2
    output  logic[15 : 0]                           ndma_cmd_id_o,          // internal transform ID
    output  logic[NDMA_TRANS_BIT-1 : 0]             ndma_cmd_size_o,        // transform size in bytes
    output  logic[NDMA_LC_ADDR_WTH-1 : 0]           ndma_cmd_lcaddr_o,      // local address, byte aligned
    output  logic[NDMA_ADDR_WTH-1 : 0]              ndma_cmd_rtaddr_o,      // remote address, byte aligned
    output  logic[NDMA_NDX_WTH-1 : 0]               ndma_cmd_destx_o,       // 2bit for 4x4
    output  logic[NDMA_NDY_WTH-1 : 0]               ndma_cmd_desty_o,	    // 2bit for 4x4
    output  logic                                   ndma_cmd_valid_o,       // config data valid
    input   logic                                   ndma_cmd_ready_i,       // ready to be configed

    input   logic[15 : 0]                           ndma_tx_done_id_i,      // transfer done ID
    input   logic                                   ndma_tx_done_i,         // transfer done
    input   logic[15 : 0]                           ndma_rx_done_id_i,      // receiver done ID
    input   logic                                   ndma_rx_done_i,         // receiver done

    input   logic                                   ndma_mem_re_i,	    // read address is valid
    input   logic[NDMA_LC_ADDR_WTH-1 : 0]           ndma_mem_raddr_i,       // byte aligned
    output  logic[NDMA_LC_DATA_WTH-1 : 0]           ndma_mem_rdata_o,       // data
    output  logic                                   ndma_mem_rdata_act_o,   // read data is active.
    input   logic                                   ndma_mem_we_i,          // write address is valid
    input   logic[NDMA_LC_ADDR_WTH-1 : 0]           ndma_mem_waddr_i,	    // byte aligned
    input   logic[NDMA_LC_DATA_WTH-1 : 0]           ndma_mem_wdata_i,       // data, same clock with write address.
    input   logic[NDMA_LC_STRB_WTH-1 : 0]           ndma_mem_wstrb_i,       // each bit indicates 32bit(4Byte) data
    output  logic                                   ndma_mem_atom_ready_o,  // it indicates whether it can do atomic op.
    // =============================================
    // HPU_DTM
    input   logic[5 : 0]                            dmi_dmid_i,
    input   logic                                   dmi_req_valid_i,
    output  logic                                   dmi_req_ready_o,
    input   dmi_req_t                               dmi_req_i,

    output  logic                                   dmi_resp_valid_o,
    input   logic                                   dmi_resp_ready_i,
    output  dmi_resp_t                              dmi_resp_o
);

//======================================================================================================================
// Wire & Reg declaration
//======================================================================================================================

    logic                                   rst_sync;
    logic[1 : 0]                            rst_dlychain;
    logic                                   ctrl_dm__status_halted;
    logic                                   ctrl_dm__status_running;
    logic                                   ctrl_dm__status_havereset;
    logic                                   ctrl_dm__unavailable;
    data_t                                  ctrl_dm__hartinfo;
    logic                                   darb_dm__req;
    logic                                   darb_dm__we;
    pc_t                                    darb_dm__addr;
    data_t                                  darb_dm__wdata;
    logic                                   if_ic__npc_en;
    pc_t                                    if_ic__npc;
    logic                                   lsu_dc__wr_en;
    pc_t                                    lsu_dc__waddr;
    data_t                                  lsu_dc__wdata;
    data_strobe_t                           lsu_dc__wstrb;
    logic                                   lsu_dc__rd_en;
    pc_t                                    lsu_dc__raddr;
    logic                                   lsu_dtcm__wr_en;
    logic                                   lsu_dtcm__wr_rls_lock;
    pc_t                                    lsu_dtcm__waddr;
    data_t                                  lsu_dtcm__wdata;
    data_strobe_t                           lsu_dtcm__wstrb;
    logic                                   lsu_dtcm__rd_en;
    logic                                   lsu_dtcm__rd_acq_lock;
    pc_t                                    lsu_dtcm__raddr;
    logic                                   lsu_clint__wr_en;
    pc_t                                    lsu_clint__waddr;
    data_t                                  lsu_clint__wdata;
    data_strobe_t                           lsu_clint__wstrb;
    logic                                   lsu_clint__rd_en;
    pc_t                                    lsu_clint__raddr;
    logic                                   lsu_lmrw__wr_en;
    pc_t                                    lsu_lmrw__waddr;
    data_t                                  lsu_lmrw__wdata;
    data_strobe_t                           lsu_lmrw__wstrb;
    logic                                   lsu_lmrw__rd_en;
    data_t                                  lsu_lmrw__raddr;
    logic                                   vmu_lmrw__vec_wr_en;
    logic[LM_ADDR_WTH-1 : 0]                vmu_lmrw__vec_waddr;
    mtx_t[VEC_SIZE-1 : 0]                   vmu_lmrw__vec_wdata;
    logic                                   vmu_lmrw__vec_rd_en;
    logic[LM_ADDR_WTH-1 : 0]                vmu_lmrw__vec_raddr;
    logic                                   vmu_lmrw__mtx_rd_en;
    logic                                   vmu_lmrw__mtx_algup_en;
    logic                                   vmu_lmrw__mtx_algdn_en;
    logic[LM_ADDR_WTH-1 : 0]                vmu_lmrw__mtx_raddr;
    logic                                   vmu_lmro__mtx_rd_en;
    logic                                   vmu_lmro__mtx_vm_mode;
    logic[LM_ADDR_WTH-1 : 0]                vmu_lmro__mtx_raddr;
    csr_bus_req_t                           csr_ic__bus_req;
    csr_bus_req_t                           csr_dc__bus_req;
    csr_bus_req_t                           csr_l2c__bus_req;
    csr_bus_req_t                           csr_lcarb__bus_req;
    logic                                   ctrl_ic__flush_req;
    pc_t                                    safemd_arc_pc;
    logic                                   safemd_ndma_single_cmd;
    logic                                   safemd_rcov_disable;
    logic                                   safemd_safe_fl;
    csr_bus_rsp_t                           ic_csr__bus_rsp;
    csr_bus_rsp_t                           dc_csr__bus_rsp;
    csr_bus_rsp_t                           l2c_csr__bus_rsp;
    logic                                   dc_lsu__wr_suc;
    logic                                   dc_lsu__rd_suc;
    data_t                                  dc_lsu__rdata;
    ndma_cmd_t                              l2c_lcarb__cmd;
    logic                                   l2c_lcarb__cmd_valid;
    ndma_mem_rsp_t                          l2c_lcarb__mem_rsp;
    logic                                   dc_clint__intr;
    logic                                   l2c_clint__intr;
    logic                                   ic_if__suc;
    inst_t[INST_FETCH_PARAL-1 : 0]          ic_if__inst;
    logic                                   ic_clint__intr;
    logic                                   ic_ctrl__flush_done;
    csr_mip_t                               clint_ctrl__intr_act;
    data_t                                  clint_lsu__rdata;
    logic                                   lmrw_lsu__wr_suc;
    data_t                                  lmrw_lsu__rdata;
    logic                                   lmrw_lsu__rd_suc;
    mtx_t[VEC_SIZE-1 : 0]                   lmrw_vmu__vec_rdata;
    mtx_t[VEC_SIZE-1 : 0]                   lmrw_vmu__mtx_rdata;
    logic[255:0]                            lmrw_lcarb__mem_rdata;
    logic                                   lmrw_lcarb__mem_rdata_act;
    mtx_t[VEC_SIZE-1 : 0]                   lmro_vmu__mtx_rdata;
    mtx_t[VEC_SIZE*VEC_SIZE_V-1 : 0]        lmro_vmu__mtx_vm_rdata;
    logic                                   lmro_lcarb__mem_rdata_act;
    logic[255:0]                            lmro_lcarb__mem_rdata;
    logic                                   dtcm_lsu__wr_suc;
    logic                                   dtcm_lsu__rd_suc;
    data_t                                  dtcm_lsu__rdata;
    logic                                   dtcm_lcarb__mem_rdata_act;
    logic[255:0]                            dtcm_lcarb__mem_rdata;
    logic                                   dtcm_lcarb__mem_atom_ready;
    logic                                   dtcm_dm__sba_gnt;
    data_t                                  dtcm_dm__sba_rdata;
    logic                                   dtcm_dm__sba_rdata_act;
    logic[255:0]                            dtcm_lcarb__node_map;
    logic[255:0]                            dtcm_lcarb__mem_map;
    logic                                   lcarb_l2c__cmd_ready;
    logic                                   lcarb_l2c__cmd_done;
    ndma_mem_req_t                          lcarb_l2c__mem_req;
    logic                                   lcarb_lmrw__mem_re;
    logic[17:0]                             lcarb_lmrw__mem_raddr;
    logic                                   lcarb_lmrw__mem_we;
    logic[17:0]                             lcarb_lmrw__mem_waddr;
    logic[255:0]                            lcarb_lmrw__mem_wdata;
    logic[7:0]                              lcarb_lmrw__mem_wstrb;
    logic                                   lcarb_lmro__mem_re;
    logic[17:0]                             lcarb_lmro__mem_raddr;
    logic                                   lcarb_lmro__mem_we;
    logic[17:0]                             lcarb_lmro__mem_waddr;
    logic[255:0]                            lcarb_lmro__mem_wdata;
    logic[7:0]                              lcarb_lmro__mem_wstrb;
    logic                                   lcarb_dtcm__mem_re;
    logic[13:0]                             lcarb_dtcm__mem_raddr;
    logic                                   lcarb_dtcm__mem_we;
    logic[13:0]                             lcarb_dtcm__mem_waddr;
    logic[255:0]                            lcarb_dtcm__mem_wdata;
    logic[7:0]                              lcarb_dtcm__mem_wstrb;
    logic                                   lcarb_clint__ndma_intr;
    logic                                   lcarb_clint__slv_wr_intr;
    logic                                   lcarb_clint__slv_rd_intr;
    logic                                   lcarb_clint__slv_swap_intr;
    csr_bus_rsp_t                           lcarb_csr__bus_rsp;
    logic                                   dm_ctrl__dmactive;
    logic[0 : 0]                            dm_ctrl__req_halt;
    logic[0 : 0]                            dm_ctrl__req_resume;
    logic                                   dm_ctrl__req_setrsthalt;
    logic                                   dm_ctrl__start_cmd;
    logic[31 : 0]                           dm_darb__rdata;
    logic                                   dm_dtcm__sba_req;
    logic[31 : 0]                           dm_dtcm__sba_addr;
    logic                                   dm_dtcm__sba_we;
    logic[31 : 0]                           dm_dtcm__sba_wdata;
    logic[3 : 0]                            dm_dtcm__sba_be;

//======================================================================================================================
// Instance
//======================================================================================================================

    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            {rst_sync, rst_dlychain} <= {3{RST_LVL}};
        end else begin
            {rst_sync, rst_dlychain} <= {rst_dlychain, !RST_LVL};
        end
    end

    hpu_pipeline hpu_pipeline_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_sync),
        .sys_hpu__restart_i                             (sys_hpu__restart_i),
        .sys_hpu__mode_single_step_i                    (sys_hpu__mode_single_step_i),
        .sys_hpu__mode_scalar_i                         (sys_hpu__mode_scalar_i),
        .sys_hpu__mode_super_scalar_i                   (sys_hpu__mode_super_scalar_i),
        .sys_hpu__init_pc_i                             (sys_hpu__init_pc_i),
        .hpu_sys__wfi_act_o                             (hpu_sys__wfi_act_o),
        .clint_ctrl__intr_act_i                         (clint_ctrl__intr_act),
        .dm_ctrl__req_halt_i                            (dm_ctrl__req_halt),
        .dm_ctrl__req_resume_i                          (dm_ctrl__req_resume),
        .dm_ctrl__req_setrsthalt_i                      (dm_ctrl__req_setrsthalt),
        .dm_ctrl__start_cmd_i                           (dm_ctrl__start_cmd),
        .ctrl_dm__status_halted_o                       (ctrl_dm__status_halted),
        .ctrl_dm__status_running_o                      (ctrl_dm__status_running),
        .ctrl_dm__status_havereset_o                    (ctrl_dm__status_havereset),
        .ctrl_dm__unavailable_o                         (ctrl_dm__unavailable),
        .ctrl_dm__hartinfo_o                            (ctrl_dm__hartinfo),
        .darb_dm__req_o                                 (darb_dm__req),
        .darb_dm__we_o                                  (darb_dm__we),
        .darb_dm__addr_o                                (darb_dm__addr),
        .darb_dm__wdata_o                               (darb_dm__wdata),
        .dm_darb__rdata_i                               (dm_darb__rdata),
        .if_ic__npc_en_o                                (if_ic__npc_en),
        .if_ic__npc_o                                   (if_ic__npc),
        .ic_if__suc_i                                   (ic_if__suc),
        .ic_if__inst_i                                  (ic_if__inst),
        .lsu_dc__wr_en_o                                (lsu_dc__wr_en),
        .lsu_dc__waddr_o                                (lsu_dc__waddr),
        .dc_lsu__wr_suc_i                               (dc_lsu__wr_suc),
        .lsu_dc__wdata_o                                (lsu_dc__wdata),
        .lsu_dc__wstrb_o                                (lsu_dc__wstrb),
        .lsu_dc__rd_en_o                                (lsu_dc__rd_en),
        .lsu_dc__raddr_o                                (lsu_dc__raddr),
        .dc_lsu__rd_suc_i                               (dc_lsu__rd_suc),
        .dc_lsu__rdata_i                                (dc_lsu__rdata),
        .lsu_dtcm__wr_en_o                              (lsu_dtcm__wr_en),
        .lsu_dtcm__wr_rls_lock_o                        (lsu_dtcm__wr_rls_lock),
        .lsu_dtcm__waddr_o                              (lsu_dtcm__waddr),
        .dtcm_lsu__wr_suc_i                             (dtcm_lsu__wr_suc),
        .lsu_dtcm__wdata_o                              (lsu_dtcm__wdata),
        .lsu_dtcm__wstrb_o                              (lsu_dtcm__wstrb),
        .lsu_dtcm__rd_en_o                              (lsu_dtcm__rd_en),
        .lsu_dtcm__rd_acq_lock_o                        (lsu_dtcm__rd_acq_lock),
        .lsu_dtcm__raddr_o                              (lsu_dtcm__raddr),
        .dtcm_lsu__rd_suc_i                             (dtcm_lsu__rd_suc),
        .dtcm_lsu__rdata_i                              (dtcm_lsu__rdata),
        .lsu_clint__wr_en_o                             (lsu_clint__wr_en),
        .lsu_clint__waddr_o                             (lsu_clint__waddr),
        .lsu_clint__wdata_o                             (lsu_clint__wdata),
        .lsu_clint__wstrb_o                             (lsu_clint__wstrb),
        .lsu_clint__rd_en_o                             (lsu_clint__rd_en),
        .lsu_clint__raddr_o                             (lsu_clint__raddr),
        .clint_lsu__rdata_i                             (clint_lsu__rdata),
        .lsu_lmrw__wr_en_o                              (lsu_lmrw__wr_en),
        .lsu_lmrw__waddr_o                              (lsu_lmrw__waddr),
        .lmrw_lsu__wr_suc_i                             (lmrw_lsu__wr_suc),
        .lsu_lmrw__wdata_o                              (lsu_lmrw__wdata),
        .lsu_lmrw__wstrb_o                              (lsu_lmrw__wstrb),
        .lsu_lmrw__rd_en_o                              (lsu_lmrw__rd_en),
        .lsu_lmrw__raddr_o                              (lsu_lmrw__raddr),
        .lmrw_lsu__rdata_i                              (lmrw_lsu__rdata),
        .lmrw_lsu__rd_suc_i                             (lmrw_lsu__rd_suc),
        .vmu_lmrw__vec_wr_en_o                          (vmu_lmrw__vec_wr_en),
        .vmu_lmrw__vec_waddr_o                          (vmu_lmrw__vec_waddr),
        .vmu_lmrw__vec_wdata_o                          (vmu_lmrw__vec_wdata),
        .vmu_lmrw__vec_rd_en_o                          (vmu_lmrw__vec_rd_en),
        .vmu_lmrw__vec_raddr_o                          (vmu_lmrw__vec_raddr),
        .lmrw_vmu__vec_rdata_i                          (lmrw_vmu__vec_rdata),
        .vmu_lmrw__mtx_rd_en_o                          (vmu_lmrw__mtx_rd_en),
        .vmu_lmrw__mtx_algup_en_o                       (vmu_lmrw__mtx_algup_en),
        .vmu_lmrw__mtx_algdn_en_o                       (vmu_lmrw__mtx_algdn_en),
        .vmu_lmrw__mtx_raddr_o                          (vmu_lmrw__mtx_raddr),
        .lmrw_vmu__mtx_rdata_i                          (lmrw_vmu__mtx_rdata),
        .vmu_lmro__mtx_rd_en_o                          (vmu_lmro__mtx_rd_en),
        .vmu_lmro__mtx_vm_mode_o                        (vmu_lmro__mtx_vm_mode),
        .vmu_lmro__mtx_raddr_o                          (vmu_lmro__mtx_raddr),
        .lmro_vmu__mtx_rdata_i                          (lmro_vmu__mtx_rdata),
        .lmro_vmu__mtx_vm_rdata_i                       (lmro_vmu__mtx_vm_rdata),
        .csr_ic__bus_req_o                              (csr_ic__bus_req),
        .ic_csr__bus_rsp_i                              (ic_csr__bus_rsp),
        .csr_dc__bus_req_o                              (csr_dc__bus_req),
        .dc_csr__bus_rsp_i                              (dc_csr__bus_rsp),
        .csr_l2c__bus_req_o                             (csr_l2c__bus_req),
        .l2c_csr__bus_rsp_i                             (l2c_csr__bus_rsp),
        .csr_lcarb__bus_req_o                           (csr_lcarb__bus_req),
        .lcarb_csr__bus_rsp_i                           (lcarb_csr__bus_rsp),
        .ctrl_ic__flush_req_o                           (ctrl_ic__flush_req),
        .ic_ctrl__flush_done_i                          (1'b1),
        .csr_hpu_id_i                                   (sys_hpu__id_i),
        .csr_dm_id_i                                    (dmi_dmid_i),
        .safemd_arc_pc_o                                (safemd_arc_pc),
        .safemd_rcov_disable_i                          (safemd_rcov_disable),
        .safemd_safe_fl_i                               (safemd_safe_fl)
    );

    hpu_cache hpu_cache_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_sync),
        .csr_ic__bus_req_i                              (csr_ic__bus_req),
        .ic_csr__bus_rsp_o                              (ic_csr__bus_rsp),
        .csr_dc__bus_req_i                              (csr_dc__bus_req),
        .dc_csr__bus_rsp_o                              (dc_csr__bus_rsp),
        .csr_l2c__bus_req_i                             (csr_l2c__bus_req),
        .l2c_csr__bus_rsp_o                             (l2c_csr__bus_rsp),
        
        .if_ic__npc_en_i                                (if_ic__npc_en),
        .if_ic__npc_i                                   (if_ic__npc),
        .ic_if__suc_o                                   (ic_if__suc),
        .ic_if__inst_o                                  (ic_if__inst),
        .lsu_dc__dcache_nonblk_wr_en_i                  (lsu_dc__wr_en),
        .lsu_dc__dcache_waddr_i                         (lsu_dc__waddr),
        .dc_lsu__dcache_wr_suc_o                        (dc_lsu__wr_suc),
        .lsu_dc__dcache_wdata_i                         (lsu_dc__wdata),
        .lsu_dc__dcache_wdata_strobe_i                  (lsu_dc__wstrb),

        .lsu_dc__dcache_nonblk_rd_en_i                  (lsu_dc__rd_en),
        .lsu_dc__dcache_raddr_i                         (lsu_dc__raddr),
        .dc_lsu__dcache_rd_suc_o                        (dc_lsu__rd_suc),
        .dc_lsu__dcache_rdata_o                         (dc_lsu__rdata),
        .l2c_lcarb__cmd_o                               (l2c_lcarb__cmd),
        .l2c_lcarb__cmd_valid_o                         (l2c_lcarb__cmd_valid),
        .lcarb_l2c__cmd_ready_i                         (lcarb_l2c__cmd_ready),
        .lcarb_l2c__cmd_done_i                          (lcarb_l2c__cmd_done),
        .lcarb_l2c__mem_req_i                           (lcarb_l2c__mem_req),
        .l2c_lcarb__mem_rsp_o                           (l2c_lcarb__mem_rsp),
        .ic_clint__intr_o                               (ic_clint__intr),
        .dc_clint__intr_o                               (dc_clint__intr),
        .l2c_clint__intr_o                              (l2c_clint__intr),
        .ctrl_ic__flush_req_i                           (ctrl_ic__flush_req)
    );

    hpu_clint hpu_clint_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_sync),
        .clk_rtc_i                                      (clk_rtc_i),
        .sys_hpu__ext_intr_i                            (sys_hpu__eint_i),
        .ic_clint__intr_i                               (ic_clint__intr),
        .dc_clint__intr_i                               (dc_clint__intr),
        .l2c_clint__intr_i                              (l2c_clint__intr),
        .lcarb_clint__ndma_intr_i                       (lcarb_clint__ndma_intr),
        .lcarb_clint__slv_wr_intr_i                     (lcarb_clint__slv_wr_intr),
        .lcarb_clint__slv_rd_intr_i                     (lcarb_clint__slv_rd_intr),
        .lcarb_clint__slv_swap_intr_i                   (lcarb_clint__slv_swap_intr),
        .csr_clint__cop_intr_i                          (1'b0),
        .clint_ctrl__intr_act_o                         (clint_ctrl__intr_act),
        .lsu_clint__wr_en_i                             (lsu_clint__wr_en),
        .lsu_clint__waddr_i                             (lsu_clint__waddr),
        .lsu_clint__wdata_i                             (lsu_clint__wdata),
        .lsu_clint__wstrb_i                             (lsu_clint__wstrb),
        .lsu_clint__rd_en_i                             (lsu_clint__rd_en),
        .lsu_clint__raddr_i                             (lsu_clint__raddr),
        .clint_lsu__rdata_o                             (clint_lsu__rdata)
    );

    hpu_lmrw hpu_lmrw_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_sync),
        .lsu_lmrw__wr_en_i                              (lsu_lmrw__wr_en),
        .lsu_lmrw__waddr_i                              (lsu_lmrw__waddr),
        .lmrw_lsu__wr_suc_o                             (lmrw_lsu__wr_suc),
        .lsu_lmrw__wdata_i                              (lsu_lmrw__wdata),
        .lsu_lmrw__wstrb_i                              (lsu_lmrw__wstrb),
        .lsu_lmrw__rd_en_i                              (lsu_lmrw__rd_en),
        .lsu_lmrw__raddr_i                              (lsu_lmrw__raddr),
        .lmrw_lsu__rdata_o                              (lmrw_lsu__rdata),
        .lmrw_lsu__rd_suc_o                             (lmrw_lsu__rd_suc),
        .vmu_lmrw__vec_wr_en_i                          (vmu_lmrw__vec_wr_en),
        .vmu_lmrw__vec_waddr_i                          (vmu_lmrw__vec_waddr),
        .vmu_lmrw__vec_wdata_i                          (vmu_lmrw__vec_wdata),
        .vmu_lmrw__vec_rd_en_i                          (vmu_lmrw__vec_rd_en),
        .vmu_lmrw__vec_raddr_i                          (vmu_lmrw__vec_raddr),
        .lmrw_vmu__vec_rdata_o                          (lmrw_vmu__vec_rdata),
        .vmu_lmrw__mtx_rd_en_i                          (vmu_lmrw__mtx_rd_en),
        .vmu_lmrw__mtx_algup_en_i                       (vmu_lmrw__mtx_algup_en),
        .vmu_lmrw__mtx_algdn_en_i                       (vmu_lmrw__mtx_algdn_en),
        .vmu_lmrw__mtx_raddr_i                          (vmu_lmrw__mtx_raddr),
        .lmrw_vmu__mtx_rdata_o                          (lmrw_vmu__mtx_rdata),
        .lcarb_lmrw__mem_re_i                           (lcarb_lmrw__mem_re),
        .lcarb_lmrw__mem_raddr_i                        (lcarb_lmrw__mem_raddr),
        .lmrw_lcarb__mem_rdata_o                        (lmrw_lcarb__mem_rdata),
        .lmrw_lcarb__mem_rdata_act_o                    (lmrw_lcarb__mem_rdata_act),
        .lcarb_lmrw__mem_we_i                           (lcarb_lmrw__mem_we),
        .lcarb_lmrw__mem_waddr_i                        (lcarb_lmrw__mem_waddr),
        .lcarb_lmrw__mem_wdata_i                        (lcarb_lmrw__mem_wdata),
        .lcarb_lmrw__mem_wstrb_i                        (lcarb_lmrw__mem_wstrb)
    );

    hpu_lmro hpu_lmro_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_sync),
        .vmu_lmro__mtx_rd_en_i                          (vmu_lmro__mtx_rd_en),
        .vmu_lmro__mtx_vm_mode_i                        (vmu_lmro__mtx_vm_mode),
        .vmu_lmro__mtx_raddr_i                          (vmu_lmro__mtx_raddr),
        .lmro_vmu__mtx_rdata_o                          (lmro_vmu__mtx_rdata),
        .lmro_vmu__mtx_vm_rdata_o                       (lmro_vmu__mtx_vm_rdata),
        .lcarb_lmro__mem_re_i                           (lcarb_lmro__mem_re),
        .lcarb_lmro__mem_raddr_i                        (lcarb_lmro__mem_raddr),
        .lmro_lcarb__mem_rdata_act_o                    (lmro_lcarb__mem_rdata_act),
        .lmro_lcarb__mem_rdata_o                        (lmro_lcarb__mem_rdata),
        .lcarb_lmro__mem_we_i                           (lcarb_lmro__mem_we),
        .lcarb_lmro__mem_waddr_i                        (lcarb_lmro__mem_waddr),
        .lcarb_lmro__mem_wdata_i                        (lcarb_lmro__mem_wdata),
        .lcarb_lmro__mem_wstrb_i                        (lcarb_lmro__mem_wstrb)
    );

    hpu_dtcm hpu_dtcm_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_sync),
        .lsu_dtcm__wr_en_i                              (lsu_dtcm__wr_en),
        .lsu_dtcm__wr_rls_lock_i                        (lsu_dtcm__wr_rls_lock),
        .lsu_dtcm__waddr_i                              (lsu_dtcm__waddr),
        .dtcm_lsu__wr_suc_o                             (dtcm_lsu__wr_suc),
        .lsu_dtcm__wdata_i                              (lsu_dtcm__wdata),
        .lsu_dtcm__wstrb_i                              (lsu_dtcm__wstrb),
        .lsu_dtcm__rd_en_i                              (lsu_dtcm__rd_en),
        .lsu_dtcm__rd_acq_lock_i                        (lsu_dtcm__rd_acq_lock),
        .lsu_dtcm__raddr_i                              (lsu_dtcm__raddr),
        .dtcm_lsu__rd_suc_o                             (dtcm_lsu__rd_suc),
        .dtcm_lsu__rdata_o                              (dtcm_lsu__rdata),
        .lcarb_dtcm__mem_re_i                           (lcarb_dtcm__mem_re),
        .lcarb_dtcm__mem_raddr_i                        (lcarb_dtcm__mem_raddr),
        .dtcm_lcarb__mem_rdata_act_o                    (dtcm_lcarb__mem_rdata_act),
        .dtcm_lcarb__mem_rdata_o                        (dtcm_lcarb__mem_rdata),
        .lcarb_dtcm__mem_we_i                           (lcarb_dtcm__mem_we),
        .lcarb_dtcm__mem_waddr_i                        (lcarb_dtcm__mem_waddr),
        .lcarb_dtcm__mem_wdata_i                        (lcarb_dtcm__mem_wdata),
        .lcarb_dtcm__mem_wstrb_i                        (lcarb_dtcm__mem_wstrb),
        .dtcm_lcarb__mem_atom_ready_o                   (dtcm_lcarb__mem_atom_ready),
        .dm_dtcm__sba_req_i                             (dm_dtcm__sba_req),
        .dm_dtcm__sba_addr_i                            (dm_dtcm__sba_addr),
        .dm_dtcm__sba_we_i                              (dm_dtcm__sba_we),
        .dm_dtcm__sba_wdata_i                           (dm_dtcm__sba_wdata),
        .dm_dtcm__sba_be_i                              (dm_dtcm__sba_be),
        .dtcm_dm__sba_gnt_o                             (dtcm_dm__sba_gnt),
        .dtcm_dm__sba_rdata_o                           (dtcm_dm__sba_rdata),
        .dtcm_dm__sba_rdata_act_o                       (dtcm_dm__sba_rdata_act),
        .hpu_sys__sig_req_o                             (hpu_sys__sig_req_o),
        .sys_hpu__sig_rsp_i                             (sys_hpu__sig_rsp_i),
        .dtcm_lcarb__node_map_o                         (dtcm_lcarb__node_map),
        .dtcm_lcarb__mem_map_o                          (dtcm_lcarb__mem_map),
        .safemd_arc_pc_i                                (safemd_arc_pc),
        .safemd_ndma_single_cmd_o                       (safemd_ndma_single_cmd),
        .safemd_rcov_disable_o                          (safemd_rcov_disable),
        .safemd_safe_fl_o                               (safemd_safe_fl)
    );

    hpu_lcarb hpu_lcarb_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_sync),
        .l2c_lcarb__cmd_i                               (l2c_lcarb__cmd),
        .l2c_lcarb__cmd_valid_i                         (l2c_lcarb__cmd_valid),
        .lcarb_l2c__cmd_ready_o                         (lcarb_l2c__cmd_ready),
        .lcarb_l2c__cmd_done_o                          (lcarb_l2c__cmd_done),
        .lcarb_l2c__mem_req_o                           (lcarb_l2c__mem_req),
        .l2c_lcarb__mem_rsp_i                           (l2c_lcarb__mem_rsp),
        .csr_lcarb__bus_req_i                           (csr_lcarb__bus_req),
        .lcarb_csr__bus_rsp_o                           (lcarb_csr__bus_rsp),
        .lcarb_lmrw__mem_re_o                           (lcarb_lmrw__mem_re),
        .lcarb_lmrw__mem_raddr_o                        (lcarb_lmrw__mem_raddr),
        .lmrw_lcarb__mem_rdata_act_i                    (lmrw_lcarb__mem_rdata_act),
        .lmrw_lcarb__mem_rdata_i                        (lmrw_lcarb__mem_rdata),
        .lcarb_lmrw__mem_we_o                           (lcarb_lmrw__mem_we),
        .lcarb_lmrw__mem_waddr_o                        (lcarb_lmrw__mem_waddr),
        .lcarb_lmrw__mem_wdata_o                        (lcarb_lmrw__mem_wdata),
        .lcarb_lmrw__mem_wstrb_o                        (lcarb_lmrw__mem_wstrb),
        .lcarb_lmro__mem_re_o                           (lcarb_lmro__mem_re),
        .lcarb_lmro__mem_raddr_o                        (lcarb_lmro__mem_raddr),
        .lmro_lcarb__mem_rdata_act_i                    (lmro_lcarb__mem_rdata_act),
        .lmro_lcarb__mem_rdata_i                        (lmro_lcarb__mem_rdata),
        .lcarb_lmro__mem_we_o                           (lcarb_lmro__mem_we),
        .lcarb_lmro__mem_waddr_o                        (lcarb_lmro__mem_waddr),
        .lcarb_lmro__mem_wdata_o                        (lcarb_lmro__mem_wdata),
        .lcarb_lmro__mem_wstrb_o                        (lcarb_lmro__mem_wstrb),
        .lcarb_dtcm__mem_re_o                           (lcarb_dtcm__mem_re),
        .lcarb_dtcm__mem_raddr_o                        (lcarb_dtcm__mem_raddr),
        .dtcm_lcarb__mem_rdata_act_i                    (dtcm_lcarb__mem_rdata_act),
        .dtcm_lcarb__mem_rdata_i                        (dtcm_lcarb__mem_rdata),
        .lcarb_dtcm__mem_we_o                           (lcarb_dtcm__mem_we),
        .lcarb_dtcm__mem_waddr_o                        (lcarb_dtcm__mem_waddr),
        .lcarb_dtcm__mem_wdata_o                        (lcarb_dtcm__mem_wdata),
        .lcarb_dtcm__mem_wstrb_o                        (lcarb_dtcm__mem_wstrb),
        .dtcm_lcarb__mem_atom_ready_i                   (dtcm_lcarb__mem_atom_ready),
        .lcarb_clint__ndma_intr_o                       (lcarb_clint__ndma_intr),
        .lcarb_clint__slv_wr_intr_o                     (lcarb_clint__slv_wr_intr),
        .lcarb_clint__slv_rd_intr_o                     (lcarb_clint__slv_rd_intr),
        .lcarb_clint__slv_swap_intr_o                   (lcarb_clint__slv_swap_intr),
        .ndma_cmd_op_o                                  (ndma_cmd_op_o),
        .ndma_cmd_id_o                                  (ndma_cmd_id_o),
        .ndma_cmd_size_o                                (ndma_cmd_size_o),
        .ndma_cmd_lcaddr_o                              (ndma_cmd_lcaddr_o),
        .ndma_cmd_rtaddr_o                              (ndma_cmd_rtaddr_o),
        .ndma_cmd_destx_o                               (ndma_cmd_destx_o),
        .ndma_cmd_desty_o                               (ndma_cmd_desty_o),
        .ndma_cmd_valid_o                               (ndma_cmd_valid_o),
        .ndma_cmd_ready_i                               (ndma_cmd_ready_i),

        .ndma_tx_done_id_i                              (ndma_tx_done_id_i),
        .ndma_tx_done_i                                 (ndma_tx_done_i),
        .ndma_rx_done_id_i                              (ndma_rx_done_id_i),
        .ndma_rx_done_i                                 (ndma_rx_done_i),

        .ndma_mem_re_i                                  (ndma_mem_re_i),
        .ndma_mem_raddr_i                               (ndma_mem_raddr_i),
        .ndma_mem_rdata_o                               (ndma_mem_rdata_o),
        .ndma_mem_rdata_act_o                           (ndma_mem_rdata_act_o),
        .ndma_mem_we_i                                  (ndma_mem_we_i),
        .ndma_mem_waddr_i                               (ndma_mem_waddr_i),
        .ndma_mem_wdata_i                               (ndma_mem_wdata_i),
        .ndma_mem_wstrb_i                               (ndma_mem_wstrb_i),
        .ndma_mem_atom_ready_o                          (ndma_mem_atom_ready_o),
        .csr_hpu_id_i                                   (sys_hpu__id_i),
        .dtcm_lcarb__node_map_i                         (dtcm_lcarb__node_map),
        .dtcm_lcarb__mem_map_i                          (dtcm_lcarb__mem_map),
        .safemd_ndma_single_cmd_i                       (safemd_ndma_single_cmd)
    );

    hpu_dm # (
        .NrHarts          (1),
        .BusWidth         (32),
        .NrDM_W           (1),
        .SelectableHarts  (1)
    ) hpu_dm_inst (
        .tck_i                                          (tck_i),
        .trst_ni                                        (trst_ni),
        .clk_i                                          (clk_i),
        .rst_ni                                         (rst_debug_i),

        .testmode_i                                     (1'b0),
        .dm_rst__ndmreset_o                             (dm_rst__ndmreset_o),
        .dm_ctrl__dmactive_o                            (dm_ctrl__dmactive),
        .dm_ctrl__halt_req_o                            (dm_ctrl__req_halt),
        .dm_ctrl__resume_req_o                          (dm_ctrl__req_resume),
        .dm_ctrl__req_resethalt_o                       (dm_ctrl__req_setrsthalt),
        .dm_ctrl__cmd_valid_o                           (dm_ctrl__start_cmd),
        .ctrl_dm__unavailable_i                         (ctrl_dm__unavailable),
        .ctrl_dm__hartinfo_i                            (ctrl_dm__hartinfo),

        .darb_dm__req_i                                 (darb_dm__req),
        .darb_dm__we_i                                  (darb_dm__we),
        .darb_dm__addr_i                                (darb_dm__addr),
        .darb_dm__be_i                                  (4'hf),
        .darb_dm__wdata_i                               (darb_dm__wdata),
        .dm_darb__rdata_o                               (dm_darb__rdata),

        .dm_dtcm__sba_req_o                             (dm_dtcm__sba_req),
        .dm_dtcm__sba_addr_o                            (dm_dtcm__sba_addr),
        .dm_dtcm__sba_we_o                              (dm_dtcm__sba_we),
        .dm_dtcm__sba_wdata_o                           (dm_dtcm__sba_wdata),
        .dm_dtcm__sba_be_o                              (dm_dtcm__sba_be),
        .dtcm_dm__sba_gnt_i                             (dtcm_dm__sba_gnt),
        .dtcm_dm__sba_rdata_i                           (dtcm_dm__sba_rdata),
        .dtcm_dm__sba_rdata_act_i                       (dtcm_dm__sba_rdata_act),
        .dmi_req_valid_i                                (dmi_req_valid_i),
        .dmi_req_ready_o                                (dmi_req_ready_o),
        .dmi_req_i                                      (dmi_req_i),
        .dmi_resp_valid_o                               (dmi_resp_valid_o),
        .dmi_resp_ready_i                               (dmi_resp_ready_i),
        .dmi_resp_o                                     (dmi_resp_o),
        .dmi_dmid_i                                     (dmi_dmid_i)
    );
//======================================================================================================================
// probe signals
//======================================================================================================================

endmodule : hpu
