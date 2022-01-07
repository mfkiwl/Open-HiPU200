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
module hpu_pipeline (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   sys_hpu__restart_i,
    input   logic                                   sys_hpu__mode_single_step_i,
    input   logic                                   sys_hpu__mode_scalar_i,
    input   logic                                   sys_hpu__mode_super_scalar_i,
    input   pc_t                                    sys_hpu__init_pc_i,
    output  logic                                   hpu_sys__wfi_act_o,
    input   csr_mip_t                               clint_ctrl__intr_act_i,
    input   logic                                   dm_ctrl__req_halt_i,
    input   logic                                   dm_ctrl__req_resume_i,
    input   logic                                   dm_ctrl__req_setrsthalt_i,
    input   logic                                   dm_ctrl__start_cmd_i,
    output  logic                                   ctrl_dm__status_halted_o,
    output  logic                                   ctrl_dm__status_running_o,
    output  logic                                   ctrl_dm__status_havereset_o,
    output  logic                                   ctrl_dm__unavailable_o,
    output  data_t                                  ctrl_dm__hartinfo_o,
    output  logic                                   darb_dm__req_o,
    output  logic                                   darb_dm__we_o,
    output  pc_t                                    darb_dm__addr_o,
    output  data_t                                  darb_dm__wdata_o,
    input   data_t                                  dm_darb__rdata_i,
    output  logic                                   if_ic__npc_en_o,
    output  pc_t                                    if_ic__npc_o,
    input   logic                                   ic_if__suc_i,
    input   inst_t[INST_FETCH_PARAL-1 : 0]          ic_if__inst_i,
    output  logic                                   lsu_dc__wr_en_o,
    output  pc_t                                    lsu_dc__waddr_o,
    input   logic                                   dc_lsu__wr_suc_i,
    output  data_t                                  lsu_dc__wdata_o,
    output  data_strobe_t                           lsu_dc__wstrb_o,
    output  logic                                   lsu_dc__rd_en_o,
    output  pc_t                                    lsu_dc__raddr_o,
    input   logic                                   dc_lsu__rd_suc_i,
    input   data_t                                  dc_lsu__rdata_i,
    output  logic                                   lsu_dtcm__wr_en_o,
    output  logic                                   lsu_dtcm__wr_rls_lock_o,
    output  pc_t                                    lsu_dtcm__waddr_o,
    input   logic                                   dtcm_lsu__wr_suc_i,
    output  data_t                                  lsu_dtcm__wdata_o,
    output  data_strobe_t                           lsu_dtcm__wstrb_o,
    output  logic                                   lsu_dtcm__rd_en_o,
    output  logic                                   lsu_dtcm__rd_acq_lock_o,
    output  pc_t                                    lsu_dtcm__raddr_o,
    input   logic                                   dtcm_lsu__rd_suc_i,
    input   data_t                                  dtcm_lsu__rdata_i,
    output  logic                                   lsu_clint__wr_en_o,
    output  pc_t                                    lsu_clint__waddr_o,
    output  data_t                                  lsu_clint__wdata_o,
    output  data_strobe_t                           lsu_clint__wstrb_o,
    output  logic                                   lsu_clint__rd_en_o,
    output  pc_t                                    lsu_clint__raddr_o,
    input   data_t                                  clint_lsu__rdata_i,
    output  logic                                   lsu_lmrw__wr_en_o,
    output  pc_t                                    lsu_lmrw__waddr_o,
    input   logic                                   lmrw_lsu__wr_suc_i,
    output  data_t                                  lsu_lmrw__wdata_o,
    output  data_strobe_t                           lsu_lmrw__wstrb_o,
    output  logic                                   lsu_lmrw__rd_en_o,
    output  data_t                                  lsu_lmrw__raddr_o,
    input   data_t                                  lmrw_lsu__rdata_i,
    input   logic                                   lmrw_lsu__rd_suc_i,
    output  logic                                   vmu_lmrw__vec_wr_en_o,
    output  logic[LM_ADDR_WTH-1 : 0]                vmu_lmrw__vec_waddr_o,
    output  mtx_t[VEC_SIZE-1 : 0]                   vmu_lmrw__vec_wdata_o,
    output  logic                                   vmu_lmrw__vec_rd_en_o,
    output  logic[LM_ADDR_WTH-1 : 0]                vmu_lmrw__vec_raddr_o,
    input   mtx_t[VEC_SIZE-1 : 0]                   lmrw_vmu__vec_rdata_i,
    output  logic                                   vmu_lmrw__mtx_rd_en_o,
    output  logic                                   vmu_lmrw__mtx_algup_en_o,
    output  logic                                   vmu_lmrw__mtx_algdn_en_o,
    output  logic[LM_ADDR_WTH-1 : 0]                vmu_lmrw__mtx_raddr_o,
    input   mtx_t[VEC_SIZE-1 : 0]                   lmrw_vmu__mtx_rdata_i,
    output  logic                                   vmu_lmro__mtx_rd_en_o,
    output  logic                                   vmu_lmro__mtx_vm_mode_o,
    output  logic[LM_ADDR_WTH-1 : 0]                vmu_lmro__mtx_raddr_o,
    input   mtx_t[VEC_SIZE-1 : 0]                   lmro_vmu__mtx_rdata_i,
    input   mtx_t[VEC_SIZE*VEC_SIZE_V-1 : 0]        lmro_vmu__mtx_vm_rdata_i,
    output  csr_bus_req_t                           csr_ic__bus_req_o,
    input   csr_bus_rsp_t                           ic_csr__bus_rsp_i,
    output  csr_bus_req_t                           csr_dc__bus_req_o,
    input   csr_bus_rsp_t                           dc_csr__bus_rsp_i,
    output  csr_bus_req_t                           csr_l2c__bus_req_o,
    input   csr_bus_rsp_t                           l2c_csr__bus_rsp_i,
    output  csr_bus_req_t                           csr_lcarb__bus_req_o,
    input   csr_bus_rsp_t                           lcarb_csr__bus_rsp_i,
    output  logic                                   ctrl_ic__flush_req_o,
    input   logic                                   ic_ctrl__flush_done_i,
    input   logic[3:0]                              csr_hpu_id_i,
    input   logic[5:0]                              csr_dm_id_i,
    output  pc_t                                    safemd_arc_pc_o,
    input   logic                                   safemd_rcov_disable_i,
    input   logic                                   safemd_safe_fl_i
);
    logic                                   if_ctrl__inst_fetch_suc;
    logic                                   if_darb__rd_en;
    pc_t                                    if_darb__raddr;
    if_inst_t                               if_id__inst;
    logic                                   if_id__inst_vld;
    update_ckpt_t                           id__ckpt_rcov;
    ckpt_t                                  id__prefet_ckpt;
    logic                                   id_if__inst_rdy;
    alu_inst_t                              id_alu0__inst;
    logic                                   id_alu0__avail;
    sr_status_e                             id_alu0__rs1_ready;
    sr_status_e                             id_alu0__rs2_ready;
    logic                                   id_alu0__inst_vld;
    alu_inst_t                              id_alu1__inst;
    logic                                   id_alu1__avail;
    sr_status_e                             id_alu1__rs1_ready;
    sr_status_e                             id_alu1__rs2_ready;
    logic                                   id_alu1__inst_vld;
    lsu_inst_t[INST_DEC_PARAL-1 : 0]        id_lsu__inst;
    logic[INST_DEC_PARAL-1 : 0]             id_lsu__avail;
    sr_status_e[INST_DEC_PARAL-1 : 0]       id_lsu__rs1_ready;
    sr_status_e[INST_DEC_PARAL-1 : 0]       id_lsu__rs2_ready;
    logic                                   id_lsu__inst_vld;
    mdu_inst_t[INST_DEC_PARAL-1 : 0]        id_mdu__inst;
    logic[INST_DEC_PARAL-1 : 0]             id_mdu__avail;
    sr_status_e[INST_DEC_PARAL-1 : 0]       id_mdu__rs1_ready;
    sr_status_e[INST_DEC_PARAL-1 : 0]       id_mdu__rs2_ready;
    logic                                   id_mdu__inst_vld;
    vmu_inst_t[INST_DEC_PARAL-1 : 0]        id_vmu__inst;
    logic[INST_DEC_PARAL-1 : 0]             id_vmu__avail;
    sr_status_e[INST_DEC_PARAL-1 : 0]       id_vmu__rs1_ready;
    sr_status_e[INST_DEC_PARAL-1 : 0]       id_vmu__rs2_ready;
    logic                                   id_vmu__inst_vld;
    rob_inst_pkg_t[INST_DEC_PARAL-1 : 0]    id_rob__inst_pkg;
    rob_slot_pkg_t                          id_rob__slot_pkg;
    logic                                   id_rob__inst_vld;
    logic[INST_DEC_PARAL-1 : 0]             id_prm__rdst_en;
    phy_sr_index_t[INST_DEC_PARAL-1 : 0]    id_prm__phy_rdst_index;
    ckpt_t[INST_DEC_PARAL-1 : 0]            id_prm__ckpt;
    phy_sr_index_t[INST_DEC_PARAL-1 : 0]    id_prm__phy_rs1_index;
    phy_sr_index_t[INST_DEC_PARAL-1 : 0]    id_prm__phy_rs2_index;
    data_t                                  prf_alu0__rs1_data;
    data_t                                  prf_alu0__rs2_data;
    data_t                                  prf_alu1__rs1_data;
    data_t                                  prf_alu1__rs2_data;
    data_t                                  prf_lsu__rs1_data;
    data_t                                  prf_lsu__rs2_data;
    data_t                                  prf_mdu__rs1_data;
    data_t                                  prf_mdu__rs2_data;
    data_t                                  prf_vmu__rs1_data;
    data_t                                  prf_vmu__rs2_data;
    sr_status_e[INST_DEC_PARAL-1 : 0]       prm_id__phy_rs1_ready;
    sr_status_e[INST_DEC_PARAL-1 : 0]       prm_id__phy_rs2_ready;
    logic                                   alu0_id__inst_rdy;
    logic[ALU_IQ_INDEX : 0]                 alu0_id__left_size;
    phy_sr_index_t                          alu0_prf__rs1_index;
    phy_sr_index_t                          alu0_prf__rs2_index;
    phy_sr_index_t                          alu0_prf__rdst_index;
    logic                                   alu0_prf__rdst_en;
    data_t                                  alu0_prf__rdst_data;
    alu_commit_t                            alu0_rob__commit;
    awake_index_t                           alu0_iq__awake;
    bypass_data_t                           alu0_bypass__data;
    awake_index_t                           alu0_prm__update_prm;
    logic                                   alu1_id__inst_rdy;
    logic[ALU_IQ_INDEX : 0]                 alu1_id__left_size;
    phy_sr_index_t                          alu1_prf__rs1_index;
    phy_sr_index_t                          alu1_prf__rs2_index;
    phy_sr_index_t                          alu1_prf__rdst_index;
    logic                                   alu1_prf__rdst_en;
    data_t                                  alu1_prf__rdst_data;
    alu_commit_t                            alu1_rob__commit;
    awake_index_t                           alu1_iq__awake;
    bypass_data_t                           alu1_bypass__data;
    awake_index_t                           alu1_prm__update_prm;
    logic[MDU_IQ_INDEX : 0]                 mdu_id__left_size;
    logic                                   mdu_id__inst_rdy;
    phy_sr_index_t                          mdu_prf__rs1_index;
    phy_sr_index_t                          mdu_prf__rs2_index;
    phy_sr_index_t                          mdu_prf__rdst_index;
    logic                                   mdu_prf__rdst_en;
    data_t                                  mdu_prf__rdst_data;
    mdu_commit_t                            mdu_rob__commit;
    awake_index_t                           mdu_iq__awake;
    awake_index_t                           mdu_prm__update_prm;
    logic                                   lsu_ctrl__sq_retire_empty;
    logic                                   lsu_id__inst_rdy;
    logic[LSU_IQ_INDEX : 0]                 lsu_id__left_size;
    lsu_commit_t                            lsu_rob__ld_commit;
    lsu_commit_t                            lsu_rob__ste_commit;
    phy_sr_index_t                          lsu_prf__rs1_index;
    phy_sr_index_t                          lsu_prf__rs2_index;
    phy_sr_index_t                          lsu_prf__rdst_index;
    logic                                   lsu_prf__rdst_en;
    data_t                                  lsu_prf__rdst_data;
    mem_wr_req_t                            lsu_mem__wr_req;
    mem_rd_req_t                            lsu_mem__rd_req;
    csr_bus_req_t                           lsu_csr__bus_req;
    awake_index_t                           lsu_iq__awake;
    awake_index_t                           lsu_prm__update_prm;
    logic                                   vmu_id__inst_rdy;
    logic[VMU_IQ_INDEX : 0]                 vmu_id__left_size;
    phy_sr_index_t                          vmu_prf__rs1_index;
    phy_sr_index_t                          vmu_prf__rs2_index;
    vmu_commit_t                            vmu_rob__commit;
    logic                                   csr_vmu_iq_empty;
    logic                                   csr_vmu_rt_empty;
    logic                                   csr_vmu_mtx_idle;
    mem_wr_rsp_t                            mem_lsu__wr_rsp;
    mem_rd_rsp_t                            mem_lsu__rd_rsp;
    logic                                   lsu_darb__wr_en;
    pc_t                                    lsu_darb__waddr;
    data_t                                  lsu_darb__wdata;
    data_strobe_t                           lsu_darb__wstrb;
    logic                                   lsu_darb__rd_en;
    data_t                                  lsu_darb__raddr;
    csr_bus_rsp_t                           csr_lsu__bus_rsp;
    csr_bus_req_t                           csr_clint__bus_req;
    csr_bus_req_t                           csr_ic__bus_req;
    csr_bus_req_t                           csr_dc__bus_req;
    csr_bus_req_t                           csr_l2c__bus_req;
    csr_bus_req_t                           csr_ctrl__bus_req;
    csr_bus_req_t                           csr_trig__bus_req;
    inst_t                                  darb_if__inst;
    logic                                   darb_lsu__wr_suc;
    logic                                   darb_lsu__rd_suc;
    data_t                                  darb_lsu__rdata;
    rob_cmd_t                               rob_ctrl__cmd;
    logic                                   rob_id__inst_rdy;
    logic[ROB_INDEX-1 : 0]                  rob_id__rob_index;
    logic                                   rob_id__rob_flag;
    lsu_retire_t                            rob_lsu__st_retire;
    vmu_retire_t                            rob_vmu__retire;
    update_btb_t                            rob_if__update_btb;
    update_fgpr_t                           rob_if__update_fgpr;
    update_arat_t                           rob_id__update_arat;
    update_ckpt_t[1 : 0]                    rob_id__update_ckpt;
    update_arc_ckpt_t                       rob_id__update_arc_ckpt;
    csr_bus_rsp_t                           trig_csr__bus_rsp;
    logic[INST_DEC_BIT : 0]                 hpm_inst_retire_sum;
    data_t[INST_DEC_PARAL-1 : 0]            hpm_inst_cmt_eve;
    logic                                   ctrl_sys__wfi_act;
    logic                                   ctrl__inst_flush_en;
    logic                                   ctrl_if__normal_fetch_en;
    logic                                   ctrl_if__single_fetch_en;
    logic                                   ctrl_if__update_npc_en;
    pc_t                                    ctrl_if__update_npc;
    logic                                   ctrl_rob__stall_en;
    logic                                   ctrl__hpu_dmode;
    logic                                   ctrl_if__btb_flush_en;
    logic                                   ctrl_if__ras_flush_en;
    logic                                   ctrl_if__fgpr_flush_en;
    logic                                   ctrl_darb__rspd_en;
    rspd_e                                  ctrl_darb__rspd_data;
    logic                                   ctrl_ic__flush_req;
    logic                                   ctrl_dm__unavailable;
    data_t                                  ctrl_dm__hartinfo;
    csr_bus_rsp_t                           ctrl_csr__bus_rsp;
    csr_mie_t                               csr_mie;
    csr_mcause_t                            csr_mcause;
    csr_mip_t                               csr_mip;
    logic                                   csr_excp_req;
    csr_mtvec_t                             csr_mtvec;
    csr_mstatus_t                           csr_mstatus;
    data_t                                  csr_mtval;
    pc_t                                    csr_mepc;
    data_t                                  hpm_mco_arch_eve;
    hpu_if hpu_if_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .ctrl__inst_flush_en_i                          (ctrl__inst_flush_en),
        .id__ckpt_rcov_i                                (id__ckpt_rcov),
        .ctrl_if__normal_fetch_en_i                     (ctrl_if__normal_fetch_en),
        .ctrl_if__single_fetch_en_i                     (ctrl_if__single_fetch_en),
        .if_ctrl__inst_fetch_suc_o                      (if_ctrl__inst_fetch_suc),
        .ctrl_if__update_npc_en_i                       (ctrl_if__update_npc_en),
        .ctrl_if__update_npc_i                          (ctrl_if__update_npc),
        .ctrl_if__btb_flush_en_i                        (ctrl_if__btb_flush_en),
        .ctrl_if__ras_flush_en_i                        (ctrl_if__ras_flush_en),
        .ctrl_if__fgpr_flush_en_i                       (ctrl_if__fgpr_flush_en),
        .if_ic__npc_en_o                                (if_ic__npc_en_o),
        .if_ic__npc_o                                   (if_ic__npc_o),
        .ic_if__suc_i                                   (ic_if__suc_i),
        .ic_if__inst_i                                  (ic_if__inst_i),
        .if_darb__rd_en_o                               (if_darb__rd_en),
        .if_darb__raddr_o                               (if_darb__raddr),
        .darb_if__inst_i                                (darb_if__inst),
        .if_id__inst_o                                  (if_id__inst),
        .if_id__inst_vld_o                              (if_id__inst_vld),
        .id_if__inst_rdy_i                              (id_if__inst_rdy),
        .rob_if__update_btb_i                           (rob_if__update_btb),
        .rob_if__update_fgpr_i                          (rob_if__update_fgpr)
    );
    hpu_id hpu_id_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .ctrl__inst_flush_en_i                          (ctrl__inst_flush_en),
        .id__ckpt_rcov_o                                (id__ckpt_rcov),
        .id__prefet_ckpt_o                              (id__prefet_ckpt),
        .if_id__inst_i                                  (if_id__inst),
        .if_id__inst_vld_i                              (if_id__inst_vld),
        .id_if__inst_rdy_o                              (id_if__inst_rdy),
        .id_alu0__inst_o                                (id_alu0__inst),
        .id_alu0__avail_o                               (id_alu0__avail),
        .id_alu0__rs1_ready_o                           (id_alu0__rs1_ready),
        .id_alu0__rs2_ready_o                           (id_alu0__rs2_ready),
        .id_alu0__inst_vld_o                            (id_alu0__inst_vld),
        .alu0_id__inst_rdy_i                            (alu0_id__inst_rdy),
        .alu0_id__left_size_i                           (alu0_id__left_size),
        .id_alu1__inst_o                                (id_alu1__inst),
        .id_alu1__avail_o                               (id_alu1__avail),
        .id_alu1__rs1_ready_o                           (id_alu1__rs1_ready),
        .id_alu1__rs2_ready_o                           (id_alu1__rs2_ready),
        .id_alu1__inst_vld_o                            (id_alu1__inst_vld),
        .alu1_id__inst_rdy_i                            (alu1_id__inst_rdy),
        .alu1_id__left_size_i                           (alu1_id__left_size),
        .id_lsu__inst_o                                 (id_lsu__inst),
        .id_lsu__avail_o                                (id_lsu__avail),
        .id_lsu__rs1_ready_o                            (id_lsu__rs1_ready),
        .id_lsu__rs2_ready_o                            (id_lsu__rs2_ready),
        .id_lsu__inst_vld_o                             (id_lsu__inst_vld),
        .lsu_id__inst_rdy_i                             (lsu_id__inst_rdy),
        .lsu_id__left_size_i                            (lsu_id__left_size),
        .id_mdu__inst_o                                 (id_mdu__inst),
        .id_mdu__avail_o                                (id_mdu__avail),
        .id_mdu__rs1_ready_o                            (id_mdu__rs1_ready),
        .id_mdu__rs2_ready_o                            (id_mdu__rs2_ready),
        .id_mdu__inst_vld_o                             (id_mdu__inst_vld),
        .mdu_id__inst_rdy_i                             (mdu_id__inst_rdy),
        .mdu_id__left_size_i                            (mdu_id__left_size),
        .id_vmu__inst_o                                 (id_vmu__inst),
        .id_vmu__avail_o                                (id_vmu__avail),
        .id_vmu__rs1_ready_o                            (id_vmu__rs1_ready),
        .id_vmu__rs2_ready_o                            (id_vmu__rs2_ready),
        .id_vmu__inst_vld_o                             (id_vmu__inst_vld),
        .vmu_id__inst_rdy_i                             (vmu_id__inst_rdy),
        .vmu_id__left_size_i                            (vmu_id__left_size),
        .id_rob__inst_pkg_o                             (id_rob__inst_pkg),
        .id_rob__slot_pkg_o                             (id_rob__slot_pkg),
        .id_rob__inst_vld_o                             (id_rob__inst_vld),
        .rob_id__inst_rdy_i                             (rob_id__inst_rdy),
        .rob_id__rob_index_i                            (rob_id__rob_index),
        .rob_id__rob_flag_i                             (rob_id__rob_flag),
        .id_prm__rdst_en_o                              (id_prm__rdst_en),
        .id_prm__phy_rdst_index_o                       (id_prm__phy_rdst_index),
        .id_prm__ckpt_o                                 (id_prm__ckpt),
        .id_prm__phy_rs1_index_o                        (id_prm__phy_rs1_index),
        .prm_id__phy_rs1_ready_i                        (prm_id__phy_rs1_ready),
        .id_prm__phy_rs2_index_o                        (id_prm__phy_rs2_index),
        .prm_id__phy_rs2_ready_i                        (prm_id__phy_rs2_ready),
        .rob_id__update_arat_i                          (rob_id__update_arat),
        .rob_id__update_ckpt_i                          (rob_id__update_ckpt),
        .rob_id__update_arc_ckpt_i                      (rob_id__update_arc_ckpt),
        .safemd_safe_fl_i                               (safemd_safe_fl_i),
        .safemd_rcov_disable_i                          (safemd_rcov_disable_i)
    );
    hpu_prf hpu_prf_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .alu0_prf__rs1_index_i                          (alu0_prf__rs1_index),
        .prf_alu0__rs1_data_o                           (prf_alu0__rs1_data),
        .alu0_prf__rs2_index_i                          (alu0_prf__rs2_index),
        .prf_alu0__rs2_data_o                           (prf_alu0__rs2_data),
        .alu0_prf__rdst_index_i                         (alu0_prf__rdst_index),
        .alu0_prf__rdst_en_i                            (alu0_prf__rdst_en),
        .alu0_prf__rdst_data_i                          (alu0_prf__rdst_data),
        .alu1_prf__rs1_index_i                          (alu1_prf__rs1_index),
        .prf_alu1__rs1_data_o                           (prf_alu1__rs1_data),
        .alu1_prf__rs2_index_i                          (alu1_prf__rs2_index),
        .prf_alu1__rs2_data_o                           (prf_alu1__rs2_data),
        .alu1_prf__rdst_index_i                         (alu1_prf__rdst_index),
        .alu1_prf__rdst_en_i                            (alu1_prf__rdst_en),
        .alu1_prf__rdst_data_i                          (alu1_prf__rdst_data),
        .lsu_prf__rs1_index_i                           (lsu_prf__rs1_index),
        .prf_lsu__rs1_data_o                            (prf_lsu__rs1_data),
        .lsu_prf__rs2_index_i                           (lsu_prf__rs2_index),
        .prf_lsu__rs2_data_o                            (prf_lsu__rs2_data),
        .lsu_prf__rdst_index_i                          (lsu_prf__rdst_index),
        .lsu_prf__rdst_en_i                             (lsu_prf__rdst_en),
        .lsu_prf__rdst_data_i                           (lsu_prf__rdst_data),
        .mdu_prf__rs1_index_i                           (mdu_prf__rs1_index),
        .prf_mdu__rs1_data_o                            (prf_mdu__rs1_data),
        .mdu_prf__rs2_index_i                           (mdu_prf__rs2_index),
        .prf_mdu__rs2_data_o                            (prf_mdu__rs2_data),
        .mdu_prf__rdst_index_i                          (mdu_prf__rdst_index),
        .mdu_prf__rdst_en_i                             (mdu_prf__rdst_en),
        .mdu_prf__rdst_data_i                           (mdu_prf__rdst_data),
        .vmu_prf__rs1_index_i                           (vmu_prf__rs1_index),
        .prf_vmu__rs1_data_o                            (prf_vmu__rs1_data),
        .vmu_prf__rs2_index_i                           (vmu_prf__rs2_index),
        .prf_vmu__rs2_data_o                            (prf_vmu__rs2_data)
    );
    hpu_prm hpu_prm_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .ctrl__inst_flush_en_i                          (ctrl__inst_flush_en),
        .id__ckpt_rcov_i                                (id__ckpt_rcov),
        .id__prefet_ckpt_i                              (id__prefet_ckpt),
        .id_prm__rdst_en_i                              (id_prm__rdst_en),
        .id_prm__phy_rdst_index_i                       (id_prm__phy_rdst_index),
        .id_prm__ckpt_i                                 (id_prm__ckpt),
        .id_prm__phy_rs1_index_i                        (id_prm__phy_rs1_index),
        .prm_id__phy_rs1_ready_o                        (prm_id__phy_rs1_ready),
        .id_prm__phy_rs2_index_i                        (id_prm__phy_rs2_index),
        .prm_id__phy_rs2_ready_o                        (prm_id__phy_rs2_ready),
        .alu0_prm__update_prm_i                         (alu0_prm__update_prm),
        .alu1_prm__update_prm_i                         (alu1_prm__update_prm),
        .mdu_prm__update_prm_i                          (mdu_prm__update_prm),
        .lsu_prm__update_prm_i                          (lsu_prm__update_prm)
    );
    hpu_alu hpu_alu0_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .ctrl__inst_flush_en_i                          (ctrl__inst_flush_en),
        .id__ckpt_rcov_i                                (id__ckpt_rcov),
        .id__prefet_ckpt_i                              (id__prefet_ckpt),
        .id_alu__inst_i                                 (id_alu0__inst),
        .id_alu__avail_i                                (id_alu0__avail),
        .id_alu__rs1_ready_i                            (id_alu0__rs1_ready),
        .id_alu__rs2_ready_i                            (id_alu0__rs2_ready),
        .id_alu__inst_vld_i                             (id_alu0__inst_vld),
        .alu_id__inst_rdy_o                             (alu0_id__inst_rdy),
        .alu_id__left_size_o                            (alu0_id__left_size),
        .alu_prf__rs1_index_o                           (alu0_prf__rs1_index),
        .prf_alu__rs1_data_i                            (prf_alu0__rs1_data),
        .alu_prf__rs2_index_o                           (alu0_prf__rs2_index),
        .prf_alu__rs2_data_i                            (prf_alu0__rs2_data),
        .alu_prf__rdst_index_o                          (alu0_prf__rdst_index),
        .alu_prf__rdst_en_o                             (alu0_prf__rdst_en),
        .alu_prf__rdst_data_o                           (alu0_prf__rdst_data),
        .alu_rob__commit_o                              (alu0_rob__commit),
        .alu_iq__awake_o                                (alu0_iq__awake),
        .alu0_iq__awake_i                               (alu0_iq__awake),
        .alu1_iq__awake_i                               (alu1_iq__awake),
        .mdu_iq__awake_i                                (mdu_iq__awake),
        .lsu_iq__awake_i                                (lsu_iq__awake),
        .alu_bypass__data_o                             (alu0_bypass__data),
        .alu0_bypass__data_i                            (alu0_bypass__data),
        .alu1_bypass__data_i                            (alu1_bypass__data),
        .alu_prm__update_prm_o                          (alu0_prm__update_prm)
    );
    hpu_alu hpu_alu1_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .ctrl__inst_flush_en_i                          (ctrl__inst_flush_en),
        .id__ckpt_rcov_i                                (id__ckpt_rcov),
        .id__prefet_ckpt_i                              (id__prefet_ckpt),
        .id_alu__inst_i                                 (id_alu1__inst),
        .id_alu__avail_i                                (id_alu1__avail),
        .id_alu__rs1_ready_i                            (id_alu1__rs1_ready),
        .id_alu__rs2_ready_i                            (id_alu1__rs2_ready),
        .id_alu__inst_vld_i                             (id_alu1__inst_vld),
        .alu_id__inst_rdy_o                             (alu1_id__inst_rdy),
        .alu_id__left_size_o                            (alu1_id__left_size),
        .alu_prf__rs1_index_o                           (alu1_prf__rs1_index),
        .prf_alu__rs1_data_i                            (prf_alu1__rs1_data),
        .alu_prf__rs2_index_o                           (alu1_prf__rs2_index),
        .prf_alu__rs2_data_i                            (prf_alu1__rs2_data),
        .alu_prf__rdst_index_o                          (alu1_prf__rdst_index),
        .alu_prf__rdst_en_o                             (alu1_prf__rdst_en),
        .alu_prf__rdst_data_o                           (alu1_prf__rdst_data),
        .alu_rob__commit_o                              (alu1_rob__commit),
        .alu_iq__awake_o                                (alu1_iq__awake),
        .alu0_iq__awake_i                               (alu0_iq__awake),
        .alu1_iq__awake_i                               (alu1_iq__awake),
        .mdu_iq__awake_i                                (mdu_iq__awake),
        .lsu_iq__awake_i                                (lsu_iq__awake),
        .alu_bypass__data_o                             (alu1_bypass__data),
        .alu0_bypass__data_i                            (alu0_bypass__data),
        .alu1_bypass__data_i                            (alu1_bypass__data),
        .alu_prm__update_prm_o                          (alu1_prm__update_prm)
    );
    hpu_mdu hpu_mdu_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .ctrl__inst_flush_en_i                          (ctrl__inst_flush_en),
        .id__ckpt_rcov_i                                (id__ckpt_rcov),
        .id__prefet_ckpt_i                              (id__prefet_ckpt),
        .id_mdu__inst_i                                 (id_mdu__inst),
        .id_mdu__avail_i                                (id_mdu__avail),
        .id_mdu__rs1_ready_i                            (id_mdu__rs1_ready),
        .id_mdu__rs2_ready_i                            (id_mdu__rs2_ready),
        .mdu_id__left_size_o                            (mdu_id__left_size),
        .id_mdu__inst_vld_i                             (id_mdu__inst_vld),
        .mdu_id__inst_rdy_o                             (mdu_id__inst_rdy),
        .mdu_prf__rs1_index_o                           (mdu_prf__rs1_index),
        .prf_mdu__rs1_data_i                            (prf_mdu__rs1_data),
        .mdu_prf__rs2_index_o                           (mdu_prf__rs2_index),
        .prf_mdu__rs2_data_i                            (prf_mdu__rs2_data),
        .mdu_prf__rdst_index_o                          (mdu_prf__rdst_index),
        .mdu_prf__rdst_en_o                             (mdu_prf__rdst_en),
        .mdu_prf__rdst_data_o                           (mdu_prf__rdst_data),
        .mdu_rob__commit_o                              (mdu_rob__commit),
        .mdu_iq__awake_o                                (mdu_iq__awake),
        .alu0_iq__awake_i                               (alu0_iq__awake),
        .alu1_iq__awake_i                               (alu1_iq__awake),
        .mdu_iq__awake_i                                (mdu_iq__awake),
        .lsu_iq__awake_i                                (lsu_iq__awake),
        .alu0_bypass__data_i                            (alu0_bypass__data),
        .alu1_bypass__data_i                            (alu1_bypass__data),
        .mdu_prm__update_prm_o                          (mdu_prm__update_prm)
    );
    hpu_lsu hpu_lsu_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .ctrl__inst_flush_en_i                          (ctrl__inst_flush_en),
        .id__ckpt_rcov_i                                (id__ckpt_rcov),
        .lsu_ctrl__sq_retire_empty_o                    (lsu_ctrl__sq_retire_empty),
        .id__prefet_ckpt_i                              (id__prefet_ckpt),
        .id_lsu__inst_i                                 (id_lsu__inst),
        .id_lsu__avail_i                                (id_lsu__avail),
        .id_lsu__rs1_ready_i                            (id_lsu__rs1_ready),
        .id_lsu__rs2_ready_i                            (id_lsu__rs2_ready),
        .id_lsu__inst_vld_i                             (id_lsu__inst_vld),
        .lsu_id__inst_rdy_o                             (lsu_id__inst_rdy),
        .lsu_id__left_size_o                            (lsu_id__left_size),
        .lsu_rob__ld_commit_o                           (lsu_rob__ld_commit),
        .lsu_rob__ste_commit_o                          (lsu_rob__ste_commit),
        .rob_lsu__st_retire_i                           (rob_lsu__st_retire),
        .lsu_prf__rs1_index_o                           (lsu_prf__rs1_index),
        .prf_lsu__rs1_data_i                            (prf_lsu__rs1_data),
        .lsu_prf__rs2_index_o                           (lsu_prf__rs2_index),
        .prf_lsu__rs2_data_i                            (prf_lsu__rs2_data),
        .lsu_prf__rdst_index_o                          (lsu_prf__rdst_index),
        .lsu_prf__rdst_en_o                             (lsu_prf__rdst_en),
        .lsu_prf__rdst_data_o                           (lsu_prf__rdst_data),
        .lsu_mem__wr_req_o                              (lsu_mem__wr_req),
        .mem_lsu__wr_rsp_i                              (mem_lsu__wr_rsp),
        .lsu_mem__rd_req_o                              (lsu_mem__rd_req),
        .mem_lsu__rd_rsp_i                              (mem_lsu__rd_rsp),
        .lsu_csr__bus_req_o                             (lsu_csr__bus_req),
        .csr_lsu__bus_rsp_i                             (csr_lsu__bus_rsp),
        .lsu_iq__awake_o                                (lsu_iq__awake),
        .alu0_iq__awake_i                               (alu0_iq__awake),
        .alu1_iq__awake_i                               (alu1_iq__awake),
        .mdu_iq__awake_i                                (mdu_iq__awake),
        .alu0_bypass__data_i                            (alu0_bypass__data),
        .alu1_bypass__data_i                            (alu1_bypass__data),
        .lsu_prm__update_prm_o                          (lsu_prm__update_prm)
    );
    hpu_vmu hpu_vmu_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .ctrl__inst_flush_en_i                          (ctrl__inst_flush_en),
        .id__ckpt_rcov_i                                (id__ckpt_rcov),
        .id__prefet_ckpt_i                              (id__prefet_ckpt),
        .id_vmu__inst_i                                 (id_vmu__inst),
        .id_vmu__avail_i                                (id_vmu__avail),
        .id_vmu__rs1_ready_i                            (id_vmu__rs1_ready),
        .id_vmu__rs2_ready_i                            (id_vmu__rs2_ready),
        .id_vmu__inst_vld_i                             (id_vmu__inst_vld),
        .vmu_id__inst_rdy_o                             (vmu_id__inst_rdy),
        .vmu_id__left_size_o                            (vmu_id__left_size),
        .vmu_prf__rs1_index_o                           (vmu_prf__rs1_index),
        .prf_vmu__rs1_data_i                            (prf_vmu__rs1_data),
        .vmu_prf__rs2_index_o                           (vmu_prf__rs2_index),
        .prf_vmu__rs2_data_i                            (prf_vmu__rs2_data),
        .vmu_rob__commit_o                              (vmu_rob__commit),
        .rob_vmu__retire_i                              (rob_vmu__retire),
        .vmu_lmrw__vec_wr_en_o                          (vmu_lmrw__vec_wr_en_o),
        .vmu_lmrw__vec_waddr_o                          (vmu_lmrw__vec_waddr_o),
        .vmu_lmrw__vec_wdata_o                          (vmu_lmrw__vec_wdata_o),
        .vmu_lmrw__vec_rd_en_o                          (vmu_lmrw__vec_rd_en_o),
        .vmu_lmrw__vec_raddr_o                          (vmu_lmrw__vec_raddr_o),
        .lmrw_vmu__vec_rdata_i                          (lmrw_vmu__vec_rdata_i),
        .vmu_lmrw__mtx_rd_en_o                          (vmu_lmrw__mtx_rd_en_o),
        .vmu_lmrw__mtx_algup_en_o                       (vmu_lmrw__mtx_algup_en_o),
        .vmu_lmrw__mtx_algdn_en_o                       (vmu_lmrw__mtx_algdn_en_o),
        .vmu_lmrw__mtx_raddr_o                          (vmu_lmrw__mtx_raddr_o),
        .lmrw_vmu__mtx_rdata_i                          (lmrw_vmu__mtx_rdata_i),
        .vmu_lmro__mtx_rd_en_o                          (vmu_lmro__mtx_rd_en_o),
        .vmu_lmro__mtx_vm_mode_o                        (vmu_lmro__mtx_vm_mode_o),
        .vmu_lmro__mtx_raddr_o                          (vmu_lmro__mtx_raddr_o),
        .lmro_vmu__mtx_rdata_i                          (lmro_vmu__mtx_rdata_i),
        .lmro_vmu__mtx_vm_rdata_i                       (lmro_vmu__mtx_vm_rdata_i),
        .alu0_iq__awake_i                               (alu0_iq__awake),
        .alu1_iq__awake_i                               (alu1_iq__awake),
        .lsu_iq__awake_i                                (lsu_iq__awake),
        .mdu_iq__awake_i                                (mdu_iq__awake),
        .csr_vmu_iq_empty_o                             (csr_vmu_iq_empty),
        .csr_vmu_rt_empty_o                             (csr_vmu_rt_empty),
        .csr_vmu_mtx_idle_o                             (csr_vmu_mtx_idle)
    );
    hpu_mem hpu_mem_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .lsu_mem__wr_req_i                              (lsu_mem__wr_req),
        .mem_lsu__wr_rsp_o                              (mem_lsu__wr_rsp),
        .lsu_mem__rd_req_i                              (lsu_mem__rd_req),
        .mem_lsu__rd_rsp_o                              (mem_lsu__rd_rsp),
        .lsu_dc__wr_en_o                                (lsu_dc__wr_en_o),
        .lsu_dc__waddr_o                                (lsu_dc__waddr_o),
        .dc_lsu__wr_suc_i                               (dc_lsu__wr_suc_i),
        .lsu_dc__wdata_o                                (lsu_dc__wdata_o),
        .lsu_dc__wstrb_o                                (lsu_dc__wstrb_o),
        .lsu_dc__rd_en_o                                (lsu_dc__rd_en_o),
        .lsu_dc__raddr_o                                (lsu_dc__raddr_o),
        .dc_lsu__rd_suc_i                               (dc_lsu__rd_suc_i),
        .dc_lsu__rdata_i                                (dc_lsu__rdata_i),
        .lsu_dtcm__wr_en_o                              (lsu_dtcm__wr_en_o),
        .lsu_dtcm__wr_rls_lock_o                        (lsu_dtcm__wr_rls_lock_o),
        .dtcm_lsu__wr_suc_i                             (dtcm_lsu__wr_suc_i),
        .lsu_dtcm__waddr_o                              (lsu_dtcm__waddr_o),
        .lsu_dtcm__wdata_o                              (lsu_dtcm__wdata_o),
        .lsu_dtcm__wstrb_o                              (lsu_dtcm__wstrb_o),
        .lsu_dtcm__rd_en_o                              (lsu_dtcm__rd_en_o),
        .lsu_dtcm__rd_acq_lock_o                        (lsu_dtcm__rd_acq_lock_o),
        .dtcm_lsu__rd_suc_i                             (dtcm_lsu__rd_suc_i),
        .lsu_dtcm__raddr_o                              (lsu_dtcm__raddr_o),
        .dtcm_lsu__rdata_i                              (dtcm_lsu__rdata_i),
        .lsu_lmrw__wr_en_o                              (lsu_lmrw__wr_en_o),
        .lsu_lmrw__waddr_o                              (lsu_lmrw__waddr_o),
        .lmrw_lsu__wr_suc_i                             (lmrw_lsu__wr_suc_i),
        .lsu_lmrw__wdata_o                              (lsu_lmrw__wdata_o),
        .lsu_lmrw__wstrb_o                              (lsu_lmrw__wstrb_o),
        .lsu_lmrw__rd_en_o                              (lsu_lmrw__rd_en_o),
        .lsu_lmrw__raddr_o                              (lsu_lmrw__raddr_o),
        .lmrw_lsu__rdata_i                              (lmrw_lsu__rdata_i),
        .lmrw_lsu__rd_suc_i                             (lmrw_lsu__rd_suc_i),
        .lsu_clint__wr_en_o                             (lsu_clint__wr_en_o),
        .lsu_clint__waddr_o                             (lsu_clint__waddr_o),
        .lsu_clint__wdata_o                             (lsu_clint__wdata_o),
        .lsu_clint__wstrb_o                             (lsu_clint__wstrb_o),
        .lsu_clint__rd_en_o                             (lsu_clint__rd_en_o),
        .lsu_clint__raddr_o                             (lsu_clint__raddr_o),
        .clint_lsu__rdata_i                             (clint_lsu__rdata_i),
        .lsu_darb__wr_en_o                              (lsu_darb__wr_en),
        .lsu_darb__waddr_o                              (lsu_darb__waddr),
        .darb_lsu__wr_suc_i                             (darb_lsu__wr_suc),
        .lsu_darb__wdata_o                              (lsu_darb__wdata),
        .lsu_darb__wstrb_o                              (lsu_darb__wstrb),
        .lsu_darb__rd_en_o                              (lsu_darb__rd_en),
        .lsu_darb__raddr_o                              (lsu_darb__raddr),
        .darb_lsu__rd_suc_i                             (darb_lsu__rd_suc),
        .darb_lsu__rdata_i                              (darb_lsu__rdata)
    );
    hpu_csr hpu_csr_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .lsu_csr__bus_req_i                             (lsu_csr__bus_req),
        .csr_lsu__bus_rsp_o                             (csr_lsu__bus_rsp),
        .csr_ic__bus_req_o                              (csr_ic__bus_req_o),
        .ic_csr__bus_rsp_i                              (ic_csr__bus_rsp_i),
        .csr_dc__bus_req_o                              (csr_dc__bus_req_o),
        .dc_csr__bus_rsp_i                              (dc_csr__bus_rsp_i),
        .csr_l2c__bus_req_o                             (csr_l2c__bus_req_o),
        .l2c_csr__bus_rsp_i                             (l2c_csr__bus_rsp_i),
        .csr_ctrl__bus_req_o                            (csr_ctrl__bus_req),
        .ctrl_csr__bus_rsp_i                            (ctrl_csr__bus_rsp),
        .csr_lcarb__bus_req_o                           (csr_lcarb__bus_req_o),
        .lcarb_csr__bus_rsp_i                           (lcarb_csr__bus_rsp_i),
        .csr_trig__bus_req_o                            (csr_trig__bus_req),
        .trig_csr__bus_rsp_i                            (trig_csr__bus_rsp),
        .hpm_inst_retire_sum_i                          (hpm_inst_retire_sum),
        .hpm_inst_cmt_eve_i                             (hpm_inst_cmt_eve),
        .hpm_mco_arch_eve_i                             (hpm_mco_arch_eve),
        .csr_vmu_iq_empty_i                             (csr_vmu_iq_empty),
        .csr_vmu_rt_empty_i                             (csr_vmu_rt_empty),
        .csr_vmu_mtx_idle_i                             (csr_vmu_mtx_idle),
        .csr_hpu_id_i                                   (csr_hpu_id_i),
        .csr_dm_id_i                                    (csr_dm_id_i)
    );
    hpu_darb hpu_darb_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .ctrl_darb__rspd_en_i                           (ctrl_darb__rspd_en),
        .ctrl_darb__rspd_data_i                         (ctrl_darb__rspd_data),
        .if_darb__rd_en_i                               (if_darb__rd_en),
        .if_darb__raddr_i                               (if_darb__raddr),
        .darb_if__inst_o                                (darb_if__inst),
        .lsu_darb__wr_en_i                              (lsu_darb__wr_en),
        .lsu_darb__waddr_i                              (lsu_darb__waddr),
        .darb_lsu__wr_suc_o                             (darb_lsu__wr_suc),
        .lsu_darb__wdata_i                              (lsu_darb__wdata),
        .lsu_darb__wstrb_i                              (lsu_darb__wstrb),
        .lsu_darb__rd_en_i                              (lsu_darb__rd_en),
        .lsu_darb__raddr_i                              (lsu_darb__raddr),
        .darb_lsu__rd_suc_o                             (darb_lsu__rd_suc),
        .darb_lsu__rdata_o                              (darb_lsu__rdata),
        .darb_dm__req_o                                 (darb_dm__req_o),
        .darb_dm__we_o                                  (darb_dm__we_o),
        .darb_dm__addr_o                                (darb_dm__addr_o),
        .darb_dm__wdata_o                               (darb_dm__wdata_o),
        .dm_darb__rdata_i                               (dm_darb__rdata_i)
    );
    hpu_rob hpu_rob_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .ctrl__inst_flush_en_i                          (ctrl__inst_flush_en),
        .id__ckpt_rcov_i                                (id__ckpt_rcov),
        .ctrl_rob__stall_en_i                           (ctrl_rob__stall_en),
        .ctrl__hpu_dmode_i                              (ctrl__hpu_dmode),
        .rob_ctrl__cmd_o                                (rob_ctrl__cmd),
        .id_rob__inst_pkg_i                             (id_rob__inst_pkg),
        .id_rob__slot_pkg_i                             (id_rob__slot_pkg),
        .id_rob__inst_vld_i                             (id_rob__inst_vld),
        .rob_id__inst_rdy_o                             (rob_id__inst_rdy),
        .rob_id__rob_index_o                            (rob_id__rob_index),
        .rob_id__rob_flag_o                             (rob_id__rob_flag),
        .alu0_rob__commit_i                             (alu0_rob__commit),
        .alu1_rob__commit_i                             (alu1_rob__commit),
        .lsu_rob__ld_commit_i                           (lsu_rob__ld_commit),
        .lsu_rob__ste_commit_i                          (lsu_rob__ste_commit),
        .vmu_rob__commit_i                              (vmu_rob__commit),
        .mdu_rob__commit_i                              (mdu_rob__commit),
        .rob_lsu__st_retire_o                           (rob_lsu__st_retire),
        .rob_vmu__retire_o                              (rob_vmu__retire),
        .rob_if__update_btb_o                           (rob_if__update_btb),
        .rob_if__update_fgpr_o                          (rob_if__update_fgpr),
        .rob_id__update_arat_o                          (rob_id__update_arat),
        .rob_id__update_ckpt_o                          (rob_id__update_ckpt),
        .rob_id__update_arc_ckpt_o                      (rob_id__update_arc_ckpt),
        .csr_trig__bus_req_i                            (csr_trig__bus_req),
        .trig_csr__bus_rsp_o                            (trig_csr__bus_rsp),
        .csr_mie_i                                      (csr_mie),
        .csr_mcause_i                                   (csr_mcause),
        .csr_mip_i                                      (csr_mip),
        .csr_excp_req_i                                 (csr_excp_req),
        .hpm_inst_retire_sum_o                          (hpm_inst_retire_sum),
        .hpm_inst_cmt_eve_o                             (hpm_inst_cmt_eve),
        .safemd_rcov_disable_i                          (safemd_rcov_disable_i)
    );
    hpu_ctrl hpu_ctrl_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .sys_hpu__restart_i                             (sys_hpu__restart_i),
        .sys_hpu__mode_single_step_i                    (sys_hpu__mode_single_step_i),
        .sys_hpu__mode_scalar_i                         (sys_hpu__mode_scalar_i),
        .sys_hpu__mode_super_scalar_i                   (sys_hpu__mode_super_scalar_i),
        .sys_hpu__init_pc_i                             (sys_hpu__init_pc_i),
        .hpu_sys__wfi_act_o                             (hpu_sys__wfi_act_o),
        .rob_ctrl__cmd_i                                (rob_ctrl__cmd),
        .clint_ctrl__intr_act_i                         (clint_ctrl__intr_act_i),
        .ctrl__inst_flush_en_o                          (ctrl__inst_flush_en),
        .ctrl_if__normal_fetch_en_o                     (ctrl_if__normal_fetch_en),
        .ctrl_if__single_fetch_en_o                     (ctrl_if__single_fetch_en),
        .if_ctrl__inst_fetch_suc_i                      (if_ctrl__inst_fetch_suc),
        .ctrl_if__update_npc_en_o                       (ctrl_if__update_npc_en),
        .ctrl_if__update_npc_o                          (ctrl_if__update_npc),
        .ctrl_rob__stall_en_o                           (ctrl_rob__stall_en),
        .ctrl__hpu_dmode_o                              (ctrl__hpu_dmode),
        .ctrl_if__btb_flush_en_o                        (ctrl_if__btb_flush_en),
        .ctrl_if__ras_flush_en_o                        (ctrl_if__ras_flush_en),
        .ctrl_if__fgpr_flush_en_o                       (ctrl_if__fgpr_flush_en),
        .ctrl_ic__flush_req_o                           (ctrl_ic__flush_req_o),
        .ic_ctrl__flush_done_i                          (ic_ctrl__flush_done_i),
        .lsu_ctrl__sq_retire_empty_i                    (lsu_ctrl__sq_retire_empty),
        .dm_ctrl__req_halt_i                            (dm_ctrl__req_halt_i),
        .dm_ctrl__req_resume_i                          (dm_ctrl__req_resume_i),
        .dm_ctrl__req_setrsthalt_i                      (dm_ctrl__req_setrsthalt_i),
        .dm_ctrl__start_cmd_i                           (dm_ctrl__start_cmd_i),
        .ctrl_dm__status_halted_o                       (ctrl_dm__status_halted_o),
        .ctrl_dm__status_running_o                      (ctrl_dm__status_running_o),
        .ctrl_dm__status_havereset_o                    (ctrl_dm__status_havereset_o),
        .ctrl_dm__unavailable_o                         (ctrl_dm__unavailable_o),
        .ctrl_dm__hartinfo_o                            (ctrl_dm__hartinfo_o),
        .ctrl_darb__rspd_en_o                           (ctrl_darb__rspd_en),
        .ctrl_darb__rspd_data_o                         (ctrl_darb__rspd_data),
        .csr_ctrl__bus_req_i                            (csr_ctrl__bus_req),
        .ctrl_csr__bus_rsp_o                            (ctrl_csr__bus_rsp),
        .csr_mie_o                                      (csr_mie),
        .csr_mcause_o                                   (csr_mcause),
        .csr_mip_o                                      (csr_mip),
        .csr_excp_req_o                                 (csr_excp_req),
        .csr_mtvec_o                                    (csr_mtvec),
        .csr_mstatus_o                                  (csr_mstatus),
        .csr_mtval_o                                    (csr_mtval),
        .csr_mepc_o                                     (csr_mepc),
        .hpm_mco_arch_eve_o                             (hpm_mco_arch_eve),
        .safemd_arc_pc_o                                (safemd_arc_pc_o)
    );
endmodule : hpu_pipeline
