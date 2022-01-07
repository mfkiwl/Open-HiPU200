`timescale 1ns/1ps
`include "hpu_head.sv"
import hpu_pkg::*;

 
module l2_cache
#
(
    parameter L1_L2_AWT             = 32,     // unit Byte
    parameter L1_L2_DWT             = 4 *8,   // 4B
    parameter L2_L1_DWT             = 32*8,   // 64B
    parameter CSR_L2C__ADDR_WTH     =  12  ,
    parameter CSR_L2C__DATA_WTH     =  32
)
(
    input  logic                                        clk_i,
    input  logic                                        rst_i,
    
    //l1 data cache interface 
    input  logic                                        l1d_l2__rd_en_i,          
    input  logic                                        l1d_l2__wr_en_i,        
    input  logic[L1_L2_AWT-1:0]                         l1d_l2__addr_i,         
    output logic                                        l2_l1d__suc_o,        
    output logic                                        l2_l1d__suc_act_o,       
    output logic[L2_L1_DWT-1:0]                         l2_l1d__rdata_o,              
    output logic                                        l2_l1d__rdata_act_o,        
    input  logic[L1_L2_DWT-1:0]                         l1d_l2__wdata_i,        
    input  logic                                        l1d_l2__wdata_act_i,      
    input  logic[3:0]                                   l1d_l2__wstrb_i,    

    //l1 instruction cache interface            
    input  logic                                        l1i_l2__rd_en_i,
    input  logic[L1_L2_AWT-1:0]                         l1i_l2__addr_i,      
    output logic                                        l2_l1i__suc_o,          
    output logic                                        l2_l1i__suc_act_o,      
    output logic[L2_L1_DWT-1:0]                         l2_l1i__rdata_o,
    output logic                                        l2_l1i__rdata_act_o,

    // command path
    output  ndma_cmd_t                                  l2c_lcarb__cmd_o,
    output  logic                                       l2c_lcarb__cmd_valid_o,
    input   logic                                       lcarb_l2c__cmd_ready_i,
    input   logic                                       lcarb_l2c__cmd_done_i,
    // data path
    input   ndma_mem_req_t                              lcarb_l2c__mem_req_i,
    output  ndma_mem_rsp_t                              l2c_lcarb__mem_rsp_o,

    input  csr_bus_req_t                                csr_l2c__bus_req,
    output csr_bus_rsp_t                                l2c_csr__bus_rsp,
 
    output logic                                        l2c_csr__csr_finish_o
);
    logic[1:0]                                          chan_use_dly1;                                // channel select
    logic                                               l1_l2_rwen_back_hit;                          // l2 to l1 hit or data
    logic                                               l1_l2_rwen_back_first_data;                   
    logic                                               l1_l2_ren_back_second_data;                   
    logic                                               l1_l2_ren_use;                                // control to data rw addr info
    logic                                               l1_l2_wen_use;
    logic[L1_L2_AWT-1:0]                                l1_l2_addr_use;
    logic                                               hit_reuslt;                                   // data to control suc_fsm hit info
    logic                                               suc_rhit_wb_fifo_exist;                       // data to control suc_fsm hit info
    logic                                               suc_rhit_way_dataram_busy;                    // data to control suc_fsm hit info
    logic[L1_L2_AWT-1:0]                                rd_miss_addr;
    logic                                               rm_rall_tag_vld_dty_act;
    logic                                               rm_vtm_dty_or_not_act;
    logic                                               rm_vtm_dty_clear_vld_act;
    logic                                               rm_vtm_set_vd_act;
    logic                                               rm_end_act;
    logic                                               rm_vtm_dirty;
    logic                                               whm_rall_tag_vld_dty_lru_act;                 // updata_fsm write hit of miss flow
    logic                                               whm_hit_or_not_act;
    logic                                               whm_clear_vld_r_wb_act;
    logic                                               whm_vtm_is_dirty;
    logic                                               whm_miss_set_vld_act;
    logic                                               whm_hit_set_dty_act;
    logic                                               whm_end_act;
    logic                                               whm_hit;
    logic [L1_L2_AWT-1: 0]                              whm_miss_addr_from_wb_fifo;
    logic                                               write_buffer_fifo_empty;
    logic                                               csr_r_tag_vld_act_dty;
    logic                                               csr_r_cmp_act;
    logic                                               csr_rwb_act;
    logic                                               csr_read_vld_hit_or_not_act;
    logic                                               csr_w_ndma_cfg_pre_two_clk_act;
    logic                                               csr_clr_vld_if_need_act;
    logic                                               csr_w_ndma_cfg_act;
    logic                                               csr_w_ndma_wait_act;
    logic                                               csr_hit;
    logic                                               csr_hit_dty;
    logic                                               csr_wb_exist;
    logic[2:0]                                          csr_model;
    logic[31:0]                                         csr_addr_set_way;
    logic                                               rm_dty_w_ndma_cfg_act;
    logic                                               rm_dty_w_ndma_wait_act;
    logic                                               rm_r_ndma_cfg_act;
    logic                                               rm_r_ndma_cfg_wait;
    logic                                               whm_dty_w_ndma_cfg_act;
    logic                                               whm_dty_w_ndma_wait_act;
    logic                                               whm_r_ndma_cfg_act;
    logic                                               whm_r_ndma_wait_act;

/*
  clk_wiz_0 instance_name
   (
    // Clock out ports
    .clk_o(clk_i),     // output clk_o
   // Clock in ports
    .clk_in1(clk_org));      // input clk_in1
*/
l2_cache_ctrl
#
(
    .L1_L2_AWT                                      (L1_L2_AWT),
    .L1_L2_DWT                                      (L1_L2_DWT),
    .L2_L1_DWT                                      (L2_L1_DWT),
    .CSR_L2C__ADDR_WTH                              (CSR_L2C__ADDR_WTH),
    .CSR_L2C__DATA_WTH                              (CSR_L2C__DATA_WTH)
)
l2_cache_ctrl_inst
(
    .clk_i                                          (clk_i),
    .rst_i                                          (rst_i),
    .l1d_l2__rd_en_i                                (l1d_l2__rd_en_i),                                  //l1 data cache interface         
    .l1d_l2__wr_en_i                                (l1d_l2__wr_en_i),       
    .l1d_l2__addr_i                                 (l1d_l2__addr_i),        
    .l1d_l2__wdata_i                                (l1d_l2__wdata_i),       
    .l1d_l2__wdata_act_i                            (l1d_l2__wdata_act_i),                 
    .l1i_l2__rd_en_i                                (l1i_l2__rd_en_i),                                  //l1 instruction cache interface 
    .l1i_l2__addr_i                                 (l1i_l2__addr_i),                        
    .csr_l2c__bus_req                               (csr_l2c__bus_req),
    .l2c_csr__bus_rsp                               (l2c_csr__bus_rsp),
    .l2c_csr__csr_finish_o                          (l2c_csr__csr_finish_o),              
    .chan_use_dly1_o                                (chan_use_dly1),                                    // channel select
    .l1_l2_rwen_back_hit_o                          (l1_l2_rwen_back_hit),                              // l2 to l1 hit or data
    .l1_l2_rwen_back_first_data_o                   (l1_l2_rwen_back_first_data),     
    .l1_l2_ren_back_second_data_o                   (l1_l2_ren_back_second_data),      
    .l1_l2_ren_use_o                                (l1_l2_ren_use),                                    // control to data rw addr info
    .l1_l2_wen_use_o                                (l1_l2_wen_use),     
    .l1_l2_addr_use_o                               (l1_l2_addr_use),     
    .hit_reuslt_i                                   (hit_reuslt),                                       
    .suc_rhit_wb_fifo_exist_i                       (suc_rhit_wb_fifo_exist),                           
    .suc_rhit_way_dataram_busy_i                    (suc_rhit_way_dataram_busy),                        
    .rd_miss_addr_o                                 (rd_miss_addr),     
    .rm_rall_tag_vld_dty_act_o                      (rm_rall_tag_vld_dty_act),     
    .rm_vtm_dty_or_not_act_o                        (rm_vtm_dty_or_not_act),   
    .rm_dty_w_ndma_cfg_act_o                        (rm_dty_w_ndma_cfg_act),            
    .rm_dty_w_ndma_wait_act_o                       (rm_dty_w_ndma_wait_act),             
    .rm_r_ndma_cfg_act_o                            (rm_r_ndma_cfg_act),        
    .rm_r_ndma_cfg_wait_o                           (rm_r_ndma_cfg_wait),         
    .rm_vtm_dty_clear_vld_act_o                     (rm_vtm_dty_clear_vld_act),   
    .rm_vtm_set_vd_act_o                            (rm_vtm_set_vd_act),   
    .rm_end_act_o                                   (rm_end_act),   
    .rm_vtm_dirty_i                                 (rm_vtm_dirty),   
    .whm_rall_tag_vld_dty_lru_act_o                 (whm_rall_tag_vld_dty_lru_act),                     // updata_fsm write hit of miss flow
    .whm_hit_or_not_act_o                           (whm_hit_or_not_act),   
    .whm_clear_vld_r_wb_act_o                       (whm_clear_vld_r_wb_act),                            
    .whm_vtm_is_dirty_i                             (whm_vtm_is_dirty),
    .whm_dty_w_ndma_cfg_act_o                       (whm_dty_w_ndma_cfg_act),                  
    .whm_dty_w_ndma_wait_act_o                      (whm_dty_w_ndma_wait_act),                   
    .whm_r_ndma_cfg_act_o                           (whm_r_ndma_cfg_act),              
    .whm_r_ndma_wait_act_o                          (whm_r_ndma_wait_act),               
    .whm_miss_set_vld_act_o                         (whm_miss_set_vld_act),   
    .whm_hit_set_dty_act_o                          (whm_hit_set_dty_act),   
    .whm_end_act_o                                  (whm_end_act),   
    .whm_hit_i                                      (whm_hit),  
    .whm_miss_addr_from_wb_fifo_i                   (whm_miss_addr_from_wb_fifo),
    .write_buffer_fifo_empty_i                      (write_buffer_fifo_empty),
    .csr_r_tag_vld_act_dty_o                        (csr_r_tag_vld_act_dty),
    .csr_r_cmp_act_o                                (csr_r_cmp_act),
    .csr_rwb_act_o                                  (csr_rwb_act),
    .csr_hit_or_not_act_o                           (csr_read_vld_hit_or_not_act),
    .csr_w_ndma_cfg_pre_two_clk_act_o               (csr_w_ndma_cfg_pre_two_clk_act),
    .csr_w_ndma_cfg_act_o                           (csr_w_ndma_cfg_act),
    .csr_w_ndma_wait_act_o                          (csr_w_ndma_wait_act),
    .csr_clr_vld_if_need_act_o                      (csr_clr_vld_if_need_act),
    .csr_hit_i                                      (csr_hit),
    .csr_hit_dty_i                                  (csr_hit_dty),
    .csr_wb_exist_i                                 (csr_wb_exist),
    .csr_model_o                                    (csr_model),
    .csr_addr_set_way_o                             (csr_addr_set_way),
    .lcarb_l2c__cmd_ready_i                         (lcarb_l2c__cmd_ready_i),
    .lcarb_l2c__cmd_done_i                          (lcarb_l2c__cmd_done_i)
);


L2_cache_data_path # (
    .L1_L2_AWT                                      (L1_L2_AWT), 
    .L1_L2_DWT                                      (L1_L2_DWT),            
    .L2_L1_DWT                                      (L2_L1_DWT),                                        
    .CSR_L2C__ADDR_WTH                              (CSR_L2C__ADDR_WTH),                      
    .CSR_L2C__DATA_WTH                              (CSR_L2C__DATA_WTH) 
)
L2_cache_data_path_inst
(
    .clk_i                                          (clk_i),
    .rst_i                                          (rst_i),
    .chan_use_dly1_i                                (chan_use_dly1),                                    // channel select
    .l1_l2_rwen_back_hit_i                          (l1_l2_rwen_back_hit),                              // l2 to l1 hit or data
    .l1_l2_rwen_back_first_data_i                   (l1_l2_rwen_back_first_data),  
    .l1_l2_ren_back_second_data_i                   (l1_l2_ren_back_second_data),  
    .l2_l1d__suc_o                                  (l2_l1d__suc_o),                                    // l2 to l1d read or write     
    .l2_l1d__suc_act_o                              (l2_l1d__suc_act_o),  
    .l2_l1d__rdata_o                                (l2_l1d__rdata_o),  
    .l2_l1d__rdata_act_o                            (l2_l1d__rdata_act_o),  
    .l1d_l2__wdata_i                                (l1d_l2__wdata_i),  
    .l1d_l2__wdata_act_i                            (l1d_l2__wdata_act_i),  
    .l1d_l2__wstrb_i                                (l1d_l2__wstrb_i),  
    .l2_l1i__suc_o                                  (l2_l1i__suc_o),                                    // l2 to l1i    
    .l2_l1i__suc_act_o                              (l2_l1i__suc_act_o),  
    .l2_l1i__rdata_o                                (l2_l1i__rdata_o),
    .l2_l1i__rdata_act_o                            (l2_l1i__rdata_act_o),  
    .l1_l2_ren_use_i                                (l1_l2_ren_use),                                    // control to data rw addr info
    .l1_l2_wen_use_i                                (l1_l2_wen_use),
    .l1_l2_addr_use_i                               (l1_l2_addr_use),
    .l1d_l2__addr_i                                 (l1d_l2__addr_i),       
    .hit_reuslt_o                                   (hit_reuslt),                           
    .suc_rhit_wb_fifo_exist_o                       (suc_rhit_wb_fifo_exist),               
    .suc_rhit_way_dataram_busy_o                    (suc_rhit_way_dataram_busy),            
    .rd_miss_addr_i                                 (rd_miss_addr),
    .rm_rall_tag_vld_dty_act_i                      (rm_rall_tag_vld_dty_act),   
    .rm_vtm_dty_or_not_act_i                        (rm_vtm_dty_or_not_act),  
    .rm_vtm_dty_clear_vld_act_i                     (rm_vtm_dty_clear_vld_act),  
    .rm_dty_w_ndma_cfg_act_i                        (rm_dty_w_ndma_cfg_act),
    .rm_dty_w_ndma_wait_act_i                       (rm_dty_w_ndma_wait_act),
    .rm_r_ndma_cfg_act_i                            (rm_r_ndma_cfg_act),
    .rm_r_ndma_cfg_wait_i                           (rm_r_ndma_cfg_wait),
    .rm_vtm_set_vd_act_i                            (rm_vtm_set_vd_act),  
    .rm_end_act_i                                   (rm_end_act),  
    .rm_vtm_dirty_o                                 (rm_vtm_dirty),  
    .whm_rall_tag_vld_dty_lru_act_i                 (whm_rall_tag_vld_dty_lru_act),                     // updata_fsm write hit of miss flow
    .whm_hit_or_not_act_i                           (whm_hit_or_not_act),  
    .whm_clear_vld_r_wb_act_i                       (whm_clear_vld_r_wb_act),  
    .whm_vtm_is_dirty_o                             (whm_vtm_is_dirty),
    .whm_dty_w_ndma_cfg_act_i                       (whm_dty_w_ndma_cfg_act),                  
    .whm_dty_w_ndma_wait_act_i                      (whm_dty_w_ndma_wait_act),                   
    .whm_r_ndma_cfg_act_i                           (whm_r_ndma_cfg_act),              
    .whm_r_ndma_wait_act_i                          (whm_r_ndma_wait_act), 
    .whm_miss_set_vld_act_i                         (whm_miss_set_vld_act),  
    .whm_hit_set_dty_act_i                          (whm_hit_set_dty_act),           
    .whm_end_act_i                                  (whm_end_act),           
    .whm_hit_o                                      (whm_hit),
    .whm_miss_addr_from_wb_fifo_o                   (whm_miss_addr_from_wb_fifo),
    .write_buffer_fifo_empty_o                      (write_buffer_fifo_empty),
    .csr_r_tag_vld_act_dty_i                        (csr_r_tag_vld_act_dty),
    .csr_r_cmp_act_i                                (csr_r_cmp_act),
    .csr_rwb_act_i                                  (csr_rwb_act),
    .csr_hit_or_not_act_i                           (csr_read_vld_hit_or_not_act),
    .csr_w_ndma_cfg_pre_two_clk_act_i               (csr_w_ndma_cfg_pre_two_clk_act),
    .csr_w_ndma_cfg_act_i                           (csr_w_ndma_cfg_act),
    .csr_w_ndma_wait_act_i                          (csr_w_ndma_wait_act),
    .csr_clr_vld_if_need_act_i                      (csr_clr_vld_if_need_act),
    .csr_hit_o                                      (csr_hit),
    .csr_hit_dty_o                                  (csr_hit_dty),
    .csr_wb_exist_o                                 (csr_wb_exist),
    .csr_model_i                                    (csr_model),
    .csr_addr_set_way_i                             (csr_addr_set_way),
    .l2c_lcarb__cmd_o                               (l2c_lcarb__cmd_o),
    .l2c_lcarb__cmd_valid_o                         (l2c_lcarb__cmd_valid_o),
    .lcarb_l2c__mem_req_i                           (lcarb_l2c__mem_req_i),
    .l2c_lcarb__mem_rsp_o                           (l2c_lcarb__mem_rsp_o)
);



endmodule
