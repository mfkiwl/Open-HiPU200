`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_lsu_exu (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   flush_en_i,
    input   update_ckpt_t                           id__ckpt_rcov_i,
    input   ckpt_t                                  id__prefet_ckpt_i,
    input   logic[LSU_IQ_INDEX-1 : 0]               iq_awksel__entry_addr_i,
    input   lsu_inst_t                              iq_awksel__inst_i,
    input   logic                                   iq_awksel__inst_valid_i,
    output  logic[LSU_IQ_INDEX-1 : 0]               exu_wb__entry_addr_o,
    output  lsu_inst_t                              exu_wb__inst_o,
    output  logic                                   exu_wb__inst_valid_o,
    input   data_t                                  bypass_rs1_data_i,
    input   data_t                                  bypass_rs2_data_i,
    output  pc_t                                    lsu_lmrw__raddr_o,
    output  logic                                   lsu_lmrw__rd_en_o,
    output  logic                                   lsu_lmrw__atom_en_o,
    output  data_t                                  lsu_clint__raddr_o,
    output  logic                                   lsu_clint__rd_en_o,
    output  logic                                   exu_wb__lcmem_hit_o,
    output  logic                                   exu_wb__dtcm_atom_hit_o,
    output  logic                                   exu_wb__dcache_hit_o,
    output  logic                                   exu_wb__clint_hit_o,
    output  pc_t                                    lsu_dtcm__raddr_o,
    output  logic                                   lsu_dtcm__rd_en_o,
    output  logic                                   lsu_dtcm__rd_acq_lock_o,
    output  data_t                                  exu_wb__dtcm_atom_rs2_data_o,
    output  pc_t                                    lsu_dc__raddr_o,
    output  logic                                   lsu_dc__nonblk_rd_en_o,
    output  data_t                                  exu_wb__st_rs2_data_o,
    output  logic[CSR_WTH-1: 0]                     lsu_csr__raddr_o,
    output  logic                                   lsu_csr__rd_en_o,
    output  data_t                                  lsu_csr__rs1_data_o,
    output  logic                                   lsu_addr_unalian_exc_en_o,
    output  logic                                   exu_wb__sb_we_o,
    output  logic                                   exu_wb__csrsb_we_o,
    output  pc_t                                    exu_wb__mem_addr_o,
    input   logic[LSU_IQ_LEN-1:0]                   cmt_iq__rmv_en_i
);
    parameter LCMEM_ADDR_STRT = 32'h0210_0000;
    parameter LCMEM_ADDR_END  = 32'h022f_ffff;
    parameter LCMEM_DTCM_ADDR_STRT = 32'h0203_0000;
    parameter LCMEM_DTCM_ADDR_END  = 32'h0203_ffff;
    parameter LCMEM_CACHE_ADDR_STRT= 32'h8000_0000;
    parameter LCMEM_CACHE_ADDR_END = 32'h9fff_ffff;
    parameter LCMEM_CLINT_ADDR_STRT  = 32'h0200_0000;
    parameter LCMEM_CLINT_ADDR_END   = 32'h0200_ffff;
    lsu_inst_t                                lsuexu_wb__inst_reg;
    logic  [PC_WTH-1 : 0]                     ld_addr;
    logic                                     ld_rd_en; 
    logic  [PC_WTH-1 : 0]                     st_addr;
    logic  [DATA_WTH-1:0]                     st_data;
    logic                                     st_wr_en;
    logic  [PC_WTH-1 : 0]                     csr_addr;
    logic                                     csr_rd_en;
    logic                                     csr_wr_en;
    logic                                     atom_rd_en;
    logic  [PC_WTH-1 : 0]                     atom_rd_addr;
    logic                                     atom_wr_en;
    logic  [DATA_WTH-1:0]                     atom_wr_rs2;
    
    logic  [DATA_WTH-1:0]                     csr_wr_rs1;
    logic                                     lsu_addr_unalian_exc_en;
    logic                                     lsu_lcmem_hit;
    logic                                     lsu_lcmen_dtcm_atom_hit;
    logic                                     lsu_cache_hit;
    logic                                     lsu_clint_hit;
    logic  [LSU_IQ_INDEX-1 : 0]           lsuexu_wb__entry_addr_reg;
    logic  [8-1:0]                            pre_iq_rmv_en;
    logic                                     lsuexu_wb__inst_valid_reg;
always_comb begin
    case(lsuexu_wb__entry_addr_reg)
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
    lsuexu_wb__inst_reg <= iq_awksel__inst_i;
end
always_ff @(posedge clk_i) begin
    lsuexu_wb__entry_addr_reg <= iq_awksel__entry_addr_i;
    lsuexu_wb__inst_valid_reg <= iq_awksel__inst_valid_i;
end
assign  exu_wb__entry_addr_o  = ((cmt_iq__rmv_en_i < pre_iq_rmv_en) && (|cmt_iq__rmv_en_i) && lsuexu_wb__inst_valid_reg ) ? lsuexu_wb__entry_addr_reg -1 :lsuexu_wb__entry_addr_reg;
assign  exu_wb__inst_o  = lsuexu_wb__inst_reg;
assign  exu_wb__inst_valid_o = lsuexu_wb__inst_valid_reg;
always_comb begin
     ld_addr      <= 0;
     ld_rd_en     <= 0;
     st_addr      <= 0;
     st_data      <= 0;
     st_wr_en     <= 0;
     csr_addr     <= 0;
     csr_rd_en    <= 0;
     csr_wr_en    <= 0;
     atom_rd_en   <= 0; 
     atom_rd_addr <= 0;
     atom_wr_en   <= 0;
     atom_wr_rs2  <= 0;
     csr_wr_rs1   <= 0;
     case(lsuexu_wb__inst_reg.opcode.optype)
          LOAD:
               begin
                   ld_addr  <= lsuexu_wb__inst_reg.opcode.imm + bypass_rs1_data_i;
                   ld_rd_en <= 1'b1;
               end
          STORE:
               begin
                   st_addr  <=  lsuexu_wb__inst_reg.opcode.imm + bypass_rs1_data_i;
                   st_data  <=  bypass_rs2_data_i;
                   st_wr_en <=  1'b1; 
               end
          CSR:
               begin
                   csr_addr  <= lsuexu_wb__inst_reg.opcode.csr_addr;
                   csr_rd_en <= lsuexu_wb__inst_reg.opcode.csr_rd_is_x0 ? 1'b0 : 1'b1;
                   csr_wr_en <= ((((lsuexu_wb__inst_reg.opcode.csr_func == CSR_RS) || (iq_awksel__inst_i.opcode.csr_func == CSR_RC))
                                && (bypass_rs1_data_i == 0)) ||
                                ((lsuexu_wb__inst_reg.opcode.csr_func == CSR_RSI)|| (iq_awksel__inst_i.opcode.csr_func == CSR_RCI)) &&(iq_awksel__inst_i.opcode.imm ==0)) ? 1'b0 :1'b1;
                   case(lsuexu_wb__inst_reg.opcode.csr_func)
                       CSR_RW:  csr_wr_rs1 <= bypass_rs1_data_i;
                       CSR_RS:  csr_wr_rs1 <= bypass_rs1_data_i;
                       CSR_RC:  csr_wr_rs1 <= bypass_rs1_data_i;
                       CSR_RWI: csr_wr_rs1 <= {27'b0,lsuexu_wb__inst_reg.opcode.imm[4:0]};
                       CSR_RSI: csr_wr_rs1 <= {27'b0,lsuexu_wb__inst_reg.opcode.imm[4:0]};
                       CSR_RCI: csr_wr_rs1 <= {27'b0,lsuexu_wb__inst_reg.opcode.imm[4:0]};
                       default:csr_wr_rs1 <= 0;
                   endcase
                  
               end
          ATOM:
               begin
                   atom_rd_en   <= 1'b1;
                   atom_rd_addr <= bypass_rs1_data_i;
                   atom_wr_en   <= 1'b1;
                   atom_wr_rs2  <= bypass_rs2_data_i;
               end
         
         default: begin
          ld_addr      <= 0;
          ld_rd_en     <= 0;
          st_addr      <= 0;
          st_data      <= 0;
          st_wr_en     <= 0;
          csr_addr     <= 0;
          csr_rd_en    <= 0;
          csr_wr_en    <= 0;
          atom_rd_en   <= 0; 
          atom_rd_addr <= 0;
          atom_wr_en   <= 0;
          atom_wr_rs2  <= 0;
         end
     endcase
end
always_ff @(posedge clk_i or  `RST_DECL(rst_i)) begin
    if(`RST_TRUE(rst_i)) begin
        lsu_addr_unalian_exc_en <= 1'b0; 
    end else begin
        lsu_addr_unalian_exc_en <= (ld_addr[1:0] != 2'b00)  || (st_addr[1:0] != 2'b00)|| (csr_addr[1:0] != 2'b00)|| (atom_rd_addr[1:0] != 2'b00) ; 
    end
end
assign  lsu_addr_unalian_exc_en_o = lsu_addr_unalian_exc_en;
assign lsu_lcmem_hit = (ld_addr >= LCMEM_ADDR_STRT)  && (ld_addr < LCMEM_ADDR_END);
assign lsu_lmrw__rd_en_o = ld_rd_en && lsu_lcmem_hit ; 
assign lsu_lmrw__raddr_o  = ({PC_WTH{lsu_lmrw__rd_en_o}} & ld_addr)  ;
assign lsu_lmrw__atom_en_o = (iq_awksel__inst_i.opcode.optype == ATOM);
assign lsu_clint_hit = (ld_addr >= LCMEM_CLINT_ADDR_STRT)  && (ld_addr < LCMEM_CLINT_ADDR_END);
assign lsu_clint__rd_en_o = ld_rd_en && lsu_clint_hit ; 
assign lsu_clint__raddr_o  = ({PC_WTH{lsu_clint__rd_en_o}} & ld_addr)  ;
assign lsu_lcmen_dtcm_atom_hit = (atom_rd_addr >= LCMEM_DTCM_ADDR_STRT)  && (atom_rd_addr < LCMEM_DTCM_ADDR_END) ;
assign exu_wb__dtcm_atom_rs2_data_o = atom_wr_rs2;
assign lsu_dtcm__raddr_o =  ({PC_WTH{atom_rd_en}} & atom_rd_addr);
assign lsu_dtcm__rd_en_o = (lsu_lcmen_dtcm_atom_hit);
assign lsu_dtcm__rd_acq_lock_o = atom_rd_en && (lsu_lcmen_dtcm_atom_hit);
assign lsu_cache_hit = (ld_addr >= LCMEM_CACHE_ADDR_STRT)  && (ld_addr < LCMEM_CACHE_ADDR_END) ;
assign lsu_dc__nonblk_rd_en_o = ld_rd_en & lsu_cache_hit ;
assign lsu_dc__raddr_o =  ({PC_WTH{lsu_dc__nonblk_rd_en_o}} & ld_addr) ;
assign lsu_csr__rd_en_o = csr_rd_en;
assign lsu_csr__raddr_o = csr_addr;
assign lsu_csr__rs1_data_o = csr_wr_rs1;
assign exu_wb__sb_we_o = (st_wr_en | atom_wr_en) ;
assign exu_wb__csrsb_we_o = csr_wr_en ;
assign exu_wb__mem_addr_o = ( {PC_WTH{st_wr_en}} & st_addr)  | ({CSR_WTH{csr_wr_en}}& csr_addr) | ({PC_WTH{atom_wr_en}}& atom_rd_addr);
assign exu_wb__st_rs2_data_o = st_data;
assign exu_wb__lcmem_hit_o = lsu_lcmem_hit;
assign exu_wb__dtcm_atom_hit_o = lsu_lcmen_dtcm_atom_hit;
assign exu_wb__dcache_hit_o = lsu_cache_hit;
assign exu_wb__clint_hit_o = lsu_clint_hit;
endmodule : hpu_lsu_exu
