//*********************************************************************************
//Project Name : HiPU200_Dcache
//Create Time  : 2020/06/09 10:48
//File Name    : dcache_ctrl.sv
//Module Name  : dcache_ctrl
//Abstract     : ctrl module integrated with fsms and LRU
//*********************************************************************************
//Modification History:
//Time          By              Version                 Change Description
//-----------------------------------------------------------------------
//2010/06/09    Zongpc           3.0                    Change Coding Style
//10:48
//*********************************************************************************

`timescale      1ns/1ps

`include "hpu_head.sv"

import hpu_pkg::*;

module dcache_ctrl
#(
    parameter   AWT           = 32,
    parameter   WORD_SEL      = 4,//4 Bytes per word, the last two bits of ADDR from CPU can be ignored
    parameter   ENTRY_SEL     = 7,
    parameter   TAG_WT        = AWT-ENTRY_SEL-WORD_SEL-2,
    parameter   TAG_WT_VC     = AWT - WORD_SEL - 2,
    parameter   LSU_DC_DWT    = 4*8,
    parameter   LINE_DWT      = 64*8,
    parameter   HALF_LINE_DWT = 32*8,
    parameter   L2_L1_DWT     = HALF_LINE_DWT,//limited by the width of ram 64bit*4
    parameter   L1_L2_DWT     = LSU_DC_DWT,//limited by the width of ram 64bit*4
    parameter   L1_WAYS       = 2,
    parameter   VC_WAYS_EXP   = 2,
    parameter   VC_WAYS       = 2**VC_WAYS_EXP, //victim cache has 2**2 = 4 ways
    parameter   CSR_DWT       = 32,
    parameter   LSU_DC_SWT    = 4,
    parameter   L1_LRU_WT     = 1,
    parameter   VC_LRU_WT     = 3
)(
    input                           clk_i,
    input                           rst_i,

    //the req from cpu
    input                           lsu_dc__dcache_nonblk_wr_en_i,
    input [AWT-1:0]                 lsu_dc__dcache_waddr_i,
    input                           lsu_dc__dcache_nonblk_rd_en_i,
    input [AWT-1:0]                 lsu_dc__dcache_raddr_i,
    input [LSU_DC_DWT-1:0]          lsu_dc__dcache_wdata_i,
    input [LSU_DC_SWT-1:0]          lsu_dc__dcache_wdata_strobe_i,

    //the rsp to cpu
    output                          dc_lsu__dcache_rd_suc_o,
    output                          dc_lsu__dcache_wr_suc_o,
    output [LSU_DC_DWT-1:0]         dc_lsu__dcache_rdata_o,

    //the req to L2
    output                          l1d_l2__wr_en_o,
    output                          l1d_l2__rd_en_o,
    output [AWT-1:0]                l1d_l2__addr_o,
    output                          l1d_l2__wdata_act_o,
    output [L1_L2_DWT-1:0]          l1d_l2__wdata_o,
    output [LSU_DC_SWT-1:0]         l1d_l2__wdata_strobe_o,

    //the data_rsp from L2
    input                           l2_l1d__suc_act_i,
    input                           l2_l1d__suc_i,
    input                           l2_l1d__rdata_act_i,
    input [L2_L1_DWT-1:0]           l2_l1d__rdata_i,

    //the interface with csr
    input  csr_bus_req_t            csr_dc__bus_req,
    output csr_bus_rsp_t            dc_csr__bus_rsp,
    output                          csr_finish_o,

    //the interface with way_tag_ram
    output                          rd_l1d_rdtag_en_o,
    output [AWT-1:0]                rd_l1d_rdtag_addr_o,
    input  [L1_WAYS-1:0]            hit_rd_l1d_i,

    output                          rd_l1d_wrtag_en_o,
    output [AWT-1:0]                rd_l1d_wrtag_addr_o,
    input  [L1_WAYS-1:0]            hit_wr_l1d_i,

    output[L1_WAYS-1:0]             wr_l1d_tag_en_o,
    input [TAG_WT_VC-1:0]           rd_l1d_rdtag_i[L1_WAYS-1:0],
    input [L1_WAYS-1:0]             valid_rd_l1d_i,

    output[L1_WAYS-1:0]             rpl_disable_o,

    //the interface with vc_tag_ram
    output                          rd_vc_rdtag_en_o,
    output [TAG_WT_VC-1:0]          rd_vc_rdtag_o,
    input                           hit_rd_vc_i,
    input  [VC_WAYS_EXP-1:0]        hit_rd_vc_way_i,

    output                          rd_vc_wrtag_en_o,
    output [TAG_WT_VC-1:0]          rd_vc_wrtag_o,
    input                           hit_wr_vc_i,
    input  [VC_WAYS_EXP-1:0]        hit_wr_vc_way_i,

    input  [VC_WAYS-1:0]            victim_valid_i,

    output                          wr_vc_tag_en_o,
    //output [VC_WAYS_EXP-1:0]        wr_vc_tag_way_o,
    output [TAG_WT_VC-1:0]          wr_vc_tag_o,

    //the interface with way_data_ram
    output [L1_WAYS-1:0]            wr_l1d_en_o,
    output [1:0]                    wr_l1d_half_en_o[L1_WAYS-1:0], //2'10 low part;2'b11 high part;2'b00 No half mode
    output [LSU_DC_SWT-1:0]         wr_l1d_data_strobe_o[L1_WAYS-1:0],
    output [AWT-1:0]                wr_l1d_addr_o[L1_WAYS-1:0],
    output [HALF_LINE_DWT-1:0]      wr_l1d_data_o[L1_WAYS-1:0],

    output [L1_WAYS-1:0]            rd_l1d_en_o,
    output [1:0]                    rd_l1d_half_en_o[L1_WAYS-1:0],
    output [AWT-1:0]                rd_l1d_addr_o[L1_WAYS-1:0],
    input  [LSU_DC_DWT-1:0]         rd_l1d_word_i[L1_WAYS-1:0],
    input [HALF_LINE_DWT-1:0]       rd_l1d_halfdata_i[L1_WAYS-1:0],
    input  [L1_WAYS-1:0]            way_data_rw_conflict_i,

    output [L1_WAYS-1:0]            clear_l1d_way_o,
    output [L1_WAYS-1:0]            clear_l1d_line_o,
    output [AWT-1:0]                clear_l1d_addr_o[L1_WAYS-1:0],

    //the interface with vc_data_ram
    output                          wr_vc_en_o,
    output [VC_WAYS_EXP-1:0]        wr_vc_way_o,
    output [WORD_SEL-1:0]           wr_vc_word_en_o,
    output                          wr_vc_line_en_o,
    output [LSU_DC_SWT-1:0]         wr_vc_data_strobe_o,
    output [LINE_DWT-1:0]           wr_vc_data_o,

    output                          rd_vc_en_o,
    output [VC_WAYS_EXP-1:0]        rd_vc_way_o,
    output [WORD_SEL-1:0]           rd_vc_word_en_o,
    input  [LSU_DC_DWT-1:0]         rd_vc_word_i,

    //some csr sigs to ram
    output                          clear_vc_all_o,
    output                          clear_vc_line_o,
    output [VC_WAYS_EXP-1:0]        clear_vc_way_o
);
    //some signals with sub_fsm
    wire [2:0]                     Current_ST2;
    wire                           l2_l1d__wr_suc_act;
    wire                           l2_l1d__wr_suc;
    wire                           l1d_l2__rd_en_pre;
    wire [L1_WAYS-1:0]             ways_occupied_rcd;
    wire [AWT-1:0]                 l1d_l2__rd_addr_o_rcd;
    wire [HALF_LINE_DWT-1:0]       rd_l1d_low_half_rcd;
    wire [HALF_LINE_DWT-1:0]       rd_l1d_high_half_rcd;
    wire                           rd_l1d_busy;
    wire                           wr_l1d_busy;
    wire                           wr_vc_busy;
    wire                           rpl_ready;
    wire [L1_WAYS-1:0]             rpl_l1d_way_rcd;
    wire                           lsu_dc__dcache_nonblk_rd_en_accept;
    wire                           lsu_dc__dcache_nonblk_wr_en_accept;

    //the specific-interface with LRU
    wire [L1_WAYS-1:0]            hot_l1d_onehot;
    wire [VC_WAYS_EXP-1:0]        hot_vc_exp;
    wire [ENTRY_SEL-1:0]          hit_rd_l1d_entry;
    wire [ENTRY_SEL-1:0]          hit_wr_l1d_entry;

    wire [ENTRY_SEL-1:0]          rpl_l1d_entry;

    dcache_main_fsm 
    #(
        .AWT              (AWT              ),
        .WORD_SEL         (WORD_SEL         ),
        .ENTRY_SEL        (ENTRY_SEL        ),
        .TAG_WT           (TAG_WT           ),
        .TAG_WT_VC        (TAG_WT_VC        ),
        .LSU_DC_DWT       (LSU_DC_DWT       ),
        .LINE_DWT         (LINE_DWT         ),
        .HALF_LINE_DWT    (HALF_LINE_DWT    ),
        .L2_L1_DWT        (L2_L1_DWT        ),
        .L1_WAYS          (L1_WAYS          ),
        .VC_WAYS_EXP      (VC_WAYS_EXP      ),
        .VC_WAYS          (VC_WAYS          ),
        .CSR_DWT          (CSR_DWT          ),
        .LSU_DC_SWT       (LSU_DC_SWT       )
    )
    dcache_main_fsm_inst(
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
        .l2_l1d__rdata_act_i           (l2_l1d__rdata_act_i           ),
        .l2_l1d__rdata_i               (l2_l1d__rdata_i               ),
        .csr_dc__bus_req               (csr_dc__bus_req               ),
        .dc_csr__bus_rsp               (dc_csr__bus_rsp               ),
        .csr_finish_o                  (csr_finish_o                  ),
        .Current_ST2_i                 (Current_ST2                   ),
        .l2_l1d__wr_suc_act_i          (l2_l1d__wr_suc_act            ),
        .l2_l1d__wr_suc_i              (l2_l1d__wr_suc                ),
        .l1d_l2__rd_en_pre_i           (l1d_l2__rd_en_pre             ),
        .ways_occupied_rcd_i           (ways_occupied_rcd             ),
        .rpl_l1d_way_rcd_i             (rpl_l1d_way_rcd               ),
        .l1d_l2__rd_addr_o_rcd_i       (l1d_l2__rd_addr_o_rcd         ),
        .rd_l1d_low_half_rcd_i         (rd_l1d_low_half_rcd           ),
        .rd_l1d_high_half_rcd_i        (rd_l1d_high_half_rcd          ),
        .rd_l1d_busy_i                 (rd_l1d_busy                   ),
        .wr_l1d_busy_i                 (wr_l1d_busy                   ),
        .wr_vc_busy_i                  (wr_vc_busy                    ),
        .rpl_ready_i                   (rpl_ready                     ),
        .lsu_dc__dcache_nonblk_rd_en_accept_o(lsu_dc__dcache_nonblk_rd_en_accept),
        .lsu_dc__dcache_nonblk_wr_en_accept_o(lsu_dc__dcache_nonblk_wr_en_accept),
        .rd_l1d_rdtag_en_o             (rd_l1d_rdtag_en_o             ),
        .rd_l1d_rdtag_addr_o           (rd_l1d_rdtag_addr_o           ),
        .hit_rd_l1d_i                  (hit_rd_l1d_i                  ),
        .rd_l1d_wrtag_en_o             (rd_l1d_wrtag_en_o             ),
        .rd_l1d_wrtag_addr_o           (rd_l1d_wrtag_addr_o           ),
        .hit_wr_l1d_i                  (hit_wr_l1d_i                  ),
        .rd_vc_rdtag_en_o              (rd_vc_rdtag_en_o              ),
        .rd_vc_rdtag_o                 (rd_vc_rdtag_o                 ),
        .hit_rd_vc_i                   (hit_rd_vc_i                   ),
        .hit_rd_vc_way_i               (hit_rd_vc_way_i               ),
        .rd_vc_wrtag_en_o              (rd_vc_wrtag_en_o              ),
        .rd_vc_wrtag_o                 (rd_vc_wrtag_o                 ),
        .hit_wr_vc_i                   (hit_wr_vc_i                   ),
        .hit_wr_vc_way_i               (hit_wr_vc_way_i               ),
        .victim_valid_i                (victim_valid_i                ),
        .hot_l1d_onehot_i              (hot_l1d_onehot                ),
        .hot_vc_exp_i                  (hot_vc_exp                    ),
        .hit_rd_l1d_entry_o            (hit_rd_l1d_entry              ),
        .hit_wr_l1d_entry_o            (hit_wr_l1d_entry              ),
        .wr_l1d_en_o                   (wr_l1d_en_o                   ),
        .wr_l1d_half_en_o              (wr_l1d_half_en_o              ),
        .wr_l1d_data_strobe_o          (wr_l1d_data_strobe_o          ),
        .wr_l1d_addr_o                 (wr_l1d_addr_o                 ),
        .wr_l1d_data_o                 (wr_l1d_data_o                 ),
        .rd_l1d_en_o                   (rd_l1d_en_o                   ),
        .rd_l1d_half_en_o              (rd_l1d_half_en_o              ),
        .rd_l1d_addr_o                 (rd_l1d_addr_o                 ),
        .rd_l1d_word_i                 (rd_l1d_word_i                 ),
        .way_data_rw_conflict_i        (way_data_rw_conflict_i        ),
        .clear_l1d_way_o               (clear_l1d_way_o               ),
        .clear_l1d_line_o              (clear_l1d_line_o              ),
        .clear_l1d_addr_o              (clear_l1d_addr_o              ),
        .wr_vc_en_o                    (wr_vc_en_o                    ),
        .wr_vc_way_o                   (wr_vc_way_o                   ),
        .wr_vc_word_en_o               (wr_vc_word_en_o               ),
        .wr_vc_line_en_o               (wr_vc_line_en_o               ),
        .wr_vc_data_strobe_o           (wr_vc_data_strobe_o           ),
        .wr_vc_data_o                  (wr_vc_data_o                  ),
        .rd_vc_en_o                    (rd_vc_en_o                    ),
        .rd_vc_way_o                   (rd_vc_way_o                   ),
        .rd_vc_word_en_o               (rd_vc_word_en_o               ),
        .rd_vc_word_i                  (rd_vc_word_i                  ),
        .clear_vc_all_o                (clear_vc_all_o                ),
        .clear_vc_line_o               (clear_vc_line_o               ),
        .clear_vc_way_o                (clear_vc_way_o                )
    );

    dcache_sub_fsm 
    #(
        .AWT              (AWT              ),
        .WORD_SEL         (WORD_SEL         ),
        .ENTRY_SEL        (ENTRY_SEL        ),
        .TAG_WT           (TAG_WT           ),
        .TAG_WT_VC        (TAG_WT_VC        ),
        .LSU_DC_DWT       (LSU_DC_DWT       ),
        .HALF_LINE_DWT    (HALF_LINE_DWT    ),
        .L1_L2_DWT        (L1_L2_DWT        ),
        .L1_WAYS          (L1_WAYS          ),
        .VC_WAYS_EXP      (VC_WAYS_EXP      ),
        .LSU_DC_SWT       (LSU_DC_SWT       )
    )
    dcache_sub_fsm_inst(
    	.clk_i                         (clk_i                         ),
        .rst_i                         (rst_i                         ),
        .lsu_dc__dcache_nonblk_wr_en_accept_i (lsu_dc__dcache_nonblk_wr_en_accept ),
        .lsu_dc__dcache_waddr_i        (lsu_dc__dcache_waddr_i        ),
        .lsu_dc__dcache_nonblk_rd_en_accept_i (lsu_dc__dcache_nonblk_rd_en_accept ),
        .lsu_dc__dcache_raddr_i        (lsu_dc__dcache_raddr_i        ),
        .lsu_dc__dcache_wdata_i        (lsu_dc__dcache_wdata_i        ),
        .lsu_dc__dcache_wdata_strobe_i (lsu_dc__dcache_wdata_strobe_i ),
        .dc_lsu__dcache_wr_suc_i       (dc_lsu__dcache_wr_suc_o       ),
        .l2_l1d__suc_act_i             (l2_l1d__suc_act_i             ),
        .l2_l1d__suc_i                 (l2_l1d__suc_i                 ),
        .l1d_l2__wr_en_o               (l1d_l2__wr_en_o               ),
        .l1d_l2__rd_en_o               (l1d_l2__rd_en_o               ),
        .l1d_l2__addr_o                (l1d_l2__addr_o                ),
        .l1d_l2__wdata_act_o           (l1d_l2__wdata_act_o           ),
        .l1d_l2__wdata_o               (l1d_l2__wdata_o               ),
        .l1d_l2__wdata_strobe_o        (l1d_l2__wdata_strobe_o        ),
        .rd_l1d_en_i                   (rd_l1d_en_o                   ),
        .wr_l1d_en_i                   (wr_l1d_en_o                   ),
        .wr_vc_way_i                   (wr_vc_way_o                   ),
        .Current_ST2_o                 (Current_ST2                   ),
        .l2_l1d__wr_suc_act_o          (l2_l1d__wr_suc_act            ),
        .l2_l1d__wr_suc_o              (l2_l1d__wr_suc                ),
        .l1d_l2__rd_en_pre_o           (l1d_l2__rd_en_pre             ),
        .ways_occupied_rcd_o           (ways_occupied_rcd             ),
        .rpl_l1d_way_rcd_o             (rpl_l1d_way_rcd               ),
        .l1d_l2__rd_addr_o_rcd_o       (l1d_l2__rd_addr_o_rcd         ),
        .rd_l1d_low_half_rcd_o         (rd_l1d_low_half_rcd           ),
        .rd_l1d_high_half_rcd_o        (rd_l1d_high_half_rcd          ),
        .rd_l1d_busy_o                 (rd_l1d_busy                   ),
        .wr_l1d_busy_o                 (wr_l1d_busy                   ),
        .wr_vc_busy_o                  (wr_vc_busy                    ),
        .rpl_ready_o                   (rpl_ready                     ),
        .hot_l1d_onehot_i              (hot_l1d_onehot                ),
        .rpl_l1d_entry_o               (rpl_l1d_entry                 ),
        .wr_l1d_tag_en_o               (wr_l1d_tag_en_o               ),
        .rd_l1d_rdtag_i                (rd_l1d_rdtag_i                ),
        .valid_rd_l1d_i                (valid_rd_l1d_i                ),
        .hit_rd_l1d_i                  (hit_rd_l1d_i                  ),
        .rpl_disable_o                 (rpl_disable_o                 ),
        .rd_l1d_halfdata_i             (rd_l1d_halfdata_i             ),
        .wr_vc_tag_en_o                (wr_vc_tag_en_o                ),
        .wr_vc_tag_o                   (wr_vc_tag_o                   ),
        .hit_rd_vc_i                   (hit_rd_vc_i                   )
    );

    dcache_LRU 
    #(
        .L1_LRU_WT   (L1_LRU_WT   ),
        .L1_WAYS     (L1_WAYS     ),
        .VC_LRU_WT   (VC_LRU_WT   ),
        .VC_WAYS_EXP (VC_WAYS_EXP ),
        .ENTRY_SEL   (ENTRY_SEL   )
    )
    dcache_LRU_inst(
    	.clk_i               (clk_i               ),
        .rst_i               (rst_i               ),
        .hit_rd_l1d_i        (hit_rd_l1d_i        ),
        .hit_rd_l1d_entry_i  (hit_rd_l1d_entry    ),
        .hit_wr_l1d_i        (hit_wr_l1d_i        ),
        .hit_wr_l1d_entry_i  (hit_wr_l1d_entry    ),
        .hit_rd_vc_i         (hit_rd_vc_i         ),
        .hit_rd_vc_way_i     (hit_rd_vc_way_i     ),
        .hit_wr_vc_i         (hit_wr_vc_i         ),
        .hit_wr_vc_way_i     (hit_wr_vc_way_i     ),
        .rpl_l1d_entry_i     (rpl_l1d_entry       ),
        .hot_l1d_onehot_o    (hot_l1d_onehot      ),
        .hot_vc_exp_o        (hot_vc_exp          )
    );
    
endmodule
    
