`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_mem (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   mem_wr_req_t                            lsu_mem__wr_req_i,
    output  mem_wr_rsp_t                            mem_lsu__wr_rsp_o,
    input   mem_rd_req_t                            lsu_mem__rd_req_i,
    output  mem_rd_rsp_t                            mem_lsu__rd_rsp_o,
    output  logic                                   lsu_dc__wr_en_o,
    output  pc_t                                    lsu_dc__waddr_o,
    input   logic                                   dc_lsu__wr_suc_i,
    output  data_t                                  lsu_dc__wdata_o,
    output  data_strobe_t                           lsu_dc__wstrb_o,
    output  logic                                   lsu_dc__rd_en_o,
    output  pc_t                                    lsu_dc__raddr_o,
    input   logic                                   dc_lsu__rd_suc_i,
    input   data_t                                  dc_lsu__rdata_i,
    output  logic                                   lsu_dtcm__wr_en_o,
    output  logic                                   lsu_dtcm__wr_rls_lock_o,
    input   logic                                   dtcm_lsu__wr_suc_i,
    output  pc_t                                    lsu_dtcm__waddr_o,
    output  data_t                                  lsu_dtcm__wdata_o,
    output  data_strobe_t                           lsu_dtcm__wstrb_o,
    output  logic                                   lsu_dtcm__rd_en_o,
    output  logic                                   lsu_dtcm__rd_acq_lock_o,
    input   logic                                   dtcm_lsu__rd_suc_i,
    output  pc_t                                    lsu_dtcm__raddr_o,
    input   data_t                                  dtcm_lsu__rdata_i,
    output  logic                                   lsu_lmrw__wr_en_o,
    output  pc_t                                    lsu_lmrw__waddr_o,
    input   logic                                   lmrw_lsu__wr_suc_i,
    output  data_t                                  lsu_lmrw__wdata_o,
    output  data_strobe_t                           lsu_lmrw__wstrb_o,
    output  logic                                   lsu_lmrw__rd_en_o,
    output  data_t                                  lsu_lmrw__raddr_o,
    input   data_t                                  lmrw_lsu__rdata_i,
    input   logic                                   lmrw_lsu__rd_suc_i,
    output  logic                                   lsu_clint__wr_en_o,
    output  pc_t                                    lsu_clint__waddr_o,
    output  data_t                                  lsu_clint__wdata_o,
    output  data_strobe_t                           lsu_clint__wstrb_o,
    output  logic                                   lsu_clint__rd_en_o,
    output  pc_t                                    lsu_clint__raddr_o,
    input   data_t                                  clint_lsu__rdata_i,
    output  logic                                   lsu_darb__wr_en_o,
    output  pc_t                                    lsu_darb__waddr_o,
    input   logic                                   darb_lsu__wr_suc_i,
    output  data_t                                  lsu_darb__wdata_o,
    output  data_strobe_t                           lsu_darb__wstrb_o,
    output  logic                                   lsu_darb__rd_en_o,
    output  data_t                                  lsu_darb__raddr_o,
    input   logic                                   darb_lsu__rd_suc_i,
    input   data_t                                  darb_lsu__rdata_i
);
    data_t[1 : 0]                           wdata_dlychain;
    data_strobe_t[1 : 0]                    wstrb_dlychain;
    logic[1 : 0]                            dc_wr_en_dlychain;
    logic[1 : 0]                            dtcm_wr_en_dlychain;
    logic[1 : 0]                            lmrw_wr_en_dlychain;
    logic[1 : 0]                            clint_wr_en_dlychain;
    logic[1 : 0]                            darb_wr_en_dlychain;
    logic[1 : 0]                            dc_rd_en_dlychain;
    logic[1 : 0]                            dtcm_rd_en_dlychain;
    logic[1 : 0]                            lmrw_rd_en_dlychain;
    logic[1 : 0]                            clint_rd_en_dlychain;
    logic[1 : 0]                            darb_rd_en_dlychain;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            wdata_dlychain <= {2{data_t'(0)}};
            wstrb_dlychain <= {2{data_strobe_t'(0)}};
        end else begin
            wdata_dlychain <= {wdata_dlychain[0], lsu_mem__wr_req_i.wdata};
            wstrb_dlychain <= {wstrb_dlychain[0], lsu_mem__wr_req_i.wstrb};
        end
    end
    assign lsu_dc__wr_en_o = lsu_mem__wr_req_i.wr_en
        && (lsu_mem__wr_req_i.waddr >= MEM_CACHE_ADDR_S) && (lsu_mem__wr_req_i.waddr <= MEM_CACHE_ADDR_E);
    assign lsu_dc__waddr_o = lsu_mem__wr_req_i.waddr;
    assign lsu_dc__wdata_o = wdata_dlychain[1];
    assign lsu_dc__wstrb_o = wstrb_dlychain[1];
    assign lsu_dc__rd_en_o = lsu_mem__rd_req_i.rd_en
        && (lsu_mem__rd_req_i.raddr >= MEM_CACHE_ADDR_S) && (lsu_mem__rd_req_i.raddr <= MEM_CACHE_ADDR_E);
    assign lsu_dc__raddr_o = lsu_mem__rd_req_i.raddr;
    assign lsu_dtcm__wr_en_o = lsu_mem__wr_req_i.wr_en
        && (lsu_mem__wr_req_i.waddr >= MEM_DTCM_ADDR_S) && (lsu_mem__wr_req_i.waddr <= MEM_DTCM_ADDR_E);
    assign lsu_dtcm__wr_rls_lock_o = lsu_mem__wr_req_i.rl_lock;
    assign lsu_dtcm__waddr_o = lsu_mem__wr_req_i.waddr;
    assign lsu_dtcm__wdata_o = lsu_mem__wr_req_i.wdata;
    assign lsu_dtcm__wstrb_o = lsu_mem__wr_req_i.wstrb;
    assign lsu_dtcm__rd_en_o = lsu_mem__rd_req_i.rd_en
        && (lsu_mem__rd_req_i.raddr >= MEM_DTCM_ADDR_S) && (lsu_mem__rd_req_i.raddr <= MEM_DTCM_ADDR_E);
    assign lsu_dtcm__rd_acq_lock_o = lsu_mem__rd_req_i.aq_lock;
    assign lsu_dtcm__raddr_o = lsu_mem__rd_req_i.raddr;
    assign lsu_lmrw__wr_en_o = lsu_mem__wr_req_i.wr_en
        && (lsu_mem__wr_req_i.waddr >= MEM_LCMEM_ADDR_S) && (lsu_mem__wr_req_i.waddr <= MEM_LCMEM_ADDR_E);
    assign lsu_lmrw__waddr_o = lsu_mem__wr_req_i.waddr;
    assign lsu_lmrw__wdata_o = lsu_mem__wr_req_i.wdata;
    assign lsu_lmrw__wstrb_o = lsu_mem__wr_req_i.wstrb;
    assign lsu_lmrw__rd_en_o = lsu_mem__rd_req_i.rd_en
        && (lsu_mem__rd_req_i.raddr >= MEM_LCMEM_ADDR_S) && (lsu_mem__rd_req_i.raddr <= MEM_LCMEM_ADDR_E);
    assign lsu_lmrw__raddr_o = lsu_mem__rd_req_i.raddr;
    assign lsu_clint__wr_en_o = lsu_mem__wr_req_i.wr_en
        && (lsu_mem__wr_req_i.waddr >= MEM_CLINT_ADDR_S) && (lsu_mem__wr_req_i.waddr <= MEM_CLINT_ADDR_E);
    assign lsu_clint__waddr_o = lsu_mem__wr_req_i.waddr;
    assign lsu_clint__wdata_o = lsu_mem__wr_req_i.wdata;
    assign lsu_clint__wstrb_o = lsu_mem__wr_req_i.wstrb;
    assign lsu_clint__rd_en_o = lsu_mem__rd_req_i.rd_en
        && (lsu_mem__rd_req_i.raddr >= MEM_CLINT_ADDR_S) && (lsu_mem__rd_req_i.raddr <= MEM_CLINT_ADDR_E);
    assign lsu_clint__raddr_o = lsu_mem__rd_req_i.raddr;
    assign lsu_darb__wr_en_o = lsu_mem__wr_req_i.wr_en
        && (lsu_mem__wr_req_i.waddr >= MEM_DEBUG_ADDR_S) && (lsu_mem__wr_req_i.waddr <= MEM_DEBUG_ADDR_E);
    assign lsu_darb__waddr_o = lsu_mem__wr_req_i.waddr;
    assign lsu_darb__wdata_o = lsu_mem__wr_req_i.wdata;
    assign lsu_darb__wstrb_o = lsu_mem__wr_req_i.wstrb;
    assign lsu_darb__rd_en_o = lsu_mem__rd_req_i.rd_en
        && (lsu_mem__rd_req_i.raddr >= MEM_DEBUG_ADDR_S) && (lsu_mem__rd_req_i.raddr <= MEM_DEBUG_ADDR_E);
    assign lsu_darb__raddr_o = lsu_mem__rd_req_i.raddr;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            dc_wr_en_dlychain <= 2'h0;
            dtcm_wr_en_dlychain <= 2'h0;
            lmrw_wr_en_dlychain <= 2'h0;
            clint_wr_en_dlychain <= 2'h0;
            darb_wr_en_dlychain <= 2'h0;
            dc_rd_en_dlychain <= 2'h0;
            dtcm_rd_en_dlychain <= 2'h0;
            lmrw_rd_en_dlychain <= 2'h0;
            clint_rd_en_dlychain <= 2'h0;
            darb_rd_en_dlychain <= 2'h0;
        end else begin
            dc_wr_en_dlychain <= {dc_wr_en_dlychain[0], lsu_dc__wr_en_o};
            dtcm_wr_en_dlychain <= {dtcm_wr_en_dlychain[0], lsu_dtcm__wr_en_o};
            lmrw_wr_en_dlychain <= {lmrw_wr_en_dlychain[0], lsu_lmrw__wr_en_o};
            clint_wr_en_dlychain <= {clint_wr_en_dlychain[0], lsu_clint__wr_en_o};
            darb_wr_en_dlychain <= {darb_wr_en_dlychain[0], lsu_darb__wr_en_o};
            dc_rd_en_dlychain <= {dc_rd_en_dlychain[0], lsu_dc__rd_en_o};
            dtcm_rd_en_dlychain <= {dtcm_rd_en_dlychain[0], lsu_dtcm__rd_en_o};
            lmrw_rd_en_dlychain <= {lmrw_rd_en_dlychain[0], lsu_lmrw__rd_en_o};
            clint_rd_en_dlychain <= {clint_rd_en_dlychain[0], lsu_clint__rd_en_o};
            darb_rd_en_dlychain <= {darb_rd_en_dlychain[0], lsu_darb__rd_en_o};
        end
    end
    always_comb begin
        if(dc_wr_en_dlychain[0]) begin
            mem_lsu__wr_rsp_o.wr_suc = dc_lsu__wr_suc_i;
        end else if(dtcm_wr_en_dlychain[0]) begin
            mem_lsu__wr_rsp_o.wr_suc = dtcm_lsu__wr_suc_i;
        end else if(lmrw_wr_en_dlychain[0]) begin
            mem_lsu__wr_rsp_o.wr_suc = lmrw_lsu__wr_suc_i;
        end else if(darb_wr_en_dlychain[0]) begin
            mem_lsu__wr_rsp_o.wr_suc = darb_lsu__wr_suc_i;
        end else if(clint_wr_en_dlychain[0]) begin
            mem_lsu__wr_rsp_o.wr_suc = 1'b1;
        end else begin
            mem_lsu__wr_rsp_o.wr_suc = 1'b1;
        end
    end
    always_comb begin
        if(dc_rd_en_dlychain[0]) begin
            mem_lsu__rd_rsp_o.rd_suc = dc_lsu__rd_suc_i;
        end else if(dtcm_rd_en_dlychain[0]) begin
            mem_lsu__rd_rsp_o.rd_suc = dtcm_lsu__rd_suc_i;
        end else if(lmrw_rd_en_dlychain[0]) begin
            mem_lsu__rd_rsp_o.rd_suc = lmrw_lsu__rd_suc_i;
        end else if(darb_rd_en_dlychain[0]) begin
            mem_lsu__rd_rsp_o.rd_suc = darb_lsu__rd_suc_i;
        end else if(clint_rd_en_dlychain[0]) begin
            mem_lsu__rd_rsp_o.rd_suc = 1'b1;
        end else begin
            mem_lsu__rd_rsp_o.rd_suc = 1'b1;
        end
    end
    always_comb begin
        if(dc_rd_en_dlychain[1]) begin
            mem_lsu__rd_rsp_o.rdata = dc_lsu__rdata_i;
        end else if(dtcm_rd_en_dlychain[1]) begin
            mem_lsu__rd_rsp_o.rdata = dtcm_lsu__rdata_i;
        end else if(lmrw_rd_en_dlychain[1]) begin
            mem_lsu__rd_rsp_o.rdata = lmrw_lsu__rdata_i;
        end else if(darb_rd_en_dlychain[1]) begin
            mem_lsu__rd_rsp_o.rdata = darb_lsu__rdata_i;
        end else if(clint_rd_en_dlychain[1]) begin
            mem_lsu__rd_rsp_o.rdata = clint_lsu__rdata_i;
        end else begin
            mem_lsu__rd_rsp_o.rdata = data_t'(0);
        end
    end
endmodule : hpu_mem
