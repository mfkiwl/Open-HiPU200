`timescale 1ns/1ps
`include "hpu_head.sv"
import hpu_pkg::*;


module l2_cache_ctrl
#
(
    parameter L1_L2_AWT             = 32,     // unit Byte
    parameter L1_L2_DWT             = 4 *8,   // 4B
    parameter L2_L1_DWT             = 32*8,   // 64B
    parameter CSR_L2C__ADDR_WTH     =  12  ,
    parameter CSR_L2C__DATA_WTH     =  32
)
(
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   l1d_l2__rd_en_i,                //l1 data cache interface         
    input   logic                                   l1d_l2__wr_en_i,    
    input   logic[L1_L2_AWT-1  : 0]                 l1d_l2__addr_i,         
    input   logic[L1_L2_DWT-1  : 0]                 l1d_l2__wdata_i,        
    input   logic                                   l1d_l2__wdata_act_i,                  
    input   logic                                   l1i_l2__rd_en_i,                //l1 instruction cache interface 
    input   logic[L1_L2_AWT-1  : 0]                 l1i_l2__addr_i,   
    input   logic                                   lcarb_l2c__cmd_ready_i,
    input   logic                                   lcarb_l2c__cmd_done_i,
    input   csr_bus_req_t                           csr_l2c__bus_req, 
    output  csr_bus_rsp_t                           l2c_csr__bus_rsp,
    output  logic                                   l2c_csr__csr_finish_o,
    output  logic[1:0]                              chan_use_dly1_o,                     // channel select
    output  logic                                   l1_l2_rwen_back_hit_o,          // l2 to l1 hit or data
    output  logic                                   l1_l2_rwen_back_first_data_o,                   
    output  logic                                   l1_l2_ren_back_second_data_o,                   
    output  logic                                   l1_l2_ren_use_o,                // control to data rw addr info
    output  logic                                   l1_l2_wen_use_o,
    output  logic[L1_L2_AWT-1:0]                    l1_l2_addr_use_o,
    input   logic                                   hit_reuslt_i,                   // data to control suc_fsm hit info
    input   logic                                   suc_rhit_wb_fifo_exist_i, 
    input   logic                                   suc_rhit_way_dataram_busy_i, 
    output  logic[L1_L2_AWT-1: 0]                   rd_miss_addr_o,
    output  logic                                   rm_rall_tag_vld_dty_act_o,
    output  logic                                   rm_vtm_dty_or_not_act_o,
    output  logic                                   rm_vtm_dty_clear_vld_act_o,
    output  logic                                   rm_dty_w_ndma_cfg_act_o,
    output  logic                                   rm_dty_w_ndma_wait_act_o,
    output  logic                                   rm_r_ndma_cfg_act_o,
    output  logic                                   rm_r_ndma_cfg_wait_o,
    output  logic                                   rm_vtm_set_vd_act_o,
    output  logic                                   rm_end_act_o,
    input   logic                                   rm_vtm_dirty_i,
    output  logic                                   whm_rall_tag_vld_dty_lru_act_o,  // updata_fsm write hit of miss flow
    output  logic                                   whm_hit_or_not_act_o,
    output  logic                                   whm_clear_vld_r_wb_act_o,
    input   logic                                   whm_vtm_is_dirty_i,
    output  logic                                   whm_dty_w_ndma_cfg_act_o,
    output  logic                                   whm_dty_w_ndma_wait_act_o,
    output  logic                                   whm_r_ndma_cfg_act_o,
    output  logic                                   whm_r_ndma_wait_act_o,
    output  logic                                   whm_miss_set_vld_act_o,
    output  logic                                   whm_hit_set_dty_act_o,
    output  logic                                   whm_end_act_o,
    input   logic                                   whm_hit_i,
    input   logic [L1_L2_AWT-1: 0]                  whm_miss_addr_from_wb_fifo_i,
    input   logic                                   write_buffer_fifo_empty_i,
    output  logic                                   csr_r_tag_vld_act_dty_o,
    output  logic                                   csr_r_cmp_act_o,
    output  logic                                   csr_rwb_act_o,
    output  logic                                   csr_hit_or_not_act_o,
    output  logic                                   csr_w_ndma_cfg_pre_two_clk_act_o,
    output  logic                                   csr_w_ndma_cfg_act_o,
    output  logic                                   csr_w_ndma_wait_act_o,
    output  logic                                   csr_clr_vld_if_need_act_o ,
    input   logic                                   csr_hit_i,
    input   logic                                   csr_hit_dty_i,
    input   logic                                   csr_wb_exist_i,
    output  logic[2:0]                              csr_model_o,
    output  logic[31:0]                             csr_addr_set_way_o

);   


    localparam                                       CHAN_NO   =  2'b00,// no req from l1i or l1d
                                                     CHAN_I_R  =  2'b01,// selected the l1i read response
                                                     CHAN_D_R  =  2'b10,// selected the l1d read response
                                                     CHAN_D_W  =  2'b11;// selected the l1d write response
    localparam                                       CSR_MODEL_clr_vld_all             = 3'b000,
                                                     CSR_MODEL_clr_vld_addr            = 3'b001,
                                                     CSR_MODEL_clr_vld_set_way         = 3'b010,
                                                     CSR_MODEL_wr_back_addr            = 3'b011,
                                                     CSR_MODEL_wr_back_set_way         = 3'b100,
                                                     CSR_MODEL_wr_back_clr_vld_addr    = 3'b101,
                                                     CSR_MODEL_wr_back_clr_vld_set_way = 3'b110;
    localparam                                       CSR_REG_DWTH = 32;
    localparam                                       CSR_REG_AWTH = 12;
    localparam                                       CSR_REG_NUM  = 16;

    localparam                                       CSR_REG_ADDR_HIGH_BITS   = 8'h7f; 
    localparam                                       CSR_REG_DEF_START        = 4'h0;
    localparam                                       CSR_REG_DEF_FINISH_FLAG  = 4'h1;
    localparam                                       CSR_REG_DEF_ADDR_SET_WAY = 4'h2;
    localparam                                       CSR_REG_DEF_MODEL        = 4'h3;

    localparam                                       TAG_WTH                             = 18,// 17
                                                     INDEX_WTH                           = 2, // 3
                                                     OFT_WTH                             = 12;
//=============================================================================
// variables declaration
//=============================================================================
    logic                                            id_rndrbn_fsm_flag;
    logic[L1_L2_AWT + L1_L2_DWT-1:0]                 wb_fifo_wr_data;  
    logic                                            wb_fifo_wr_en;
    logic                                            wb_fifo_full;                      
    logic[L1_L2_AWT + L1_L2_DWT-1:0]                 wb_fifo_rd_data;
    logic                                            wb_fifo_rd_en;
    logic                                            wb_fifo_empty;
    logic                                            rd_miss;
    logic                                            rd_miss_d0;
    logic                                            rd_miss_wb_exist;
    logic                                            rd_miss_way_dataram_busy;
    logic                                            hit_reuslt_d0;
    logic                                            suc_rhit_wb_fifo_exist_d0;
    logic                                            suc_rhit_way_dataram_busy_d0;
    logic                                            hit_result_dly1, hit_result_dly2;
    logic[1:0]                                       chan_use,chan_use_dly1, chan_use_dly2, chan_use_dly3; 
    logic                                            suc_fsm_rall_tagram_vld_wb ;
    logic                                            id_both_en;
    logic                                            id_both_en_d0;
    logic                                            rd_miss_flag_clr;
    logic                                            rd_miss_flag_set;
    logic[L1_L2_AWT:0]                               rd_miss_addr_reg;// must stable in the whole rd miss ,it always use in data path
    logic                                            l1_l2_ren_use_d0,l1_l2_ren_use_d1;
    logic[L1_L2_AWT-1: 0]                            l1_l2_addr_use_d0,l1_l2_addr_use_d1,l1_l2_addr_use_d2;
    logic                                            rd_miss_add_equ_l1_l2_addr_use_d0;
    logic                                            wr_miss_add_equ_l1_l2_addr_use_d0;
    logic                                            wr_miss_add_equ_l1_l2_addr_use_d1;
    logic                                            update_fsm_cs_equ_wait0;
    logic                                            rm_vtm_dirty_d0;
    logic                                            whm_hit_d0;
    logic                                            whm_vtm_is_dirty_d0;
    logic                                            csr_hit_d0;
    logic                                            csr_hit_dty_d0;
    logic                                            csr_wb_exist_d0;
    logic[CSR_REG_DWTH-1:0]                          csr_slave_reg                           [CSR_REG_NUM-1:0];
    logic[CSR_REG_DWTH-1:0]                          csr_slave_reg_r                         [CSR_REG_NUM-1:0];
    logic                                            csr_l2c__csr_re_d0;
    logic                                            csr_l2c__csr_re_d1;
    logic[CSR_L2C__ADDR_WTH-1:0]                     csr_l2c__csr_re_addr_d0;
    logic[CSR_L2C__ADDR_WTH-1:0]                     csr_l2c__csr_re_addr_d1;
    logic                                            csr_fsm_not_wr_back;
    logic                                            csr_start_pulse;
    /*
    update_fsm : three condition
    1 read miss 
    2 write miss 
    3 write hit 
    update operation
    */
    enum { UPDATE_FSM_IDEAL,  //
        UPDATE_FSM_WAIT0_RD_MISS_PULSE,  //
        UPDATE_FSM_WAIT1_RD_MISS_PULSE,  //

        UPDATE_FSM_RM_LOCK_MISS_ADDR,  //
        UPDATE_FSM_RM_RALL_TAG_VLD_DTY,                 // read lru get the victim cache line
        UPDATE_FSM_RM_DTY_OR_NOT,                       // vtm line is dirty or not
        UPDATE_FSM_RM_DTY_OR_NOT_WAIT,                  // vtm line is dirty or not
        UPDATE_FSM_RM_DTY_CLR_VLD,                      // clr vtm line valid bit to update vtm line
        UPDATE_FSM_RM_DTY_W_NDMA_CFG,                   // write noc dma configure dma old vtm line data out to ddr
        UPDATE_FSM_RM_DTY_W_NDMA_WAIT,                  // wait write dam trans over
        UPDATE_FSM_RM_R_NDMA_CFG,                       // read noc dam to get new data to the line, configure dma
        UPDATE_FSM_RM_R_NDMA_WAIT,                      // wait read dma trans over
        UPDATE_FSM_RM_SET_VLD,                          // 1 set valid bit  2 write tag ram  3 mark not dirty
        UPDATE_FSM_RM_END_WAIT0,                        // end to wait state
        UPDATE_FSM_RM_END_WAIT1,                        // end to wait state

        UPDATE_FSM_WMH_RALL_TAG_VLD_DTY_LRU,            // read the tag ram for hit
        UPDATE_FSM_WMH_HIT_OR_NOT,                      // read hit bit, hit or not?
        UPDATE_FSM_WMH_HIT_OR_NOT_WAIT0,                // read hit bit, hit or not?
        UPDATE_FSM_WMH_HIT_OR_NOT_WAIT1,                // read hit bit, hit or not?
        UPDATE_FSM_WMH_CLR_VLD_R_WB,                    // clr valid bit and read write buffer
        UPDATE_FSM_WMH_CLR_VLD_R_WB_WAIT,               // clr valid bit and read write buffer
        UPDATE_FSM_WMH_DTY_W_NDMA_CFG,                  // dirty  w dma configure
        UPDATE_FSM_WMH_DTY_W_NDMA_WAIT,                 // dirty w dma wait
        UPDATE_FSM_WMH_R_NDMA_CFG,                      // read dma configure
        UPDATE_FSM_WMH_R_NDMA_WAIT,                     // read dma data wait
        UPDATE_FSM_WMH_SET_VLD,                         // 1 set valid 2 write tag ram 3 write data(w 4B data) ram 3 mark dirty 
        UPDATE_FSM_WMH_END,                             // 1 set valid 2 write tag ram 3 write data(w 4B data) ram 3 mark dirty 
    
        UPDATE_FSM_WMH_HIT_SET_DTY,                     // 1 write data ram 2 dirty 3 read wb_fifo

        // csr task
        CSR_FSM_R_TAG_LVD_DTY,                                   // read the tag ram get the tag value and cmp resutl
        CSR_FSM_R_CMP,                                   // read the tag ram get the tag value and cmp resutl
        CSR_FSM_R_WB,                                    // read the tag ram get the tag value and cmp resutl
        CSR_FSM_HIT_OR_NOT_WAIT,                   // addr: vld+wb+tag_cmp_rslt -> hit?  set/way: vld+wb hit?
        CSR_FSM_HIT_OR_NOT_WAIT0,                   // addr: vld+wb+tag_cmp_rslt -> hit?  set/way: vld+wb hit?
        CSR_FSM_HIT_OR_NOT_WAIT1,                   // addr: vld+wb+tag_cmp_rslt -> hit?  set/way: vld+wb hit?
        CSR_FSM_HIT_OR_NOT_WAIT2,                   // addr: vld+wb+tag_cmp_rslt -> hit?  set/way: vld+wb hit?
        CSR_FSM_HIT_OR_NOT,                        // addr: vld+wb+tag_cmp_rslt -> hit?  set/way: vld+wb hit?
        CSR_FSM_W_NDMA_CFG,                             // write noc dma configure
        CSR_FSM_W_NDMA_WAIT,                            // wait w noc dma data
        CSR_FSM_CLR_VLD_IF_NEED,                        // clear valid reg if need
        CSR_FSM_END

    }   update_fsm_cs,update_fsm_ns;      

    enum {  ID_RNDRBN_FSM_I,                            // if l1i and l1d request at same time, l1i got responsed  
            ID_RNDRBN_FSM_D}                            // if l1i and l1d request at same time, l1d got responsed
            id_rndrbn_fsm;


    enum {  SUC_FSM_IDEAL,                              // ideal for the fsm
            SUC_FSM_TAG_HIT,                            // read the tag ram and write buffer fifo generate suc 
            SUC_FSM_DAT_ACS0,                           // data access, read or write data lower 32B
            SUC_FSM_DAT_ACS1                            // data access, read or write data higher 32B
            } suc_fsm;                                  // data access, read or write data 

            
            

    //=============================================================================
    // suc fsm and id_rndrbn_fsm -> chan_use signal
    //=============================================================================
    /*
    SUC_FSM :  record the three state of hit or write not full progress 

                if:l1_rw_en
    SUC_FSM_IDEAL   ->   SUC_FSM_TAG_HIT   ->   SUC_FSM_DAT_ACES
            <--------------------------------------
    */

    assign suc_fsm_rall_tagram_vld_wb = (suc_fsm == SUC_FSM_IDEAL) && (l1i_l2__rd_en_i |  l1d_l2__rd_en_i);

    always_ff @(posedge clk_i, `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            suc_fsm <= SUC_FSM_IDEAL;
        end else begin
            if( suc_fsm == SUC_FSM_IDEAL && (l1i_l2__rd_en_i |  l1d_l2__rd_en_i ) ) begin
                suc_fsm <= SUC_FSM_TAG_HIT;
            end else if( suc_fsm == SUC_FSM_TAG_HIT ) begin
                suc_fsm <= SUC_FSM_IDEAL;
            end
        end
    end
    always_ff @(posedge clk_i, `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            hit_result_dly1 <= 1'b0;
            hit_result_dly2 <= 1'b0;
        end else begin
            hit_result_dly1 <= hit_reuslt_i;
            hit_result_dly2 <= hit_result_dly1 && ((chan_use_dly2 == CHAN_I_R) || (chan_use_dly2 == CHAN_D_R));
        end
    end
    assign l1_l2_rwen_back_hit_o        = (suc_fsm == SUC_FSM_TAG_HIT);
    assign l1_l2_rwen_back_first_data_o = hit_result_dly1;
    assign l1_l2_ren_back_second_data_o = hit_result_dly2;

    //=============================================================================================//
    // id_rndrbn_fsm : when i$ and d$ access l2$ at same time we select i first, next time 
    //                 select d first
    //=============================================================================================//

    /*
    id_rndrbn_fsm:
                if: i_d_both_en at same time
                    --> 
    ID_RNDRBN_FSM_I            ID_RNDRBN_FSM_D   
                    <--
                if: i_d_both_en at same time
    */

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            id_rndrbn_fsm    <= ID_RNDRBN_FSM_I;
            id_rndrbn_fsm_flag <= 1'b1;
            end
        else if( id_rndrbn_fsm == ID_RNDRBN_FSM_I && id_both_en && id_rndrbn_fsm_flag ) 
            begin
            id_rndrbn_fsm    <= ID_RNDRBN_FSM_D;
            id_rndrbn_fsm_flag <= 1'b0;
            end
        else if( id_rndrbn_fsm == ID_RNDRBN_FSM_D && id_both_en && id_rndrbn_fsm_flag) 
            begin   
            id_rndrbn_fsm    <= ID_RNDRBN_FSM_I;
            id_rndrbn_fsm_flag <= 1'b0;
            end
        else begin
            id_rndrbn_fsm_flag <= 1'b1;
            end
    end

    assign  id_both_en = l1i_l2__rd_en_i & l1d_l2__rd_en_i  ;
    
    always_comb
    begin
        if(id_both_en)// both en depend on the  id_rndrbn_fsm
            chan_use = (id_rndrbn_fsm==ID_RNDRBN_FSM_I) ? CHAN_I_R : CHAN_D_R ; 
        else if( l1i_l2__rd_en_i )
                chan_use = CHAN_I_R;
        else if( l1d_l2__rd_en_i )
                chan_use = CHAN_D_R;
        else 
                chan_use = CHAN_NO;
    end

    always_ff@(posedge clk_i, `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            chan_use_dly1 <= CHAN_NO;
            chan_use_dly2 <= CHAN_NO;
            chan_use_dly3 <= CHAN_NO;
        end else begin
            if(suc_fsm == SUC_FSM_IDEAL && (  l1i_l2__rd_en_i |  l1d_l2__rd_en_i  )) begin
                chan_use_dly1 <= chan_use;
            end
            chan_use_dly2 <= chan_use_dly1;
            chan_use_dly3 <= chan_use_dly2;
        end
    end


    assign  l1_l2_ren_use_o  =    ((l1d_l2__rd_en_i||l1i_l2__rd_en_i) && suc_fsm == SUC_FSM_IDEAL);  
/*
*
    assign  l1_l2_ren_use_o  =  (chan_use == CHAN_I_R) ? (l1i_l2__rd_en_i && suc_fsm == SUC_FSM_IDEAL)  :
                                (chan_use == CHAN_D_R) ? (l1d_l2__rd_en_i && suc_fsm == SUC_FSM_IDEAL) : 1'b0;
    * */
    assign  l1_l2_wen_use_o  = l1d_l2__wr_en_i ;         
                            

    assign  l1_l2_addr_use_o = (chan_use == CHAN_I_R) ? l1i_l2__addr_i : l1d_l2__addr_i ;



    assign  chan_use_dly1_o =  chan_use_dly1;
    /*assign  chan_use_o = chan_req_puls_l1_l2 ? chan_use
                       : l1_l2_rwen_back_hit_o ? chan_use_dly1
                       : l1_l2_rwen_back_first_data_o ? chan_use_dly2
                       : chan_use_dly3;
*/
    //assign  chan_req_puls_l1_l2_o = chan_req_puls_l1_l2 ;
    /*
    read miss reg and flag
    used for register the read miss operation 
    because the main_fsm most of time are process of write buffer data
    can not in the  IDEAL state to detect the read miss 
    */



    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            rd_miss_addr_reg      <= {1'b1,{L1_L2_AWT{1'b0}}};
            end                      // not reg same read address  for the rd miss fsm
        else if( update_fsm_cs == UPDATE_FSM_RM_LOCK_MISS_ADDR ) 
            begin
            rd_miss_addr_reg      <= {1'b0,l1_l2_addr_use_d2} ;
            end
    end

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            l1_l2_ren_use_d0 <= 1'b0;
            l1_l2_ren_use_d1 <= 1'b0;
            end
        else
            begin
            l1_l2_ren_use_d0 <= l1_l2_ren_use_o;
            l1_l2_ren_use_d1 <= l1_l2_ren_use_d0;
            end
    end

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            l1_l2_addr_use_d0 <= 1'b0; 
            l1_l2_addr_use_d1 <= 1'b0; 
            l1_l2_addr_use_d2 <= 1'b0; 
            end
        else
            begin
            l1_l2_addr_use_d0 <= l1_l2_addr_use_o;
            l1_l2_addr_use_d1 <= l1_l2_addr_use_d0;
            l1_l2_addr_use_d2 <= l1_l2_addr_use_d1;
            end
    end


    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            hit_reuslt_d0 <= 1'b0;
            suc_rhit_wb_fifo_exist_d0 <= 1'b0;
            suc_rhit_way_dataram_busy_d0 <= 1'b0;
            end
        else
            begin
            hit_reuslt_d0 <= hit_reuslt_i;
            suc_rhit_wb_fifo_exist_d0 <= suc_rhit_wb_fifo_exist_i;
            suc_rhit_way_dataram_busy_d0 <= suc_rhit_way_dataram_busy_i;
            end
    end


    assign      rd_miss_d0               = l1_l2_ren_use_d1  &&  (!hit_reuslt_d0);
    assign      rd_miss_wb_exist         = l1_l2_ren_use_d1  &&  (suc_rhit_wb_fifo_exist_d0);
    assign      rd_miss_way_dataram_busy = l1_l2_ren_use_d1  &&  (suc_rhit_way_dataram_busy_d0);
    //=============================================================================================//
    // update_fsm : when read miss or write hit/miss(read addr data from write buffer)
    //=============================================================================================//

    // write hit miss trigger signal to data path
    assign  rd_miss_addr_o                  = rd_miss_addr_reg[L1_L2_AWT-1: 0];    
    assign  rm_rall_tag_vld_dty_act_o       = (update_fsm_cs==UPDATE_FSM_RM_RALL_TAG_VLD_DTY && !suc_fsm_rall_tagram_vld_wb );
    assign  rm_vtm_dty_or_not_act_o         = (update_fsm_cs == UPDATE_FSM_RM_DTY_OR_NOT) ;
    assign  rm_dty_w_ndma_cfg_act_o         = (update_fsm_cs==UPDATE_FSM_RM_DTY_W_NDMA_CFG);
    assign  rm_dty_w_ndma_wait_act_o        = (update_fsm_cs==UPDATE_FSM_RM_DTY_W_NDMA_WAIT);
    assign  rm_r_ndma_cfg_act_o             = (update_fsm_cs==UPDATE_FSM_RM_R_NDMA_CFG);
    assign  rm_r_ndma_cfg_wait_o            = (update_fsm_cs==UPDATE_FSM_RM_R_NDMA_WAIT);
    assign  rm_vtm_dty_clear_vld_act_o      = (update_fsm_cs == UPDATE_FSM_RM_DTY_CLR_VLD);
    assign  rm_vtm_set_vd_act_o             = (update_fsm_cs == UPDATE_FSM_RM_SET_VLD);
    assign  rm_end_act_o                    = (update_fsm_cs == UPDATE_FSM_RM_END_WAIT1);

    always_ff @(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            rm_vtm_dirty_d0     <= 1'b0;
            whm_hit_d0          <= 1'b0;
            whm_vtm_is_dirty_d0 <= 1'b0;
            end
        else 
            begin
            rm_vtm_dirty_d0     <= rm_vtm_dirty_i;
            whm_hit_d0          <= whm_hit_i;
            whm_vtm_is_dirty_d0 <= whm_vtm_is_dirty_i;
            end
    end

    always_ff @(posedge clk_i, `RST_DECL(rst_i))
    begin
    if(`RST_TRUE(rst_i))
        begin
        update_fsm_cs    <= UPDATE_FSM_IDEAL;
        end
    else
        begin
        update_fsm_cs    <= update_fsm_ns;
        end
    end
        
    always_comb   
    begin
    update_fsm_ns = UPDATE_FSM_IDEAL;
    case(update_fsm_cs)
    UPDATE_FSM_IDEAL    :
        begin
            update_fsm_ns = UPDATE_FSM_WAIT0_RD_MISS_PULSE;
        end
    UPDATE_FSM_WAIT0_RD_MISS_PULSE:
        begin
        if(csr_start_pulse)
            update_fsm_ns = CSR_FSM_R_TAG_LVD_DTY;
        else if(rd_miss_d0 && !rd_miss_wb_exist && !rd_miss_way_dataram_busy) // first check read miss is set ?
            update_fsm_ns = UPDATE_FSM_RM_LOCK_MISS_ADDR;
        else 
            update_fsm_ns = UPDATE_FSM_WAIT1_RD_MISS_PULSE;
        end
    UPDATE_FSM_WAIT1_RD_MISS_PULSE   :
        begin
        if(csr_start_pulse)
            update_fsm_ns = CSR_FSM_R_TAG_LVD_DTY;
        else if(rd_miss_d0 && !rd_miss_wb_exist && !rd_miss_way_dataram_busy) // seconde check read miss is set , because the hit fsm is two state, once check probably miss a pulse?
            update_fsm_ns = UPDATE_FSM_RM_LOCK_MISS_ADDR;
        else if(!write_buffer_fifo_empty_i)
            update_fsm_ns = UPDATE_FSM_WMH_RALL_TAG_VLD_DTY_LRU;
        else 
            update_fsm_ns = UPDATE_FSM_IDEAL;
        end
    UPDATE_FSM_RM_LOCK_MISS_ADDR:                                         
        begin                 
            update_fsm_ns = UPDATE_FSM_RM_RALL_TAG_VLD_DTY;
        end   
    UPDATE_FSM_RM_RALL_TAG_VLD_DTY    :
        begin                 
        if(suc_fsm_rall_tagram_vld_wb)
            update_fsm_ns = UPDATE_FSM_RM_RALL_TAG_VLD_DTY;
        else             
            update_fsm_ns = UPDATE_FSM_RM_DTY_OR_NOT;
        end  
    UPDATE_FSM_RM_DTY_OR_NOT:                                         
        begin                 
            update_fsm_ns = UPDATE_FSM_RM_DTY_OR_NOT_WAIT;
        end   
    UPDATE_FSM_RM_DTY_OR_NOT_WAIT:                                         
        begin                
        if(rm_vtm_dirty_d0)                     
            update_fsm_ns = UPDATE_FSM_RM_DTY_W_NDMA_CFG;        
        else                                      
            update_fsm_ns = UPDATE_FSM_RM_DTY_CLR_VLD;
        end                                                         
    UPDATE_FSM_RM_DTY_W_NDMA_CFG    :                      
        begin                                       
        if(lcarb_l2c__cmd_ready_i)
            update_fsm_ns = UPDATE_FSM_RM_DTY_W_NDMA_WAIT;  
        else                                    
            update_fsm_ns = UPDATE_FSM_RM_DTY_W_NDMA_CFG;   
        end                                         
    UPDATE_FSM_RM_DTY_W_NDMA_WAIT:                   
        begin                                       
        if(lcarb_l2c__cmd_done_i)
            update_fsm_ns = UPDATE_FSM_RM_R_NDMA_CFG;       
        else                                       
            update_fsm_ns = UPDATE_FSM_RM_DTY_W_NDMA_WAIT;   
        end     
    UPDATE_FSM_RM_DTY_CLR_VLD:                         
        begin                                     
        update_fsm_ns = UPDATE_FSM_RM_R_NDMA_CFG;       
        end                                           
    UPDATE_FSM_RM_R_NDMA_CFG:                        
        begin                                      
        if(lcarb_l2c__cmd_ready_i )
            update_fsm_ns = UPDATE_FSM_RM_R_NDMA_WAIT;                                          
        else                                                                
            update_fsm_ns = UPDATE_FSM_RM_R_NDMA_CFG;                 
        end                                                          
    UPDATE_FSM_RM_R_NDMA_WAIT:                                    
        begin                                                  
        if(lcarb_l2c__cmd_done_i )
            update_fsm_ns = UPDATE_FSM_RM_SET_VLD;                                 
        else                                                   
            update_fsm_ns = UPDATE_FSM_RM_R_NDMA_WAIT;                                    
        end   
    UPDATE_FSM_RM_SET_VLD:                                       
        begin
            update_fsm_ns = UPDATE_FSM_RM_END_WAIT0;
        end                                                                 
    UPDATE_FSM_RM_END_WAIT0:                                       
        begin
            update_fsm_ns = UPDATE_FSM_RM_END_WAIT1;
        end
    UPDATE_FSM_RM_END_WAIT1:                                       
        begin
            update_fsm_ns = UPDATE_FSM_IDEAL;
        end
    /*******************for write miss or hit**********************/
    UPDATE_FSM_WMH_RALL_TAG_VLD_DTY_LRU:
        begin
        if(  suc_fsm_rall_tagram_vld_wb  ) // if suc fsm read tag ram, it will collision  avoid
            update_fsm_ns = UPDATE_FSM_WMH_RALL_TAG_VLD_DTY_LRU;
        else
            update_fsm_ns = UPDATE_FSM_WMH_HIT_OR_NOT;
        end
    UPDATE_FSM_WMH_HIT_OR_NOT:                                         
        begin 
        update_fsm_ns = UPDATE_FSM_WMH_HIT_OR_NOT_WAIT0;
        end
    UPDATE_FSM_WMH_HIT_OR_NOT_WAIT0:                                         
        begin 
        if(  whm_hit_d0  )                                            
            update_fsm_ns = UPDATE_FSM_WMH_HIT_OR_NOT_WAIT1;                      
        else
            update_fsm_ns = UPDATE_FSM_WMH_CLR_VLD_R_WB;
        end
    UPDATE_FSM_WMH_HIT_OR_NOT_WAIT1:                                         
        begin 
        update_fsm_ns = UPDATE_FSM_WMH_HIT_SET_DTY;
        end
    UPDATE_FSM_WMH_CLR_VLD_R_WB:                           
        begin
        update_fsm_ns = UPDATE_FSM_WMH_CLR_VLD_R_WB_WAIT;
        end
    UPDATE_FSM_WMH_CLR_VLD_R_WB_WAIT:                           
        begin
        if(whm_vtm_is_dirty_d0)  //vtm_line_vld==1 && vtm_line_dirty==1 
            update_fsm_ns = UPDATE_FSM_WMH_DTY_W_NDMA_CFG;
        else
            update_fsm_ns = UPDATE_FSM_WMH_R_NDMA_CFG;
        end
    UPDATE_FSM_WMH_DTY_W_NDMA_CFG:                           // w dma
        begin                                                  
        if(lcarb_l2c__cmd_ready_i)
            update_fsm_ns = UPDATE_FSM_WMH_DTY_W_NDMA_WAIT;                                          
        else                                                                
            update_fsm_ns = UPDATE_FSM_WMH_DTY_W_NDMA_CFG;                 
        end    
    UPDATE_FSM_WMH_DTY_W_NDMA_WAIT:
        begin
        if(lcarb_l2c__cmd_done_i )
            update_fsm_ns = UPDATE_FSM_WMH_R_NDMA_CFG;
        else
            update_fsm_ns = UPDATE_FSM_WMH_DTY_W_NDMA_WAIT;
        end
    UPDATE_FSM_WMH_R_NDMA_CFG:                              // r dma
        begin                                                  
        if(lcarb_l2c__cmd_ready_i)
            update_fsm_ns = UPDATE_FSM_WMH_R_NDMA_WAIT;                                          
        else                                                                
            update_fsm_ns = UPDATE_FSM_WMH_R_NDMA_CFG;                 
        end    
    UPDATE_FSM_WMH_R_NDMA_WAIT:
        begin
        if(lcarb_l2c__cmd_done_i )
            update_fsm_ns = UPDATE_FSM_WMH_SET_VLD;
        else
            update_fsm_ns = UPDATE_FSM_WMH_R_NDMA_WAIT;
        end
    UPDATE_FSM_WMH_SET_VLD:
        begin
            update_fsm_ns = UPDATE_FSM_WMH_END;
        end
    UPDATE_FSM_WMH_HIT_SET_DTY:
        begin
        update_fsm_ns = UPDATE_FSM_WMH_END;
        end
    UPDATE_FSM_WMH_END:
        begin
        update_fsm_ns = UPDATE_FSM_IDEAL;
        end
    /************************************below is csr task***************************************/
    CSR_FSM_R_TAG_LVD_DTY:
        begin
        if(  suc_fsm_rall_tagram_vld_wb  ) // if suc fsm read tag ram, it will collision  avoid
            update_fsm_ns = CSR_FSM_R_TAG_LVD_DTY;
        else
            update_fsm_ns = CSR_FSM_R_CMP;
        end
    CSR_FSM_R_CMP:
        begin
        update_fsm_ns = CSR_FSM_R_WB;
        end
    CSR_FSM_R_WB:
        begin
        if(  suc_fsm_rall_tagram_vld_wb  ) // if suc fsm read tag ram, it will collision  avoid
            update_fsm_ns = CSR_FSM_R_WB;
        else
            update_fsm_ns = CSR_FSM_HIT_OR_NOT;
        end
    CSR_FSM_HIT_OR_NOT:
        begin
            update_fsm_ns = CSR_FSM_HIT_OR_NOT_WAIT;
        end
    CSR_FSM_HIT_OR_NOT_WAIT:
            begin
            if(csr_wb_exist_d0)
                update_fsm_ns = UPDATE_FSM_WMH_RALL_TAG_VLD_DTY_LRU;
            else if(csr_hit_d0 && csr_fsm_not_wr_back )
                update_fsm_ns = CSR_FSM_CLR_VLD_IF_NEED;
            else if(csr_hit_dty_d0 && !csr_fsm_not_wr_back )
                update_fsm_ns = CSR_FSM_HIT_OR_NOT_WAIT0;
            else
                update_fsm_ns = CSR_FSM_END;
            end
    CSR_FSM_HIT_OR_NOT_WAIT0:
        begin
            update_fsm_ns = CSR_FSM_HIT_OR_NOT_WAIT1;
        end
    CSR_FSM_HIT_OR_NOT_WAIT1:
        begin
            update_fsm_ns = CSR_FSM_HIT_OR_NOT_WAIT2;
        end
    CSR_FSM_HIT_OR_NOT_WAIT2:
        begin
            update_fsm_ns = CSR_FSM_W_NDMA_CFG;
        end
    CSR_FSM_W_NDMA_CFG: 
            begin                                                
            if(lcarb_l2c__cmd_ready_i)
                update_fsm_ns = CSR_FSM_W_NDMA_WAIT;                                          
            else                                                                
                update_fsm_ns = CSR_FSM_W_NDMA_CFG;                 
            end    
    CSR_FSM_W_NDMA_WAIT:
            begin
            if(lcarb_l2c__cmd_done_i)
                update_fsm_ns = CSR_FSM_CLR_VLD_IF_NEED;                                          
            else                                                                
                update_fsm_ns = CSR_FSM_W_NDMA_WAIT;                 
            end 
    CSR_FSM_CLR_VLD_IF_NEED:
            begin
            update_fsm_ns = CSR_FSM_END;
            end
    CSR_FSM_END:
            begin
            update_fsm_ns = UPDATE_FSM_IDEAL;
            end                                   
    default    :    
        begin
        update_fsm_ns = UPDATE_FSM_IDEAL;
        end
        endcase
    end

    // write hit miss trigger signal to data path
    assign  whm_rall_tag_vld_dty_lru_act_o      = ( update_fsm_cs == UPDATE_FSM_WMH_RALL_TAG_VLD_DTY_LRU  ) && ( !suc_fsm_rall_tagram_vld_wb );
    assign  whm_hit_or_not_act_o                = ( update_fsm_cs == UPDATE_FSM_WMH_HIT_OR_NOT  );
    assign  whm_dty_w_ndma_cfg_act_o            = ( update_fsm_cs ==  UPDATE_FSM_WMH_DTY_W_NDMA_CFG); 
    assign  whm_dty_w_ndma_wait_act_o           = ( update_fsm_cs == UPDATE_FSM_WMH_DTY_W_NDMA_WAIT );
    assign  whm_clear_vld_r_wb_act_o            = ( update_fsm_cs == UPDATE_FSM_WMH_CLR_VLD_R_WB );
    assign  whm_r_ndma_cfg_act_o                = ( update_fsm_cs == UPDATE_FSM_WMH_R_NDMA_CFG );
    assign  whm_r_ndma_wait_act_o               = ( update_fsm_cs == UPDATE_FSM_WMH_R_NDMA_WAIT );
    assign  whm_miss_set_vld_act_o              = ( update_fsm_cs == UPDATE_FSM_WMH_SET_VLD);
    assign  whm_hit_set_dty_act_o               = ( update_fsm_cs ==  UPDATE_FSM_WMH_HIT_SET_DTY);
    assign  whm_end_act_o                       = ( update_fsm_cs ==  UPDATE_FSM_WMH_END);
        


    assign    csr_r_tag_vld_act_dty_o = (update_fsm_cs == CSR_FSM_R_TAG_LVD_DTY);
    assign    csr_r_cmp_act_o = (update_fsm_cs == CSR_FSM_R_CMP);
    assign    csr_rwb_act_o = (update_fsm_cs == CSR_FSM_R_WB);
    assign    csr_hit_or_not_act_o = (update_fsm_cs == CSR_FSM_HIT_OR_NOT);
    assign    csr_w_ndma_cfg_pre_two_clk_act_o = (update_fsm_cs == CSR_FSM_HIT_OR_NOT_WAIT0);
    assign    csr_w_ndma_cfg_act_o = (update_fsm_cs == CSR_FSM_W_NDMA_CFG);
    assign    csr_w_ndma_wait_act_o = (update_fsm_cs == CSR_FSM_W_NDMA_WAIT);
    assign    csr_clr_vld_if_need_act_o = (update_fsm_cs == CSR_FSM_CLR_VLD_IF_NEED);

    //=============================================================================================//
    // csr_fsm : 8 control mode for csr interface
    //=============================================================================================//



    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
    if(`RST_TRUE(rst_i))
        begin
        for(int i=0;i<CSR_REG_NUM;i=i+1)
            begin
            csr_slave_reg [i] <= {CSR_REG_DWTH{1'b0}}; 
            end
        end
    else if(csr_l2c__bus_req.wr_en && csr_l2c__bus_req.waddr[CSR_REG_AWTH-1:4] == CSR_REG_ADDR_HIGH_BITS)
        begin
        for(int i=0;i<CSR_REG_NUM;i=i+1)
            begin
            if(csr_l2c__bus_req.waddr[3:0] == i )
                csr_slave_reg [i] <= csr_l2c__bus_req.wdata; 
            end
        end 
    end

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
    if(`RST_TRUE(rst_i))
        begin
            for(int i=0;i<CSR_REG_NUM;i=i+1)
            begin
            csr_slave_reg_r[i] <= {CSR_REG_DWTH{1'b0}}; 
            end
            csr_start_pulse <= 1'b0;
            l2c_csr__csr_finish_o<=1'b0;
        end
    else if(csr_l2c__bus_req.wr_en && csr_l2c__bus_req.waddr[CSR_REG_AWTH-1:0] == {CSR_REG_ADDR_HIGH_BITS,CSR_REG_DEF_START} && csr_l2c__bus_req.wdata[0] == 1)
    begin
        for(int i=0;i<CSR_REG_NUM;i=i+1)
            begin
            csr_slave_reg_r[i] <= csr_slave_reg[i];
            end
        csr_start_pulse <= 1'b1;
        l2c_csr__csr_finish_o <= 1'b0;
        end 
    else if(csr_l2c__bus_req.wr_en && csr_l2c__bus_req.waddr[CSR_REG_AWTH-1:0] == {CSR_REG_ADDR_HIGH_BITS,CSR_REG_DEF_FINISH_FLAG} )// write busy bit
        begin
        l2c_csr__csr_finish_o <= csr_l2c__bus_req.wdata[0];//  csr_l2c__bus_req.wdata[0] is the finish flag so ~csr_l2c__bus_req.wdata[0] to busy
        end
    else if(update_fsm_cs==CSR_FSM_END)
        begin
        csr_start_pulse <= 1'b0;
        l2c_csr__csr_finish_o <= 1'b1;
        end
    end
    assign  csr_model_o        = csr_slave_reg_r[CSR_REG_DEF_MODEL][2:0];
    assign  csr_addr_set_way_o = csr_slave_reg_r[CSR_REG_DEF_ADDR_SET_WAY][31:0];

    //assign  l2c_csr__bus_rsp.rdata = (csr_l2c__bus_req.rd_en && csr_l2c__bus_req.raddr == {CSR_REG_ADDR_HIGH_BITS,CSR_REG_DEF_FINISH_FLAG}) ? {{(CSR_REG_DWTH-1){1'b0}},(~l2c_csr__csr_finish_o)} : {CSR_REG_DWTH{1'b0}};
    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            l2c_csr__bus_rsp.rdata <= {CSR_REG_DWTH{1'b0}};
            end
        else if(csr_l2c__bus_req.rd_en && csr_l2c__bus_req.raddr == {CSR_REG_ADDR_HIGH_BITS,CSR_REG_DEF_FINISH_FLAG}) begin
            l2c_csr__bus_rsp.rdata <= {{(CSR_REG_DWTH-1){1'b0}},(l2c_csr__csr_finish_o)};
            end
        else if(csr_l2c__bus_req.rd_en && csr_l2c__bus_req.raddr == {CSR_REG_ADDR_HIGH_BITS,CSR_REG_DEF_ADDR_SET_WAY}) begin
            l2c_csr__bus_rsp.rdata <= csr_slave_reg_r[CSR_REG_DEF_ADDR_SET_WAY][31:0];
            end
        else if(csr_l2c__bus_req.rd_en && csr_l2c__bus_req.raddr == {CSR_REG_ADDR_HIGH_BITS,CSR_REG_DEF_MODEL}) begin
            l2c_csr__bus_rsp.rdata <= csr_slave_reg_r[CSR_REG_DEF_MODEL][31:0];;
            end
    end
    // read logic 
    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            csr_l2c__csr_re_d0      <= 1'b0;
            csr_l2c__csr_re_addr_d0 <= {CSR_L2C__ADDR_WTH{1'b0}};
            csr_l2c__csr_re_d1      <= 1'b0;
            csr_l2c__csr_re_addr_d1 <= {CSR_L2C__ADDR_WTH{1'b0}};
            end
        else
            begin
            csr_l2c__csr_re_d0      <= csr_l2c__bus_req.rd_en        ;
            csr_l2c__csr_re_addr_d0 <= csr_l2c__bus_req.raddr   ;
            csr_l2c__csr_re_d1      <= csr_l2c__csr_re_d0       ;
            csr_l2c__csr_re_addr_d1 <= csr_l2c__csr_re_addr_d0  ;
            end
    end

    //assign l2c_csr__bus_rsp.rdata = csr_slave_reg_r[csr_l2c__csr_re_addr_d1];
    
    assign csr_fsm_not_wr_back    = (csr_model_o== CSR_MODEL_clr_vld_all 
                                    || csr_model_o== CSR_MODEL_clr_vld_addr 
                                    || csr_model_o== CSR_MODEL_clr_vld_set_way ) ? 1'b1 : 1'b0;



    always_ff@(posedge clk_i, `RST_DECL(rst_i))begin
        if(`RST_TRUE(rst_i))begin
            csr_hit_d0 <= 1'b0;
            csr_hit_dty_d0 <= 1'b0;
            csr_wb_exist_d0 <= 1'b0;
        end
        else begin
            csr_hit_d0<= csr_hit_i;
            csr_hit_dty_d0<= csr_hit_dty_i;
            csr_wb_exist_d0<= csr_wb_exist_i;
        end
    end

endmodule
