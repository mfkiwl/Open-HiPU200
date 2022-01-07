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
// FILE NAME  : addsub_stage0.sv
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
module addsub_stage0(in1, in2, ci, add_sub, sum, co);
    parameter DW = 32;

    input [DW-1 : 0] in1;
    input [DW-1 : 0] in2;
    input ci;
    input add_sub;
    output [DW-1 : 0] sum;
    output co;

`ifdef PLATFORM_SIM
    assign {co, sum} = add_sub ? in1 - in2 - ci : in1 + in2 + ci;
`endif

`ifdef PLATFORM_XILINX
    assign {co, sum} = add_sub ? in1 - in2 - ci : in1 + in2 + ci;
`endif

`ifdef PLATFORM_ASIC
    // Instance of DW01_addsub
    DW01_addsub #(DW) U1 (
        .A(in1), .B(in2), .CI(ci), .ADD_SUB(add_sub),
        .SUM(sum), .CO(co)
    );
`endif

endmodule : addsub_stage0

