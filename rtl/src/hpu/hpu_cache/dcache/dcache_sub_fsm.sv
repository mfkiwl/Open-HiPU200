//*********************************************************************************
//Project Name : HiPU200_Dccache
//Create Time  : 2020/06/08 20:34
//File Name    : dcache_sub_fsm.sv
//Module Name  : dcache_sub_fsm
//Abstract     : sub_fsm of dcache
//*********************************************************************************
//Modification History:
//Time          By              Version                 Change Description
//-----------------------------------------------------------------------
//2010/06/08    Zongpc           3.0                    change coding style
//20:34
//*********************************************************************************

`timescale      1ns/1ps

`include "hpu_head.sv"

import hpu_pkg::*;

module dcache_sub_fsm
#(
    parameter    AWT           = 32,
    parameter    WORD_SEL      = 4,//4 Bytes per word, the last two bits of ADDR from CPU can be ignored
    parameter    ENTRY_SEL     = 7,
    parameter    TAG_WT        = AWT-ENTRY_SEL-WORD_SEL-2,
    parameter    TAG_WT_VC     = AWT-WORD_SEL-2,
    parameter    LSU_DC_DWT    = 4*8,
    parameter    HALF_LINE_DWT = 32*8,
    parameter    L1_L2_DWT     = 4*8,
    parameter    L1_WAYS       = 2,
    parameter    VC_WAYS_EXP   = 2,
    parameter    LSU_DC_SWT    = 4
)(
    input                           clk_i,
    input                           rst_i,

    //the req from cpu
    input                            lsu_dc__dcache_nonblk_wr_en_accept_i,
    input [AWT-1:0]                  lsu_dc__dcache_waddr_i,
    input                            lsu_dc__dcache_nonblk_rd_en_accept_i,
    input [AWT-1:0]                  lsu_dc__dcache_raddr_i,
    input [LSU_DC_DWT-1:0]           lsu_dc__dcache_wdata_i,
    input [LSU_DC_SWT-1:0]           lsu_dc__dcache_wdata_strobe_i,
    input                            dc_lsu__dcache_wr_suc_i,

    //the rsp from L2
    input                            l2_l1d__suc_act_i,
    input                            l2_l1d__suc_i,

    //the req to L2
    output reg                       l1d_l2__wr_en_o,
    output reg                       l1d_l2__rd_en_o,
    output reg [AWT-1:0]             l1d_l2__addr_o,
    output reg                       l1d_l2__wdata_act_o,
    output reg [L1_L2_DWT-1:0]       l1d_l2__wdata_o,
    output reg [LSU_DC_SWT-1:0]      l1d_l2__wdata_strobe_o,

    //the interface with main_fsm
    input [L1_WAYS-1:0]              rd_l1d_en_i,
    input [L1_WAYS-1:0]              wr_l1d_en_i,
    input [VC_WAYS_EXP-1:0]          wr_vc_way_i,
    output [2:0]                     Current_ST2_o,
    output reg                       l2_l1d__wr_suc_act_o,
    output reg                       l2_l1d__wr_suc_o,//gen by sub fsm to indicate the rsp from l2 is rd
    output                           l1d_l2__rd_en_pre_o,
    output reg [L1_WAYS-1:0]         ways_occupied_rcd_o,
    output reg [L1_WAYS-1:0]         rpl_l1d_way_rcd_o,
    output reg [AWT-1:0]             l1d_l2__rd_addr_o_rcd_o,
    output reg [HALF_LINE_DWT-1:0]   rd_l1d_low_half_rcd_o,
    output reg [HALF_LINE_DWT-1:0]   rd_l1d_high_half_rcd_o,
    output reg                       rd_l1d_busy_o,
    output reg                       wr_l1d_busy_o,
    output reg                       wr_vc_busy_o,
    output reg                       rpl_ready_o,

    //the signal go to the LRU module
    input  [L1_WAYS-1:0]             hot_l1d_onehot_i,//it represents the Inx of way which is the Least_Recent_Used
//    input  [VC_WAYS_EXP-1:0]         hot_vc_exp_i, //it represents the Inx of way which is the Least_Recent_Used
    output [ENTRY_SEL-1:0]           rpl_l1d_entry_o,

    //the interface with way_tag_ram
    output reg [L1_WAYS-1:0]         wr_l1d_tag_en_o,
    input  [TAG_WT_VC-1:0]           rd_l1d_rdtag_i[L1_WAYS-1:0],
    input  [L1_WAYS-1:0]             valid_rd_l1d_i,
    input  [L1_WAYS-1:0]             hit_rd_l1d_i,

    output [L1_WAYS-1:0]             rpl_disable_o,

    //the interface with way_data_ram
    input [HALF_LINE_DWT-1:0]        rd_l1d_halfdata_i[L1_WAYS-1:0],

    //the interface with vc_tag_ram
    output reg                       wr_vc_tag_en_o,
//    output reg [VC_WAYS_EXP-1:0]     wr_vc_tag_way_o,
    output reg [TAG_WT_VC-1:0]       wr_vc_tag_o,
    input                            hit_rd_vc_i
);

    localparam    ST2_IDLE         = 0;
    localparam    ST2_FETCH_L2_A   = 1;
    localparam    ST2_FETCH_L2_B   = 2;
    localparam    ST2_FETCH_L2_C   = 3;
    localparam    ST2_WRITE_L1D_A  = 4;
    localparam    ST2_WRITE_L1D_B  = 5;
    localparam    ST2_WAIT_NEW_RQS = 6;

    localparam    ST3_IDLE         = 0;
    localparam    ST3_WRITE_L2     = 1;

    localparam    DLY1_WT          = 2*AWT+L1_WAYS+6;

    reg  [2:0]                       Current_ST2;
    reg  [2:0]                       Next_ST2;

    reg                              Current_ST3;
    reg                              Next_ST3;

    //gen by sub fsm to indicate the rsp from l2 is rd 
    reg                              l2_l1d__rd_suc_act;
    reg                              l2_l1d__rd_suc;

    //record the tag of the way may be replaced when sub fsm start to work
    reg  [TAG_WT_VC-1:0]             l1d_replace_tag_rcd[L1_WAYS-1:0];

    //dly 1 cycle to make the req to l2, timing optimize
    reg                              l1d_l2__rd_en_pre;
    reg  [AWT-1:0]                   l1d_l2__addr_pre;

    reg                              l2_wr_block;

    wire                             l2_wr_buffer_conflict;

    wire                             lsu_dc__dcache_nonblk_rd_en_accept_i_dly1;
    wire [L1_WAYS-1:0]               rd_l1d_en_i_dly1;
    wire [AWT-1:0]                   lsu_dc__dcache_raddr_i_dly1;
    wire [AWT-1:0]                   lsu_dc__dcache_waddr_i_dly1;
    wire                             l1d_l2__wr_en_o_dly1;
    wire                             l2_l1d__wr_suc_act_dly1;
    wire                             l2_l1d__wr_suc_dly1;
    wire                             l1d_l2__rd_en_pre_dly1;
    wire                             dc_lsu__dcache_wr_suc_i_dly1;

    reg                              l1d_l2__wr_en_o_dly2;
    reg                              l1d_l2__rd_en_pre_dly2;

    wire [DLY1_WT-1:0]               data_dly1;
    reg  [DLY1_WT-1:0]               data_dly1_reg;

    integer                          i;


    /******************************************************Sub_FSM deal with load******************************************************/
    always @(posedge clk_i or `RST_DECL(rst_i)) begin : Sub_RD_FSM_a
        if(`RST_TRUE(rst_i)) begin
            Current_ST2 <= ST2_IDLE;
        end else begin
            Current_ST2 <= Next_ST2;
        end
    end

    always @(*) begin : Sub_RD_FSM_b
        case(Current_ST2)
            ST2_IDLE : begin
                if (l1d_l2__rd_en_pre) begin
                    Next_ST2 = ST2_FETCH_L2_A;
                end else begin
                    Next_ST2 = ST2_IDLE;
                end
            end
            ST2_FETCH_L2_A : begin
                Next_ST2 = ST2_FETCH_L2_B;
            end
            ST2_FETCH_L2_B : begin
                if (l2_l1d__rd_suc_act && l2_l1d__rd_suc) begin
                    Next_ST2 = ST2_FETCH_L2_C;
                end else begin
                    Next_ST2 = ST2_FETCH_L2_B;
                end
            end
            ST2_FETCH_L2_C : begin
                Next_ST2 = ST2_WRITE_L1D_A;
            end
            ST2_WRITE_L1D_A : begin
                Next_ST2 = ST2_WRITE_L1D_B;
            end
            ST2_WRITE_L1D_B : begin
                if(lsu_dc__dcache_nonblk_rd_en_accept_i&&(lsu_dc__dcache_raddr_i == l1d_l2__rd_addr_o_rcd_o)) begin
                    Next_ST2 = ST2_WAIT_NEW_RQS;
                end else begin
                    Next_ST2 = ST2_IDLE;
                end
            end
            ST2_WAIT_NEW_RQS : begin
                Next_ST2 = ST2_IDLE;
            end
            default : begin
                Next_ST2 = ST2_IDLE;
            end
        endcase
    end

    assign l2_wr_buffer_conflict = lsu_dc__dcache_nonblk_rd_en_accept_i_dly1 && lsu_dc__dcache_nonblk_wr_en_accept_i 
                                   && (lsu_dc__dcache_raddr_i_dly1[AWT-1:WORD_SEL+2] == lsu_dc__dcache_waddr_i[AWT-1:WORD_SEL+2]);

    always @(*) begin : Sub_RD_FSM_c
        case(Current_ST2)
            ST2_IDLE : begin
                //-----------signals between l1d and l2-----------
                l1d_l2__rd_en_pre  = (!((|hit_rd_l1d_i)||(hit_rd_vc_i))) && lsu_dc__dcache_nonblk_rd_en_accept_i_dly1 && (~l2_wr_buffer_conflict);
                l1d_l2__addr_pre   = l1d_l2__rd_en_pre ? lsu_dc__dcache_raddr_i_dly1 : lsu_dc__dcache_raddr_i;
                l1d_l2__rd_en_o    = 1'b0;
                l1d_l2__addr_o     = lsu_dc__dcache_waddr_i;
                l2_l1d__rd_suc_act = 1'b0;
                l2_l1d__rd_suc     = 1'b0;
                //-----------------busy signals--------------------
                rd_l1d_busy_o      = 1'b0;
                wr_l1d_busy_o      = (lsu_dc__dcache_raddr_i_dly1[ENTRY_SEL+WORD_SEL+1:WORD_SEL+2] ==
                                      lsu_dc__dcache_waddr_i_dly1[ENTRY_SEL+WORD_SEL+1:WORD_SEL+2]) &&  l1d_l2__rd_en_pre;
                wr_vc_busy_o       = 1'b0;
                l2_wr_block        = 1'b0;
                //---------------tag_ram signals-------------------
                wr_vc_tag_en_o     = 1'b0;
                //wr_vc_tag_way_o    = {VC_WAYS_EXP{1'b0}};
                wr_vc_tag_o        = {TAG_WT_VC{1'b0}};
                for(i=0; i<L1_WAYS; i=i+1) begin
                    wr_l1d_tag_en_o[i] = 1'b0;
                end
            end
            ST2_FETCH_L2_A : begin
                //-----------signals between l1d and l2-----------
                l1d_l2__rd_en_pre  = 1'b0;
                l1d_l2__addr_pre   = {AWT{1'b0}};
                l1d_l2__rd_en_o    = 1'b1;
                l1d_l2__addr_o     = l1d_l2__rd_addr_o_rcd_o;
                l2_l1d__rd_suc_act = l1d_l2__wr_en_o_dly1 ? 1'b0 : l2_l1d__suc_act_i;
                l2_l1d__rd_suc     = l1d_l2__wr_en_o_dly1 ? 1'b0 : l2_l1d__suc_i;
                //-----------------busy signals--------------------
                rd_l1d_busy_o      = 1'b1;
                wr_l1d_busy_o      = (l1d_l2__rd_addr_o_rcd_o[ENTRY_SEL+WORD_SEL+1:WORD_SEL+2] ==
                                      lsu_dc__dcache_waddr_i_dly1[ENTRY_SEL+WORD_SEL+1:WORD_SEL+2]);
                wr_vc_busy_o       = 1'b0;
                l2_wr_block        = 1'b0;
                //---------------tag_ram signals-------------------
                wr_vc_tag_en_o     = 1'b0;
                //wr_vc_tag_way_o    = {VC_WAYS_EXP{1'b0}};
                wr_vc_tag_o        = {TAG_WT_VC{1'b0}};
                for (i=0; i<L1_WAYS; i=i+1) begin
                    wr_l1d_tag_en_o[i] = 1'b0;
                end
            end
            ST2_FETCH_L2_B : begin
                //-----------signals between l1d and l2-----------
                l1d_l2__rd_en_pre  = 1'b0;
                l1d_l2__addr_pre   = {AWT{1'b0}};
                l1d_l2__rd_en_o    = (l2_l1d__rd_suc_act && l2_l1d__rd_suc) ? 1'b0 : 1'b1;
                l1d_l2__addr_o     = (l2_l1d__rd_suc_act && l2_l1d__rd_suc) ? lsu_dc__dcache_waddr_i : l1d_l2__rd_addr_o_rcd_o;
                l2_l1d__rd_suc_act = l1d_l2__wr_en_o_dly1 ? 1'b0 : l2_l1d__suc_act_i;
                l2_l1d__rd_suc     = l1d_l2__wr_en_o_dly1 ? 1'b0 : l2_l1d__suc_i;
                //-----------------busy signals--------------------
                rd_l1d_busy_o      = 1'b0;
                wr_l1d_busy_o      = 1'b0;
                wr_vc_busy_o       = l1d_l2__rd_en_pre_dly2;
                l2_wr_block        = (l2_l1d__rd_suc_act && l2_l1d__rd_suc) ? 
                                     (lsu_dc__dcache_waddr_i[AWT-1:WORD_SEL+2] == l1d_l2__rd_addr_o_rcd_o[AWT-1:WORD_SEL+2]) : 1'b0;
                //---------------tag_ram signals-------------------
                wr_vc_tag_en_o     = rpl_ready_o;
                //wr_vc_tag_way_o    = hot_vc_exp_i;
                wr_vc_tag_o        = rpl_l1d_way_rcd_o[0] ? l1d_replace_tag_rcd[0] : l1d_replace_tag_rcd[1];
                for (i=0; i<L1_WAYS; i=i+1) begin
                    wr_l1d_tag_en_o[i] = 1'b0;
                end
            end
            ST2_FETCH_L2_C : begin
                //-----------signals between l1d and l2-----------
                l1d_l2__rd_en_pre  = 1'b0;
                l1d_l2__addr_pre   = {AWT{1'b0}};
                l1d_l2__rd_en_o    = 1'b0;
                l1d_l2__addr_o     = lsu_dc__dcache_waddr_i;
                l2_l1d__rd_suc_act = 1'b0;
                l2_l1d__rd_suc     = 1'b0;
                //-----------------busy signals--------------------
                rd_l1d_busy_o      = 1'b0;
                wr_l1d_busy_o      = 1'b1;
                wr_vc_busy_o       = 1'b0;
                l2_wr_block        = (lsu_dc__dcache_waddr_i[AWT-1:WORD_SEL+2] == l1d_l2__rd_addr_o_rcd_o[AWT-1:WORD_SEL+2]);
                //---------------tag_ram signals-------------------
                wr_vc_tag_en_o     = rpl_ready_o;
                //wr_vc_tag_way_o    = hot_vc_exp_i;
                wr_vc_tag_o        = rpl_l1d_way_rcd_o[0] ? l1d_replace_tag_rcd[0] : l1d_replace_tag_rcd[1];
                for (i=0; i<L1_WAYS; i=i+1) begin
                    wr_l1d_tag_en_o[i] = 1'b0;
                end
            end
            ST2_WRITE_L1D_A : begin
                //-----------signals between l1d and l2-----------
                l1d_l2__rd_en_pre  = 1'b0;
                l1d_l2__addr_pre   = {AWT{1'b0}};
                l1d_l2__rd_en_o    = 1'b0;
                l1d_l2__addr_o     = lsu_dc__dcache_waddr_i;
                l2_l1d__rd_suc_act = 1'b0;
                l2_l1d__rd_suc     = 1'b0;
                //-----------------busy signals--------------------
                rd_l1d_busy_o      = 1'b0;
                wr_l1d_busy_o      = 1'b1;
                wr_vc_busy_o       = 1'b0;
                l2_wr_block        = (lsu_dc__dcache_waddr_i[AWT-1:WORD_SEL+2] == l1d_l2__rd_addr_o_rcd_o[AWT-1:WORD_SEL+2]);
                //---------------tag_ram signals-------------------
                wr_vc_tag_en_o     = 1'b0;
                //wr_vc_tag_way_o    = {VC_WAYS_EXP{1'b0}};
                wr_vc_tag_o        = {TAG_WT_VC{1'b0}};
                for (i=0; i<L1_WAYS; i=i+1) begin
                    wr_l1d_tag_en_o[i] = wr_l1d_en_i[i];
                end
            end
            ST2_WRITE_L1D_B : begin
                //-----------signals between l1d and l2-----------
                l1d_l2__rd_en_pre  = 1'b0;
                l1d_l2__addr_pre   = {AWT{1'b0}};
                l1d_l2__rd_en_o    = 1'b0;
                l1d_l2__addr_o     = lsu_dc__dcache_waddr_i;
                l2_l1d__rd_suc_act = 1'b0;
                l2_l1d__rd_suc     = 1'b0;
                //-----------------busy signals--------------------
                rd_l1d_busy_o      = 1'b0;
                wr_l1d_busy_o      = 1'b0;
                wr_vc_busy_o       = 1'b0;
                l2_wr_block        = (lsu_dc__dcache_waddr_i[AWT-1:WORD_SEL+2] == l1d_l2__rd_addr_o_rcd_o[AWT-1:WORD_SEL+2]);
                //---------------tag_ram signals-------------------
                wr_vc_tag_en_o     = 1'b0;
                //wr_vc_tag_way_o    = {VC_WAYS_EXP{1'b0}};
                wr_vc_tag_o        = {TAG_WT_VC{1'b0}};
                for (i=0; i<L1_WAYS; i=i+1) begin
                    wr_l1d_tag_en_o[i] = 1'b0;
                end
            end
            ST2_WAIT_NEW_RQS : begin
                //-----------signals between l1d and l2-----------
                l1d_l2__rd_en_pre  = 1'b0;
                l1d_l2__addr_pre   = {AWT{1'b0}};
                l1d_l2__rd_en_o    = 1'b0;
                l1d_l2__addr_o     = lsu_dc__dcache_waddr_i;
                l2_l1d__rd_suc_act = 1'b0;
                l2_l1d__rd_suc     = 1'b0;
                //-----------------busy signals--------------------
                rd_l1d_busy_o      = 1'b0;
                wr_l1d_busy_o      = 1'b0;
                wr_vc_busy_o       = 1'b0;
                l2_wr_block        = (lsu_dc__dcache_waddr_i[AWT-1:WORD_SEL+2] == l1d_l2__rd_addr_o_rcd_o[AWT-1:WORD_SEL+2]);
                //---------------tag_ram signals-------------------
                wr_vc_tag_en_o     = 1'b0;
                //wr_vc_tag_way_o    = {VC_WAYS_EXP{1'b0}};
                wr_vc_tag_o        = {TAG_WT_VC{1'b0}};
                for (i=0; i<L1_WAYS; i=i+1) begin
                    wr_l1d_tag_en_o[i] = 1'b0;
                end
            end
            default : begin
                //-----------signals between l1d and l2-----------
                l1d_l2__rd_en_pre  = 1'b0;
                l1d_l2__addr_pre   = {AWT{1'b0}};
                l1d_l2__rd_en_o    = 1'b0;
                l1d_l2__addr_o     = lsu_dc__dcache_waddr_i;
                l2_l1d__rd_suc_act = 1'b0;
                l2_l1d__rd_suc     = 1'b0;
                //-----------------busy signals--------------------
                rd_l1d_busy_o      = 1'b0;
                wr_l1d_busy_o      = 1'b0;
                wr_vc_busy_o       = 1'b0;
                l2_wr_block        = 1'b0;
                //---------------tag_ram signals-------------------
                wr_vc_tag_en_o     = 1'b0;
                //wr_vc_tag_way_o    = {VC_WAYS_EXP{1'b0}};
                wr_vc_tag_o        = {TAG_WT_VC{1'b0}};
                for (i=0; i<L1_WAYS; i=i+1) begin
                    wr_l1d_tag_en_o[i] = 1'b0;
                end
            end
        endcase
    end

    //------------------record the necessary information of the req to l2 ------------------
    always @(posedge clk_i or `RST_DECL(rst_i)) begin : load_req_rcd_block
        if (`RST_TRUE(rst_i)) begin
            l1d_l2__rd_addr_o_rcd_o <= {AWT{1'b0}};
            ways_occupied_rcd_o     <= {L1_WAYS{1'b0}};
            rpl_l1d_way_rcd_o       <= {L1_WAYS{1'b0}};
            rpl_ready_o             <= 1'b0;
            rd_l1d_low_half_rcd_o   <= {HALF_LINE_DWT{1'b0}};
            rd_l1d_high_half_rcd_o  <= {HALF_LINE_DWT{1'b0}};
            for(i=0; i<L1_WAYS; i=i+1) begin
                l1d_replace_tag_rcd[i] <= {TAG_WT_VC{1'b0}};
            end
        end else begin
            /*work with "rd l1d mem at the next clk of LSU gives the load req"*/
            if (l1d_l2__rd_en_pre) begin
                l1d_l2__rd_addr_o_rcd_o <= l1d_l2__addr_pre;
                ways_occupied_rcd_o     <= valid_rd_l1d_i;
                l1d_replace_tag_rcd[0]  <= rd_l1d_rdtag_i[0];
                l1d_replace_tag_rcd[1]  <= rd_l1d_rdtag_i[1];
                rpl_ready_o             <= 1'b0;
            end else if (l1d_l2__rd_en_pre_dly1) begin
                rpl_l1d_way_rcd_o       <= hot_l1d_onehot_i;
                if (l1d_l2__rd_addr_o_rcd_o[WORD_SEL+1]) begin
                    rd_l1d_high_half_rcd_o <= hot_l1d_onehot_i[0] ? rd_l1d_halfdata_i[0] :
                                                                    rd_l1d_halfdata_i[1] ;
                end else begin
                    rd_l1d_low_half_rcd_o  <= hot_l1d_onehot_i[0] ? rd_l1d_halfdata_i[0] :
                                                                    rd_l1d_halfdata_i[1] ;
                end
            end else if (l1d_l2__rd_en_pre_dly2) begin
                if (l1d_l2__rd_addr_o_rcd_o[WORD_SEL+1]) begin
                    rd_l1d_low_half_rcd_o  <= rpl_l1d_way_rcd_o[0] ? rd_l1d_halfdata_i[0] :
                                                                     rd_l1d_halfdata_i[1] ;
                end else begin
                    rd_l1d_high_half_rcd_o <= rpl_l1d_way_rcd_o[0] ? rd_l1d_halfdata_i[0] :
                                                                     rd_l1d_halfdata_i[1] ;
                end
                rpl_ready_o <= &ways_occupied_rcd_o;
            end else begin
                rpl_ready_o <= 1'b0;
            end
        end
     end

    /******************************************************Sub_FSM deal with store******************************************************/
    always @(posedge clk_i or `RST_DECL(rst_i)) begin : Sub_WR_FSM_a
        if(`RST_TRUE(rst_i)) begin
            Current_ST3 <= ST2_IDLE;
        end else begin
            Current_ST3 <= Next_ST3;
        end
    end

    always @(*) begin : Sub_WR_FSM_b
        case (Current_ST3)
            ST3_IDLE : begin
                if (l1d_l2__wr_en_o) begin
                    Next_ST3 = ST3_WRITE_L2;
                end else begin
                    Next_ST3 = ST3_IDLE;
                end
            end
            ST3_WRITE_L2: begin
                if(l1d_l2__wr_en_o) begin
                    Next_ST3 = ST3_WRITE_L2;
                end else begin
                    Next_ST3 = ST3_IDLE;
                end
            end
            default : begin
                Next_ST3 = ST3_IDLE;
            end
        endcase
    end

    always @(*) begin : Sub_WR_FSM_c
        case (Current_ST3)
        ST3_IDLE : begin
            l1d_l2__wr_en_o        = (!l1d_l2__rd_en_o) ? (lsu_dc__dcache_nonblk_wr_en_accept_i&&(~l2_wr_block)) : 1'b0;
            l2_l1d__wr_suc_o       = 1'b0;
            l2_l1d__wr_suc_act_o   = 1'b0;
            l1d_l2__wdata_act_o    = dc_lsu__dcache_wr_suc_i_dly1;
            l1d_l2__wdata_o        = lsu_dc__dcache_wdata_i;
            l1d_l2__wdata_strobe_o = lsu_dc__dcache_wdata_strobe_i;
        end
        ST3_WRITE_L2 : begin
            l1d_l2__wr_en_o        = (!l1d_l2__rd_en_o) ? (lsu_dc__dcache_nonblk_wr_en_accept_i&&(~l2_wr_block)) : 1'b0;
            l2_l1d__wr_suc_o       = l2_l1d__suc_i;
            l2_l1d__wr_suc_act_o   = l2_l1d__suc_act_i;
            l1d_l2__wdata_act_o    = dc_lsu__dcache_wr_suc_i_dly1;
            l1d_l2__wdata_o        = lsu_dc__dcache_wdata_i;
            l1d_l2__wdata_strobe_o = lsu_dc__dcache_wdata_strobe_i;
        end
        default : begin
            l1d_l2__wr_en_o        = 1'b0;
            l1d_l2__wdata_act_o    = 1'b0;
            l1d_l2__wdata_o        = {L1_L2_DWT{1'b0}};
            l1d_l2__wdata_strobe_o = {LSU_DC_SWT{1'b0}};
            l2_l1d__wr_suc_o       = 1'b0;
            l2_l1d__wr_suc_act_o   = 1'b0;
        end
        endcase        
    end

    /******************************************************Dly_Chain******************************************************/
    assign data_dly1 = {lsu_dc__dcache_nonblk_rd_en_accept_i,
                        rd_l1d_en_i,
                        lsu_dc__dcache_raddr_i,
                        lsu_dc__dcache_waddr_i,
                        l1d_l2__wr_en_o,
                        l2_l1d__wr_suc_act_o,
                        l2_l1d__wr_suc_o,
                        l1d_l2__rd_en_pre,
                        dc_lsu__dcache_wr_suc_i};

    assign {lsu_dc__dcache_nonblk_rd_en_accept_i_dly1,
            rd_l1d_en_i_dly1,
            lsu_dc__dcache_raddr_i_dly1,
            lsu_dc__dcache_waddr_i_dly1,
            l1d_l2__wr_en_o_dly1,
            l2_l1d__wr_suc_act_dly1,
            l2_l1d__wr_suc_dly1,
            l1d_l2__rd_en_pre_dly1,
            dc_lsu__dcache_wr_suc_i_dly1} = data_dly1_reg;

    always @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            data_dly1_reg          <= {DLY1_WT{1'b0}};
            l1d_l2__wr_en_o_dly2   <= 1'b0;
            l1d_l2__rd_en_pre_dly2 <= 1'b0;
        end else begin
            data_dly1_reg          <= data_dly1;
            l1d_l2__wr_en_o_dly2   <= l1d_l2__wr_en_o_dly1;
            l1d_l2__rd_en_pre_dly2 <= l1d_l2__rd_en_pre_dly1;
        end
    end

    /**************************************************Gen some output sigs**************************************************/
    assign Current_ST2_o       = Current_ST2;
    assign rpl_l1d_entry_o     = l1d_l2__rd_addr_o_rcd_o[ENTRY_SEL+WORD_SEL+1:WORD_SEL+2];
    assign l1d_l2__rd_en_pre_o = l1d_l2__rd_en_pre;
    assign rpl_disable_o       = (&ways_occupied_rcd_o) ? hot_l1d_onehot_i : {L1_WAYS{1'b0}};

endmodule
