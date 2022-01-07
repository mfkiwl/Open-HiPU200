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
// FILE NAME  : sync_fifo.sv
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps

module sync_fifo #(
    parameter FIFO_LEN = 16,
    parameter DATA_WTH = 8,
    parameter ADDR_WTH = 4,
    parameter FULL_ASSERT_VALUE = FIFO_LEN,
    parameter FULL_NEGATE_VALUE = FIFO_LEN,
    parameter EMPTY_ASSERT_VALUE = 0,
    parameter EMPTY_NEGATE_VALUE = 0
) (
    // clock & reset
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    // write interface
    input   logic[DATA_WTH-1 : 0]                   wr_data_i,
    input   logic                                   wr_en_i,
    output  logic                                   full_o,
    output  logic                                   a_full_o,
    // read interface
    output  logic[DATA_WTH-1 : 0]                   rd_data_o,
    input   logic                                   rd_en_i,
    output  logic                                   empty_o,
    output  logic                                   a_empty_o
);

//======================================================================================================================
// Wire & Reg declaration
//======================================================================================================================
    logic[DATA_WTH-1 : 0]                   mem[0 : FIFO_LEN-1];
    logic                                   wr_en;
    logic[ADDR_WTH : 0]                     wr_addr;
    logic                                   wr_mark;
    logic                                   rd_en;
    logic[ADDR_WTH : 0]                     rd_addr;
    logic                                   rd_mark;
    logic                                   empty, full;
    logic                                   a_empty, a_full;

//======================================================================================================================
// Instance
//======================================================================================================================
    // write logic
    assign wr_en = wr_en_i & (~full);

    always @(posedge clk_i or `RST_DECL(rst_i))begin
        if(`RST_TRUE(rst_i)) begin
            wr_addr <= {(ADDR_WTH+1){1'b0}};
            wr_mark <= 1'b0;
        end else begin
            if(wr_en) begin
                if(wr_addr == FIFO_LEN - 1'b1) begin
                    wr_addr <= {(ADDR_WTH+1){1'b0}};
                    wr_mark <= ~wr_mark;
                end else begin
                    wr_addr <= wr_addr + 1'b1;
                end
                mem[wr_addr[ADDR_WTH-1:0]] <= wr_data_i;
            end
        end
    end

    // read logic
    assign rd_en = rd_en_i & (~empty);
    always @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            rd_addr <= {(ADDR_WTH+1){1'b0}};
            rd_mark <= 1'b0;
        end else begin
            if(rd_en) begin
                if(rd_addr == FIFO_LEN - 1'b1) begin
                    rd_addr <= {(ADDR_WTH+1){1'b0}};
                    rd_mark <= ~rd_mark;
                end else begin
                    rd_addr <= rd_addr + 1'b1;
                end
            end
        end
    end
    assign rd_data_o = mem[rd_addr[ADDR_WTH-1:0]];

    // full/empty signal logic
    assign empty = (wr_addr == rd_addr) && (wr_mark == rd_mark);
    assign full = (wr_addr == rd_addr) && (wr_mark != rd_mark);

    assign empty_o = empty;
    assign full_o = full;

    // almost full/empty signal logic
    always @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            a_empty <= 1'b1;
            a_full <= 1'b0;
        end else begin
            if(rd_en & (~wr_en)) begin
                if(wr_addr < rd_addr) begin
                    if(wr_addr + FIFO_LEN - rd_addr == EMPTY_ASSERT_VALUE + 1'b1)
                        a_empty <= 1'b1;
                    if(wr_addr + FIFO_LEN - rd_addr == FULL_NEGATE_VALUE)
                        a_full <= 1'b0;
                end else begin
                    if(wr_addr - rd_addr == EMPTY_ASSERT_VALUE + 1'b1)
                        a_empty <= 1'b1;
                    if(wr_addr - rd_addr == FULL_NEGATE_VALUE)
                        a_full <= 1'b0;
                end
            end else if((~rd_en) & wr_en) begin
                if(wr_addr < rd_addr) begin
                    if(wr_addr + FIFO_LEN - rd_addr == EMPTY_NEGATE_VALUE)
                        a_empty <= 1'b0;
                    if(wr_addr + FIFO_LEN - rd_addr == FULL_ASSERT_VALUE - 1'b1)
                        a_full <= 1'b1;
                end else begin
                    if(wr_addr - rd_addr == EMPTY_NEGATE_VALUE)
                        a_empty <= 1'b0;
                    if(wr_addr - rd_addr == FULL_ASSERT_VALUE - 1'b1)
                        a_full <= 1'b1;
                end
            end
        end
    end

    assign a_empty_o = a_empty;
    assign a_full_o = a_full;

//======================================================================================================================
// just for simulation
//======================================================================================================================
// synospsys translate_off

// synospsys translate_on

//======================================================================================================================
// probe signals
//======================================================================================================================

endmodule : sync_fifo
