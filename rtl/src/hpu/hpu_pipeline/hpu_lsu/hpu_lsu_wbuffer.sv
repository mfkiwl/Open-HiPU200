`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_lsu_wbuffer (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   flush_en_i,
    input   update_ckpt_t                           id__ckpt_rcov_i,
    input   ckpt_t                                  id__prefet_ckpt_i,
    output  logic                                   wb_iq__flush_finsh_o,
    input   logic[LSU_IQ_INDEX-1 : 0]               exu_wb__entry_addr_i,
    input  lsu_inst_t                               exu_wb__inst_i,
    input  logic                                    exu_wb__inst_valid_i,
    input   pc_t                                    lsu_lcmem__raddr_i,
    input   pc_t                                    lsu_lcmem__dtcm_raddr_i,
    input   pc_t                                    lsu_dc__raddr_i,
    input   logic[CSR_WTH-1 : 0]                    lsu_csr__raddr_i,
    input   pc_t                                    lsu_clint__raddr_i,
    input   logic                                   exu_wb__sb_we_i,
    input   logic                                   exu_wb__csrsb_we_i,
    input   pc_t                                    exu_wb__mem_addr_i,
    input   data_t                                  exu_wb__st_rs2_data_i,
    output  logic                                   wb_iq__csrsb_full_o,
    output  logic                                   wb_iq__sb_full_o,
    output  logic                                   lsu_prf__rdst_en_o,
    output  phy_sr_index_t                          lsu_prf__rdst_index_o,
    output  data_t                                  lsu_prf__rdst_data_o,
    output  awake_index_t                           lsu_iq__awake_o,
    output  logic[CSR_WTH-1 : 0]                    lsu_csr__waddr_o,
    output  logic                                   lsu_csr__wr_en_o,
    input   data_t                                  csr_lsu__rdata_i,
    input   data_t                                  lsu_csr__rs1_data_i,
    output  data_t                                  lsu_csr__wdata_o,
    input   logic                                   exu_wb__lcmem_hit_i,
    input   logic                                   exu_wb__dtcm_atom_hit_i,
    input   logic                                   exu_wb__dcache_hit_i,
    input   logic                                   exu_wb__clint_hit_i,
    output  pc_t                                    lsu_lmrw__waddr_o,
    output  logic                                   lsu_lmrw__wr_en_o,
    output  data_t                                  lsu_lmrw__wdata_o,
    output  data_strobe_t                           lsu_lmrw__wstrb_o,
    input   data_t                                  lmrw_lsu__rdata_i,
    output  pc_t                                    lsu_clint__waddr_o,
    output  logic                                   lsu_clint__wr_en_o,
    output  data_t                                  lsu_clint__wdata_o,
    output  data_strobe_t                           lsu_clint__wstrb_o,
    input   data_t                                  clint_lsu__rdata_i,
    input   data_t                                  exu_wb__dtcm_atom_rs2_data_i,
    output  logic                                   lsu_dtcm__wr_rls_lock_o,
    input   logic                                   dtcm_lsu__wr_suc_i,
    output  pc_t                                    lsu_dtcm__waddr_o,
    output  logic                                   lsu_dtcm__wr_en_o,
    output  data_t                                  lsu_dtcm__wdata_o,
    output  data_strobe_t                           lsu_dtcm__wstrb_o,
    input   logic                                   dtcm_lsu__rd_suc_i,
    input   data_t                                  dtcm_lsu__rdata_i,
    input   logic                                   dc_lsu__rd_suc_i,
    input   data_t                                  dc_lsu__rdata_i,
    output  logic                                   lsu_dc__nonblk_wr_en_o,
    output  pc_t                                    lsu_dc__waddr_o,
    input   logic                                   dc_lsu__wr_suc_i,
    output  data_t                                  lsu_dc__wdata_o,
    output  data_strobe_t                           lsu_dc__wstrb_o,
    input   logic                                   lsu_addr_unalian_exc_en_i,
    output  logic[LSU_IQ_LEN-1:0]                   cmt_iq__rmv_en_o,
    output  logic[LSU_IQ_LEN-1:0]                   cmt_iq__rmv_sel_en_o,
    output  logic[LSU_IQ_LEN-1:0]                   cmt_iq__cg_issued_en_o,
    input  lsu_retire_t                             rob_lsu__retire_i, 
    output lsu_commit_t                             lsu_rob__commit_o
);
localparam    CSR_WB_NUM = 8;
localparam    ST_ATOM_WB_NUM = 8;
localparam    CSR_WB_INX_WTH = 3;
localparam    ST_ATOM_WB_WTH = 3;
localparam    CSR_FULL_ASSERT_VALUE = 0;
localparam    CSR_FULL_NEGATE_VALUE = 0;
localparam    CSR_EMPTY_ASSERT_VALUE = 0;
localparam    CSR_EMPTY_NEGATE_VALUE = 0;
localparam    ST_ATOM_FULL_ASSERT_VALUE = 4;
localparam    ST_ATOM_FULL_NEGATE_VALUE = 4;
localparam    ST_ATOM_EMPTY_ASSERT_VALUE = 0;
localparam    ST_ATOM_EMPTY_NEGATE_VALUE = 0;
localparam    LCMEM_ADDR_STRT = 32'h0210_0000;
localparam    LCMEM_ADDR_END  = 32'h022f_ffff;
localparam    DTCM_ADDR_STRT = 32'h0203_0000;
localparam    DTCM_ADDR_END  = 32'h0203_ffff;
localparam    CACHE_ADDR_STRT= 32'h8000_0000;
localparam    CACHE_ADDR_END = 32'h9fff_ffff;
localparam    CLINT_ADDR_STRT  = 32'h0200_0000;
localparam    CLINT_ADDR_END   = 32'h0200_ffff;
lsu_wbuffer_csr_t [CSR_WB_NUM-1 : 0]                csr_wbuffer;
lsu_wbuffer_csr_t                                   csr_wbuffer_rd_data;
lsu_wbuffer_st_atom_t [ST_ATOM_WB_NUM-1 : 0]        st_atom_wbuffer;
lsu_wbuffer_st_atom_t                               st_atom_wbuffer_rd_data;
logic                                               csr_wb_a_empty;
logic                                               csr_wb_a_full;
logic                                               st_atom_wb_a_empty;
logic                                               st_atom_wb_a_full;
logic                                               csr_wb_full;
logic                                               st_atom_wb_full;
logic                                               csr_wb_empty;
logic                                               st_atom_wb_empty;
logic  [CSR_WB_INX_WTH-1 :0]                        csr_wb_head_ptr;
logic  [CSR_WB_INX_WTH-1 :0]                        csr_wb_tail_ptr;
logic                                               csr_head_mark;
logic                                               csr_tail_mark;
logic  [ST_ATOM_WB_WTH-1 :0]                        st_atom_wb_head_ptr;
logic  [ST_ATOM_WB_WTH-1 :0]                        st_atom_wb_tail_ptr;
logic                                               st_atom_head_mark;
logic                                               st_atom_tail_mark;
lsu_inst_t                                          lsu_wb_inst_reg0; 
lsu_inst_t                                          lsu_wb_inst_reg1; 
logic                                               lsuexu_wb__dcache_hit_reg0;
logic                                               lsuexu_wb__dcache_hit_reg1;
logic                                               lsuexu_wb__lcmem_hit_reg0;
logic                                               lsuexu_wb__lcmem_hit_reg1;
logic                                               lsuexu_wb__dtcm_atom_hit_reg0;
logic                                               lsuexu_wb__dtcm_atom_hit_reg1;
logic                                               lsuexu_wb__clint_hit_reg0;
logic                                               lsuexu_wb__clint_hit_reg1;
logic                                               dc_lsu__dcache_rd_hit_reg0;
logic                                               ld_wr_rd_en;
logic  [PC_WTH-1  :0]                               ld_wr_rd_addr;
logic  [DATA_WTH-1:0]                               ld_wr_rd_data;
logic                                               csr_wr_rd_en;
logic  [PC_WTH-1  :0]                               csr_wr_rd_addr;
logic  [DATA_WTH-1:0]                               csr_wr_rd_data;
logic                                               atom_wr_rd_en;
logic  [PC_WTH-1  :0]                               atom_wr_rd_addr;
logic  [DATA_WTH-1:0]                               atom_wr_rd_data;
logic                                               csr_wb_wr_en_reg0;
logic                                               csr_wb_wr_en_reg1;
logic [PC_WTH-1  :0]                                csr_wb_wr_addr_reg0;
logic [PC_WTH-1  :0]                                csr_wb_wr_addr_reg1;
logic [DATA_WTH-1:0]                                lsu_csr__rs1_data_reg0;
logic [DATA_WTH-1:0]                                lsu_csr__rs1_data_reg1;
logic                                               atom_wb_wr_en_reg0;
logic                                               atom_wb_wr_en_reg1;
logic [PC_WTH-1  :0]                                atom_wb_wr_addr_reg0;
logic [PC_WTH-1  :0]                                atom_wb_wr_addr_reg1;
logic [DATA_WTH-1:0]                                lsuexu_wb__atom_rs2_data_reg0;
logic [DATA_WTH-1:0]                                lsuexu_wb__atom_rs2_data_reg1;
logic                                               st_wb_wr_en_reg0;
logic                                               st_wb_wr_en_reg1;
logic [PC_WTH-1  :0]                                st_wb_wr_addr_reg0;
logic [PC_WTH-1  :0]                                st_wb_wr_addr_reg1;
logic [DATA_WTH-1:0]                                lsuexu_wb__st_rs2_data_reg0;
logic [DATA_WTH-1:0]                                lsuexu_wb__st_rs2_data_reg1;
logic                                               dtcm_lsu_rd_suc_reg0;
logic                                               st_wb_wr_en;
logic [PC_WTH-1  :0]                                st_wb_wr_addr;
logic [DATA_WTH-1:0]                                st_wb_wr_data;
logic                                               csr_wb_wr_en; 
logic  [PC_WTH-1  :0]                               csr_wb_wr_addr;
logic  [DATA_WTH-1:0]                               csr_wb_wr_data; 
logic                                               atom_wb_wr_en;
logic  [PC_WTH-1  :0]                               atom_wb_wr_addr;
logic  [DATA_WTH-1:0]                               atom_wb_wr_data; 
logic  [LSU_IQ_LEN-1 :0]                      lsucmt_iq_rmv_en;
logic  [LSU_IQ_LEN-1 :0]                      st_lsucmt_iq_rmv_en;
logic  [LSU_IQ_LEN-1:0]                       lsucmt_iq_rmv_sel_en;
logic                                               lcmem_wd_hit;
logic                                               cache_wd_hit;
logic                                               dtcm_wd_hit;
logic                                               clint_wd_hit;
logic                                               csr_wb_rd_en;
logic                                               st_atom_wb_rd_en;
logic                                               st_atom_wb_wr_en;
logic [PC_WTH-1  :0]                                st_atom_wb_wr_addr;
logic [DATA_WTH-1:0]                                st_atom_wb_wr_data;
logic [LSU_IQ_INDEX-1 : 0]                      st_atom_wb_wr_pos_index;
lsu_commit_t                                        ld_rob_commit;
lsu_commit_t                                        st_rob_commit;
lsu_commit_t                                        csr_rob_commit;
lsu_commit_t                                        fence_rob_commit;
lsu_commit_t                                        atom_rob_commit;
logic [LSU_IQ_INDEX-1 : 0]                      lsuexu_wb__entry_addr_reg0;
logic [LSU_IQ_INDEX-1 : 0]                      lsuexu_wb__entry_addr_reg1;
logic [LSU_IQ_INDEX-1 : 0]                      lsuexu_wb__entry_addr_crt_reg0;
logic [PC_WTH-1 : 0]                                lsu_lcmem_raddr_reg0;
logic [PC_WTH-1 : 0]                                lsu_lcmem_raddr_reg1;
logic [PC_WTH-1 : 0]                                lsu_lcmem_dtcm_raddr_reg0;
logic [PC_WTH-1 : 0]                                lsu_lcmem_dtcm_raddr_reg1;
logic [PC_WTH-1 : 0]                                lsu_dc_dcache_raddr_reg0;
logic [PC_WTH-1 : 0]                                lsu_dc_dcache_raddr_reg1;
logic [CSR_WTH-1: 0]                                lsu_csr_raddr_reg0;
logic [CSR_WTH-1: 0]                                lsu_csr_raddr_reg1;
logic [CSR_WTH-1: 0]                                lsu_clint_raddr_reg0;
logic [CSR_WTH-1: 0]                                lsu_clint_raddr_reg1;
awake_index_t                                       lsu_fu_awake_data;
logic                                               lsu_dtcm_wr_rls_lock;
logic                                               rob_x__jb_flush_en_reg0;
logic                                               flush_en;
logic                                               flush_en_expd;
logic [3:0]                                         flush_en_cnt;
logic [7:0]                                         rob_x__jb_flush_br_tag_reg0;
logic [7:0]                                         flush_br_tag_expd;
logic                                               lsuwb_iq_flush_finsh;
logic [LSU_IQ_LEN-1:0]                        lsucmt_iq_cg_issued_en;
data_t                                              data_strobe;
logic     [8-1:0]                                   pre_iq_rmv_en;
logic                                               lsuexu_wb__inst_valid_reg0;
always_ff  @(posedge clk_i ) begin
    rob_x__jb_flush_en_reg0 <= flush_en_i;
end 
always_ff @(posedge clk_i or  `RST_DECL(rst_i)) begin
    if(`RST_TRUE(rst_i)) begin
        flush_en <= 1'b0;
    end else if(lsuwb_iq_flush_finsh)begin 
        flush_en <= 1'b0;
    end else if(flush_en_i && (~rob_x__jb_flush_en_reg0)) begin
        flush_en <= 1'b1;
    end
end
assign flush_en_expd = flush_en | flush_en_i;
assign flush_br_tag_expd = 1'b0;
always_ff @(posedge clk_i or  `RST_DECL(rst_i)) begin
    if(`RST_TRUE(rst_i)) begin
        flush_en_cnt <= 4'd0;
    end else begin
        if(~flush_en_expd || lsuwb_iq_flush_finsh) begin
            flush_en_cnt <= 4'd0;
        end else if(flush_en_expd >= 4'd10) begin
            flush_en_cnt <= flush_en_cnt;
        end else if(flush_en_expd) begin
            flush_en_cnt <= flush_en_cnt + 1;
        end
    end
end
always_ff @(posedge clk_i or  `RST_DECL(rst_i)) begin
    if(`RST_TRUE(rst_i)) begin
        lsuwb_iq_flush_finsh = 1'b0;
    end else if(lsuwb_iq_flush_finsh) begin
        lsuwb_iq_flush_finsh = 1'b0;
    end else if((flush_en_cnt >= 4'd10) && (csr_wb_empty) && (st_atom_wb_empty)) begin
        lsuwb_iq_flush_finsh = 1'b1 ;
    end
end
assign wb_iq__flush_finsh_o = lsuwb_iq_flush_finsh;
always_ff @(posedge clk_i ) begin
    lsu_wb_inst_reg0 <= exu_wb__inst_i;
    lsu_wb_inst_reg1 <= lsu_wb_inst_reg0 ;
end
always_ff @(posedge clk_i ) begin
    lsuexu_wb__entry_addr_reg0 <= exu_wb__entry_addr_i;
    lsuexu_wb__entry_addr_reg1 <= lsuexu_wb__entry_addr_crt_reg0;
end
always_ff @(posedge clk_i) begin
    lsuexu_wb__dcache_hit_reg0 <= exu_wb__dcache_hit_i;
    lsuexu_wb__dcache_hit_reg1 <= lsuexu_wb__dcache_hit_reg0;
end
always_ff @(posedge clk_i) begin
    lsuexu_wb__lcmem_hit_reg0 <= exu_wb__lcmem_hit_i;
    lsuexu_wb__lcmem_hit_reg1 <= lsuexu_wb__lcmem_hit_reg0;
end
always_ff @(posedge clk_i) begin
    lsuexu_wb__dtcm_atom_hit_reg0 <= exu_wb__dtcm_atom_hit_i;
    lsuexu_wb__dtcm_atom_hit_reg1 <= lsuexu_wb__dtcm_atom_hit_reg0;
end
always_ff @(posedge clk_i) begin
    lsuexu_wb__clint_hit_reg0 <= exu_wb__clint_hit_i;
    lsuexu_wb__clint_hit_reg1 <= lsuexu_wb__clint_hit_reg0;
end
always_ff @(posedge clk_i) begin
    dtcm_lsu_rd_suc_reg0 <= dtcm_lsu__rd_suc_i;
end
always_ff @(posedge clk_i) begin
    lsu_lcmem_raddr_reg0       <=lsu_lcmem__raddr_i;
    lsu_lcmem_raddr_reg1       <=lsu_lcmem_raddr_reg0;
    lsu_lcmem_dtcm_raddr_reg0  <=lsu_lcmem__dtcm_raddr_i;
    lsu_lcmem_dtcm_raddr_reg1  <=lsu_lcmem_dtcm_raddr_reg0;
    lsu_dc_dcache_raddr_reg0   <=lsu_dc__raddr_i;
    lsu_dc_dcache_raddr_reg1   <=lsu_dc_dcache_raddr_reg0;
    lsu_csr_raddr_reg0         <=lsu_csr__raddr_i;
    lsu_csr_raddr_reg1         <=lsu_csr_raddr_reg0;
    lsu_clint_raddr_reg0       <=lsu_clint__raddr_i;
    lsu_clint_raddr_reg1       <=lsu_clint_raddr_reg0;
end
always_ff @(posedge clk_i) begin
    dc_lsu__dcache_rd_hit_reg0 <= dc_lsu__rd_suc_i;
end
always_comb begin
    case(lsuexu_wb__entry_addr_reg0)
        3'd0: pre_iq_rmv_en = 8'b0000_0001; 
        3'd1: pre_iq_rmv_en = 8'b0000_0010; 
        3'd2: pre_iq_rmv_en = 8'b0000_0100; 
        3'd3: pre_iq_rmv_en = 8'b0000_1000; 
        3'd4: pre_iq_rmv_en = 8'b0001_0000; 
        3'd5: pre_iq_rmv_en = 8'b0010_0000; 
        3'd6: pre_iq_rmv_en = 8'b0100_0000; 
        3'd7: pre_iq_rmv_en = 8'b1000_0000; 
        default: pre_iq_rmv_en = 8'b0000_0000; 
    endcase
end
always_ff @(posedge clk_i) begin
    lsuexu_wb__inst_valid_reg0 <= exu_wb__inst_valid_i;
end
assign  lsuexu_wb__entry_addr_crt_reg0  = ((cmt_iq__rmv_en_o < pre_iq_rmv_en) && (|cmt_iq__rmv_en_o)&& lsuexu_wb__inst_valid_reg0 ) ? lsuexu_wb__entry_addr_reg0 -1 :lsuexu_wb__entry_addr_reg0;
always_comb  begin
     lsucmt_iq_cg_issued_en = 8'b0000_0000;
     case(lsu_wb_inst_reg1.opcode.optype)
          LOAD:   begin
                      if(ld_wr_rd_en == 0) begin
                          case(lsuexu_wb__entry_addr_reg1)
                              8'd0 : lsucmt_iq_cg_issued_en = 8'b0000_0001;
                              8'd1 : lsucmt_iq_cg_issued_en = 8'b0000_0010;
                              8'd2 : lsucmt_iq_cg_issued_en = 8'b0000_0100;
                              8'd3 : lsucmt_iq_cg_issued_en = 8'b0000_1000;
                              8'd4 : lsucmt_iq_cg_issued_en = 8'b0001_0000;
                              8'd5 : lsucmt_iq_cg_issued_en = 8'b0010_0000;
                              8'd6 : lsucmt_iq_cg_issued_en = 8'b0100_0000;
                              8'd7 : lsucmt_iq_cg_issued_en = 8'b1000_0000;
                              default:lsucmt_iq_cg_issued_en = 8'b0000_0000;
                          endcase
                      end else begin
                          lsucmt_iq_cg_issued_en = 8'b0000_0000;
                      end
                  end
          ATOM:   begin
                      if(atom_wr_rd_en  && (~dtcm_lsu_rd_suc_reg0)) begin
                          case(lsuexu_wb__entry_addr_reg1)
                              8'd0 : lsucmt_iq_cg_issued_en = 8'b0000_0001;
                              8'd1 : lsucmt_iq_cg_issued_en = 8'b0000_0010;
                              8'd2 : lsucmt_iq_cg_issued_en = 8'b0000_0100;
                              8'd3 : lsucmt_iq_cg_issued_en = 8'b0000_1000;
                              8'd4 : lsucmt_iq_cg_issued_en = 8'b0001_0000;
                              8'd5 : lsucmt_iq_cg_issued_en = 8'b0010_0000;
                              8'd6 : lsucmt_iq_cg_issued_en = 8'b0100_0000;
                              8'd7 : lsucmt_iq_cg_issued_en = 8'b1000_0000;
                              default:lsucmt_iq_cg_issued_en = 8'b0000_0000;
                          endcase
                      end else begin
                          lsucmt_iq_cg_issued_en = 8'b0000_0000;
                      end
                  end
          default: lsucmt_iq_cg_issued_en = 8'b0000_0000;
     endcase
end
assign data_strobe =  (lsu_wb_inst_reg1.opcode.ls_size == BYTE) ? 32'h0000_00ff:
                      (lsu_wb_inst_reg1.opcode.ls_size == HALF) ? 32'h0000_ffff:
                      (lsu_wb_inst_reg1.opcode.ls_size == WORD) ? 32'hffff_ffff:32'hffff_ffff;
always_comb  begin
     ld_wr_rd_en     =0; 
     ld_wr_rd_addr   =0;
     ld_wr_rd_data   =0;
     csr_wr_rd_en    =0;
     csr_wr_rd_addr  =0;
     csr_wr_rd_data  =0;
     atom_wr_rd_en   =0;
     atom_wr_rd_addr =0;
     atom_wr_rd_data =0;
     lsu_fu_awake_data.en = 1'b0;
     lsu_fu_awake_data.rdst_index = 0;
     case(lsu_wb_inst_reg1.opcode.optype)
          LOAD:
               begin
                   ld_wr_rd_en   = ((lsuexu_wb__dcache_hit_reg1 && ~dc_lsu__dcache_rd_hit_reg0) || (~dtcm_lsu_rd_suc_reg0 && (lsuexu_wb__dtcm_atom_hit_reg1) )) ? 1'b0 : 1'b1;
                   for(integer i =0;i < ST_ATOM_WB_NUM;i = i+1)begin
                       if(((st_atom_wbuffer[i].mem_addr == lsu_lcmem_raddr_reg1) 
                           || (st_atom_wbuffer[i].mem_addr ==lsu_dc_dcache_raddr_reg1)
                           || (st_atom_wbuffer[i].mem_addr ==lsu_clint_raddr_reg1))
                           && ((st_atom_wbuffer[i].rob_index + st_atom_wbuffer[i].rob_offset) <= (lsu_wb_inst_reg1.rob_index + lsu_wb_inst_reg1.rob_offset))
                           && (st_atom_wbuffer[i].ls_size >= lsu_wb_inst_reg1.opcode.ls_size)) begin
                           ld_wr_rd_en = 1'b1;
                       end
                   end
                   ld_wr_rd_addr = lsu_wb_inst_reg1.phy_rdst_index;
                   ld_wr_rd_data = (  ({DATA_WTH{lsuexu_wb__lcmem_hit_reg1}} &lmrw_lsu__rdata_i) 
                                    | ({DATA_WTH{lsuexu_wb__dtcm_atom_hit_reg1}} &dtcm_lsu__rdata_i)
                                    | ({DATA_WTH{lsuexu_wb__clint_hit_reg1}} &clint_lsu__rdata_i)
                                    | ({DATA_WTH{lsuexu_wb__dcache_hit_reg1}} &dc_lsu__rdata_i) ) & data_strobe;
                   
                   for(integer i =0;i < ST_ATOM_WB_NUM;i = i+1)begin
                       if(((st_atom_wbuffer[i].mem_addr == lsu_lcmem_raddr_reg1) 
                           || (st_atom_wbuffer[i].mem_addr ==lsu_dc_dcache_raddr_reg1)
                           || (st_atom_wbuffer[i].mem_addr ==lsu_clint_raddr_reg1))
                           && ((st_atom_wbuffer[i].rob_index + st_atom_wbuffer[i].rob_offset) <= (lsu_wb_inst_reg1.rob_index + lsu_wb_inst_reg1.rob_offset))
                           && (st_atom_wbuffer[i].ls_size >= lsu_wb_inst_reg1.opcode.ls_size) ) begin
                           ld_wr_rd_data = st_atom_wbuffer[i].mem_data;
                       end
                   end
                   lsu_fu_awake_data.en = (lsuexu_wb__dcache_hit_reg1 && ~dc_lsu__dcache_rd_hit_reg0) ? 1'b0 : 1'b1;
                   lsu_fu_awake_data.rdst_index = lsu_wb_inst_reg1.phy_rdst_index;
               end
          CSR:
               begin
                   csr_wr_rd_en   = 1'b1 && (~lsu_wb_inst_reg1.opcode.csr_rd_is_x0);
                   csr_wr_rd_addr = lsu_wb_inst_reg1.phy_rdst_index;
                   csr_wr_rd_data = csr_lsu__rdata_i;
                   for(integer i =0;i < CSR_WB_NUM;i = i+1)begin
                       if((csr_wbuffer[i].mem_addr == lsu_csr_raddr_reg1) && ((csr_wbuffer[i].rob_index  + csr_wbuffer[i].rob_offset)<= (lsu_wb_inst_reg1.rob_index + lsu_wb_inst_reg1.rob_offset))) begin
                           csr_wr_rd_data = csr_wbuffer[i].mem_data;
                       end
                   end
                   lsu_fu_awake_data.en = 1'b1 && (lsu_wb_inst_reg1.opcode.csr_rd_is_x0);
                   lsu_fu_awake_data.rdst_index = lsu_wb_inst_reg1.phy_rdst_index;
               end
          ATOM:
               begin
                   atom_wr_rd_en   = (dtcm_lsu_rd_suc_reg0 && (lsuexu_wb__dtcm_atom_hit_reg1) ) ? 1'b1 : 1'b0;
                   atom_wr_rd_addr = lsu_wb_inst_reg1.phy_rdst_index;
                   atom_wr_rd_data =  (dtcm_lsu_rd_suc_reg0 && (lsuexu_wb__dtcm_atom_hit_reg1) ) ? dtcm_lsu__rdata_i :32'hFFFF_FFFF;
                   lsu_fu_awake_data.en = 1'b1;
                   lsu_fu_awake_data.rdst_index = lsu_wb_inst_reg1.phy_rdst_index;
               end
         default:
               begin
                   ld_wr_rd_en     =0; 
                   ld_wr_rd_addr   =0;
                   ld_wr_rd_data   =0;
                   csr_wr_rd_en    =0;
                   csr_wr_rd_addr  =0;
                   csr_wr_rd_data  =0;
                   atom_wr_rd_en   =0;
                   atom_wr_rd_addr =0;
                   atom_wr_rd_data =0;
                   lsu_fu_awake_data.en = 1'b0;
                   lsu_fu_awake_data.rdst_index = 0;
               end
     endcase
end
assign lsu_iq__awake_o = lsu_fu_awake_data && 1'b0;
always_ff @(posedge clk_i ) begin
    csr_wb_wr_en_reg0 <= exu_wb__csrsb_we_i;
    csr_wb_wr_en_reg1 <= csr_wb_wr_en_reg0 ;
end
always_ff @(posedge clk_i ) begin
    csr_wb_wr_addr_reg0 <= exu_wb__mem_addr_i;
    csr_wb_wr_addr_reg1 <= csr_wb_wr_addr_reg0 ;
end
always_ff @(posedge clk_i ) begin
    lsu_csr__rs1_data_reg0 <= lsu_csr__rs1_data_i;
    lsu_csr__rs1_data_reg1 <= lsu_csr__rs1_data_reg0 ;
end
always_ff @(posedge clk_i ) begin
    atom_wb_wr_en_reg0 <= exu_wb__sb_we_i;
    atom_wb_wr_en_reg1 <= atom_wb_wr_en_reg0 ;
end
always_ff @(posedge clk_i ) begin
    st_wb_wr_en_reg0 <= exu_wb__sb_we_i;
    st_wb_wr_en_reg1 <= st_wb_wr_en_reg0 ;
end
always_ff @(posedge clk_i ) begin
    atom_wb_wr_addr_reg0 <= exu_wb__mem_addr_i;
    atom_wb_wr_addr_reg1 <= atom_wb_wr_addr_reg0 ;
end
always_ff @(posedge clk_i ) begin
    lsuexu_wb__atom_rs2_data_reg0 <= exu_wb__dtcm_atom_rs2_data_i;
    lsuexu_wb__atom_rs2_data_reg1 <= lsuexu_wb__atom_rs2_data_reg0 ;
end
always_ff @(posedge clk_i ) begin
    st_wb_wr_addr_reg0 <= exu_wb__mem_addr_i;
    st_wb_wr_addr_reg1 <= st_wb_wr_addr_reg0 ;
end
always_ff @(posedge clk_i ) begin
    lsuexu_wb__st_rs2_data_reg0 <= exu_wb__st_rs2_data_i;
    lsuexu_wb__st_rs2_data_reg1 <= lsuexu_wb__st_rs2_data_reg0 ;
end
always_comb begin
    st_wb_wr_en   = 0; 
    st_wb_wr_addr = 0; 
    st_wb_wr_data = 0; 
    case(lsu_wb_inst_reg1.opcode.optype)
              STORE:
                   begin
                       st_wb_wr_en   = st_wb_wr_en_reg1;
                       st_wb_wr_addr = st_wb_wr_addr_reg1;
                       st_wb_wr_data = lsuexu_wb__st_rs2_data_reg1; 
                   end
              default: 
                   begin
                       st_wb_wr_en   = 0; 
                       st_wb_wr_addr = 0; 
                       st_wb_wr_data = 0; 
                   end
    endcase
end
always_comb begin
    csr_wb_wr_en    =0; 
    csr_wb_wr_addr  =0;
    csr_wb_wr_data  =0; 
    atom_wb_wr_en   =0;
    atom_wb_wr_addr =0;
    atom_wb_wr_data =0; 
    case(lsu_wb_inst_reg1.opcode.optype)
              CSR:
                   begin
                       csr_wb_wr_en   = csr_wb_wr_en_reg1;
                       csr_wb_wr_addr = csr_wb_wr_addr_reg1;  
                       case(lsu_wb_inst_reg1.opcode.csr_func)
                         CSR_RW: csr_wb_wr_data = lsu_csr__rs1_data_reg1;
                         CSR_RS: csr_wb_wr_data = csr_lsu__rdata_i | lsu_csr__rs1_data_reg1;
                         CSR_RC: csr_wb_wr_data = csr_lsu__rdata_i & (~lsu_csr__rs1_data_reg1);
                         CSR_RWI:csr_wb_wr_data = lsu_csr__rs1_data_reg1;
                         CSR_RSI:csr_wb_wr_data = csr_lsu__rdata_i | lsu_csr__rs1_data_reg1;
                         CSR_RCI:csr_wb_wr_data = csr_lsu__rdata_i & (~lsu_csr__rs1_data_reg1);
                           default: csr_wb_wr_data = 0;
                       endcase
                   end
    
              ATOM:
                   begin
                       atom_wb_wr_en   = dtcm_lsu_rd_suc_reg0 ? atom_wb_wr_en_reg1 : 1'b0; 
                       atom_wb_wr_addr = atom_wb_wr_addr_reg1;
                       case(lsu_wb_inst_reg1.opcode.atom_func)
                           ATOM_SWAP: atom_wb_wr_data =  lsuexu_wb__atom_rs2_data_reg1;
                           ATOM_ADD : atom_wb_wr_data =  lsuexu_wb__atom_rs2_data_reg1 + (({DATA_WTH{lsuexu_wb__dtcm_atom_hit_reg1}} &dtcm_lsu__rdata_i)); 
                           ATOM_XOR : atom_wb_wr_data =  lsuexu_wb__atom_rs2_data_reg1 ^ (({DATA_WTH{lsuexu_wb__dtcm_atom_hit_reg1}} &dtcm_lsu__rdata_i)); 
                           ATOM_AND : atom_wb_wr_data =  lsuexu_wb__atom_rs2_data_reg1 & (({DATA_WTH{lsuexu_wb__dtcm_atom_hit_reg1}} &dtcm_lsu__rdata_i));
                           ATOM_OR  : atom_wb_wr_data =  lsuexu_wb__atom_rs2_data_reg1 | (({DATA_WTH{lsuexu_wb__dtcm_atom_hit_reg1}} &dtcm_lsu__rdata_i));
                           ATOM_MIN : atom_wb_wr_data =  (lsuexu_wb__atom_rs2_data_reg1 >= (({DATA_WTH{lsuexu_wb__dtcm_atom_hit_reg1}} &dtcm_lsu__rdata_i))) ?
                                                         ({DATA_WTH{lsuexu_wb__dtcm_atom_hit_reg1}} &dtcm_lsu__rdata_i)  : lsuexu_wb__atom_rs2_data_reg1  ;
                           ATOM_MAX : atom_wb_wr_data =  lsuexu_wb__atom_rs2_data_reg1  >= (({DATA_WTH{lsuexu_wb__dtcm_atom_hit_reg1}} &dtcm_lsu__rdata_i)) ?
                                                         lsuexu_wb__atom_rs2_data_reg1 : ({DATA_WTH{lsuexu_wb__dtcm_atom_hit_reg1}} &dtcm_lsu__rdata_i) ;
                           ATOM_MINU: atom_wb_wr_data =  (lsuexu_wb__atom_rs2_data_reg1 >= (({DATA_WTH{lsuexu_wb__dtcm_atom_hit_reg1}} &dtcm_lsu__rdata_i))) ?
                                                         ({DATA_WTH{lsuexu_wb__dtcm_atom_hit_reg1}} &dtcm_lsu__rdata_i)  : lsuexu_wb__atom_rs2_data_reg1  ;
                           ATOM_MAXU: atom_wb_wr_data =  lsuexu_wb__atom_rs2_data_reg1  >= (({DATA_WTH{lsuexu_wb__dtcm_atom_hit_reg1}} &dtcm_lsu__rdata_i)) ?
                                                         lsuexu_wb__atom_rs2_data_reg1 : ({DATA_WTH{lsuexu_wb__dtcm_atom_hit_reg1}} &dtcm_lsu__rdata_i) ;
                           default:atom_wb_wr_data =0; 
                       endcase
                   end
             
             default: begin
                          csr_wb_wr_en    =0; 
                          csr_wb_wr_addr  =0;
                          csr_wb_wr_data  =0; 
                          atom_wb_wr_en   =0;
                          atom_wb_wr_addr =0;
                          atom_wb_wr_data =0; 
                      end
    endcase
end
assign st_atom_wb_wr_en        =  st_wb_wr_en | atom_wb_wr_en; 
assign st_atom_wb_wr_addr      =  ({PC_WTH{st_wb_wr_en}} & st_wb_wr_addr)  | ({PC_WTH{atom_wb_wr_en}} & atom_wb_wr_addr) ;
assign st_atom_wb_wr_data      =  ({PC_WTH{st_wb_wr_en}} & st_wb_wr_data)  | ({PC_WTH{atom_wb_wr_en}} & atom_wb_wr_data) ;
assign st_atom_wb_wr_pos_index =  ({LSU_IQ_INDEX{st_wb_wr_en}} &lsuexu_wb__entry_addr_reg1)  | ({LSU_IQ_INDEX{atom_wb_wr_en}} & lsuexu_wb__entry_addr_reg1) ;
assign csr_wb_full = (csr_wb_head_ptr == csr_wb_tail_ptr) && (csr_head_mark != csr_tail_mark);
assign csr_wb_empty = (csr_wb_head_ptr == csr_wb_tail_ptr) && (csr_head_mark == csr_tail_mark);
assign st_atom_wb_full = (st_atom_wb_head_ptr == st_atom_wb_tail_ptr) && (st_atom_head_mark != st_atom_tail_mark);
assign st_atom_wb_empty = (st_atom_wb_head_ptr == st_atom_wb_tail_ptr) && (st_atom_head_mark == st_atom_tail_mark);
assign wb_iq__csrsb_full_o = csr_wb_a_full;
assign wb_iq__sb_full_o = st_atom_wb_a_full;
assign csr_wb_rd_en = (!csr_wb_empty && csr_wbuffer_rd_data.status == 2'b10) ||(!csr_wb_empty && csr_wbuffer_rd_data.is_valid == 1'b0);
always_ff  @(posedge clk_i or  `RST_DECL(rst_i)) begin
    if(`RST_TRUE(rst_i)) begin
        csr_wb_head_ptr <= 0;
        csr_head_mark   <= 0;
    end else begin
        if(csr_wb_rd_en) begin
            if(csr_wb_head_ptr == CSR_WB_NUM -1) begin
                csr_wb_head_ptr <= 0;
                csr_head_mark   <= ~csr_head_mark;
            end else begin
            csr_wb_head_ptr     <= csr_wb_head_ptr + 1;
            end
        end
    end
end
assign   csr_wbuffer_rd_data = csr_wbuffer[csr_wb_head_ptr]; 
always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
    if(`RST_TRUE(rst_i)) begin
        csr_wb_tail_ptr <= 0;
        csr_tail_mark   <= 0;
        for(integer i=0;i < CSR_WB_NUM;i=i+1) begin
            csr_wbuffer[i].is_valid    <= 0;
            csr_wbuffer[i].ckpt.index  <= 0;
            csr_wbuffer[i].ckpt.flag   <= 0;
            csr_wbuffer[i].rob_index   <= 0;
            csr_wbuffer[i].rob_offset  <= 0;
            csr_wbuffer[i].mem_addr_rdy<= 1'b0;
            csr_wbuffer[i].mem_addr    <= 32'hffff_ffff;
            csr_wbuffer[i].mem_data    <= 0;
            csr_wbuffer[i].mem_data_rdy<= 1'b0;
            csr_wbuffer[i].status      <= 2'b00;
            csr_wbuffer[i].pos_index   <= 0;
        end
    end else begin
        if(csr_wb_rd_en)begin
            csr_wbuffer[csr_wb_head_ptr].is_valid    <= 0;
            csr_wbuffer[csr_wb_head_ptr].ckpt.index  <= 0;
            csr_wbuffer[csr_wb_head_ptr].ckpt.flag   <= 0;
            csr_wbuffer[csr_wb_head_ptr].rob_index   <= 0;
            csr_wbuffer[csr_wb_head_ptr].rob_offset  <= 0;
            csr_wbuffer[csr_wb_head_ptr].mem_addr_rdy<= 1'b0;
            csr_wbuffer[csr_wb_head_ptr].mem_addr    <= 32'hffff_ffff;
            csr_wbuffer[csr_wb_head_ptr].mem_data    <= 0;
            csr_wbuffer[csr_wb_head_ptr].mem_data_rdy<= 1'b0;
            csr_wbuffer[csr_wb_head_ptr].status      <= 2'b00;
            csr_wbuffer[csr_wb_head_ptr].pos_index   <= 0;
        end
        if(csr_wb_wr_en)begin
            if(csr_wb_tail_ptr == CSR_WB_NUM -1) begin
                csr_wb_tail_ptr  <= 0;
                csr_tail_mark    <= ~csr_tail_mark;
            end else begin
                csr_wb_tail_ptr  <= csr_wb_tail_ptr + 1;
            end
            csr_wbuffer[csr_wb_tail_ptr].ckpt.index  <= lsu_wb_inst_reg1.ckpt.index;
            csr_wbuffer[csr_wb_tail_ptr].rob_index   <= lsu_wb_inst_reg1.rob_index;
            csr_wbuffer[csr_wb_tail_ptr].rob_offset  <= lsu_wb_inst_reg1.rob_offset;
            csr_wbuffer[csr_wb_tail_ptr].mem_addr_rdy<= 1'b1;
            csr_wbuffer[csr_wb_tail_ptr].mem_addr    <= csr_wb_wr_addr;
            csr_wbuffer[csr_wb_tail_ptr].mem_data    <= csr_wb_wr_data;
            csr_wbuffer[csr_wb_tail_ptr].mem_data_rdy<= 1'b1;
            if( rob_lsu__retire_i.en && (rob_lsu__retire_i.rob_index == csr_wbuffer[csr_wb_tail_ptr].rob_index)
                && (rob_lsu__retire_i.rob_offset_mark[0] && (csr_wbuffer[csr_wb_tail_ptr].rob_offset[0])) ) begin
                csr_wbuffer[csr_wb_tail_ptr].status <= 2'b10;
            end else if( rob_lsu__retire_i.en && (rob_lsu__retire_i.rob_index == csr_wbuffer[csr_wb_tail_ptr].rob_index)
                && (rob_lsu__retire_i.rob_offset_mark[1] && (csr_wbuffer[csr_wb_tail_ptr].rob_offset[1])) ) begin
                csr_wbuffer[csr_wb_tail_ptr].status <= 2'b10;
            end else begin
                csr_wbuffer[csr_wb_tail_ptr].status <= 2'b01;
            end
            csr_wbuffer[csr_wb_tail_ptr].pos_index   <= lsuexu_wb__entry_addr_reg1;
        end else begin
            
            for(integer i=0;i < ST_ATOM_WB_NUM;i = i+1) begin
            end
        end
        for(integer i =0; i< ST_ATOM_WB_NUM;i=i+1) begin
            if( rob_lsu__retire_i.en && (rob_lsu__retire_i.rob_index == csr_wbuffer[i].rob_index)
                && (rob_lsu__retire_i.rob_offset_mark[0] && (csr_wbuffer[i].rob_offset[0])) && csr_wbuffer[i].is_valid) begin
                csr_wbuffer[i].status <= 2'b10;
            end else if( rob_lsu__retire_i.en && (rob_lsu__retire_i.rob_index == csr_wbuffer[i].rob_index)
                && (rob_lsu__retire_i.rob_offset_mark[1] && (csr_wbuffer[i].rob_offset[1]))&& csr_wbuffer[i].is_valid) begin
                csr_wbuffer[i].status <= 2'b10;
            end 
        end
    end
end
always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
    if(`RST_TRUE(rst_i)) begin
        csr_wb_a_empty <= 1'b1;
        csr_wb_a_full <= 1'b0;
    end else begin
        if(csr_wb_rd_en & (~csr_wb_wr_en)) begin
            if(csr_wb_tail_ptr < csr_wb_head_ptr) begin
                if(csr_wb_tail_ptr + CSR_WB_NUM - csr_wb_head_ptr == CSR_EMPTY_ASSERT_VALUE + 1'b1)
                    csr_wb_a_empty <= 1'b1;
                if(csr_wb_tail_ptr + CSR_WB_NUM - csr_wb_head_ptr == CSR_FULL_NEGATE_VALUE)
                    csr_wb_a_full <= 1'b0;
            end else begin
                if(csr_wb_tail_ptr - csr_wb_head_ptr == CSR_EMPTY_ASSERT_VALUE + 1'b1)
                    csr_wb_a_empty <= 1'b1;
                if(csr_wb_tail_ptr - csr_wb_head_ptr == CSR_FULL_NEGATE_VALUE)
                    csr_wb_a_full <= 1'b0;
            end
        end else if((~csr_wb_rd_en) & csr_wb_wr_en) begin
            if(csr_wb_tail_ptr < csr_wb_head_ptr) begin
                if(csr_wb_tail_ptr + CSR_WB_NUM - csr_wb_head_ptr == CSR_EMPTY_NEGATE_VALUE)
                    csr_wb_a_empty <= 1'b0;
                if(csr_wb_tail_ptr + CSR_WB_NUM - csr_wb_head_ptr == CSR_FULL_ASSERT_VALUE - 1'b1)
                    csr_wb_a_full <= 1'b1;
            end else begin
                if(csr_wb_tail_ptr - csr_wb_head_ptr == CSR_EMPTY_NEGATE_VALUE)
                    csr_wb_a_empty <= 1'b0;
                if(csr_wb_tail_ptr - csr_wb_head_ptr == CSR_FULL_ASSERT_VALUE - 1'b1)
                    csr_wb_a_full <= 1'b1;
            end
        end
    end
end
always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
    if(`RST_TRUE(rst_i)) begin
        st_atom_wb_a_empty <= 1'b1;
        st_atom_wb_a_full <= 1'b0;
    end else begin
        if(st_atom_wb_rd_en & (~st_atom_wb_wr_en)) begin
            if(st_atom_wb_tail_ptr < st_atom_wb_head_ptr) begin
                if(st_atom_wb_tail_ptr + ST_ATOM_WB_NUM - st_atom_wb_head_ptr == ST_ATOM_EMPTY_ASSERT_VALUE + 1'b1)
                    st_atom_wb_a_empty <= 1'b1;
                if(st_atom_wb_tail_ptr + ST_ATOM_WB_NUM - st_atom_wb_head_ptr == ST_ATOM_FULL_NEGATE_VALUE)
                    st_atom_wb_a_full <= 1'b0;
            end else begin
                if(st_atom_wb_tail_ptr - st_atom_wb_head_ptr == ST_ATOM_EMPTY_ASSERT_VALUE + 1'b1)
                    st_atom_wb_a_empty <= 1'b1;
                if(st_atom_wb_tail_ptr - st_atom_wb_head_ptr == ST_ATOM_FULL_NEGATE_VALUE)
                    st_atom_wb_a_full <= 1'b0;
            end
        end else if((~st_atom_wb_rd_en) & st_atom_wb_wr_en) begin
            if(st_atom_wb_tail_ptr < st_atom_wb_head_ptr) begin
                if(st_atom_wb_tail_ptr + ST_ATOM_WB_NUM - st_atom_wb_head_ptr == ST_ATOM_EMPTY_NEGATE_VALUE)
                    st_atom_wb_a_empty <= 1'b0;
                if(st_atom_wb_tail_ptr + ST_ATOM_WB_NUM - st_atom_wb_head_ptr == ST_ATOM_FULL_ASSERT_VALUE - 1'b1)
                    st_atom_wb_a_full <= 1'b1;
            end else begin
                if(st_atom_wb_tail_ptr - st_atom_wb_head_ptr == ST_ATOM_EMPTY_NEGATE_VALUE)
                    st_atom_wb_a_empty <= 1'b0;
                if(st_atom_wb_tail_ptr - st_atom_wb_head_ptr == ST_ATOM_FULL_ASSERT_VALUE - 1'b1)
                    st_atom_wb_a_full <= 1'b1;
            end
        end
    end
end
always_ff  @(posedge clk_i or  `RST_DECL(rst_i)) begin
    if(`RST_TRUE(rst_i)) begin
        lsu_dtcm_wr_rls_lock <= 1'b0;
    end else begin
        lsu_dtcm_wr_rls_lock <= ((!st_atom_wb_empty && st_atom_wbuffer_rd_data.status == 2'b10) && dtcm_wd_hit  && dtcm_lsu__wr_suc_i) && (st_atom_wbuffer_rd_data.is_atom) ? 1'b1: 1'b0;  ;
    end
end
assign lsu_dtcm__wr_rls_lock_o = lsu_dtcm_wr_rls_lock;
assign st_atom_wb_rd_en = ((!st_atom_wb_empty && (st_atom_wbuffer_rd_data.status == 2'b10 )) && lcmem_wd_hit) ||
                          ((!st_atom_wb_empty && (st_atom_wbuffer_rd_data.status == 2'b10 )) && dtcm_wd_hit  && dtcm_lsu__wr_suc_i) ||
                          ((!st_atom_wb_empty && (st_atom_wbuffer_rd_data.status == 2'b10 )) && cache_wd_hit && dc_lsu__wr_suc_i) ||
                          (!st_atom_wb_empty  && (st_atom_wbuffer_rd_data.is_valid == 1'b0));
always_ff  @(posedge clk_i or  `RST_DECL(rst_i)) begin
    if(`RST_TRUE(rst_i)) begin
        st_atom_wb_head_ptr <= 0;
        st_atom_head_mark   <= 0;
    end else begin
        if(st_atom_wb_rd_en) begin
            if(st_atom_wb_head_ptr == ST_ATOM_WB_NUM -1) begin
                st_atom_wb_head_ptr <= 0;
                st_atom_head_mark   <= ~st_atom_head_mark;
            end else begin
                st_atom_wb_head_ptr <= st_atom_wb_head_ptr + 1;
            end
        end
    end
end
assign st_atom_wbuffer_rd_data = st_atom_wbuffer[st_atom_wb_head_ptr];
always_ff  @(posedge clk_i or  `RST_DECL(rst_i)) begin
    if(`RST_TRUE(rst_i)) begin
        st_atom_wb_tail_ptr <= 0;
        st_atom_tail_mark   <= 0;
        for(integer i=0;i < ST_ATOM_WB_NUM;i=i+1) begin
            st_atom_wbuffer[i].is_valid    <= 0;
            st_atom_wbuffer[i].rob_index   <= 0;
            st_atom_wbuffer[i].rob_offset  <= 0;
            st_atom_wbuffer[i].mem_addr_rdy<= 1'b0;
            st_atom_wbuffer[i].mem_addr    <= 32'hffff_ffff;
            st_atom_wbuffer[i].mem_data    <= 0;
            st_atom_wbuffer[i].mem_data_rdy<= 1'b0;
            st_atom_wbuffer[i].status      <= 2'b11;
            st_atom_wbuffer[i].pos_index   <= 2'b00;
            st_atom_wbuffer[i].ls_size     <= WORD;
            st_atom_wbuffer[i].is_atom     <= 0;
        end
    end else begin
        if(st_atom_wb_rd_en)begin
            st_atom_wbuffer[st_atom_wb_head_ptr].is_valid    <= 0;
            st_atom_wbuffer[st_atom_wb_head_ptr].rob_index   <= 0;
            st_atom_wbuffer[st_atom_wb_head_ptr].rob_offset  <= 0;
            st_atom_wbuffer[st_atom_wb_head_ptr].mem_addr_rdy<= 1'b0;
            st_atom_wbuffer[st_atom_wb_head_ptr].mem_addr    <= 32'hffff_ffff;
            st_atom_wbuffer[st_atom_wb_head_ptr].mem_data    <= 0;
            st_atom_wbuffer[st_atom_wb_head_ptr].mem_data_rdy<= 1'b0;
            st_atom_wbuffer[st_atom_wb_head_ptr].status      <= 2'b00;
            st_atom_wbuffer[st_atom_wb_head_ptr].pos_index   <= 0;
            st_atom_wbuffer[st_atom_wb_head_ptr].ls_size     <= WORD;
            st_atom_wbuffer[st_atom_wb_head_ptr].is_atom     <= 0;
        end
        if(st_atom_wb_wr_en)begin
            if(st_atom_wb_tail_ptr == ST_ATOM_WB_NUM -1) begin
                st_atom_wb_tail_ptr  <= 0;
                st_atom_tail_mark    <= ~st_atom_tail_mark;
            end else begin
                st_atom_wb_tail_ptr  <= st_atom_wb_tail_ptr + 1;
            end
            st_atom_wbuffer[st_atom_wb_tail_ptr].rob_index   <= lsu_wb_inst_reg1.rob_index;
            st_atom_wbuffer[st_atom_wb_tail_ptr].rob_offset  <= lsu_wb_inst_reg1.rob_offset;
            st_atom_wbuffer[st_atom_wb_tail_ptr].mem_addr_rdy<= 1'b1;
            st_atom_wbuffer[st_atom_wb_tail_ptr].mem_addr    <= st_atom_wb_wr_addr;
            st_atom_wbuffer[st_atom_wb_tail_ptr].mem_data    <= st_atom_wb_wr_data;
            st_atom_wbuffer[st_atom_wb_tail_ptr].mem_data_rdy<= 1'b1;
            st_atom_wbuffer[st_atom_wb_tail_ptr].mem_data_rdy<= 1'b1;
            st_atom_wbuffer[st_atom_wb_tail_ptr].ls_size     <= lsu_wb_inst_reg1.opcode.ls_size;
            st_atom_wbuffer[st_atom_wb_tail_ptr].is_atom     <= (lsu_wb_inst_reg1.opcode.optype == ATOM);
            if( rob_lsu__retire_i.en && (rob_lsu__retire_i.rob_index == st_atom_wbuffer[st_atom_wb_tail_ptr].rob_index)
                && (rob_lsu__retire_i.rob_offset_mark[0] && (st_atom_wbuffer[st_atom_wb_tail_ptr].rob_offset[0]))) begin
                st_atom_wbuffer[st_atom_wb_tail_ptr].status <= 2'b10;
            end else if( rob_lsu__retire_i.en && (rob_lsu__retire_i.rob_index == st_atom_wbuffer[st_atom_wb_tail_ptr].rob_index)
                && (rob_lsu__retire_i.rob_offset_mark[1] && (st_atom_wbuffer[st_atom_wb_tail_ptr].rob_offset[1]))) begin
                st_atom_wbuffer[st_atom_wb_tail_ptr].status <= 2'b10;
            end else begin
                st_atom_wbuffer[st_atom_wb_tail_ptr].status <= 2'b01;
            end
            st_atom_wbuffer[st_atom_wb_tail_ptr].pos_index <= st_atom_wb_wr_pos_index;
        end else begin
            
        end
        for(integer i =0; i< ST_ATOM_WB_NUM;i=i+1) begin
            if( rob_lsu__retire_i.en && (rob_lsu__retire_i.rob_index == st_atom_wbuffer[i].rob_index)
                && (rob_lsu__retire_i.rob_offset_mark[0])&& (st_atom_wbuffer[i].rob_offset[0])&& st_atom_wbuffer[i].is_valid) begin
                st_atom_wbuffer[i].status <= 2'b10;
            end else if( rob_lsu__retire_i.en && (rob_lsu__retire_i.rob_index == st_atom_wbuffer[i].rob_index)
                && (rob_lsu__retire_i.rob_offset_mark[1] && (st_atom_wbuffer[i].rob_offset[1]))&& st_atom_wbuffer[i].is_valid) begin
                st_atom_wbuffer[i].status <= 2'b10;
            end
        end
    end
end
always_comb  begin
    st_rob_commit.en           = 0; 
    st_rob_commit.rob_index    = 0; 
    st_rob_commit.rob_offset   = 0;
    st_rob_commit.excp_en      = 0;
    st_rob_commit.excp         = INST_ADDR_MISALIGNED;
    st_lsucmt_iq_rmv_en = 0;
    case(lsu_wb_inst_reg1.opcode.optype)
         STORE:
              begin
                  st_rob_commit.en = st_wb_wr_en;  
                  st_rob_commit.rob_index = lsu_wb_inst_reg1.rob_index;
                  st_rob_commit.rob_offset = lsu_wb_inst_reg1.rob_offset;
                  st_rob_commit.excp_en      = 0;
                  st_rob_commit.excp         = INST_ADDR_MISALIGNED;
                  case(lsuexu_wb__entry_addr_reg1)
                      3'd0: st_lsucmt_iq_rmv_en = 8'b0000_0001; 
                      3'd1: st_lsucmt_iq_rmv_en = 8'b0000_0010; 
                      3'd2: st_lsucmt_iq_rmv_en = 8'b0000_0100; 
                      3'd3: st_lsucmt_iq_rmv_en = 8'b0000_1000; 
                      3'd4: st_lsucmt_iq_rmv_en = 8'b0001_0000; 
                      3'd5: st_lsucmt_iq_rmv_en = 8'b0010_0000; 
                      3'd6: st_lsucmt_iq_rmv_en = 8'b0100_0000; 
                      3'd7: st_lsucmt_iq_rmv_en = 8'b1000_0000; 
                      default: st_lsucmt_iq_rmv_en = 8'b0000_0000; 
                  endcase
              end
          default: begin
                     st_rob_commit.en           = 0; 
                     st_rob_commit.rob_index    = 0; 
                     st_rob_commit.rob_offset   = 0;
                     st_rob_commit.excp_en      = 0;
                     st_rob_commit.excp         = INST_ADDR_MISALIGNED;
                     st_lsucmt_iq_rmv_en = 0;
                 end
    endcase
end
always_comb  begin
     ld_rob_commit.en           = 0; 
     ld_rob_commit.rob_index    = 0; 
     ld_rob_commit.rob_offset   = 0;
     ld_rob_commit.excp_en      = 0;
     ld_rob_commit.excp         = INST_ADDR_MISALIGNED;
     csr_rob_commit.en          = 0;
     csr_rob_commit.rob_index   = 0; 
     csr_rob_commit.rob_offset  = 0;
     csr_rob_commit.excp_en     = 0;
     csr_rob_commit.excp        = INST_ADDR_MISALIGNED;
     fence_rob_commit.en        = 0;
     fence_rob_commit.rob_index = 0;
     fence_rob_commit.rob_offset= 0;
     fence_rob_commit.excp_en   = 0;
     fence_rob_commit.excp      = INST_ADDR_MISALIGNED;
     atom_rob_commit.en         = 0; 
     atom_rob_commit.rob_index  = 0;
     atom_rob_commit.rob_offset = 0; 
     atom_rob_commit.excp_en    = 0; 
     atom_rob_commit.excp       = INST_ADDR_MISALIGNED; 
     lsucmt_iq_rmv_en = 0;
     case(lsu_wb_inst_reg1.opcode.optype)
          LOAD:
               begin
                   ld_rob_commit.en = ld_wr_rd_en;  
                   ld_rob_commit.rob_index = lsu_wb_inst_reg1.rob_index;
                   ld_rob_commit.rob_offset = lsu_wb_inst_reg1.rob_offset;
                   case(lsuexu_wb__entry_addr_reg1)
                       3'd0: lsucmt_iq_rmv_en = 8'b0000_0001; 
                       3'd1: lsucmt_iq_rmv_en = 8'b0000_0010; 
                       3'd2: lsucmt_iq_rmv_en = 8'b0000_0100; 
                       3'd3: lsucmt_iq_rmv_en = 8'b0000_1000; 
                       3'd4: lsucmt_iq_rmv_en = 8'b0001_0000; 
                       3'd5: lsucmt_iq_rmv_en = 8'b0010_0000; 
                       3'd6: lsucmt_iq_rmv_en = 8'b0100_0000; 
                       3'd7: lsucmt_iq_rmv_en = 8'b1000_0000; 
                       default: lsucmt_iq_rmv_en = 8'b0000_0000; 
                   endcase
               end
          CSR:
               begin
                   csr_rob_commit.en = csr_wb_wr_en;  
                   csr_rob_commit.rob_index = lsu_wb_inst_reg1.rob_index;
                   csr_rob_commit.rob_offset = lsu_wb_inst_reg1.rob_offset;
                   case(lsuexu_wb__entry_addr_reg1)
                       3'd0: lsucmt_iq_rmv_en = 8'b0000_0001; 
                       3'd1: lsucmt_iq_rmv_en = 8'b0000_0010; 
                       3'd2: lsucmt_iq_rmv_en = 8'b0000_0100; 
                       3'd3: lsucmt_iq_rmv_en = 8'b0000_1000; 
                       3'd4: lsucmt_iq_rmv_en = 8'b0001_0000; 
                       3'd5: lsucmt_iq_rmv_en = 8'b0010_0000; 
                       3'd6: lsucmt_iq_rmv_en = 8'b0100_0000; 
                       3'd7: lsucmt_iq_rmv_en = 8'b1000_0000; 
                       default: lsucmt_iq_rmv_en = 8'b0000_0000; 
                   endcase
               end
          FENCE:
               begin
                   fence_rob_commit.en = 1'b1;
                   fence_rob_commit.rob_index = lsu_wb_inst_reg1.rob_index;
                   fence_rob_commit.rob_offset = lsu_wb_inst_reg1.rob_offset;
                   case(lsuexu_wb__entry_addr_reg1)
                       3'd0: lsucmt_iq_rmv_en = 8'b0000_0001; 
                       3'd1: lsucmt_iq_rmv_en = 8'b0000_0010; 
                       3'd2: lsucmt_iq_rmv_en = 8'b0000_0100; 
                       3'd3: lsucmt_iq_rmv_en = 8'b0000_1000; 
                       3'd4: lsucmt_iq_rmv_en = 8'b0001_0000; 
                       3'd5: lsucmt_iq_rmv_en = 8'b0010_0000; 
                       3'd6: lsucmt_iq_rmv_en = 8'b0100_0000; 
                       3'd7: lsucmt_iq_rmv_en = 8'b1000_0000; 
                       default: lsucmt_iq_rmv_en = 8'b0000_0000; 
                   endcase
               end
          ATOM:
               begin
                   atom_rob_commit.en = atom_wb_wr_en;  
                   atom_rob_commit.rob_index = lsu_wb_inst_reg1.rob_index;
                   atom_rob_commit.rob_offset = lsu_wb_inst_reg1.rob_offset;
                   if(atom_wb_wr_en)begin
                       case(lsuexu_wb__entry_addr_reg1)
                           3'd0: lsucmt_iq_rmv_en = 8'b0000_0001; 
                           3'd1: lsucmt_iq_rmv_en = 8'b0000_0010; 
                           3'd2: lsucmt_iq_rmv_en = 8'b0000_0100; 
                           3'd3: lsucmt_iq_rmv_en = 8'b0000_1000; 
                           3'd4: lsucmt_iq_rmv_en = 8'b0001_0000; 
                           3'd5: lsucmt_iq_rmv_en = 8'b0010_0000; 
                           3'd6: lsucmt_iq_rmv_en = 8'b0100_0000; 
                           3'd7: lsucmt_iq_rmv_en = 8'b1000_0000; 
                           default: lsucmt_iq_rmv_en = 8'b0000_0000; 
                       endcase
                   end
               end
         
         default: begin
                      ld_rob_commit.en           = 0; 
                      ld_rob_commit.rob_index    = 0; 
                      ld_rob_commit.rob_offset   = 0;
                      ld_rob_commit.excp_en      = 0;
                      ld_rob_commit.excp         = INST_ADDR_MISALIGNED;
                      csr_rob_commit.en          = 0;
                      csr_rob_commit.rob_index   = 0; 
                      csr_rob_commit.rob_offset  = 0;
                      csr_rob_commit.excp_en     = 0;
                      csr_rob_commit.excp        = INST_ADDR_MISALIGNED;
                      fence_rob_commit.en        = 0;
                      fence_rob_commit.rob_index = 0;
                      fence_rob_commit.rob_offset= 0;
                      fence_rob_commit.excp_en   = 0;
                      fence_rob_commit.excp      = INST_ADDR_MISALIGNED;
                      atom_rob_commit.en         = 0; 
                      atom_rob_commit.rob_index  = 0;
                      atom_rob_commit.rob_offset = 0; 
                      atom_rob_commit.excp_en    = 0; 
                      atom_rob_commit.excp       = INST_ADDR_MISALIGNED; 
                      lsucmt_iq_rmv_en = 0;
                  end
     endcase
end
assign lsu_rob__commit_o = ld_rob_commit.en     ? ld_rob_commit    :
                           st_rob_commit.en     ? st_rob_commit    :
                           csr_rob_commit.en    ? csr_rob_commit   :
                           atom_rob_commit.en   ? atom_rob_commit  :
                           fence_rob_commit.en  ? fence_rob_commit :0;
assign cmt_iq__rmv_en_o = (lsucmt_iq_rmv_en | st_lsucmt_iq_rmv_en) & {8{lsu_rob__commit_o.en}};
always_ff  @(posedge clk_i or  `RST_DECL(rst_i)) begin
    if(`RST_TRUE(rst_i)) begin
        lsucmt_iq_rmv_sel_en <= 0;
    end else begin
        case(cmt_iq__rmv_en_o)
            8'b0000_0001: lsucmt_iq_rmv_sel_en <= 8'b1111_1111;
            8'b0000_0010: lsucmt_iq_rmv_sel_en <= 8'b1111_1110;
            8'b0000_0100: lsucmt_iq_rmv_sel_en <= 8'b1111_1100;
            8'b0000_1000: lsucmt_iq_rmv_sel_en <= 8'b1111_1000;
            8'b0001_0000: lsucmt_iq_rmv_sel_en <= 8'b1111_0000;
            8'b0010_0000: lsucmt_iq_rmv_sel_en <= 8'b1110_0000;
            8'b0100_0000: lsucmt_iq_rmv_sel_en <= 8'b1100_0000;
            8'b1000_0000: lsucmt_iq_rmv_sel_en <= 8'b1000_0000;
            
            default:   lsucmt_iq_rmv_sel_en <= 0;
        endcase
    end
end
assign cmt_iq__rmv_sel_en_o = lsucmt_iq_rmv_sel_en;
assign cmt_iq__cg_issued_en_o = lsucmt_iq_cg_issued_en;
assign lsu_prf__rdst_en_o   = ld_wr_rd_en | csr_wr_rd_en | atom_wr_rd_en;
assign lsu_prf__rdst_index_o = ({PC_WTH{ld_wr_rd_en}} & ld_wr_rd_addr) | ({PC_WTH{csr_wr_rd_en}} & csr_wr_rd_addr) | ({PC_WTH{atom_wr_rd_en}} & atom_wr_rd_addr);
assign lsu_prf__rdst_data_o = ({PC_WTH{ld_wr_rd_en}} & ld_wr_rd_data) | ({PC_WTH{csr_wr_rd_en}} & csr_wr_rd_data) | ({PC_WTH{atom_wr_rd_en}} & atom_wr_rd_data);
assign lsu_csr__waddr_o         =  csr_wbuffer_rd_data.mem_addr;
assign lsu_csr__wr_en_o       =  (!csr_wb_empty) &&  (csr_wbuffer_rd_data.status == 2'b10) && (csr_wbuffer_rd_data.is_valid);
assign lsu_csr__wdata_o  =  csr_wbuffer_rd_data.mem_data;
assign lcmem_wd_hit             =   (st_atom_wbuffer_rd_data.mem_addr >= LCMEM_ADDR_STRT)  && (st_atom_wbuffer_rd_data.mem_addr < LCMEM_ADDR_END);
assign lsu_lmrw__waddr_o        =   st_atom_wbuffer_rd_data.mem_addr;
assign lsu_lmrw__wr_en_o        =   (lcmem_wd_hit) && (!(st_atom_wb_empty)) && (st_atom_wbuffer_rd_data.status == 2'b10);
assign lsu_lmrw__wdata_o        =   st_atom_wbuffer_rd_data.mem_data;
assign lsu_lmrw__wstrb_o        =   (st_atom_wbuffer_rd_data.ls_size == BYTE) ? 4'b0001 :
                                    (st_atom_wbuffer_rd_data.ls_size == HALF) ? 4'b0011 :    
                                    (st_atom_wbuffer_rd_data.ls_size == WORD) ? 4'b1111 : 4'b0000;   
assign clint_wd_hit       =   (st_atom_wbuffer_rd_data.mem_addr >= CLINT_ADDR_STRT)  && (st_atom_wbuffer_rd_data.mem_addr < CLINT_ADDR_END);
assign lsu_clint__waddr_o =   st_atom_wbuffer_rd_data.mem_addr;
assign lsu_clint__wr_en_o =   (clint_wd_hit) && (!(st_atom_wb_empty)) && (st_atom_wbuffer_rd_data.status == 2'b10);
assign lsu_clint__wdata_o =   st_atom_wbuffer_rd_data.mem_data;
assign lsu_clint__wstrb_o =   (st_atom_wbuffer_rd_data.ls_size == BYTE) ? 4'b0001 :
                              (st_atom_wbuffer_rd_data.ls_size == HALF) ? 4'b0011 :
                              (st_atom_wbuffer_rd_data.ls_size == WORD) ? 4'b1111 : 4'b0000;
assign cache_wd_hit                   =   (st_atom_wbuffer_rd_data.mem_addr >= CACHE_ADDR_STRT)  && (st_atom_wbuffer_rd_data.mem_addr < CACHE_ADDR_END);
assign lsu_dc__waddr_o         =   {PC_WTH{lsu_dc__nonblk_wr_en_o}} & st_atom_wbuffer_rd_data.mem_addr;
assign lsu_dc__nonblk_wr_en_o  =   (cache_wd_hit) &&( !(st_atom_wb_empty)) && (st_atom_wbuffer_rd_data.status == 2'b10) && (st_atom_wbuffer_rd_data.is_valid) ;
assign lsu_dc__wdata_o         =   {PC_WTH{lsu_dc__nonblk_wr_en_o}} & st_atom_wbuffer_rd_data.mem_data;
assign lsu_dc__wstrb_o         =   (st_atom_wbuffer_rd_data.ls_size == BYTE) ? 4'b0001 :
                                          (st_atom_wbuffer_rd_data.ls_size == HALF) ? 4'b0011 :    
                                          (st_atom_wbuffer_rd_data.ls_size == WORD) ? 4'b1111 : 4'b0000;   
assign dtcm_wd_hit       =   (st_atom_wbuffer_rd_data.mem_addr >= DTCM_ADDR_STRT)  && (st_atom_wbuffer_rd_data.mem_addr < DTCM_ADDR_END);
assign lsu_dtcm__waddr_o =   {PC_WTH{lsu_dtcm__wr_en_o}} & st_atom_wbuffer_rd_data.mem_addr;
assign lsu_dtcm__wr_en_o =   (dtcm_wd_hit) &&( !(st_atom_wb_empty)) && (st_atom_wbuffer_rd_data.status == 2'b10)&& (st_atom_wbuffer_rd_data.is_valid);
assign lsu_dtcm__wdata_o =   {PC_WTH{lsu_dtcm__wr_en_o}} & st_atom_wbuffer_rd_data.mem_data;
assign lsu_dtcm__wstrb_o =   (st_atom_wbuffer_rd_data.ls_size == BYTE) ? 4'b0001 :
                             (st_atom_wbuffer_rd_data.ls_size == HALF) ? 4'b0011 :
                             (st_atom_wbuffer_rd_data.ls_size == WORD) ? 4'b1111 : 4'b0000;
endmodule : hpu_lsu_wbuffer
