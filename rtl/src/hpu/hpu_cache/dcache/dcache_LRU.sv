//*********************************************************************************
//Project Name : HiPU200_Dcache
//Create Time  : 2020/06/08 10:02
//File Name    : dcache_LRU.sv
//Module Name  : dcache_LRU
//Abstract     : LRU of dcache
//*********************************************************************************
//Modification History:
//Time          By              Version                 Change Description
//-----------------------------------------------------------------------
//2010/06/08    Zongpc           3.0                    Change Coding Style
//10:02
//*********************************************************************************

`timescale      1ns/1ps

`include "hpu_head.sv"

import hpu_pkg::*;

module dcache_LRU
#(
    parameter   L1_LRU_WT = 1,//use 1 bit to reflect 2 ways #----#
    parameter   L1_WAYS = 2,//#----#
    parameter   VC_LRU_WT = 3,//use 3 bit to reflect 4 ways #----#
    parameter   VC_WAYS_EXP = 2,//#----#
    parameter   ENTRY_SEL = 7
)(
    input                           clk_i,
    input                           rst_i,
    input  [L1_WAYS-1:0]            hit_rd_l1d_i,
    input  [ENTRY_SEL-1:0]          hit_rd_l1d_entry_i,
    input  [L1_WAYS-1:0]            hit_wr_l1d_i,
    input  [ENTRY_SEL-1:0]          hit_wr_l1d_entry_i,
    input                           hit_rd_vc_i,
    input  [VC_WAYS_EXP-1:0]        hit_rd_vc_way_i,
    input                           hit_wr_vc_i,
    input  [VC_WAYS_EXP-1:0]        hit_wr_vc_way_i,
    input  [ENTRY_SEL-1:0]          rpl_l1d_entry_i,
    output [L1_WAYS-1:0]            hot_l1d_onehot_o,
    output [VC_WAYS_EXP-1:0]        hot_vc_exp_o
);
    localparam                      ENTRY_NUM = 2**ENTRY_SEL;

    reg [L1_LRU_WT-1:0]             hot_wr_l1d;
    reg [L1_LRU_WT-1:0]             hot_rd_l1d;
    reg [L1_LRU_WT-1:0]             hot_l1d_table[ENTRY_NUM-1:0];
    reg [VC_LRU_WT-1:0]             hot_vc_table;

    integer                         i;

    /*********************************************LRU table of l1d*********************************************/
    //LSU load operation maintain hot_l1d_table
    always @(*) begin
        if(hit_rd_l1d_i == 2'b10) begin
            hot_rd_l1d = 1'b0;
        end else if(hit_rd_l1d_i == 2'b01) begin
            hot_rd_l1d = 1'b1;
        end else begin
            hot_rd_l1d = hot_l1d_table[hit_rd_l1d_entry_i];
        end
    end

    //LSU store operation maintain hot_l1d_table
    always @(*) begin
        if (hit_wr_l1d_i == 2'b10) begin
            hot_wr_l1d = 1'b0;
        end else if (hit_wr_l1d_i == 2'b01) begin
            hot_wr_l1d = 1'b1;
        end else begin
            hot_wr_l1d = hot_l1d_table[hit_wr_l1d_entry_i];
        end
    end

    //the rule of the update on hot_l1d
    always @(posedge clk_i or `RST_DECL(rst_i)) begin : Pseudo_LRU_l1d
        if(`RST_TRUE(rst_i)) begin
            for(i=0; i<ENTRY_NUM ; i=i+1) begin
                hot_l1d_table[i] <= {L1_LRU_WT{1'b0}};
            end
        end else begin
            //if(hit_rd_l1d_entry_i == rpl_l1d_entry_i || hit_wr_l1d_entry_i == rpl_l1d_entry_i) begin
                if (hit_rd_l1d_entry_i == hit_wr_l1d_entry_i)begin
                    if (hot_rd_l1d == hot_wr_l1d)begin
                        hot_l1d_table[hit_rd_l1d_entry_i] <= hot_rd_l1d;
                    end else begin
                        if({|hit_rd_l1d_i,|hit_wr_l1d_i} == 2'b10)begin
                            hot_l1d_table[hit_rd_l1d_entry_i] <= hot_rd_l1d;
                        end else if({|hit_rd_l1d_i,|hit_wr_l1d_i} == 2'b01)begin
                            hot_l1d_table[hit_rd_l1d_entry_i] <= hot_wr_l1d;
                        end
                    end//when load and store hit on the same entry, update the table only if hit on the same way
                end else begin
                    hot_l1d_table[hit_rd_l1d_entry_i] <= hot_rd_l1d;
                    hot_l1d_table[hit_wr_l1d_entry_i] <= hot_wr_l1d;
                end//when load and store hit on different entries, update the table respectively
            //end
        end
    end

    /*********************************************LRU table of vc*********************************************/
    always @(posedge clk_i or `RST_DECL(rst_i)) begin : Pseudo_LRU_vc
        if(`RST_TRUE(rst_i)) begin
            hot_vc_table <= 3'b000;
        end else begin
            if(hit_rd_vc_i&&hit_wr_vc_i)begin
                if (hit_rd_vc_way_i[1] == hit_wr_vc_way_i[1]) begin
                    hot_vc_table[2] <= !(hit_rd_vc_way_i[1]);
                    if(hit_rd_vc_way_i[0] == hit_wr_vc_way_i[0]) begin
                        if(hit_rd_vc_way_i[1])begin
                            hot_vc_table[0] <= !(hit_rd_vc_way_i[0]);
                        end else begin
                            hot_vc_table[1] <= !(hit_rd_vc_way_i[0]);
                        end
                    end
                end
            end else if({hit_rd_vc_i,hit_wr_vc_i} == 2'b10)begin
                hot_vc_table[2] <= !(hit_rd_vc_way_i[1]);
                if(hit_rd_vc_way_i[1])begin
                    hot_vc_table[0] <= !(hit_rd_vc_way_i[0]);
                end else begin
                    hot_vc_table[1] <= !(hit_rd_vc_way_i[0]);
                end
            end else if({hit_rd_vc_i,hit_wr_vc_i} == 2'b01)begin
                hot_vc_table[2] <= !(hit_wr_vc_way_i[1]);
                if(hit_wr_vc_way_i[1])begin
                    hot_vc_table[0] <= !(hit_wr_vc_way_i[0]);
                end else begin
                    hot_vc_table[1] <= !(hit_wr_vc_way_i[0]);
                end
            end
        end
    end
    
    /*if hot_l1d_table[replace_l1d_entry_i] == 1'b0, it means way0 is not used at recent;
      if hot_l1d_table[replace_l1d_entry_i] == 1'b1, it means way1 is not used at recent;
      the high bit of the onehot sig reflects whether way1 can be written,
      the low bit reflects whether way0 can be written*/
    assign hot_l1d_onehot_o = (hot_l1d_table[rpl_l1d_entry_i]) ? 2'b10 : 2'b01; 
    assign hot_vc_exp_o     = (hot_vc_table[2:1]==2'b00) ? 2'b00 :
                              (hot_vc_table[2:1]==2'b01) ? 2'b01 :
                              ({hot_vc_table[2],hot_vc_table[0]}==2'b10) ? 2'b10 :
                              ({hot_vc_table[2],hot_vc_table[0]}==2'b11) ? 2'b11 : {VC_WAYS_EXP{1'b0}};

endmodule