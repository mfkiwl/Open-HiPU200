`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_lsu_iq (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   flush_en_i,
    input   update_ckpt_t                           ckpt_rcov_i,
    input   ckpt_t                                  id__prefet_ckpt_i,
    input   lsu_inst_t[INST_DEC_PARAL-1 : 0]        id_lsu__inst_i,
    input   logic[INST_DEC_PARAL-1 : 0]             id_lsu__avail_i,
    input   sr_status_e[INST_DEC_PARAL-1 : 0]       id_lsu__rs1_ready_i,
    input   sr_status_e[INST_DEC_PARAL-1 : 0]       id_lsu__rs2_ready_i,
    output  logic[LSU_IQ_INDEX : 0]                 lsu_id__left_size_o,
    input   logic                                   id_lsu__inst_vld_i,
    output  logic                                   lsu_id__inst_rdy_o,
    input   awake_index_t                           alu0_iq__awake_i,
    input   awake_index_t                           alu1_iq__awake_i,
    input   awake_index_t                           mdu_iq__awake_i,
    input   awake_index_t                           laq_awake_i,
    output  logic                                   lsu_en_o,
    output  lsu_inst_t                              lsu_inst_o,
    input   logic                                   lsq_stall_i
);
    lsu_inst_t                              lsu_iq_inst[LSU_IQ_LEN-1 : 0];
    logic[LSU_IQ_INDEX-1 : 0]               ins_addr[INST_DEC_PARAL-1 : 0];
    sr_status_e                             lsu_iq_rs1_ready[LSU_IQ_LEN-1 : 0];
    sr_status_e                             lsu_iq_rs2_ready[LSU_IQ_LEN-1 : 0];
    logic                                   iq_full, iq_empty;
    logic[INST_DEC_PARAL-1 : 0]             iq_item_insert_en;
    logic[INST_DEC_BIT : 0]                 insert_psum[INST_DEC_PARAL-1 : 0];
    logic[INST_DEC_BIT : 0]                 insert_sum;
    logic                                   rcov_flag, insert_flag, delete_flag;
    logic[LSU_IQ_INDEX-1 : 0]               rcov_addr, insert_addr, delete_addr;
    logic                                   iq_item_delete_en;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<LSU_IQ_LEN; i=i+1) begin
                lsu_iq_inst[i] <= lsu_inst_t'(0);
            end
        end else begin
            for(integer i=0; i<LSU_IQ_LEN; i=i+1) begin
                for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                    if(iq_item_insert_en[j] && (LSU_IQ_INDEX'(insert_addr+$unsigned(j)) == $unsigned(i))) begin
                        lsu_iq_inst[i] <= id_lsu__inst_i[j];
                    end
                end
            end
        end
    end
    always_comb begin
        for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
            ins_addr[i] = insert_addr + i[LSU_IQ_INDEX-1 : 0];
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<LSU_IQ_LEN; i=i+1) begin
                lsu_iq_rs1_ready[i] <= FLY;
                lsu_iq_rs2_ready[i] <= FLY;
            end
        end else begin
            for(integer i=0; i<LSU_IQ_LEN; i=i+1) begin
                if( (alu0_iq__awake_i.en && (alu0_iq__awake_i.rdst_index == lsu_iq_inst[i].phy_rs1_index))
                    || (alu1_iq__awake_i.en && (alu1_iq__awake_i.rdst_index == lsu_iq_inst[i].phy_rs1_index))
                    || (mdu_iq__awake_i.en && (mdu_iq__awake_i.rdst_index == lsu_iq_inst[i].phy_rs1_index))
                    || (laq_awake_i.en && (laq_awake_i.rdst_index == lsu_iq_inst[i].phy_rs1_index)) ) begin
                    lsu_iq_rs1_ready[i] <= READY;
                end
                if( (alu0_iq__awake_i.en && (alu0_iq__awake_i.rdst_index == lsu_iq_inst[i].phy_rs2_index))
                    || (alu1_iq__awake_i.en && (alu1_iq__awake_i.rdst_index == lsu_iq_inst[i].phy_rs2_index))
                    || (mdu_iq__awake_i.en && (mdu_iq__awake_i.rdst_index == lsu_iq_inst[i].phy_rs2_index))
                    || (laq_awake_i.en && (laq_awake_i.rdst_index == lsu_iq_inst[i].phy_rs2_index)) ) begin
                    lsu_iq_rs2_ready[i] <= READY;
                end
                for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                    if(iq_item_insert_en[j] && (ins_addr[j] == i[LSU_IQ_INDEX-1 : 0])) begin
                        lsu_iq_rs1_ready[i] <= id_lsu__rs1_ready_i[j];
                        lsu_iq_rs2_ready[i] <= id_lsu__rs2_ready_i[j];
                    end
                end
            end
        end
    end
    assign iq_full = {~insert_flag, insert_addr} == {delete_flag, delete_addr};
    assign iq_empty = {insert_flag, insert_addr} == {delete_flag, delete_addr};
    assign lsu_id__left_size_o = {1'b1, delete_addr} - {delete_flag^insert_flag, insert_addr};
    assign lsu_id__inst_rdy_o = (lsu_id__left_size_o >= 2);
    always_comb begin
        for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
            iq_item_insert_en[i] = id_lsu__avail_i[i] & id_lsu__inst_vld_i & lsu_id__inst_rdy_o;
        end
        insert_psum[0] = iq_item_insert_en[0];
        for(integer i=1; i<INST_DEC_PARAL; i=i+1) begin
            insert_psum[i] = insert_psum[i-1] + {{INST_DEC_BIT{1'b0}}, iq_item_insert_en[i]};
        end
    end
    assign insert_sum = insert_psum[INST_DEC_PARAL-1];
    always_comb begin
        {rcov_flag, rcov_addr} = {insert_flag, insert_addr};
        for(integer i=LSU_IQ_LEN*2-1; i>=0; i=i-1) begin
            if( (chk_ckpt(lsu_iq_inst[i[LSU_IQ_INDEX-1 : 0]].ckpt, ckpt_rcov_i.ckpt, id__prefet_ckpt_i))
                && (i >= {1'b0, delete_addr})
                && (i < {insert_flag^delete_flag, insert_addr})
            ) begin
                {rcov_flag, rcov_addr} = {i[LSU_IQ_INDEX]^delete_flag, i[LSU_IQ_INDEX-1 : 0]};
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            insert_addr <= {LSU_IQ_INDEX{1'b0}};
            insert_flag <= 1'b0;
        end else begin
            if(flush_en_i) begin
                {insert_flag, insert_addr} <= {(LSU_IQ_INDEX+1){1'b0}};
            end else if(ckpt_rcov_i.en) begin
                {insert_flag, insert_addr} <= {rcov_flag, rcov_addr};
            end else begin
                {insert_flag, insert_addr} <= {insert_flag, insert_addr} + {{(LSU_IQ_INDEX-INST_DEC_BIT){1'b0}}, insert_sum};
            end
        end
    end
    assign iq_item_delete_en = lsu_en_o & !lsq_stall_i;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            delete_addr <= {LSU_IQ_INDEX{1'b0}};
            delete_flag <= 1'b0;
        end else begin
            if(flush_en_i) begin
                {delete_flag, delete_addr} <= {(LSU_IQ_INDEX+1){1'b0}};
            end else if(iq_item_delete_en) begin
                {delete_flag, delete_addr} <= {delete_flag, delete_addr} + 1'b1;
            end
        end
    end
    assign lsu_en_o = !iq_empty && lsu_iq_rs1_ready[delete_addr] && lsu_iq_rs2_ready[delete_addr]
        && !flush_en_i
        && !(ckpt_rcov_i.en && ({delete_flag, delete_addr} == {rcov_flag, rcov_addr}));
    assign lsu_inst_o = lsu_iq_inst[delete_addr];
endmodule : hpu_lsu_iq
