`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_alu_iq (
    input  logic                                    clk_i,
    input  logic                                    rst_i,
    input   logic                                   flush_en_i,
    input   update_ckpt_t                           ckpt_rcov_i,
    input   ckpt_t                                  id__prefet_ckpt_i,
    input   alu_inst_t                              id_alu__inst_i,
    input   logic                                   id_alu__avail_i,
    input   sr_status_e                             id_alu__rs1_ready_i,
    input   sr_status_e                             id_alu__rs2_ready_i,
    input   logic                                   id_alu__inst_vld_i,
    output  logic                                   alu_id__inst_rdy_o,
    output  logic[ALU_IQ_INDEX : 0]                 alu_id__left_size_o,
    output  awake_index_t                           alu_iq__awake_o,
    input   awake_index_t                           alu0_iq__awake_i,
    input   awake_index_t                           alu1_iq__awake_i,
    input   awake_index_t                           mdu_iq__awake_i,
    input   awake_index_t                           lsu_iq__awake_i,
    output  logic                                   alu_en_o,
    output  alu_inst_t                              alu_inst_o,
    output  awake_index_t                           alu_prm__update_prm_o
);
    logic                                   iq_insert_en;
    logic                                   iq_delete_en;
    logic[ALU_IQ_INDEX : 0]                 rcov_addr;
    logic[ALU_IQ_INDEX : 0]                 rcov_size;
    logic[ALU_IQ_INDEX : 0]                 tail_addr;
    logic[ALU_IQ_INDEX : 0]                 left_size;
    awake_index_t                           alu0_aw;
    awake_index_t                           alu1_aw;
    awake_index_t                           mdu_aw;
    awake_index_t                           lsu_aw;
    sr_status_e                             rs1_ready[ALU_IQ_LEN-1 : 0];
    sr_status_e                             rs2_ready[ALU_IQ_LEN-1 : 0];
    alu_inst_t                              alu_iq_inst[ALU_IQ_LEN-1 : 0];
    sr_status_e                             alu_iq_rs1_ready[ALU_IQ_LEN-1 : 0];
    sr_status_e                             alu_iq_rs2_ready[ALU_IQ_LEN-1 : 0];
    logic                                   sel_active;
    logic[ALU_IQ_INDEX-1 : 0]               sel_addr;
    
    assign iq_insert_en = (id_alu__avail_i & id_alu__inst_vld_i & alu_id__inst_rdy_o);
    assign iq_delete_en = sel_active;
    always_comb begin
        rcov_addr = tail_addr;
        for(integer i=ALU_IQ_LEN-1; i>=0; i=i-1)begin
            if((i<tail_addr) && chk_ckpt(alu_iq_inst[i].ckpt, ckpt_rcov_i.ckpt, id__prefet_ckpt_i)) begin
                rcov_addr = (ALU_IQ_INDEX+1)'(i);
            end
        end
        rcov_size = ALU_IQ_LEN - rcov_addr;
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            tail_addr <= {(ALU_IQ_INDEX+1){1'b0}};
            left_size <= ALU_IQ_LEN;
        end else begin
            if(flush_en_i) begin
                tail_addr <= {(ALU_IQ_INDEX+1){1'b0}};
                left_size <= ALU_IQ_LEN;
            end else if(ckpt_rcov_i.en) begin
                if(iq_delete_en) begin
                    tail_addr <= rcov_addr - 1'b1;
                    left_size <= rcov_size + 1'b1;
                end else begin
                    tail_addr <= rcov_addr;
                    left_size <= rcov_size;
                end
            end else begin
                case({iq_insert_en, iq_delete_en})
                    2'b10: begin
                        tail_addr <= tail_addr + 1'b1;
                        left_size <= left_size - 1'b1;
                    end
                    2'b01: begin
                        tail_addr <= tail_addr - 1'b1;
                        left_size <= left_size + 1'b1;
                    end
                endcase
            end
        end
    end
    assign alu_id__inst_rdy_o = (tail_addr != ALU_IQ_LEN);
    assign alu_id__left_size_o = left_size;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<ALU_IQ_LEN; i=i+1)begin
                alu_iq_inst[i] <= alu_inst_t'(0);
            end
        end else begin
            for(integer i=0; i<ALU_IQ_LEN; i=i+1)begin
                if(iq_delete_en) begin
                    if(i >= sel_addr && i<tail_addr-1 && i<ALU_IQ_LEN-1) begin
                        alu_iq_inst[i] <= alu_iq_inst[i+1];
                    end else if(i == tail_addr-1) begin
                        alu_iq_inst[i] <= id_alu__inst_i;
                    end
                end else begin
                    if (i == tail_addr) begin
                        alu_iq_inst[i] <= id_alu__inst_i;
                    end
                end
            end
        end
    end
    assign alu0_aw = alu0_iq__awake_i;
    assign alu1_aw = alu1_iq__awake_i;
    assign mdu_aw = mdu_iq__awake_i;
    assign lsu_aw = lsu_iq__awake_i;
    always_comb begin
        for(integer i=0; i<ALU_IQ_LEN; i=i+1) begin
            if(i == tail_addr) begin
                rs1_ready[i] = id_alu__rs1_ready_i;
                if((alu0_aw.en && (alu0_aw.rdst_index == id_alu__inst_i.phy_rs1_index))
                    || (alu1_aw.en && (alu1_aw.rdst_index == id_alu__inst_i.phy_rs1_index))
                    || (mdu_aw.en && (mdu_aw.rdst_index == id_alu__inst_i.phy_rs1_index))
                    || (lsu_aw.en && (lsu_aw.rdst_index == id_alu__inst_i.phy_rs1_index))) begin
                    rs1_ready[i] = READY;
                end
            end else begin
                rs1_ready[i] = alu_iq_rs1_ready[i];
                if((alu0_aw.en && (alu0_aw.rdst_index == alu_iq_inst[i].phy_rs1_index))
                    || (alu1_aw.en && (alu1_aw.rdst_index == alu_iq_inst[i].phy_rs1_index))
                    || (mdu_aw.en && (mdu_aw.rdst_index == alu_iq_inst[i].phy_rs1_index))
                    || (lsu_aw.en && (lsu_aw.rdst_index == alu_iq_inst[i].phy_rs1_index))) begin
                    rs1_ready[i] = READY;
                end
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<ALU_IQ_LEN; i=i+1) begin
                alu_iq_rs1_ready[i] <= FLY;
            end
        end else begin
            for(integer i=0; i<ALU_IQ_LEN; i=i+1) begin
                if(iq_delete_en && (i >= sel_addr) && (i < ALU_IQ_LEN-1)) begin
                    alu_iq_rs1_ready[i] <= rs1_ready[i+1];
                end else begin
                    alu_iq_rs1_ready[i] <= rs1_ready[i];
                end
            end
        end
    end
    always_comb begin
        for(integer i=0; i<ALU_IQ_LEN; i=i+1) begin
            if(i == tail_addr) begin
                rs2_ready[i] = id_alu__rs2_ready_i;
                if((alu0_aw.en && (alu0_aw.rdst_index == id_alu__inst_i.phy_rs2_index))
                    || (alu1_aw.en && (alu1_aw.rdst_index == id_alu__inst_i.phy_rs2_index))
                    || (mdu_aw.en && (mdu_aw.rdst_index == id_alu__inst_i.phy_rs2_index))
                    || (lsu_aw.en && (lsu_aw.rdst_index == id_alu__inst_i.phy_rs2_index))) begin
                    rs2_ready[i] = READY;
                end
            end else begin
                rs2_ready[i] = alu_iq_rs2_ready[i];
                if((alu0_aw.en && (alu0_aw.rdst_index == alu_iq_inst[i].phy_rs2_index))
                    || (alu1_aw.en && (alu1_aw.rdst_index == alu_iq_inst[i].phy_rs2_index))
                    || (mdu_aw.en && (mdu_aw.rdst_index == alu_iq_inst[i].phy_rs2_index))
                    || (lsu_aw.en && (lsu_aw.rdst_index == alu_iq_inst[i].phy_rs2_index))) begin
                    rs2_ready[i] = READY;
                end
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<ALU_IQ_LEN; i=i+1) begin
                alu_iq_rs2_ready[i] <= FLY;
            end
        end else begin
            for(integer i=0; i<ALU_IQ_LEN; i=i+1) begin
                if(iq_delete_en && (i >= sel_addr) && (i < ALU_IQ_LEN-1)) begin
                    alu_iq_rs2_ready[i] <= rs2_ready[i+1];
                end else begin
                    alu_iq_rs2_ready[i] <= rs2_ready[i];
                end
            end
        end
    end
    always_comb begin
        sel_active = 1'b0;
        sel_addr = ALU_IQ_INDEX'(0);
        for(integer i=ALU_IQ_LEN-1; i>=0; i=i-1) begin
            if( (i < tail_addr) && (alu_iq_rs1_ready[i] == READY) && (alu_iq_rs2_ready[i] == READY) ) begin
                sel_addr = ALU_IQ_INDEX'(i);
                sel_active = 1'b1;
            end
        end
        if( flush_en_i
            || (ckpt_rcov_i.en && (chk_ckpt(alu_iq_inst[sel_addr].ckpt, ckpt_rcov_i.ckpt, id__prefet_ckpt_i)))) begin
            sel_active = 1'b0;
        end
    end
    assign alu_iq__awake_o.en = sel_active && alu_iq_inst[sel_addr].opcode.rdst_en;
    assign alu_iq__awake_o.rdst_index = alu_iq_inst[sel_addr].phy_rdst_index;
    assign alu_prm__update_prm_o = alu_iq__awake_o;
    assign alu_en_o = sel_active;
    assign alu_inst_o = alu_iq_inst[sel_addr];
endmodule : hpu_alu_iq
