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
// FILE NAME  : sig_sync.sv
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps

module sig_sync #(
    SIG_WTH = 1,
    SIG_DLY = 2
) (
    // clock & reset
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    // write interface
    input   logic[SIG_WTH-1 : 0]                    data_i,
    output  logic[SIG_WTH-1 : 0]                    data_o
);

//======================================================================================================================
// Wire & Reg declaration
//======================================================================================================================

    logic[SIG_DLY-1 : 0][SIG_WTH-1 : 0]        sync_data;

//======================================================================================================================
// Instance
//======================================================================================================================

    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<SIG_DLY; i=i+1) begin
                sync_data[i] <= {SIG_WTH{1'b0}};
            end
        end else begin
            sync_data <= {sync_data[SIG_DLY-2 : 0], data_i};
        end
    end
    assign data_o = sync_data[SIG_DLY-1];

//======================================================================================================================
// just for simulation
//======================================================================================================================
// synospsys translate_off

// synospsys translate_on

//======================================================================================================================
// probe signals
//======================================================================================================================

endmodule : sig_sync
