//*********************************************************************************
//Project Name : HiPU200_Dcache
//Create Time  : 2020/06/01 21:57
//File Name    : way_data_ram.sv
//Module Name  : way_data_ram
//Abstract     : way_data_ram of dcahe
//*********************************************************************************
//Modification History:
//Time          By              Version                 Change Description
//-----------------------------------------------------------------------
//2010/06/01    Zongpc           3.0                    Change Coding Style
//21:57
//*********************************************************************************

`timescale      1ns/1ps

`include "hpu_head.sv"

import hpu_pkg::*;

module way_data_ram #(
    parameter   AWT           = 32,
    parameter   WORD_SEL      = 4,
    parameter   ENTRY_SEL     = 7,
    parameter   HALF_LINE_DWT = 32*8,
    parameter   LSU_DC_DWT    = 4*8,
	parameter   LSU_DC_SWT    = 4
)(
    input                       clk_i,
    input                       rst_i,

    input                       wr_en_i,
    input  [1:0]                wr_half_en_i,
    input  [AWT-1:0]            wr_addr_i,
    input  [LSU_DC_SWT-1:0]     wr_data_strobe_i,
    input  [HALF_LINE_DWT-1:0]  wr_data_i,

    input                       rd_en_i,
    input  [AWT-1:0]            rd_addr_i,
    output                      rd_wr_conflict_o,
    output [LSU_DC_DWT-1:0]     rd_word_o,
    output [HALF_LINE_DWT-1:0]  rd_half_data_o
);
    localparam  HALF_LINE_SWT      = HALF_LINE_DWT/8;
    localparam  HALF_LINE_WORD_NUM = HALF_LINE_DWT/LSU_DC_DWT;
    // |---------------------32B-----------------------|
    //  _________   _________    _________    _________  ___
    // | 4B | 4B | | 4B | 4B |  | 4B | 4B |  | 4B | 4B |  |
    // |(p0)|(p1)| |(p2)|(p3)|  |(p4)|(p5)|  |(p6)|(p7)| entry_0 (low_half)
    // |____|____| |____|____|  |____|____|  |____|____| _|_
    //  _________   _________    _________    _________  ___
    // | 4B | 4B | | 4B | 4B |  | 4B | 4B |  | 4B | 4B |  |
    // |(p0)|(p1)| |(p2)|(p3)|  |(p4)|(p5)|  |(p6)|(p7)| entry_0 (high_half)
    // |____|____| |____|____|  |____|____|  |____|____| _|_
    // each way has 2**7   = 128 entrys

    wire                        wr_ram_en;
    wire [ENTRY_SEL:0]          wr_ram_addr; //RAM shape is 32B(Width)x256(Depth)
    wire [HALF_LINE_DWT-1:0]    wr_ram_data;
    wire [HALF_LINE_SWT-1:0]    wr_ram_strobe;

    wire                        rd_ram_en;
    wire [ENTRY_SEL:0]          rd_ram_addr;
    wire [HALF_LINE_DWT-1:0]    rd_ram_data;

    reg [WORD_SEL-1:0]          rd_word_sel;

    assign wr_ram_en     = wr_en_i;
    //if wr_half_en[1]   = 1,then half_data(32B) should be written
    //use wr_half_en[0] to choose which part to write 
    assign wr_ram_addr   = (wr_half_en_i[1]) ? {wr_addr_i[ENTRY_SEL+WORD_SEL+1:WORD_SEL+2],wr_half_en_i[0]}:
                                               wr_addr_i[ENTRY_SEL+WORD_SEL+1:WORD_SEL+1];
    assign wr_ram_data   = (wr_half_en_i[1]) ? wr_data_i : {HALF_LINE_WORD_NUM{wr_data_i[LSU_DC_DWT-1:0]}};
    assign wr_ram_strobe = (wr_half_en_i[1]) ? {HALF_LINE_SWT{1'b1}} :
                                               ((32'h0000000f&{{28{1'b0}},wr_data_strobe_i}) << {wr_addr_i[WORD_SEL:2],2'b00});

    assign rd_ram_en        = rd_en_i;
    assign rd_ram_addr      = rd_addr_i[ENTRY_SEL+WORD_SEL+1:WORD_SEL+1];
    assign rd_wr_conflict_o = wr_ram_en & (wr_half_en_i == 2'b10) & ({wr_addr_i[ENTRY_SEL+WORD_SEL+1:WORD_SEL+2],1'b0} == rd_ram_addr);//work with TSMC IP wr-first-mem
    //assign rd_wr_conflict_o = wr_ram_en & (wr_half_en_i == 2'b11) & ({wr_addr_i[ENTRY_SEL+WORD_SEL+1:WORD_SEL+2],1'b0} == rd_ram_addr);//work with Xilinx IP rd-first-mem

    always @ (posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            rd_word_sel <= {WORD_SEL{1'b0}};
        end else begin
            rd_word_sel <= rd_addr_i[WORD_SEL:2];
        end
    end

    assign rd_word_o     = ({LSU_DC_DWT{rd_word_sel==3'b000}} & rd_ram_data[31 :0  ]) |
                           ({LSU_DC_DWT{rd_word_sel==3'b001}} & rd_ram_data[63 :32 ]) |
                           ({LSU_DC_DWT{rd_word_sel==3'b010}} & rd_ram_data[95 :64 ]) |
                           ({LSU_DC_DWT{rd_word_sel==3'b011}} & rd_ram_data[127:96 ]) |
                           ({LSU_DC_DWT{rd_word_sel==3'b100}} & rd_ram_data[159:128]) |
                           ({LSU_DC_DWT{rd_word_sel==3'b101}} & rd_ram_data[191:160]) |
                           ({LSU_DC_DWT{rd_word_sel==3'b110}} & rd_ram_data[223:192]) | 
                           ({LSU_DC_DWT{rd_word_sel==3'b111}} & rd_ram_data[255:224]) ;
    assign rd_half_data_o = rd_ram_data;


    sdp_uhd_w256x256s_r256x256d1_wrap data_ram (.clk_i          (clk_i),
                                                .we_i           (wr_ram_en),
                                                .waddr_i        (wr_ram_addr),
                                                .wdata_i        (wr_ram_data),
                                                .wdata_strob_i  (wr_ram_strobe),
                                                .re_i           (rd_ram_en),
                                                .raddr_i        (rd_ram_addr),
                                                .rdata_o        (rd_ram_data));
endmodule
