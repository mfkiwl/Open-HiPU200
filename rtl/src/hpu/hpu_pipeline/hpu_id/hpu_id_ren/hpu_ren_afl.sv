`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_ren_afl (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   update_arat_t                           rob_id__update_arat_i,
    input   logic                                   flush_en_i,
    output  logic                                   afl_rcov_en_o,
    output  logic[PHY_SR_LEN-1 : 0]                 afl_rcov_data_o
);
    logic[INST_DEC_PARAL-1 : 0]             afl_update_en;
    assign afl_update_en = rob_id__update_arat_i.en ? rob_id__update_arat_i.avail: INST_DEC_PARAL'(0);
    assign afl_rcov_en_o = flush_en_i;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            afl_rcov_data_o <= {PHY_SR_LEN{1'b1}};
        end else begin
            for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
                if(afl_update_en[i]) begin
                    afl_rcov_data_o[rob_id__update_arat_i.phy_old_rdst_index[i]] <= 1'b1;
                    afl_rcov_data_o[rob_id__update_arat_i.phy_rdst_index[i]] <= 1'b0;
                end
            end
        end
    end
endmodule : hpu_ren_afl
