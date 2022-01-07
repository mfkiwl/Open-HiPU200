`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_prf (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   phy_sr_index_t                          alu0_prf__rs1_index_i,
    output  data_t                                  prf_alu0__rs1_data_o,
    input   phy_sr_index_t                          alu0_prf__rs2_index_i,
    output  data_t                                  prf_alu0__rs2_data_o,
    input   phy_sr_index_t                          alu0_prf__rdst_index_i,
    input   logic                                   alu0_prf__rdst_en_i,
    input   data_t                                  alu0_prf__rdst_data_i,
    input   phy_sr_index_t                          alu1_prf__rs1_index_i,
    output  data_t                                  prf_alu1__rs1_data_o,
    input   phy_sr_index_t                          alu1_prf__rs2_index_i,
    output  data_t                                  prf_alu1__rs2_data_o,
    input   phy_sr_index_t                          alu1_prf__rdst_index_i,
    input   logic                                   alu1_prf__rdst_en_i,
    input   data_t                                  alu1_prf__rdst_data_i,
    input   phy_sr_index_t                          lsu_prf__rs1_index_i,
    output  data_t                                  prf_lsu__rs1_data_o,
    input   phy_sr_index_t                          lsu_prf__rs2_index_i,
    output  data_t                                  prf_lsu__rs2_data_o,
    input   phy_sr_index_t                          lsu_prf__rdst_index_i,
    input   logic                                   lsu_prf__rdst_en_i,
    input   data_t                                  lsu_prf__rdst_data_i,
    input   phy_sr_index_t                          mdu_prf__rs1_index_i,
    output  data_t                                  prf_mdu__rs1_data_o,
    input   phy_sr_index_t                          mdu_prf__rs2_index_i,
    output  data_t                                  prf_mdu__rs2_data_o,
    input   phy_sr_index_t                          mdu_prf__rdst_index_i,
    input   logic                                   mdu_prf__rdst_en_i,
    input   data_t                                  mdu_prf__rdst_data_i,
    input   phy_sr_index_t                          vmu_prf__rs1_index_i,
    output  data_t                                  prf_vmu__rs1_data_o,
    input   phy_sr_index_t                          vmu_prf__rs2_index_i,
    output  data_t                                  prf_vmu__rs2_data_o
);
    phy_sr_index_t[3 : 0]                   wr_addr;
    logic[3 : 0]                            wr_en;
    data_t[3 : 0]                           wr_data;
    phy_sr_index_t[4 : 0]                   rd_addr_grp0;
    data_t[4 : 0]                           rd_data_grp0;
    phy_sr_index_t[4 : 0]                   rd_addr_grp1;
    data_t[4 : 0]                           rd_data_grp1;
    assign wr_addr = {alu0_prf__rdst_index_i, alu1_prf__rdst_index_i, mdu_prf__rdst_index_i, lsu_prf__rdst_index_i};
    assign wr_en = {alu0_prf__rdst_en_i, alu1_prf__rdst_en_i, mdu_prf__rdst_en_i, lsu_prf__rdst_en_i};
    assign wr_data = {alu0_prf__rdst_data_i, alu1_prf__rdst_data_i, mdu_prf__rdst_data_i, lsu_prf__rdst_data_i};
    assign rd_addr_grp0 = {alu0_prf__rs1_index_i, alu0_prf__rs2_index_i, alu1_prf__rs1_index_i, alu1_prf__rs2_index_i,
        vmu_prf__rs2_index_i};
    assign {prf_alu0__rs1_data_o, prf_alu0__rs2_data_o, prf_alu1__rs1_data_o, prf_alu1__rs2_data_o,
        prf_vmu__rs2_data_o} = rd_data_grp0;
    hpu_regfile #(
        .NUM_RD (5),
        .NUM_WR (4)
    ) hpu_regfile_grp0_inst (
        .clk_i                  (clk_i),
        .rst_i                  (rst_i),
        .raddr_i                (rd_addr_grp0),
        .rdata_o                (rd_data_grp0),
        .waddr_i                (wr_addr),
        .wr_en_i                (wr_en),
        .wdata_i                (wr_data)
    );
    assign rd_addr_grp1 = {lsu_prf__rs1_index_i, lsu_prf__rs2_index_i, mdu_prf__rs1_index_i, mdu_prf__rs2_index_i,
        vmu_prf__rs1_index_i};
    assign {prf_lsu__rs1_data_o, prf_lsu__rs2_data_o, prf_mdu__rs1_data_o, prf_mdu__rs2_data_o,
        prf_vmu__rs1_data_o} = rd_data_grp1;
    hpu_regfile #(
        .NUM_RD (5),
        .NUM_WR (4)
    ) hpu_regfile_grp1_inst (
        .clk_i                  (clk_i),
        .rst_i                  (rst_i),
        .raddr_i                (rd_addr_grp1),
        .rdata_o                (rd_data_grp1),
        .waddr_i                (wr_addr),
        .wr_en_i                (wr_en),
        .wdata_i                (wr_data)
    );
endmodule : hpu_prf
