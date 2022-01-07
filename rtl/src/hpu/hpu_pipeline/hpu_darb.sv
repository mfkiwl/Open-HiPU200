`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_darb (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   ctrl_darb__rspd_en_i,
    input   rspd_e                                  ctrl_darb__rspd_data_i,
    input   logic                                   if_darb__rd_en_i,
    input   pc_t                                    if_darb__raddr_i,
    output  inst_t                                  darb_if__inst_o,
    input   logic                                   lsu_darb__wr_en_i,
    input   pc_t                                    lsu_darb__waddr_i,
    output  logic                                   darb_lsu__wr_suc_o,
    input   data_t                                  lsu_darb__wdata_i,
    input   data_strobe_t                           lsu_darb__wstrb_i,
    input   logic                                   lsu_darb__rd_en_i,
    input   data_t                                  lsu_darb__raddr_i,
    output  logic                                   darb_lsu__rd_suc_o,
    output  data_t                                  darb_lsu__rdata_o,
    output  logic                                   darb_dm__req_o,
    output  logic                                   darb_dm__we_o,
    output  pc_t                                    darb_dm__addr_o,
    output  data_t                                  darb_dm__wdata_o,
    input   data_t                                  dm_darb__rdata_i
);
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            darb_dm__req_o <= 1'b0;
            darb_dm__we_o <= 1'b0;
            darb_dm__addr_o <= pc_t'(0);
            darb_dm__wdata_o <= data_t'(0);
        end else begin
            if(ctrl_darb__rspd_en_i) begin
                darb_dm__req_o <= 1'b1;
                darb_dm__we_o <= 1'b1;
                darb_dm__addr_o <= (ctrl_darb__rspd_data_i == RSPD_HALT) ? pc_t'('h100)
                                 : (ctrl_darb__rspd_data_i == RSPD_CMD) ? pc_t'('h104)
                                 : (ctrl_darb__rspd_data_i == RSPD_RESUME) ? pc_t'('h108)
                                 : pc_t'('h10c);
                darb_dm__wdata_o <= data_t'(0);
                darb_lsu__wr_suc_o <= 1'b0;
                darb_lsu__rd_suc_o <= 1'b0;
            end else if(if_darb__rd_en_i) begin
                darb_dm__req_o <= if_darb__rd_en_i;
                darb_dm__we_o <= 1'b0;
                darb_dm__addr_o <= if_darb__raddr_i;
                darb_lsu__wr_suc_o <= 1'b0;
                darb_lsu__rd_suc_o <= 1'b0;
            end else if(lsu_darb__wr_en_i) begin
                darb_dm__req_o <= lsu_darb__wr_en_i;
                darb_dm__we_o <= 1'b1;
                darb_dm__addr_o <= lsu_darb__waddr_i;
                darb_dm__wdata_o <= lsu_darb__wdata_i;
                darb_lsu__rd_suc_o <= 1'b0;
            end else if(lsu_darb__rd_en_i) begin
                darb_dm__req_o <= lsu_darb__rd_en_i;
                darb_dm__we_o <= 1'b0;
                darb_dm__addr_o <= lsu_darb__raddr_i;
            end else begin
                darb_dm__req_o <= 1'b0;
                darb_dm__we_o <= 1'b0;
                darb_dm__addr_o <= pc_t'(0);
                darb_dm__wdata_o <= data_t'(0);
                darb_lsu__wr_suc_o <= 1'b1;
                darb_lsu__rd_suc_o <= 1'b1;
            end
        end
    end
    assign darb_if__inst_o = inst_t'(dm_darb__rdata_i);
    assign darb_lsu__rdata_o = dm_darb__rdata_i;
endmodule : hpu_darb
