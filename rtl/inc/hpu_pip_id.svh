// ---------------------------------------------------------------------------------------------------------------------
// Copyright (c) 1986 - 2020, CAG team, Institute of AI and Robotics, Xi'an Jiaotong University. Proprietary and
// Confidential All Rights Reserved.
// ---------------------------------------------------------------------------------------------------------------------
// NOTICE: All information contained herein is, and remains the property of CAG team, Institute of AI and Robotics,
// Xi'an Jiaotong University. The intellectual and technical concepts contained herein are proprietary to CAG team, and
// may be covered by P.R.C. and Foreign Patents, patents in process, and are protected by trade secret or copyright law.
//
// This work may not be copied, modified, re-published, uploaded, executed, or distributed in any way, in any time, in
// any medium, whether in whole or in part, without prior written permission from CAG team, Institute of AI and
// Robotics, Xi'an Jiaotong University.
//
// The copyright notice above does not evidence any actual or intended publication or disclosure of this source code,
// which includes information that is confidential and/or proprietary, and is a trade secret, of CAG team.
// ---------------------------------------------------------------------------------------------------------------------
// FILE NAME  : hpu_pip_id.svh
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

//`ifndef HPU_PIP_ID_SVH
`define HPU_PIP_ID_SVH

// -----
// Register renaming
parameter ARC_SR_LEN = 32;
parameter ARC_SR_INDEX = $clog2(ARC_SR_LEN);
parameter PHY_SR_LEN = 64;
parameter PHY_SR_INDEX = $clog2(PHY_SR_LEN);
parameter VR_LEN = 16;
parameter VR_INDEX = $clog2(VR_LEN);
parameter VPR_LEN= 8;
parameter VPR_INDEX = $clog2(VPR_LEN);

parameter CKPT_LEN = 8;
parameter CKPT_INDEX = $clog2(CKPT_LEN);

typedef logic[ARC_SR_INDEX-1 : 0] arc_sr_index_t;
typedef logic[PHY_SR_INDEX-1 : 0] phy_sr_index_t;
typedef logic[VR_INDEX-1 : 0] vr_index_t;
typedef logic[VPR_INDEX-1 : 0] vpr_index_t;
typedef logic[CKPT_INDEX-1 : 0] ckpt_index_t;

// PRM
typedef enum logic { FLY = 1'b0, READY = 1'b1 } sr_status_e;

// -----
// DEC
parameter INST_LD       = 7'b0000011;
parameter INST_ST       = 7'b0100011;
parameter INST_OPI      = 7'b0010011;
parameter INST_OP       = 7'b0110011;
parameter INST_BR       = 7'b1100011;
parameter INST_JALR     = 7'b1100111;
parameter INST_JAL      = 7'b1101111;
parameter INST_AUIPC    = 7'b0010111;
parameter INST_LUI      = 7'b0110111;
parameter INST_ATOM     = 7'b0101111;
parameter INST_VEC      = 7'b0101011;
parameter INST_MAT      = 7'b0001011;
parameter INST_MISC_MEM = 7'b0001111;
parameter INST_SYSTEM   = 7'b1110011;

typedef enum logic [1 : 0] {
    BYTE = 2'b00,
    HALF = 2'b01,
    WORD = 2'b10,
    DWORD = 2'b11
} dec_size_e;

// classify the instruction type
typedef enum logic [2 : 0] {
    ALG = 3'h0,
    UP,
    JAL,
    JALR,
    BR,
    CALL,
    RET
} itype_alu_e;

typedef enum logic [2 : 0] {
    LOAD = 3'h0,
    STORE,
    CSR,
    ATOM,
    FENCE
} itype_lsu_e;

typedef enum logic [2 : 0] {
    MUL = 3'h0,
    MULH,
    DIV,
    REM
} itype_mdu_e;

typedef enum logic [2 : 0] {
    VEC = 3'h0,
    MTX,
    VCSR
} itype_vmu_e;

typedef enum logic [2 : 0] {
    SYSC_MEM = 3'h0,
    SYSC_SYS
} itype_sysc_e;

typedef union packed {
    itype_alu_e                                 alu;
    itype_lsu_e                                 lsu;
    itype_vmu_e                                 vmu;
    itype_sysc_e                                sysc;
} optype_t;

typedef enum logic [3 : 0] {
    TO_NONE = 4'h0,
    TO_ALU  = 4'h1,
    TO_LSU  = 4'h2,
    TO_MDU  = 4'h4,
    TO_VMU  = 4'h8
} issue_type_e;

// -----
// For ALU/BRU/SYSC instructions
typedef enum logic [2 : 0] {
    ALG_AS   = 3'b000,
    ALG_SL   = 3'b001,
    ALG_SLT  = 3'b010,
    ALG_SLTU = 3'b011,
    ALG_XOR  = 3'b100,
    ALG_SR   = 3'b101,
    ALG_OR   = 3'b110,
    ALG_AND  = 3'b111
} scl_alg_func_e;

typedef enum logic {
    ALG_ADD = 1'b0,
    ALG_SUB = 1'b1
} scl_alg_add_e;

typedef enum logic {
    ALG_LOGIC = 1'b0,
    ALG_ALGRITHM = 1'b1
} scl_alg_shift_e;

typedef enum logic [2 : 0] {
    BR_EQ = 3'b000,
    BR_NE = 3'b001,
    BR_LT = 3'b100,
    BR_GE = 3'b101,
    BR_LTU = 3'b110,
    BR_GEU = 3'b111
} scl_branch_func_e;

// -----
// For System control instructions
typedef enum logic [3 : 0] {
    ECALL = 4'h0,
    EBREAK,
    DRET,
    MRET,
    SRET,
    URET,
    WFI,
    FENCEI
} scl_sysc_e;

// -----
// For LSU instructions
typedef enum logic [2 : 0] {
    CSR_RW = 3'b001,
    CSR_RS = 3'b010,
    CSR_RC = 3'b011,
    CSR_RWI= 3'b101,
    CSR_RSI= 3'b110,
    CSR_RCI= 3'b111
} scl_csr_func_e;

typedef enum logic [4 : 0] {
    ATOM_LR   = 5'b00010,
    ATOM_SC   = 5'b00011,
    ATOM_SWAP = 5'b00001,
    ATOM_ADD  = 5'b00000,
    ATOM_XOR  = 5'b00100,
    ATOM_AND  = 5'b01100,
    ATOM_OR   = 5'b01000,
    ATOM_MIN  = 5'b10000,
    ATOM_MAX  = 5'b10100,
    ATOM_MINU = 5'b11000,
    ATOM_MAXU = 5'b11100
} scl_atom_func_e;

// -----
// For VMU instructions
typedef enum logic [3 : 0] {
    VLD     = 4'b0000,
    VST     = 4'b0001,
    VOP     = 4'b0010,
    VMUL    = 4'b0011,
    VLOGIC  = 4'b0100,
    VSHIFT  = 4'b0101,
    VALIGN  = 4'b0110,
    VLUT    = 4'b0111,
    VPCMP   = 4'b1000,
    VPLOGIC = 4'b1001,
    VPSWAP  = 4'b1010,
    VFOP    = 4'b1100
    //VFMAD   = 4'b1110 // obsolete
} vec_func_e;

typedef enum logic [1 : 0] {
    VEC_ADD = 2'b00,
    VEC_SUB = 2'b01,
    VEC_MAX = 2'b10,
    VEC_MIN = 2'b11
} vec_alg_type_e;

typedef enum logic [1 : 0] {
    VF_ADD = 2'b00,
    VF_SUB = 2'b01,
    VF_MUL = 2'b10
} vec_fop_type_e;

typedef enum logic [1 : 0] {
    VEC_AND = 2'b00,
    VEC_OR  = 2'b01,
    VEC_XOR = 2'b10,
    VEC_XNOR = 2'b11
} vec_lgc_type_e;

typedef enum logic [1 : 0] {
    VEC_HORI = 2'b00,
    VEC_VERT = 2'b01
} vec_align_type_e;

typedef enum logic [1 : 0] {
    VEC_EQ = 2'b00,
    VEC_NE = 2'b01,
    VEC_LT = 2'b10,
    VEC_GE = 2'b11
} vec_cmp_type_e;

typedef enum logic [1 : 0] {
    VEC_SLL = 2'b00,
    VEC_SRL = 2'b01,
    VEC_SRA = 2'b11
} vec_shift_type_e;

typedef union packed {
    vec_alg_type_e alg;
    vec_fop_type_e fop;
    vec_lgc_type_e lgc;
    vec_cmp_type_e cmp;
    vec_shift_type_e shift;
    vec_align_type_e align;
    dec_size_e ls_size;
    logic[1 : 0] data;
} vec_type_t;

typedef enum logic [1 : 0] {
    VEC_SRC_VEC = 2'b00,
    VEC_SRC_SCL = 2'b01,
    VEC_SRC_IMM = 2'b10
} vec_src_type_e;

typedef enum logic [1 : 0] {
    MTX_MTX = 2'b00,
    MTX_DOT = 2'b01,
    MTX_VEC = 2'b10,
    MTX_VECBUNDLE = 2'b11
} mtx_func_e;

typedef enum logic [1 : 0] {
    MTX_ALG_NONE  = 2'b00,
    MTX_ALG_UP = 2'b10,
    MTX_ALG_DN = 2'b11
} mtx_align_e;

parameter ROUND_LOW = 2'h0;
parameter ROUND_MID = 2'h1;
parameter ROUND_UP = 2'h2;

// ALU/BRU parameters
typedef struct packed {
    itype_alu_e                                 optype;
    scl_alg_func_e                              alg_func;       // algebra,and,or,xor,sll,slr,sra,slt,sge,se,sne
    scl_alg_add_e                               alg_add;        // add, sub
    scl_alg_shift_e                             alg_shift;      // logic, algebra
    scl_branch_func_e                           branch_func;    // eq, ne, lt, ge
    logic                                       is_unsigned;    // signed, unsigned for op, up, jp, and br
    logic                                       rs1_en;
    logic                                       rs2_en;
    logic                                       rdst_en;
    logic                                       with_imm;       // with imm, without imm
    data_t                                      imm;
} alu_opcode_t;

// LSU parameters
typedef struct packed {
    itype_lsu_e                                 optype;
    scl_csr_func_e                              csr_func;       // rw, rs, rc
    logic                                       csr_we_mask;    // CSR write avoid
    logic                                       csr_re_mask;    // CSR read avoid
    csr_addr_t                                  csr_addr;       // CSR address
    scl_atom_func_e                             atom_func;      // lr, sc, atm ops
    logic[3 : 0]                                predecessor;    // predecessor of FENCE instruction
    logic[3 : 0]                                successor;      // successor of FENCE instruction
    dec_size_e                                  ls_size;        // byte, half word, word, double word
    logic                                       is_unsigned;    // signed, unsigned
    logic                                       rs1_en;
    logic                                       rs2_en;
    logic                                       rdst_en;
    logic                                       with_imm;       // with imm, without imm
    data_t                                      imm;            // imm
} lsu_opcode_t;

// MDU parameters
typedef struct packed {
    itype_mdu_e                                 optype;
    logic                                       rs1_unsigned;   // whether rs1 is unsigned
    logic                                       rs2_unsigned;   // whether rs2 is unsigned
} mdu_opcode_t;

// VMU parameters
typedef struct packed {
    itype_vmu_e                                 optype;
    vec_func_e                                  vec_func;       // ld, st, op, mul, logic, shift, align, lut, vpcmp,
                                                                // vplogic, vpswap, fop, fmad
    vec_type_t                                  vec_type;       // for alg type: add, sub, max, min
                                                                // for cmp type: eq, ne, lt, ge
                                                                // for shift type: sll, srl, sra
                                                                // for ls_size: byte, half word, word, double word
    vec_src_type_e                              vec_src_type;   // rs2 type: vector, scalar, imm
    logic                                       with_vpr;       // with vpr, without vpr
    logic                                       vpr_index;      // vpr index
    mtx_func_e                                  mtx_func;       // matrix, matrix dot, matrix vector, mv bundle
    mtx_align_e                                 mtx_align;      // normal, align upper, align down
    logic                                       mtx_acc;        // none, accumulator
    scl_csr_func_e                              csr_func;       // rw, rs, rc
    csr_addr_t                                  csr_addr;
    logic                                       rs1_en;
    logic                                       vrs1_en;
    logic                                       rs2_en;
    logic                                       vrs2_en;
    logic                                       vrs3_en;
    logic                                       vrdst_en;
    logic                                       with_imm;       // with imm, without imm
    data_t                                      imm;            // imm
} vmu_opcode_t;

// SYSC parameters
typedef struct packed {
    itype_sysc_e                                optype;
    scl_sysc_e                                  sysc;           // ecall, ebreak, mret, dret, wfi, fencei
} sysc_opcode_t;

// -----
// Register renaming
typedef struct packed {
    logic                                       flag;
    ckpt_index_t                                index;
} ckpt_t;

typedef struct packed {
    logic                                       en;
    ckpt_t                                      ckpt;
    logic                                       ckpt_suc;
    pc_t                                        next_pc;
} update_ckpt_t;

typedef struct packed {
    logic                                       en;
    ckpt_t                                      ckpt;
} update_arc_ckpt_t;

function automatic logic chk_ckpt (
    ckpt_t          obj,
    ckpt_t          _start,
    ckpt_t          _end
);
    if(({obj.flag^_start.flag, obj.index} <= {_end.flag^_start.flag, _end.index})
        && ({obj.flag^_start.flag, obj.index} > _start.index)) begin
        chk_ckpt = 1'b1;
    end else begin
        chk_ckpt = 1'b0;
    end
endfunction : chk_ckpt


//`endif
