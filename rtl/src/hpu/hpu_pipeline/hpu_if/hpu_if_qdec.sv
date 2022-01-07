`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_if_qdec (
    input   inst_t                                  cur_inst_i,
    input   pc_t                                    cur_inst_pc_if1_i,
    input   logic                                   inst_may_be_call_i,
    input   data_t                                  inst_may_be_call_rs1_i,
    output  logic                                   inst_may_be_call_o,
    output  data_t                                  inst_may_be_call_rs1_o,
    output  qdec_type_e                             qdec_type_o,
    output  pc_t                                    qdec_pred_npc_o
);
    arc_sr_index_t                          rs1, rs2, rd;
    assign rs1 = get_rs1(cur_inst_i);
    assign rs2 = get_rs2(cur_inst_i);
    assign rd = get_rd(cur_inst_i);
    always_comb begin
        qdec_type_o = IS_NORMAL;
        inst_may_be_call_o = 1'b0;
        inst_may_be_call_rs1_o = data_t'(0);
        qdec_pred_npc_o = cur_inst_pc_if1_i + 3'h4;
        case(cur_inst_i[6 : 0])
            INST_BR: begin
                qdec_type_o = IS_BRANCH;
            end
            INST_JALR: begin
                if((rs1 == SR_RA || rs1 == SR_T0) && !(rd == SR_RA || rd == SR_T0)) begin
                    qdec_type_o = IS_RET;
                end else if((rd == SR_RA || rd == SR_T0) && (inst_may_be_call_i)) begin
                    qdec_type_o = IS_CALL;
                    qdec_pred_npc_o = inst_may_be_call_rs1_i + i_imm(cur_inst_i);
                end else begin
                    qdec_type_o = IS_JALR;
                end
            end
            INST_JAL: begin
                if(rd == SR_RA || rd == SR_T0) begin
                    qdec_type_o = IS_CALL;
                end else begin
                    qdec_type_o = IS_JAL;
                end
                qdec_pred_npc_o = cur_inst_pc_if1_i + j_imm(cur_inst_i);
            end
            INST_LUI: begin
                if(rs1 == SR_RA || rs1 == SR_T0) begin
                    inst_may_be_call_o = 1'b1;
                    inst_may_be_call_rs1_o = u_imm(cur_inst_i);
                end
            end
            INST_AUIPC: begin
                if(rs1 == SR_RA || rs1 == SR_T0) begin
                    inst_may_be_call_o = 1'b1;
                    inst_may_be_call_rs1_o = cur_inst_pc_if1_i + u_imm(cur_inst_i);
                end
            end
        endcase
    end
endmodule : hpu_if_qdec
