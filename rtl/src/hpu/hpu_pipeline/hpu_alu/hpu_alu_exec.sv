`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_alu_exec (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   alu_inst_t                              alu_inst_exec_i,
    input   data_t                                  bypass_rs1_data_exec_i,
    input   data_t                                  bypass_rs2_data_exec_i,
    output  data_t                                  phy_rdst_data_o,
    output  logic                                   br_is_taken_o,
    output  data_t                                  alu_next_pc_o,
    output  logic                                   alu_excp_en_o,
    output  excp_e                                  alu_excp_o
);
    data_t                                  rs1;
    data_t                                  rs2;
    data_t                                  imm;
    alu_inst_t                              inst;
    data_t                                  real_rs2;
    assign rs1 = bypass_rs1_data_exec_i;
    assign rs2 = bypass_rs2_data_exec_i;
    assign imm = alu_inst_exec_i.opcode.imm;
    assign inst = alu_inst_exec_i;
    assign alu_excp_en_o = 1'b0;
    assign alu_excp_o = INST_ADDR_MISALIGNED;
    always_comb begin
        phy_rdst_data_o = data_t'(0);
        br_is_taken_o = 1'b0;
        real_rs2 = rs2;
        alu_next_pc_o = pc_t'(0);
        case(inst.opcode.optype)
            ALG: begin
                real_rs2 = (alu_inst_exec_i.opcode.with_imm) ? imm : rs2;
                case(inst.opcode.alg_func)
                    ALG_AS: begin
                        phy_rdst_data_o = (inst.opcode.alg_add == ALG_ADD) ? rs1 + real_rs2 : rs1 - real_rs2;
                    end
                    ALG_SL: begin
                        phy_rdst_data_o = rs1 << (real_rs2[4:0]);
                    end
                    ALG_SR: begin 
                        phy_rdst_data_o = (inst.opcode.alg_shift == ALG_ALGRITHM) ?
                            ({{32{rs1[31]}}, rs1} >> real_rs2[4:0]) : rs1 >> (real_rs2[4:0]);
                    end
                    ALG_SLT: begin
                        phy_rdst_data_o = ($signed(rs1) < $signed(real_rs2)) ? 'h1 : 'h0;
                    end
                    ALG_SLTU: begin
                        phy_rdst_data_o = (rs1 < real_rs2) ? 'h1 : 'h0;
                    end
                    ALG_XOR: begin
                        phy_rdst_data_o = rs1 ^ real_rs2;
                    end
                    ALG_OR: begin
                        phy_rdst_data_o = rs1 | real_rs2;
                    end
                    ALG_AND: begin
                        phy_rdst_data_o = rs1 & real_rs2;
                    end
                endcase
            end
            UP: begin
                phy_rdst_data_o = inst.opcode.imm;
            end
            JAL: begin
                phy_rdst_data_o = inst.cur_pc + 4;
                alu_next_pc_o = inst.cur_pc + inst.opcode.imm;
            end
            JALR: begin
                phy_rdst_data_o = inst.cur_pc + 4;
                alu_next_pc_o = rs1 + inst.opcode.imm;
            end
            BR: begin
                case(inst.opcode.branch_func)
                    BR_EQ: br_is_taken_o = (rs1 == rs2) ? 1'b1 : 1'b0;
                    BR_NE: br_is_taken_o = (rs1 != rs2) ? 1'b1 : 1'b0;
                    BR_LT: br_is_taken_o = ($signed(rs1) < $signed(rs2)) ? 1'b1 : 1'b0;
                    BR_GE: br_is_taken_o = ($signed(rs1) >= $signed(rs2)) ? 1'b1 : 1'b0;
                    BR_LTU: br_is_taken_o = (rs1 < rs2) ? 1'b1 : 1'b0;
                    BR_GEU: br_is_taken_o = (rs1 >= rs2) ? 1'b1 : 1'b0;
                endcase
                if(br_is_taken_o) begin
                    alu_next_pc_o = inst.cur_pc + inst.opcode.imm;
                end else begin
                    alu_next_pc_o = inst.cur_pc + 4;
                end
            end
        endcase
    end
endmodule : hpu_alu_exec
