`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_lsu_bypass (
    input   bypass_data_t                           alu0_bypass__data_i,
    input   bypass_data_t                           alu1_bypass__data_i,
    input   phy_sr_index_t                          phy_rs1_index_reg_i,
    input   data_t                                  phy_rs1_data_reg_i,
    output  data_t                                  bypass_rs1_data_o,
    input   phy_sr_index_t                          phy_rs2_index_reg_i,
    input   data_t                                  phy_rs2_data_reg_i,
    output  data_t                                  bypass_rs2_data_o
);
    always_comb begin
        if((alu0_bypass__data_i.en) && (alu0_bypass__data_i.rdst_index == phy_rs1_index_reg_i) ) begin
            bypass_rs1_data_o = alu0_bypass__data_i.rdst_data;
        end else if((alu1_bypass__data_i.en) && (alu1_bypass__data_i.rdst_index == phy_rs1_index_reg_i) ) begin
            bypass_rs1_data_o = alu1_bypass__data_i.rdst_data;
        end else begin
            bypass_rs1_data_o = phy_rs1_data_reg_i;
        end
    end
    always_comb begin
        if((alu0_bypass__data_i.en) && (alu0_bypass__data_i.rdst_index == phy_rs2_index_reg_i) ) begin
            bypass_rs2_data_o = alu0_bypass__data_i.rdst_data;
        end else if((alu1_bypass__data_i.en) && (alu1_bypass__data_i.rdst_index == phy_rs2_index_reg_i) ) begin
            bypass_rs2_data_o = alu1_bypass__data_i.rdst_data;
        end else begin
            bypass_rs2_data_o = phy_rs2_data_reg_i;
        end
    end
endmodule
