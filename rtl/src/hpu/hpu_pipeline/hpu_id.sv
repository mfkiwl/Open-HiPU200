`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_id (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   ctrl__inst_flush_en_i,
    output  update_ckpt_t                           id__ckpt_rcov_o,
    output  ckpt_t                                  id__prefet_ckpt_o,
    input   if_inst_t                               if_id__inst_i,
    input   logic                                   if_id__inst_vld_i,
    output  logic                                   id_if__inst_rdy_o,
    output  alu_inst_t                              id_alu0__inst_o,
    output  logic                                   id_alu0__avail_o,
    output  sr_status_e                             id_alu0__rs1_ready_o,
    output  sr_status_e                             id_alu0__rs2_ready_o,
    output  logic                                   id_alu0__inst_vld_o,
    input   logic                                   alu0_id__inst_rdy_i,
    input   logic[ALU_IQ_INDEX : 0]                 alu0_id__left_size_i,
    output  alu_inst_t                              id_alu1__inst_o,
    output  logic                                   id_alu1__avail_o,
    output  sr_status_e                             id_alu1__rs1_ready_o,
    output  sr_status_e                             id_alu1__rs2_ready_o,
    output  logic                                   id_alu1__inst_vld_o,
    input   logic                                   alu1_id__inst_rdy_i,
    input   logic[ALU_IQ_INDEX : 0]                 alu1_id__left_size_i,
    output  lsu_inst_t[INST_DEC_PARAL-1 : 0]        id_lsu__inst_o,
    output  logic[INST_DEC_PARAL-1 : 0]             id_lsu__avail_o,
    output  sr_status_e[INST_DEC_PARAL-1 : 0]       id_lsu__rs1_ready_o,
    output  sr_status_e[INST_DEC_PARAL-1 : 0]       id_lsu__rs2_ready_o,
    output  logic                                   id_lsu__inst_vld_o,
    input   logic                                   lsu_id__inst_rdy_i,
    input   logic[LSU_IQ_INDEX : 0]                 lsu_id__left_size_i,
    output  mdu_inst_t[INST_DEC_PARAL-1 : 0]        id_mdu__inst_o,
    output  logic[INST_DEC_PARAL-1 : 0]             id_mdu__avail_o,
    output  sr_status_e[INST_DEC_PARAL-1 : 0]       id_mdu__rs1_ready_o,
    output  sr_status_e[INST_DEC_PARAL-1 : 0]       id_mdu__rs2_ready_o,
    output  logic                                   id_mdu__inst_vld_o,
    input   logic                                   mdu_id__inst_rdy_i,
    input   logic[MDU_IQ_INDEX : 0]                 mdu_id__left_size_i,
    output  vmu_inst_t[INST_DEC_PARAL-1 : 0]        id_vmu__inst_o,
    output  logic[INST_DEC_PARAL-1 : 0]             id_vmu__avail_o,
    output  sr_status_e[INST_DEC_PARAL-1 : 0]       id_vmu__rs1_ready_o,
    output  sr_status_e[INST_DEC_PARAL-1 : 0]       id_vmu__rs2_ready_o,
    output  logic                                   id_vmu__inst_vld_o,
    input   logic                                   vmu_id__inst_rdy_i,
    input   logic[VMU_IQ_INDEX : 0]                 vmu_id__left_size_i,
    output  rob_inst_pkg_t[INST_DEC_PARAL-1 : 0]    id_rob__inst_pkg_o,
    output  rob_slot_pkg_t                          id_rob__slot_pkg_o,
    output  logic                                   id_rob__inst_vld_o,
    input   logic                                   rob_id__inst_rdy_i,
    input   logic[ROB_INDEX-1 : 0]                  rob_id__rob_index_i,
    input   logic                                   rob_id__rob_flag_i,
    output  logic[INST_DEC_PARAL-1 : 0]             id_prm__rdst_en_o,
    output  phy_sr_index_t[INST_DEC_PARAL-1 : 0]    id_prm__phy_rdst_index_o,
    output  ckpt_t[INST_DEC_PARAL-1 : 0]            id_prm__ckpt_o,
    output  phy_sr_index_t[INST_DEC_PARAL-1 : 0]    id_prm__phy_rs1_index_o,
    input   sr_status_e[INST_DEC_PARAL-1 : 0]       prm_id__phy_rs1_ready_i,
    output  phy_sr_index_t[INST_DEC_PARAL-1 : 0]    id_prm__phy_rs2_index_o,
    input   sr_status_e[INST_DEC_PARAL-1 : 0]       prm_id__phy_rs2_ready_i,
    input   update_arat_t                           rob_id__update_arat_i,
    input   update_ckpt_t[1 : 0]                    rob_id__update_ckpt_i,
    input   update_arc_ckpt_t                       rob_id__update_arc_ckpt_i,
    input   logic                                   safemd_rcov_disable_i,
    input   logic                                   safemd_safe_fl_i
);
    logic                                   flush_en;
    update_ckpt_t                           ckpt_rcov;
    logic                                   dec_en;
    logic                                   dec_is_stall;
    pc_t[INST_DEC_PARAL-1 : 0]              cur_pc_id0;
    issue_type_e[INST_DEC_PARAL-1 : 0]      inst_issue_type_id0;
    logic[INST_DEC_PARAL-1 : 0]             inst_is_jbr_id0;
    logic[INST_DEC_PARAL-1 : 0]             inst_is_ld_id0;
    logic[INST_DEC_PARAL-1 : 0]             inst_is_st_id0;
    logic[INST_DEC_PARAL-1 : 0]             inst_is_bid_id0;
    logic[INST_DEC_PARAL-1 : 0]             inst_complete_id0;
    logic[INST_DEC_PARAL-1 : 0]             inst_excp_en_id0;
    excp_e[INST_DEC_PARAL-1 : 0]            inst_excp_id0;
    alu_opcode_t[INST_DEC_PARAL-1 : 0]      alu_opcode_id0;
    lsu_opcode_t[INST_DEC_PARAL-1 : 0]      lsu_opcode_id0;
    mdu_opcode_t[INST_DEC_PARAL-1 : 0]      mdu_opcode_id0;
    vmu_opcode_t[INST_DEC_PARAL-1 : 0]      vmu_opcode_id0;
    sysc_opcode_t[INST_DEC_PARAL-1 : 0]     sysc_opcode_id0;
    arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rs1_index_id0;
    arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rs2_index_id0;
    arc_sr_index_t[INST_DEC_PARAL-1 : 0]    rs3_index_id0;
    arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rdst_index_id0;
    logic[INST_DEC_PARAL-1 : 0]             rdst_en_id0;
    logic[INST_DEC_PARAL-1 : 0]             inst_is_act_id0;
    phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rs1_index_id1;
    phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rs2_index_id1;
    phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rdst_index_id1;
    phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_old_rdst_index_id1;
    logic                                   ckpt_avail_id1;
    ckpt_t                                  ckpt_id1;
    logic                                   fl_is_stall;
    logic                                   dec_en_ff;
    if_inst_t                               inst_id1;
    pc_t[INST_DEC_PARAL-1 : 0]              cur_pc_id1;
    issue_type_e[INST_DEC_PARAL-1 : 0]      inst_issue_type_id1;
    logic[INST_DEC_PARAL-1 : 0]             inst_is_jbr_id1;
    logic[INST_DEC_PARAL-1 : 0]             inst_is_ld_id1;
    logic[INST_DEC_PARAL-1 : 0]             inst_is_st_id1;
    logic[INST_DEC_PARAL-1 : 0]             inst_is_bid_id1;
    logic[INST_DEC_PARAL-1 : 0]             inst_complete_id1;
    logic[INST_DEC_PARAL-1 : 0]             inst_excp_en_id1;
    excp_e[INST_DEC_PARAL-1 : 0]            inst_excp_id1;
    alu_opcode_t[INST_DEC_PARAL-1 : 0]      alu_opcode_id1;
    lsu_opcode_t[INST_DEC_PARAL-1 : 0]      lsu_opcode_id1;
    mdu_opcode_t[INST_DEC_PARAL-1 : 0]      mdu_opcode_id1;
    vmu_opcode_t[INST_DEC_PARAL-1 : 0]      vmu_opcode_id1;
    sysc_opcode_t[INST_DEC_PARAL-1 : 0]     sysc_opcode_id1;
    arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rs1_index_id1;
    arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rs2_index_id1;
    arc_sr_index_t[INST_DEC_PARAL-1 : 0]    rs3_index_id1;
    arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rdst_index_id1;
    logic[INST_DEC_PARAL-1 : 0]             rdst_en_id1;
    logic                                   disp_en;
    logic[INST_DEC_PARAL-1 : 0]             inst_is_act_id1;
    logic                                   disp_is_stall;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            flush_en <= 1'b0;
            ckpt_rcov <= update_ckpt_t'(0);
        end else begin
            flush_en <= ctrl__inst_flush_en_i;
            ckpt_rcov <= id__ckpt_rcov_o;
        end
    end
    assign dec_en = if_id__inst_vld_i
        && !fl_is_stall
        && !(flush_en || ckpt_rcov.en);
    assign dec_is_stall = (disp_en && disp_is_stall);
    assign id_if__inst_rdy_o = !(dec_is_stall && dec_en) && !fl_is_stall;
    for(genvar gi=0; gi<INST_DEC_PARAL; gi=gi+1) begin : hpu_dec
        assign cur_pc_id0[gi] = {dec_pc_base(if_id__inst_i.cur_pc), gi[INST_DEC_BIT-1 : 0], 2'h0};
        hpu_id_dec hpu_id_dec_inst (
            .inst_id0_i                             (if_id__inst_i.inst[gi]),
            .cur_pc_id0_i                           (cur_pc_id0[gi]),
            .inst_issue_type_id0_o                  (inst_issue_type_id0[gi]),
            .inst_is_jbr_id0_o                      (inst_is_jbr_id0[gi]),
            .inst_is_bid_id0_o                      (inst_is_bid_id0[gi]),
            .inst_is_ld_id0_o                       (inst_is_ld_id0[gi]),
            .inst_is_st_id0_o                       (inst_is_st_id0[gi]),
            .inst_complete_id0_o                    (inst_complete_id0[gi]),
            .inst_excp_en_id0_o                     (inst_excp_en_id0[gi]),
            .inst_excp_id0_o                        (inst_excp_id0[gi]),
            .alu_opcode_id0_o                       (alu_opcode_id0[gi]),
            .lsu_opcode_id0_o                       (lsu_opcode_id0[gi]),
            .mdu_opcode_id0_o                       (mdu_opcode_id0[gi]),
            .vmu_opcode_id0_o                       (vmu_opcode_id0[gi]),
            .sysc_opcode_id0_o                      (sysc_opcode_id0[gi]),
            .arc_rs1_index_id0_o                    (arc_rs1_index_id0[gi]),
            .arc_rs2_index_id0_o                    (arc_rs2_index_id0[gi]),
            .rs3_index_id0_o                        (rs3_index_id0[gi]),
            .arc_rdst_index_id0_o                   (arc_rdst_index_id0[gi]),
            .rdst_en_id0_o                          (rdst_en_id0[gi])
        );
        assign inst_is_act_id0[gi] = dec_en && !dec_is_stall && if_id__inst_i.avail[gi];
    end
    hpu_id_ren hpu_id_ren_inst (
        .clk_i                                  (clk_i),
        .rst_i                                  (rst_i),
        .flush_en_i                             (flush_en),
        .ckpt_rcov_i                            (ckpt_rcov),
        .id__ckpt_rcov_o                        (id__ckpt_rcov_o),
        .id__prefet_ckpt_o                      (id__prefet_ckpt_o),
        .inst_is_act_id0_i                      (inst_is_act_id0),
        .inst_is_jbr_id0_i                      (inst_is_jbr_id0),
        .rdst_en_id0_i                          (rdst_en_id0),
        .arc_rs1_index_id0_i                    (arc_rs1_index_id0),
        .arc_rs2_index_id0_i                    (arc_rs2_index_id0),
        .arc_rdst_index_id0_i                   (arc_rdst_index_id0),
        .phy_rs1_index_id1_o                    (phy_rs1_index_id1),
        .phy_rs2_index_id1_o                    (phy_rs2_index_id1),
        .phy_rdst_index_id1_o                   (phy_rdst_index_id1),
        .phy_old_rdst_index_id1_o               (phy_old_rdst_index_id1),
        .ckpt_avail_id1_o                       (ckpt_avail_id1),
        .ckpt_id1_o                             (ckpt_id1),
        .rob_id__update_arat_i                  (rob_id__update_arat_i),
        .rob_id__update_ckpt_i                  (rob_id__update_ckpt_i),
        .rob_id__update_arc_ckpt_i              (rob_id__update_arc_ckpt_i),
        .fl_is_stall_o                          (fl_is_stall),
        .dec_is_stall_i                         (dec_is_stall),
        .safemd_rcov_disable_i                  (safemd_rcov_disable_i),
        .safemd_safe_fl_i                       (safemd_safe_fl_i)
    );
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            dec_en_ff <= 1'b0;
            inst_id1 <= if_inst_t'(0);
            for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
                cur_pc_id1[i] <= pc_t'(0);
                inst_issue_type_id1[i] <= issue_type_e'(0);
                inst_is_jbr_id1[i] <= 1'b0;
                inst_is_ld_id1[i] <= 1'b0;
                inst_is_st_id1[i] <= 1'b0;
                inst_is_bid_id1[i] <= 1'b0;
                inst_complete_id1[i] <= 1'b0;
                inst_excp_en_id1[i] <= 1'b0;
                inst_excp_id1[i] <= excp_e'(0);
                alu_opcode_id1[i] <= alu_opcode_t'(0);
                lsu_opcode_id1[i] <= lsu_opcode_t'(0);
                mdu_opcode_id1[i] <= mdu_opcode_t'(0);
                vmu_opcode_id1[i] <= vmu_opcode_t'(0);
                sysc_opcode_id1[i] <= sysc_opcode_t'(0);
                arc_rs1_index_id1[i] <= arc_sr_index_t'(0);
                arc_rs2_index_id1[i] <= arc_sr_index_t'(0);
                rs3_index_id1[i] <= arc_sr_index_t'(0);
                arc_rdst_index_id1[i] <= arc_sr_index_t'(0);
                rdst_en_id1[i] <= 1'b0;
            end
        end else begin
            dec_en_ff <= dec_is_stall ? disp_en : dec_en;
            if(!dec_is_stall) begin
                inst_id1 <= if_id__inst_i;
                cur_pc_id1 <= cur_pc_id0;
                inst_issue_type_id1 <= inst_issue_type_id0;
                inst_is_jbr_id1 <= inst_is_jbr_id0;
                inst_is_ld_id1 <= inst_is_ld_id0;
                inst_is_st_id1 <= inst_is_st_id0;
                inst_is_bid_id1 <= inst_is_bid_id0;
                inst_complete_id1 <= inst_complete_id0;
                inst_excp_en_id1 <= inst_excp_en_id0;
                inst_excp_id1 <= inst_excp_id0;
                alu_opcode_id1 <= alu_opcode_id0;
                lsu_opcode_id1 <= lsu_opcode_id0;
                mdu_opcode_id1 <= mdu_opcode_id0;
                vmu_opcode_id1 <= vmu_opcode_id0;
                sysc_opcode_id1 <= sysc_opcode_id0;
                arc_rs1_index_id1 <= arc_rs1_index_id0;
                arc_rs2_index_id1 <= arc_rs2_index_id0;
                rs3_index_id1 <= rs3_index_id0;
                arc_rdst_index_id1 <= arc_rdst_index_id0;
                rdst_en_id1 <= rdst_en_id0;
            end
        end
    end
    assign disp_en = dec_en_ff
        & ~(flush_en | ckpt_rcov.en);
    always_comb begin
        for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
            inst_is_act_id1[i] = disp_en && !disp_is_stall && inst_id1.avail[i];
        end
    end
    hpu_id_disp hpu_id_disp_inst (
        .inst_id1_i                             (inst_id1),
        .inst_is_act_id1_i                      (inst_is_act_id1),
        .disp_en_i                              (disp_en),
        .inst_issue_type_id1_i                  (inst_issue_type_id1),
        .inst_is_jbr_id1_i                      (inst_is_jbr_id1),
        .inst_is_ld_id1_i                       (inst_is_ld_id1),
        .inst_is_st_id1_i                       (inst_is_st_id1),
        .inst_is_bid_id1_i                      (inst_is_bid_id1),
        .inst_complete_id1_i                    (inst_complete_id1),
        .inst_excp_en_id1_i                     (inst_excp_en_id1),
        .inst_excp_id1_i                        (inst_excp_id1),
        .alu_opcode_id1_i                       (alu_opcode_id1),
        .lsu_opcode_id1_i                       (lsu_opcode_id1),
        .mdu_opcode_id1_i                       (mdu_opcode_id1),
        .vmu_opcode_id1_i                       (vmu_opcode_id1),
        .sysc_opcode_id1_i                      (sysc_opcode_id1),
        .arc_rs1_index_id1_i                    (arc_rs1_index_id1),
        .arc_rs2_index_id1_i                    (arc_rs2_index_id1),
        .rs3_index_id1_i                        (rs3_index_id1),
        .arc_rdst_index_id1_i                   (arc_rdst_index_id1),
        .rdst_en_id1_i                          (rdst_en_id1),
        .phy_rs1_index_id1_i                    (phy_rs1_index_id1),
        .phy_rs2_index_id1_i                    (phy_rs2_index_id1),
        .phy_rdst_index_id1_i                   (phy_rdst_index_id1),
        .phy_old_rdst_index_id1_i               (phy_old_rdst_index_id1),
        .ckpt_avail_id1_i                       (ckpt_avail_id1),
        .ckpt_id1_i                             (ckpt_id1),
        .id_prm__rdst_en_o                      (id_prm__rdst_en_o),
        .id_prm__phy_rdst_index_o               (id_prm__phy_rdst_index_o),
        .id_prm__ckpt_o                         (id_prm__ckpt_o),
        .id_prm__phy_rs1_index_o                (id_prm__phy_rs1_index_o),
        .prm_id__phy_rs1_ready_i                (prm_id__phy_rs1_ready_i),
        .id_prm__phy_rs2_index_o                (id_prm__phy_rs2_index_o),
        .prm_id__phy_rs2_ready_i                (prm_id__phy_rs2_ready_i),
        .id_alu0__inst_o                        (id_alu0__inst_o),
        .id_alu0__avail_o                       (id_alu0__avail_o),
        .id_alu0__rs1_ready_o                   (id_alu0__rs1_ready_o),
        .id_alu0__rs2_ready_o                   (id_alu0__rs2_ready_o),
        .id_alu0__inst_vld_o                    (id_alu0__inst_vld_o),
        .alu0_id__inst_rdy_i                    (alu0_id__inst_rdy_i),
        .alu0_id__left_size_i                   (alu0_id__left_size_i),
        .id_alu1__inst_o                        (id_alu1__inst_o),
        .id_alu1__avail_o                       (id_alu1__avail_o),
        .id_alu1__rs1_ready_o                   (id_alu1__rs1_ready_o),
        .id_alu1__rs2_ready_o                   (id_alu1__rs2_ready_o),
        .id_alu1__inst_vld_o                    (id_alu1__inst_vld_o),
        .alu1_id__inst_rdy_i                    (alu1_id__inst_rdy_i),
        .alu1_id__left_size_i                   (alu1_id__left_size_i),
        .id_mdu__inst_o                         (id_mdu__inst_o),
        .id_mdu__avail_o                        (id_mdu__avail_o),
        .id_mdu__rs1_ready_o                    (id_mdu__rs1_ready_o),
        .id_mdu__rs2_ready_o                    (id_mdu__rs2_ready_o),
        .id_mdu__inst_vld_o                     (id_mdu__inst_vld_o),
        .mdu_id__inst_rdy_i                     (mdu_id__inst_rdy_i),
        .mdu_id__left_size_i                    (mdu_id__left_size_i),
        .id_lsu__inst_o                         (id_lsu__inst_o),
        .id_lsu__avail_o                        (id_lsu__avail_o),
        .id_lsu__rs1_ready_o                    (id_lsu__rs1_ready_o),
        .id_lsu__rs2_ready_o                    (id_lsu__rs2_ready_o),
        .id_lsu__inst_vld_o                     (id_lsu__inst_vld_o),
        .lsu_id__inst_rdy_i                     (lsu_id__inst_rdy_i),
        .lsu_id__left_size_i                    (lsu_id__left_size_i),
        .id_vmu__inst_o                         (id_vmu__inst_o),
        .id_vmu__avail_o                        (id_vmu__avail_o),
        .id_vmu__rs1_ready_o                    (id_vmu__rs1_ready_o),
        .id_vmu__rs2_ready_o                    (id_vmu__rs2_ready_o),
        .id_vmu__inst_vld_o                     (id_vmu__inst_vld_o),
        .vmu_id__inst_rdy_i                     (vmu_id__inst_rdy_i),
        .vmu_id__left_size_i                    (vmu_id__left_size_i),
        .id_rob__inst_pkg_o                     (id_rob__inst_pkg_o),
        .id_rob__slot_pkg_o                     (id_rob__slot_pkg_o),
        .id_rob__inst_vld_o                     (id_rob__inst_vld_o),
        .rob_id__inst_rdy_i                     (rob_id__inst_rdy_i),
        .rob_id__rob_index_i                    (rob_id__rob_index_i),
        .rob_id__rob_flag_i                     (rob_id__rob_flag_i),
        .disp_is_stall_o                        (disp_is_stall)
    );
    logic prb_id0_en;
    logic prb_id1_en;
    pc_t prb_id1_pc;
    pc_t prb_id1_pred_npc;
    logic[INST_DEC_PARAL-1 : 0] prb_id1_pc_mask;
    issue_type_e[INST_DEC_PARAL-1 : 0] prb_id1_pc_type;
    itype_alu_e[INST_DEC_PARAL-1 : 0] prb_id1_alu_op;
    itype_lsu_e[INST_DEC_PARAL-1 : 0] prb_id1_lsu_op;
    itype_vmu_e[INST_DEC_PARAL-1 : 0] prb_id1_vmu_op;
    itype_sysc_e[INST_DEC_PARAL-1 : 0] prb_id1_sysc_op;
    ckpt_t prb_id1_ckpt;
    logic prb_id1_ckpt_avail;
    assign prb_id0_en = dec_en;
    assign prb_id1_en = disp_en;
    assign prb_id1_pc = disp_en ? inst_id1.cur_pc : pc_t'(0);
    assign prb_id1_pred_npc = disp_en ? inst_id1.pred_npc : pc_t'(0);
    for(genvar i=0; i<INST_DEC_PARAL; i=i+1) begin
        assign prb_id1_pc_mask[i] = disp_en && inst_id1.avail[i];
        assign prb_id1_pc_type[i] = inst_issue_type_id1[i];
        assign prb_id1_alu_op[i] = (prb_id1_pc_type[i] == TO_ALU) ? alu_opcode_id1[i].optype : itype_alu_e'(0);
        assign prb_id1_lsu_op[i] = (prb_id1_pc_type[i] == TO_LSU) ? lsu_opcode_id1[i].optype : itype_lsu_e'(0);
        assign prb_id1_vmu_op[i] = (prb_id1_pc_type[i] == TO_VMU) ? vmu_opcode_id1[i].optype : itype_vmu_e'(0);
        assign prb_id1_sysc_op[i] = (prb_id1_pc_type[i] == TO_NONE) ? sysc_opcode_id1[i].optype : itype_sysc_e'(0);
    end
    assign prb_id1_ckpt = ckpt_id1;
    assign prb_id1_ckpt_avail = ckpt_avail_id1;
endmodule : hpu_id
