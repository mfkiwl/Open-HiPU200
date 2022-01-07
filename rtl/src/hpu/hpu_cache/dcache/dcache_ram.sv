//*********************************************************************************
//Project Name : HiPU200_Dcache
//Create Time  : 2020/06/09 16:40
//File Name    : dcache_ram.sv
//Module Name  : dcache_ram
//Abstract     : the ram_top of dcache
//*********************************************************************************
//Modification History:
//Time          By              Version                 Change Description
//-----------------------------------------------------------------------
//2010/06/09    Zongpc           3.0                    Change Coding Style
//16:40
//*********************************************************************************

`timescale      1ns/1ps

`include "hpu_head.sv"

import hpu_pkg::*;

module dcache_ram
#(
    parameter   AWT           = 32,
    parameter   WORD_SEL      = 4,
    parameter   ENTRY_SEL     = 7,
    parameter   ENTRY_NUM     = 2*ENTRY_SEL,
    parameter   TAG_WT        = AWT-ENTRY_SEL-WORD_SEL-2,
    parameter   TAG_WT_VC     = AWT-WORD_SEL-2,
    parameter   L1_WAYS       = 2,
    parameter   VC_WAYS_EXP   = 2,
    parameter   VC_WAYS       = 2**VC_WAYS_EXP,
    parameter   LINE_DWT      = 64*8,
    parameter   HALF_LINE_DWT = 32*8,
    parameter   LSU_DC_DWT    = 4*8,
	parameter   LSU_DC_SWT    = 4
)(
    input                       clk_i,
    input                       rst_i,

     //the interface with way_tag_ram
    input                       rd_l1d_rdtag_en_i,
    input  [AWT-1:0]            rd_l1d_rdtag_addr_i,
    output [L1_WAYS-1:0]        hit_rd_l1d_o,

    input                       rd_l1d_wrtag_en_i,
    input  [AWT-1:0]            rd_l1d_wrtag_addr_i,
    output [L1_WAYS-1:0]        hit_wr_l1d_o,

    input  [L1_WAYS-1:0]        wr_l1d_tag_en_i,
    output [TAG_WT_VC-1:0]      rd_l1d_rdtag_o[L1_WAYS-1:0],
    output [L1_WAYS-1:0]        valid_rd_l1d_o,

    input  [L1_WAYS-1:0]        rpl_disable_i,

    //the interface with vc_tag_ram
    input                       rd_vc_rdtag_en_i,
    input  [TAG_WT_VC-1:0]      rd_vc_rdtag_i,
    output                      hit_rd_vc_o,
    output [VC_WAYS_EXP-1:0]    hit_rd_vc_way_o,

    input                       rd_vc_wrtag_en_i,
    input  [TAG_WT_VC-1:0]      rd_vc_wrtag_i,
    output                      hit_wr_vc_o,
    output [VC_WAYS_EXP-1:0]    hit_wr_vc_way_o,

    output [VC_WAYS-1:0]        victim_valid_o,

    input                       wr_vc_tag_en_i,
//    input  [VC_WAYS_EXP-1:0]    wr_vc_tag_way_i,
    input  [TAG_WT_VC-1:0]      wr_vc_tag_i,

    //the interface with way_data_ram
    input  [L1_WAYS-1:0]        wr_l1d_en_i,
    input  [1:0]                wr_l1d_half_en_i[L1_WAYS-1:0], //2'10 low part;2'b11 high part;2'b00 No half mode
    input  [LSU_DC_SWT-1:0]     wr_l1d_data_strobe_i[L1_WAYS-1:0],
    input  [AWT-1:0]            wr_l1d_addr_i[L1_WAYS-1:0],
    input  [HALF_LINE_DWT-1:0]  wr_l1d_data_i[L1_WAYS-1:0],

    input  [L1_WAYS-1:0]        rd_l1d_en_i,
    input  [1:0]                rd_l1d_half_en_i[L1_WAYS-1:0],
    input  [AWT-1:0]            rd_l1d_addr_i[L1_WAYS-1:0],
    output [LSU_DC_DWT-1:0]     rd_l1d_word_o[L1_WAYS-1:0],
    output [HALF_LINE_DWT-1:0]  rd_l1d_halfdata_o[L1_WAYS-1:0],
    output [L1_WAYS-1:0]        way_data_rw_conflict_o,

    input  [L1_WAYS-1:0]        clear_l1d_way_i,
    input  [L1_WAYS-1:0]        clear_l1d_line_i,
    input  [AWT-1:0]            clear_l1d_addr_i[L1_WAYS-1:0],

    //the interface with vc_data_ram
    input                       wr_vc_en_i,
    input  [VC_WAYS_EXP-1:0]    wr_vc_way_i,
    input  [WORD_SEL-1:0]       wr_vc_word_en_i,
    input                       wr_vc_line_en_i,
    input  [LSU_DC_SWT-1:0]     wr_vc_data_strobe_i,
    input  [LINE_DWT-1:0]       wr_vc_data_i,

    input                       rd_vc_en_i,
    input  [VC_WAYS_EXP-1:0]    rd_vc_way_i,
    input  [WORD_SEL-1:0]       rd_vc_word_en_i,
    output [LSU_DC_DWT-1:0]     rd_vc_word_o,

    //some csr sigs to ram
    input                       clear_vc_all_i,
    input                       clear_vc_line_i,
    input [VC_WAYS_EXP-1:0]     clear_vc_way_i
);
    wire [TAG_WT_VC-1:0]        rd_l1d_wrtag[L1_WAYS-1:0];
	wire [L1_WAYS-1:0] 		    valid_wr_l1d;

    way_tag_ram 
    #(
        .AWT       (AWT       ),
        .WORD_SEL  (WORD_SEL  ),
        .ENTRY_SEL (ENTRY_SEL ),
        .ENTRY_NUM (ENTRY_NUM ),
        .TAG_WT    (TAG_WT    ),
        .TAG_WT_VC (TAG_WT_VC )
    )
    way0_wrtag(
        .clk_i          (clk_i                   ),
        .rst_i          (rst_i                   ),
        .wr_en_i        (wr_l1d_tag_en_i[0]      ),
        .wr_addr_i      (wr_l1d_addr_i[0]        ),
        .rd_en_i        (rd_l1d_wrtag_en_i       ),
        .rd_half_en_i   (rd_l1d_half_en_i[0]     ),
        .rd_addr_i      (rd_l1d_wrtag_addr_i     ),
        .ld_addr_i      (rd_l1d_rdtag_addr_i     ),
        .rpl_disable_i  (rpl_disable_i[0]        ),
        .clear_all_i    (clear_l1d_way_i[0]      ),
        .clear_line_i   (clear_l1d_line_i[0]     ),
        .clear_addr_i   (clear_l1d_addr_i[0]     ),
        .rd_tag_o       (rd_l1d_wrtag[0]         ),
        .hit_o          (hit_wr_l1d_o[0]         ),
        .valid_o        (valid_wr_l1d[0]         )
    );

    way_tag_ram 
    #(
        .AWT       (AWT       ),
        .WORD_SEL  (WORD_SEL  ),
        .ENTRY_SEL (ENTRY_SEL ),
        .ENTRY_NUM (ENTRY_NUM ),
        .TAG_WT    (TAG_WT    ),
        .TAG_WT_VC (TAG_WT_VC )
    )
    way0_rdtag(
        .clk_i          (clk_i                   ),
        .rst_i          (rst_i                   ),
        .wr_en_i        (wr_l1d_tag_en_i[0]      ),
        .wr_addr_i      (wr_l1d_addr_i[0]        ),
        .rd_en_i        (rd_l1d_rdtag_en_i       ),
        .rd_half_en_i   (rd_l1d_half_en_i[0]     ),
        .rd_addr_i      (rd_l1d_rdtag_addr_i     ),
        .ld_addr_i      (rd_l1d_rdtag_addr_i     ),
        .rpl_disable_i  (rpl_disable_i[0]        ),
        .clear_all_i    (clear_l1d_way_i[0]      ),
        .clear_line_i   (clear_l1d_line_i[0]     ),
        .clear_addr_i   (clear_l1d_addr_i[0]     ),
        .rd_tag_o       (rd_l1d_rdtag_o[0]       ),
        .hit_o          (hit_rd_l1d_o[0]         ),
        .valid_o        (valid_rd_l1d_o[0]       )
    );

    way_tag_ram 
    #(
        .AWT       (AWT       ),
        .WORD_SEL  (WORD_SEL  ),
        .ENTRY_SEL (ENTRY_SEL ),
        .ENTRY_NUM (ENTRY_NUM ),
        .TAG_WT    (TAG_WT    ),
        .TAG_WT_VC (TAG_WT_VC )
    )
    way1_wrtag(
        .clk_i          (clk_i                   ),
        .rst_i          (rst_i                   ),
        .wr_en_i        (wr_l1d_tag_en_i[1]      ),
        .wr_addr_i      (wr_l1d_addr_i[1]        ),
        .rd_en_i        (rd_l1d_wrtag_en_i       ),
        .rd_half_en_i   (rd_l1d_half_en_i[1]     ),
        .rd_addr_i      (rd_l1d_wrtag_addr_i     ),
        .ld_addr_i      (rd_l1d_rdtag_addr_i     ),
        .rpl_disable_i  (rpl_disable_i[1]        ),
        .clear_all_i    (clear_l1d_way_i[1]      ),
        .clear_line_i   (clear_l1d_line_i[1]     ),
        .clear_addr_i   (clear_l1d_addr_i[1]     ),
        .rd_tag_o       (rd_l1d_wrtag[1]         ),
        .hit_o          (hit_wr_l1d_o[1]         ),
        .valid_o        (valid_wr_l1d[1]         )
    );

    way_tag_ram 
    #(
        .AWT       (AWT       ),
        .WORD_SEL  (WORD_SEL  ),
        .ENTRY_SEL (ENTRY_SEL ),
        .ENTRY_NUM (ENTRY_NUM ),
        .TAG_WT    (TAG_WT    ),
        .TAG_WT_VC (TAG_WT_VC )
    )
    way1_rdtag(
        .clk_i          (clk_i                   ),
        .rst_i          (rst_i                   ),
        .wr_en_i        (wr_l1d_tag_en_i[1]      ),
        .wr_addr_i      (wr_l1d_addr_i[1]        ),
        .rd_en_i        (rd_l1d_rdtag_en_i       ),
        .rd_half_en_i   (rd_l1d_half_en_i[1]     ),
        .rd_addr_i      (rd_l1d_rdtag_addr_i     ),
        .ld_addr_i      (rd_l1d_rdtag_addr_i     ),
        .rpl_disable_i  (rpl_disable_i[1]        ),
        .clear_all_i    (clear_l1d_way_i[1]      ),
        .clear_line_i   (clear_l1d_line_i[1]     ),
        .clear_addr_i   (clear_l1d_addr_i[1]     ),
        .rd_tag_o       (rd_l1d_rdtag_o[1]       ),
        .hit_o          (hit_rd_l1d_o[1]         ),
        .valid_o        (valid_rd_l1d_o[1]       )
    );

    vc_tag_ram 
    #(
        .AWT         (AWT         ),
        .WORD_SEL    (WORD_SEL    ),
        .ENTRY_SEL   (ENTRY_SEL   ),
        .TAG_WT_VC   (TAG_WT_VC   ),
        .VC_WAYS_EXP (VC_WAYS_EXP ),
        .VC_WAYS     (VC_WAYS     )
    )
    vc_tag(
        .clk_i         (clk_i                ),
        .rst_i         (rst_i                ),
        .wr_en_i       (wr_vc_tag_en_i       ),
        .wr_way_i      (wr_vc_way_i          ),
        .wr_tag_i      (wr_vc_tag_i          ),
        .rd_rdtag_en_i (rd_vc_rdtag_en_i     ),
        .rd_rdtag_i    (rd_vc_rdtag_i        ),
        .rd_wrtag_en_i (rd_vc_wrtag_en_i     ),
        .rd_wrtag_i    (rd_vc_wrtag_i        ),
        .clear_all_i   (clear_vc_all_i       ),
        .clear_line_i  (clear_vc_line_i      ),
        .clear_way_i   (clear_vc_way_i       ),
        .hit_rd_o      (hit_rd_vc_o          ),
        .hit_rd_way_o  (hit_rd_vc_way_o      ),
        .hit_wr_o      (hit_wr_vc_o          ),
        .hit_wr_way_o  (hit_wr_vc_way_o      ),
        .valid_o       (victim_valid_o       )
    );
    

    way_data_ram 
    #(
        .AWT                (AWT                ),
        .WORD_SEL           (WORD_SEL           ),
        .ENTRY_SEL          (ENTRY_SEL          ),
        .HALF_LINE_DWT      (HALF_LINE_DWT      ),
        .LSU_DC_DWT         (LSU_DC_DWT         ),
        .LSU_DC_SWT         (LSU_DC_SWT         )
    )
    way0_data(
        .clk_i            (clk_i                     ),
        .rst_i            (rst_i                     ),
        .wr_en_i          (wr_l1d_en_i[0]            ),
        .wr_half_en_i     (wr_l1d_half_en_i[0]       ),
        .wr_addr_i        (wr_l1d_addr_i[0]          ),
        .wr_data_strobe_i (wr_l1d_data_strobe_i[0]   ),
        .wr_data_i        (wr_l1d_data_i[0]          ),
        .rd_en_i          (rd_l1d_en_i[0]            ),
        .rd_addr_i        (rd_l1d_addr_i[0]          ),
        .rd_wr_conflict_o (way_data_rw_conflict_o[0] ),
        .rd_word_o        (rd_l1d_word_o[0]          ),
        .rd_half_data_o   (rd_l1d_halfdata_o[0]      )
    );

    way_data_ram 
    #(
        .AWT                (AWT                ),
        .WORD_SEL           (WORD_SEL           ),
        .ENTRY_SEL          (ENTRY_SEL          ),
        .HALF_LINE_DWT      (HALF_LINE_DWT      ),
        .LSU_DC_DWT         (LSU_DC_DWT         ),
        .LSU_DC_SWT         (LSU_DC_SWT         )
    )
    way1_data(
        .clk_i            (clk_i                     ),
        .rst_i            (rst_i                     ),
        .wr_en_i          (wr_l1d_en_i[1]            ),
        .wr_half_en_i     (wr_l1d_half_en_i[1]       ),
        .wr_addr_i        (wr_l1d_addr_i[1]          ),
        .wr_data_strobe_i (wr_l1d_data_strobe_i[1]   ),
        .wr_data_i        (wr_l1d_data_i[1]          ),
        .rd_en_i          (rd_l1d_en_i[1]            ),
        .rd_addr_i        (rd_l1d_addr_i[1]          ),
        .rd_wr_conflict_o (way_data_rw_conflict_o[1] ),
        .rd_word_o        (rd_l1d_word_o[1]          ),
        .rd_half_data_o   (rd_l1d_halfdata_o[1]      )
    );

    vc_data_ram 
    #(
        .LINE_DWT    (LINE_DWT    ),
        .WORD_SEL    (WORD_SEL    ),
        .VC_WAYS_EXP (VC_WAYS_EXP ),
        .VC_WAYS     (VC_WAYS     ),
        .LSU_DC_DWT  (LSU_DC_DWT  ),
        .LSU_DC_SWT  (LSU_DC_SWT  )
    )
    vc_data(
        .clk_i            (clk_i               ),
        .rst_i            (rst_i               ),
        .wr_en_i          (wr_vc_en_i          ),
        .wr_way_i         (wr_vc_way_i         ),
        .wr_word_en_i     (wr_vc_word_en_i     ),
        .wr_line_en_i     (wr_vc_line_en_i     ),
        .wr_data_strobe_i (wr_vc_data_strobe_i ),
        .wr_data_i        (wr_vc_data_i        ),
        .rd_en_i          (rd_vc_en_i          ),
        .rd_way_i         (rd_vc_way_i         ),
        .rd_word_en_i     (rd_vc_word_en_i     ),
        .rd_word_o        (rd_vc_word_o        )
    );
    
endmodule
