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
// FILE NAME  : hpu_pip_bkend.svh
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

//`ifndef HPU_PIP_BKEND_SVH
`define HPU_PIP_BKEND_SVH

// -----
// Re-order Buffer
parameter ROB_LEN = 64;
parameter ROB_INDEX = $clog2(ROB_LEN);

// -----
// ALU/BRU
parameter ALU_IQ_LEN = 8;
parameter ALU_IQ_INDEX = $clog2(ALU_IQ_LEN);

// -----
// MDU
parameter MDU_IQ_LEN = 8;
parameter MDU_IQ_INDEX = $clog2(MDU_IQ_LEN);

// -----
// LSU
parameter LSU_IQ_LEN = 8;
parameter LSU_IQ_INDEX = $clog2(LSU_IQ_LEN);

parameter LAQ_LEN = 8;
parameter LAQ_INDEX = $clog2(LAQ_LEN);

parameter SQ_LEN = 8;
parameter SQ_INDEX = $clog2(SQ_LEN);

// -----
// VMU
parameter VMU_IQ_LEN = 8;
parameter VMU_IQ_INDEX = $clog2(VMU_IQ_LEN);

parameter VEC_SIZE = 64;
parameter VEC_SIZE_H = 8;
parameter VEC_SIZE_V = 8;
parameter VEC_SIZE_N = 8;

parameter LM_ADDR_WTH = 13;
parameter LM_IND_WTH = 3;
parameter LM_OFFSET_WTH = 9;

// below definition is obsolete 
parameter MRA_IND_WTH = 3;
parameter MRA_ADDR_WTH = 9;

parameter MRB_IND_WTH = 3;
parameter MRB_ADDR_WTH = 9;

parameter MRA_DATA_WTH = MTX_WTH * VEC_SIZE;
parameter MRB_DATA_WTH = MTX_WTH * VEC_SIZE;
parameter MRB_VM_DATA_WTH = 512*8;
parameter VEC_DATA_WTH = 32*64;

// -----
// ALU
typedef struct packed {
    // instruction basic item
    alu_opcode_t                                opcode;
    ckpt_t                                      ckpt;
    phy_sr_index_t                              phy_rs1_index;
    phy_sr_index_t                              phy_rs2_index;
    phy_sr_index_t                              phy_rdst_index;
    // others:
    logic                                       is_jbr;
    pc_t                                        cur_pc;
    logic                                       rob_flag;
    logic[ROB_INDEX-1 : 0]                      rob_index;
    logic[INST_DEC_BIT-1 : 0]                   rob_offset;
} alu_inst_t;

typedef struct packed {
    logic                                       avail;
    alu_inst_t                                  alu_inst;
    sr_status_e                                 phy_rs1_ready;
    sr_status_e                                 phy_rs2_ready;
} alu_inst_pkg_t;

typedef struct packed {
    logic                                       en;
    logic                                       rob_flag;
    logic[ROB_INDEX-1 : 0]                      rob_index;
    logic[INST_DEC_BIT-1 : 0]                   rob_offset;
    logic                                       excp_en;
    excp_e                                      excp;
    logic                                       is_jbr;
    pc_t                                        next_pc;
    logic                                       br_taken;
} alu_commit_t;

// -----
// MDU
typedef struct packed {
    // instruction basic item
    mdu_opcode_t                                opcode;
    ckpt_t                                      ckpt;
    phy_sr_index_t                              phy_rs1_index;
    phy_sr_index_t                              phy_rs2_index;
    phy_sr_index_t                              phy_rdst_index;
    // others:
    logic[ROB_INDEX-1 : 0]                      rob_index;
    logic[INST_DEC_BIT-1 : 0]                   rob_offset;
    // source and destinate register
} mdu_inst_t;

typedef struct packed {
    logic                                       avail;
    mdu_inst_t                                  mdu_inst;
    sr_status_e                                 phy_rs1_ready;
    sr_status_e                                 phy_rs2_ready;
} mdu_inst_pkg_t;

typedef struct packed {
    logic                                       en;
    logic[ROB_INDEX-1 : 0]                      rob_index;
    logic[INST_DEC_BIT-1 : 0]                   rob_offset;
} mdu_commit_t;

// -----
// LSU
typedef struct packed {
    // instruction basic item
    lsu_opcode_t                                opcode;
    ckpt_t                                      ckpt;
    phy_sr_index_t                              phy_rs1_index;
    phy_sr_index_t                              phy_rs2_index;
    phy_sr_index_t                              phy_rdst_index;
    // others:
    logic[ROB_INDEX-1 : 0]                      rob_index;
    logic[INST_DEC_BIT-1 : 0]                   rob_offset;
    // source and destinate register
} lsu_inst_t;

typedef struct packed {
    logic                                       avail;
    lsu_inst_t                                  lsu_inst;
    sr_status_e                                 phy_rs1_ready;
    sr_status_e                                 phy_rs2_ready;
} lsu_inst_pkg_t;

typedef struct packed {
    logic                                       en;
    logic[ROB_INDEX-1 : 0]                      rob_index;
    logic[INST_DEC_BIT-1 : 0]                   rob_offset;
    logic                                       excp_en;
    excp_e                                      excp;
    logic                                       is_ldst;
    pc_t                                        ldst_addr;
    data_t                                      ldst_data;
    //logic                                       vmu_csr_active;
} lsu_commit_t;

typedef struct packed {
    logic                                       en;
    logic[ROB_INDEX-1 : 0]                      rob_index;
    logic[INST_DEC_BIT : 0]                     rob_rt_sum;
} lsu_retire_t;

typedef enum logic[1 : 0] {
    LAQ_LD = 0,
    LAQ_CSR = 1,
    LAQ_AMO = 2,
    LAQ_FENCE = 3
} laq_type_e;

typedef enum logic[1 : 0] {
    SAQ_ST = 0,
    SAQ_CSR = 1,
    SAQ_AMO = 2,
    SAQ_FENCE = 3
} saq_type_e;

typedef enum logic {
    ACC_MEM = 0,
    ACC_CSR = 1
} lsu_acc_type_e;

typedef struct packed {
    laq_type_e                                  ld_type; // LD, CSR, AMO, FENCE
    dec_size_e                                  ld_size;
    logic                                       is_unsigned;
    pc_t                                        addr;
    data_strobe_t                               strb;
    logic                                       order_pred;
    logic                                       order_succ;
    logic                                       ld_dpend_avail;
    logic[LAQ_INDEX-1 : 0]                      ld_dpend_index;
    logic                                       st_dpend_avail;
    logic[SQ_INDEX-1 : 0]                       st_dpend_index;
    logic                                       st_dpend_fwd;
    logic                                       crsp_sq_avail;
    logic[SQ_INDEX-1 : 0]                       crsp_sq_index;
    phy_sr_index_t                              phy_rdst_index;
    logic[ROB_INDEX-1 : 0]                      rob_index;
    logic[INST_DEC_BIT-1 : 0]                   rob_offset;
    ckpt_t                                      ckpt;
} laq_item_t;

typedef struct packed {
    saq_type_e                                  st_type; // ST, CSR, AMO, FENCE
    scl_atom_func_e                             atom_func;
    scl_csr_func_e                              csr_func;
    pc_t                                        addr;
    data_t                                      data;
    data_strobe_t                               strb;
    logic                                       data_rdy;
    logic                                       order_pred;
    logic                                       order_succ;
    logic                                       st_dpend_avail;
    logic[SQ_INDEX-1 : 0]                       st_dpend_index;
    logic[LAQ_INDEX-1 : 0]                      crsp_laq_index;
    ckpt_t                                      ckpt;
} sq_item_t;

// -- memory interface
typedef struct packed {
    logic                                       wr_en;
    logic                                       rl_lock;
    pc_t                                        waddr;
    data_t                                      wdata;
    data_strobe_t                               wstrb;
} mem_wr_req_t;

typedef struct packed {
    logic                                       wr_suc;
} mem_wr_rsp_t;

typedef struct packed {
    logic                                       rd_en;
    logic                                       aq_lock;
    pc_t                                        raddr;
} mem_rd_req_t;

typedef struct packed {
    logic                                       rd_suc;
    data_t                                      rdata;
} mem_rd_rsp_t;

// -----
// last design
typedef struct packed{
    logic                                       is_valid;
    ckpt_t                                      ckpt;
    logic[ROB_INDEX-1 : 0]                      rob_index;
    logic[INST_DEC_BIT-1 : 0]                   rob_offset;
    logic                                       mem_addr_rdy;
    logic                                       mem_data_rdy;
    pc_t                                        mem_addr;
    data_t                                      mem_data;
    logic[1:0]                                  status;
    logic[LSU_IQ_INDEX-1 : 0]                   pos_index;
}lsu_wbuffer_csr_t;

typedef struct packed{
    logic                                       is_valid;
    ckpt_t                                      ckpt;
    logic[ROB_INDEX-1 : 0]                      rob_index;
    logic[INST_DEC_BIT-1 : 0]                   rob_offset;
    logic                                       mem_addr_rdy;
    logic                                       mem_data_rdy;
    pc_t                                        mem_addr;
    data_t                                      mem_data;
    logic[1:0]                                  status;
    logic[LSU_IQ_INDEX-1 : 0]                   pos_index;
    logic                                       is_atom;
    dec_size_e                                  ls_size; // byte, half word, word, double word
}lsu_wbuffer_st_atom_t;

// -----
// VMU
typedef struct packed {
    // instruction basic item
    vmu_opcode_t                                opcode;
    ckpt_t                                      ckpt;
    phy_sr_index_t                              phy_rs1_index;
    phy_sr_index_t                              phy_rs2_index;
    vr_index_t                                  vrs1_index;
    vr_index_t                                  vrs2_index;
    vr_index_t                                  vrs3_index;
    vr_index_t                                  vrdst_index;
    // others:
    logic[ROB_INDEX-1 : 0]                      rob_index;
    logic[INST_DEC_BIT-1 : 0]                   rob_offset;
} vmu_inst_t;

typedef struct packed {
    logic                                       avail;
    vmu_inst_t                                  vmu_inst;
    sr_status_e                                 phy_rs1_ready;
    sr_status_e                                 phy_rs2_ready;
} vmu_inst_pkg_t;

typedef struct packed {
    logic                                       en;
    logic[ROB_INDEX-1 : 0]                      rob_index;
    logic[INST_DEC_BIT-1 : 0]                   rob_offset;
} vmu_commit_t;

typedef struct packed {
    logic                                       en;
    logic[INST_DEC_BIT : 0]                     vmu_rt_sum;
} vmu_retire_t;

// -----
// Re-order Buffer
typedef struct packed {
    // instruction basic item
    inst_t                                      inst;
    issue_type_e                                issue_type;
    optype_t                                    itype;
    logic                                       is_ld;
    logic                                       is_st;
    logic                                       csr_we_mask;
    scl_sysc_e                                  sysc;
    logic                                       rdst_en;
    arc_sr_index_t                              arc_rdst_index; // rdst is already conatained in instr
    phy_sr_index_t                              phy_rdst_index;
    phy_sr_index_t                              phy_old_rdst_index;
} rob_inst_t;

typedef struct packed {
    rob_inst_t                                  rob_inst;
    logic                                       avail;
    logic                                       complete;
    logic                                       excp_en;
    excp_e                                      excp;
} rob_inst_pkg_t;

typedef struct packed {
    pc_t                                        cur_pc; // the slot basic PC
    pc_t                                        pred_npc;
    logic                                       pred_bid_taken;
    // for Jump/Branch instruction
    logic                                       is_jbr;
    logic                                       is_bid;
    logic[INST_DEC_BIT-1 : 0]                   first_pc_offset; // the PC LSB of first valid instruction
    logic[INST_DEC_BIT-1 : 0]                   last_pc_offset; // the PC LSB of last valid instruction
    logic                                       ckpt_act;
    ckpt_t                                      ckpt;
    // for HPU_IF update
    qdec_type_e                                 qdec_type;
    logic[BTB_WAY_BIT-1 : 0]                    btb_way_sel;
    logic[INST_FETCH_BIT-1 : 0]                 fet_pc_offset;
} rob_slot_pkg_t;

typedef struct packed {
    pc_t                                        ldst_addr;
    data_t                                      ldst_data;
} rob_inst_ls_t;

typedef struct packed {
    logic                                       en;
    ctrl_cmd_e                                  cmd;
    pc_t                                        npc;
    excp_e                                      excp_type;
    inst_t                                      excp_inst;
    pc_t                                        excp_addr;
    scl_sysc_e                                  sysc;
    logic                                       bid_mispred;
} rob_cmd_t;

// -----
// Inter function units
typedef struct packed {
    logic                                       en;
    phy_sr_index_t                              rdst_index;
} awake_index_t;

typedef struct packed {
    logic                                       en;
    phy_sr_index_t                              rdst_index;
    data_t                                      rdst_data;
} bypass_data_t;

typedef struct packed {
    logic                                       en;
    phy_sr_index_t                              rdst_index;
    data_t[VEC_SIZE-1 : 0]                      rdst_data;
    logic[VEC_SIZE-1 : 0]                       rdst_mask;
} vmu_bypass_data_t;

//`endif
