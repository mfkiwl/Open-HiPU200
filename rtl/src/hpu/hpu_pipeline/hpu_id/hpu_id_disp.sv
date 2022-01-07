`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_id_disp (
    input   if_inst_t                               inst_id1_i,
    input   logic[INST_DEC_PARAL-1 : 0]             inst_is_act_id1_i,
    input   logic                                   disp_en_i,
    input   issue_type_e[INST_DEC_PARAL-1 : 0]      inst_issue_type_id1_i,
    input   logic[INST_DEC_PARAL-1 : 0]             inst_is_jbr_id1_i,
    input   logic[INST_DEC_PARAL-1 : 0]             inst_is_ld_id1_i,
    input   logic[INST_DEC_PARAL-1 : 0]             inst_is_st_id1_i,
    input   logic[INST_DEC_PARAL-1 : 0]             inst_is_bid_id1_i,
    input   logic[INST_DEC_PARAL-1 : 0]             inst_complete_id1_i,
    input   logic[INST_DEC_PARAL-1 : 0]             inst_excp_en_id1_i,
    input   excp_e[INST_DEC_PARAL-1 : 0]            inst_excp_id1_i,
    input   alu_opcode_t[INST_DEC_PARAL-1 : 0]      alu_opcode_id1_i,
    input   lsu_opcode_t[INST_DEC_PARAL-1 : 0]      lsu_opcode_id1_i,
    input   mdu_opcode_t[INST_DEC_PARAL-1 : 0]      mdu_opcode_id1_i,
    input   vmu_opcode_t[INST_DEC_PARAL-1 : 0]      vmu_opcode_id1_i,
    input   sysc_opcode_t[INST_DEC_PARAL-1 : 0]     sysc_opcode_id1_i,
    input   arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rs1_index_id1_i,
    input   arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rs2_index_id1_i,
    input   arc_sr_index_t[INST_DEC_PARAL-1 : 0]    rs3_index_id1_i,
    input   arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rdst_index_id1_i,
    input   logic[INST_DEC_PARAL-1 : 0]             rdst_en_id1_i,
    input   phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rs1_index_id1_i,
    input   phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rs2_index_id1_i,
    input   phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rdst_index_id1_i,
    input   phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_old_rdst_index_id1_i,
    input   logic                                   ckpt_avail_id1_i,
    input   ckpt_t                                  ckpt_id1_i,
    output  logic[INST_DEC_PARAL-1 : 0]             id_prm__rdst_en_o,
    output  phy_sr_index_t[INST_DEC_PARAL-1 : 0]    id_prm__phy_rdst_index_o,
    output  ckpt_t[INST_DEC_PARAL-1 : 0]            id_prm__ckpt_o,
    output  phy_sr_index_t[INST_DEC_PARAL-1 : 0]    id_prm__phy_rs1_index_o,
    input   sr_status_e[INST_DEC_PARAL-1 : 0]       prm_id__phy_rs1_ready_i,
    output  phy_sr_index_t[INST_DEC_PARAL-1 : 0]    id_prm__phy_rs2_index_o,
    input   sr_status_e[INST_DEC_PARAL-1 : 0]       prm_id__phy_rs2_ready_i,
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
    output  mdu_inst_t[INST_DEC_PARAL-1 : 0]        id_mdu__inst_o,
    output  logic[INST_DEC_PARAL-1 : 0]             id_mdu__avail_o,
    output  sr_status_e[INST_DEC_PARAL-1 : 0]       id_mdu__rs1_ready_o,
    output  sr_status_e[INST_DEC_PARAL-1 : 0]       id_mdu__rs2_ready_o,
    output  logic                                   id_mdu__inst_vld_o,
    input   logic                                   mdu_id__inst_rdy_i,
    input   logic[MDU_IQ_INDEX : 0]                 mdu_id__left_size_i,
    output  lsu_inst_t[INST_DEC_PARAL-1 : 0]        id_lsu__inst_o,
    output  logic[INST_DEC_PARAL-1 : 0]             id_lsu__avail_o,
    output  sr_status_e[INST_DEC_PARAL-1 : 0]       id_lsu__rs1_ready_o,
    output  sr_status_e[INST_DEC_PARAL-1 : 0]       id_lsu__rs2_ready_o,
    output  logic                                   id_lsu__inst_vld_o,
    input   logic                                   lsu_id__inst_rdy_i,
    input   logic[LSU_IQ_INDEX : 0]                 lsu_id__left_size_i,
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
    output  logic                                   disp_is_stall_o
);
    logic[INST_DEC_PARAL-1 : 0]             alu_en;
    logic[INST_DEC_PARAL-1 : 0]             lsu_en;
    logic[INST_DEC_PARAL-1 : 0]             mdu_en;
    logic[INST_DEC_PARAL-1 : 0]             vmu_en;
    logic[INST_DEC_PARAL-1 : 0]             jbr_en;
    logic[INST_DEC_PARAL-1 : 0]             bid_en;
    logic                                   rob_stall;
    alu_inst_pkg_t[INST_DEC_PARAL-1 : 0]    alu_cmd;
    alu_inst_pkg_t                          id_alu0__inst_pkg, id_alu1__inst_pkg;
    lsu_inst_pkg_t[INST_DEC_PARAL-1 : 0]    lsu_cmd, id_lsu__inst_pkg;
    mdu_inst_pkg_t[INST_DEC_PARAL-1 : 0]    mdu_cmd, id_mdu__inst_pkg;
    vmu_inst_pkg_t[INST_DEC_PARAL-1 : 0]    vmu_cmd, id_vmu__inst_pkg;
    logic                                   alu0_is_prefer;
    logic                                   alu0_sel, alu1_sel, lsu_sel, mdu_sel, vmu_sel;
    logic                                   alu0_stall, alu1_stall, lsu_stall, mdu_stall, vmu_stall;
    for(genvar gi=0; gi<INST_DEC_PARAL; gi=gi+1) begin : disp_enable
        assign alu_en[gi] = inst_id1_i.avail[gi] && (inst_issue_type_id1_i[gi] == TO_ALU);
        assign lsu_en[gi] = inst_id1_i.avail[gi] && (inst_issue_type_id1_i[gi] == TO_LSU);
        assign mdu_en[gi] = inst_id1_i.avail[gi] && (inst_issue_type_id1_i[gi] == TO_MDU);
        assign vmu_en[gi] = inst_id1_i.avail[gi] && (inst_issue_type_id1_i[gi] == TO_VMU);
        assign jbr_en[gi] = inst_id1_i.avail[gi] && inst_is_jbr_id1_i[gi];
        assign bid_en[gi] = inst_id1_i.avail[gi] && inst_is_bid_id1_i[gi];
    end
    always_comb begin
        for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
            id_rob__inst_pkg_o[i].rob_inst.inst = inst_id1_i.inst[i];
            id_rob__inst_pkg_o[i].rob_inst.issue_type = inst_issue_type_id1_i[i];
            id_rob__inst_pkg_o[i].rob_inst.itype = alu_en[i] ? alu_opcode_id1_i[i].optype
                                                 : lsu_en[i] ? lsu_opcode_id1_i[i].optype
                                                 : mdu_en[i] ? mdu_opcode_id1_i[i].optype
                                                 : vmu_en[i] ? vmu_opcode_id1_i[i].optype
                                                 : sysc_opcode_id1_i[i].optype;
            id_rob__inst_pkg_o[i].rob_inst.is_ld = inst_is_ld_id1_i[i];
            id_rob__inst_pkg_o[i].rob_inst.is_st = inst_is_st_id1_i[i];
            id_rob__inst_pkg_o[i].rob_inst.csr_we_mask = lsu_opcode_id1_i[i].csr_we_mask;
            id_rob__inst_pkg_o[i].rob_inst.sysc = sysc_opcode_id1_i[i].sysc;
            id_rob__inst_pkg_o[i].rob_inst.rdst_en = rdst_en_id1_i[i];
            id_rob__inst_pkg_o[i].rob_inst.arc_rdst_index = arc_rdst_index_id1_i[i];
            id_rob__inst_pkg_o[i].rob_inst.phy_rdst_index = phy_rdst_index_id1_i[i];
            id_rob__inst_pkg_o[i].rob_inst.phy_old_rdst_index = phy_old_rdst_index_id1_i[i];
            id_rob__inst_pkg_o[i].avail = inst_id1_i.avail[i];
            id_rob__inst_pkg_o[i].complete = inst_complete_id1_i[i];
            id_rob__inst_pkg_o[i].excp_en = inst_excp_en_id1_i[i];
            id_rob__inst_pkg_o[i].excp = inst_excp_id1_i[i];
        end
    end
    assign id_rob__slot_pkg_o.cur_pc = inst_id1_i.cur_pc;
    assign id_rob__slot_pkg_o.pred_npc = inst_id1_i.pred_npc;
    assign id_rob__slot_pkg_o.pred_bid_taken = inst_id1_i.pred_bid_taken;
    assign id_rob__slot_pkg_o.is_jbr = |jbr_en;
    assign id_rob__slot_pkg_o.is_bid = |bid_en;
    always_comb begin
        id_rob__slot_pkg_o.first_pc_offset = {INST_DEC_BIT{1'b1}};
        for(integer i=INST_DEC_PARAL-2; i>=0; i=i-1) begin
            if(inst_id1_i.avail[i]) begin
                id_rob__slot_pkg_o.first_pc_offset = i;
            end
        end
        id_rob__slot_pkg_o.ckpt_act = ckpt_avail_id1_i;
        id_rob__slot_pkg_o.ckpt = ckpt_id1_i;
        id_rob__slot_pkg_o.btb_way_sel = inst_id1_i.btb_way_sel;
        id_rob__slot_pkg_o.fet_pc_offset = inst_id1_i.fet_pc_offset;
        id_rob__slot_pkg_o.last_pc_offset = {INST_DEC_BIT{1'b0}};
        id_rob__slot_pkg_o.qdec_type = inst_id1_i.qdec_type[0];
        for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
            if(inst_id1_i.avail[i]) begin
                id_rob__slot_pkg_o.last_pc_offset = i[INST_DEC_BIT-1 : 0];
                id_rob__slot_pkg_o.qdec_type = inst_id1_i.qdec_type[i];
            end
        end
    end
    assign id_rob__inst_vld_o = disp_en_i && |inst_id1_i.avail && !disp_is_stall_o;
    assign rob_stall = !rob_id__inst_rdy_i;
    always_comb begin
        for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
            alu_cmd[i].alu_inst.opcode = alu_opcode_id1_i[i];
            alu_cmd[i].alu_inst.ckpt = ckpt_id1_i;
            alu_cmd[i].alu_inst.phy_rs1_index = phy_rs1_index_id1_i[i];
            alu_cmd[i].alu_inst.phy_rs2_index = phy_rs2_index_id1_i[i];
            alu_cmd[i].alu_inst.phy_rdst_index = phy_rdst_index_id1_i[i];
            alu_cmd[i].alu_inst.is_jbr = inst_is_jbr_id1_i[i];
            alu_cmd[i].alu_inst.cur_pc = inst_id1_i.cur_pc + (i<<2);
            alu_cmd[i].alu_inst.rob_flag = rob_id__rob_flag_i;
            alu_cmd[i].alu_inst.rob_index = rob_id__rob_index_i;
            alu_cmd[i].alu_inst.rob_offset = INST_DEC_BIT'(i);
            alu_cmd[i].avail = alu_en[i];
            alu_cmd[i].phy_rs1_ready = alu_opcode_id1_i[i].rs1_en ? prm_id__phy_rs1_ready_i[i] : READY;
            alu_cmd[i].phy_rs2_ready = alu_opcode_id1_i[i].rs2_en ? prm_id__phy_rs2_ready_i[i] : READY;
            lsu_cmd[i].lsu_inst.opcode = lsu_opcode_id1_i[i];
            lsu_cmd[i].lsu_inst.ckpt = ckpt_id1_i;
            lsu_cmd[i].lsu_inst.phy_rs1_index = phy_rs1_index_id1_i[i];
            lsu_cmd[i].lsu_inst.phy_rs2_index = phy_rs2_index_id1_i[i];
            lsu_cmd[i].lsu_inst.phy_rdst_index = phy_rdst_index_id1_i[i];
            lsu_cmd[i].lsu_inst.rob_index = rob_id__rob_index_i;
            lsu_cmd[i].lsu_inst.rob_offset = INST_DEC_BIT'(i);
            lsu_cmd[i].avail = lsu_en[i];
            lsu_cmd[i].phy_rs1_ready = lsu_opcode_id1_i[i].rs1_en ? prm_id__phy_rs1_ready_i[i] : READY;
            lsu_cmd[i].phy_rs2_ready = lsu_opcode_id1_i[i].rs2_en ? prm_id__phy_rs2_ready_i[i] : READY;
            mdu_cmd[i].mdu_inst.opcode = mdu_opcode_id1_i[i];
            mdu_cmd[i].mdu_inst.ckpt = ckpt_id1_i;
            mdu_cmd[i].mdu_inst.phy_rs1_index = phy_rs1_index_id1_i[i];
            mdu_cmd[i].mdu_inst.phy_rs2_index = phy_rs2_index_id1_i[i];
            mdu_cmd[i].mdu_inst.phy_rdst_index = phy_rdst_index_id1_i[i];
            mdu_cmd[i].mdu_inst.rob_index = rob_id__rob_index_i;
            mdu_cmd[i].mdu_inst.rob_offset = INST_DEC_BIT'(i);
            mdu_cmd[i].avail = mdu_en[i];
            mdu_cmd[i].phy_rs1_ready = prm_id__phy_rs1_ready_i[i];
            mdu_cmd[i].phy_rs2_ready = prm_id__phy_rs2_ready_i[i];
            vmu_cmd[i].vmu_inst.opcode = vmu_opcode_id1_i[i];
            vmu_cmd[i].vmu_inst.ckpt = ckpt_id1_i;
            vmu_cmd[i].vmu_inst.phy_rs1_index = phy_rs1_index_id1_i[i];
            vmu_cmd[i].vmu_inst.phy_rs2_index = phy_rs2_index_id1_i[i];
            vmu_cmd[i].vmu_inst.vrs1_index = arc_rs1_index_id1_i[i][3:0];
            vmu_cmd[i].vmu_inst.vrs2_index = arc_rs2_index_id1_i[i][3:0];
            vmu_cmd[i].vmu_inst.vrs3_index = rs3_index_id1_i[i][3:0];
            vmu_cmd[i].vmu_inst.vrdst_index = arc_rdst_index_id1_i[i][3:0];
            vmu_cmd[i].vmu_inst.rob_index = rob_id__rob_index_i;
            vmu_cmd[i].vmu_inst.rob_offset = INST_DEC_BIT'(i);
            vmu_cmd[i].avail = vmu_en[i];
            vmu_cmd[i].phy_rs1_ready = vmu_opcode_id1_i[i].rs1_en ? prm_id__phy_rs1_ready_i[i] : READY;
            vmu_cmd[i].phy_rs2_ready = vmu_opcode_id1_i[i].rs2_en ? prm_id__phy_rs2_ready_i[i] : READY;
        end
    end
    assign alu0_sel = !alu_en[0];
    assign alu1_sel = alu_en[1];
    assign alu0_is_prefer = (alu0_id__left_size_i >= alu1_id__left_size_i) ? 1'b1 : 1'b0;
    always_comb begin
        id_alu0__inst_pkg = alu0_sel ? alu_cmd[1] : alu_cmd[0];
        id_alu1__inst_pkg = alu1_sel ? alu_cmd[1] : alu_cmd[0];
        id_alu0__inst_pkg.avail = (alu_en[0] ^ alu_en[1]) ? alu0_is_prefer : alu_en[0];
        id_alu1__inst_pkg.avail = (alu_en[0] ^ alu_en[1]) ? !alu0_is_prefer : alu_en[1];
    end
    assign id_alu0__inst_o = id_alu0__inst_pkg.alu_inst;
    assign id_alu0__avail_o = id_alu0__inst_pkg.avail;
    assign id_alu0__rs1_ready_o = id_alu0__inst_pkg.phy_rs1_ready;
    assign id_alu0__rs2_ready_o = id_alu0__inst_pkg.phy_rs2_ready;
    assign id_alu1__inst_o = id_alu1__inst_pkg.alu_inst;
    assign id_alu1__avail_o = id_alu1__inst_pkg.avail;
    assign id_alu1__rs1_ready_o = id_alu1__inst_pkg.phy_rs1_ready;
    assign id_alu1__rs2_ready_o = id_alu1__inst_pkg.phy_rs2_ready;
    assign id_alu0__inst_vld_o = disp_en_i && id_alu0__inst_pkg.avail && !disp_is_stall_o;
    assign id_alu1__inst_vld_o = disp_en_i && id_alu1__inst_pkg.avail && !disp_is_stall_o;
    assign alu0_stall = !alu0_id__inst_rdy_i;
    assign alu1_stall = !alu1_id__inst_rdy_i;
    assign lsu_sel = !lsu_en[0];
    always_comb begin
        id_lsu__inst_pkg[0] = lsu_sel ? lsu_cmd[1] : lsu_cmd[0];
        id_lsu__inst_pkg[1] = lsu_cmd[1];
        id_lsu__inst_pkg[0].avail = lsu_en[0] | lsu_en[1];
        id_lsu__inst_pkg[1].avail = lsu_en[0] & lsu_en[1];
    end
    always_comb begin
        for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
            id_lsu__inst_o[i] = id_lsu__inst_pkg[i].lsu_inst;
            id_lsu__avail_o[i] = id_lsu__inst_pkg[i].avail;
            id_lsu__rs1_ready_o[i] = id_lsu__inst_pkg[i].phy_rs1_ready;
            id_lsu__rs2_ready_o[i] = id_lsu__inst_pkg[i].phy_rs2_ready;
        end
    end
    assign id_lsu__inst_vld_o = disp_en_i && |id_lsu__avail_o && !disp_is_stall_o;
    assign lsu_stall = !lsu_id__inst_rdy_i;
    assign mdu_sel = !mdu_en[0];
    always_comb begin
        id_mdu__inst_pkg[0] = mdu_sel ? mdu_cmd[1] : mdu_cmd[0];
        id_mdu__inst_pkg[1] = mdu_cmd[1];
        id_mdu__inst_pkg[0].avail = mdu_en[0] | mdu_en[1];
        id_mdu__inst_pkg[1].avail = mdu_en[0] & mdu_en[1];
    end
    always_comb begin
        for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
            id_mdu__inst_o[i] = id_mdu__inst_pkg[i].mdu_inst;
            id_mdu__avail_o[i] = id_mdu__inst_pkg[i].avail;
            id_mdu__rs1_ready_o[i] = id_mdu__inst_pkg[i].phy_rs1_ready;
            id_mdu__rs2_ready_o[i] = id_mdu__inst_pkg[i].phy_rs2_ready;
        end
    end
    assign id_mdu__inst_vld_o = disp_en_i && |id_mdu__avail_o && !disp_is_stall_o;
    assign mdu_stall = !mdu_id__inst_rdy_i;
    assign vmu_sel = !vmu_en[0];
    always_comb begin
        id_vmu__inst_pkg[0] = vmu_sel ? vmu_cmd[1] : vmu_cmd[0];
        id_vmu__inst_pkg[1] = vmu_cmd[1];
        id_vmu__inst_pkg[0].avail = vmu_en[0] | vmu_en[1];
        id_vmu__inst_pkg[1].avail = vmu_en[0] & vmu_en[1];
    end
    always_comb begin
        for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
            id_vmu__inst_o[i] = id_vmu__inst_pkg[i].vmu_inst;
            id_vmu__avail_o[i] = id_vmu__inst_pkg[i].avail;
            id_vmu__rs1_ready_o[i] = id_vmu__inst_pkg[i].phy_rs1_ready;
            id_vmu__rs2_ready_o[i] = id_vmu__inst_pkg[i].phy_rs2_ready;
        end
    end
    assign id_vmu__inst_vld_o = disp_en_i && |id_vmu__avail_o && !disp_is_stall_o;
    assign vmu_stall = !vmu_id__inst_rdy_i || (vmu_id__left_size_i < vmu_en[0] + vmu_en[1]);
    assign disp_is_stall_o = alu0_stall | alu1_stall | lsu_stall | mdu_stall | vmu_stall | rob_stall;
    always_comb begin
        for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
            id_prm__rdst_en_o[i] = inst_is_act_id1_i[i] & rdst_en_id1_i[i];
            id_prm__phy_rdst_index_o[i] = phy_rdst_index_id1_i[i];
            id_prm__phy_rs1_index_o[i] = phy_rs1_index_id1_i[i];
            id_prm__phy_rs2_index_o[i] = phy_rs2_index_id1_i[i];
            id_prm__ckpt_o[i] = ckpt_id1_i;
        end
    end
endmodule : hpu_id_disp
