`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_alu (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   ctrl__inst_flush_en_i,
    input   update_ckpt_t                           id__ckpt_rcov_i,
    input   ckpt_t                                  id__prefet_ckpt_i,
    input   alu_inst_t                              id_alu__inst_i,
    input   logic                                   id_alu__avail_i,
    input   sr_status_e                             id_alu__rs1_ready_i,
    input   sr_status_e                             id_alu__rs2_ready_i,
    input   logic                                   id_alu__inst_vld_i,
    output  logic                                   alu_id__inst_rdy_o,
    output  logic[ALU_IQ_INDEX : 0]                 alu_id__left_size_o,
    output  phy_sr_index_t                          alu_prf__rs1_index_o,
    input   data_t                                  prf_alu__rs1_data_i,
    output  phy_sr_index_t                          alu_prf__rs2_index_o,
    input   data_t                                  prf_alu__rs2_data_i,
    output  phy_sr_index_t                          alu_prf__rdst_index_o,
    output  logic                                   alu_prf__rdst_en_o,
    output  data_t                                  alu_prf__rdst_data_o,
    output  alu_commit_t                            alu_rob__commit_o,
    output  awake_index_t                           alu_iq__awake_o,
    input   awake_index_t                           alu0_iq__awake_i,
    input   awake_index_t                           alu1_iq__awake_i,
    input   awake_index_t                           mdu_iq__awake_i,
    input   awake_index_t                           lsu_iq__awake_i,
    output  bypass_data_t                           alu_bypass__data_o,
    input   bypass_data_t                           alu0_bypass__data_i,
    input   bypass_data_t                           alu1_bypass__data_i,
    output  awake_index_t                           alu_prm__update_prm_o
);
    logic                                   flush_en;
    update_ckpt_t                           ckpt_rcov;
    logic                                   alu_en;
    alu_inst_t                              alu_inst;
    logic                                   alu_en_dly1;
    alu_inst_t                              alu_inst_reg;
    phy_sr_index_t                          phy_rs1_index_reg;
    phy_sr_index_t                          phy_rs2_index_reg;
    logic                                   alu_reg_en;
    data_t                                  bypass_rs1_data;
    data_t                                  bypass_rs2_data;
    logic                                   alu_reg_en_dly1;
    alu_inst_t                              alu_inst_exec;
    data_t                                  bypass_rs1_data_exec;
    data_t                                  bypass_rs2_data_exec;
    logic                                   alu_exec_en;
    data_t                                  phy_rdst_data;
    logic                                   br_is_taken;
    pc_t                                    alu_next_pc;
    logic                                   alu_excp_en;
    excp_e                                  alu_excp;
    logic                                   alu_exec_en_dly1;
    alu_inst_t                              alu_inst_wb;
    data_t                                  phy_rdst_data_wb;
    logic                                   br_is_taken_wb;
    pc_t                                    alu_next_pc_wb;
    logic                                   alu_excp_en_wb;
    excp_e                                  alu_excp_wb;
    logic                                   alu_wb_en;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            flush_en <= 1'b0;
            ckpt_rcov <= update_ckpt_t'(0);
        end else begin
            flush_en <= ctrl__inst_flush_en_i;
            ckpt_rcov <= id__ckpt_rcov_i;
        end
    end
    hpu_alu_iq hpu_alu_iq_inst (
        .clk_i                                  (clk_i),
        .rst_i                                  (rst_i),
        .flush_en_i                             (flush_en),
        .ckpt_rcov_i                            (ckpt_rcov),
        .id__prefet_ckpt_i                      (id__prefet_ckpt_i),
        .id_alu__inst_i                         (id_alu__inst_i),
        .id_alu__avail_i                        (id_alu__avail_i),
        .id_alu__rs1_ready_i                    (id_alu__rs1_ready_i),
        .id_alu__rs2_ready_i                    (id_alu__rs2_ready_i),
        .id_alu__inst_vld_i                     (id_alu__inst_vld_i),
        .alu_id__inst_rdy_o                     (alu_id__inst_rdy_o),
        .alu_id__left_size_o                    (alu_id__left_size_o),
        .alu_iq__awake_o                        (alu_iq__awake_o),
        .alu0_iq__awake_i                       (alu0_iq__awake_i),
        .alu1_iq__awake_i                       (alu1_iq__awake_i),
        .mdu_iq__awake_i                        (mdu_iq__awake_i),
        .lsu_iq__awake_i                        (lsu_iq__awake_i),
        .alu_en_o                               (alu_en),
        .alu_inst_o                             (alu_inst),
        .alu_prm__update_prm_o                  (alu_prm__update_prm_o)
    );
    assign alu_prf__rs1_index_o = alu_inst.phy_rs1_index;
    assign alu_prf__rs2_index_o = alu_inst.phy_rs2_index;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            alu_en_dly1 <= 1'b0;
            alu_inst_reg <= alu_inst_t'(0);
            phy_rs1_index_reg <= phy_sr_index_t'(0);
            phy_rs2_index_reg <= phy_sr_index_t'(0);
        end else begin
            alu_en_dly1 <= alu_en;
            alu_inst_reg <= alu_inst;
            phy_rs1_index_reg <= alu_inst.phy_rs1_index;
            phy_rs2_index_reg <= alu_inst.phy_rs2_index;
        end
    end
    assign alu_reg_en = alu_en_dly1
        && !flush_en
        && !(ckpt_rcov.en && chk_ckpt(alu_inst_reg.ckpt, ckpt_rcov.ckpt, id__prefet_ckpt_i));
    hpu_alu_bypass hpu_alu_bypass_inst (
        .alu0_bypass__data_i                    (alu0_bypass__data_i),
        .alu1_bypass__data_i                    (alu1_bypass__data_i),
        .phy_rs1_index_reg_i                    (phy_rs1_index_reg),
        .prf_alu__rs1_data_i                    (prf_alu__rs1_data_i),
        .bypass_rs1_data_o                      (bypass_rs1_data),
        .phy_rs2_index_reg_i                    (phy_rs2_index_reg),
        .prf_alu__rs2_data_i                    (prf_alu__rs2_data_i),
        .bypass_rs2_data_o                      (bypass_rs2_data)
    );
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            alu_reg_en_dly1 <= 1'b0;
            alu_inst_exec <= alu_inst_t'(0);
            bypass_rs1_data_exec <= data_t'(0);
            bypass_rs2_data_exec <= data_t'(0);
        end else begin
            alu_reg_en_dly1 <= alu_reg_en;
            alu_inst_exec <= alu_inst_reg;
            bypass_rs1_data_exec <= bypass_rs1_data;
            bypass_rs2_data_exec <= bypass_rs2_data;
        end
    end
    assign alu_exec_en = alu_reg_en_dly1
        && !flush_en
        && !(ckpt_rcov.en && chk_ckpt(alu_inst_exec.ckpt, ckpt_rcov.ckpt, id__prefet_ckpt_i));
    hpu_alu_exec hpu_alu_exec_inst (
        .clk_i                                  (clk_i),
        .rst_i                                  (rst_i),
        .alu_inst_exec_i                        (alu_inst_exec),
        .bypass_rs1_data_exec_i                 (bypass_rs1_data_exec),
        .bypass_rs2_data_exec_i                 (bypass_rs2_data_exec),
        .phy_rdst_data_o                        (phy_rdst_data),
        .br_is_taken_o                          (br_is_taken),
        .alu_next_pc_o                          (alu_next_pc),
        .alu_excp_en_o                          (alu_excp_en),
        .alu_excp_o                             (alu_excp)
    );
    assign alu_bypass__data_o.en = alu_exec_en && alu_inst_exec.opcode.rdst_en
        && (alu_inst_exec.phy_rdst_index != phy_sr_index_t'(0));
    assign alu_bypass__data_o.rdst_index = alu_inst_exec.phy_rdst_index;
    assign alu_bypass__data_o.rdst_data = phy_rdst_data;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            alu_exec_en_dly1 <= 1'b0;
            alu_inst_wb <= alu_inst_t'(0);
            phy_rdst_data_wb <= data_t'(0);
            br_is_taken_wb <= 1'b0;
            alu_next_pc_wb <= pc_t'(0);
            alu_excp_en_wb <= 1'b0;
            alu_excp_wb <= INST_ADDR_MISALIGNED;
        end else begin
            alu_exec_en_dly1 <= alu_exec_en;
            alu_inst_wb <= alu_inst_exec;
            phy_rdst_data_wb <= phy_rdst_data;
            br_is_taken_wb <= br_is_taken;
            alu_next_pc_wb <= alu_next_pc;
            alu_excp_en_wb <= alu_excp_en;
            alu_excp_wb <= alu_excp;
        end
    end
    assign alu_wb_en = alu_exec_en_dly1
        && !flush_en
        && !(ckpt_rcov.en && chk_ckpt(alu_inst_wb.ckpt, ckpt_rcov.ckpt, id__prefet_ckpt_i));
    assign alu_prf__rdst_en_o = alu_wb_en && alu_inst_wb.opcode.rdst_en
        && (alu_inst_wb.phy_rdst_index != phy_sr_index_t'(0));
    assign alu_prf__rdst_index_o = alu_inst_wb.phy_rdst_index;
    assign alu_prf__rdst_data_o = phy_rdst_data_wb;
    assign alu_rob__commit_o.en = alu_wb_en;
    assign alu_rob__commit_o.rob_flag = alu_inst_wb.rob_flag;
    assign alu_rob__commit_o.rob_index = alu_inst_wb.rob_index;
    assign alu_rob__commit_o.rob_offset = alu_inst_wb.rob_offset;
    assign alu_rob__commit_o.excp_en = alu_excp_en_wb;
    assign alu_rob__commit_o.excp = alu_excp_wb;
    assign alu_rob__commit_o.is_jbr = alu_inst_wb.is_jbr;
    assign alu_rob__commit_o.next_pc = alu_next_pc_wb;
    assign alu_rob__commit_o.br_taken = br_is_taken_wb;
endmodule : hpu_alu
