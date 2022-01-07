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
// FILE NAME  : sum4_stage0.sv
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns/1ps

// `define PLATFORM_ASIC
`include "glb_def.svh"

module sum4_stage0 (in1, in2, in3, in4, sum);
    parameter DW = 32;

    input [DW-1:0] in1;
    input [DW-1:0] in2;
    input [DW-1:0] in3;
    input [DW-1:0] in4;
    output[DW-1:0] sum;

`ifdef PLATFORM_SIM
    assign sum = in1 + in2 + in3 + in4;
`endif

`ifdef PLATFORM_XILINX
    assign sum = in1 + in2 + in3 + in4;
`endif

`ifdef PLATFORM_ASIC
    parameter num_inputs = 4;
    parameter input_width = DW;
    logic[DW*4-1:0] in;
    assign in = {in1, in2, in3, in4};
    // Instance of DW02_sum
    DW02_sum #(num_inputs,  input_width) U1 (
        .INPUT(in), .SUM(sum)
    );
`endif

endmodule : sum4_stage0
