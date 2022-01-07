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
// FILE NAME  : hpu.svh
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

//`ifndef HPU_SVH
`define HPU_SVH

// -----
// Set reset level of HPU
// `define SET_NEG_RST

`ifdef SET_NEG_RST
    `define RST_DECL(sig) negedge sig
    `define RST_TRUE(sig) !(sig)
    parameter RST_LVL = 1'b0;
`else
    `define RST_DECL(sig) posedge sig
    `define RST_TRUE(sig) (sig)
    parameter RST_LVL = 1'b1;
`endif

// -----
// global definitions
parameter int PC_WTH = 32;
parameter int INST_WTH = 32;
parameter int DATA_WTH = 32;
parameter int MTX_WTH = 8;
parameter int VEC_LUT_WTH = 9;

typedef logic[INST_WTH-1 : 0] inst_t;
typedef logic[PC_WTH-1 : 0] pc_t;
typedef logic[DATA_WTH-1 : 0] data_t;
typedef logic[DATA_WTH/8-1 : 0] data_strobe_t;
typedef logic[MTX_WTH-1 : 0] mtx_t;

typedef enum logic[1 : 0] {
    U_MODE = 2'h0,
    S_MODE = 2'h1,
    H_MODE = 2'h2,
    M_MODE = 2'h3
} pri_e;

typedef enum logic[1 : 0] {
    PRC_STEP = 2'h0,
    PRC_SINGLE = 2'h1,
    PRC_MULTI = 2'h2
} hpu_mode_e;

// RISC-V conventional definition
parameter SR_ZERO = 5'd0;
parameter SR_RA = 5'd1;
parameter SR_SP = 5'd2;
parameter SR_GP = 5'd3;
parameter SR_TP = 5'd4;
parameter SR_T0 = 5'd5;
parameter SR_T1 = 5'd6;
parameter SR_T2 = 5'd7;
parameter SR_S0FP = 5'd8;
parameter SR_S1 = 5'd9;
parameter SR_A0 = 5'd10;
parameter SR_A1 = 5'd11;
parameter SR_A2 = 5'd12;
parameter SR_A3 = 5'd13;
parameter SR_A4 = 5'd14;
parameter SR_A5 = 5'd15;
parameter SR_A6 = 5'd16;
parameter SR_A7 = 5'd17;
parameter SR_S2 = 5'd18;
parameter SR_S3 = 5'd19;
parameter SR_S4 = 5'd20;
parameter SR_S5 = 5'd21;
parameter SR_S6 = 5'd22;
parameter SR_S7 = 5'd23;
parameter SR_S8 = 5'd24;
parameter SR_S9 = 5'd25;
parameter SR_S10 = 5'd26;
parameter SR_S11 = 5'd27;
parameter SR_T3 = 5'd28;
parameter SR_T4 = 5'd29;
parameter SR_T5 = 5'd30;
parameter SR_T6 = 5'd31;

function automatic logic [4 : 0] get_rs1(logic [INST_WTH-1 : 0] instruction_i);
    return { instruction_i[19 : 15] };
endfunction

function automatic logic [4 : 0] get_rs2(logic [INST_WTH-1 : 0] instruction_i);
    return { instruction_i[24 : 20] };
endfunction

function automatic logic [4 : 0] get_rs3(logic [INST_WTH-1 : 0] instruction_i);
    return { instruction_i[29 : 25] };
endfunction

function automatic logic [4 : 0] get_rd(logic [INST_WTH-1 : 0] instruction_i);
    return { instruction_i[11 : 7] };
endfunction

function automatic logic [DATA_WTH-1 : 0] i_imm (logic [INST_WTH-1 : 0] instruction_i);
    return { {(DATA_WTH-12) {instruction_i[31]}}, instruction_i[31:20] };
endfunction

function automatic logic [DATA_WTH-1 : 0] s_imm (logic [INST_WTH-1 : 0] instruction_i);
    return { {(DATA_WTH-12) {instruction_i[31]}}, instruction_i[31:25], instruction_i[11:7]};
endfunction

function automatic logic [DATA_WTH-1 : 0] b_imm (logic [INST_WTH-1 : 0] instruction_i);
    return { {(DATA_WTH-12) {instruction_i[31]}}, instruction_i[7], instruction_i[30:25], instruction_i[11:8], 1'b0 };
endfunction

function automatic logic [DATA_WTH-1 : 0] u_imm (logic [INST_WTH-1 : 0] instruction_i);
    return { {(DATA_WTH-31) {instruction_i[31]}}, instruction_i[30:12], 12'h0 };
endfunction

function automatic logic [DATA_WTH-1 : 0] j_imm (logic [INST_WTH-1 : 0] instruction_i);
    return { {(DATA_WTH-20) {instruction_i[31]}}, instruction_i[19:12], instruction_i[20], instruction_i[30:21], 1'b0 };
endfunction

function automatic logic [DATA_WTH-1 : 0] csr_imm (logic [INST_WTH-1 : 0] instruction_i);
    // return { {(DATA_WTH-4) {instruction_i[19]}}, instruction_i[18:15]};
    return { {(DATA_WTH-5) {1'b0}}, instruction_i[19:15]};
endfunction

function automatic logic [DATA_WTH-1 : 0] vl_imm (logic [INST_WTH-1 : 0] instruction_i);
    return { {(DATA_WTH-9) {instruction_i[31]}}, instruction_i[30], instruction_i[27:24], instruction_i[23:20] };
endfunction

function automatic logic [DATA_WTH-1 : 0] vs_imm (logic [INST_WTH-1 : 0] instruction_i);
    return { {(DATA_WTH-9) {instruction_i[31]}}, instruction_i[30], instruction_i[27:24], instruction_i[10:7] };
endfunction

function automatic logic [DATA_WTH-1 : 0] vsh_imm (logic [INST_WTH-1 : 0] instruction_i);
    return { {(DATA_WTH-5) {instruction_i[24]}}, instruction_i[24:20] };
endfunction : vsh_imm

// -----
// HPU Memory map
parameter MEM_DEBUG_ADDR_S = 32'h0000_0100;
parameter MEM_DEBUG_ADDR_E = 32'h0000_0fff;

parameter MEM_CLINT_ADDR_S = 32'h0200_0000;
parameter MEM_CLINT_ADDR_E = 32'h0200_ffff;

parameter MEM_DTCM_ADDR_S = 32'h0201_0000;
parameter MEM_DTCM_ADDR_E = 32'h0201_3fff;

parameter AMO_ADDR_S = 32'h0201_0000;       // atomic memory start
parameter AMO_ADDR_E = 32'h0201_003f;       // atomic memory end
parameter NMAP_ADDR = 32'h0201_2000;        // node map address
parameter MMAP_ADDR = 32'h0201_2020;        // memory map address
parameter SSIG_ADDR = 32'h0201_2040;        // system signal address
parameter APC_ADDR = 32'h0201_2060;         // arch PC address
parameter SFMD_ADDR = 32'h0201_2080;        // safe mode

parameter MEM_LCMEM_ADDR_S = 32'h0210_0000;
parameter MEM_LCMEM_ADDR_E = 32'h0217_ffff;

parameter MEM_CACHE_ADDR_S = 32'h8000_0000;
parameter MEM_CACHE_ADDR_E = 32'hffff_ffff;

// -----
// HPU_CTRL
typedef enum logic [2 : 0] {
    CMD_NORMAL, CMD_SYSC, CMD_EXCP, CMD_TRIG, CMD_MISPRED
} ctrl_cmd_e;

typedef enum logic [2 : 0] {
    RSPD_HALT, RSPD_CMD, RSPD_RESUME, RSPD_EXCP
} rspd_e;

// -----
// NoC DMA
parameter NDMA_LC_ADDR_WTH = 32;
parameter NDMA_LC_DATA_WTH = 256;
parameter NDMA_LC_STRB_WTH = NDMA_LC_DATA_WTH/32;

parameter NDMA_ADDR_WTH = 32;
parameter NDMA_NDX_WTH = 2;
parameter NDMA_NDY_WTH = 2;
//parameter NDMA_TRANS_BIT = 19;
parameter NDMA_TRANS_BIT = 33;

typedef struct packed {
    logic                                   cls;        // cls: 1'b1, L2C; 1'b0, CSR
    logic[2:0]                              index;      // index of CSR command
    logic[1:0]                              cmd;        // command
    logic[3:0]                              hpu_id;     // hpu_id
} ndma_id_t;

typedef struct packed {
    logic[1:0]                              cmd;        // command: write=2'h0; read=2'h1; swap=2'h2
    logic[NDMA_LC_ADDR_WTH-1 : 0]           lcaddr;     // byte aligned
    logic[NDMA_ADDR_WTH-1 : 0]              rtaddr;     // byte aligned
    logic[NDMA_TRANS_BIT-1 : 0]             size;       // in bytes
    logic[NDMA_NDX_WTH-1 : 0]               destx;      // 2bit for 4x4
    logic[NDMA_NDY_WTH-1 : 0]               desty;      // 2bit for 4x4
} ndma_cmd_t;

typedef struct packed {
    logic                                   rd_en;      // read address is valid
    logic[NDMA_LC_ADDR_WTH-1 : 0]           raddr;      // byte aligned
    logic                                   wr_en;      // write address is valid
    logic[NDMA_LC_ADDR_WTH-1 : 0]           waddr;      // byte aligned
    logic[NDMA_LC_DATA_WTH-1 : 0]           wdata;      // data, same clock with write address.
    logic[NDMA_LC_DATA_WTH/32-1 : 0]        wstrb;      // each bit indicates 32bit(4Byte) data
} ndma_mem_req_t;

typedef struct packed {
   logic[NDMA_LC_DATA_WTH-1 : 0]            rdata;      // data
   logic                                    rdata_act;  // read data is active. delay 1-N clock from read address.
   logic                                    atom_ready; // it indicates whether it can do atomic operation
} ndma_mem_rsp_t;

//`endif
