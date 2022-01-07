//*********************************************************************************
//Project Name : HiPU200_Dcache
//Create Time  : 2020/06/01 21:55
//File Name    : dcache_top.sv
//Module Name  : dcache_top
//Abstract     : the top module of dcache
//*********************************************************************************
//Modification History:
//Time          By              Version                 Change Description
//-----------------------------------------------------------------------
//2010/06/01    Zongpc           3.0                    Change Coding Style
//21:55
//*********************************************************************************

`timescale      1ns/1ps

`include "hpu_head.sv"

import hpu_pkg::*;

module dcache_top #(
    //**********************Composition of addr*************************
    //       _______________________32bits_______________________
    //      |____________________________________________________|
    //      |________tag__________|_Cacheline_index__|____Byte___|
    //      |31|30|......|15|14|13|12|11|......|8|7|6|5|4|3|2|1|0|
    //      |_______19bits________|______7bits_______|_______|___|
    //                                                      one word(4B)
    parameter   AWT           = 32,       //the addr_width from LSU to dc
    parameter   WORD_SEL      = 4,   //4b to choose 1 word(4B) in the cacheline(64B),addr[5:2]
    parameter   ENTRY_SEL     = 7,  //7b to choose 1 cacheline(64B) in way(64Bx128),addr[12:6]
    parameter   ENTRY_NUM     = 2**ENTRY_SEL,
    parameter   TAG_WT        = AWT - ENTRY_SEL - WORD_SEL - 2,    //The data is Word aligned, the last 2b of ADDR can be ignored
    parameter   TAG_WT_VC     = AWT - WORD_SEL - 2,    //The data is Word aligned, the last 2b of ADDR can be ignored

    //**********************Parameter of CacheLine*************************
    parameter   LINE_DWT      = 64*8,             //64B
    parameter   HALF_LINE_DWT = LINE_DWT/2,   //32B,to fit the transmission between dc and L2

    //**********************Parameter of DataInterface*************************
    parameter   LSU_DC_DWT    = 4*8,           //4B
    parameter   LSU_DC_SWT    = 4,
    parameter   DC_L2_DWT     = LSU_DC_DWT,
    parameter   L2_DC_DWT     = HALF_LINE_DWT,
    parameter   L2_L1_DWT     = HALF_LINE_DWT,//limited by the width of ram 64bit*4
    parameter   L1_L2_DWT     = LSU_DC_DWT,//limited by the width of ram 64bit*4

    //**********************Parameter of cache ways*************************
    parameter   L1_WAYS       = 2,
    parameter   VC_WAYS_EXP   = 2,
    parameter   VC_WAYS       = 2**VC_WAYS_EXP, //victim cache has 2**2 = 4 ways

    //**********************Parameter of LRU*************************
    parameter   L1_LRU_WT     = 1,
    parameter   VC_LRU_WT     = 3,

    //**********************CSR self define parameters*************************
    parameter   CSR_DWT       = 32
)(
    input                           clk_i,
    input                           rst_i,

    //the req from cpu
    input                           lsu_dc__dcache_nonblk_wr_en_i,
    input  [AWT-1:0]                lsu_dc__dcache_waddr_i,
    input                           lsu_dc__dcache_nonblk_rd_en_i,
    input  [AWT-1:0]                lsu_dc__dcache_raddr_i,
    input  [LSU_DC_DWT-1:0]         lsu_dc__dcache_wdata_i,
    input  [LSU_DC_SWT-1:0]         lsu_dc__dcache_wdata_strobe_i,
    
    //the rsp to cpu
    output                          dc_lsu__dcache_rd_suc_o,
    output                          dc_lsu__dcache_wr_suc_o,
    output [LSU_DC_DWT-1:0]         dc_lsu__dcache_rdata_o,
    
    //the rsp from L2
    input                           l2_l1d__suc_act_i,
    input                           l2_l1d__suc_i,
    input                           l2_l1d__rdata_act_i,
    input  [L2_L1_DWT-1:0]          l2_l1d__rdata_i,
    
    //the req to L2
    output                          l1d_l2__wr_en_o,
    output                          l1d_l2__rd_en_o,
    output [AWT-1:0]                l1d_l2__addr_o,
    output                          l1d_l2__wdata_act_o,
    output [L1_L2_DWT-1:0]          l1d_l2__wdata_o,
    output [LSU_DC_SWT-1:0]         l1d_l2__wdata_strobe_o,
    
    input csr_bus_req_t             csr_dc__bus_req,
    output csr_bus_rsp_t            dc_csr__bus_rsp,
    output                          csr_finish_o
);
    //the interface with way_tag_ram
    wire                            rd_l1d_rdtag_en;
    wire  [AWT-1:0]                 rd_l1d_rdtag_addr;
    wire  [L1_WAYS-1:0]             hit_rd_l1d;

    wire                            rd_l1d_wrtag_en;
    wire  [AWT-1:0]                 rd_l1d_wrtag_addr;
    wire  [L1_WAYS-1:0]             hit_wr_l1d;

    wire  [L1_WAYS-1:0]             wr_l1d_tag_en;
    wire  [L1_WAYS-1:0]             rpl_disable;
    wire  [TAG_WT_VC-1:0]           rd_l1d_rdtag[L1_WAYS-1:0];
    wire  [L1_WAYS-1:0]             valid_rd_l1d;

    //the interface with vc_tag_ram
    wire                            rd_vc_rdtag_en;
    wire  [TAG_WT_VC-1:0]           rd_vc_rdtag;
    wire                            hit_rd_vc;
    wire  [VC_WAYS_EXP-1:0]         hit_rd_vc_way;

    wire                            rd_vc_wrtag_en;
    wire  [TAG_WT_VC-1:0]           rd_vc_wrtag;
    wire                            hit_wr_vc;
    wire  [VC_WAYS_EXP-1:0]         hit_wr_vc_way;

    wire  [VC_WAYS-1:0]             victim_valid;

    wire                            wr_vc_tag_en;
//    wire  [VC_WAYS_EXP-1:0]         wr_vc_tag_way;
    wire  [TAG_WT_VC-1:0]           wr_vc_tag;

    //the interface with way_data_ram
    wire  [L1_WAYS-1:0]             wr_l1d_en;
    wire  [1:0]                     wr_l1d_half_en[L1_WAYS-1:0]; //2'10 low part;2'b11 high part;2'b00 No half mode
    wire  [LSU_DC_SWT-1:0]          wr_l1d_data_strobe[L1_WAYS-1:0];
    wire  [AWT-1:0]                 wr_l1d_addr[L1_WAYS-1:0];
    wire  [HALF_LINE_DWT-1:0]       wr_l1d_data[L1_WAYS-1:0];

    wire  [L1_WAYS-1:0]             rd_l1d_en;
    wire  [1:0]                     rd_l1d_half_en[L1_WAYS-1:0];
    wire  [AWT-1:0]                 rd_l1d_addr[L1_WAYS-1:0];
    wire  [LSU_DC_DWT-1:0]          rd_l1d_word[L1_WAYS-1:0];
    wire  [HALF_LINE_DWT-1:0]       rd_l1d_halfdata[L1_WAYS-1:0];
    wire  [L1_WAYS-1:0]             way_data_rw_conflict;

    wire  [L1_WAYS-1:0]             clear_l1d_way;
    wire  [L1_WAYS-1:0]             clear_l1d_line;
    wire  [AWT-1:0]                 clear_l1d_addr[L1_WAYS-1:0];

    //the interface with vc_data_ram
    wire                            wr_vc_en;
    wire  [VC_WAYS_EXP-1:0]         wr_vc_way;
    wire  [WORD_SEL-1:0]            wr_vc_word_en;
    wire                            wr_vc_line_en;
    wire  [LSU_DC_SWT-1:0]          wr_vc_data_strobe;
    wire  [LINE_DWT-1:0]            wr_vc_data;

    wire                            rd_vc_en;
    wire  [VC_WAYS_EXP-1:0]         rd_vc_way;
    wire  [WORD_SEL-1:0]            rd_vc_word_en;
    wire  [LSU_DC_DWT-1:0]          rd_vc_word;

    //some csr sigs to ram
    wire                            clear_vc_all;
    wire                            clear_vc_line;
    wire  [VC_WAYS_EXP-1:0]         clear_vc_way;

    dcache_ctrl 
    #(
        .AWT           (AWT           ),
        .WORD_SEL      (WORD_SEL      ),
        .ENTRY_SEL     (ENTRY_SEL     ),
        .TAG_WT        (TAG_WT        ),
        .TAG_WT_VC     (TAG_WT_VC     ),
        .LSU_DC_DWT    (LSU_DC_DWT    ),
        .LINE_DWT      (LINE_DWT      ),
        .HALF_LINE_DWT (HALF_LINE_DWT ),
        .L2_L1_DWT     (L2_L1_DWT     ),
        .L1_L2_DWT     (L1_L2_DWT     ),
        .L1_WAYS       (L1_WAYS       ),
        .VC_WAYS_EXP   (VC_WAYS_EXP   ),
        .VC_WAYS       (VC_WAYS       ),
        .CSR_DWT       (CSR_DWT       ),
        .LSU_DC_SWT    (LSU_DC_SWT    ),
        .L1_LRU_WT     (L1_LRU_WT     ),
        .VC_LRU_WT     (VC_LRU_WT     )
    )
    u_dcache_ctrl(
    	.clk_i                         (clk_i                         ),
        .rst_i                         (rst_i                         ),
        .lsu_dc__dcache_nonblk_wr_en_i (lsu_dc__dcache_nonblk_wr_en_i ),
        .lsu_dc__dcache_waddr_i        (lsu_dc__dcache_waddr_i        ),
        .lsu_dc__dcache_nonblk_rd_en_i (lsu_dc__dcache_nonblk_rd_en_i ),
        .lsu_dc__dcache_raddr_i        (lsu_dc__dcache_raddr_i        ),
        .lsu_dc__dcache_wdata_i        (lsu_dc__dcache_wdata_i        ),
        .lsu_dc__dcache_wdata_strobe_i (lsu_dc__dcache_wdata_strobe_i ),
        .dc_lsu__dcache_rd_suc_o       (dc_lsu__dcache_rd_suc_o       ),
        .dc_lsu__dcache_wr_suc_o       (dc_lsu__dcache_wr_suc_o       ),
        .dc_lsu__dcache_rdata_o        (dc_lsu__dcache_rdata_o        ),
        .l1d_l2__wr_en_o               (l1d_l2__wr_en_o               ),
        .l1d_l2__rd_en_o               (l1d_l2__rd_en_o               ),
        .l1d_l2__addr_o                (l1d_l2__addr_o                ),
        .l1d_l2__wdata_act_o           (l1d_l2__wdata_act_o           ),
        .l1d_l2__wdata_o               (l1d_l2__wdata_o               ),
        .l1d_l2__wdata_strobe_o        (l1d_l2__wdata_strobe_o        ),
        .l2_l1d__suc_act_i             (l2_l1d__suc_act_i             ),
        .l2_l1d__suc_i                 (l2_l1d__suc_i                 ),
        .l2_l1d__rdata_act_i           (l2_l1d__rdata_act_i           ),
        .l2_l1d__rdata_i               (l2_l1d__rdata_i               ),
        .csr_dc__bus_req               (csr_dc__bus_req               ),
        .dc_csr__bus_rsp               (dc_csr__bus_rsp               ),
        .csr_finish_o                  (csr_finish_o                  ),
        .rd_l1d_rdtag_en_o             (rd_l1d_rdtag_en               ),
        .rd_l1d_rdtag_addr_o           (rd_l1d_rdtag_addr             ),
        .hit_rd_l1d_i                  (hit_rd_l1d                    ),
        .rd_l1d_wrtag_en_o             (rd_l1d_wrtag_en               ),
        .rd_l1d_wrtag_addr_o           (rd_l1d_wrtag_addr             ),
        .hit_wr_l1d_i                  (hit_wr_l1d                    ),
        .wr_l1d_tag_en_o               (wr_l1d_tag_en                 ),
        .rd_l1d_rdtag_i                (rd_l1d_rdtag                  ),
        .valid_rd_l1d_i                (valid_rd_l1d                  ),
        .rpl_disable_o                 (rpl_disable                   ),
        .rd_vc_rdtag_en_o              (rd_vc_rdtag_en                ),
        .rd_vc_rdtag_o                 (rd_vc_rdtag                   ),
        .hit_rd_vc_i                   (hit_rd_vc                     ),
        .hit_rd_vc_way_i               (hit_rd_vc_way                 ),
        .rd_vc_wrtag_en_o              (rd_vc_wrtag_en                ),
        .rd_vc_wrtag_o                 (rd_vc_wrtag                   ),
        .hit_wr_vc_i                   (hit_wr_vc                     ),
        .hit_wr_vc_way_i               (hit_wr_vc_way                 ),
        .victim_valid_i                (victim_valid                  ),
        .wr_vc_tag_en_o                (wr_vc_tag_en                  ),
        .wr_vc_tag_o                   (wr_vc_tag                     ),
        .wr_l1d_en_o                   (wr_l1d_en                     ),
        .wr_l1d_half_en_o              (wr_l1d_half_en                ),
        .wr_l1d_data_strobe_o          (wr_l1d_data_strobe            ),
        .wr_l1d_addr_o                 (wr_l1d_addr                   ),
        .wr_l1d_data_o                 (wr_l1d_data                   ),
        .rd_l1d_en_o                   (rd_l1d_en                     ),
        .rd_l1d_half_en_o              (rd_l1d_half_en                ),
        .rd_l1d_addr_o                 (rd_l1d_addr                   ),
        .rd_l1d_word_i                 (rd_l1d_word                   ),
        .rd_l1d_halfdata_i             (rd_l1d_halfdata               ),
        .way_data_rw_conflict_i        (way_data_rw_conflict          ),
        .clear_l1d_way_o               (clear_l1d_way                 ),
        .clear_l1d_line_o              (clear_l1d_line                ),
        .clear_l1d_addr_o              (clear_l1d_addr                ),
        .wr_vc_en_o                    (wr_vc_en                      ),
        .wr_vc_way_o                   (wr_vc_way                     ),
        .wr_vc_word_en_o               (wr_vc_word_en                 ),
        .wr_vc_line_en_o               (wr_vc_line_en                 ),
        .wr_vc_data_strobe_o           (wr_vc_data_strobe             ),
        .wr_vc_data_o                  (wr_vc_data                    ),
        .rd_vc_en_o                    (rd_vc_en                      ),
        .rd_vc_way_o                   (rd_vc_way                     ),
        .rd_vc_word_en_o               (rd_vc_word_en                 ),
        .rd_vc_word_i                  (rd_vc_word                    ),
        .clear_vc_all_o                (clear_vc_all                  ),
        .clear_vc_line_o               (clear_vc_line                 ),
        .clear_vc_way_o                (clear_vc_way                  )
    );
    

    dcache_ram 
    #(
        .AWT           (AWT           ),
        .WORD_SEL      (WORD_SEL      ),
        .ENTRY_SEL     (ENTRY_SEL     ),
        .ENTRY_NUM     (ENTRY_NUM     ),
        .TAG_WT        (TAG_WT        ),
        .TAG_WT_VC     (TAG_WT_VC     ),
        .L1_WAYS       (L1_WAYS       ),
        .VC_WAYS_EXP   (VC_WAYS_EXP   ),
        .VC_WAYS       (VC_WAYS       ),
        .LINE_DWT      (LINE_DWT      ),
        .HALF_LINE_DWT (HALF_LINE_DWT ),
        .LSU_DC_DWT    (LSU_DC_DWT    ),
        .LSU_DC_SWT    (LSU_DC_SWT    )
    )
    u_dcache_ram(
        .clk_i                  (clk_i                  ),
        .rst_i                  (rst_i                  ),
        .rd_l1d_rdtag_en_i      (rd_l1d_rdtag_en        ),
        .rd_l1d_rdtag_addr_i    (rd_l1d_rdtag_addr      ),
        .hit_rd_l1d_o           (hit_rd_l1d             ),
        .rd_l1d_wrtag_en_i      (rd_l1d_wrtag_en        ),
        .rd_l1d_wrtag_addr_i    (rd_l1d_wrtag_addr      ),
        .hit_wr_l1d_o           (hit_wr_l1d             ),
        .wr_l1d_tag_en_i        (wr_l1d_tag_en          ),
        .rd_l1d_rdtag_o         (rd_l1d_rdtag           ),
        .valid_rd_l1d_o         (valid_rd_l1d           ),
        .rpl_disable_i          (rpl_disable            ),
        .rd_vc_rdtag_en_i       (rd_vc_rdtag_en         ),
        .rd_vc_rdtag_i          (rd_vc_rdtag            ),
        .hit_rd_vc_o            (hit_rd_vc              ),
        .hit_rd_vc_way_o        (hit_rd_vc_way          ),
        .rd_vc_wrtag_en_i       (rd_vc_wrtag_en         ),
        .rd_vc_wrtag_i          (rd_vc_wrtag            ),
        .hit_wr_vc_o            (hit_wr_vc              ),
        .hit_wr_vc_way_o        (hit_wr_vc_way          ),
        .victim_valid_o         (victim_valid           ),
        .wr_vc_tag_en_i         (wr_vc_tag_en           ),
        .wr_vc_tag_i            (wr_vc_tag              ),
        .wr_l1d_en_i            (wr_l1d_en              ),
        .wr_l1d_half_en_i       (wr_l1d_half_en         ),
        .wr_l1d_data_strobe_i   (wr_l1d_data_strobe     ),
        .wr_l1d_addr_i          (wr_l1d_addr            ),
        .wr_l1d_data_i          (wr_l1d_data            ),
        .rd_l1d_en_i            (rd_l1d_en              ),
        .rd_l1d_half_en_i       (rd_l1d_half_en         ),
        .rd_l1d_addr_i          (rd_l1d_addr            ),
        .rd_l1d_word_o          (rd_l1d_word            ),
        .rd_l1d_halfdata_o      (rd_l1d_halfdata        ),
        .way_data_rw_conflict_o (way_data_rw_conflict   ),
        .clear_l1d_way_i        (clear_l1d_way          ),
        .clear_l1d_line_i       (clear_l1d_line         ),
        .clear_l1d_addr_i       (clear_l1d_addr         ),
        .wr_vc_en_i             (wr_vc_en               ),
        .wr_vc_way_i            (wr_vc_way              ),
        .wr_vc_word_en_i        (wr_vc_word_en          ),
        .wr_vc_line_en_i        (wr_vc_line_en          ),
        .wr_vc_data_strobe_i    (wr_vc_data_strobe      ),
        .wr_vc_data_i           (wr_vc_data             ),
        .rd_vc_en_i             (rd_vc_en               ),
        .rd_vc_way_i            (rd_vc_way              ),
        .rd_vc_word_en_i        (rd_vc_word_en          ),
        .rd_vc_word_o           (rd_vc_word             ),
        .clear_vc_all_i         (clear_vc_all           ),
        .clear_vc_line_i        (clear_vc_line          ),
        .clear_vc_way_i         (clear_vc_way           )
    );

endmodule
