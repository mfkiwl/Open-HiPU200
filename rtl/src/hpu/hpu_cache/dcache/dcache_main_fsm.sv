//*********************************************************************************
//Project Name : HiPU200_Dcache
//Create Time  : 2020/06/03 11:07
//File Name    : dcache_main_fsm.sv
//Module Name  : dcache_main_fsm
//Abstract     : dcache main fsm control the conmunication with LSU and L2
//*********************************************************************************
//Modification History:
//Time          By              Version                 Change Description
//-----------------------------------------------------------------------
//2010/06/03    Zongpc           3.0                    Change Coding Style
//11:07
//*********************************************************************************

`timescale      1ns/1ps

`include "hpu_head.sv"
import hpu_pkg::*;

module dcache_main_fsm #(
    parameter   AWT           = 32,
    parameter   WORD_SEL      = 4,//4 Bytes per word, the last two bits of ADDR from CPU can be ignored
    parameter   ENTRY_SEL     = 7,
    parameter   TAG_WT        = AWT-ENTRY_SEL-WORD_SEL-2,
    parameter   TAG_WT_VC     = AWT-WORD_SEL-2,
    parameter   LSU_DC_DWT    = 4*8,
    parameter   LINE_DWT      = 64*8,
    parameter   HALF_LINE_DWT = 32*8,
    parameter   L2_L1_DWT     = HALF_LINE_DWT,//limited by the width of ram 64bit*4
    parameter   L1_WAYS       = 2,
    parameter   VC_WAYS_EXP   = 2,
    parameter   VC_WAYS       = 2**VC_WAYS_EXP, //victim cache has 2**2 = 4 ways
    parameter   CSR_DWT       = 32,
    parameter   LSU_DC_SWT    = 4
)(
    input                          clk_i,
    input                          rst_i,

    //the req from cpu
    input                           lsu_dc__dcache_nonblk_wr_en_i,
    input [AWT-1:0]                 lsu_dc__dcache_waddr_i,
    input                           lsu_dc__dcache_nonblk_rd_en_i,
    input [AWT-1:0]                 lsu_dc__dcache_raddr_i,
    input [LSU_DC_DWT-1:0]          lsu_dc__dcache_wdata_i,
    input [LSU_DC_SWT-1:0]          lsu_dc__dcache_wdata_strobe_i,

    //the rsp to cpu
    output reg                      dc_lsu__dcache_rd_suc_o,
    output reg                      dc_lsu__dcache_wr_suc_o,
    output reg [LSU_DC_DWT-1:0]     dc_lsu__dcache_rdata_o,

    //the data_rsp from L2
    input                           l2_l1d__rdata_act_i,
    input [L2_L1_DWT-1:0]           l2_l1d__rdata_i,

    //the interface with csr
    input  csr_bus_req_t            csr_dc__bus_req,
    output csr_bus_rsp_t            dc_csr__bus_rsp,
    output                          csr_finish_o,

    //some signals with sub_fsm
    input [2:0]                     Current_ST2_i,//the state of sub_fsm_rd
    input                           l2_l1d__wr_suc_act_i,
    input                           l2_l1d__wr_suc_i,//the wr_rsp from L2 (Creat by sub_fsm_wr)
    input                           l1d_l2__rd_en_pre_i,
    input [L1_WAYS-1:0]             ways_occupied_rcd_i,//wether the two ways of the cache_set in L1D are all occupied
    input [L1_WAYS-1:0]             rpl_l1d_way_rcd_i,//the way in l1d to be replaced
    input [AWT-1:0]                 l1d_l2__rd_addr_o_rcd_i,//the addr_record of the cache line that L2 is dealing with
    input [HALF_LINE_DWT-1:0]       rd_l1d_low_half_rcd_i,//the low half data of the cache_set in L1D which may be replaced
    input [HALF_LINE_DWT-1:0]       rd_l1d_high_half_rcd_i,//the high half data of the cache_set in L1D which may be replaced
    input                           rd_l1d_busy_i,//if it is high, can't read L1D now, to avoid conflict
    input                           wr_l1d_busy_i,//if it is high, can't read L1D now, to avoid conflict
    input                           wr_vc_busy_i,//if it is high, can't write VC now, to avoid conflict
    input                           rpl_ready_i,
    output reg                      lsu_dc__dcache_nonblk_rd_en_accept_o,
    output reg                      lsu_dc__dcache_nonblk_wr_en_accept_o,

    //the interface with way_tag_ram
    output reg                      rd_l1d_rdtag_en_o,
    output reg [AWT-1:0]            rd_l1d_rdtag_addr_o,
    input      [L1_WAYS-1:0]        hit_rd_l1d_i,

    output reg                      rd_l1d_wrtag_en_o,
    output reg [AWT-1:0]            rd_l1d_wrtag_addr_o,
    input      [L1_WAYS-1:0]        hit_wr_l1d_i,

    //the interface with vc_tag_ram
    output reg                      rd_vc_rdtag_en_o,
    output reg [TAG_WT_VC-1:0]      rd_vc_rdtag_o,
    input                           hit_rd_vc_i,
    input      [VC_WAYS_EXP-1:0]    hit_rd_vc_way_i,

    output reg                      rd_vc_wrtag_en_o,
    output reg [TAG_WT_VC-1:0]      rd_vc_wrtag_o,
    input                           hit_wr_vc_i,
    input      [VC_WAYS_EXP-1:0]    hit_wr_vc_way_i,

    input      [VC_WAYS-1:0]        victim_valid_i,

    //the specific-interface with LRU
    input      [L1_WAYS-1:0]        hot_l1d_onehot_i,//it represents the Inx of way which is the Least_Recent_Used
    input      [VC_WAYS_EXP-1:0]    hot_vc_exp_i, //it represents the Inx of way which is the Least_Recent_Used
    output reg [ENTRY_SEL-1:0]      hit_rd_l1d_entry_o,
    output reg [ENTRY_SEL-1:0]      hit_wr_l1d_entry_o,

    //the interface with way_data_ram
    output reg [L1_WAYS-1:0]        wr_l1d_en_o,
    output reg [1:0]                wr_l1d_half_en_o[L1_WAYS-1:0], //2'10 low part;2'b11 high part;2'b00 No half mode
    output reg [LSU_DC_SWT-1:0]     wr_l1d_data_strobe_o[L1_WAYS-1:0],
    output reg [AWT-1:0]            wr_l1d_addr_o[L1_WAYS-1:0],
    output reg [HALF_LINE_DWT-1:0]  wr_l1d_data_o[L1_WAYS-1:0],

    output reg [L1_WAYS-1:0]        rd_l1d_en_o,
    output reg [1:0]                rd_l1d_half_en_o[L1_WAYS-1:0],
    output reg [AWT-1:0]            rd_l1d_addr_o[L1_WAYS-1:0],
    input      [LSU_DC_DWT-1:0]     rd_l1d_word_i[L1_WAYS-1:0],
    input      [L1_WAYS-1:0]        way_data_rw_conflict_i,

    output reg [L1_WAYS-1:0]        clear_l1d_way_o,
    output reg [L1_WAYS-1:0]        clear_l1d_line_o,
    output reg [AWT-1:0]            clear_l1d_addr_o[L1_WAYS-1:0],

    //the interface with vc_data_ram
    output reg                      wr_vc_en_o,
    output reg [VC_WAYS_EXP-1:0]    wr_vc_way_o,
    output reg [WORD_SEL-1:0]       wr_vc_word_en_o,
    output reg                      wr_vc_line_en_o,
    output reg [LSU_DC_SWT-1:0]     wr_vc_data_strobe_o,
    output reg [LINE_DWT-1:0]       wr_vc_data_o,
    
    output reg                      rd_vc_en_o,
    output reg [VC_WAYS_EXP-1:0]    rd_vc_way_o,
    output reg [WORD_SEL-1:0]       rd_vc_word_en_o,
    input      [LSU_DC_DWT-1:0]     rd_vc_word_i,

    output reg                      clear_vc_all_o,
    output reg                      clear_vc_line_o,
    output reg [VC_WAYS_EXP-1:0]    clear_vc_way_o
);
    localparam    ST1_IDLE  = 0;
    localparam    ST1_COMP  = 1;//the state to deal with rd/wr req from CPU
    localparam    ST1_CSR_A = 2;//csr_reg decode
    localparam    ST1_CSR_B = 3;//csr_reg reset

    localparam    ST2_IDLE         = 0;
    localparam    ST2_FETCH_L2_A   = 1;
    localparam    ST2_FETCH_L2_B   = 2;
    localparam    ST2_FETCH_L2_C   = 3;
    localparam    ST2_WRITE_L1D_A  = 4;
    localparam    ST2_WRITE_L1D_B  = 5;
    localparam    ST2_WAIT_NEW_RQS = 6;

    localparam    DLY1_WT = AWT*3+WORD_SEL*2+L1_WAYS*2+VC_WAYS_EXP+L2_L1_DWT+8;
    localparam    DLY2_WT = AWT*2+WORD_SEL;

    localparam    CSR_MWT = 5;

    integer                     i;

    reg  [1:0]                  Current_ST1;
    reg  [1:0]                  Next_ST1;

    reg                         dc_lsu__dcache_rd_suc_act;
    reg                         dc_lsu__dcache_wr_suc_act;
    //reg                         dc_lsu__dcache_rdata_act;
    /*work with "rd l1d mem at the clk of LSU gives the load req"
    reg  [LSU_DC_DWT-1:0]       rd_l1d_word_i_dly1[L1_WAYS-1:0];*/


    //decode the addr from LSU
    wire [WORD_SEL-1:0]         lsu_dc__rd_word_sel;
    wire [WORD_SEL-1:0]         lsu_dc__wr_word_sel;

    wire [AWT-1:0]              lsu_dc__dcache_raddr_nxt_half;

    reg [HALF_LINE_DWT-1:0]     replace_low_half_data[L1_WAYS-1:0];
    reg [HALF_LINE_DWT-1:0]     replace_high_half_data[L1_WAYS-1:0];

    //csr information record
    reg [CSR_MWT-1:0]           csr_mode;
    reg [CSR_DWT-1:0]           csr_addr;
    reg                         csr_act;
    reg                         csr_status;
    reg [CSR_MWT-1:0]           csr_mode_lck;//lock the csr mode when act the csr operation
    reg [CSR_DWT-1:0]           csr_addr_lck;//lock the csr addr when act the csr operation

    //such tight timing requriment in the prj involves some pipeline design
    wire                        csr_act_dly1;
    wire                        lsu_dc__dcache_nonblk_rd_en_i_dly1;
    wire                        lsu_dc__dcache_nonblk_wr_en_i_dly1;
    wire [AWT-1:0]              lsu_dc__dcache_raddr_i_dly1;
    wire [AWT-1:0]              lsu_dc__dcache_raddr_nxt_half_dly1;
    wire [AWT-1:0]              lsu_dc__dcache_waddr_i_dly1;
    wire [WORD_SEL-1:0]         lsu_dc__rd_word_sel_dly1;
    wire [WORD_SEL-1:0]         lsu_dc__wr_word_sel_dly1;
    wire [L1_WAYS-1:0]          hit_rd_l1d_dly1;
    wire                        hit_rd_vc_dly1;
    wire [L1_WAYS-1:0]          hit_wr_l1d_dly1;
    wire                        hit_wr_vc_dly1;
    wire [VC_WAYS_EXP-1:0]      hit_wr_vc_way_dly1;
//    wire                        dc_lsu__dcache_rd_suc_act_dly1;
//    wire                        dc_lsu__dcache_rd_suc_o_dly1;
    wire                        dc_lsu__dcache_wr_suc_act_dly1;
    wire                        dc_lsu__dcache_wr_suc_o_dly1;
    wire                        l2_l1d__rdata_act_i_dly1;
    wire [L2_L1_DWT-1:0]        l2_l1d__rdata_i_dly1;
    
    wire [AWT-1:0]              lsu_dc__dcache_waddr_i_dly2;
    wire [WORD_SEL-1:0]         lsu_dc__wr_word_sel_dly2;
    wire [AWT-1:0]              lsu_dc__dcache_raddr_nxt_half_dly2;

    wire [DLY1_WT-1:0]          data_dly1;
    wire [DLY2_WT-1:0]          data_dly2;

    reg  [DLY1_WT-1:0]          data_dly1_reg;
    reg  [DLY2_WT-1:0]          data_dly2_reg;

    /*********************************************Deal with Input_CSR signals*********************************************/
    always @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            csr_act  <= 1'b0;
            csr_addr <= {CSR_DWT{1'b0}};
            csr_mode <= {CSR_MWT{1'b0}};
        end else begin
            if (csr_dc__bus_req.wr_en && (csr_dc__bus_req.waddr == 12'h7E0)) begin
                csr_act  <= csr_dc__bus_req.wdata[0];
            end else if (csr_dc__bus_req.wr_en && (csr_dc__bus_req.waddr == 12'h7E2)) begin
                csr_addr <= csr_dc__bus_req.wdata;
            end else if (csr_dc__bus_req.wr_en && (csr_dc__bus_req.waddr == 12'h7E3)) begin
                csr_mode <= csr_dc__bus_req.wdata[CSR_MWT-1:0];
            end else begin
                csr_act  <= 1'b0;
            end
        end
    end

    always @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            csr_status <= 1'b0;
        end else begin
            if (csr_act) begin
                csr_status <= 1'b0;
            end else if (Current_ST1 == ST1_CSR_A) begin
                csr_status <= 1'b1;
            end else if (csr_dc__bus_req.wr_en && (csr_dc__bus_req.waddr == 12'h7E1)) begin
                csr_status <= csr_dc__bus_req.wdata[0];
            end
        end
    end

    assign csr_finish_o = csr_status;

    assign dc_csr__bus_rsp.rdata = (csr_dc__bus_req.rd_en && (csr_dc__bus_req.raddr == 12'h7E1)) ? {{(CSR_DWT-1){1'b0}},csr_status} :
                                                                                                   32'h00000000;

    always @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            csr_addr_lck <= {CSR_DWT{1'b0}};
            csr_mode_lck <= {CSR_MWT{1'b0}};
        end else begin
            if(csr_act)begin//lock the csr reg, when act the csr operation
                csr_addr_lck <= csr_addr;
                csr_mode_lck <= csr_mode;
            end
        end
    end

    /*********************************************split lsu_dc__dcache_addr_i*********************************************/
    assign lsu_dc__rd_word_sel           = lsu_dc__dcache_raddr_i[WORD_SEL+1:2];
    assign lsu_dc__wr_word_sel           = lsu_dc__dcache_waddr_i[WORD_SEL+1:2];
    assign lsu_dc__dcache_raddr_nxt_half = {lsu_dc__dcache_raddr_i[AWT-1:WORD_SEL+2],
                                            !lsu_dc__dcache_raddr_i[WORD_SEL+1],
                                            lsu_dc__dcache_raddr_i[WORD_SEL:0]};

    /******************************************************Main_FSM******************************************************/
    always @(posedge clk_i or `RST_DECL(rst_i)) begin : Main_FSM_a
        if(`RST_TRUE(rst_i)) begin
            Current_ST1 <= ST1_IDLE;
        end else begin
            Current_ST1 <= Next_ST1;
        end
    end

    always @(*) begin : Main_FSM_b
        case (Current_ST1)
            ST1_IDLE : begin
                if(csr_act_dly1)begin
                    Next_ST1 = ST1_CSR_A;
                end else begin
                    Next_ST1 = ST1_COMP;
                end
            end
            ST1_COMP : begin
                if(csr_act_dly1)begin
                    Next_ST1 = ST1_CSR_A;
                end else begin
                    Next_ST1 = ST1_COMP;
                end
            end
            ST1_CSR_A : begin
                Next_ST1 = ST1_CSR_B;
            end
            ST1_CSR_B : begin
                Next_ST1 = ST1_COMP;
            end
            default : begin
                Next_ST1 = ST1_IDLE;
            end
        endcase
    end

    always @(*) begin : Main_FSM_c_no_csr_sigs
        if (Current_ST1 == ST1_COMP) begin
            //-----------------------------------lsu load or csr operation-----------------------------------
            //cause read on rdtag_ram
            rd_l1d_rdtag_en_o   = csr_act_dly1||lsu_dc__dcache_nonblk_rd_en_i;
            rd_l1d_rdtag_addr_o = csr_act_dly1 ? csr_addr_lck : lsu_dc__dcache_raddr_i;
            rd_vc_rdtag_en_o    = csr_act_dly1||lsu_dc__dcache_nonblk_rd_en_i;
            rd_vc_rdtag_o       = csr_act_dly1 ? csr_addr_lck[AWT-1:WORD_SEL+2] : lsu_dc__dcache_raddr_i[AWT-1:WORD_SEL+2];
            //load rsp from dc to lsu
            dc_lsu__dcache_rd_suc_act = lsu_dc__dcache_nonblk_rd_en_i_dly1;
            dc_lsu__dcache_rd_suc_o   = (!(csr_act||csr_act_dly1)) && ((!rd_l1d_busy_i) && (|((~way_data_rw_conflict_i)&hit_rd_l1d_i))) //no data_ram conflict hit L1D
                                        || ((!(csr_act||csr_act_dly1)) && hit_rd_vc_i);//hit VC
            //rd l1d data_ram
            for (i=0;i<L1_WAYS;i=i+1) begin
                /*rd l1d mem at the next clk of LSU gives the load req*/
                rd_l1d_en_o[i]   = (Current_ST2_i == ST2_FETCH_L2_A) || (Current_ST2_i == ST2_IDLE) || lsu_dc__dcache_nonblk_rd_en_i_dly1;
                rd_l1d_half_en_o[i] = (Current_ST2_i == ST2_IDLE) ? 2'b10 :
                                      (Current_ST2_i == ST2_FETCH_L2_A) ? 2'b11 : 2'b00;
                rd_l1d_addr_o[i] = (Current_ST2_i == ST2_FETCH_L2_A) ? lsu_dc__dcache_raddr_nxt_half_dly2 : lsu_dc__dcache_raddr_i_dly1;
                /*rd l1d mem at the clk of LSU gives the load req
                rd_l1d_en_o[i]   = (Current_ST2_i == ST2_IDLE)||lsu_dc__dcache_nonblk_rd_en_i;
                rd_l1d_addr_o[i] = ({AWT{l1d_l2__rd_en_pre_i}} & lsu_dc__dcache_raddr_nxt_half_dly1)
                                   | ({AWT{!l1d_l2__rd_en_pre_i}} & lsu_dc__dcache_raddr_i);*/
            end
            //rd vc data_ram
            rd_vc_en_o      = 1'b1;
            rd_vc_way_o     = hit_rd_vc_way_i;
            rd_vc_word_en_o = lsu_dc__rd_word_sel_dly1;
            //the load data from dc to lsu
            //dc_lsu__dcache_rdata_act = dc_lsu__dcache_rd_suc_act_dly1&&dc_lsu__dcache_rd_suc_o_dly1;
            /*work with "rd l1d mem at the next clk of LSU gives the load req"*/
            dc_lsu__dcache_rdata_o   = (hit_rd_l1d_dly1[0]) ? rd_l1d_word_i[0] :
                                       (hit_rd_l1d_dly1[1]) ? rd_l1d_word_i[1] :
                                       (hit_rd_vc_dly1) ? rd_vc_word_i : {LSU_DC_DWT{1'b0}};
            /*work with "rd l1d mem at the clk of LSU gives the load req"
            dc_lsu__dcache_rdata_o   = (hit_rd_l1d_dly1[0]) ? rd_l1d_word_i_dly1[0] :
                                       (hit_rd_l1d_dly1[1]) ? rd_l1d_word_i_dly1[1] :
                                       (hit_rd_vc_dly1) ? rd_vc_word_i : {LSU_DC_DWT{1'b0}};*/
            //-----------------------------------------lsu store-----------------------------------------------
            //cause read on wrtag_ram
            rd_l1d_wrtag_en_o   = lsu_dc__dcache_nonblk_wr_en_i;
            rd_l1d_wrtag_addr_o = lsu_dc__dcache_waddr_i;
            rd_vc_wrtag_en_o    = lsu_dc__dcache_nonblk_wr_en_i;
            rd_vc_wrtag_o       = lsu_dc__dcache_waddr_i[AWT-1:WORD_SEL+2];;
            //store rsp from dc to lsu
            dc_lsu__dcache_wr_suc_act = lsu_dc__dcache_nonblk_wr_en_i_dly1;
            dc_lsu__dcache_wr_suc_o   = ((|hit_wr_l1d_i)&&(!wr_l1d_busy_i)) ? l2_l1d__wr_suc_i && l2_l1d__wr_suc_act_i && (!(csr_act||csr_act_dly1)) :
                                        (hit_wr_vc_i && (!wr_vc_busy_i)) ? l2_l1d__wr_suc_i && l2_l1d__wr_suc_act_i && (!(csr_act||csr_act_dly1)) :
                                        (|{hit_wr_l1d_i,hit_wr_vc_i}) ? 1'b0 : l2_l1d__wr_suc_i && l2_l1d__wr_suc_act_i && (!(csr_act||csr_act_dly1));
            //wr l1d data_ram
            for (i=0;i<L1_WAYS;i=i+1) begin
                wr_l1d_en_o[i]          = (l2_l1d__rdata_act_i_dly1) ? ((^ways_occupied_rcd_i) ? (!ways_occupied_rcd_i[i]) : rpl_l1d_way_rcd_i[i]) : 
                                                                       (dc_lsu__dcache_wr_suc_act_dly1 && dc_lsu__dcache_wr_suc_o_dly1 && hit_wr_l1d_dly1[i]);
                wr_l1d_addr_o[i]        = (l2_l1d__rdata_act_i_dly1) ? l1d_l2__rd_addr_o_rcd_i : lsu_dc__dcache_waddr_i_dly2;
                wr_l1d_data_o[i]        = (l2_l1d__rdata_act_i_dly1) ? l2_l1d__rdata_i_dly1 : {{(HALF_LINE_DWT-LSU_DC_DWT){1'b0}},lsu_dc__dcache_wdata_i};
                wr_l1d_data_strobe_o[i] = (dc_lsu__dcache_wr_suc_act_dly1 && dc_lsu__dcache_wr_suc_o_dly1 && hit_wr_l1d_dly1[i]) ? 
                                          lsu_dc__dcache_wdata_strobe_i : {LSU_DC_SWT{1'b1}};
                wr_l1d_half_en_o[i]     = (l2_l1d__rdata_act_i_dly1 && (Current_ST2_i == ST2_WRITE_L1D_A)) ? 2'b10 : 
                                          (l2_l1d__rdata_act_i_dly1 && (Current_ST2_i == ST2_WRITE_L1D_B)) ? 2'b11 : 2'b00;
            end
            //wr vc data_ram
            wr_vc_en_o          = (rpl_ready_i) ? 1'b1 : 
                                  (dc_lsu__dcache_wr_suc_act_dly1 && dc_lsu__dcache_wr_suc_o_dly1 && hit_wr_vc_dly1 );
            wr_vc_way_o         = (dc_lsu__dcache_wr_suc_act_dly1 && dc_lsu__dcache_wr_suc_o_dly1) ? hit_wr_vc_way_dly1 : 
                                  (!victim_valid_i[0]) ? 2'b00 : 
                                  (!victim_valid_i[1]) ? 2'b01 : 
                                  (!victim_valid_i[2]) ? 2'b10 : 
                                  (!victim_valid_i[3]) ? 2'b11 : hot_vc_exp_i;
            wr_vc_data_o        = (dc_lsu__dcache_wr_suc_act_dly1 && dc_lsu__dcache_wr_suc_o_dly1 && hit_wr_vc_dly1) ? 
                                  {{(LINE_DWT-LSU_DC_DWT){1'b0}},lsu_dc__dcache_wdata_i} : 
                                  {rd_l1d_high_half_rcd_i,rd_l1d_low_half_rcd_i};
            wr_vc_data_strobe_o = (dc_lsu__dcache_wr_suc_act_dly1 && dc_lsu__dcache_wr_suc_o_dly1 && hit_wr_vc_dly1) ? 
                                  lsu_dc__dcache_wdata_strobe_i : {LSU_DC_SWT{1'b1}};
            wr_vc_line_en_o     = rpl_ready_i;
            wr_vc_word_en_o     = rpl_ready_i ? {WORD_SEL{1'b0}} : lsu_dc__wr_word_sel_dly2;

            lsu_dc__dcache_nonblk_rd_en_accept_o = lsu_dc__dcache_nonblk_rd_en_i;
            lsu_dc__dcache_nonblk_wr_en_accept_o = lsu_dc__dcache_nonblk_wr_en_i;
        end else begin
            rd_l1d_rdtag_en_o           = 1'b0;
            rd_l1d_rdtag_addr_o         = {AWT{1'b0}};
            rd_vc_rdtag_en_o            = 1'b0;
            rd_vc_rdtag_o               = {TAG_WT_VC{1'b0}};
            dc_lsu__dcache_rd_suc_act   = 1'b0;
            dc_lsu__dcache_rd_suc_o     = 1'b0;
            rd_vc_en_o                  = 1'b0;
            rd_vc_way_o                 = {VC_WAYS_EXP{1'b0}};
            rd_vc_word_en_o             = 1'b0;
            //dc_lsu__dcache_rdata_act    = 1'b0;
            dc_lsu__dcache_rdata_o      = {LSU_DC_DWT{1'b0}};
            rd_l1d_wrtag_en_o           = 1'b0;
            rd_l1d_wrtag_addr_o         = {AWT{1'b0}};
            rd_vc_wrtag_en_o            = 1'b0;
            rd_vc_wrtag_o               = {TAG_WT_VC{1'b0}};
            dc_lsu__dcache_wr_suc_act   = 1'b0;
            dc_lsu__dcache_wr_suc_o     = 1'b0;
            wr_vc_en_o                  = 1'b0;
            wr_vc_way_o                 = {VC_WAYS_EXP{1'b0}};
            wr_vc_data_o                = {LINE_DWT{1'b0}};
            wr_vc_data_strobe_o         = {LSU_DC_SWT{1'b0}};
            wr_vc_line_en_o             = 1'b0;
            wr_vc_word_en_o             = {WORD_SEL{1'b0}};
            lsu_dc__dcache_nonblk_rd_en_accept_o = 1'b0;
            lsu_dc__dcache_nonblk_wr_en_accept_o = 1'b0;
            for(i=0;i<L1_WAYS;i=i+1)begin
                rd_l1d_en_o[i]          = 1'b0;
                rd_l1d_half_en_o[i]     = 2'b00;
                rd_l1d_addr_o[i]        = {AWT{1'b0}};
                wr_l1d_en_o[i]          = 1'b0;
                wr_l1d_addr_o[i]        = 1'b0;
                wr_l1d_data_o[i]        = {HALF_LINE_DWT{1'b0}};
                wr_l1d_data_strobe_o[i] = {LSU_DC_SWT{1'b0}};
                wr_l1d_half_en_o[i]     = 2'b00;
            end
        end
    end

     always @(*) begin : Main_FSM_c_csr_sigs
        if (Current_ST1 == ST1_CSR_A) begin
            case(csr_mode_lck)
                5'b10000 : begin//clear all
                    for (i = 0; i < L1_WAYS; i=i+1) begin
                        clear_l1d_way_o[i]  = 1'b1;
                        clear_l1d_line_o[i] = 1'b0;
                        clear_l1d_addr_o[i] = {CSR_DWT{1'b0}}; 
                    end
                    clear_vc_all_o  = 1'b1;
                    clear_vc_line_o = 1'b0;
                    clear_vc_way_o  = {VC_WAYS_EXP{1'b0}};
                end
                5'b01000 : begin//clear line with pc
                    for (i = 0; i < L1_WAYS; i=i+1) begin
                        clear_l1d_way_o[i]  = 1'b0;
                        clear_l1d_line_o[i] = hit_rd_l1d_i[i];
                        clear_l1d_addr_o[i] = csr_addr_lck; 
                    end
                    clear_vc_all_o  = 1'b0;
                    clear_vc_line_o = hit_rd_vc_i;
                    clear_vc_way_o  = hit_rd_vc_way_i;
                end
                5'b00100 : begin//clear line with way and line_idx
                    for (i = 0; i < L1_WAYS; i=i+1) begin
                        clear_l1d_way_o[i]  = 1'b0;
                        clear_l1d_line_o[i] = csr_addr_lck[WORD_SEL+ENTRY_SEL+2+i];
                        clear_l1d_addr_o[i] = csr_addr_lck;
                    end
                    clear_vc_all_o  = 1'b0;
                    clear_vc_line_o = 1'b0;
                    clear_vc_way_o  = {VC_WAYS_EXP{1'b0}};
                end
                5'b00010 : begin//clear set
                    for (i = 0; i < L1_WAYS; i=i+1) begin
                        clear_l1d_way_o[i]  = 1'b0;
                        clear_l1d_line_o[i] = 1'b1;
                        clear_l1d_addr_o[i] = csr_addr_lck; 
                    end
                    clear_vc_all_o  = 1'b1;
                    clear_vc_line_o = 1'b0;
                    clear_vc_way_o  = {VC_WAYS_EXP{1'b0}};                    
                end
                5'b00001 : begin//clear way
                    for (i = 0; i < L1_WAYS; i=i+1) begin
                        clear_l1d_line_o[i] = 1'b0;
                        clear_l1d_addr_o[i] = {CSR_DWT{1'b0}}; 
                    end
                    clear_l1d_way_o[0] = (csr_addr_lck == 32'h00000001);
                    clear_l1d_way_o[1] = (csr_addr_lck == 32'h00000002);
                    clear_vc_all_o  = 1'b0;
                    clear_vc_line_o = (csr_addr_lck == 32'h00000003) || (csr_addr_lck == 32'h00000004) ||
                                      (csr_addr_lck == 32'h00000005) || (csr_addr_lck == 32'h00000006) ;
                    clear_vc_way_o  = ({2{csr_addr_lck == 32'h00000003}} & 2'b00) | 
                                      ({2{csr_addr_lck == 32'h00000004}} & 2'b01) |
                                      ({2{csr_addr_lck == 32'h00000005}} & 2'b10) |
                                      ({2{csr_addr_lck == 32'h00000006}} & 2'b11) ;
                end
                default : begin
                    for (i = 0; i < L1_WAYS; i=i+1) begin
                        clear_l1d_way_o[i]  = 1'b0;
                        clear_l1d_line_o[i] = 1'b0;
                        clear_l1d_addr_o[i] = {CSR_DWT{1'b0}}; 
                    end
                    clear_vc_all_o  = 1'b0;
                    clear_vc_line_o = 1'b0;
                    clear_vc_way_o  = {VC_WAYS_EXP{1'b0}};
                end
            endcase
        end else begin
            for (i = 0; i < L1_WAYS; i=i+1) begin
                        clear_l1d_way_o[i]  = 1'b0;
                        clear_l1d_line_o[i] = 1'b0;
                        clear_l1d_addr_o[i] = {CSR_DWT{1'b0}}; 
                    end
            clear_vc_all_o  = 1'b0;
            clear_vc_line_o = 1'b0;
            clear_vc_way_o  = {VC_WAYS_EXP{1'b0}};
        end
    end

    /**********************************************hit l1d word out to LSU***********************************************/
    /*work with "rd l1d mem at the clk of LSU gives the load req"
    always @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for (i = 0; i < L1_WAYS; i=i+1) begin
                rd_l1d_word_i_dly1[i] <= {LSU_DC_DWT{1'b0}};
            end
        end else begin
            for (i = 0; i < L1_WAYS; i=i+1) begin
                rd_l1d_word_i_dly1[i] <= rd_l1d_word_i[i];
            end
        end
    end*/

    /**********************************************hit l1d entry out to csr***********************************************/
    always @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            hit_rd_l1d_entry_o <= {ENTRY_SEL{1'b0}};
            hit_wr_l1d_entry_o <= {ENTRY_SEL{1'b0}};
        end else begin
            hit_rd_l1d_entry_o <= rd_l1d_rdtag_addr_o[ENTRY_SEL+WORD_SEL+1:WORD_SEL+2];
            hit_wr_l1d_entry_o <= rd_l1d_wrtag_addr_o[ENTRY_SEL+WORD_SEL+1:WORD_SEL+2];
        end
    end

    /******************************************************Dly_Chain******************************************************/
    always @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            data_dly1_reg <= {DLY1_WT{1'b0}};
            data_dly2_reg <= {DLY2_WT{1'b0}};
        end else begin
            data_dly1_reg <= data_dly1;
            data_dly2_reg <= data_dly2;
        end
    end
   
    assign data_dly1 = {csr_act,
                        lsu_dc__dcache_raddr_i,
                        lsu_dc__dcache_raddr_nxt_half,
                        lsu_dc__rd_word_sel,
                        lsu_dc__dcache_nonblk_rd_en_i,
                        lsu_dc__dcache_nonblk_wr_en_i,
                        hit_rd_l1d_i,
                        hit_rd_vc_i,
                        dc_lsu__dcache_wr_suc_act,
                        dc_lsu__dcache_wr_suc_o,
                        hit_wr_l1d_i,
                        hit_wr_vc_i,
                        hit_wr_vc_way_i,
                        lsu_dc__dcache_waddr_i,
                        lsu_dc__wr_word_sel,
                        l2_l1d__rdata_act_i,
                        l2_l1d__rdata_i};

    assign {csr_act_dly1,
            lsu_dc__dcache_raddr_i_dly1,
            lsu_dc__dcache_raddr_nxt_half_dly1,
            lsu_dc__rd_word_sel_dly1,
            lsu_dc__dcache_nonblk_rd_en_i_dly1,
            lsu_dc__dcache_nonblk_wr_en_i_dly1,
            hit_rd_l1d_dly1,
            hit_rd_vc_dly1,
            dc_lsu__dcache_wr_suc_act_dly1,
            dc_lsu__dcache_wr_suc_o_dly1,
            hit_wr_l1d_dly1,
            hit_wr_vc_dly1,
            hit_wr_vc_way_dly1,
            lsu_dc__dcache_waddr_i_dly1,
            lsu_dc__wr_word_sel_dly1,
            l2_l1d__rdata_act_i_dly1,
            l2_l1d__rdata_i_dly1} = data_dly1_reg;

    assign data_dly2 = {lsu_dc__dcache_waddr_i_dly1,
                        lsu_dc__wr_word_sel_dly1,
                        lsu_dc__dcache_raddr_nxt_half_dly1};

    assign {lsu_dc__dcache_waddr_i_dly2,
            lsu_dc__wr_word_sel_dly2,
            lsu_dc__dcache_raddr_nxt_half_dly2} = data_dly2_reg;

endmodule
