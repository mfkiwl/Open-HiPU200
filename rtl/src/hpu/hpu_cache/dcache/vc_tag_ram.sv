//*********************************************************************************
//Project Name : HiPU200_Dcache
//Create Time  : 2020/06/02 19:59
//File Name    : vc_tag_ram.sv
//Module Name  : vc_tag_ram
//Abstract     : vc_tag_ram of dcache
//*********************************************************************************
//Modification History:
//Time          By              Version                 Change Description
//-----------------------------------------------------------------------
//2010/06/02    Zongpc           3.0                    Change Coding Style
//19:59
//*********************************************************************************

`timescale      1ns/1ps

`include "hpu_head.sv"

import hpu_pkg::*;

module vc_tag_ram #(
    parameter   AWT         = 32,
    parameter   WORD_SEL    = 4,
    parameter   ENTRY_SEL   = 7,
    parameter   TAG_WT_VC   = AWT-WORD_SEL-2,
    parameter   VC_WAYS_EXP = 2,
    parameter   VC_WAYS     = 2**VC_WAYS_EXP
)(
    input                       clk_i,
    input                       rst_i,

    input                       wr_en_i,
    input  [VC_WAYS_EXP-1:0]    wr_way_i,
    input  [TAG_WT_VC-1:0]      wr_tag_i,
    
    input                       rd_rdtag_en_i,
    input  [TAG_WT_VC-1:0]      rd_rdtag_i,
    input                       rd_wrtag_en_i,
    input  [TAG_WT_VC-1:0]      rd_wrtag_i,

    input                       clear_all_i,
    input                       clear_line_i,
    input  [VC_WAYS_EXP-1:0]    clear_way_i,

    output                      hit_rd_o,
    output [VC_WAYS_EXP-1:0]    hit_rd_way_o,
    output                      hit_wr_o,
    output [VC_WAYS_EXP-1:0]    hit_wr_way_o,
    output [VC_WAYS-1:0]        valid_o
);
    reg [TAG_WT_VC-1:0]         tag_ram[VC_WAYS-1:0];//use Registers to save tag information
    reg [VC_WAYS-1:0]           valid_table;//record valid information

    reg                         hit_rd;
    reg                         hit_wr;
    reg [VC_WAYS_EXP-1:0]       hit_rd_way;
    reg [VC_WAYS_EXP-1:0]       hit_wr_way;

    always @ (posedge clk_i or `RST_DECL(rst_i)) begin
        if (`RST_TRUE(rst_i)) begin
            for (integer i = 0; i < VC_WAYS; i = i+1) begin
                tag_ram[i] <= 0;
            end
            valid_table <= 0;
        end else begin
            if (clear_all_i) begin
                valid_table <= 0;
            end else if (clear_line_i) begin
                valid_table[clear_way_i] <= 1'b0;
            end else if (wr_en_i) begin
                valid_table[wr_way_i] <= 1'b1;
                tag_ram[wr_way_i]     <= wr_tag_i;
            end
        end
    end

    always @ (posedge clk_i or `RST_DECL(rst_i)) begin
        if (`RST_TRUE(rst_i)) begin
            hit_rd     <= 1'b0;
            hit_rd_way <= {VC_WAYS_EXP{1'b0}};
        end else begin
            if (rd_rdtag_en_i) begin
                if (wr_en_i) begin
                    {hit_rd,hit_rd_way} <= (wr_tag_i == rd_rdtag_i) ? {1'b1,wr_way_i} :
                                           (valid_table[0] && (tag_ram[0] == rd_rdtag_i) && wr_way_i!=2'b00) ? 3'b100 :
                                           (valid_table[1] && (tag_ram[1] == rd_rdtag_i) && wr_way_i!=2'b01) ? 3'b101 :
                                           (valid_table[2] && (tag_ram[2] == rd_rdtag_i) && wr_way_i!=2'b10) ? 3'b110 :
                                           (valid_table[3] && (tag_ram[3] == rd_rdtag_i) && wr_way_i!=2'b11) ? 3'b111 : 
                                           {1'b0,{VC_WAYS_EXP{1'b0}}};
                end else begin
                    {hit_rd,hit_rd_way} <= (valid_table[0] && (tag_ram[0] == rd_rdtag_i)) ? 3'b100 :
                                           (valid_table[1] && (tag_ram[1] == rd_rdtag_i)) ? 3'b101 :
                                           (valid_table[2] && (tag_ram[2] == rd_rdtag_i)) ? 3'b110 :
                                           (valid_table[3] && (tag_ram[3] == rd_rdtag_i)) ? 3'b111 : 
                                           {1'b0,{VC_WAYS_EXP{1'b0}}};
                end
            end else begin
                {hit_rd,hit_rd_way} <= {1'b0,{VC_WAYS_EXP{1'b0}}};
            end
        end
    end

    always @ (posedge clk_i or `RST_DECL(rst_i)) begin
        if (`RST_TRUE(rst_i)) begin
            hit_wr     <= 1'b0;
            hit_wr_way <= {VC_WAYS_EXP{1'b0}};
        end else begin
            if (rd_wrtag_en_i) begin
                if (wr_en_i) begin
                    {hit_wr,hit_wr_way} <= (wr_tag_i == rd_wrtag_i) ? {1'b1,wr_way_i} :
                                           (valid_table[0] && (tag_ram[0] == rd_wrtag_i) && wr_way_i!=2'b00) ? 3'b100 :
                                           (valid_table[1] && (tag_ram[1] == rd_wrtag_i) && wr_way_i!=2'b01) ? 3'b101 :
                                           (valid_table[2] && (tag_ram[2] == rd_wrtag_i) && wr_way_i!=2'b10) ? 3'b110 :
                                           (valid_table[3] && (tag_ram[3] == rd_wrtag_i) && wr_way_i!=2'b11) ? 3'b111 :
                                           {1'b0,{VC_WAYS_EXP{1'b0}}};
                end else begin
                    {hit_wr,hit_wr_way} <= (valid_table[0] && (tag_ram[0] == rd_wrtag_i)) ? 3'b100 :
                                           (valid_table[1] && (tag_ram[1] == rd_wrtag_i)) ? 3'b101 :
                                           (valid_table[2] && (tag_ram[2] == rd_wrtag_i)) ? 3'b110 :
                                           (valid_table[3] && (tag_ram[3] == rd_wrtag_i)) ? 3'b111 :
                                           {1'b0,{VC_WAYS_EXP{1'b0}}};
		    	end
            end else begin
                {hit_wr,hit_wr_way} <= {1'b0,{VC_WAYS_EXP{1'b0}}};
            end
        end
    end

    assign hit_rd_o     = hit_rd;
    assign hit_wr_o     = hit_wr;
    assign hit_rd_way_o = hit_rd_way;
    assign hit_wr_way_o = hit_wr_way;
    assign valid_o      = valid_table;

endmodule 