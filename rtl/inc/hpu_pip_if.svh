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
// FILE NAME  : hpu_pip_if.svh
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

//`ifndef HPU_PIP_IF_SVH
`define HPU_PIP_IF_SVH

// ==========
// Instruction fetch
// ==========
parameter int INST_FETCH_PARAL = 4;
parameter int INST_FETCH_BIT = $clog2(INST_FETCH_PARAL);
parameter int INST_FETCH_INC_BIT = INST_FETCH_BIT + 2;

parameter int INST_DEC_PARAL = 2;
parameter int INST_DEC_BIT = $clog2(INST_DEC_PARAL);

parameter int IBUF_PARAL = INST_FETCH_PARAL/INST_DEC_PARAL;
parameter int IBUF_LEN = 8;
parameter int IBUF_INDEX = $clog2(IBUF_LEN);

function automatic logic[PC_WTH-1 : INST_FETCH_BIT+2] fet_pc_base(pc_t pc);
    return pc[PC_WTH-1 : INST_FETCH_BIT+2];
endfunction

function automatic logic[PC_WTH-1 : INST_DEC_BIT+2] dec_pc_base(pc_t pc);
    return pc[PC_WTH-1 : INST_DEC_BIT+2];
endfunction

// -----
// BTB
parameter int BTB_LEN = 32;
parameter int BTB_INDEX = $clog2(BTB_LEN);

parameter int BTB_TAG_WTH = 16;
parameter int BTB_WTH = BTB_TAG_WTH + PC_WTH + 3; // 3 is the width of qdec_type_e

parameter int BTB_WAY_PARAL = 2;
parameter int BTB_WAY_BIT = $clog2(BTB_WAY_PARAL);

function automatic logic [BTB_TAG_WTH-1 : 0] get_btb_tag (input logic [INST_WTH-1 : 0] addr);
    return {addr[31:28], addr[2 + INST_FETCH_BIT + BTB_INDEX +: (BTB_TAG_WTH-6)], addr[2 +: INST_FETCH_BIT]};
endfunction

function automatic logic [BTB_INDEX-1 : 0] get_btb_index (input logic [INST_WTH-1 : 0] addr);
    return addr[2 + INST_FETCH_BIT +: BTB_INDEX]; // ^ addr[2 +: INST_FETCH_BIT];
endfunction

// -----
// RAS
parameter int RAS_LEN = 16;
parameter int RAS_INDEX = $clog2(RAS_LEN);

// -----
// BHT & PHT
parameter int BHT_LEN = 128;
parameter int BHT_INDEX = $clog2(BHT_LEN);
parameter int BHT_WTH = 5;

parameter int PHT_LEN = 128;
parameter int PHT_INDEX= $clog2(PHT_LEN);

function automatic logic [BHT_INDEX-1 : 0] get_bht_index (input logic [INST_WTH-1 : 0] addr);
    return {addr[2 + INST_FETCH_BIT +: BHT_INDEX]};
endfunction

function automatic logic [PHT_INDEX-1 : 0] get_pht_index (
    input logic [INST_WTH-1 : 0] addr,
    input logic [BHT_WTH-1 : 0] bhr
);
    return addr[4 + INST_FETCH_BIT +: PHT_INDEX] ^ {bhr[BHT_WTH-1 : 0], addr[2 +: 2]};
endfunction : get_pht_index

// -----
// quick decoder
typedef enum logic [2 : 0] {
    IS_NORMAL = 3'h0,
    IS_BRANCH = 3'h1,
    IS_JAL = 3'h2,
    IS_JALR = 3'h3,
    IS_CALL = 3'h4,
    IS_RET = 3'h5,
    IS_AMO = 3'h6,
    IS_FENCE = 3'h7
} qdec_type_e;

typedef struct packed {
    logic                                       en;
    logic[BTB_WAY_BIT-1 : 0]                    way_sel;
    qdec_type_e                                 qdec_type; //could be optimized as "logic is_ret"
    pc_t                                        pred_npc;
    pc_t                                        cur_pc;
} update_btb_t;

typedef struct packed {
    logic                                       push_en;
    pc_t                                        push_pred_npc;
    logic                                       pop_en;
} update_ras_t;

typedef struct packed {
    logic                                       en;
    logic                                       is_taken;
    pc_t                                        cur_pc;
} update_fgpr_t;

typedef struct packed {
    logic                                       en;
    logic                                       is_taken;
    pc_t                                        cur_pc;
    logic[BHT_WTH-1 : 0]                        bhr;
} update_pht_t;

// instruction buffer
typedef struct packed {
    logic[INST_DEC_PARAL-1 : 0]                 avail;
    inst_t[INST_DEC_PARAL-1 : 0]                inst;
    qdec_type_e[INST_DEC_PARAL-1 : 0]           qdec_type;
    pc_t                                        cur_pc;
    pc_t                                        pred_npc;
    logic                                       pred_bid_taken;
    logic[BTB_WAY_BIT-1 : 0]                    btb_way_sel;
    logic[INST_FETCH_BIT-1 : 0]                 fet_pc_offset;
} if_inst_t;

//`endif
