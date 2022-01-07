`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_ren_rat(
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rs1_index_id0_i,
    input   arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rs2_index_id0_i,
    input   arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rdst_index_id0_i,
    output  phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rs1_index_id0_o,
    output  phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rs2_index_id0_o,
    output  phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_old_rdst_index_id0_o,
    input   logic[INST_DEC_PARAL-1 : 0]             rdst_act_id0_i,
    input   phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rdst_index_id0_i,
    input   logic                                   ckpt_save_en_id1_i,
    input   ckpt_index_t                            ckpt_save_index_id1_i,
    input   logic                                   ckpt_rcov_en_i,
    input   ckpt_index_t                            ckpt_rcov_index_i,
    input   logic                                   arat_rcov_en_i,
    input   phy_sr_index_t[ARC_SR_LEN-1 : 0]        arat_rcov_data_i
);
    phy_sr_index_t[ARC_SR_LEN-1 : 0]        rat;
    phy_sr_index_t[ARC_SR_LEN-1 : 0]        ckpt_rat[CKPT_LEN-1 : 0];
    always_ff@(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<ARC_SR_LEN; i=i+1) begin
                rat[i] <= phy_sr_index_t'(0);
            end
        end else begin
            if(arat_rcov_en_i) begin
                rat <= arat_rcov_data_i;
            end else if(ckpt_rcov_en_i) begin
                rat <= ckpt_rat[ckpt_rcov_index_i];
            end else begin
                for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
                    if(rdst_act_id0_i[i] && (arc_rdst_index_id0_i[i] != 0)) begin
                        rat[arc_rdst_index_id0_i[i]] <= phy_rdst_index_id0_i[i];
                    end
                end
            end
        end
    end
    always_comb begin
        for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
            phy_rs1_index_id0_o[i] = rat[arc_rs1_index_id0_i[i]];
            phy_rs2_index_id0_o[i] = rat[arc_rs2_index_id0_i[i]];
            phy_old_rdst_index_id0_o[i] = rat[arc_rdst_index_id0_i[i]];
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<CKPT_LEN; i=i+1) begin
                for(integer j=0; j<ARC_SR_LEN; j=j+1) begin
                    ckpt_rat[i][j] <= phy_sr_index_t'(0);
                end
            end
        end else begin
            if(ckpt_save_en_id1_i) begin
                ckpt_rat[ckpt_save_index_id1_i] <= rat;
            end
        end
    end
    logic redund;
    always @(posedge clk_i) begin
        asst_rat0: assert (rat[0] == 0);
    end
    always @(posedge clk_i) begin
        redund <= 0;
        for(int i=0; i<32; i++) begin
            for(int j=i+1; j<32; j++) begin
                if(rat[i] == rat[j] && rat[i] != 0) begin
                    redund <= 1;
                end
            end
        end
        asst_rat1: assert (redund == 0);
    end
endmodule : hpu_ren_rat
