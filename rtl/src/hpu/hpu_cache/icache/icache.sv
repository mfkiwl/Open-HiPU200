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
// FILE NAME  : icache.sv
// DEPARTMENT : Architecture
// AUTHOR     : fugelin
// AUTHOR'S EMAIL : fugelin@stu.xjtu.edu.cn
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------
`timescale 1ns / 1ps
 
`include "hpu_head.sv"

import hpu_pkg::*;

module icache #(
    // -----
    // interpretation of different components of address
    parameter ADDR_WT = 32,
    parameter TAG_WT = 20,
    parameter INDEX_WT = 6,
    parameter BLOCK_OFFSET_WT = 2,
    parameter INST_ALIGN_WT = 4,
    // -----
    // interpretation of cache line width
    parameter CACHE_LINE_WT = 512,
    // -----
    // width of the connection between L1I AND F,F means fetch
    parameter L1I_F_DATA_WT = 4*32,     
    // -----
    // width of the connection between L1I AND L2
    parameter L2_L1I_DATA_WT = 32*8,
    // -----
    // definition of CSR width
    parameter CSR_L1I_ADDR_WT = 12,
    parameter CSR_L1I_DATA_WT = 32,
    // -----
    // definition of way number and set number
    parameter WAY_NUM = 2,
    parameter SET_NUM = 64
) (
    // -----
    // clock & reset
    input   logic                                   clk_i, 
    input   logic                                   rst_i,
    // -----
    //the req from if to I$
    input   logic                                   if_ic__npc_en_i,
    input   logic[ADDR_WT-1:0]                      if_ic__npc_i,
    // -----
    //the rsp from I$ to if
    output  logic                                   ic_if__suc_o,
    output  logic[L1I_F_DATA_WT-1:0]                ic_if__inst_o, 
    // -----
    //the req from I$ to L2_Cache
    output  logic                                   l1i_l2__rd_en_o,
    output  logic[ADDR_WT-1:0]                      l1i_l2__addr_o, 
    // -----
    //the rsp from L2_Cache to I$
    input   logic                                   l2_l1i__suc_i, 
    input   logic                                   l2_l1i__suc_act_i,
    input   logic[L2_L1I_DATA_WT-1:0]               l2_l1i__rdata_i,
    input   logic                                   l2_l1i__rdata_act_i,  
    // -----
    // connection between csr and ic
    input   csr_bus_req_t                           csr_ic__bus_req,
    output  csr_bus_rsp_t                           ic_csr__bus_rsp,
    output  logic                                   ic_csr__csr_finish_o,           
    // -----
    // achieve fully flush icache    
    input   logic                                   ctrl_ic__flush_req_i
);
//======================================================================================================================
// Parameter
//======================================================================================================================
    enum logic[3 : 0] {
        IDLE = 4'h0,
        SWAP_LINE,
        R_L2_SWAP_WAIT,
        W_S_BUF00,
        W_S_BUF01,
        R_L2_CACH,
        R_L2_CACH_SUC_OR_NOT,
        W_I_CACHE0,
        W_I_CACHE1,
        R_L2_BUF,
        R_L2_BUF_SUC_OR_NOT,
        W_S_BUF10,
        W_S_BUF11
    } CURRENT_STATE,NEXT_STATE;
//======================================================================================================================
// Wire & Reg declaration
//======================================================================================================================
    logic                                   npc_lt2g_en;
    logic                                   pc_en_i_d1;             //*****define of pc_delay
    logic[TAG_WT-1:0]                       inst_addr_tag;          //*****define of instruction
    logic[INDEX_WT-1:0]                     inst_addr_index;
    logic[ADDR_WT-1:0]                      inst_addr_i_d1;
    logic[BLOCK_OFFSET_WT-1:0]              inst_addr_offset_d1;
    logic[TAG_WT-1:0]                       inst_addr_tag_d1;
    logic[INDEX_WT-1:0]                     inst_addr_index_d1;
    logic[INDEX_WT-1:0]                     inst_addr_index_save;
    logic[TAG_WT-1:0]                       inst_addr_tag_save;     // use save because hit use combinational logic, so
                                                                    // the addr may change in the cycle ,to make the
                                                                    // assign change
    logic                                   cache_hit_way0;         //*****define of hit
    logic                                   cache_hit_way1;
    logic                                   prefetch_hit;
    logic[WAY_NUM-1:0]                      valid_array [SET_NUM-1:0];  //*****define of valid array
    integer                                 i;                      //***** define of iterative variable
    integer                                 j;                      //***** define of iterative variable
    logic                                   age_array [SET_NUM-1:0];//*****define of age array
    logic                                   age_array_save;
    logic[CSR_L1I_DATA_WT-1:0]              csr_reg_01;             //*****define of csr variable
    logic[CSR_L1I_DATA_WT-1:0]              csr_reg_02;               
    logic[TAG_WT-1:0]                       stream_buffer_tag;      //*****define of stream buffer
    logic[INDEX_WT-1:0]                     stream_buffer_index; 
    logic[CACHE_LINE_WT-1:0]                stream_buffer_data;  
    logic                                   stream_buffer_valid;
    logic[L2_L1I_DATA_WT-1:0]               stream_buffer_data_temp;
    logic[L2_L1I_DATA_WT-1:0]               cache_data_temp;
    logic                                   we_tag_way0;            //*****define of ram interface
    logic                                   we_tag_way1;
    logic                                   we_data_way0;
    logic                                   we_data_way1;
    logic[INDEX_WT-1:0]                     addra_tag_way0;
    logic[INDEX_WT-1:0]                     addra_tag_way1;
    logic[INDEX_WT-1:0]                     addra_data_way0;
    logic[INDEX_WT-1:0]                     addra_data_way1;
    logic[TAG_WT-1:0]                       din_tag_way0;           // for ram, it only sample the value on the clock
                                                                    // age, so don't waoory about the change of addr
                                                                    // during the cycle
    logic[TAG_WT-1:0]                       din_tag_way1;
    logic[CACHE_LINE_WT-1:0]                din_data_way0;
    logic[CACHE_LINE_WT-1:0]                din_data_way1;
    logic[TAG_WT-1:0]                       dout_tag_way0;
    logic[TAG_WT-1:0]                       dout_tag_way1;
    logic[CACHE_LINE_WT-1:0]                dout_data_way0;
    logic[CACHE_LINE_WT-1:0]                dout_data_way1;
    logic[ADDR_WT-1:0]                      inst_addr_now;
    logic[TAG_WT-1:0]                       inst_addr_now_tag;
    logic[INDEX_WT-1:0]                     inst_addr_now_index;
    logic[ADDR_WT-1:0]                      inst_addr_next;
    logic[TAG_WT-1:0]                       inst_addr_next_tag;
    logic[INDEX_WT-1:0]                     inst_addr_next_index;

//======================================================================================================================
// Instance
//======================================================================================================================

    // If the access address is below 2GiB, force the access data as all 0.
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            npc_lt2g_en <= 1'b0;
        end else begin
            npc_lt2g_en <= if_ic__npc_en_i && !if_ic__npc_i[ADDR_WT-1];
        end
    end

    assign inst_addr_tag   = if_ic__npc_i[ADDR_WT-1:ADDR_WT-TAG_WT];
    assign inst_addr_index = if_ic__npc_i[ADDR_WT-TAG_WT-1:ADDR_WT-TAG_WT-INDEX_WT];
    assign inst_addr_index_d1 = inst_addr_i_d1[ADDR_WT-TAG_WT-1:ADDR_WT-TAG_WT-INDEX_WT];
    assign inst_addr_offset_d1= inst_addr_i_d1[ADDR_WT-TAG_WT-INDEX_WT-1:ADDR_WT-TAG_WT-INDEX_WT-BLOCK_OFFSET_WT];

    // design of  csr
	// csr bus write csr_reg_02
    always_ff@(posedge clk_i or `RST_DECL(rst_i)) begin 
        if(`RST_TRUE(rst_i)) begin
            csr_reg_02 <= {(CSR_L1I_DATA_WT){1'b0}};
        end else begin
            if ((csr_ic__bus_req.wr_en) && (csr_ic__bus_req.waddr=='h7D2)) begin
                csr_reg_02 <= csr_ic__bus_req.wdata;
            end
        end    
    end
    assign ic_csr__csr_finish_o = csr_reg_01[0];
    
    // csr bus read 
    always_ff@(posedge clk_i or `RST_DECL(rst_i)) begin 
        if(`RST_TRUE(rst_i)) begin
            ic_csr__bus_rsp.rdata <= {(CSR_L1I_DATA_WT){1'b0}};
        end else begin
            if ((csr_ic__bus_req.rd_en) && (csr_ic__bus_req.raddr=='h7D1)) begin
                ic_csr__bus_rsp.rdata <= csr_reg_01;
            end else begin 
                ic_csr__bus_rsp.rdata <= {(CSR_L1I_DATA_WT){1'b0}};
            end
        end
    end
    
  //  assign ic_csr__bus_rsp.rdata = ((csr_ic__bus_req.rd_en) && (csr_ic__bus_req.raddr=='h7D1)) ? csr_reg_01 : 32'h0;

    // here set the initial value of inst_addr_tag_save to be 1, not 0. Because, during the rst_i is active, the addr of
    // stream buffer is 0.so when rst_i is down, prefetch hit will be 1
	// for reg the ipc when enable if_ic__npc_en_i is enable reg the addr and the access address is >= 2GiB
    always_ff@(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            inst_addr_tag_save    <= TAG_WT'(1);
            inst_addr_index_save  <= INDEX_WT'(1);
        end else begin
            if(if_ic__npc_en_i && (if_ic__npc_i[ADDR_WT-1])) begin
                inst_addr_tag_save    <= if_ic__npc_i[ADDR_WT-1:ADDR_WT-TAG_WT];
                inst_addr_index_save  <= if_ic__npc_i[ADDR_WT-TAG_WT-1:ADDR_WT-TAG_WT-INDEX_WT];
            end
        end
    end
    
    // here write like this,because for this requset,we eed to save the PC to be same, not changed because of pipnling
    // give new PCgen the way0 way1 or prefetch_hit hit signal
    always_comb begin
        cache_hit_way0 = 1'b0;
        cache_hit_way1 = 1'b0;
        prefetch_hit   = 1'b0;
        if((dout_tag_way0 == inst_addr_tag_save )&&(valid_array[inst_addr_index_save][0] == 1'b1)) begin
            cache_hit_way0 = 1'b1;
        end else if((dout_tag_way1 == inst_addr_tag_save )&&(valid_array[inst_addr_index_save][1] == 1'b1)) begin
            cache_hit_way1 = 1'b1;
        end else if((stream_buffer_tag == inst_addr_tag_save) && (stream_buffer_index == inst_addr_index_save)
            &&(stream_buffer_valid == 1'b1)) begin
            prefetch_hit   = 1'b1;
        end
    end
        
    assign ic_if__suc_o = ((cache_hit_way0|cache_hit_way1|prefetch_hit)&pc_en_i_d1) || npc_lt2g_en;

    // update the age_array on the up edge of the second beat, it updates the value because of the value of hit,
    // age_array=0 means kick out the data of way 0
    always_ff@(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(j=0;j<SET_NUM;j=j+1) begin
                age_array[j] <= 1'b0;
            end 
        end else begin
            if((pc_en_i_d1)&&(~cache_hit_way0)&&(cache_hit_way1)) begin
                age_array[inst_addr_index_d1] <= 1'b0;
            end else if((pc_en_i_d1)&&(cache_hit_way0)&&(~cache_hit_way1)) begin
                age_array[inst_addr_index_d1] <= 1'b1;
            end
        end
    end

    // give the cpu data 
    always_ff@(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ic_if__inst_o <= { L1I_F_DATA_WT{ 1'b0 }};
        end else begin
            if(npc_lt2g_en) begin
                ic_if__inst_o <= { L1I_F_DATA_WT{ 1'b0 }};
            end else if((pc_en_i_d1) && (cache_hit_way0) && (~cache_hit_way1) && (~prefetch_hit)) begin
                case(inst_addr_offset_d1)
                    BLOCK_OFFSET_WT'(0):ic_if__inst_o <= dout_data_way0[127:0];    //  (0+1)*128-1:2*128
                    BLOCK_OFFSET_WT'(1):ic_if__inst_o <= dout_data_way0[255:128];  //  (1+1)*128-1:2*128
                    BLOCK_OFFSET_WT'(2):ic_if__inst_o <= dout_data_way0[383:256];  //  (2+1)*128-1:2*128
                    BLOCK_OFFSET_WT'(3):ic_if__inst_o <= dout_data_way0[511:384];  //  (3+1)*128-1:3*128
                endcase
            end else if((pc_en_i_d1) && (~cache_hit_way0) && (cache_hit_way1) && (~prefetch_hit)) begin
                case(inst_addr_offset_d1)
                    BLOCK_OFFSET_WT'(0):ic_if__inst_o <= dout_data_way1[127:0];
                    BLOCK_OFFSET_WT'(1):ic_if__inst_o <= dout_data_way1[255:128];
                    BLOCK_OFFSET_WT'(2):ic_if__inst_o <= dout_data_way1[383:256];
                    BLOCK_OFFSET_WT'(3):ic_if__inst_o <= dout_data_way1[511:384];
                endcase
            end else if((pc_en_i_d1) && (~cache_hit_way0) && (~cache_hit_way1) && (prefetch_hit)) begin
                case(inst_addr_offset_d1)
                    BLOCK_OFFSET_WT'(0):ic_if__inst_o <= stream_buffer_data[127:0];
                    BLOCK_OFFSET_WT'(1):ic_if__inst_o <= stream_buffer_data[255:128];
                    BLOCK_OFFSET_WT'(2):ic_if__inst_o <= stream_buffer_data[383:256];
                    BLOCK_OFFSET_WT'(3):ic_if__inst_o <= stream_buffer_data[511:384];
                endcase
            end
        end
    end

    //===========================================================================================//
    //main fsm for update line from l2 to l1i
    //===========================================================================================//
    //change the state of FSM when clk_edge arrives
    always_ff@(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin 
            CURRENT_STATE <= IDLE;
        end else begin
            CURRENT_STATE <= NEXT_STATE;
        end
    end

    always_comb begin
        NEXT_STATE = CURRENT_STATE;
        case(CURRENT_STATE)
            IDLE: begin
                if((~cache_hit_way0)&&(~cache_hit_way1)&&(prefetch_hit)&&(pc_en_i_d1)) begin
                    NEXT_STATE = SWAP_LINE;
                end else if((~cache_hit_way0)&&(~cache_hit_way1)&&(~prefetch_hit)&&(pc_en_i_d1)) begin
                    NEXT_STATE = R_L2_CACH;
                end
            end
            SWAP_LINE: begin
                if(l2_l1i__suc_act_i == 1'b1 && l2_l1i__suc_i == 1'b1) begin
                    NEXT_STATE = W_S_BUF00;
                end
            end
            W_S_BUF00: begin
                NEXT_STATE = W_S_BUF01;
            end
            W_S_BUF01: begin
                NEXT_STATE = IDLE;
            end
            R_L2_CACH: begin
                if(l2_l1i__suc_act_i==1'b1 && l2_l1i__suc_i==1'b1) begin
                    NEXT_STATE = W_I_CACHE0;
                end
            end
            W_I_CACHE0: begin
                NEXT_STATE = W_I_CACHE1;
            end
            W_I_CACHE1: begin
                NEXT_STATE = R_L2_BUF;
            end
            R_L2_BUF: begin
                NEXT_STATE = R_L2_BUF_SUC_OR_NOT;
            end
            R_L2_BUF_SUC_OR_NOT: begin
                if(l2_l1i__suc_act_i==1'b1 && l2_l1i__suc_i==1'b1) begin
                    NEXT_STATE = W_S_BUF10;
                end else begin
                    NEXT_STATE = R_L2_BUF;
                end
            end
            W_S_BUF10: begin
                NEXT_STATE = W_S_BUF11;
            end
            W_S_BUF11: begin
                NEXT_STATE = IDLE;
            end
        endcase
    end

    //===========================================================================================//
    //main fsm for update line from l2 to l1i end
    //===========================================================================================//
    // save the addr that we will use when it is IDLE state
    always_ff@(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            inst_addr_now  <= { ADDR_WT { 1'b0 }};
            inst_addr_now_tag  <= { TAG_WT { 1'b0 }};
            inst_addr_now_index  <= { INDEX_WT { 1'b0 }};
            inst_addr_next <= { ADDR_WT { 1'b0 }};
            inst_addr_next_tag <= { TAG_WT { 1'b0 }};
            inst_addr_next_index <= { INDEX_WT { 1'b0 }};
            age_array_save <= 1'b0;
        end else begin
            case(NEXT_STATE)
                IDLE: begin
                    inst_addr_now  <= {if_ic__npc_i[ADDR_WT-1 : BLOCK_OFFSET_WT+INST_ALIGN_WT],
                        {(BLOCK_OFFSET_WT+INST_ALIGN_WT){1'b0}}};
                    inst_addr_now_tag <= if_ic__npc_i[ADDR_WT-1 -: TAG_WT];
                    inst_addr_now_index <= if_ic__npc_i[ADDR_WT-TAG_WT-1 -: INDEX_WT];
                    inst_addr_next <= {if_ic__npc_i[ADDR_WT-1 : BLOCK_OFFSET_WT+INST_ALIGN_WT] + 1'b1,
                        {(BLOCK_OFFSET_WT+INST_ALIGN_WT){1'b0}}};
                    age_array_save <=age_array[if_ic__npc_i[ADDR_WT-TAG_WT-1:ADDR_WT-TAG_WT-INDEX_WT]];
                end
                SWAP_LINE: begin
                    inst_addr_next_tag <= inst_addr_next[ADDR_WT-1:ADDR_WT-TAG_WT];
                    inst_addr_next_index <= inst_addr_next[ADDR_WT-TAG_WT-1:ADDR_WT-TAG_WT-INDEX_WT];
                end
                R_L2_CACH: begin
                    inst_addr_next_tag <= inst_addr_next[ADDR_WT-1:ADDR_WT-TAG_WT];
                    inst_addr_next_index <= inst_addr_next[ADDR_WT-TAG_WT-1:ADDR_WT-TAG_WT-INDEX_WT];
                end
            endcase
        end
    end


    //design of stream buffer in FSM
    //use main fsm update stream buffer
    always_ff@(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            stream_buffer_data  <= { CACHE_LINE_WT {1'b0}};
            stream_buffer_valid <= 1'b0;
            stream_buffer_tag   <= { TAG_WT { 1'b0 }};
            stream_buffer_index <= { INDEX_WT { 1'b0 }};
            stream_buffer_data_temp <= 0;
        end else begin
            if(((csr_ic__bus_req.wr_en) && (csr_ic__bus_req.waddr=='h7D0) && (csr_ic__bus_req.wdata==1)
                &&(csr_reg_02==1))|| (ctrl_ic__flush_req_i == 1)) begin
                stream_buffer_valid <= 1'b0;
            end else begin
                case(CURRENT_STATE)
                    W_S_BUF00: begin
                        stream_buffer_data_temp <= l2_l1i__rdata_i;
                        // stream_buffer_tag <= inst_addr_next[ADDR_WT-1:ADDR_WT-TAG_WT];
                        // stream_buffer_index <= inst_addr_next[ADDR_WT-TAG_WT-1:ADDR_WT-TAG_WT-INDEX_WT];
                        // stream_buffer_valid <= 1'b1;
                    end
                    W_S_BUF01: begin
                        stream_buffer_tag <= inst_addr_next[ADDR_WT-1:ADDR_WT-TAG_WT];
                        stream_buffer_index <= inst_addr_next[ADDR_WT-TAG_WT-1:ADDR_WT-TAG_WT-INDEX_WT];
                        stream_buffer_data[511:256] <= l2_l1i__rdata_i;
                        stream_buffer_data[255:0] <= stream_buffer_data_temp;
                        stream_buffer_valid <= 1'b1;
                    end
                    W_S_BUF10: begin
                        stream_buffer_data_temp <= l2_l1i__rdata_i;
                        // stream_buffer_tag <= inst_addr_next[ADDR_WT-1:ADDR_WT-TAG_WT];
                        // stream_buffer_index <= inst_addr_next[ADDR_WT-TAG_WT-1:ADDR_WT-TAG_WT-INDEX_WT];
                        // stream_buffer_valid <= 1'b1;
                    end
                    W_S_BUF11: begin
                        stream_buffer_tag <= inst_addr_next[ADDR_WT-1:ADDR_WT-TAG_WT];
                        stream_buffer_index <= inst_addr_next[ADDR_WT-TAG_WT-1:ADDR_WT-TAG_WT-INDEX_WT];
                        stream_buffer_data[511:256] <= l2_l1i__rdata_i;
                        stream_buffer_data[255:0] <= stream_buffer_data_temp;
                        stream_buffer_valid <= 1'b1;
                    end
                endcase
            end
        end
    end

    //design of valid array of FSM
    //update cache valid bit use csr or main fsm
    always_ff@(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(i=0;i<SET_NUM;i=i+1) begin
                valid_array[i][WAY_NUM-1:0] <= 2'b00;
            end
            csr_reg_01 <= 0;
        end else begin
            if(((csr_ic__bus_req.wr_en) && (csr_ic__bus_req.waddr=='h7D0) && (csr_ic__bus_req.wdata==1)
                && (csr_reg_02==1)) || (ctrl_ic__flush_req_i==1)) begin
                for(i=0;i<SET_NUM;i=i+1) begin
                    valid_array[i][WAY_NUM-1:0] <= 2'b00;
                end
                csr_reg_01 <= 1;
            end else if ((csr_ic__bus_req.wr_en)&& (csr_ic__bus_req.waddr=='h7D1)) begin
                csr_reg_01 <= csr_ic__bus_req.wdata;
            end else if(NEXT_STATE == W_I_CACHE1) begin
                if(age_array_save) begin
                    valid_array[inst_addr_now_index][1] <= 1;
                end else if(~age_array_save) begin
                    valid_array[inst_addr_now_index][0] <= 1;
                end
            end else if(NEXT_STATE == SWAP_LINE) begin
                if(age_array_save) begin
                    valid_array[stream_buffer_index][1] <= 1;
                end else if(~age_array_save) begin
                    valid_array[stream_buffer_index][0] <= 1;
                end
            end
        end
    end

    //design of interface with L2 cahce in FSM
    //gen to l2 signal
    always_comb begin
        l1i_l2__rd_en_o  = 1'b0;
        l1i_l2__addr_o   = {ADDR_WT{1'b0}};
        case(CURRENT_STATE)
            IDLE: begin
                if((pc_en_i_d1) && (~cache_hit_way0) && (~cache_hit_way1) && (prefetch_hit)) begin
                    l1i_l2__rd_en_o  = 1'b1;
                    l1i_l2__addr_o   = {inst_addr_i_d1[ADDR_WT-1 : BLOCK_OFFSET_WT+INST_ALIGN_WT] + 1'b1,
                        {(BLOCK_OFFSET_WT+INST_ALIGN_WT){1'b0}}};
                end else if((pc_en_i_d1) && (~cache_hit_way0) && (~cache_hit_way1) && (~prefetch_hit)) begin
                    l1i_l2__rd_en_o  = 1'b1;
                    l1i_l2__addr_o   = {inst_addr_i_d1[ADDR_WT-1 : BLOCK_OFFSET_WT+INST_ALIGN_WT],
                        {(BLOCK_OFFSET_WT+INST_ALIGN_WT){1'b0}}};
                end else begin
                    l1i_l2__rd_en_o  = 1'b0;
                    l1i_l2__addr_o   = 0;
                end
            end
            SWAP_LINE: begin
                if((l2_l1i__suc_act_i == 1'b1) && (l2_l1i__suc_i == 1'b1)) begin
       			    l1i_l2__rd_en_o  = 1'b0;
                    l1i_l2__addr_o   = 0;
        	    end else begin
                    l1i_l2__rd_en_o  = 1'b1;
                    l1i_l2__addr_o   = inst_addr_next;
       	        end
        	end
            R_L2_CACH: begin
                if((l2_l1i__suc_act_i == 1'b1) && (l2_l1i__suc_i == 1'b1)) begin
                    l1i_l2__rd_en_o  = 1'b0;
                    l1i_l2__addr_o   = 0;
                end else begin
                    l1i_l2__rd_en_o  = 1'b1;
                    l1i_l2__addr_o   = inst_addr_now;
                end
            end
            R_L2_BUF: begin
                l1i_l2__rd_en_o  = 1'b1;
                l1i_l2__addr_o   = inst_addr_next;
            end
        endcase
    end         

    //*****design of data ram in FSM
    //dataram tagram we addr data
    always_comb begin
        addra_tag_way0 = inst_addr_now_index;
        din_tag_way0 = inst_addr_now_tag;
        addra_tag_way1 = inst_addr_now_index;       
        din_tag_way1 = inst_addr_now_tag;       
        addra_data_way0  = inst_addr_now_index;
        din_data_way0 = {l2_l1i__rdata_i, cache_data_temp};
        addra_data_way1  = inst_addr_now_index;
        din_data_way1 = {l2_l1i__rdata_i, cache_data_temp};
        case(CURRENT_STATE)
            SWAP_LINE: begin // when stream buffer is hit  cp the data from stream buffer to cache
                if (age_array_save) begin
                    addra_tag_way1   = stream_buffer_index;
                    din_tag_way1     = stream_buffer_tag;
                    addra_data_way1  = stream_buffer_index;
                    din_data_way1    = stream_buffer_data;              
                end else begin
                    addra_tag_way0   = stream_buffer_index;
                    din_tag_way0     = stream_buffer_tag;
                    addra_data_way0  = stream_buffer_index;
                    din_data_way0    = stream_buffer_data;
                end
            end
        endcase
    end
    //design of tagram/dataram we in FSM
    //dataram tagram we addr data
    always_comb begin
        we_data_way0  = 1'b0;
        we_data_way1  = 1'b0;
        we_tag_way0   = 1'b0;
        we_tag_way1   = 1'b0;
        case(CURRENT_STATE)
            SWAP_LINE: begin // when stream buffer is hit  cp the data from stream buffer to cache
                if (age_array_save && (stream_buffer_valid == 1'b1)) begin
                    we_data_way1  = 1'b1;
                    we_tag_way1   = 1'b1;           
                end else if (~age_array_save && (stream_buffer_valid == 1'b1)) begin
                    we_data_way0  = 1'b1;
                    we_tag_way0   = 1'b1;
                end
            end
            W_I_CACHE1: begin
                if(age_array_save) begin
                    we_data_way1  = 1'b1;
                    we_tag_way1   = 1'b1;
                end else begin
                    we_data_way0  = 1'b1;
                    we_tag_way0   = 1'b1;
                end
            end
        endcase
    end

//======================================================================================================================
// Instance
//======================================================================================================================
    
    array_d1 #(.DWTH(TAG_WT),.AWTH(INDEX_WT),.DEPTH(SET_NUM)) sram_tag_way0 (
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        .wen_i              (we_tag_way0),
        .waddr_i            (addra_tag_way0),
        .wdata_i            (din_tag_way0),
        .raddr_i            (inst_addr_index),
        .rdata_o            (dout_tag_way0)
    );

    array_d1 #(.DWTH(TAG_WT),.AWTH(INDEX_WT),.DEPTH(SET_NUM)) sram_tag_way1 (
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        .wen_i              (we_tag_way1),
        .waddr_i            (addra_tag_way1),
        .wdata_i            (din_tag_way1),
        .raddr_i            (inst_addr_index),
        .rdata_o            (dout_tag_way1)
    );
	/*instance for dataram*/
    sdp_uhd_w64x64s_r64x64d1_wrap  sram_data_way0[7:0] (
        .clk_i              ({8{clk_i}}),
        .we_i               ({8{we_data_way0}}),
        .waddr_i            ({8{addra_data_way0}}),
        .wdata_i            (din_data_way0),
        .wdata_strob_i      ({8{8'hff}}),
        .re_i               (8'hff),
        .raddr_i            ({8{inst_addr_index}}),
        .rdata_o            (dout_data_way0)
    );
    sdp_uhd_w64x64s_r64x64d1_wrap  sram_data_way1[7:0] (
        .clk_i              ({8{clk_i}}),
        .we_i               ({8{we_data_way1}}),
        .waddr_i            ({8{addra_data_way1}}),
        .wdata_i            (din_data_way1),
        .wdata_strob_i      ({8{8'hff}}),
        .re_i               (8'hff),
        .raddr_i            ({8{inst_addr_index}}),
        .rdata_o            (dout_data_way1)
    );

    //*****define of delay instance
    always_ff@(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            pc_en_i_d1 <= 0;
            inst_addr_i_d1 <= 0;    
            inst_addr_tag_d1 <= 0;
            cache_data_temp <= 0;      
        end else begin
            pc_en_i_d1 <= if_ic__npc_en_i && (if_ic__npc_i[ADDR_WT-1]);
            inst_addr_i_d1 <= if_ic__npc_i;    
            inst_addr_tag_d1 <= inst_addr_tag;
            cache_data_temp <= l2_l1i__rdata_i;                
        end
    end

endmodule : icache
