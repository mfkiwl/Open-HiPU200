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
// FILE NAME  : div_pip.sv
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns/1ps

// `define PLATFORM_ASIC
`include "glb_def.svh"

// add_sub: 1'b0: add, 1'b1: sub.
module div_pip(clk, rst_n, en, a, b, quotient, remainder, divide_by_0);
    parameter a_width = 8;
    parameter b_width = 8;
    parameter tc_mode = 0;
    parameter rem_mode = 1;
    parameter num_stages = 2;
    parameter stall_mode = 1;
    parameter rst_mode = 1;
    parameter op_iso_mode = 0;

    input clk;
    input rst_n;
    input en;
    input [a_width-1 : 0] a;
    input [b_width-1 : 0] b;
    output [a_width-1 : 0] quotient;
    output [b_width-1 : 0] remainder;
    output divide_by_0;

`ifdef PLATFORM_SIM
    generate
        if(tc_mode) begin
            assign quotient = $signed(a)/$signed(b);
            assign remainder = $signed(a) % $signed(b);
        end else begin
            assign quotient = a/b;
            assign remainder = a % b;
        end
    endgenerate
    assign divide_by_0 = (b==0);
`endif

`ifdef PLATFORM_XILINX

`endif

`ifdef PLATFORM_ASIC
    // Instance of DW_div_pip
    DW_div_pipe #(a_width,   b_width,   tc_mode,  rem_mode, num_stages,   stall_mode,   rst_mode,   op_iso_mode) U1 (
        .clk(clk),   .rst_n(rst_n),   .en(en),
        .a(a),   .b(b),   .quotient(quotient),
        .remainder(remainder),   .divide_by_0(divide_by_0)
    );
`endif

endmodule : div_pip
