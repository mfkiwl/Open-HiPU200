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
// FILE NAME  : mult_stage0.svh
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns/1ps

// `define PLATFORM_ASIC
`include "glb_def.svh"

module mult_stage0 (in1, in2, tc, prod);
    parameter A_width = 8, B_width = 8;

    input [A_width-1:0] in1;
    input [B_width-1:0] in2;
    input tc;
    output[A_width+B_width-1:0] prod;

`ifdef PLATFORM_SIM
    assign prod = $signed(in1) * $signed(in2);
`endif

`ifdef PLATFORM_XILINX
    mul8_stage0 U1(.A(in1), .B(in2), .P(prod));
`endif

`ifdef PLATFORM_ASIC
    // Instance of DW02_mult
    DW02_mult #(A_width, B_width) U1 (
        .A(in1), .B(in2), .TC(tc), .PRODUCT(prod)
    );
`endif

endmodule : mult_stage0

// using function inference
// module mul8_8 (in1, in2, prod);
//     parameter func_A_width = 8, func_B_width = 8;
//
//     // Pass the widths to the DWF_mult functions
//     parameter A_width = func_A_width, B_width = func_B_width;
//
//     // Please add search_path = search_path + {synopsys_root + "/dw/sim_ver"}
//     // to your .synopsys_dc.setup file (for synthesis) and add
//     // +incdir+$SYNOPSYS/dw/sim_ver+ to your verilog simulator command line
//     // (for simulation).
//     `include "DW02_mult_function.inc"
//
//     input [func_A_width-1:0] in1;
//     input [func_B_width-1:0] in2;
//     output[func_A_width+func_B_width-1:0] prod;
//
//     assign prod = DWF_mult_tc(in1, in2);
//
// endmodule : mul8_8
