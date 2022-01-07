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
// FILE NAME  : dec_bin_to_onehot.sv
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps

module dec_bin_to_onehot #(
    parameter BIN_WTH = 3,
    parameter OHOT_WTH = 8
) (
    input   logic[BIN_WTH-1 : 0]                    data_i,
    output  logic[OHOT_WTH-1 : 0]                   data_o
);

//======================================================================================================================
// Wire & Reg declaration
//======================================================================================================================
    genvar gi;

//======================================================================================================================
// Instance
//======================================================================================================================

    generate
        for (gi = 0; gi < OHOT_WTH; gi = gi+1) begin
            assign data_o[gi] = (data_i == gi) ? 1'b1 : 1'b0;
        end
    endgenerate

//======================================================================================================================
// just for simulation
//======================================================================================================================
// synospsys translate_off

// synospsys translate_on

//======================================================================================================================
// probe signals
//======================================================================================================================

endmodule : dec_bin_to_onehot

