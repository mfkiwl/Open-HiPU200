`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_prm (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   ctrl__inst_flush_en_i,
    input   update_ckpt_t                           id__ckpt_rcov_i,
    input   ckpt_t                                  id__prefet_ckpt_i,
    input   logic[INST_DEC_PARAL-1 : 0]             id_prm__rdst_en_i,
    input   phy_sr_index_t[INST_DEC_PARAL-1 : 0]    id_prm__phy_rdst_index_i,
    input   ckpt_t[INST_DEC_PARAL-1 : 0]            id_prm__ckpt_i,
    input   phy_sr_index_t[INST_DEC_PARAL-1 : 0]    id_prm__phy_rs1_index_i,
    output  sr_status_e[INST_DEC_PARAL-1 : 0]       prm_id__phy_rs1_ready_o,
    input   phy_sr_index_t[INST_DEC_PARAL-1 : 0]    id_prm__phy_rs2_index_i,
    output  sr_status_e[INST_DEC_PARAL-1 : 0]       prm_id__phy_rs2_ready_o,
    input   awake_index_t                           alu0_prm__update_prm_i,
    input   awake_index_t                           alu1_prm__update_prm_i,
    input   awake_index_t                           mdu_prm__update_prm_i,
    input   awake_index_t                           lsu_prm__update_prm_i
);
    logic                                   flush_en;
    update_ckpt_t                           rcov;
    ckpt_t                                  prm_ckpt[0 : PHY_SR_LEN-1];
    sr_status_e                             prm_mark[0 : PHY_SR_LEN-1];
    ckpt_t                                  rcov_ckpt;
    ckpt_t                                  pref_ckpt;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            flush_en <= 1'b0;
            rcov <= update_ckpt_t'(0);
        end else begin
            flush_en <= ctrl__inst_flush_en_i;
            rcov <= id__ckpt_rcov_i;
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<PHY_SR_LEN; i=i+1) begin
                prm_ckpt[i] <= ckpt_t'(0);
            end
        end else begin
            for(integer i=1; i<PHY_SR_LEN; i=i+1) begin
                for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                    if(id_prm__rdst_en_i[j] && (id_prm__phy_rdst_index_i[j] == i)) begin
                        prm_ckpt[i] <= id_prm__ckpt_i[j];
                    end
                end
            end
            prm_ckpt[0] <= ckpt_t'(0);
        end
    end
    assign rcov_ckpt = rcov.ckpt;
    assign pref_ckpt = id__prefet_ckpt_i;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<PHY_SR_LEN; i=i+1) begin
                prm_mark[i] <= READY;
            end
        end else begin
            for(integer i=1; i<PHY_SR_LEN; i=i+1) begin
                for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                    if(id_prm__rdst_en_i[j] && (id_prm__phy_rdst_index_i[j] == i)) begin
                        prm_mark[i] <= FLY;
                    end
                end
                if(alu0_prm__update_prm_i.en && (alu0_prm__update_prm_i.rdst_index == i)) begin
                    prm_mark[i] <= READY;
                end
                if(alu1_prm__update_prm_i.en && (alu1_prm__update_prm_i.rdst_index == i)) begin
                    prm_mark[i] <= READY;
                end
                if(mdu_prm__update_prm_i.en && (mdu_prm__update_prm_i.rdst_index == i)) begin
                    prm_mark[i] <= READY;
                end
                if(lsu_prm__update_prm_i.en && (lsu_prm__update_prm_i.rdst_index == i)) begin
                    prm_mark[i] <= READY;
                end
                if(rcov.en && chk_ckpt(prm_ckpt[i], rcov_ckpt, pref_ckpt) ) begin
                    prm_mark[i] <= READY;
                end
                if(flush_en) begin
                    prm_mark[i] <= READY;
                end
            end
            prm_mark[0] <= READY;
        end
    end
    always_comb begin
        for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
            prm_id__phy_rs1_ready_o[i] = prm_mark[id_prm__phy_rs1_index_i[i]];
            if( (alu0_prm__update_prm_i.en && (alu0_prm__update_prm_i.rdst_index==id_prm__phy_rs1_index_i[i]))
                || (alu1_prm__update_prm_i.en && (alu1_prm__update_prm_i.rdst_index==id_prm__phy_rs1_index_i[i]))
                || (mdu_prm__update_prm_i.en && (mdu_prm__update_prm_i.rdst_index==id_prm__phy_rs1_index_i[i]))
                || (lsu_prm__update_prm_i.en && (lsu_prm__update_prm_i.rdst_index==id_prm__phy_rs1_index_i[i])) ) begin
                prm_id__phy_rs1_ready_o[i] = READY;
            end
            for(integer j=0; j<i; j=j+1) begin
                if( id_prm__rdst_en_i[j] && (id_prm__phy_rs1_index_i[i] == id_prm__phy_rdst_index_i[j])
                    && (id_prm__phy_rs1_index_i[i] != 0)) begin
                    prm_id__phy_rs1_ready_o[i] = FLY;
                end
            end
        end
    end
    always_comb begin
        for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
            prm_id__phy_rs2_ready_o[i] = prm_mark[id_prm__phy_rs2_index_i[i]];
            if( (alu0_prm__update_prm_i.en && (alu0_prm__update_prm_i.rdst_index==id_prm__phy_rs2_index_i[i]))
                || (alu1_prm__update_prm_i.en && (alu1_prm__update_prm_i.rdst_index==id_prm__phy_rs2_index_i[i]))
                || (mdu_prm__update_prm_i.en && (mdu_prm__update_prm_i.rdst_index==id_prm__phy_rs2_index_i[i]))
                || (lsu_prm__update_prm_i.en && (lsu_prm__update_prm_i.rdst_index==id_prm__phy_rs2_index_i[i])) ) begin
                prm_id__phy_rs2_ready_o[i] = READY;
            end
            for(integer j=0; j<i; j=j+1) begin
                if( id_prm__rdst_en_i[j] && (id_prm__phy_rs2_index_i[i] == id_prm__phy_rdst_index_i[j])
                    && (id_prm__phy_rs2_index_i[i] != 0)) begin
                    prm_id__phy_rs2_ready_o[i] = FLY;
                end
            end
        end
    end
endmodule : hpu_prm
