`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_id_dec (
    input   inst_t                                  inst_id0_i,
    input   pc_t                                    cur_pc_id0_i,
    output  issue_type_e                            inst_issue_type_id0_o,
    output  logic                                   inst_is_jbr_id0_o,
    output  logic                                   inst_is_bid_id0_o,
    output  logic                                   inst_is_ld_id0_o,
    output  logic                                   inst_is_st_id0_o,
    output  logic                                   inst_complete_id0_o,
    output  logic                                   inst_excp_en_id0_o,
    output  excp_e                                  inst_excp_id0_o,
    output  alu_opcode_t                            alu_opcode_id0_o,
    output  lsu_opcode_t                            lsu_opcode_id0_o,
    output  mdu_opcode_t                            mdu_opcode_id0_o,
    output  vmu_opcode_t                            vmu_opcode_id0_o,
    output  sysc_opcode_t                           sysc_opcode_id0_o,
    output  arc_sr_index_t                          arc_rs1_index_id0_o,
    output  arc_sr_index_t                          arc_rs2_index_id0_o,
    output  arc_sr_index_t                          rs3_index_id0_o,
    output  arc_sr_index_t                          arc_rdst_index_id0_o,
    output  logic                                   rdst_en_id0_o
);
    csr_addr_t                              csr_addr;
    assign arc_rs1_index_id0_o = get_rs1(inst_id0_i);
    assign arc_rs2_index_id0_o = get_rs2(inst_id0_i);
    assign rs3_index_id0_o = get_rs3(inst_id0_i);
    assign arc_rdst_index_id0_o = get_rd(inst_id0_i);
    always_comb begin
        inst_issue_type_id0_o = TO_NONE;
        inst_is_jbr_id0_o = 1'b0;
        inst_is_ld_id0_o = 1'b0;
        inst_is_st_id0_o = 1'b0;
        inst_is_bid_id0_o = 1'b0;
        inst_complete_id0_o = 1'b0;
        inst_excp_en_id0_o = 1'b0;
        inst_excp_id0_o = excp_e'(0);
        alu_opcode_id0_o = alu_opcode_t'(0);
        lsu_opcode_id0_o = lsu_opcode_t'(0);
        vmu_opcode_id0_o = vmu_opcode_t'(0);
        mdu_opcode_id0_o = mdu_opcode_t'(0);
        sysc_opcode_id0_o = sysc_opcode_t'(0);
        rdst_en_id0_o = 1'b0;
        case(inst_id0_i[6 : 0])
            INST_LD: begin
                inst_issue_type_id0_o = TO_LSU;
                inst_is_ld_id0_o = 1'b1;
                lsu_opcode_id0_o.optype = LOAD;
                lsu_opcode_id0_o.ls_size = dec_size_e'(inst_id0_i[13 : 12]);
                lsu_opcode_id0_o.is_unsigned = inst_id0_i[14];
                lsu_opcode_id0_o.with_imm = 1'b1;
                lsu_opcode_id0_o.imm = i_imm(inst_id0_i);
                lsu_opcode_id0_o.rs1_en = 1'b1;
                lsu_opcode_id0_o.rdst_en = 1'b1;
                rdst_en_id0_o = 1'b1;
            end
            INST_ST: begin
                inst_issue_type_id0_o = TO_LSU;
                inst_is_st_id0_o = 1'b1;
                lsu_opcode_id0_o.optype = STORE;
                lsu_opcode_id0_o.ls_size = dec_size_e'(inst_id0_i[13 : 12]);
                lsu_opcode_id0_o.is_unsigned = inst_id0_i[14];
                lsu_opcode_id0_o.with_imm = 1'b1;
                lsu_opcode_id0_o.imm = s_imm(inst_id0_i);
                lsu_opcode_id0_o.rs1_en = 1'b1;
                lsu_opcode_id0_o.rs2_en = 1'b1;
            end
            INST_OPI: begin
                inst_issue_type_id0_o = TO_ALU;
                alu_opcode_id0_o.optype = ALG;
                alu_opcode_id0_o.alg_func = scl_alg_func_e'(inst_id0_i[14 : 12]);
                alu_opcode_id0_o.alg_add = ALG_ADD;
                alu_opcode_id0_o.alg_shift = scl_alg_shift_e'(inst_id0_i[30]);
                alu_opcode_id0_o.is_unsigned = inst_id0_i[12];
                alu_opcode_id0_o.with_imm = 1'b1;
                alu_opcode_id0_o.imm = i_imm(inst_id0_i);
                alu_opcode_id0_o.rs1_en = 1'b1;
                alu_opcode_id0_o.rdst_en = 1'b1;
                rdst_en_id0_o = 1'b1;
            end
            INST_OP: begin
                if(inst_id0_i[31:25] == 7'h1) begin
                    inst_issue_type_id0_o = TO_MDU;
                    mdu_opcode_id0_o.optype = (inst_id0_i[14:12]==3'b000) ? MUL
                                            : (inst_id0_i[14]==1'b0) ? MULH
                                            : (inst_id0_i[14:13]==2'b10) ? DIV
                                            : REM;
                    mdu_opcode_id0_o.rs1_unsigned = (inst_id0_i[14:12]==3'h3)
                                                  || (inst_id0_i[14:12]==3'h5)
                                                  || (inst_id0_i[14:12]==3'h7);
                    mdu_opcode_id0_o.rs2_unsigned = (inst_id0_i[14:12]==3'h2)
                                                  || (inst_id0_i[14:12]==3'h3)
                                                  || (inst_id0_i[14:12]==3'h5)
                                                  || (inst_id0_i[14:12]==3'h7);
                    rdst_en_id0_o = 1'b1;
                end else begin
                    inst_issue_type_id0_o = TO_ALU;
                    alu_opcode_id0_o.optype = ALG;
                    alu_opcode_id0_o.alg_func = scl_alg_func_e'(inst_id0_i[14 : 12]);
                    alu_opcode_id0_o.alg_add = scl_alg_add_e'(inst_id0_i[30]);
                    alu_opcode_id0_o.alg_shift = scl_alg_shift_e'(inst_id0_i[30]);
                    alu_opcode_id0_o.is_unsigned = inst_id0_i[12];
                    alu_opcode_id0_o.rs1_en = 1'b1;
                    alu_opcode_id0_o.rs2_en = 1'b1;
                    alu_opcode_id0_o.rdst_en = 1'b1;
                    rdst_en_id0_o = 1'b1;
                end
            end
            INST_BR: begin
                inst_issue_type_id0_o = TO_ALU;
                inst_is_jbr_id0_o = 1'b1;
                inst_is_bid_id0_o = 1'b1;
                alu_opcode_id0_o.optype = BR;
                alu_opcode_id0_o.branch_func = scl_branch_func_e'(inst_id0_i[14 : 12]);
                alu_opcode_id0_o.with_imm = 1'b1;
                alu_opcode_id0_o.imm = b_imm(inst_id0_i);
                alu_opcode_id0_o.rs1_en = 1'b1;
                alu_opcode_id0_o.rs2_en = 1'b1;
            end
            INST_JALR: begin
                inst_issue_type_id0_o = TO_ALU;
                inst_is_jbr_id0_o = 1'b1;
                alu_opcode_id0_o.optype = JALR;
                alu_opcode_id0_o.with_imm = 1'b1;
                alu_opcode_id0_o.imm = i_imm(inst_id0_i);
                alu_opcode_id0_o.rs1_en = 1'b1;
                alu_opcode_id0_o.rdst_en = 1'b1;
                rdst_en_id0_o = 1'b1;
            end
            INST_JAL: begin
                inst_issue_type_id0_o = TO_ALU;
                inst_is_jbr_id0_o = 1'b1;
                alu_opcode_id0_o.optype = JAL;
                alu_opcode_id0_o.with_imm = 1'b1;
                alu_opcode_id0_o.imm = j_imm(inst_id0_i);
                alu_opcode_id0_o.rdst_en = 1'b1;
                rdst_en_id0_o = 1'b1;
            end
            INST_AUIPC: begin
                inst_issue_type_id0_o = TO_ALU;
                alu_opcode_id0_o.optype = UP;
                alu_opcode_id0_o.with_imm = 1'b1;
                alu_opcode_id0_o.imm = cur_pc_id0_i + u_imm(inst_id0_i);
                alu_opcode_id0_o.rdst_en = 1'b1;
                rdst_en_id0_o = 1'b1;
            end
            INST_LUI: begin
                inst_issue_type_id0_o = TO_ALU;
                alu_opcode_id0_o.optype = UP;
                alu_opcode_id0_o.with_imm = 1'b1;
                alu_opcode_id0_o.imm = u_imm(inst_id0_i);
                alu_opcode_id0_o.rdst_en = 1'b1;
                rdst_en_id0_o = 1'b1;
            end
            INST_ATOM: begin
                inst_issue_type_id0_o = TO_LSU;
                lsu_opcode_id0_o.optype = ATOM;
                lsu_opcode_id0_o.ls_size = WORD;
                lsu_opcode_id0_o.atom_func = scl_atom_func_e'(inst_id0_i[31 : 27]);
                case(inst_id0_i[26 : 25])
                    2'b01: begin
                        lsu_opcode_id0_o.predecessor = 4'b1111;
                        lsu_opcode_id0_o.successor = 4'b0000;
                    end
                    2'b10: begin
                        lsu_opcode_id0_o.predecessor = 4'b0000;
                        lsu_opcode_id0_o.successor = 4'b1111;
                    end
                    2'b11: begin
                        lsu_opcode_id0_o.predecessor = 4'b1111;
                        lsu_opcode_id0_o.successor = 4'b1111;
                    end
                    default: begin
                        lsu_opcode_id0_o.predecessor = 4'b0000;
                        lsu_opcode_id0_o.successor = 4'b0000;
                    end
                endcase
                lsu_opcode_id0_o.rs1_en = 1'b1;
                lsu_opcode_id0_o.rs2_en = 1'b1;
                lsu_opcode_id0_o.rdst_en = 1'b1;
                rdst_en_id0_o = 1'b1;
            end
            INST_VEC: begin
                inst_issue_type_id0_o = TO_VMU;
                vmu_opcode_id0_o.optype = VEC;
                vmu_opcode_id0_o.vec_func= vec_func_e'(inst_id0_i[14 : 11]);
                vmu_opcode_id0_o.vec_type.data = inst_id0_i[29 : 28];
                vmu_opcode_id0_o.vec_src_type = vec_src_type_e'(inst_id0_i[26 : 25]);
                vmu_opcode_id0_o.with_vpr = inst_id0_i[31];
                vmu_opcode_id0_o.vpr_index = inst_id0_i[30];
                case(vmu_opcode_id0_o.vec_func)
                    VLD: begin
                        vmu_opcode_id0_o.with_imm = 1'b1;
                        vmu_opcode_id0_o.imm = vl_imm(inst_id0_i);
                        vmu_opcode_id0_o.rs1_en = 1'b1;
                        vmu_opcode_id0_o.vrdst_en = 1'b1;
                    end
                    VST: begin
                        vmu_opcode_id0_o.with_imm = 1'b1;
                        vmu_opcode_id0_o.imm = vs_imm(inst_id0_i);
                        vmu_opcode_id0_o.rs1_en = 1'b1;
                        vmu_opcode_id0_o.vrs2_en = 1'b1;
                    end
                    VSHIFT: begin
                        vmu_opcode_id0_o.with_imm = (vmu_opcode_id0_o.vec_src_type == VEC_SRC_IMM) ? 1'b1 : 1'b0;
                        vmu_opcode_id0_o.imm = vsh_imm(inst_id0_i);
                        vmu_opcode_id0_o.vrs1_en = 1'b1;
                        vmu_opcode_id0_o.rs2_en = (vmu_opcode_id0_o.vec_src_type == VEC_SRC_SCL) ? 1'b1 : 1'b0;
                        vmu_opcode_id0_o.vrs2_en = (vmu_opcode_id0_o.vec_src_type == VEC_SRC_VEC) ? 1'b1 : 1'b0;
                        vmu_opcode_id0_o.vrdst_en = 1'b1;
                    end
                    default: begin
                        vmu_opcode_id0_o.with_imm = 1'b0;
                        vmu_opcode_id0_o.imm = 'h0;
                        vmu_opcode_id0_o.vrs1_en = 1'b1;
                        vmu_opcode_id0_o.rs2_en = (vmu_opcode_id0_o.vec_src_type == VEC_SRC_SCL) ? 1'b1 : 1'b0;
                        vmu_opcode_id0_o.vrs2_en = (vmu_opcode_id0_o.vec_src_type == VEC_SRC_VEC) ? 1'b1 : 1'b0;
                        vmu_opcode_id0_o.vrdst_en = 1'b1;
                    end
                endcase
            end
            INST_MAT: begin
                inst_issue_type_id0_o = TO_VMU;
                vmu_opcode_id0_o.optype = MTX;
                vmu_opcode_id0_o.mtx_func = mtx_func_e'(inst_id0_i[13 : 12]);
                vmu_opcode_id0_o.mtx_align = mtx_align_e'({inst_id0_i[14], inst_id0_i[29]});
                vmu_opcode_id0_o.mtx_acc = inst_id0_i[11];
                vmu_opcode_id0_o.rs1_en = 1'b1;
                vmu_opcode_id0_o.rs2_en = 1'b1;
                vmu_opcode_id0_o.vrs3_en = 1'b1;
                vmu_opcode_id0_o.vrdst_en = 1'b1;
            end
            INST_MISC_MEM: begin
                if(inst_id0_i[14 : 12] == 3'h0) begin
                    inst_issue_type_id0_o = TO_LSU;
                    lsu_opcode_id0_o.optype = FENCE;
                    lsu_opcode_id0_o.predecessor = inst_id0_i[27 : 24];
                    lsu_opcode_id0_o.successor = inst_id0_i[23 : 20];
                    inst_complete_id0_o = 1'b1;
                end else if(inst_id0_i[14 : 12] == 3'h1) begin
                    inst_issue_type_id0_o = TO_NONE;
                    sysc_opcode_id0_o.optype = SYSC_MEM;
                    sysc_opcode_id0_o.sysc = FENCEI;
                    inst_complete_id0_o = 1'b1;
                end else begin
                    inst_excp_en_id0_o = 1'b1;
                    inst_excp_id0_o = ILLEGAL_INST;
                    inst_complete_id0_o = 1'b1;
                end
            end
            INST_SYSTEM: begin
                if(inst_id0_i[14 : 12] == 3'h0) begin
                    inst_issue_type_id0_o = TO_NONE;
                    sysc_opcode_id0_o.optype = SYSC_SYS;
                    case(inst_id0_i[31 : 20])
                        12'b0000000_00010: sysc_opcode_id0_o.sysc = URET;
                        12'b0001000_00010: sysc_opcode_id0_o.sysc = SRET;
                        12'b0011000_00010: sysc_opcode_id0_o.sysc = MRET;
                        12'b0111101_10010: sysc_opcode_id0_o.sysc = DRET;
                        12'b0000000_00001: sysc_opcode_id0_o.sysc = EBREAK;
                        12'b0000000_00000: sysc_opcode_id0_o.sysc = ECALL;
                        12'b0001000_00101: sysc_opcode_id0_o.sysc = WFI;
                    endcase
                    inst_complete_id0_o = 1'b1;
                end else begin
                    csr_addr = i_imm(inst_id0_i);
                    if(csr_addr[11:6] == 6'b101111) begin
                        inst_issue_type_id0_o = TO_VMU;
                        vmu_opcode_id0_o.optype = VCSR;
                        vmu_opcode_id0_o.csr_func = scl_csr_func_e'(inst_id0_i[13: 12]);
                        vmu_opcode_id0_o.csr_addr = csr_addr;
                        vmu_opcode_id0_o.with_imm = inst_id0_i[14];
                        vmu_opcode_id0_o.imm = csr_imm(inst_id0_i);
                        vmu_opcode_id0_o.rs1_en = ~vmu_opcode_id0_o.with_imm;
                    end else begin
                        inst_issue_type_id0_o = TO_LSU;
                        lsu_opcode_id0_o.optype = CSR;
                        lsu_opcode_id0_o.ls_size = WORD;
                        lsu_opcode_id0_o.csr_func = scl_csr_func_e'(inst_id0_i[13 : 12]);
                        lsu_opcode_id0_o.csr_we_mask =
                            (  lsu_opcode_id0_o.csr_func == CSR_RS
                            || lsu_opcode_id0_o.csr_func == CSR_RC
                            || lsu_opcode_id0_o.csr_func == CSR_RSI
                            || lsu_opcode_id0_o.csr_func == CSR_RCI )
                            && (arc_rs1_index_id0_o == 0);
                        lsu_opcode_id0_o.csr_re_mask =
                            (  lsu_opcode_id0_o.csr_func == CSR_RW
                            || lsu_opcode_id0_o.csr_func == CSR_RWI )
                            && (arc_rdst_index_id0_o == 0);
                        lsu_opcode_id0_o.csr_addr = csr_addr;
                        lsu_opcode_id0_o.predecessor = inst_id0_i[27:24];
                        lsu_opcode_id0_o.successor = inst_id0_i[23:20];
                        lsu_opcode_id0_o.with_imm = inst_id0_i[14];
                        lsu_opcode_id0_o.imm = csr_imm(inst_id0_i);
                        lsu_opcode_id0_o.rs1_en = ~lsu_opcode_id0_o.with_imm;
                        lsu_opcode_id0_o.rdst_en = 1'b1;
                        rdst_en_id0_o = 1'b1;
                    end
                end
            end
            default: begin
                inst_excp_en_id0_o = 1'b1;
                inst_excp_id0_o = ILLEGAL_INST;
                inst_complete_id0_o = 1'b1;
            end
        endcase
    end
endmodule : hpu_id_dec
