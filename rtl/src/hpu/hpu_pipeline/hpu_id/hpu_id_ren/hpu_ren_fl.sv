`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_ren_fl (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic[INST_DEC_PARAL-1 : 0]             rdst_act_id0_i,
    input   arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rdst_index_id0_i,
    output  phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rdst_index_id0_o,
    input   update_arat_t                           rob_id__update_arat_i,
    input   logic                                   ckpt_save_en_id1_i,
    input   ckpt_index_t                            ckpt_save_index_id1_i,
    input   logic                                   ckpt_rcov_en_i,
    input   ckpt_index_t                            ckpt_rcov_index_i,
    input   logic                                   afl_rcov_en_i,
    input   logic[PHY_SR_LEN-1 : 0]                 afl_rcov_data_i,
    output  logic                                   fl_is_stall_o,
    input   logic                                   safemd_safe_fl_i
);
    phy_sr_index_t[INST_DEC_PARAL-1 : 0]    fl_push_rdst_index;
    logic[INST_DEC_PARAL-1 : 0]             fl_push_en;
    logic[PHY_SR_LEN-1 : 0]                 freelist;
    phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rdst_index_cand;
    logic[PHY_SR_LEN-1 : 0]                 ckpt_fl[CKPT_LEN-1 : 0];
    logic[PHY_SR_INDEX-1 : 0]               fl_cnt_comb[PHY_SR_LEN-1 : 1];
    logic[PHY_SR_INDEX-1 : 0]               fl_cnt;
    logic                                   fl_is_stall_safemd;
    assign fl_push_rdst_index = rob_id__update_arat_i.phy_old_rdst_index;
    assign fl_push_en = rob_id__update_arat_i.en ? rob_id__update_arat_i.avail: INST_DEC_PARAL'(0);
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            freelist <= {PHY_SR_LEN{1'b1}};
        end else begin
            if(afl_rcov_en_i) begin
                freelist <= afl_rcov_data_i;
            end else begin
                if(ckpt_rcov_en_i) begin
                    freelist <= ckpt_fl[ckpt_rcov_index_i];
                end else begin
                    for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
                        if(rdst_act_id0_i[i]) begin
                            freelist[phy_rdst_index_id0_o[i]] <= 1'b0;
                        end
                    end
                end
                for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
                    if(fl_push_en[i]) begin
                        freelist[fl_push_rdst_index[i]] <= 1'b1;
                    end
                end
                freelist[0] <= 1'b1;
            end
        end
    end
    always_comb begin
        phy_rdst_index_cand[0] = phy_sr_index_t'(0);
        for(integer i=PHY_SR_LEN-1; i>0; i=i-1) begin
            if(freelist[i] == 1'b1) begin
                phy_rdst_index_cand[0] = phy_sr_index_t'(i);
            end
        end
        if(arc_rdst_index_id0_i[0] == 0) begin
            phy_rdst_index_id0_o[0] = phy_sr_index_t'(0);
        end else begin
            phy_rdst_index_id0_o[0] = phy_rdst_index_cand[0];
        end
    end
    always_comb begin
        phy_rdst_index_cand[1] = phy_sr_index_t'(0);
        for(integer i=1; i<PHY_SR_LEN; i=i+1) begin
            if(freelist[i] == 1'b1) begin
                phy_rdst_index_cand[1] = phy_sr_index_t'(i);
            end
        end
        if(arc_rdst_index_id0_i[1] == 0) begin
            phy_rdst_index_id0_o[1] = phy_sr_index_t'(0);
        end else begin
            phy_rdst_index_id0_o[1] = phy_rdst_index_cand[1];
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<CKPT_LEN; i=i+1) begin
                ckpt_fl[i] <= {PHY_SR_LEN{1'b0}};
            end
        end else begin
            if(ckpt_save_en_id1_i) begin
                ckpt_fl[ckpt_save_index_id1_i] <= freelist;
            end
            for(integer i=0; i<CKPT_LEN; i=i+1) begin
                for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                    if(fl_push_en[j]) begin
                        ckpt_fl[i][fl_push_rdst_index[j]] <= 1'b1;
                    end
                end
            end
        end
    end
    always_comb begin
        fl_cnt_comb[1] = freelist[1];
        for(integer i=2; i<PHY_SR_LEN; i=i+1) begin
            fl_cnt_comb[i] = freelist[i] + fl_cnt_comb[i-1];
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            fl_cnt <= {PHY_SR_INDEX{1'b1}};
        end else begin
            fl_cnt <= fl_cnt_comb[PHY_SR_LEN-1];
        end
    end
    assign fl_is_stall_safemd = (fl_cnt < INST_DEC_PARAL*2 + 2);
    assign fl_is_stall_o = safemd_safe_fl_i ? fl_is_stall_safemd : (phy_rdst_index_cand[0] == phy_rdst_index_cand[1]);
    logic[6 : 0] prb_fl_cnt;
    always_comb begin
        prb_fl_cnt = 0;
        for(int i=1; i<64; i++) begin
            prb_fl_cnt += 7'(freelist[i]);
        end
    end
endmodule : hpu_ren_fl
