`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_regfile #(
    parameter NUM_RD = 2,
    parameter NUM_WR = 2
) (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   phy_sr_index_t[NUM_RD-1 : 0]            raddr_i,
    output  data_t[NUM_RD-1 : 0]                    rdata_o,
    input   phy_sr_index_t[NUM_WR-1 : 0]            waddr_i,
    input   logic[NUM_WR-1 : 0]                     wr_en_i,
    input   data_t[NUM_WR-1 : 0]                    wdata_i
);
    logic[PHY_SR_LEN-1 : 0]                 wr_en_onehot[NUM_WR-1 : 0];
    data_t[PHY_SR_LEN-1 : 0]                regfile;
    phy_sr_index_t[NUM_RD-1 : 0]            raddr_ff;
    always_comb begin
        for(int i=0; i<NUM_WR; i++) begin : prf_write
            for(int j=0; j<PHY_SR_LEN; j++) begin
                wr_en_onehot[i][j] = (j == waddr_i[i]) ? wr_en_i[i] : 1'b0;
            end
        end
    end
    assign regfile[0] = {DATA_WTH{1'b0}};
    for(genvar gi=1; gi<PHY_SR_LEN; gi++) begin : prf_write
        always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
            if(`RST_TRUE(rst_i)) begin
                regfile[gi] <= data_t'(0);
            end else begin
                for(int j=0; j<NUM_WR; j++) begin
                    if(wr_en_onehot[j][gi]) begin
                        regfile[gi] <= wdata_i[j];
                    end
                end
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<NUM_RD; i++) begin
                raddr_ff[i] <= phy_sr_index_t'(0);
            end
        end else begin
            for(integer i=0; i<NUM_RD; i++) begin
                raddr_ff[i] <= raddr_i[i];
            end
        end
    end
    always_comb begin
        for(integer i=0; i<NUM_RD; i++) begin
            rdata_o[i] = regfile[raddr_ff[i]];
            for(int j=0; j<NUM_WR; j++) begin
                if( (waddr_i[j] != 'h0) && (waddr_i[j] == raddr_ff[i]) && (wr_en_i[j]) ) begin
                    rdata_o[i] = wdata_i[j];
                end
            end
        end
    end
endmodule : hpu_regfile
