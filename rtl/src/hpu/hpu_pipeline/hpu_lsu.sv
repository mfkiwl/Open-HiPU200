`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_lsu (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   ctrl__inst_flush_en_i,
    input   update_ckpt_t                           id__ckpt_rcov_i,
    output  logic                                   lsu_ctrl__sq_retire_empty_o,
    input   ckpt_t                                  id__prefet_ckpt_i,
    input   lsu_inst_t[INST_DEC_PARAL-1 : 0]        id_lsu__inst_i,
    input   logic[INST_DEC_PARAL-1 : 0]             id_lsu__avail_i,
    input   sr_status_e[INST_DEC_PARAL-1 : 0]       id_lsu__rs1_ready_i,
    input   sr_status_e[INST_DEC_PARAL-1 : 0]       id_lsu__rs2_ready_i,
    input   logic                                   id_lsu__inst_vld_i,
    output  logic                                   lsu_id__inst_rdy_o,
    output  logic[LSU_IQ_INDEX : 0]                 lsu_id__left_size_o,
    output  lsu_commit_t                            lsu_rob__ld_commit_o,
    output  lsu_commit_t                            lsu_rob__ste_commit_o,
    input   lsu_retire_t                            rob_lsu__st_retire_i,
    output  phy_sr_index_t                          lsu_prf__rs1_index_o,
    input   data_t                                  prf_lsu__rs1_data_i,
    output  phy_sr_index_t                          lsu_prf__rs2_index_o,
    input   data_t                                  prf_lsu__rs2_data_i,
    output  phy_sr_index_t                          lsu_prf__rdst_index_o,
    output  logic                                   lsu_prf__rdst_en_o,
    output  data_t                                  lsu_prf__rdst_data_o,
    output  mem_wr_req_t                            lsu_mem__wr_req_o,
    input   mem_wr_rsp_t                            mem_lsu__wr_rsp_i,
    output  mem_rd_req_t                            lsu_mem__rd_req_o,
    input   mem_rd_rsp_t                            mem_lsu__rd_rsp_i,
    output  csr_bus_req_t                           lsu_csr__bus_req_o,
    input   csr_bus_rsp_t                           csr_lsu__bus_rsp_i,
    output  awake_index_t                           lsu_iq__awake_o,
    input   awake_index_t                           alu0_iq__awake_i,
    input   awake_index_t                           alu1_iq__awake_i,
    input   awake_index_t                           mdu_iq__awake_i,
    input   bypass_data_t                           alu0_bypass__data_i,
    input   bypass_data_t                           alu1_bypass__data_i,
    output  awake_index_t                           lsu_prm__update_prm_o
);
    logic                                   flush_en;
    update_ckpt_t                           ckpt_rcov;
    logic                                   lsu_en;
    lsu_inst_t                              lsu_inst;
    logic                                   lsu_en_ff;
    lsu_inst_t                              lsu_inst_reg;
    phy_sr_index_t                          phy_rs1_index_reg;
    phy_sr_index_t                          phy_rs2_index_reg;
    logic                                   lsq_stall_ff;
    data_t                                  phy_rs1_data_reg_ff;
    data_t                                  phy_rs2_data_reg_ff;
    data_t                                  phy_rs1_data_reg;
    data_t                                  phy_rs2_data_reg;
    logic                                   lsu_reg_en;
    data_t                                  bypass_rs1_data;
    data_t                                  bypass_rs2_data;
    logic                                   lsu_reg_en_ff;
    lsu_inst_t                              lsu_inst_ag;
    data_t                                  bypass_rs1_data_ag;
    data_t                                  bypass_rs2_data_ag;
    logic                                   lsu_ag_en;
    logic                                   laq_cmd_en;
    laq_item_t                              laq_cmd;
    logic                                   sq_cmd_en;
    sq_item_t                               sq_cmd;
    pc_t                                    chk_dpend_addr;
    data_t                                  chk_dpend_data;
    lsu_acc_type_e                          chk_dpend_type;
    data_strobe_t                           chk_dpend_strb;
    logic                                   misalign_act;
    logic                                   lsq_stall;
    logic                                   laq_cmd_ins;
    logic                                   sq_cmd_ins;
    logic                                   laq_full;
    logic[LAQ_INDEX-1 : 0]                  laq_ins_index;
    awake_index_t                           laq_awake;
    logic                                   ld_dpend_avail;
    logic[LAQ_INDEX-1 : 0]                  ld_dpend_index;
    logic                                   update_sq_en;
    logic[SQ_INDEX-1 : 0]                   update_sq_index;
    data_t                                  update_sq_data;
    logic                                   acqlock_amo_en;
    logic[LAQ_INDEX-1 : 0]                  acqlock_amo_index;
    logic                                   shortcut_en;
    logic[SQ_INDEX-1 : 0]                   shortcut_index;
    logic                                   sq_full;
    logic[SQ_INDEX-1 : 0]                   sq_ins_index;
    logic                                   st_dpend_avail;
    logic[SQ_INDEX-1 : 0]                   st_dpend_index;
    logic                                   st_dpend_fwd;
    logic                                   rmv_sq_dpend_en;
    logic[SQ_INDEX-1 : 0]                   rmv_sq_dpend_index;
    logic                                   awake_amo_en;
    logic[LAQ_INDEX-1 : 0]                  awake_amo_index;
    logic                                   delete_order_en;
    logic[LAQ_INDEX-1 : 0]                  delete_order_index;
    logic                                   shortcut_rd_suc;
    data_t                                  shortcut_rdata;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            flush_en <= 1'b0;
            ckpt_rcov <= update_ckpt_t'(0);
        end else begin
            flush_en <= ctrl__inst_flush_en_i;
            ckpt_rcov <= id__ckpt_rcov_i;
        end
    end
    hpu_lsu_iq   hpu_lsu_iq_inst (
        .clk_i                                  (clk_i),
        .rst_i                                  (rst_i),
        .flush_en_i                             (flush_en),
        .ckpt_rcov_i                            (ckpt_rcov),
        .id__prefet_ckpt_i                      (id__prefet_ckpt_i),
        .id_lsu__inst_i                         (id_lsu__inst_i),
        .id_lsu__avail_i                        (id_lsu__avail_i),
        .id_lsu__rs1_ready_i                    (id_lsu__rs1_ready_i),
        .id_lsu__rs2_ready_i                    (id_lsu__rs2_ready_i),
        .lsu_id__left_size_o                    (lsu_id__left_size_o),
        .id_lsu__inst_vld_i                     (id_lsu__inst_vld_i),
        .lsu_id__inst_rdy_o                     (lsu_id__inst_rdy_o),
        .alu0_iq__awake_i                       (alu0_iq__awake_i),
        .alu1_iq__awake_i                       (alu1_iq__awake_i),
        .mdu_iq__awake_i                        (mdu_iq__awake_i),
        .laq_awake_i                            (laq_awake),
        .lsu_en_o                               (lsu_en),
        .lsu_inst_o                             (lsu_inst),
        .lsq_stall_i                            (lsq_stall)
    );
    assign lsu_prf__rs1_index_o = lsu_inst.phy_rs1_index;
    assign lsu_prf__rs2_index_o = lsu_inst.phy_rs2_index;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            lsu_en_ff <= 1'b0;
            lsu_inst_reg <= lsu_inst_t'(0);
            phy_rs1_index_reg <= phy_sr_index_t'(0);
            phy_rs2_index_reg <= phy_sr_index_t'(0);
            lsq_stall_ff <= 1'b0;
            phy_rs1_data_reg_ff <= data_t'(0);
            phy_rs2_data_reg_ff <= data_t'(0);
        end else begin
            lsu_en_ff <= lsq_stall ? lsu_reg_en : lsu_en;
            if(!lsq_stall) begin
                lsu_inst_reg <= lsu_inst;
                phy_rs1_index_reg <= lsu_inst.phy_rs1_index;
                phy_rs2_index_reg <= lsu_inst.phy_rs2_index;
            end
            lsq_stall_ff <= lsq_stall;
            phy_rs1_data_reg_ff <= bypass_rs1_data;
            phy_rs2_data_reg_ff <= bypass_rs2_data;
        end
    end
    assign phy_rs1_data_reg = lsq_stall_ff ? phy_rs1_data_reg_ff : prf_lsu__rs1_data_i;
    assign phy_rs2_data_reg = lsq_stall_ff ? phy_rs2_data_reg_ff : prf_lsu__rs2_data_i;
    assign lsu_reg_en = lsu_en_ff
        && !flush_en
        && !(ckpt_rcov.en && chk_ckpt(lsu_inst_reg.ckpt, ckpt_rcov.ckpt, id__prefet_ckpt_i));
    hpu_lsu_bypass hpu_lsu_bypass_inst (
        .alu0_bypass__data_i                    (alu0_bypass__data_i),
        .alu1_bypass__data_i                    (alu1_bypass__data_i),
        .phy_rs1_index_reg_i                    (phy_rs1_index_reg),
        .phy_rs1_data_reg_i                     (phy_rs1_data_reg),
        .bypass_rs1_data_o                      (bypass_rs1_data),
        .phy_rs2_index_reg_i                    (phy_rs2_index_reg),
        .phy_rs2_data_reg_i                     (phy_rs2_data_reg),
        .bypass_rs2_data_o                      (bypass_rs2_data)
    );
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            lsu_reg_en_ff <= 1'b0;
            lsu_inst_ag <= lsu_inst_t'(0);
            bypass_rs1_data_ag <= data_t'(0);
            bypass_rs2_data_ag <= data_t'(0);
        end else begin
            lsu_reg_en_ff <= lsq_stall ? lsu_ag_en : lsu_reg_en;
            if(!lsq_stall) begin
                lsu_inst_ag <= lsu_inst_reg;
                bypass_rs1_data_ag <= bypass_rs1_data;
                bypass_rs2_data_ag <= bypass_rs2_data;
            end
        end
    end
    assign lsu_ag_en = lsu_reg_en_ff
        && !flush_en
        && !(ckpt_rcov.en && chk_ckpt(lsu_inst_ag.ckpt, ckpt_rcov.ckpt, id__prefet_ckpt_i));
    always_comb begin
        laq_cmd_en = 1'b0;
        laq_cmd.ld_type = laq_type_e'(0);
        laq_cmd.ld_size = lsu_inst_ag.opcode.ls_size;
        laq_cmd.is_unsigned = lsu_inst_ag.opcode.is_unsigned;
        laq_cmd.order_pred = lsu_inst_ag.opcode.predecessor[1];
        laq_cmd.order_succ = lsu_inst_ag.opcode.successor[1];
        laq_cmd.ld_dpend_avail = ld_dpend_avail;
        laq_cmd.ld_dpend_index = ld_dpend_index;
        laq_cmd.st_dpend_avail = st_dpend_avail;
        laq_cmd.st_dpend_index = st_dpend_index;
        laq_cmd.st_dpend_fwd = st_dpend_fwd;
        laq_cmd.crsp_sq_avail = 1'b1;
        laq_cmd.crsp_sq_index = sq_ins_index;
        laq_cmd.phy_rdst_index = lsu_inst_ag.phy_rdst_index;
        laq_cmd.rob_index = lsu_inst_ag.rob_index;
        laq_cmd.rob_offset = lsu_inst_ag.rob_offset;
        laq_cmd.ckpt = lsu_inst_ag.ckpt;
        sq_cmd_en = 1'b0;
        sq_cmd.st_type = saq_type_e'(0);
        sq_cmd.atom_func = lsu_inst_ag.opcode.atom_func;
        sq_cmd.csr_func = lsu_inst_ag.opcode.csr_func;
        sq_cmd.data_rdy = 1'b0;
        sq_cmd.order_pred = lsu_inst_ag.opcode.predecessor[0];
        sq_cmd.order_succ = lsu_inst_ag.opcode.successor[0];
        sq_cmd.st_dpend_avail = st_dpend_avail;
        sq_cmd.st_dpend_index = st_dpend_index;
        sq_cmd.crsp_laq_index = laq_ins_index;
        sq_cmd.ckpt = lsu_inst_ag.ckpt;
        chk_dpend_addr = bypass_rs1_data_ag;
        chk_dpend_data = bypass_rs2_data_ag;
        chk_dpend_type = ACC_MEM;
        case(lsu_inst_ag.opcode.optype)
            LOAD: begin
                laq_cmd_en = lsu_ag_en;
                laq_cmd.ld_type = LAQ_LD;
                chk_dpend_addr = bypass_rs1_data_ag + lsu_inst_ag.opcode.imm;
                chk_dpend_type = ACC_MEM;
            end
            STORE: begin
                sq_cmd_en = lsu_ag_en;
                sq_cmd.st_type = SAQ_ST;
                sq_cmd.data_rdy = 1'b1;
                chk_dpend_addr = bypass_rs1_data_ag + lsu_inst_ag.opcode.imm;
                chk_dpend_type = ACC_MEM;
            end
            ATOM: begin
                laq_cmd_en = lsu_ag_en;
                laq_cmd.ld_type = LAQ_AMO;
                sq_cmd_en = lsu_ag_en;
                sq_cmd.st_type = SAQ_AMO;
                chk_dpend_addr = bypass_rs1_data_ag;
                chk_dpend_type = ACC_MEM;
            end
            CSR: begin
                laq_cmd_en = lsu_ag_en && !lsu_inst_ag.opcode.csr_re_mask;
                laq_cmd.ld_type = LAQ_CSR;
                laq_cmd.crsp_sq_avail = !lsu_inst_ag.opcode.csr_we_mask;
                sq_cmd_en = lsu_ag_en && !lsu_inst_ag.opcode.csr_we_mask;
                sq_cmd.st_type = SAQ_CSR;
                sq_cmd.data_rdy = lsu_inst_ag.opcode.csr_re_mask;
                chk_dpend_data = lsu_inst_ag.opcode.with_imm ? lsu_inst_ag.opcode.imm : bypass_rs1_data_ag;
                chk_dpend_addr = pc_t'({lsu_inst_ag.opcode.csr_addr, 2'h0});
                chk_dpend_type = ACC_CSR;
            end
            FENCE: begin
                laq_cmd_en = lsu_ag_en;
                laq_cmd.ld_type = LAQ_FENCE;
                sq_cmd_en = lsu_ag_en;
                sq_cmd.st_type = SAQ_FENCE;
            end
        endcase
        laq_cmd.addr = chk_dpend_addr;
        sq_cmd.addr = chk_dpend_addr;
        chk_dpend_strb = data_strobe_t'(0);
        misalign_act = 1'b0;
        sq_cmd.data = chk_dpend_data;
        case(lsu_inst_ag.opcode.ls_size)
            BYTE: begin
                case(chk_dpend_addr[1:0])
                    2'b00: begin chk_dpend_strb = 4'h1; sq_cmd.data = data_t'(chk_dpend_data[7 : 0]); end
                    2'b01: begin chk_dpend_strb = 4'h2; sq_cmd.data = data_t'({chk_dpend_data[7 : 0],8'h0}); end
                    2'b10: begin chk_dpend_strb = 4'h4; sq_cmd.data = data_t'({chk_dpend_data[7 : 0],16'h0}); end
                    2'b11: begin chk_dpend_strb = 4'h8; sq_cmd.data = data_t'({chk_dpend_data[7 : 0],24'h0}); end
                endcase
            end
            HALF: begin
                case(chk_dpend_addr[1:0])
                    2'b00: begin chk_dpend_strb = 4'h3; sq_cmd.data = data_t'(chk_dpend_data[15 : 0]); end
                    2'b01: begin chk_dpend_strb = 4'h6; sq_cmd.data = data_t'({chk_dpend_data[15 : 0],8'h0}); end
                    2'b10: begin chk_dpend_strb = 4'hc; sq_cmd.data = data_t'({chk_dpend_data[15 : 0],16'h0}); end
                    2'b11: misalign_act = lsu_ag_en;
                endcase
            end
            WORD: begin
                case(chk_dpend_addr[1:0])
                    2'b00: begin chk_dpend_strb = 4'hf; sq_cmd.data = chk_dpend_data; end
                    2'b01: misalign_act = lsu_ag_en;
                    2'b10: misalign_act = lsu_ag_en;
                    2'b11: misalign_act = lsu_ag_en;
                endcase
            end
        endcase
        laq_cmd.strb = chk_dpend_strb;
        sq_cmd.strb = chk_dpend_strb;
    end
    assign lsu_rob__ste_commit_o.en = ((sq_cmd_en && sq_cmd.data_rdy) || misalign_act) && !lsq_stall;
    assign lsu_rob__ste_commit_o.rob_index = lsu_inst_ag.rob_index;
    assign lsu_rob__ste_commit_o.rob_offset = lsu_inst_ag.rob_offset;
    assign lsu_rob__ste_commit_o.excp_en = misalign_act;
    assign lsu_rob__ste_commit_o.excp = INST_ADDR_MISALIGNED;
    assign lsu_rob__ste_commit_o.is_ldst = sq_cmd_en && (sq_cmd.st_type == SAQ_ST);
    assign lsu_rob__ste_commit_o.ldst_addr = sq_cmd.addr;
    assign lsu_rob__ste_commit_o.ldst_data = sq_cmd.data;
    assign lsq_stall = (laq_full | sq_full) & ~misalign_act;
    assign laq_cmd_ins = laq_cmd_en & ~misalign_act & !lsq_stall;
    assign sq_cmd_ins = sq_cmd_en & ~misalign_act & !lsq_stall;
    hpu_lsu_laq hpu_lsu_laq_inst (
        .clk_i                                  (clk_i),
        .rst_i                                  (rst_i),
        .flush_en_i                             (flush_en),
        .ckpt_rcov_i                            (ckpt_rcov),
        .id__prefet_ckpt_i                      (id__prefet_ckpt_i),
        .laq_cmd_ins_i                          (laq_cmd_ins),
        .laq_cmd_i                              (laq_cmd),
        .laq_full_o                             (laq_full),
        .laq_ins_index_o                        (laq_ins_index),
        .lsu_rob__ld_commit_o                   (lsu_rob__ld_commit_o),
        .laq_awake_o                            (laq_awake),
        .lsu_prf__rdst_index_o                  (lsu_prf__rdst_index_o),
        .lsu_prf__rdst_en_o                     (lsu_prf__rdst_en_o),
        .lsu_prf__rdst_data_o                   (lsu_prf__rdst_data_o),
        .chk_dpend_addr_i                       (chk_dpend_addr),
        .chk_dpend_strb_i                       (chk_dpend_strb),
        .chk_dpend_type_i                       (chk_dpend_type),
        .ld_dpend_avail_o                       (ld_dpend_avail),
        .ld_dpend_index_o                       (ld_dpend_index),
        .rmv_sq_dpend_en_i                      (rmv_sq_dpend_en),
        .rmv_sq_dpend_index_i                   (rmv_sq_dpend_index),
        .update_sq_en_o                         (update_sq_en),
        .update_sq_index_o                      (update_sq_index),
        .update_sq_data_o                       (update_sq_data),
        .awake_amo_en_i                         (awake_amo_en),
        .awake_amo_index_i                      (awake_amo_index),
        .delete_order_en_i                      (delete_order_en),
        .delete_order_index_i                   (delete_order_index),
        .acqlock_amo_en_o                       (acqlock_amo_en),
        .acqlock_amo_index_o                    (acqlock_amo_index),
        .shortcut_en_o                          (shortcut_en),
        .shortcut_index_o                       (shortcut_index),
        .shortcut_rd_suc_i                      (shortcut_rd_suc),
        .shortcut_rdata_i                       (shortcut_rdata),
        .lsu_mem__rd_req_o                      (lsu_mem__rd_req_o),
        .mem_lsu__rd_rsp_i                      (mem_lsu__rd_rsp_i),
        .lsu_csr__rd_en_o                       (lsu_csr__bus_req_o.rd_en),
        .lsu_csr__raddr_o                       (lsu_csr__bus_req_o.raddr),
        .csr_lsu__rdata_i                       (csr_lsu__bus_rsp_i.rdata)
    );
    assign lsu_iq__awake_o = laq_awake;
    assign lsu_prm__update_prm_o = laq_awake;
    hpu_lsu_sq hpu_lsu_sq_inst (
        .clk_i                                  (clk_i),
        .rst_i                                  (rst_i),
        .flush_en_i                             (flush_en),
        .ckpt_rcov_i                            (ckpt_rcov),
        .lsu_ctrl__sq_retire_empty_o            (lsu_ctrl__sq_retire_empty_o),
        .id__prefet_ckpt_i                      (id__prefet_ckpt_i),
        .sq_cmd_ins_i                           (sq_cmd_ins),
        .sq_cmd_i                               (sq_cmd),
        .sq_full_o                              (sq_full),
        .sq_ins_index_o                         (sq_ins_index),
        .rob_lsu__st_retire_i                   (rob_lsu__st_retire_i),
        .chk_dpend_addr_i                       (chk_dpend_addr),
        .chk_dpend_strb_i                       (chk_dpend_strb),
        .chk_dpend_type_i                       (chk_dpend_type),
        .st_dpend_avail_o                       (st_dpend_avail),
        .st_dpend_index_o                       (st_dpend_index),
        .st_dpend_fwd_o                         (st_dpend_fwd),
        .rmv_sq_dpend_en_o                      (rmv_sq_dpend_en),
        .rmv_sq_dpend_index_o                   (rmv_sq_dpend_index),
        .update_sq_en_i                         (update_sq_en),
        .update_sq_index_i                      (update_sq_index),
        .update_sq_data_i                       (update_sq_data),
        .awake_amo_en_o                         (awake_amo_en),
        .awake_amo_index_o                      (awake_amo_index),
        .acqlock_amo_en_i                       (acqlock_amo_en),
        .acqlock_amo_index_i                    (acqlock_amo_index),
        .delete_order_en_o                      (delete_order_en),
        .delete_order_index_o                   (delete_order_index),
        .shortcut_en_i                          (shortcut_en),
        .shortcut_index_i                       (shortcut_index),
        .shortcut_rd_suc_o                      (shortcut_rd_suc),
        .shortcut_rdata_o                       (shortcut_rdata),
        .lsu_mem__wr_req_o                      (lsu_mem__wr_req_o),
        .mem_lsu__wr_rsp_i                      (mem_lsu__wr_rsp_i),
        .lsu_csr__wr_en_o                       (lsu_csr__bus_req_o.wr_en),
        .lsu_csr__waddr_o                       (lsu_csr__bus_req_o.waddr),
        .lsu_csr__wdata_o                       (lsu_csr__bus_req_o.wdata),
        .lsu_csr__wstrb_o                       (lsu_csr__bus_req_o.wstrb)
    );
endmodule : hpu_lsu
