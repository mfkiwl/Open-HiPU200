//*********************************************************************************
//Project Name : HiPU200_Dcache
//Create Time  : 2020/06/03 09:17
//File Name    : vc_data_ram.sv
//Module Name  : vc_data_ram
//Abstract     : vc_data_ram of dcache
//*********************************************************************************
//Modification History:
//Time          By              Version                 Change Description
//-----------------------------------------------------------------------
//2010/06/03    Zongpc           3.0                    Change Coding Style
//09:17
//*********************************************************************************

`timescale      1ns/1ps

`include "hpu_head.sv"

import hpu_pkg::*;

module vc_data_ram #(
    parameter   LINE_DWT    = 64*8,
    parameter   WORD_SEL    = 4,
    parameter   VC_WAYS_EXP = 2,
    parameter   VC_WAYS     = 2**VC_WAYS_EXP,
    parameter   LSU_DC_DWT  = 4*8,
    parameter   LSU_DC_SWT  = 4
)(
    input                       clk_i,
    input                       rst_i,

    input                       wr_en_i,
    input  [VC_WAYS_EXP-1:0]    wr_way_i,
    //if there is a WORD(4B) should be written, this signal will indicate the place
    input  [WORD_SEL-1:0]       wr_word_en_i,
    //if there is a LINE(64B) shoule be written, this signal will be high
    input                       wr_line_en_i,
    input  [LSU_DC_SWT-1:0]     wr_data_strobe_i,
    input  [LINE_DWT-1:0]       wr_data_i,

    input                       rd_en_i,
    input  [VC_WAYS_EXP-1:0]    rd_way_i,
    input  [WORD_SEL-1:0]       rd_word_en_i,
    output [LSU_DC_DWT-1:0]     rd_word_o
);
    localparam WORD_NUM = 2**WORD_SEL;

    reg [LSU_DC_DWT-1:0] data_ram [0:VC_WAYS-1][0:WORD_NUM-1];
    reg [LSU_DC_DWT-1:0] rd_word;

    always @ (posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer j=0; j<VC_WAYS; j=j+1) begin
                for(integer i=0; i<WORD_NUM; i=i+1) begin
                    data_ram[j][i] <= {LSU_DC_DWT{1'b0}};
                end
            end
        end else begin
            if(wr_en_i) begin 
                if (wr_line_en_i) begin
                    for(integer i=0; i<WORD_NUM; i=i+1) begin
                        data_ram[wr_way_i][i] <= wr_data_i[i*LSU_DC_DWT +: LSU_DC_DWT];
                    end
                end else begin
                    data_ram[wr_way_i][wr_word_en_i][7:0]   <= (wr_data_strobe_i[0]) ? wr_data_i[7:0]  :
                                                                                       data_ram[wr_way_i][wr_word_en_i][7:0];
                    data_ram[wr_way_i][wr_word_en_i][15:8]  <= (wr_data_strobe_i[1]) ? wr_data_i[15:8] :
                                                                                       data_ram[wr_way_i][wr_word_en_i][15:8];
                    data_ram[wr_way_i][wr_word_en_i][23:16] <= (wr_data_strobe_i[2]) ? wr_data_i[23:16]:
                                                                                       data_ram[wr_way_i][wr_word_en_i][23:16];
                    data_ram[wr_way_i][wr_word_en_i][31:24] <= (wr_data_strobe_i[3]) ? wr_data_i[31:24]:
                                                                                       data_ram[wr_way_i][wr_word_en_i][31:24];
                end
            end
        end
    end

    always @ (posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            rd_word  <= {LSU_DC_DWT{1'b0}};
        end else begin
            if (rd_en_i) begin
                rd_word <= data_ram[rd_way_i][rd_word_en_i];
            end
        end
    end

    assign rd_word_o = rd_word;

endmodule