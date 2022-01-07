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
// FILE NAME  : div_seq.sv
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
module div_seq (clk, rst_n, hold, start, a, b, complete, divide_by_0, quotient, remainder);
    parameter a_width = 32;
    parameter b_width = 32;
    parameter tc_mode = 0;
    parameter num_cyc = 8;
    parameter rst_mode = 0;
    parameter input_mode = 1;
    parameter output_mode = 1;
    parameter early_start = 0;
    // Please add +incdir+$SYNOPSYS/dw/sim_ver+ to your verilog simulator command line (for simulation).

    input clk;
    input rst_n;
    input hold;
    input start;
    input [a_width-1 : 0] a;
    input [b_width-1 : 0] b;
    output complete;
    output divide_by_0;
    output [a_width-1 : 0] quotient;
    output [b_width-1 : 0] remainder;

`ifdef PLATFORM_SIM
    generate
        if(tc_mode) begin
            assign quotient = $signed(a) / $signed(b);
            assign remainder = $signed(a) % $signed(b);
        end else begin
            assign quotient = a/b;
            assign remainder = a % b;
        end
    endgenerate
    assign divide_by_0 = (b==0);
`endif

`ifdef PLATFORM_XILINX
    assign complete = 1'b0;
    assign divide_by_0 = 1'b0;
    assign quotient = 'h0;
    assign remainder = 'h0;
`endif

`ifdef PLATFORM_ASIC
    // Instance of DW_div_seq
    DW_div_seq #(a_width, b_width, tc_mode, num_cyc, rst_mode, input_mode, output_mode, early_start) U1 (
        .clk(clk),   .rst_n(rst_n),   .hold(hold),
        .start(start),   .a(a),   .b(b),
        .complete(complete),   .divide_by_0(divide_by_0),
        .quotient(quotient),   .remainder(remainder)
    );
`endif

endmodule : div_seq

