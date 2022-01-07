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
// FILE NAME  : hpu_pip_trig.svh
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

//`ifndef HPU_PIP_TRIG_SVH
`define HPU_PIP_TRIG_SVH

parameter TRIG_NUM = 4;
parameter TRIG_NUM_BIT = $clog2(TRIG_NUM);

typedef enum logic[3 : 0] {
    TRIG_TYPE_INVALID = 0,
    TRIG_TYPE_MCONTROL = 2,
    TRIG_TYPE_ICOUNT = 3,
    TRIG_TYPE_ITRIGGER = 4,
    TRIG_TYPE_ETRIGGER = 5
} trig_type_e;

typedef struct packed {
    trig_type_e     typ;
    logic           dmode;
    logic[5 : 0]    maskmax;
    logic           hit;
    logic           select;
    logic           timing;
    logic[1 : 0]    sizelo;
    logic[3 : 0]    action;
    logic           chain;
    logic[3 : 0]    match;
    logic           m_mode_en;
    logic           h_mode_en;
    logic           s_mode_en;
    logic           u_mode_en;
    logic           execute;
    logic           store;
    logic           load;
} csr_mcontrol_t;

typedef struct packed {
    trig_type_e     typ;
    logic           dmode;
    logic[1 : 0]    rsv0;
    logic           hit;
    logic[13 : 0]   count;
    logic           m_mode_en;
    logic           h_mode_en;
    logic           s_mode_en;
    logic           u_mode_en;
    logic[5 : 0]    action;
} csr_icount_t;

typedef struct packed {
    trig_type_e     typ;
    logic           dmode;
    logic           hit;
    logic[15 : 0]   rsv0;
    logic           m_mode_en;
    logic           h_mode_en;
    logic           s_mode_en;
    logic           u_mode_en;
    logic[5 : 0]    action;
} csr_ietrigger_t;

typedef struct packed {
    trig_type_e     typ;
    logic           dmode;
    logic[26 : 0]   rsv0;
} csr_tdata1_common_t;

typedef union packed {
    csr_mcontrol_t mcontrol;
    csr_icount_t icount;
    csr_ietrigger_t ietrigger;
    csr_tdata1_common_t common;
} csr_trig_tdata1_t;

typedef struct packed {
    logic[5 : 0]    mvalue;
    logic           mselect;
    logic[6 : 0]    rsv0;
    logic[15 : 0]   svalue;
    logic[1 : 0]    sselect;
} csr_trig_tdata3_t;

// -----
// trigger
typedef struct packed {
    logic                                       avail;
    pc_t                                        pc;
    inst_t                                      inst;
    logic                                       is_ld;
    logic                                       is_st;
    pc_t                                        ldst_addr;
    data_t                                      ldst_data;
} inst_trig_info_t;

// -----
// Physical register mark
typedef struct packed {
    logic                                       avail;
    ckpt_t                                      ckpt;
    phy_sr_index_t                              phy_rdst_index;
} prm_inst_t;

typedef struct packed {
    logic                                       en;
    logic[INST_DEC_PARAL-1:0]                   avail;
    arc_sr_index_t[INST_DEC_PARAL-1:0]          arc_rdst_index;
    phy_sr_index_t[INST_DEC_PARAL-1:0]          phy_rdst_index;
    phy_sr_index_t[INST_DEC_PARAL-1:0]          phy_old_rdst_index;
} update_arat_t;

// -----
// Trigger
function automatic data_t[INST_DEC_PARAL-1 : 0] get_trig_probe (
    input csr_trig_tdata1_t tdata1,
    input inst_trig_info_t[INST_DEC_PARAL-1 : 0] inst
);
    for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
        get_trig_probe[i] = data_t'(0);
        // perform a match on the virtual address
        if(tdata1.mcontrol.select == 1'b0) begin
            if(tdata1.mcontrol.execute) begin
                get_trig_probe[i] = inst[i].pc;
            end else if(tdata1.mcontrol.store) begin
                get_trig_probe[i] = data_t'(inst[i].ldst_addr);
            end else if(tdata1.mcontrol.load) begin
                get_trig_probe[i] = data_t'(inst[i].ldst_addr);
            end
            // perform a match on the data value loaded/stored, or the instruction executed.
        end else begin
            if(tdata1.mcontrol.execute) begin
                get_trig_probe[i] = inst[i].inst;
            end else if(tdata1.mcontrol.store) begin
                get_trig_probe[i] = inst[i].ldst_data;
            end else if(tdata1.mcontrol.load) begin
                get_trig_probe[i] = inst[i].ldst_data;
            end
        end
    end
    return get_trig_probe;
endfunction

function automatic logic[INST_DEC_PARAL-1 : 0] get_trig_probe_act (
    input csr_trig_tdata1_t tdata1,
    input inst_trig_info_t[INST_DEC_PARAL-1 : 0] inst,
    input logic[INST_DEC_PARAL-1 : 0] inst_act
);
    for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
        // trigger enable signal
        get_trig_probe_act[i] = 1'b0;
        if(tdata1.mcontrol.execute) begin
            get_trig_probe_act[i] = inst_act && inst[i].avail;
        end else if(tdata1.mcontrol.store) begin
            get_trig_probe_act[i] = inst_act && inst[i].avail && inst[i].is_st;
        end else if(tdata1.mcontrol.load) begin
            get_trig_probe_act[i] = inst_act && inst[i].avail && inst[i].is_ld;
        end
    end
    return get_trig_probe_act;
endfunction

function automatic logic get_trig_timing (csr_trig_tdata1_t tdata1);
    // generate the trigger timing
    get_trig_timing = 1'b0;
    case(tdata1.common.typ)
        // match trigger decode
        TRIG_TYPE_MCONTROL: get_trig_timing = tdata1.mcontrol.timing;
        // icount trigger decode
        TRIG_TYPE_ICOUNT: get_trig_timing = 1'b0;
        // interrupt trigger decode
        TRIG_TYPE_ITRIGGER: get_trig_timing = 1'b1;
        // exception trigger decode
        TRIG_TYPE_ETRIGGER: get_trig_timing = 1'b0;
    endcase
    return get_trig_timing;
endfunction

//`endif
