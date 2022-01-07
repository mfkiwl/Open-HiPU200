//*********************************************************************************
//Project Name : HiPU200_Dcache
//Create Time  : 2020/06/02 16:39
//File Name    : way_tag_ram.sv
//Module Name  : way_tag_ram
//Abstract     : way_tag_ram of dcache
//*********************************************************************************
//Modification History:
//Time          By              Version                 Change Description
//-----------------------------------------------------------------------
//2010/06/02    Zongpc           3.0                    Change Coding Stytle
//16:39
//*********************************************************************************

`timescale      1ns/1ps

`include "hpu_head.sv"

import hpu_pkg::*;

module way_tag_ram #(
    parameter   AWT       = 32,
    parameter   WORD_SEL  = 4,
    parameter   ENTRY_SEL = 7,
    parameter   ENTRY_NUM = 2*ENTRY_SEL,
    parameter   TAG_WT    = AWT-ENTRY_SEL-WORD_SEL-2,
    parameter   TAG_WT_VC = AWT-WORD_SEL-2
)(
    input                   clk_i,
    input                   rst_i,

    input                   wr_en_i,
    input  [AWT-1:0]        wr_addr_i,
    input                   rd_en_i,
    input  [1:0]            rd_half_en_i,
    input  [AWT-1:0]        rd_addr_i,

    input  [AWT-1:0]        ld_addr_i,

    input                   rpl_disable_i,
    //csr ctrl interface
    input                   clear_all_i,
    input                   clear_line_i,
    input  [AWT-1:0]        clear_addr_i,

    output [TAG_WT_VC-1:0]  rd_tag_o,
    output                  hit_o,
    output                  valid_o
);
    wire                    wr_ram_en;
    wire [ENTRY_SEL-1:0]    wr_ram_addr;
    wire [TAG_WT-1:0]       wr_ram_tag;
    wire                    rd_ram_en;
    wire [ENTRY_SEL-1:0]    rd_ram_addr;
    wire [TAG_WT-1:0]       rd_ram_tag;

    wire [ENTRY_SEL-1:0]    clear_entry;

    reg                     rd_en_dly1;
    reg  [ENTRY_SEL-1:0]    rd_entry_dly1;
    reg  [TAG_WT-1:0]       tag_i_dly1;

    reg  [ENTRY_SEL-1:0]    rpl_entry_rcd;

    //work with xilinx IP rd-first-mem
    //*Notice : when use TSMC IP wr-first-mem it should be comment
    //wire                    hit_ram;
    //wire                    hit_safe;
    //reg                     tag_conflict;
    //reg                     tag_safe;

    reg  [ENTRY_NUM-1:0]    valid_tabel;//record the valid information

    assign wr_ram_en   = wr_en_i;
    assign wr_ram_addr = wr_addr_i[ENTRY_SEL+WORD_SEL+1:WORD_SEL+2];
    assign wr_ram_tag  = wr_addr_i[AWT-1:ENTRY_SEL+WORD_SEL+2];
    assign rd_ram_en   = rd_en_i;
    assign rd_ram_addr = rd_addr_i[ENTRY_SEL+WORD_SEL+1:WORD_SEL+2];
    assign clear_entry = clear_addr_i[ENTRY_SEL+WORD_SEL+1:WORD_SEL+2];

    //vaild_table is controled by csr and wr operation
    always @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            valid_tabel <= {ENTRY_NUM{1'b0}};
        end else begin
            if (clear_all_i) begin
                valid_tabel <= {ENTRY_NUM{1'b0}};
            end else if (clear_line_i) begin
                valid_tabel[clear_entry] <= 1'b0;
            end else if (rpl_disable_i && rd_half_en_i == 2'b11) begin
                valid_tabel[rpl_entry_rcd] <= 1'b0;
            end else if (wr_en_i) begin
                valid_tabel[wr_ram_addr] <= 1'b1;
            end
        end
    end

    //rcd the entry to be replaced
    always @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            rpl_entry_rcd <= {ENTRY_SEL{1'b0}};
        end else begin
            if(rd_half_en_i == 2'b10) begin
                rpl_entry_rcd <= ld_addr_i[ENTRY_SEL+WORD_SEL+1:WORD_SEL+2];
            end
        end
    end
    
    //delay some signals to compare with orignal ones,then git the way hit status
    always @ (posedge clk_i or `RST_DECL(rst_i)) begin
        if (`RST_TRUE(rst_i)) begin
            rd_en_dly1          <= 1'b0;
            rd_entry_dly1       <= {ENTRY_SEL{1'b0}};
            tag_i_dly1          <= {TAG_WT{1'b0}};
            //work with xilinx IP rd-first-mem
            //*Notice : when use TSMC IP wr-first-mem it should be comment
            //tag_conflict       <= 1'b0; 
            //tag_safe           <= 1'b0;
        end else begin
            rd_en_dly1          <= rd_en_i;
            rd_entry_dly1       <= rd_addr_i[ENTRY_SEL+WORD_SEL+1:WORD_SEL+2];
            tag_i_dly1          <= rd_addr_i[AWT-1:ENTRY_SEL+WORD_SEL+2];
            //work with xilinx IP rd-first-mem
            //*Notice : when use TSMC IP wr-first-mem it should be comment
            //tag_conflict        <= (wr_ram_addr==rd_ram_addr) ? (wr_ram_en&rd_ram_en) : 1'b0;
            //tag_safe            <= (wr_ram_tag == rd_addr_i[AWT-1:ENTRY_SEL+WORD_SEL+2]);
        end
    end
    
    assign rd_tag_o = {rd_ram_tag,rd_entry_dly1};
    //assign hit_ram = (!tag_conflict) & valid_tabel[rd_entry_dly1] & (rd_ram_tag == tag_i_dly1);
    //assign hit_safe = tag_conflict & tag_safe;
    //assign hit_o = (rd_en_dly1 & hit_safe) | (rd_en_dly1 & hit_ram); //work with xilinx IP rd-first-mem
    assign hit_o = rd_en_dly1 & valid_tabel[rd_entry_dly1] & (rd_ram_tag == tag_i_dly1);//work with TSMC IP wr-first-mem
    assign valid_o  = (rd_en_dly1) ? valid_tabel[rd_entry_dly1] : 1'b0;

    sdp_uhd_w128x19b_r128x19d1_wrap tag_ram(.clk_i           (clk_i),
                                            .we_i            (wr_ram_en),
                                            .waddr_i         (wr_ram_addr),
                                            .wdata_i         (wr_ram_tag),
                                            .wdata_bwe_i     ({TAG_WT{1'b1}}),
                                            .re_i            (rd_ram_en),
                                            .raddr_i         (rd_ram_addr),
                                            .rdata_o         (rd_ram_tag));

endmodule

