`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_ren_arat(
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   update_arat_t                           rob_id__update_arat_i,
    input   logic                                   flush_en_i,
    output  logic                                   arat_rcov_en_o,
    output  phy_sr_index_t[ARC_SR_LEN-1 : 0]        arat_rcov_data_o
);
    logic[INST_DEC_PARAL-1 : 0]             arat_update_en;
    assign arat_update_en = rob_id__update_arat_i.en ? rob_id__update_arat_i.avail : INST_DEC_PARAL'(0);
    assign arat_rcov_en_o = flush_en_i;
    always_ff@(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<ARC_SR_LEN; i=i+1) begin
                arat_rcov_data_o[i] <= phy_sr_index_t'(0);
            end
        end else begin
            for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
                if(arat_update_en[i]) begin
                    arat_rcov_data_o[rob_id__update_arat_i.arc_rdst_index[i]]<=rob_id__update_arat_i.phy_rdst_index[i];
                end
            end
        end
    end
endmodule : hpu_ren_arat
