`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_id_ren(
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   flush_en_i,
    input   update_ckpt_t                           ckpt_rcov_i,
    output  update_ckpt_t                           id__ckpt_rcov_o,
    output  ckpt_t                                  id__prefet_ckpt_o,
    input   logic[INST_DEC_PARAL-1 : 0]             inst_is_act_id0_i,
    input   logic[INST_DEC_PARAL-1 : 0]             inst_is_jbr_id0_i,
    input   logic[INST_DEC_PARAL-1 : 0]             rdst_en_id0_i,
    input   arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rs1_index_id0_i,
    input   arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rs2_index_id0_i,
    input   arc_sr_index_t[INST_DEC_PARAL-1 : 0]    arc_rdst_index_id0_i,
    output  phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rs1_index_id1_o,
    output  phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rs2_index_id1_o,
    output  phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rdst_index_id1_o,
    output  phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_old_rdst_index_id1_o,
    output  logic                                   ckpt_avail_id1_o,
    output  ckpt_t                                  ckpt_id1_o,
    input   update_arat_t                           rob_id__update_arat_i,
    input   update_ckpt_t[1 : 0]                    rob_id__update_ckpt_i,
    input   update_arc_ckpt_t                       rob_id__update_arc_ckpt_i,
    output  logic                                   fl_is_stall_o,
    input   logic                                   dec_is_stall_i,
    input   logic                                   safemd_rcov_disable_i,
    input   logic                                   safemd_safe_fl_i
);
    logic[INST_DEC_PARAL-1 : 0]             rdst_act_id0;
    logic[INST_DEC_PARAL-1 : 0]             jbr_act_id0;
    phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rdst_index_id0;
    phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rs1_index_id0;
    phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_rs2_index_id0;
    phy_sr_index_t[INST_DEC_PARAL-1 : 0]    phy_old_rdst_index_id0;
    logic[CKPT_LEN-1 : 0]                   ckpt;
    ckpt_t                                  ckpt_arc, ckpt_ins, ckpt_del;
    logic                                   ckpt_is_empty, ckpt_is_full, ckpt_is_block;
    update_ckpt_t[1 : 0]                    update_ckpt;
    update_ckpt_t                           mispred;
    logic                                   cur_rcov_act;
    update_ckpt_t                           ckpt_rcov;
    logic                                   ckpt_rcov_en, ckpt_save_en;
    logic                                   ckpt_save_en_id1;
    ckpt_index_t                            ckpt_rcov_index, ckpt_save_index;
    ckpt_index_t                            ckpt_save_index_id1;
    logic                                   afl_rcov_en;
    logic[PHY_SR_LEN-1 : 0]                 afl_rcov_data;
    logic                                   arat_rcov_en;
    phy_sr_index_t[ARC_SR_LEN-1 : 0]        arat_rcov_data;
    assign rdst_act_id0 = inst_is_act_id0_i & rdst_en_id0_i;
    assign jbr_act_id0 = inst_is_act_id0_i & inst_is_jbr_id0_i;
    hpu_ren_fl hpu_ren_fl_inst (
        .clk_i                                  (clk_i),
        .rst_i                                  (rst_i),
        .rdst_act_id0_i                         (rdst_act_id0),
        .arc_rdst_index_id0_i                   (arc_rdst_index_id0_i),
        .phy_rdst_index_id0_o                   (phy_rdst_index_id0),
        .rob_id__update_arat_i                  (rob_id__update_arat_i),
        .ckpt_save_en_id1_i                     (ckpt_save_en_id1),
        .ckpt_save_index_id1_i                  (ckpt_save_index_id1),
        .ckpt_rcov_en_i                         (ckpt_rcov_en),
        .ckpt_rcov_index_i                      (ckpt_rcov_index),
        .afl_rcov_en_i                          (afl_rcov_en),
        .afl_rcov_data_i                        (afl_rcov_data),
        .fl_is_stall_o                          (fl_is_stall_o),
        .safemd_safe_fl_i                       (safemd_safe_fl_i)
    );
    hpu_ren_rat hpu_ren_rat_inst (
        .clk_i                                  (clk_i),
        .rst_i                                  (rst_i),
        .arc_rs1_index_id0_i                    (arc_rs1_index_id0_i),
        .arc_rs2_index_id0_i                    (arc_rs2_index_id0_i),
        .arc_rdst_index_id0_i                   (arc_rdst_index_id0_i),
        .phy_rs1_index_id0_o                    (phy_rs1_index_id0),
        .phy_rs2_index_id0_o                    (phy_rs2_index_id0),
        .phy_old_rdst_index_id0_o               (phy_old_rdst_index_id0),
        .rdst_act_id0_i                         (rdst_act_id0),
        .phy_rdst_index_id0_i                   (phy_rdst_index_id0),
        .ckpt_save_en_id1_i                     (ckpt_save_en_id1),
        .ckpt_save_index_id1_i                  (ckpt_save_index_id1),
        .ckpt_rcov_en_i                         (ckpt_rcov_en),
        .ckpt_rcov_index_i                      (ckpt_rcov_index),
        .arat_rcov_en_i                         (arat_rcov_en),
        .arat_rcov_data_i                       (arat_rcov_data)
    );
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
                phy_rs1_index_id1_o[i] <= phy_sr_index_t'(0);
                phy_rs2_index_id1_o[i] <= phy_sr_index_t'(0);
            end
        end else begin
            if(!dec_is_stall_i) begin
                for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
                    phy_rs1_index_id1_o[i] <= phy_rs1_index_id0[i];
                    phy_rs2_index_id1_o[i] <= phy_rs2_index_id0[i];
                    for(integer j=0; j<i; j=j+1) begin
                        if(rdst_act_id0[j] && (arc_rdst_index_id0_i[j] == arc_rs1_index_id0_i[i])) begin
                            phy_rs1_index_id1_o[i] <= phy_rdst_index_id0[j];
                        end
                        if(rdst_act_id0[j] && (arc_rdst_index_id0_i[j] == arc_rs2_index_id0_i[i])) begin
                            phy_rs2_index_id1_o[i] <= phy_rdst_index_id0[j];
                        end
                    end
                end
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
                phy_rdst_index_id1_o[i] <= phy_sr_index_t'(0);
                phy_old_rdst_index_id1_o[i] <= phy_sr_index_t'(0);
            end
        end else begin
            if(!dec_is_stall_i) begin
                phy_rdst_index_id1_o <= phy_rdst_index_id0;
                for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
                    phy_old_rdst_index_id1_o[i] <= phy_old_rdst_index_id0[i];
                    for(integer j=0; j<i; j=j+1) begin
                        if(rdst_act_id0[j] && (arc_rdst_index_id0_i[j] == arc_rdst_index_id0_i[i])) begin
                            phy_old_rdst_index_id1_o[i] <= phy_rdst_index_id0[j];
                        end
                    end
                end
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ckpt <= CKPT_LEN'(0);
        end else begin
            for(integer i=0; i<CKPT_LEN; i=i+1) begin
                if((i == rob_id__update_ckpt_i[0].ckpt.index) && rob_id__update_ckpt_i[0].en
                    && rob_id__update_ckpt_i[0].ckpt_suc ) begin
                    ckpt[i] <= 1'b0;
                end else if((i == rob_id__update_ckpt_i[1].ckpt.index) && rob_id__update_ckpt_i[1].en
                    && rob_id__update_ckpt_i[1].ckpt_suc) begin
                    ckpt[i] <= 1'b0;
                end else if((i == ckpt_rcov_i.ckpt.index) && ckpt_rcov_i.en) begin
                    ckpt[i] <= 1'b0;
                end else if((i==ckpt_ins.index) && (ckpt_save_en)) begin
                    ckpt[i] <= 1'b1;
                end
            end
            if(flush_en_i) begin
                ckpt <= CKPT_LEN'(0);
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ckpt_arc <= ckpt_t'(0);
        end else begin
            if(rob_id__update_arc_ckpt_i.en) begin
                ckpt_arc <= rob_id__update_arc_ckpt_i.ckpt;
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ckpt_ins <= ckpt_t'(0);
        end else begin
            if(ckpt_rcov_i.en) begin
                {ckpt_ins.flag, ckpt_ins.index} <= {ckpt_rcov_i.ckpt.flag, ckpt_rcov_i.ckpt.index} + 1'b1;
            end else if(ckpt_save_en) begin
                {ckpt_ins.flag, ckpt_ins.index} <= {ckpt_ins.flag, ckpt_ins.index} + 1'b1;
            end
            if(flush_en_i) begin
                {ckpt_ins.flag, ckpt_ins.index} <= {(CKPT_INDEX+1){1'b0}};
            end
        end
    end
    assign id__prefet_ckpt_o = ckpt_ins;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ckpt_del <= ckpt_t'(0);
        end else begin
            if(!ckpt_is_empty && (ckpt[ckpt_del.index] == 1'b0)) begin
                {ckpt_del.flag, ckpt_del.index} <= {ckpt_del.flag, ckpt_del.index} + 1'b1;
            end
            if(flush_en_i) begin
                {ckpt_del.flag, ckpt_del.index} <= {(CKPT_INDEX+1){1'b0}};
            end
        end
    end
    assign ckpt_is_empty = ({ckpt_ins.flag, ckpt_ins.index} == {ckpt_del.flag, ckpt_del.index});
    assign ckpt_is_full = ({~ckpt_ins.flag, ckpt_ins.index} == {ckpt_del.flag, ckpt_del.index});
    assign ckpt_is_block = ({ckpt_ins.flag, ckpt_ins.index} + 1'b1 == {ckpt_arc.flag, ckpt_arc.index});
    always_comb begin
        if({rob_id__update_ckpt_i[0].ckpt.flag ^ ckpt_del.flag, rob_id__update_ckpt_i[0].ckpt.index}
            < {rob_id__update_ckpt_i[1].ckpt.flag ^ ckpt_del.flag, rob_id__update_ckpt_i[1].ckpt.index}) begin
            update_ckpt[0] = rob_id__update_ckpt_i[0];
            update_ckpt[1] = rob_id__update_ckpt_i[1];
        end else begin
            update_ckpt[0] = rob_id__update_ckpt_i[1];
            update_ckpt[1] = rob_id__update_ckpt_i[0];
        end
        if(update_ckpt[0].en && !update_ckpt[0].ckpt_suc) begin
            mispred = update_ckpt[0];
        end else begin
            mispred = update_ckpt[1];
        end
        mispred.en = !safemd_rcov_disable_i && ((update_ckpt[0].en && !update_ckpt[0].ckpt_suc)
            || (update_ckpt[1].en && !update_ckpt[1].ckpt_suc));
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            cur_rcov_act <= 1'b0;
            ckpt_rcov <= update_ckpt_t'(0);
        end else begin
            if(flush_en_i) begin
                cur_rcov_act <= 1'b0;
                ckpt_rcov <= update_ckpt_t'(0);
            end else begin
                if(cur_rcov_act == 1'b0) begin
                    if(mispred.en) begin
                        cur_rcov_act <= 1'b1;
                        ckpt_rcov <= mispred;
                    end else begin
                        ckpt_rcov.en <= 1'b0;
                    end
                end else begin
                    if(ckpt_rcov_i.en && (ckpt_rcov_i.ckpt.index == ckpt_rcov.ckpt.index)) begin
                        cur_rcov_act <= 1'b0;
                    end
                    if(mispred.en && ({mispred.ckpt.flag ^ ckpt_del.flag, mispred.ckpt.index}
                        < {ckpt_rcov.ckpt.flag ^ ckpt_del.flag, ckpt_rcov.ckpt.index})) begin
                        cur_rcov_act <= 1'b1;
                        ckpt_rcov <= mispred;
                    end else begin
                        ckpt_rcov.en <= 1'b0;
                    end
                end
            end
        end
    end
    assign id__ckpt_rcov_o = flush_en_i ? update_ckpt_t'(0) : ckpt_rcov;
    assign ckpt_rcov_en = id__ckpt_rcov_o.en;
    assign ckpt_rcov_index = id__ckpt_rcov_o.ckpt.index;
    assign ckpt_save_en = |jbr_act_id0 && !ckpt_is_full && !ckpt_is_block && !ckpt_rcov_i.en;
    assign ckpt_save_index = ckpt_ins.index;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ckpt_save_en_id1 <= 1'b0;
            ckpt_save_index_id1 <= ckpt_index_t'(0);
        end else begin
            ckpt_save_en_id1 <= ckpt_save_en;
            ckpt_save_index_id1 <= ckpt_save_index;
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ckpt_avail_id1_o <= 1'b0;
            ckpt_id1_o <= ckpt_t'(0);
        end else begin
            if(!dec_is_stall_i) begin
                ckpt_avail_id1_o <= ckpt_save_en;
                ckpt_id1_o <= ckpt_ins;
            end
        end
    end
    hpu_ren_afl hpu_ren_afl_inst (
        .clk_i                                  (clk_i),
        .rst_i                                  (rst_i),
        .rob_id__update_arat_i                  (rob_id__update_arat_i),
        .flush_en_i                             (flush_en_i),
        .afl_rcov_en_o                          (afl_rcov_en),
        .afl_rcov_data_o                        (afl_rcov_data)
    );
    hpu_ren_arat hpu_ren_arat_inst (
        .clk_i                                  (clk_i),
        .rst_i                                  (rst_i),
        .rob_id__update_arat_i                  (rob_id__update_arat_i),
        .flush_en_i                             (flush_en_i),
        .arat_rcov_en_o                         (arat_rcov_en),
        .arat_rcov_data_o                       (arat_rcov_data)
    );
    logic[CKPT_LEN-1 : 0] prb_id1_ckpt_table;
    update_ckpt_t prb_id1_recover_ckpt;
    always_comb begin
        for(integer i=0; i<CKPT_LEN; i=i+1) begin
            prb_id1_ckpt_table[i] = (ckpt_del.flag == ckpt_ins.flag) ? (i >= ckpt_del.index) && (i < ckpt_ins.index)
                                                                     : (i >= ckpt_del.index) || (i < ckpt_ins.index);
        end
    end
    assign prb_id1_recover_ckpt = id__ckpt_rcov_o.en ? id__ckpt_rcov_o : 'h0;
endmodule : hpu_id_ren
