`timescale 1ns/1ps
`include "hpu_head.sv"
import hpu_pkg::*;


module L2_cache_data_path # (
    parameter L1_L2_AWT             = 32,     // unit Byte
    parameter L1_L2_DWT             = 4 *8,   // 4B
    parameter L2_L1_DWT             = 32*8,   // 64B
    parameter CSR_L2C__ADDR_WTH     =  12  ,
    parameter CSR_L2C__DATA_WTH     =  32,
    parameter CHAN_USE_WTH          = 2
)
(
    input  logic                            clk_i,
    input  logic                            rst_i,
    input  logic[CHAN_USE_WTH-1:0]          chan_use_dly1_i,                                     // channel select
    input  logic                            l1_l2_rwen_back_hit_i,                          // l2 to l1 hit or data
    input  logic                            l1_l2_rwen_back_first_data_i,                   
    input  logic                            l1_l2_ren_back_second_data_i,                   
    output logic                            l2_l1d__suc_o,                          // l2 to l1d read or write     
    output logic                            l2_l1d__suc_act_o,
    output logic[L2_L1_DWT-1  : 0]          l2_l1d__rdata_o, 
    output logic                            l2_l1d__rdata_act_o,  
    input  logic[L1_L2_DWT-1  : 0]          l1d_l2__wdata_i,                          
    input  logic                            l1d_l2__wdata_act_i,    
    input  logic[3:0]                       l1d_l2__wstrb_i,    
    output logic                            l2_l1i__suc_o,                                  // l2 to l1i    
    output logic                            l2_l1i__suc_act_o,      
    output logic[L2_L1_DWT-1  : 0]          l2_l1i__rdata_o,
    output logic                            l2_l1i__rdata_act_o,
    input  logic                            l1_l2_ren_use_i,                                // control to data rw addr info
    input  logic                            l1_l2_wen_use_i,
    input  logic[L1_L2_AWT-1:0]             l1_l2_addr_use_i,
    input  logic[L1_L2_AWT-1:0]             l1d_l2__addr_i,
    output logic                            hit_reuslt_o,                                   
    output logic                            suc_rhit_wb_fifo_exist_o,
    output logic                            suc_rhit_way_dataram_busy_o,
    input  logic[L1_L2_AWT-1  : 0]          rd_miss_addr_i,
    input  logic                            rm_rall_tag_vld_dty_act_i,
    input  logic                            rm_vtm_dty_or_not_act_i,
    input  logic                            rm_dty_w_ndma_cfg_act_i,
    input  logic                            rm_dty_w_ndma_wait_act_i,
    input  logic                            rm_r_ndma_cfg_act_i,
    input  logic                            rm_r_ndma_cfg_wait_i,
    input  logic                            rm_vtm_dty_clear_vld_act_i,
    input  logic                            rm_vtm_set_vd_act_i,
    input  logic                            rm_end_act_i,
    output logic                            rm_vtm_dirty_o,
    input  logic                            whm_rall_tag_vld_dty_lru_act_i,                      // updata_fsm write hit of miss flow
    input  logic                            whm_hit_or_not_act_i,
    input  logic                            whm_dty_w_ndma_cfg_act_i,
    input  logic                            whm_dty_w_ndma_wait_act_i,
    input  logic                            whm_r_ndma_cfg_act_i,
    input  logic                            whm_r_ndma_wait_act_i,
    input  logic                            whm_clear_vld_r_wb_act_i,
    output logic                            whm_vtm_is_dirty_o,
    input  logic                            whm_miss_set_vld_act_i,
    input  logic                            whm_hit_set_dty_act_i,
    input  logic                            whm_end_act_i,
    output logic                            whm_hit_o,
    output logic [L1_L2_AWT-1: 0]           whm_miss_addr_from_wb_fifo_o,
    output logic                            write_buffer_fifo_empty_o,
    input  logic                            csr_r_tag_vld_act_dty_i,
    input  logic                            csr_r_cmp_act_i,
    input  logic                            csr_rwb_act_i,
    input  logic                            csr_hit_or_not_act_i,
    input  logic                            csr_w_ndma_cfg_pre_two_clk_act_i,
    input  logic                            csr_w_ndma_cfg_act_i,
    input  logic                            csr_w_ndma_wait_act_i,
    input  logic                            csr_clr_vld_if_need_act_i,
    output logic                            csr_hit_o,
    output logic                            csr_hit_dty_o,
    output logic                            csr_wb_exist_o,
    input  logic[2:0]                       csr_model_i,
    input  logic[31:0]                      csr_addr_set_way_i,
    output ndma_cmd_t                       l2c_lcarb__cmd_o,
    output logic                            l2c_lcarb__cmd_valid_o,
    input  ndma_mem_req_t                   lcarb_l2c__mem_req_i,
    output ndma_mem_rsp_t                   l2c_lcarb__mem_rsp_o
);

    genvar                                  gi,gj,gw;
    localparam                              CHAN_NO                             = 2'b00,// no req from l1i or l1d
                                            CHAN_I_R                            = 2'b01,// selected the l1i read response
                                            CHAN_D_R                            = 2'b10,// selected the l1d read response
                                            CHAN_D_W                            = 2'b11;// selected the l1d write response
    localparam                              WAY_NUM                             = 4;
    localparam                              TAG_WTH                             = 18,// 17
                                            INDEX_WTH                           = 2, // 3
                                            OFT_WTH                             = 12;
    localparam                              DMA_ADDR_OFT_WTH                    = 6;  // 64 B
    localparam                              DATA_RAM_ADDR_OFT_WTH               = 5;  // 64 B
    localparam                              WAY_WTH                             = 2;
    localparam                              SUC_FSM_DLY                         = 3;// 0-3
    localparam                              WHM_FSM_DLY                         = 4;// 0-4
    localparam                              CSR_MODEL_clr_vld_all               = 3'b000,
                                            CSR_MODEL_clr_vld_addr              = 3'b001,
                                            CSR_MODEL_clr_vld_set_way           = 3'b010,
                                            CSR_MODEL_wr_back_addr              = 3'b011,
                                            CSR_MODEL_wr_back_set_way           = 3'b100,
                                            CSR_MODEL_wr_back_clr_vld_addr      = 3'b101,
                                            CSR_MODEL_wr_back_clr_vld_set_way   = 3'b110;
    localparam                              ndma_r_cmd                          = 2'b01;
    localparam                              ndma_w_cmd                          = 2'b00;
    localparam                              dma_tras_num_4KB                    = 4096;
    localparam                              dma_ddr_destx                       = 1  ;
    localparam                              dma_ddr_desty                       = 0  ;
    localparam                              RM_FSM_DLY=3 ; // 0-3

    logic                                   l1_l2_ren_use;
    logic                                   l1_l2_wen_use;
    logic[L1_L2_AWT-1:0]                    l1_l2_addr_use,l1_l2_addr_w_reg,l1_l2_addr_w_reg_d0;
    logic[0:0]                              vld_way_or_not              [WAY_NUM-1:0];  
    logic[0:0]                              vld_way_or_not_d0           [WAY_NUM-1:0];       
    logic[0:0]                              suc_rhit_way_reuslt         [WAY_NUM-1:0];
    logic[0:0]                              suc_rhit_way_busy           [WAY_NUM-1:0];
    logic[WAY_WTH-1:0]                      suc_rhit_way_result_encoder;
    logic                                   suc_rhit_reuslt;
    logic[WAY_WTH-1:0]                      suc_rhit_way_result_encoder_d0;
    logic                                   wb_fifo_cmp_en;
    logic[TAG_WTH+INDEX_WTH-1:0]            wb_fifo_cmp_data_a;
    logic                                   wb_fifo_cmp_result;
    logic[(L1_L2_DWT+4)-1:0]                wb_fifo_wr_data_d;                              // add the strob signal
    logic[L1_L2_AWT-1:0]                    wb_fifo_wr_data_a;
    logic                                   wb_fifo_wr_en;
    logic                                   wb_fifo_full;
    logic                                   wb_fifo_a_full;
    logic[(L1_L2_DWT+4)-1:0]                wb_fifo_rd_data_d;                              // add the strob signal
    logic[L1_L2_AWT-1:0]                    wb_fifo_rd_data_a;
    logic                                   wb_fifo_rd_en;
    logic                                   wb_fifo_empty;
    logic                                   wb_fifo_a_empty;
    logic                                   dataram_cs                  [WAY_NUM-1:0];             
    logic                                   dataram_we                  [WAY_NUM-1:0];             
    logic[8:0]                              dataram_addr                [WAY_NUM-1:0];             
    logic[255:0]                            dataram_wdata               [WAY_NUM-1:0];             
    logic[31:0]                             dataram_wdata_strob         [WAY_NUM-1:0];             
    logic[255:0]                            dataram_rdata               [WAY_NUM-1:0];             
    logic                                   tagram_wen                  [WAY_NUM-1:0];             
    logic[INDEX_WTH-1:0]                    tagram_waddr                [WAY_NUM-1:0];             
    logic[TAG_WTH-1:0]                      tagram_wdata                [WAY_NUM-1:0];             
    logic[INDEX_WTH-1:0]                    tagram_raddr                [WAY_NUM-1:0];             
    logic[TAG_WTH:0]                        tagram_rdata                [WAY_NUM-1:0];   
    logic                                   dty_all_srst                [WAY_NUM-1:0];     
    logic                                   dty_w_en_set                [WAY_NUM-1:0];     
    logic                                   dty_w_en_reset              [WAY_NUM-1:0];         
    logic[INDEX_WTH-1:0]                    dty_waddr                   [WAY_NUM-1:0];     
    logic[INDEX_WTH-1:0]                    dty_raddr                   [WAY_NUM-1:0];     
    logic                                   dty_rdata                   [WAY_NUM-1:0];   
    logic                                   vld_all_srst                [WAY_NUM-1:0];     
    logic                                   vld_w_en_set                [WAY_NUM-1:0];     
    logic                                   vld_w_en_reset              [WAY_NUM-1:0];         
    logic[INDEX_WTH-1:0]                    vld_waddr                   [WAY_NUM-1:0];     
    logic[INDEX_WTH-1:0]                    vld_raddr                   [WAY_NUM-1:0];     
    logic                                   vld_rdata                   [WAY_NUM-1:0];   
    logic[0:0]                              cmp_en                      [WAY_NUM-1:0];
    logic[TAG_WTH:0]                        cmp_tag;
    logic[TAG_WTH:0]                        cmp_way_tag                 [WAY_NUM-1 :0];
    logic                                   cmp_result                  [WAY_NUM-1 :0];
    logic                                   plru_srst_lru;     
    logic                                   plru_update_lru;  
    logic[INDEX_WTH-1:0]                    plru_windex;    
    logic[INDEX_WTH-1:0]                    plru_rindex;     
    logic[WAY_WTH  -1:0]                    plru_cur_way;     
    logic[WAY_WTH  -1:0]                    plru_vtm_way;  

    logic[TAG_WTH-1:0]                      tag_l1_addr_use;                  
    logic[INDEX_WTH-1:0]                    index_l1_addr_use;
    logic[OFT_WTH-1:0]                      offset_l1_addr_use;  
    logic[(SUC_FSM_DLY+1)*TAG_WTH-1:0]      tag_l1_addr_use_dlychain;
    logic[(SUC_FSM_DLY+1)*INDEX_WTH-1:0]    index_l1_addr_use_dlychain;
    logic[(SUC_FSM_DLY+1)*OFT_WTH-1:0]      offset_l1_addr_use_dlychain;
    logic[(SUC_FSM_DLY+1)*CHAN_USE_WTH-1:0] chan_use_dlychain;
    logic[SUC_FSM_DLY:0]                    l1_l2_ren_use_dlychain;
    logic[SUC_FSM_DLY:0]                    l1_l2_wen_use_dlychain;
    logic[(SUC_FSM_DLY+1)*L1_L2_AWT-1 :0]   l1_l2_addr_use_dlychain;

    logic[(SUC_FSM_DLY+1)*(TAG_WTH+1)-1 :0] suc_tagram_rdata_dlychain   [WAY_NUM-1:0];
    logic[SUC_FSM_DLY:0]                    suc_vld_rdata_dlychain      [WAY_NUM-1:0];
    logic                                   suc_rhit_reuslt_reg;
    logic[0:0]                              suc_rhit_way_reuslt_d0      [WAY_NUM-1:0];
    logic[0:0]                              suc_rhit_way_reuslt_d1      [WAY_NUM-1:0];
    logic[L2_L1_DWT-1:0]                    dataram_rdata_use_first,dataram_rdata_use_second;
    logic[TAG_WTH-1:0]                      rm_tag_addr;           
    logic[INDEX_WTH-1:0]                    rm_index_addr;
    logic[OFT_WTH-1:0]                      rm_offset_addr;
    logic[(WHM_FSM_DLY+1)*(TAG_WTH+1)-1 :0] rm_tagram_rdata_dlychain  [WAY_NUM-1:0];
    logic[RM_FSM_DLY:0]                     rm_vld_rdata_dlychain       [WAY_NUM-1:0];
    logic[RM_FSM_DLY:0]                     rm_dty_rdata_dlychain       [WAY_NUM-1:0];
    logic[(RM_FSM_DLY+1)*WAY_WTH-1 :0]      rm_lru_vtm_dlychain;
    logic[WAY_WTH-1:0]                      rm_vtm_way_encoder_reg;
    logic[WAY_NUM-1:0]                      rm_vtm_way_decode;
    logic[WAY_NUM-1:0]                      rm_vtm_way_decoder_reg;
    logic                                   rm_vtm_dty;
    logic                                   rm_vtm_vld;
    logic[TAG_WTH:0]                        rm_vtm_tag_value;
    logic[TAG_WTH:0]                        rm_vtm_tag_value_reg;
    logic[TAG_WTH-1:0]                      wr_hit_miss_tag_addr;                  
    logic[INDEX_WTH-1:0]                    wr_hit_miss_index_addr;
    logic[OFT_WTH-1:0]                      wr_hit_miss_offset_addr;  
    logic[TAG_WTH-1:0]                      wr_hit_miss_tag_addr_reg;                  
    logic[INDEX_WTH-1:0]                    wr_hit_miss_index_addr_reg;
    logic[OFT_WTH-1:0]                      wr_hit_miss_offset_addr_reg;  
    logic[(L1_L2_DWT+4)-1:0]                wr_hit_miss_wb_fifo_data_d_reg;  
    logic[(WHM_FSM_DLY+1)*(TAG_WTH+1)-1 :0] whm_tagram_rdata_dlychain  [WAY_NUM-1:0];
    logic[WHM_FSM_DLY:0]                    whm_vld_rdata_dlychain     [WAY_NUM-1:0];
    logic[WHM_FSM_DLY:0]                    whm_dty_rdata_dlychain     [WAY_NUM-1:0];
    logic[(WHM_FSM_DLY+1)*WAY_WTH-1:0] whm_lru_vtm_dlychain;
    logic[0:0]                              wr_hit_miss_way_hit         [WAY_NUM-1:0] ;
    logic[0:0]                              wr_hit_miss_way_hit_busy_reg[WAY_NUM-1:0] ;
    logic[WAY_WTH-1:0]                      wr_hit_miss_way_hit_encoder;
    logic[WAY_WTH-1:0]                      wr_hit_miss_way_hit_encoder_reg;
    logic[0:0]                              wr_hit_miss_way_hit_reg [WAY_NUM-1:0] ;
    logic                                   whm_hit;
    logic                                   wr_hit_miss_vtm_vld;
    logic                                   wr_hit_miss_vtm_dty;
    logic[TAG_WTH:0]                        whm_vtm_tag_value;
    logic[TAG_WTH:0]                        whm_vtm_tag_value_reg;
    logic[0:0]                              plru_vtm_way_decoder[WAY_NUM-1:0] ;
    logic[0:0]                              wr_hit_miss_vtm_way_reg [WAY_NUM-1:0];
    logic[0:0]                              wr_hit_miss_vtm_way_reg_d0 [WAY_NUM-1:0];
    logic[WAY_WTH-1:0]                      wr_hit_miss_vtm_way_encoder_reg;

    logic[TAG_WTH-1:0]                      csr_tag_addr;                  
    logic[INDEX_WTH-1:0]                    csr_index_addr;
    logic[TAG_WTH:0]                        csr_tag_addr_from_tagram;
    logic[WAY_WTH-1:0]                      csr_model_set_way_way_value;
    logic[WAY_WTH-1:0]                      csr_model_set_way_way_value_reg;
    logic[TAG_WTH-1:0]                      csr_tag_addr_reg;                  
    logic[INDEX_WTH-1:0]                    csr_index_addr_reg;
    logic[0:0]                              csr_hit_way_model_addr     [WAY_NUM-1:0] ;
    logic[0:0]                              csr_hit_way_model_set_way  [WAY_NUM-1:0] ;
    logic[0:0]                              csr_hit_way                [WAY_NUM-1:0] ;
    logic[0:0]                              csr_hit_way_reg            [WAY_NUM-1:0] ;
    logic[TAG_WTH:0]                        csr_tagram_rdata_d0        [WAY_NUM-1:0] ;
    logic[TAG_WTH:0]                        csr_tagram_rdata_reg        [WAY_NUM-1:0] ;
    logic                                   csr_model_addr   ; 
    logic                                   csr_model_set_way; 
    logic                                   csr_model_clr_all; 
    logic                                   csr_vld_and_tag_hit    [WAY_NUM-1:0];
    logic                                   csr_vld_and_tag_hit_dty    [WAY_NUM-1:0];
    logic[0:0]                              csr_w_dnma_way        [WAY_NUM-1:0] ;
    logic                                   csr_w_dnma_way_reg  [WAY_NUM-1:0];
    logic[WAY_WTH-1:0]                      csr_w_dnma_way_encoder;
    logic[WAY_WTH-1:0]                      csr_w_dnma_way_encoder_reg;
    logic                                   csr_hit_model_addr        ;
    logic                                   csr_hit_model_set_way     ;
    logic                                   csr_hit_dty_model_addr        ;
    logic                                   csr_hit_dty_model_set_way     ;
    logic                                   csr_clr_vld_model_addr    ;
    logic                                   csr_clr_vld_model_set_way ;
    logic                                   lcarb_ren_d0 ;
    logic                                   lcarb_ren_d1 ;
    logic[L2_L1_DWT-1  : 0]                 lcarb_rdata_d0;
    logic[L2_L1_DWT-1  : 0]                 lcarb_rdata;
    logic                                   lcarb_ren_way_d0      [WAY_NUM-1:0]  ;
    logic[WAY_WTH-1:0]                      lcarb_ren_way_encoder;
    logic[WAY_WTH-1:0]                      sur_rhit_way_encoder_d1;
    logic                                   csr_cmp_result_reg [WAY_NUM-1:0];
    logic                                   csr_vld_rdata_d0 [WAY_NUM-1:0];
    logic                                   csr_vld_rdata_reg [WAY_NUM-1:0];
    logic                                   csr_dty_rdata_d0 [WAY_NUM-1:0];
    logic                                   csr_dty_rdata_reg [WAY_NUM-1:0];
    logic[WAY_NUM-1:0]                      csr_way_decode;
    logic[WAY_NUM-1:0]                      csr_way_decoder_reg;

    assign  l1_l2_ren_use = l1_l2_ren_use_i;
    assign  l1_l2_wen_use = l1_l2_wen_use_i;
    assign  l1_l2_addr_use = l1_l2_addr_use_i;

    assign   tag_l1_addr_use    = l1_l2_addr_use_i [TAG_WTH+INDEX_WTH+OFT_WTH-1 : INDEX_WTH+OFT_WTH]; 
    assign   index_l1_addr_use  = l1_l2_addr_use_i [INDEX_WTH+OFT_WTH-1         :           OFT_WTH];
    assign   offset_l1_addr_use = l1_l2_addr_use_i [OFT_WTH-1                   :                 0];


    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            tag_l1_addr_use_dlychain    <= {((SUC_FSM_DLY+1)*TAG_WTH){1'b0}}; 
            index_l1_addr_use_dlychain  <= {((SUC_FSM_DLY+1)*INDEX_WTH){1'b0}}; 
            offset_l1_addr_use_dlychain <= {((SUC_FSM_DLY+1)*OFT_WTH){1'b0}}; 
            chan_use_dlychain           <= {((SUC_FSM_DLY+1)*2){1'b0}}; 
            l1_l2_ren_use_dlychain      <= {SUC_FSM_DLY{1'b0}}; 
            l1_l2_wen_use_dlychain      <= {SUC_FSM_DLY{1'b0}}; 
            l1_l2_addr_use_dlychain     <= {((SUC_FSM_DLY+1)*L1_L2_AWT){1'b0}}; 
            end
        else
            begin
            tag_l1_addr_use_dlychain    <=  {tag_l1_addr_use_dlychain[SUC_FSM_DLY*TAG_WTH-1:0],tag_l1_addr_use};
            index_l1_addr_use_dlychain  <=  {index_l1_addr_use_dlychain[SUC_FSM_DLY*INDEX_WTH-1:0],index_l1_addr_use};
            offset_l1_addr_use_dlychain <=  {offset_l1_addr_use_dlychain[SUC_FSM_DLY*OFT_WTH-1:0], offset_l1_addr_use};
            chan_use_dlychain           <=  {chan_use_dlychain[SUC_FSM_DLY*CHAN_USE_WTH-1:0], chan_use_dly1_i};// the 0 1 2 3 total four clock ,this is the 1 clock enble
            l1_l2_ren_use_dlychain      <=  {l1_l2_ren_use_dlychain[SUC_FSM_DLY-1:0],l1_l2_ren_use};  
            l1_l2_wen_use_dlychain      <=  {l1_l2_wen_use_dlychain[SUC_FSM_DLY-1:0],l1_l2_wen_use};                       
            l1_l2_addr_use_dlychain     <=  {l1_l2_addr_use_dlychain[SUC_FSM_DLY*L1_L2_AWT-1:0],l1_l2_addr_use};              
            end
    end


    /*  the clock 0 : 1 read valid reg 2 read all way tag ram  3 compare the write buffer for cmp 
    read valid reg
    en   : l1_l2_ren_use 
    addr : index_l1_addr_use 
    data : vld_way_or_not[3:0]

    read all way tag ram 
    ren  : l1_l2_ren_use 
    addr : index_l1_addr_use
    data : suc_fsm_tagram_rdata

    cmp write buffer
    en   : l1_l2_ren_use
    addr : index_l1_addr_use  ,only have 4K alied addr compare
    data : wb_fifo_cmp_result (next clock enable)
    */

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                suc_tagram_rdata_dlychain[i] <= {((SUC_FSM_DLY+1)*(TAG_WTH+1)){1'b0}}; 
                suc_vld_rdata_dlychain[i]    <= {SUC_FSM_DLY{1'b0}}; 
                end
            end
        else
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                suc_tagram_rdata_dlychain[i] <=  {suc_tagram_rdata_dlychain[i][SUC_FSM_DLY*(TAG_WTH+1)-1:0] , tagram_rdata[i]};
                suc_vld_rdata_dlychain[i]    <=  {suc_vld_rdata_dlychain[i][SUC_FSM_DLY-1:0]            , vld_rdata[i]   };
                end
            end
    end


    /*  the clock 1  :   2 gen hit  3 read data ram

    2 gen hit

    suc_rhit_reuslt

    3 read all way data ram 
    en   :  l1_l2_rwen_back_hit_i && suc_rhit_reuslt  (include only ren)
    ren  :  suc_rhit_way_reuslt
    addr :  {index_l1_addr_use_dlychain[INDEX_WTH-1 : 0],offset_l1_addr_use_dlychain[OFT_WTH-1,DMA_ADDR_OFT_WTH]}  // index , offset from 4KB-> 32B
    data :  dataram_rdata_use_first

    4 detect the update_fsm which way is busy

    */
    logic                                       csr_busy;
    logic                                       rm_busy;
    logic                                       whm_busy;
    logic                                       whm_busy_d1;
    logic                                       whm_busy_rising;
    logic                                       whm_hit_reg;
    logic[WAY_NUM-1:0]                          rm_whm_dataram_busy_way;

    always_comb
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        if(csr_busy)
            rm_whm_dataram_busy_way[i] = csr_w_dnma_way_reg[i]; 
        else if(rm_busy)
            rm_whm_dataram_busy_way[i] = rm_vtm_way_decoder_reg[i] ; 
        else if(whm_busy && whm_hit_reg)
            rm_whm_dataram_busy_way[i] = wr_hit_miss_way_hit_busy_reg[i]; 
        else if(whm_busy && !whm_hit_reg)
            rm_whm_dataram_busy_way[i] = wr_hit_miss_vtm_way_reg[i]; 
        else 
            rm_whm_dataram_busy_way[i] = 1'b0; 
        end
    end

    always_comb
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        suc_rhit_way_reuslt[i] = suc_vld_rdata_dlychain[i][0]& cmp_result[i] & (~rm_whm_dataram_busy_way[i]); 
        suc_rhit_way_busy[i]   = suc_vld_rdata_dlychain[i][0]& cmp_result[i] & rm_whm_dataram_busy_way[i]; 
                                    // use valid bit  the tagram cmp result
        end
    end

    encoder  suc_rhit_way_result_encoder_inst   (
    .a    (  suc_rhit_way_reuslt[0]          ),
    .b    (  suc_rhit_way_reuslt[1]          ),
    .c    (  suc_rhit_way_reuslt[2]          ),
    .d    (  suc_rhit_way_reuslt[3]          ),
    .out  (  suc_rhit_way_result_encoder     )
    );

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                suc_rhit_way_reuslt_d0[i] <= 1'b0; 
                suc_rhit_way_reuslt_d1[i] <= 1'b0; 
                end
            end
        else
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                suc_rhit_way_reuslt_d0[i] <= suc_rhit_way_reuslt   [i];
                suc_rhit_way_reuslt_d1[i] <= suc_rhit_way_reuslt_d0[i];
                end
            end
    end
    // if write buffer have the data  it is not hit
    assign      suc_rhit_reuslt =  wb_fifo_cmp_result ?  1'b0 : (suc_rhit_way_reuslt[0] | suc_rhit_way_reuslt[1]|suc_rhit_way_reuslt[2]|suc_rhit_way_reuslt[3] )  ;
    assign      suc_rhit_wb_fifo_exist_o =  wb_fifo_cmp_result ;
    assign      suc_rhit_way_dataram_busy_o =  (suc_rhit_way_busy[0] | suc_rhit_way_busy[1] | suc_rhit_way_busy[2] | suc_rhit_way_busy[3] ) ;
    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            suc_rhit_reuslt_reg <= 1'b0;
        else
            suc_rhit_reuslt_reg <= suc_rhit_reuslt;

    end

    assign hit_reuslt_o = l1_l2_rwen_back_hit_i && 
                            (l1_l2_ren_use_dlychain[0] && suc_rhit_reuslt )  ;// read hit ?
                            
    //|| (l1_l2_wen_use_dlychain[0] && !wb_fifo_full)// write wb !full?                        

/*
    assign hit_reuslt_o = l1_l2_rwen_back_hit_i && 
                        (
                            l
                            ((chan_use_dly1_i==CHAN_D_R||chan_use_dly1_i==CHAN_I_R) && suc_rhit_reuslt ) // read hit ?
                            || (chan_use_dly1_i==CHAN_D_W && !wb_fifo_full)// write wb !full?
                        );
    * */

    always_comb
    begin
    if(chan_use_dly1_i==CHAN_I_R && l1_l2_rwen_back_hit_i)
        begin
        l2_l1i__suc_o = suc_rhit_reuslt;
        end
    else  
        begin
        l2_l1i__suc_o     = 1'b0;
        end
    end

    always_comb
    begin
    if(chan_use_dly1_i==CHAN_D_R && l1_l2_rwen_back_hit_i)
        begin
        l2_l1d__suc_o = suc_rhit_reuslt;
        end
    else if(l1_l2_wen_use_dlychain[0])
        begin
        l2_l1d__suc_o     = !wb_fifo_full;
        end
    else  
        begin
        l2_l1d__suc_o     = 1'b0;
        end
    end

    assign l2_l1i__suc_act_o =  l1_l2_rwen_back_hit_i && (chan_use_dly1_i==CHAN_I_R);
    assign l2_l1d__suc_act_o =  (l1_l2_rwen_back_hit_i && chan_use_dly1_i==CHAN_D_R) || (l1_l2_wen_use_dlychain[0]);


    /*  the clock 2  : 1  read all way data ram  2 update plru  3  output to L1 the first 32B

    1 read all way data ram 
    en   :  hit_way_reuslt_d0
    addr :  {index_l1_addr_use_d2,offset_l1_addr_use_d2[OFT_WTH-1,DMA_ADDR_OFT_WTH]}  // index , offset from 4KB-> 32B
    data :  dataram_rdata_use_second

    2 update plru 
    en  : l1_l2_rwen_back_first_data_i && (chan_use_i==CHAN_I_R||chan_use_i==CHAN_D_R) && suc_rhit_reuslt_reg
    addr: index_l1_addr_use_dlychain[2*INDEX_WTH-1 : INDEX_WTH]
    data: suc_rhit_way_result_encoder_d0

    */

    /* mux data ram data */
    //encoder hit_way_encoder0
    //(
    //    .a  ( suc_rhit_way_reuslt_d0[0]      )   ,
    //    .b  ( suc_rhit_way_reuslt_d0[1]      )   ,
    //    .c  ( suc_rhit_way_reuslt_d0[2]      )   ,
    //    .d  ( suc_rhit_way_reuslt_d0[3]      )   ,
    //    .out( suc_rhit_way_result_encoder_d0 )
    //);


    //mux4 #(.width(L2_L1_DWT)) dataram_mux0
    //(
        //.sel    ( suc_rhit_way_result_encoder_d0),
        //.a      ( dataram_rdata[0]         ),
        //.b      ( dataram_rdata[1]         ),
        //.c      ( dataram_rdata[2]         ),
        //.d      ( dataram_rdata[3]         ),
        //.f      ( dataram_rdata_use_first  )
    //);

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            for(int i=0;i<WAY_WTH;i=i+1)
                begin
                suc_rhit_way_result_encoder_d0[i] <= 1'b0; 
                end
            end
        else
            begin
            for(int i=0;i<WAY_WTH;i=i+1)
                begin
                suc_rhit_way_result_encoder_d0[i] <= suc_rhit_way_result_encoder[i];
                end
            end
    end

    always_comb
    begin
        case ({suc_rhit_way_reuslt_d0[3],suc_rhit_way_reuslt_d0[2],suc_rhit_way_reuslt_d0[1],suc_rhit_way_reuslt_d0[0]})
            4'b0001:
                dataram_rdata_use_first = dataram_rdata[0];
            4'b0010:
                dataram_rdata_use_first = dataram_rdata[1];
            4'b0100:
                dataram_rdata_use_first = dataram_rdata[2];
            4'b1000:
                dataram_rdata_use_first = dataram_rdata[3];
            default:
                dataram_rdata_use_first = {L2_L1_DWT{1'b0}};
        endcase
    end
    /*  the clock 3  :  output to L1 the second 32B
    */

    ///* mux data ram data */
    //encoder hit_way_encoder1
    //(
        //.a  ( suc_rhit_way_reuslt_d1[0]      )   ,
        //.b  ( suc_rhit_way_reuslt_d1[1]      )   ,
        //.c  ( suc_rhit_way_reuslt_d1[2]      )   ,
        //.d  ( suc_rhit_way_reuslt_d1[3]      )   ,
        //.out( sur_rhit_way_encoder_d1 )
    //);
    //mux4 #(.width(L2_L1_DWT)) dataram_mux1
    //(
        //.sel    ( sur_rhit_way_encoder_d1   ),
        //.a      ( dataram_rdata[0]            ),
        //.b      ( dataram_rdata[1]            ),
        //.c      ( dataram_rdata[2]            ),
        //.d      ( dataram_rdata[3]            ),
        //.f      ( dataram_rdata_use_second    )
    //);
    always_comb
    begin
        case ({suc_rhit_way_reuslt_d1[3],suc_rhit_way_reuslt_d1[2],suc_rhit_way_reuslt_d1[1],suc_rhit_way_reuslt_d1[0]})
            4'b0001:
                dataram_rdata_use_second = dataram_rdata[0];
            4'b0010:
                dataram_rdata_use_second = dataram_rdata[1];
            4'b0100:
                dataram_rdata_use_second = dataram_rdata[2];
            4'b1000:
                dataram_rdata_use_second = dataram_rdata[3];
            default:
                dataram_rdata_use_second = {L2_L1_DWT{1'b0}};
        endcase
    end

       

    assign l2_l1i__rdata_o = l1_l2_rwen_back_first_data_i ? dataram_rdata_use_first : dataram_rdata_use_second ;
    assign l2_l1i__rdata_act_o = (l1_l2_rwen_back_first_data_i && chan_use_dlychain[CHAN_USE_WTH*1-1:CHAN_USE_WTH*0]==CHAN_I_R ) || (l1_l2_ren_back_second_data_i && chan_use_dlychain[CHAN_USE_WTH*2-1:CHAN_USE_WTH*1]==CHAN_I_R) ;



    assign l2_l1d__rdata_o = l1_l2_rwen_back_first_data_i ? dataram_rdata_use_first : dataram_rdata_use_second ;
    assign l2_l1d__rdata_act_o = (l1_l2_rwen_back_first_data_i && chan_use_dlychain[CHAN_USE_WTH*1-1:CHAN_USE_WTH*0]==CHAN_D_R ) || (l1_l2_ren_back_second_data_i && chan_use_dlychain[CHAN_USE_WTH*2-1:CHAN_USE_WTH*1]==CHAN_D_R) ;

    //=============================================================================
    // suc_fsm write  
    //=============================================================================

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
    if(`RST_TRUE(rst_i))
        begin
        l1_l2_addr_w_reg    <= {L1_L2_AWT{1'b0}};
        l1_l2_addr_w_reg_d0 <= {L1_L2_AWT{1'b0}};
        end
    else 
        begin
            if(l1_l2_wen_use)
            begin
            l1_l2_addr_w_reg <= l1d_l2__addr_i;
            end
        l1_l2_addr_w_reg_d0 <= l1_l2_addr_w_reg;
        end
    end


    //=============================================================================
    // update_fsm read miss 
    //=============================================================================

    assign   rm_tag_addr     = rd_miss_addr_i [TAG_WTH+INDEX_WTH+OFT_WTH-1 : INDEX_WTH+OFT_WTH]; 
    assign   rm_index_addr   = rd_miss_addr_i [INDEX_WTH+OFT_WTH-1         :           OFT_WTH];
    assign   rm_offset_addr  = rd_miss_addr_i [OFT_WTH-1                   :                 0];

    /*  read miss fsm 
    clock 0 : 1 read valid reg   2 read dirty reg  3 read plru 
    1 read valid reg
    en   : rm_rall_tag_vld_dty_act_i
    addr : rm_index_addr
    data : rm_vld_rdata_dlychain

    2 read dirty reg
    reg  : rm_rall_tag_vld_dty_act_i
    addr : rm_index_addr
    data : rm_dty_rdata_dlychain

    3 read plru get vtm way
    reg  : rm_rall_tag_vld_dty_act_i
    addr : rm_index_addr
    data : rm_lru_vtm_dlychain -> it is endcoder 
    */

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
    if(`RST_TRUE(rst_i))
        begin
        rm_busy <= 1'b0;
        end
    else if( rm_rall_tag_vld_dty_act_i)
        begin
        rm_busy <= 1'b1;
        end
    else if(rm_end_act_i)
        begin
        rm_busy <= 1'b0;
        end
    end


    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                rm_tagram_rdata_dlychain[i] <=  {((RM_FSM_DLY+1)*(TAG_WTH+1)){1'b0}};
                rm_vld_rdata_dlychain[i]    <=  {RM_FSM_DLY{1'b0}};
                rm_dty_rdata_dlychain[i]    <=  {RM_FSM_DLY{1'b0}};
                end
            rm_lru_vtm_dlychain    <=  {((RM_FSM_DLY+1)*WAY_WTH){1'b0}};
            end
        else
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                rm_tagram_rdata_dlychain[i] <=  {rm_tagram_rdata_dlychain[i][RM_FSM_DLY*(TAG_WTH+1)-1:0] , tagram_rdata[i]};;
                rm_vld_rdata_dlychain[i]    <=  {rm_vld_rdata_dlychain[i][RM_FSM_DLY-1:0]   , vld_rdata[i]};
                rm_dty_rdata_dlychain[i]    <=  {rm_dty_rdata_dlychain[i][RM_FSM_DLY-1:0]   , dty_rdata[i]};
                end
            rm_lru_vtm_dlychain    <=  {rm_lru_vtm_dlychain[RM_FSM_DLY*WAY_WTH-1:0]        , plru_vtm_way   };
            end
    end  
        
    /*
    clock 1 : 
    1 decoder the plru
    2 use plru vtm way ->   vld & dty  -> dirty ?   
    */


    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            rm_vtm_way_encoder_reg <= {(WAY_WTH){1'b0}};
            end
        else if(rm_vtm_dty_or_not_act_i)
            begin
            rm_vtm_way_encoder_reg <= rm_lru_vtm_dlychain[1*WAY_WTH-1 : 0*WAY_WTH]  ;
            end
    end

    decoder rm_vtm_way_decoder_inst
    (
        .in   (     rm_lru_vtm_dlychain[1*WAY_WTH-1:0*WAY_WTH] ),
        .d0   (     rm_vtm_way_decode[0]                       ),
        .d1   (     rm_vtm_way_decode[1]                       ),
        .d2   (     rm_vtm_way_decode[2]                       ),
        .d3   (     rm_vtm_way_decode[3]                       )
    );

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
        begin
        rm_vtm_way_decoder_reg <= {WAY_NUM{1'b0}};  
        end
    else if(rm_vtm_dty_or_not_act_i)
        begin
        rm_vtm_way_decoder_reg <= rm_vtm_way_decode ;  
        end
    end


    assign   rm_vtm_vld          =  rm_vld_rdata_dlychain[rm_lru_vtm_dlychain[1*WAY_WTH-1:0*WAY_WTH]][0];
    assign   rm_vtm_dty          =  rm_dty_rdata_dlychain[rm_lru_vtm_dlychain[1*WAY_WTH-1:0*WAY_WTH]][0];
    assign   rm_vtm_dirty_o  =  rm_vtm_dty && rm_vtm_vld;


    mux4 #(.width(TAG_WTH+1)) read_miss_vtm_tag_value
    (
        .sel    ( rm_lru_vtm_dlychain[1*WAY_WTH-1:0*WAY_WTH]      ),
        .a      ( rm_tagram_rdata_dlychain[0][1*(TAG_WTH+1)-1:0*(TAG_WTH+1)]    ),
        .b      ( rm_tagram_rdata_dlychain[1][1*(TAG_WTH+1)-1:0*(TAG_WTH+1)]    ),
        .c      ( rm_tagram_rdata_dlychain[2][1*(TAG_WTH+1)-1:0*(TAG_WTH+1)]    ),
        .d      ( rm_tagram_rdata_dlychain[3][1*(TAG_WTH+1)-1:0*(TAG_WTH+1)]    ),
        .f      ( rm_vtm_tag_value           )
    );

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            rm_vtm_tag_value_reg         <=  {(TAG_WTH+1){1'b0}};
            end
        else if(rm_vtm_dty_or_not_act_i) 
            begin
            rm_vtm_tag_value_reg         <=  rm_vtm_tag_value;
            end
    end



    /*
    clock 2 : if dirty set vtm way not valid
    set vtm way not valid
    en  : rm_vtm_dty_clear_vld_act_i
    addr: rm_index_addr
    data: 1'b0
    */


    /*
    clock last : 1 write tag ram 2 set valid reg of victim line 3 set not dirty reg of victim line 
    1 write tag ram 
    en  : rm_vtm_set_vd_act_i
    addr: rm_index_addr
    data: rm_tag_addr
    2 set valid reg of victim line
    en  : rm_vtm_set_vd_act_i
    addr: rm_index_addr
    data: 1'b1
    3 set not dirty reg of victim line 
    en  : rm_vtm_set_vd_act_i
    addr: rm_index_addr
    data: 1'b0
    4 update lru with vtm line 
    en  : rm_vtm_set_vd_act_i
    addr: rm_index_addr 
    data: rm_vtm_way_encoder_reg
    */


    //=============================================================================
    // update_fsm write hit or miss 
    //=============================================================================



    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
    if(`RST_TRUE(rst_i))
        begin
        whm_busy <= 1'b0;
        end
    else if(whm_rall_tag_vld_dty_lru_act_i)
        begin
        whm_busy <= 1'b1;
        end
    else if(whm_end_act_i)
        begin
        whm_busy <= 1'b0;
        end
    end

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
    if(`RST_TRUE(rst_i))
        begin
        whm_busy_d1 <= 1'b0;
        end
    else
        begin
        whm_busy_d1 <= whm_busy;
        end
    end
    assign  whm_busy_rising = whm_busy && (!whm_busy_d1);


    assign   wr_hit_miss_tag_addr     = wb_fifo_rd_data_a [TAG_WTH+INDEX_WTH+OFT_WTH-1 : INDEX_WTH+OFT_WTH]; 
    assign   wr_hit_miss_index_addr   = wb_fifo_rd_data_a [INDEX_WTH+OFT_WTH-1         :           OFT_WTH];
    assign   wr_hit_miss_offset_addr  = wb_fifo_rd_data_a [OFT_WTH-1                   :                 0];

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
                wr_hit_miss_tag_addr_reg         <=  {TAG_WTH{1'b0}};
                wr_hit_miss_index_addr_reg       <=  {INDEX_WTH{1'b0}};
                wr_hit_miss_offset_addr_reg      <=  {OFT_WTH{1'b0}};
                wr_hit_miss_wb_fifo_data_d_reg   <=  {(L1_L2_DWT+4){1'b0}};
            end                 
        else if(whm_rall_tag_vld_dty_lru_act_i)
            begin
                wr_hit_miss_tag_addr_reg         <=   wr_hit_miss_tag_addr;
                wr_hit_miss_index_addr_reg       <=   wr_hit_miss_index_addr;                             
                wr_hit_miss_offset_addr_reg      <=   wr_hit_miss_offset_addr;    
                wr_hit_miss_wb_fifo_data_d_reg   <=   wb_fifo_rd_data_d ;
            end                 
    end
    assign whm_miss_addr_from_wb_fifo_o = {wr_hit_miss_tag_addr_reg,wr_hit_miss_index_addr_reg,wr_hit_miss_offset_addr_reg};

    /* clk 0  : 1 read tagram 2 read vld 3 read dty 4 read plru
    en  : whm_rall_tag_vld_dty_lru_act_i
    addr: wr_hit_miss_index_addr
    data: whm_tagram_rdata_dlychain    

    en  : whm_rall_tag_vld_dty_lru_act_i
    addr: wr_hit_miss_index_addr
    data: whm_vld_rdata_dlychain    

    en  : whm_rall_tag_vld_dty_lru_act_i
    addr: wr_hit_miss_index_addr
    data: whm_dty_rdata_dlychain  

    en  : whm_rall_tag_vld_dty_lru_act_i
    addr: wr_hit_miss_index_addr
    data: whm_lru_vtm_dlychain
    */



    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                whm_tagram_rdata_dlychain[i] <=  {((WHM_FSM_DLY+1)*(TAG_WTH+1)){1'b0}};
                whm_vld_rdata_dlychain[i]    <=  {(WHM_FSM_DLY){1'b0}};
                whm_dty_rdata_dlychain[i]    <=  {(WHM_FSM_DLY){1'b0}};
                end
            whm_lru_vtm_dlychain    <=  {((WHM_FSM_DLY+1)*WAY_WTH){1'b0}};
            end
        else
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                whm_tagram_rdata_dlychain[i] <=  {whm_tagram_rdata_dlychain[i][WHM_FSM_DLY*(TAG_WTH+1)-1:0] , tagram_rdata[i]};
                whm_vld_rdata_dlychain[i]    <=  {whm_vld_rdata_dlychain[i][WHM_FSM_DLY-1:0]            , vld_rdata[i]   };
                whm_dty_rdata_dlychain[i]    <=  {whm_dty_rdata_dlychain[i][WHM_FSM_DLY-1:0]            , dty_rdata[i]   };
                end
            whm_lru_vtm_dlychain    <=  {whm_lru_vtm_dlychain[WHM_FSM_DLY*WAY_WTH-1:0]    , plru_vtm_way};
            end
    end
                

    /* clk 1  : 1 compator the tag data  2 read valid reg 3 read dirty reg (for next miss stage)

    en  : whm_hit_or_not_act_i
    addr: wr_hit_miss_index_addr_reg
    data: wr_hit_miss_tagram_rdata_d0  -> cmp_result

    */




    always_comb
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        wr_hit_miss_way_hit[i] = whm_vld_rdata_dlychain[i][0] & cmp_result[i];
        end
    end

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                wr_hit_miss_way_hit_reg[i] <= 1'b0;
                end
            wr_hit_miss_way_hit_encoder_reg <= {(WAY_WTH){1'b0}};
            end
        else if(whm_hit_or_not_act_i)
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                wr_hit_miss_way_hit_reg[i] <= wr_hit_miss_way_hit[i];
                end
            wr_hit_miss_way_hit_encoder_reg <= wr_hit_miss_way_hit_encoder;
            end
    end

    encoder encoder_whm_hit_way_encoder
    (
    .a    (  wr_hit_miss_way_hit[0]          ),
    .b    (  wr_hit_miss_way_hit[1]          ),
    .c    (  wr_hit_miss_way_hit[2]          ),
    .d    (  wr_hit_miss_way_hit[3]          ),
    .out  (  wr_hit_miss_way_hit_encoder     )
    );

    assign   whm_hit =   wr_hit_miss_way_hit[0]|wr_hit_miss_way_hit[1]|wr_hit_miss_way_hit[2]|wr_hit_miss_way_hit[3];


    assign   whm_hit_o = whm_hit ;


    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
    if(`RST_TRUE(rst_i))
        begin
        whm_hit_reg <= 1'b0;
        end
    else if(whm_busy_rising)
        begin
        whm_hit_reg <= whm_hit;
        end
    end
    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                wr_hit_miss_way_hit_busy_reg[i] <= 1'b0;
                end
            end
        else if(whm_busy_rising)
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                wr_hit_miss_way_hit_busy_reg[i] <= wr_hit_miss_way_hit[i];
                end
            end
    end
    /* clk 2  : 1 read lru 2 read dirty reg  3 get vtm line valid and dirty or not 4 clear the vtm_valid bit 5 read wb fifo ren
    1 read lru    
    en  : whm_clear_vld_r_wb_act_i
    addr: wr_hit_miss_index_addr_reg
    data: plru_vtm_way

    3 get vtm line valid and dirty or not

    4 clear the vtm_valid bit
    en  : whm_clear_vld_r_wb_act_i
    addr: wr_hit_miss_index_addr_reg
    data: plru_vtm_way_decoder
    5 read wb fifo ren
    en  : whm_clear_vld_r_wb_act_i
    addr: 
    data: 
    */

    mux4 #(.width(1)) wr_hit_miss_clear_valid_rd_write_buffer_vtm_vld_decoder
    (
        .sel    ( whm_lru_vtm_dlychain[3*WAY_WTH-1:2*WAY_WTH]        ),
        .a      ( whm_vld_rdata_dlychain[0][2]     ),
        .b      ( whm_vld_rdata_dlychain[1][2]     ),
        .c      ( whm_vld_rdata_dlychain[2][2]     ),
        .d      ( whm_vld_rdata_dlychain[3][2]     ),
        .f      ( wr_hit_miss_vtm_vld            )
    );
    mux4 #(.width(1)) wr_hit_miss_clear_valid_rd_write_buffer_vtm_dty_decoder
    (
        .sel    ( whm_lru_vtm_dlychain[3*WAY_WTH-1:2*WAY_WTH]      ),
        .a      ( whm_dty_rdata_dlychain[0][2]    ),
        .b      ( whm_dty_rdata_dlychain[1][2]    ),
        .c      ( whm_dty_rdata_dlychain[2][2]    ),
        .d      ( whm_dty_rdata_dlychain[3][2]    ),
        .f      ( wr_hit_miss_vtm_dty           )
    );

    assign    whm_vtm_is_dirty_o = wr_hit_miss_vtm_vld && wr_hit_miss_vtm_dty;

    decoder wr_hit_miss_clear_valid_rd_write_buffer_vtm
    (
        .in   (     whm_lru_vtm_dlychain[3*WAY_WTH-1:2*WAY_WTH] ),
        .d0   (     plru_vtm_way_decoder[0]  ),
        .d1   (     plru_vtm_way_decoder[1]  ),
        .d2   (     plru_vtm_way_decoder[2]  ),
        .d3   (     plru_vtm_way_decoder[3]  )
    );


    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
        begin
        for(int i=0;i<WAY_NUM;i=i+1)
            begin
            wr_hit_miss_vtm_way_reg[i] <= 1'b0;
            end
        wr_hit_miss_vtm_way_encoder_reg <= {(WAY_WTH){1'b0}};
        end
    else if(whm_clear_vld_r_wb_act_i)
        begin
        for(int i=0;i<WAY_NUM;i=i+1)
            begin
            wr_hit_miss_vtm_way_reg[i] <= plru_vtm_way_decoder[i];
            end
        wr_hit_miss_vtm_way_encoder_reg <= whm_lru_vtm_dlychain[3*WAY_WTH-1:2*WAY_WTH];
        end
    end

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                wr_hit_miss_vtm_way_reg_d0[i] <= 1'b0;
                end
            end
        else 
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                wr_hit_miss_vtm_way_reg_d0[i] <= wr_hit_miss_vtm_way_reg[i];
                end
            end
    end


    mux4 #(.width(TAG_WTH+1)) wr_hit_miss_vtm_tag_value
    (
        .sel    ( whm_lru_vtm_dlychain[3*WAY_WTH-1:2*WAY_WTH]      ),
        .a      ( whm_tagram_rdata_dlychain[0][3*(TAG_WTH+1)-1:2*(TAG_WTH+1)]    ),
        .b      ( whm_tagram_rdata_dlychain[1][3*(TAG_WTH+1)-1:2*(TAG_WTH+1)]    ),
        .c      ( whm_tagram_rdata_dlychain[2][3*(TAG_WTH+1)-1:2*(TAG_WTH+1)]    ),
        .d      ( whm_tagram_rdata_dlychain[3][3*(TAG_WTH+1)-1:2*(TAG_WTH+1)]    ),
        .f      ( whm_vtm_tag_value           )
    );

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            whm_vtm_tag_value_reg         <=  {(TAG_WTH+1){1'b0}};
            end
        else if(whm_clear_vld_r_wb_act_i) 
            begin
            whm_vtm_tag_value_reg         <=  whm_vtm_tag_value;
            end
    end

     /* clk miss last  : 1 write data ram(4B) 2 write tag ram 3 set vtm dirty bit 4 set vtm valid
    1 write data ram(4B)    
    en  : whm_miss_set_vld_act_i
    addr: {wr_hit_miss_index_addr_reg,wr_hit_miss_offset_addr_reg higher 7bit}
    data: wr_hit_miss_wb_fifo_data_d_reg
    2 write tag ram
    en  : whm_miss_set_vld_act_i
    addr: wr_hit_miss_index_addr_reg
    data: wr_hit_miss_tag_addr_reg
    3 set vtm dirty bit
    en  : whm_miss_set_vld_act_i
    addr: wr_hit_miss_index_addr_reg
    data: wr_hit_miss_vtm_way_reg
    4 set vtm valid
    en  : whm_miss_set_vld_act_i
    addr: wr_hit_miss_index_addr_reg
    data: wr_hit_miss_vtm_way_reg
    5 udpate lru
    en  : whm_miss_set_vld_act_i
    addr: wr_hit_miss_index_addr_reg
    data: wr_hit_miss_vtm_way_encoder_reg
    */



    //=============================================================================
    // csr fsm data path
    //=============================================================================

    /*
    localparam                 CSR_MODEL_clr_vld_all             = 0,
                                        CSR_MODEL_clr_vld_addr            = 1,
                                        CSR_MODEL_clr_vld_set_way         = 2,
                                        CSR_MODEL_wr_back_addr            = 3,
                                        CSR_MODEL_wr_back_set_way         = 4,
                                        CSR_MODEL_wr_back_clr_vld_addr    = 5,
                                        CSR_MODEL_wr_back_clr_vld_set_way = 6;*/

    // the index always frome csr_addr_set_way_i
    assign   csr_index_addr   = csr_addr_set_way_i [INDEX_WTH+OFT_WTH-1 : OFT_WTH];

    assign   csr_model_addr    = (csr_model_i == CSR_MODEL_clr_vld_addr    || csr_model_i== CSR_MODEL_wr_back_addr || csr_model_i== CSR_MODEL_wr_back_clr_vld_addr ) ? 1'b1 : 1'b0;
    assign   csr_model_set_way = (csr_model_i == CSR_MODEL_clr_vld_set_way ||csr_model_i == CSR_MODEL_wr_back_set_way || csr_model_i== CSR_MODEL_wr_back_clr_vld_set_way) ? 1'b1 : 1'b0;
    assign   csr_model_clr_all = (csr_model_i == CSR_MODEL_clr_vld_all);

    assign  csr_clr_vld_model_addr = (csr_model_i==CSR_MODEL_clr_vld_addr  || csr_model_i==CSR_MODEL_wr_back_clr_vld_addr) ? 1'b1 : 1'b0;
    assign  csr_clr_vld_model_set_way = (csr_model_i==CSR_MODEL_clr_vld_set_way || csr_model_i==CSR_MODEL_wr_back_clr_vld_set_way)  ? 1'b1 : 1'b0 ;


    /* clock 0
    csr_r_tag_vld_act_dty_i:  read tag ram  and vld
    read tag ram
    1 CSR_MODEL_wr_back_addr or CSR_MODEL_wr_back_clr_vld_addr
    read tag 
    en   : csr_r_tag_vld_act_dty_i && csr_wr_back
    addr : csr_index_addr
    data : tagram_rdata 

    2 csr_index_addr_reg read vld
    read valid reg  :     
    en              :  csr_r_tag_vld_act_dty_i     
    addr            :  csr_index_addr     
    data            :  vld_rdata  -> csr_vld_rdata_d0   
    */
    
    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))begin
        for(int i=0;i<WAY_NUM;i=i+1)begin
            csr_tagram_rdata_d0[i] <= {TAG_WTH{1'b0}};
            csr_vld_rdata_d0[i]    <= 1'b0;
            csr_dty_rdata_d0[i]    <= 1'b0;
            end
        end   
        else begin
            for(int i=0;i<WAY_NUM;i=i+1)begin
                csr_tagram_rdata_d0[i] <= tagram_rdata[i];
                csr_vld_rdata_d0[i]  <= vld_rdata[i];
                csr_dty_rdata_d0[i]  <= dty_rdata[i];
                end
            end   
    end                 


    /*
    clock 1   1 cmp the comparator of tag      
    1 cmp tag
    en:  csr_r_tag_vld_act_dty_i 
    tag_from_addr:   csr_tag_addr    
    tag_from_tagram: csr_tagram_rdata_reg 
    cmp  result :    cmp_result ->  cmp_result =  csr_hit_way_model_addr 

    2 lock vld and tag data
    en: csr_r_tag_vld_act_dty_i
    csr_tagram_rdata_d0 -> csr_tagram_rdata_reg 
    csr_vld_rdata_d0 -> csr_vld_rdata_reg 

    */
    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))begin
        for(int i=0;i<WAY_NUM;i=i+1)begin
            csr_cmp_result_reg[i] <= 1'b0;
            end
        end   
        else if(csr_r_cmp_act_i)begin
            for(int i=0;i<WAY_NUM;i=i+1)begin
                csr_cmp_result_reg[i] <= cmp_result[i];
                end
            end   
    end                 

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))begin
        for(int i=0;i<WAY_NUM;i=i+1)begin
            csr_tagram_rdata_reg[i] <= {TAG_WTH{1'b0}};
            csr_vld_rdata_reg[i]    <= 1'b0;
            csr_dty_rdata_reg[i]    <= 1'b0;
            end
        end   
        else if(csr_r_cmp_act_i)begin
            for(int i=0;i<WAY_NUM;i=i+1)begin
                csr_tagram_rdata_reg[i] <= csr_tagram_rdata_d0[i];
                csr_vld_rdata_reg[i]  <= csr_vld_rdata_d0[i];
                csr_dty_rdata_reg[i]  <= csr_dty_rdata_d0[i];
                end
            end   
    end                 


                 

    decoder csr_way_decoder_inst
    (
        .in   (     csr_w_dnma_way_encoder_reg    ),
        .d0   (     csr_way_decode[0]      ),
        .d1   (     csr_way_decode[1]      ),
        .d2   (     csr_way_decode[2]      ),
        .d3   (     csr_way_decode[3]      )
    );

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
        begin
        csr_way_decoder_reg <= {WAY_NUM{1'b0}};  
        end
    else if(csr_r_cmp_act_i)
        begin
        csr_way_decoder_reg <= csr_way_decode ;  
        end
    end
    /*
    clock 2:  read writer buffer cmp  

    en: csr_rwb_act_i
    data :  {csr_tag_addr,csr_index_addr}
    result: wb_fifo_cmp_result (next clk enable)
    */

    // when in mode set/way, read tag from tag ram  use set_way -> csr_model_set_way_way_value select the tag value of some way
    assign   csr_tag_addr_from_tagram  = csr_tagram_rdata_reg[csr_model_set_way_way_value];
    
    // when in mode set/way the csr_addr_set_way_i  { set_way , index ,offset}  ,split the set_way
    assign   csr_model_set_way_way_value = csr_model_set_way ?  csr_addr_set_way_i [INDEX_WTH+OFT_WTH+1 :INDEX_WTH+OFT_WTH]  : 2'b00;

    // when  in mode set/way, the tag is from csr_tag_addr_from_tagram, esle in mode_addr is from  csr_addr_set_way_i
    assign   csr_tag_addr     = csr_model_addr ? csr_addr_set_way_i [TAG_WTH+INDEX_WTH+OFT_WTH-1 : INDEX_WTH+OFT_WTH] :
                                csr_model_set_way ? csr_tag_addr_from_tagram[TAG_WTH-1: 0] : 0 ;



    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            csr_index_addr_reg              <=   {(INDEX_WTH){1'b0}};
            csr_tag_addr_reg                <=   {(TAG_WTH){1'b0}};
            csr_model_set_way_way_value_reg <= {(WAY_WTH){1'b0}}; 
            end   
        else if(csr_rwb_act_i)
            begin
            csr_index_addr_reg              <=   csr_index_addr;  
            csr_tag_addr_reg                <=   csr_tag_addr;                                                         
            csr_model_set_way_way_value_reg <= csr_model_set_way_way_value; 
            end   
    end  

    /* 
    clock 3  csr_hit_or_not_act_i  
    */
    //  csr_hit_way_model_addr 
    //                                          ->  csr_hit_way  ->  csr_hit_way_reg
    //  csr_model_set_way_way_value
    
    always_comb
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        csr_hit_way_model_addr[i]  = csr_cmp_result_reg[i];  // the comparator of tagram 
    end

    decoder csr_model_set_way_decoder
    (
        .in   (     csr_model_set_way_way_value    ),
        .d0   (     csr_hit_way_model_set_way[0]  ),
        .d1   (     csr_hit_way_model_set_way[1]  ),
        .d2   (     csr_hit_way_model_set_way[2]  ),
        .d3   (     csr_hit_way_model_set_way[3]  )
    );

    always_comb
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        csr_hit_way[i]  = csr_model_addr ?  csr_hit_way_model_addr [i]: csr_model_set_way ? csr_hit_way_model_set_way[i]:0 ;
    end

    always_comb
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
    csr_vld_and_tag_hit[i] = csr_hit_way[i] & csr_vld_rdata_reg[i];
    end

    always_comb
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
    csr_vld_and_tag_hit_dty[i] = csr_hit_way[i] & csr_vld_rdata_reg[i] & csr_dty_rdata_reg[i];
    end
    encoder encoder_csr_w_dnma_way_reg_encoder
    (
    .a    (  csr_w_dnma_way[0]          ),
    .b    (  csr_w_dnma_way[1]          ),
    .c    (  csr_w_dnma_way[2]          ),
    .d    (  csr_w_dnma_way[3]          ),
    .out  (  csr_w_dnma_way_encoder     )
    );

    always_comb
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
    csr_w_dnma_way[i] = (csr_model_addr) ? (csr_hit_way[i] & csr_vld_rdata_reg[i]) : csr_model_set_way ? (csr_hit_way[i]) : 1'b0  ;
    end

    assign csr_hit_model_addr    = (!wb_fifo_cmp_result) && ( csr_vld_and_tag_hit[0] | csr_vld_and_tag_hit[1] | csr_vld_and_tag_hit[2] |csr_vld_and_tag_hit[3]  );
    assign csr_hit_model_set_way = csr_vld_rdata_reg[csr_model_set_way_way_value_reg] & (!wb_fifo_cmp_result);

    assign csr_hit_dty_model_addr    = (!wb_fifo_cmp_result) && ( csr_vld_and_tag_hit_dty[0] | csr_vld_and_tag_hit_dty[1] | csr_vld_and_tag_hit_dty[2] |csr_vld_and_tag_hit_dty[3]  );
    assign csr_hit_dty_model_set_way = csr_vld_rdata_reg[csr_model_set_way_way_value_reg] & csr_dty_rdata_reg[csr_model_set_way_way_value_reg] & (!wb_fifo_cmp_result);

    //assign csr_wb_exist_o = wb_fifo_cmp_result;
    assign csr_wb_exist_o = ~wb_fifo_empty;
    assign csr_hit_o = csr_model_addr ? csr_hit_model_addr :  csr_model_set_way ? csr_hit_model_set_way : csr_model_clr_all ? 1'b1 : 1'b0;

    assign csr_hit_dty_o = csr_model_addr ? csr_hit_dty_model_addr :  csr_model_set_way ? csr_hit_dty_model_set_way : csr_model_clr_all ? 1'b1 : 1'b0;

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                csr_hit_way_reg[i] <= 1'b0;
                end
            end   
        else if(csr_hit_or_not_act_i)  
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                csr_hit_way_reg[i] <= csr_hit_way[i];
                end
            end   
    end                 

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                csr_w_dnma_way_reg[i] <=  1'b0;
                end
            csr_w_dnma_way_encoder_reg <= {WAY_WTH{1'b0}};        
            end   
        else if(csr_hit_or_not_act_i)
            begin
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                csr_w_dnma_way_reg[i] <=  csr_w_dnma_way[i];
                end
            csr_w_dnma_way_encoder_reg <= csr_w_dnma_way_encoder;        
            end   
                            
    end     
    
    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
    if(`RST_TRUE(rst_i))
        begin
        csr_busy <= 1'b0;
        end
    else if(csr_w_ndma_cfg_pre_two_clk_act_i)
        begin
        csr_busy <= 1'b1;
        end
    else if( csr_clr_vld_if_need_act_i)
        begin
        csr_busy <= 1'b0;
        end
    end
 
    /* clock 2   w ndma configure
    csr_w_ndma_cfg_act_i : 
    en   :  1
    addr :  {csr_tag_addr_reg,csr_index_addr_reg,12'h0}
    data :  
    */

    /* clock 2   w ndma wait
    csr_w_ndma_wait_act_i : 
    en   :  csr_w_dnma_way_reg[i]
    addr :  
    data :  
    */


    /*
    csr_clr_vld_if_need_act_i:
    1 CSR_MODEL_clr_vld_all:   
        clear all vld reg
        en  : csr_clr_vld_if_need_act_i 
        addr: 
        data: vld_all_srst

    2 CSR_MODEL_clr_vld_addr or CSR_MODEL_wr_back_clr_vld_addr 
        clear vld reg of addr
        en  : csr_clr_vld_if_need_act_i
        addr: csr_index_addr_reg
        data: we_reset <- csr_hit_way_reg[i]

    3  CSR_MODEL_clr_vld_set_way or CSR_MODEL_wr_back_clr_vld_set_way:   
        clear vld reg of addr
        en  : csr_clr_vld_if_need_act_i
        addr: csr_index_addr_reg
        data: we_reset <- csr_hit_way_reg[i]  

    */


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////
    // rw tag ram   ---------------------------------------------------

    always_comb  // r tag ram
    begin
    if(l1_l2_ren_use)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        tagram_raddr[i] = index_l1_addr_use;
        end
    end
    else if(rm_rall_tag_vld_dty_act_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        tagram_raddr[i] = rm_index_addr;
        end
    end
    else if(whm_rall_tag_vld_dty_lru_act_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        tagram_raddr[i] = wr_hit_miss_index_addr;
        end
    end
    else if(csr_r_tag_vld_act_dty_i && (csr_model_i != CSR_MODEL_clr_vld_all))
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        tagram_raddr[i] = csr_index_addr;
        end
    end   
    else
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        tagram_raddr[i] = {(INDEX_WTH){1'b0}};
        end
    end
    end

    // r compator   ---------------------------------------------------
    always_comb  // r cmp
    begin
    if(l1_l2_rwen_back_hit_i)
    begin
    cmp_tag = {1'b0,tag_l1_addr_use_dlychain[TAG_WTH-1:0]};
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        cmp_en[i]       = 1'b1 ;
        cmp_way_tag[i]  = suc_tagram_rdata_dlychain[i][1*(TAG_WTH+1)-1 : 0*(TAG_WTH+1)];  
        end
    end
    else if(whm_hit_or_not_act_i)
    begin
    cmp_tag = {1'b0,wr_hit_miss_tag_addr_reg};
    for(int i=0;i<WAY_NUM;i=i+1)  
        begin
        cmp_en[i]       = 1'b1;
        cmp_way_tag[i]  = whm_tagram_rdata_dlychain[i][(TAG_WTH+1)-1:0] ;
        end
    end
    else if(csr_r_cmp_act_i && (csr_model_i != CSR_MODEL_clr_vld_all))
    begin
    cmp_tag =  {1'b0,csr_addr_set_way_i [TAG_WTH+INDEX_WTH+OFT_WTH-1 : INDEX_WTH+OFT_WTH] };
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        cmp_en[i]       = 1'b1;
        cmp_way_tag[i]  = csr_tagram_rdata_d0[i] ; //delaychan 1 of tagram_rdata
        end
    end   
    else
    begin
    cmp_tag = 1'b0;
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        cmp_en[i]       = 1'b0 ;
        cmp_way_tag[i]  = {(TAG_WTH){1'b0}} ;
        end
    end
    end


    always_comb  // w tag ram
    begin
    if(rm_vtm_set_vd_act_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        tagram_wen  [i] = rm_vtm_way_decoder_reg[i];
        tagram_waddr[i] = rm_index_addr;
        tagram_wdata[i] = rm_tag_addr;
        end
    end
    else if(whm_miss_set_vld_act_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        tagram_wen  [i] = wr_hit_miss_vtm_way_reg_d0[i];
        tagram_waddr[i] = wr_hit_miss_index_addr_reg;
        tagram_wdata[i] = wr_hit_miss_tag_addr_reg;
        end
    end  
    else
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        tagram_wen  [i] = 1'b0;
        tagram_waddr[i] = {(INDEX_WTH){1'b0}};
        tagram_wdata[i] = {(TAG_WTH){1'b0}};
        end
    end
    end


    // rw data ram---------------------------------------------------
    always_comb
    begin
    for(int w=0;w<WAY_NUM;w=w+1)// for eache way
    begin
        /**************************************************************************read start***********************************************************************/
    if(l1_l2_rwen_back_hit_i && suc_rhit_reuslt && w == suc_rhit_way_result_encoder)
        begin
        dataram_cs   [w] = 1'b1;
        dataram_we   [w] = 1'b0;
        dataram_addr [w] = {index_l1_addr_use_dlychain[INDEX_WTH-1 : 0],offset_l1_addr_use_dlychain[OFT_WTH-1:DMA_ADDR_OFT_WTH],1'b0};
        end
    else if(l1_l2_rwen_back_first_data_i && suc_rhit_reuslt_reg && w == suc_rhit_way_result_encoder_d0 )
        begin
        dataram_cs   [w] = 1'b1;
        dataram_we   [w] = 1'b0;
        dataram_addr [w] = {index_l1_addr_use_dlychain[2*INDEX_WTH-1 : INDEX_WTH],offset_l1_addr_use_dlychain[2*OFT_WTH-1: DMA_ADDR_OFT_WTH + OFT_WTH],1'b1};
        end
    else if(rm_dty_w_ndma_wait_act_i && lcarb_l2c__mem_req_i.rd_en && w == rm_vtm_way_encoder_reg )
        begin
        dataram_cs   [w] = 1'b1;
        dataram_we   [w] = 1'b0;
        dataram_addr [w] = {rm_index_addr,lcarb_l2c__mem_req_i.raddr[OFT_WTH-1:DATA_RAM_ADDR_OFT_WTH]} ;
        end
    else if(whm_dty_w_ndma_wait_act_i && lcarb_l2c__mem_req_i.rd_en && w == wr_hit_miss_vtm_way_encoder_reg)
        begin
        dataram_cs   [w] = 1'b1;
        dataram_we   [w] = 1'b0;
        dataram_addr [w] = {wr_hit_miss_index_addr_reg,lcarb_l2c__mem_req_i.raddr[OFT_WTH-1:DATA_RAM_ADDR_OFT_WTH]} ;
        end
    else if(csr_w_ndma_wait_act_i && lcarb_l2c__mem_req_i.rd_en && w == csr_w_dnma_way_encoder_reg)
        begin
        dataram_cs   [w] = 1'b1;
        dataram_we   [w] = 1'b0;
        dataram_addr [w] = {csr_index_addr_reg,lcarb_l2c__mem_req_i.raddr[OFT_WTH-1:DATA_RAM_ADDR_OFT_WTH]} ;
        end
        /**************************************************************************read end*************************************************************************/
    else if(whm_hit_set_dty_act_i && w == wr_hit_miss_way_hit_encoder_reg)
        begin
        dataram_cs   [w] = 1'b1;
        dataram_we   [w] = 1'b1;
        dataram_addr [w] = {wr_hit_miss_index_addr_reg,wr_hit_miss_offset_addr_reg[OFT_WTH-1 : DATA_RAM_ADDR_OFT_WTH] };
        end
    else if(whm_miss_set_vld_act_i && w == wr_hit_miss_vtm_way_encoder_reg )
        begin
        dataram_cs   [w] = 1'b1;
        dataram_we   [w] = 1'b1;
        dataram_addr [w] = {wr_hit_miss_index_addr_reg,wr_hit_miss_offset_addr_reg[OFT_WTH-1 : DATA_RAM_ADDR_OFT_WTH] };
        end
    else if(rm_r_ndma_cfg_wait_i && lcarb_l2c__mem_req_i.wr_en && w == rm_vtm_way_encoder_reg)
        begin
        dataram_cs   [w] = 1'b1;
        dataram_we   [w] = 1'b1;
        dataram_addr [w] = {rm_index_addr,lcarb_l2c__mem_req_i.waddr[OFT_WTH-1:DATA_RAM_ADDR_OFT_WTH]};
        end
    else if(whm_r_ndma_wait_act_i && lcarb_l2c__mem_req_i.wr_en && w == wr_hit_miss_vtm_way_encoder_reg)
        begin
        dataram_cs   [w] = 1'b1;
        dataram_we   [w] = 1'b1;
        dataram_addr [w] = {wr_hit_miss_index_addr_reg,lcarb_l2c__mem_req_i.waddr[OFT_WTH-1:DATA_RAM_ADDR_OFT_WTH]};
        end
    else
        begin
        dataram_cs   [w] = 1'b0;
        dataram_we   [w] = 1'b0;
        dataram_addr [w] = 9'd0;
        end
    end
    end



    always_comb
    begin
    for(int w=0;w<WAY_NUM;w=w+1)// for eache way
    begin
    for(int i=0;i<8;i=i+1) // 8*4B =32B  data ram with
        begin                                      
        for(int j=0;j<4;j=j+1) 
            begin//  for every 4B    way wr_hit_miss_way_hit_encoder_reg
            if(whm_hit_set_dty_act_i && w == wr_hit_miss_way_hit_encoder_reg && i == wr_hit_miss_offset_addr_reg[4:2] )
                begin              // if 000 dst frist 4B <= src   if  001 dst second 4B <= src 
                dataram_wdata[w][(i*4+j)*8 +: 8 ] = wr_hit_miss_wb_fifo_data_d_reg[j*8 +: 8];
                dataram_wdata_strob [w][ i*4+j ]  = wr_hit_miss_wb_fifo_data_d_reg[j+L1_L2_DWT];
                end
            else if(whm_miss_set_vld_act_i && w == wr_hit_miss_vtm_way_encoder_reg && i == wr_hit_miss_offset_addr_reg[4:2] )
                begin // for every 4B    wr_hit_miss_way_hit_encoder_reg
                dataram_wdata[w][(i*4+j)*8 +: 8 ] = wr_hit_miss_wb_fifo_data_d_reg[j*8 +: 8];
                dataram_wdata_strob [w][ i*4+j ]  = wr_hit_miss_wb_fifo_data_d_reg[j+L1_L2_DWT];
                end
            else if(whm_r_ndma_wait_act_i && lcarb_l2c__mem_req_i.wr_en && w == wr_hit_miss_vtm_way_encoder_reg)
                begin  // for 32 Btye
                dataram_wdata[w]       = lcarb_l2c__mem_req_i.wdata;  
                dataram_wdata_strob[w][ i*4+j ] = lcarb_l2c__mem_req_i.wstrb[i];
                end
            else if(rm_r_ndma_cfg_wait_i && lcarb_l2c__mem_req_i.wr_en && w == rm_vtm_way_encoder_reg)
                begin  // for 32 Btye
                dataram_wdata[w]       = lcarb_l2c__mem_req_i.wdata;  
                dataram_wdata_strob[w][ i*4+j ] = lcarb_l2c__mem_req_i.wstrb[i];
                end
            else
                begin
                dataram_wdata[w][(i*4+j)*8 +: 8 ] = 8'h0;
                dataram_wdata_strob[w] [ i*4+j ]  = 1'b0;
                end
            end
        end  
    end
    
    end


    // rw vld reg ---------------------------------------------------
    always_comb // r vld
    begin
    if(l1_l2_ren_use)  
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        vld_raddr[i]      = index_l1_addr_use; 
        end
    end
    else if(rm_rall_tag_vld_dty_act_i)  
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        vld_raddr[i]      = rm_index_addr; 
        end
    end 
    else if(whm_rall_tag_vld_dty_lru_act_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        vld_raddr[i]      = wr_hit_miss_index_addr;
        end
    end
    else if(csr_r_tag_vld_act_dty_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        vld_raddr[i]      = csr_index_addr;
        end
    end
    else
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        vld_raddr[i]      = 1'b0;
        end
    end
    end
    always_comb // w vld
    begin
    if(rm_vtm_dty_clear_vld_act_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        vld_all_srst[i]   = 1'b0;
        vld_w_en_set[i]   = 1'b0;
        vld_w_en_reset[i] = rm_vtm_way_decoder_reg[i];
        vld_waddr[i]      = rm_index_addr;
        end
    end
    else if(rm_vtm_set_vd_act_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        vld_all_srst[i]   = 1'b0;
        vld_w_en_set[i]   = rm_vtm_way_decoder_reg[i];
        vld_w_en_reset[i] = 1'b0;
        vld_waddr[i]      = rm_index_addr;
        end
    end   
    else if(whm_clear_vld_r_wb_act_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        vld_all_srst[i]   = 1'b0;
        vld_w_en_set[i]   = 1'b0;
        vld_w_en_reset[i] = plru_vtm_way_decoder[i];
        vld_waddr[i]      = wr_hit_miss_index_addr_reg;
        end
    end
    else if(whm_miss_set_vld_act_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        vld_all_srst[i]   = 1'b0;
        vld_w_en_set[i]   = wr_hit_miss_vtm_way_reg_d0[i];
        vld_w_en_reset[i] = 1'b0;
        vld_waddr[i]      = wr_hit_miss_index_addr_reg;
        end
    end
    else if(csr_clr_vld_if_need_act_i && (csr_model_i==CSR_MODEL_clr_vld_all))
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        vld_all_srst[i]   = 1'b1;
        vld_w_en_set[i]   = 1'b0;
        vld_w_en_reset[i] = 1'b0;
        vld_waddr[i]      = {(INDEX_WTH){1'b0}};
        end
    end
    else if(csr_clr_vld_if_need_act_i && (csr_clr_vld_model_addr || csr_clr_vld_model_set_way) )
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        vld_all_srst[i]   = 0;
        vld_w_en_set[i]   = 1'b0;
        vld_w_en_reset[i] = csr_hit_way_reg[i];
        vld_waddr[i]      = csr_index_addr_reg;
        end
    end
    else
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        vld_all_srst[i]   = 1'b0;
        vld_w_en_set[i]   = 1'b0;
        vld_w_en_reset[i] = 1'b0;
        vld_waddr[i]      = {(INDEX_WTH){1'b0}};
        end
    end
    end



    // rw dty reg
    always_comb // r dty reg
    begin
    if(rm_rall_tag_vld_dty_act_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        dty_raddr[i]      = rm_index_addr;
        end
    end   
    else if(whm_rall_tag_vld_dty_lru_act_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        dty_raddr[i]      = wr_hit_miss_index_addr;
        end
    end
    else if(csr_r_tag_vld_act_dty_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        dty_raddr[i]      = csr_index_addr;
        end
    end
    else
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        dty_raddr[i]      = {(INDEX_WTH){1'b0}};
        end
    end
    end

    always_comb // w dty reg
    begin
    if(rm_vtm_set_vd_act_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin// from dma read finish  mark not dirty
        dty_all_srst[i]   = 0;
        dty_w_en_set[i]   = 0;
        dty_w_en_reset[i] = rm_vtm_way_decoder_reg[i];
        dty_waddr[i]      = rm_index_addr;
        end
    end
    else if(whm_hit_set_dty_act_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        dty_all_srst[i]   = 1'b0;
        dty_w_en_set[i]   = wr_hit_miss_way_hit_reg[i];
        dty_w_en_reset[i] = 1'b0;
        dty_waddr[i]      = wr_hit_miss_index_addr_reg;
        end
    end
    else if(whm_miss_set_vld_act_i)
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        dty_all_srst[i]   = 1'b0;
        dty_w_en_set[i]   = wr_hit_miss_vtm_way_reg_d0[i];
        dty_w_en_reset[i] = 1'b0;
        dty_waddr[i]      = wr_hit_miss_index_addr_reg;
        end
    end
    else
    begin
    for(int i=0;i<WAY_NUM;i=i+1)
        begin
        dty_all_srst[i]   = 1'b0;
        dty_w_en_set[i]   = 1'b0;
        dty_w_en_reset[i] = 1'b0;
        dty_waddr[i]      = {(INDEX_WTH){1'b0}};
        end
    end
    end



    // rd lru reg
    always_comb // r lur
    begin
    if(rm_rall_tag_vld_dty_act_i)
    begin
    plru_rindex = rm_index_addr;
    end
    else if(whm_rall_tag_vld_dty_lru_act_i)
    begin
    plru_rindex = wr_hit_miss_index_addr;
    end
    else
    begin
    plru_rindex     = {(INDEX_WTH){1'b0}};
    end
    end

    always_comb // w lur
    begin
    if(l1_l2_rwen_back_first_data_i && (l1_l2_ren_use_dlychain[1]) && suc_rhit_reuslt_reg )
    begin
    plru_srst_lru   = 1'b0;
    plru_update_lru = 1'b1;
    plru_windex     = index_l1_addr_use_dlychain[2*INDEX_WTH-1 : INDEX_WTH];
    plru_cur_way    = suc_rhit_way_result_encoder_d0;
    end
    else if(rm_vtm_set_vd_act_i )
    begin
    plru_srst_lru   = 1'b0;
    plru_update_lru = 1'b1;
    plru_windex     = rm_index_addr;
    plru_cur_way    = rm_vtm_way_encoder_reg;
    end
    else if(whm_miss_set_vld_act_i )
    begin
    plru_srst_lru   = 1'b0;
    plru_update_lru = 1'b1;
    plru_windex     = wr_hit_miss_index_addr_reg;
    plru_cur_way    = wr_hit_miss_vtm_way_encoder_reg;
    end
    else
    begin
    plru_srst_lru   = 1'b0;
    plru_update_lru = 1'b0;
    plru_windex     = {(INDEX_WTH){1'b0}};
    plru_cur_way    = {(WAY_WTH){1'b0}};
    end

    end

    // rw write buffer fifo

    assign  wb_fifo_wr_en = l1d_l2__wdata_act_i; // && ! wb_fifo_full ;
    assign  wb_fifo_wr_data_a = l1_l2_addr_w_reg_d0;
    assign  wb_fifo_wr_data_d = {l1d_l2__wstrb_i,l1d_l2__wdata_i};

    always_comb // read fifo
    begin
    if(whm_clear_vld_r_wb_act_i || whm_hit_set_dty_act_i)
    begin
    wb_fifo_rd_en = 1'b1;
    end
    else
    begin
    wb_fifo_rd_en = 1'b0;
    end

    end
    always_comb // cmp fifo
    begin
    if(l1_l2_ren_use)
    begin
    wb_fifo_cmp_en = 1'b1;
    wb_fifo_cmp_data_a = {tag_l1_addr_use ,index_l1_addr_use};
    end
    else if(csr_rwb_act_i)
    begin
    wb_fifo_cmp_en = 1'b1;
    wb_fifo_cmp_data_a = {csr_tag_addr_reg,csr_index_addr_reg};
    end
    else
    begin
    wb_fifo_cmp_en = 1'b0;
    wb_fifo_cmp_data_a = 1'b0;
    end

    end

    // rw ndma

    //rd miss address
    //{rm_tag_addr,rm_index_addr,rm_offset_addr}

    // wr hit miss addrss
    //{wr_hit_miss_tag_addr_reg,wr_hit_miss_index_addr_reg,wr_hit_miss_offset_addr_reg}
    /*
    logic          [L1_L2_AWT-1:0] l2_ram_local_addr_reg ;

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
    if(`RST_TRUE(rst_i))
    l2_ram_local_addr_reg <= 0;
    else if(rm_dty_w_ndma_cfg_act_i||rm_r_ndma_cfg_act_i||whm_dty_w_ndma_cfg_act_i||whm_r_ndma_cfg_act_i)
    l2_ram_local_addr_reg 
    end*/

//    always_comb begin
//        if(rm_dty_w_ndma_cfg_act_i) begin
//            l2c_lcarb__cmd_valid_o    =  1'b1;
//            l2c_lcarb__cmd_o.cmd      =  ndma_w_cmd;
//            l2c_lcarb__cmd_o.size     =  dma_tras_num_4KB;
//            l2c_lcarb__cmd_o.destx    =  dma_ddr_destx;
//            l2c_lcarb__cmd_o.desty    =  dma_ddr_desty;
//            l2c_lcarb__cmd_o.lcaddr   =  {rm_tag_addr,rm_index_addr,rm_offset_addr};
//            l2c_lcarb__cmd_o.rtaddr   =  {rm_tag_addr,rm_index_addr,rm_offset_addr};
//        end else if(whm_dty_w_ndma_cfg_act_i) begin
//            l2c_lcarb__cmd_valid_o     =  1'b1;
//            l2c_lcarb__cmd_o.cmd       =  ndma_w_cmd;
//            l2c_lcarb__cmd_o.size      =  dma_tras_num_4KB;
//            l2c_lcarb__cmd_o.destx     =  dma_ddr_destx;
//            l2c_lcarb__cmd_o.desty     =  dma_ddr_desty;
//            l2c_lcarb__cmd_o.lcaddr    =  {wr_hit_miss_tag_addr_reg,wr_hit_miss_index_addr_reg,wr_hit_miss_offset_addr_reg};
//            l2c_lcarb__cmd_o.rtaddr    =  {wr_hit_miss_tag_addr_reg,wr_hit_miss_index_addr_reg,wr_hit_miss_offset_addr_reg};
//        end else if(csr_w_ndma_cfg_act_i) begin
//            l2c_lcarb__cmd_valid_o     =  1'b1;
//            l2c_lcarb__cmd_o.cmd       =  ndma_w_cmd;
//            l2c_lcarb__cmd_o.size      =  dma_tras_num_4KB;
//            l2c_lcarb__cmd_o.destx     =  dma_ddr_destx;
//            l2c_lcarb__cmd_o.desty     =  dma_ddr_desty;
//            l2c_lcarb__cmd_o.lcaddr    =  {csr_tag_addr_reg,csr_index_addr_reg,{OFT_WTH{1'b0}}};
//            l2c_lcarb__cmd_o.rtaddr    =  {csr_tag_addr_reg,csr_index_addr_reg,{OFT_WTH{1'b0}}};
//        end else if(rm_r_ndma_cfg_act_i) begin
//            l2c_lcarb__cmd_valid_o     =  1'b1;
//            l2c_lcarb__cmd_o.cmd       =  ndma_r_cmd;
//            l2c_lcarb__cmd_o.size      =  dma_tras_num_4KB;
//            l2c_lcarb__cmd_o.destx     =  dma_ddr_destx;
//            l2c_lcarb__cmd_o.desty     =  dma_ddr_desty;
//            l2c_lcarb__cmd_o.lcaddr    =  {rm_tag_addr,rm_index_addr,rm_offset_addr};
//            l2c_lcarb__cmd_o.rtaddr    =  {rm_tag_addr,rm_index_addr,rm_offset_addr};
//        end else if(whm_r_ndma_cfg_act_i) begin
//            l2c_lcarb__cmd_valid_o     =  1'b1;
//            l2c_lcarb__cmd_o.cmd       =  ndma_r_cmd;
//            l2c_lcarb__cmd_o.size      =  dma_tras_num_4KB;
//            l2c_lcarb__cmd_o.destx     =  dma_ddr_destx;
//            l2c_lcarb__cmd_o.desty     =  dma_ddr_desty;
//            l2c_lcarb__cmd_o.lcaddr    =  {wr_hit_miss_tag_addr_reg,wr_hit_miss_index_addr_reg,wr_hit_miss_offset_addr_reg};
//            l2c_lcarb__cmd_o.rtaddr    =  {wr_hit_miss_tag_addr_reg,wr_hit_miss_index_addr_reg,wr_hit_miss_offset_addr_reg};
//        end else begin
//            l2c_lcarb__cmd_valid_o     =  1'b0;
//            l2c_lcarb__cmd_o.cmd       =  ndma_r_cmd;
//            l2c_lcarb__cmd_o.size      =  dma_tras_num_4KB;
//            l2c_lcarb__cmd_o.destx     =  dma_ddr_destx;
//            l2c_lcarb__cmd_o.desty     =  dma_ddr_desty;
//            l2c_lcarb__cmd_o.lcaddr    =  1'b0;
//            l2c_lcarb__cmd_o.rtaddr    =  1'b0;
//        end
//    end
    // aw
    always_comb begin
        if(rm_dty_w_ndma_cfg_act_i) begin
            l2c_lcarb__cmd_valid_o    =  1'b1;
            l2c_lcarb__cmd_o.cmd      =  ndma_w_cmd;
            l2c_lcarb__cmd_o.size     =  dma_tras_num_4KB;
            l2c_lcarb__cmd_o.destx    =  dma_ddr_destx;
            l2c_lcarb__cmd_o.desty    =  dma_ddr_desty;
            l2c_lcarb__cmd_o.lcaddr   =  {rm_vtm_tag_value_reg[TAG_WTH-1:0],rm_index_addr,{OFT_WTH{1'b0}}};
            l2c_lcarb__cmd_o.rtaddr   =  {rm_vtm_tag_value_reg[TAG_WTH-1:0],rm_index_addr,{OFT_WTH{1'b0}}};
        end else if(whm_dty_w_ndma_cfg_act_i) begin
            l2c_lcarb__cmd_valid_o     =  1'b1;
            l2c_lcarb__cmd_o.cmd       =  ndma_w_cmd;
            l2c_lcarb__cmd_o.size      =  dma_tras_num_4KB;
            l2c_lcarb__cmd_o.destx     =  dma_ddr_destx;
            l2c_lcarb__cmd_o.desty     =  dma_ddr_desty;
            l2c_lcarb__cmd_o.lcaddr    =  {whm_vtm_tag_value_reg[TAG_WTH-1:0],wr_hit_miss_index_addr_reg,{OFT_WTH{1'b0}}};
            l2c_lcarb__cmd_o.rtaddr    =  {whm_vtm_tag_value_reg[TAG_WTH-1:0],wr_hit_miss_index_addr_reg,{OFT_WTH{1'b0}}};
        end else if(csr_w_ndma_cfg_act_i) begin
            l2c_lcarb__cmd_valid_o     =  1'b1;
            l2c_lcarb__cmd_o.cmd       =  ndma_w_cmd;
            l2c_lcarb__cmd_o.size      =  dma_tras_num_4KB;
            l2c_lcarb__cmd_o.destx     =  dma_ddr_destx;
            l2c_lcarb__cmd_o.desty     =  dma_ddr_desty;
            l2c_lcarb__cmd_o.lcaddr    =  {csr_tag_addr_reg,csr_index_addr_reg,{OFT_WTH{1'b0}}};
            l2c_lcarb__cmd_o.rtaddr    =  {csr_tag_addr_reg,csr_index_addr_reg,{OFT_WTH{1'b0}}};
        end else if(rm_r_ndma_cfg_act_i) begin
            l2c_lcarb__cmd_valid_o     =  1'b1;
            l2c_lcarb__cmd_o.cmd       =  ndma_r_cmd;
            l2c_lcarb__cmd_o.size      =  dma_tras_num_4KB;
            l2c_lcarb__cmd_o.destx     =  dma_ddr_destx;
            l2c_lcarb__cmd_o.desty     =  dma_ddr_desty;
            l2c_lcarb__cmd_o.lcaddr    =  {rm_tag_addr,rm_index_addr,{OFT_WTH{1'b0}}};
            l2c_lcarb__cmd_o.rtaddr    =  {rm_tag_addr,rm_index_addr,{OFT_WTH{1'b0}}};
        end else if(whm_r_ndma_cfg_act_i) begin
            l2c_lcarb__cmd_valid_o     =  1'b1;
            l2c_lcarb__cmd_o.cmd       =  ndma_r_cmd;
            l2c_lcarb__cmd_o.size      =  dma_tras_num_4KB;
            l2c_lcarb__cmd_o.destx     =  dma_ddr_destx;
            l2c_lcarb__cmd_o.desty     =  dma_ddr_desty;
            l2c_lcarb__cmd_o.lcaddr    =  {wr_hit_miss_tag_addr_reg,wr_hit_miss_index_addr_reg,{OFT_WTH{1'b0}}};
            l2c_lcarb__cmd_o.rtaddr    =  {wr_hit_miss_tag_addr_reg,wr_hit_miss_index_addr_reg,{OFT_WTH{1'b0}}};
        end else begin
            l2c_lcarb__cmd_valid_o     =  1'b0;
            l2c_lcarb__cmd_o.cmd       =  ndma_r_cmd;
            l2c_lcarb__cmd_o.size      =  dma_tras_num_4KB;
            l2c_lcarb__cmd_o.destx     =  dma_ddr_destx;
            l2c_lcarb__cmd_o.desty     =  dma_ddr_desty;
            l2c_lcarb__cmd_o.lcaddr    =  1'b0;
            l2c_lcarb__cmd_o.rtaddr    =  1'b0;
        end
    end

    always_ff@(posedge clk_i, `RST_DECL(rst_i))
    begin
        if(`RST_TRUE(rst_i))
            begin
            lcarb_ren_d0 <= 1'b0;
            lcarb_ren_d1 <= 1'b0;
            lcarb_rdata_d0 <= {(L2_L1_DWT){1'b0}};
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                lcarb_ren_way_d0[i]    <=  1'b0;
                end
            end
        else
            begin
            lcarb_ren_d0 <= lcarb_l2c__mem_req_i.rd_en;
            lcarb_ren_d1 <= lcarb_ren_d0;
            lcarb_rdata_d0 <= lcarb_rdata; 
            for(int i=0;i<WAY_NUM;i=i+1)
                begin
                lcarb_ren_way_d0[i]    <=  dataram_cs[i]&(~dataram_we[i]);
                end
            end
    end




    assign  l2c_lcarb__mem_rsp_o.rdata_act = lcarb_ren_d1;
    assign  l2c_lcarb__mem_rsp_o.rdata = lcarb_rdata_d0; 
    assign  l2c_lcarb__mem_rsp_o.atom_ready = 1'b0; 

    always_ff@(posedge clk_i, `RST_DECL(rst_i)) begin
    if(`RST_TRUE(rst_i))begin
        lcarb_ren_way_encoder <= {WAY_WTH{1'b0}};
    end
    else if(rm_dty_w_ndma_cfg_act_i)begin
        lcarb_ren_way_encoder <= rm_vtm_way_encoder_reg;
        end
    else if(whm_dty_w_ndma_cfg_act_i)begin
        lcarb_ren_way_encoder <= wr_hit_miss_vtm_way_encoder_reg;
        end
    else if(csr_w_ndma_cfg_act_i) begin
        lcarb_ren_way_encoder <= csr_w_dnma_way_encoder_reg;
        end
    end
    /* mux data ram data 
    encoder dataram_ren_way_encoder0
    (
        .a  ( lcarb_ren_way_d0[0]      )   ,
        .b  ( lcarb_ren_way_d0[1]      )   ,
        .c  ( lcarb_ren_way_d0[2]      )   ,
        .d  ( lcarb_ren_way_d0[3]      )   ,
        .out( lcarb_ren_way_encoder    )
    );*/
    mux4 #(.width(L2_L1_DWT)) dataram_ren_way_mux
    (
        .sel    ( lcarb_ren_way_encoder    ),
        .a      ( dataram_rdata[0]         ),
        .b      ( dataram_rdata[1]         ),
        .c      ( dataram_rdata[2]         ),
        .d      ( dataram_rdata[3]         ),
        .f      ( lcarb_rdata )
    );


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////



    assign  write_buffer_fifo_empty_o = wb_fifo_empty;
    /* write buffer */
    write_buffer_fifo #(
        .OFT_WTH(OFT_WTH),
        .TAG_WTH(TAG_WTH),
        .INDEX_WTH(INDEX_WTH),
        .FIFO_LEN(8                     ),
        .DATA_A_WTH(L1_L2_AWT           ),
        .DATA_D_WTH(L1_L2_DWT+4         ),
        .ADDR_WTH(3                     ),
        .FULL_ASSERT_VALUE(7),
        .FULL_NEGATE_VALUE(7),
        .EMPTY_ASSERT_VALUE(0),
        .EMPTY_NEGATE_VALUE(0)
    ) wb_fifo (
        .clk_i             ( clk_i                                   ),
        .rst_i             ( rst_i                                   ),
        .cmp_en_i          ( wb_fifo_cmp_en                          ),
        .cmp_data_a_i      ( wb_fifo_cmp_data_a                      ),
        .cmp_result_o      ( wb_fifo_cmp_result                      ),
        .wr_data_a_i       ( wb_fifo_wr_data_a    [L1_L2_AWT -1 : 0] ),
        .wr_data_d_i       ( wb_fifo_wr_data_d    [(L1_L2_DWT+4)-1:0]),
        .wr_en_i           ( wb_fifo_wr_en                           ),
        .full_o            (                                         ),
        .a_full_o          ( wb_fifo_full                            ),
        .rd_data_a_o       ( wb_fifo_rd_data_a    [L1_L2_AWT -1 : 0] ),
        .rd_data_d_o       ( wb_fifo_rd_data_d    [(L1_L2_DWT+4)-1:0]),
        .rd_en_i           ( wb_fifo_rd_en                           ),
        .empty_o           ( wb_fifo_empty                           ),
        .a_empty_o         (                                         )
        );




    /*************tag ram data ram******************/
    /*
    cache data parameter :
    cache line           : 4KB
    cache way            : 4-way
    cache set            : 8-set

    data ram paramter    :  
    per way              :      depth 1024 x width 32B(256bit)
    4-ways               : 4 x  depth 1024 x width 32B(256bit) = 128KB
    */






    generate
        for (gi=0; gi<WAY_NUM; gi=gi+1) begin : dataram_dataram_valid_diryt_gen 
        // data ram:
        if(INDEX_WTH==2)
            begin
                sp_d512_w256 dataram_inst(
                    .clk_i          (clk_i                     ),
                    .cs_i           (dataram_cs[gi]            ),
                    .we_i           (dataram_we[gi]            ),
                    .addr_i         (dataram_addr[gi]          ),
                    .wdata_i        (dataram_wdata[gi]         ),
                    .wdata_strob_i  (dataram_wdata_strob[gi]   ),         
                    .rdata_o        (dataram_rdata[gi]         )
                );
                /*sdp_d512_w256 dataram_inst
                (
                    .clk_i          (clk_i                     ),
                    .we_i           (dataram_we[gi]            ),
                    .waddr_i        (dataram_addr[gi]         ),
                    .wdata_i        (dataram_wdata[gi]         ),
                    .wdata_strob_i  (dataram_wdata_strob[gi]   ),         
                    .re_i           (dataram_re[gi]            ),
                    .raddr_i        (dataram_raddr[gi]         ),
                    .rdata_o        (dataram_rdata[gi]         )
                );*/
            end
        else if(INDEX_WTH==3)
            begin
                sp_d1024_w256 dataram_inst(
                    .clk_i          (clk_i                     ),
                    .cs_i           (dataram_cs[gi]            ),
                    .we_i           (dataram_we[gi]            ),
                    .addr_i         (dataram_addr[gi]          ),
                    .wdata_i        (dataram_wdata[gi]         ),
                    .wdata_strob_i  (dataram_wdata_strob[gi]   ),         
                    .rdata_o        (dataram_rdata[gi]         )
                );
            /*sdp_d1024_w256 dataram_inst
                (
                    .clk_i          (clk_i                     ),
                    .we_i           (dataram_we[gi]            ),
                    .waddr_i        (dataram_addr[gi]         ),
                    .wdata_i        (dataram_wdata[gi]         ),
                    .wdata_strob_i  (dataram_wdata_strob[gi]   ),         
                    .re_i           (dataram_re[gi]            ),
                    .raddr_i        (dataram_raddr[gi]         ),
                    .rdata_o        (dataram_rdata[gi]         )
                );*/
            end
        // tag ram
        array #(.DWTH(TAG_WTH+1),.AWTH(INDEX_WTH),.DEPTH(4)) tagram_inst
        (
            .clk_i         (   clk_i             ),
            .rst_i         (   rst_i             ),
            .wen_i         (   tagram_wen[gi]    ),   
            .waddr_i       (   tagram_waddr[gi]  ),   
            .wdata_i       (   {1'b0,tagram_wdata[gi]}  ),   
            .raddr_i       (   tagram_raddr[gi]  ),   
            .rdata_o       (   tagram_rdata[gi]  )      
        );
        /*
        dirty bit
        */
        multi_reg #( .DWTH(4),.AWTH(INDEX_WTH) ) dirty_inst
        (
            .clk_i       (  clk_i            ) ,    
            .rst_i       (  rst_i            ) ,     
            .all_srst_i  (  dty_all_srst[gi] ) ,        
            .w_en_set_i  (  dty_w_en_set[gi]      ) , // same number as cache line 8
            .w_en_reset_i(  dty_w_en_reset[gi]    ) ,  
            .waddr_i     (  dty_waddr[gi]  ) ,   
            .raddr_i     (  dty_raddr[gi]    ) ,                   
            .rdata_o     (  dty_rdata[gi]    )  
        );

        /*
        valid bit
        */
        multi_reg #(.DWTH(4),.AWTH(INDEX_WTH)) valid_inst
        (
            .clk_i       (clk_i) ,    
            .rst_i       (rst_i) ,     
            .all_srst_i  (vld_all_srst[gi]) ,        
            .w_en_set_i  (vld_w_en_set[gi]) , // same number as cache line 8
            .w_en_reset_i(vld_w_en_reset[gi]) ,  
            .waddr_i     (vld_waddr[gi]) ,   
            .raddr_i     (vld_raddr[gi]) ,                   
            .rdata_o     (vld_rdata[gi])  
        );
        comparator  #( .WTH(TAG_WTH+1) ) comparator_inst
        (
            .en        (cmp_en[gi]),
            .a         (cmp_tag) ,    
            .b         (cmp_way_tag[gi]) ,     // tagram_rdata[gi]
            .out       (cmp_result[gi]) 
        );
    
    end 
    endgenerate


    
    pseudo_lru #(.INDEX_WTH(INDEX_WTH),.LINE_NUM(4),.WAY_WTH(2)) pseudo_lru_inst
    (
    .clk_i           (clk_i),  
    .rst_i           (rst_i),  
    .srst_lru_i      (plru_srst_lru),       
    .update_lru_i    (plru_update_lru),       
    .windex_i        (plru_windex),   
    .rindex_i        (plru_rindex),                  
    .cur_way_i       (plru_cur_way),                  
    .vtm_way_o       (plru_vtm_way)               
    );
endmodule
