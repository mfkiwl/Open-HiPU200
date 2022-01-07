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
// FILE NAME  : hpu_cache.svh
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

//`ifndef HPU_CACHE_SVH
`define HPU_CACHE_SVH

// instruction cache
typedef struct packed {
    logic                                       avail;
    logic [INST_WTH-1 : 0]                      instruction;
} icache_t;
typedef struct packed {
    logic                                       npc_is_enable;
    logic [PC_WTH-1 : 0]                        npc;
} icache_req_t;
typedef struct packed {
    logic                                       hit_is_active;
    logic                                       hit;
    logic [INST_FETCH_PARAL-1 : 0]              inst_is_active;
    icache_t [INST_FETCH_PARAL-1 : 0]           inst;
} icache_rsp_t;


// data cache
typedef struct packed {
    logic                                       wr_is_enable;
    logic                                       rd_is_enable;
    logic [PC_WTH-1 : 0]                        addr;
    logic [DATA_WTH-1 : 0]                      wdata;
} dcache_req_t;
typedef struct packed {
    logic                                       hit_is_active;
    logic                                       hit;
    logic                                       rdata_is_active;
    logic [DATA_WTH-1 : 0]                      rdata;
} dcache_rsp_t;

// // local memory
// typedef struct packed {
//     logic                                       wr_is_enable;
//     logic                                       rd_is_enable;
//     logic [PC_WTH-1 : 0]                        addr;
//     logic [DATA_WTH-1 : 0]                      wdata;
// } lcmem_scl_req_t;
// typedef struct packed {
//     logic                                       is_active;
//     logic [DATA_WTH-1 : 0]                      rdata;
// } lcmem_scl_rsp_t;
// 
// typedef struct packed {
//     logic                                       wr_is_enable;
//     logic                                       rd_is_enable;
//     logic [MRA_IND_WTH-1 : 0]                   mra_index;
//     logic [MRA_ADDR_WTH-1 : 0]                  mra_addr;
//     logic [VEC_DATA_WTH-1 : 0]                  wdata;
// } lcmem_vec_req_t;
// typedef struct packed {
//     logic                                       is_active;
//     logic [VEC_DATA_WTH-1 : 0]                  rdata;
// } lcmem_vec_rsp_t;
// 
// 
// typedef struct packed {
//     logic                                       rd_is_enable;
//     logic [MRA_IND_WTH-1 : 0]                   mra_index;
//     logic [MRA_ADDR_WTH-1 : 0]                  mra_addr;
// } lcmem_mra_req_t;
// typedef struct packed {
//     logic                                       is_active;
//     logic [MRA_DATA_WTH-1 : 0]                  rdata;
// } lcmem_mra_rsp_t;
// 
// typedef enum [0 : 0] {
//     MTX_MTX_MODE = 1'b0,
//     VEC_MTX_MODE = 1'b1
// } mrb_ld_mode_e;
// 
// typedef struct packed {
//     logic                                       rd_is_enable;
//     logic [MRB_IND_WTH-1 : 0]                   mrb_index;
//     logic [MRB_ADDR_WTH-1 : 0]                  mrb_addr;
//     mrb_ld_mode_e                               mrb_mode;
// } lcmem_mrb_req_t;
// typedef struct packed {
//     logic                                       is_active;
//     logic [MRB_DATA_WTH-1 : 0]                  mm_rdata;
//     logic [MRB_VM_DATA_WTH-1 : 0]               vm_rdata;
// } lcmem_mrb_rsp_t;

//`endif
