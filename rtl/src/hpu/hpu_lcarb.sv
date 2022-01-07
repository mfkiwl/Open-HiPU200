// ---------------------------------------------------------------------------------------------------------------------
// Copyright (c) 1986 - 2020, CAG team, Institute of AI and Robotics, Xi'an Jiaotong University. Proprietary and
// Confidential All Rights Reserved.
// ---------------------------------------------------------------------------------------------------------------------
// NOTICE: All information contained herein is, and remains the property of CAG team, Institute of AI and Robotics,
// Xi'an Jiaotong University. The intellectual and technical concepts contained herein are proprietary to CAG team, and
// may be covered by P.R.C. and Foreign Patents, patents in process, and are protected by trade secret or copyright law.
//
// This work may not be copied, modified, re-published, uploaded, executed, or distributed in any way, in any time, in
// any medium, whether in whole or in part, without prior written permission from CAG team, Institute of AI and
// Robotics, Xi'an Jiaotong University.
//
// The copyright notice above does not evidence any actual or intended publication or disclosure of this source code,
// which includes information that is confidential and/or proprietary, and is a trade secret, of CAG team.
// ---------------------------------------------------------------------------------------------------------------------
// FILE NAME  : hpu_lcarb.sv
// DEPARTMENT : CAG of IAIR
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_lcarb(
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   ndma_cmd_t                              l2c_lcarb__cmd_i,
    input   logic                                   l2c_lcarb__cmd_valid_i,
    output  logic                                   lcarb_l2c__cmd_ready_o,
    output  logic                                   lcarb_l2c__cmd_done_o,
    output  ndma_mem_req_t                          lcarb_l2c__mem_req_o,
    input   ndma_mem_rsp_t                          l2c_lcarb__mem_rsp_i,
    input   csr_bus_req_t                           csr_lcarb__bus_req_i,
    output  csr_bus_rsp_t                           lcarb_csr__bus_rsp_o,
    output  logic                                   lcarb_lmrw__mem_re_o,
    output  logic[17:0]                             lcarb_lmrw__mem_raddr_o,
    input   logic                                   lmrw_lcarb__mem_rdata_act_i,
    input   logic[255:0]                            lmrw_lcarb__mem_rdata_i,
    output  logic                                   lcarb_lmrw__mem_we_o,
    output  logic[17:0]                             lcarb_lmrw__mem_waddr_o,
    output  logic[255:0]                            lcarb_lmrw__mem_wdata_o,
    output  logic[7:0]                              lcarb_lmrw__mem_wstrb_o,
    output  logic                                   lcarb_lmro__mem_re_o,
    output  logic[17:0]                             lcarb_lmro__mem_raddr_o,
    input   logic                                   lmro_lcarb__mem_rdata_act_i,
    input   logic[255:0]                            lmro_lcarb__mem_rdata_i,
    output  logic                                   lcarb_lmro__mem_we_o,
    output  logic[17:0]                             lcarb_lmro__mem_waddr_o,
    output  logic[255:0]                            lcarb_lmro__mem_wdata_o,
    output  logic[7:0]                              lcarb_lmro__mem_wstrb_o,
    output  logic                                   lcarb_dtcm__mem_re_o,
    output  logic[13:0]                             lcarb_dtcm__mem_raddr_o,
    input   logic                                   dtcm_lcarb__mem_rdata_act_i,
    input   logic[255:0]                            dtcm_lcarb__mem_rdata_i,
    output  logic                                   lcarb_dtcm__mem_we_o,
    output  logic[13:0]                             lcarb_dtcm__mem_waddr_o,
    output  logic[255:0]                            lcarb_dtcm__mem_wdata_o,
    output  logic[7:0]                              lcarb_dtcm__mem_wstrb_o,
    input   logic                                   dtcm_lcarb__mem_atom_ready_i,
    output  logic                                   lcarb_clint__ndma_intr_o,
    output  logic                                   lcarb_clint__slv_wr_intr_o,
    output  logic                                   lcarb_clint__slv_rd_intr_o,
    output  logic                                   lcarb_clint__slv_swap_intr_o,
    output  logic[3 : 0]                            ndma_cmd_op_o,
    output  logic[15 : 0]                           ndma_cmd_id_o,
    output  logic[NDMA_TRANS_BIT-1 : 0]             ndma_cmd_size_o,
    output  logic[NDMA_LC_ADDR_WTH-1 : 0]           ndma_cmd_lcaddr_o,
    output  logic[NDMA_ADDR_WTH-1 : 0]              ndma_cmd_rtaddr_o,
    output  logic[NDMA_NDX_WTH-1 : 0]               ndma_cmd_destx_o,
    output  logic[NDMA_NDY_WTH-1 : 0]               ndma_cmd_desty_o,
    output  logic                                   ndma_cmd_valid_o,
    input   logic                                   ndma_cmd_ready_i,
    input   logic[15 : 0]                           ndma_tx_done_id_i,
    input   logic                                   ndma_tx_done_i,
    input   logic[15 : 0]                           ndma_rx_done_id_i,
    input   logic                                   ndma_rx_done_i,
    input   logic                                   ndma_mem_re_i,
    input   logic[NDMA_LC_ADDR_WTH-1 : 0]           ndma_mem_raddr_i,
    output  logic[NDMA_LC_DATA_WTH-1 : 0]           ndma_mem_rdata_o,
    output  logic                                   ndma_mem_rdata_act_o,
    input   logic                                   ndma_mem_we_i,
    input   logic[NDMA_LC_ADDR_WTH-1 : 0]           ndma_mem_waddr_i,
    input   logic[NDMA_LC_DATA_WTH-1 : 0]           ndma_mem_wdata_i,
    input   logic[NDMA_LC_STRB_WTH-1 : 0]           ndma_mem_wstrb_i,
    output  logic                                   ndma_mem_atom_ready_o,
    input   logic[3 : 0]                            csr_hpu_id_i,
    input   logic[255 : 0]                          dtcm_lcarb__node_map_i,
    input   logic[255 : 0]                          dtcm_lcarb__mem_map_i,
    input   logic                                   safemd_ndma_single_cmd_i
);
    typedef enum logic[1:0] { L2C, CSR } lcarb_status_e;
    logic[1 : 0]                            csr_ndma_cmd;
    logic[7 : 0]                            csr_ndma_done_vec;
    logic[31 : 0]                           csr_ndma_lcaddr;
    logic[31 : 0]                           csr_ndma_rtaddr;
    logic[19 : 0]                           csr_ndma_size;
    logic[1 : 0]                            csr_ndma_destx;
    logic[1 : 0]                            csr_ndma_desty;
    logic[15 : 0]                           csr_ndma_wr_mask;
    logic[15 : 0]                           csr_ndma_rd_mask;
    logic[15 : 0]                           csr_ndma_swap_mask;
    logic[15 : 0]                           csr_ndma_wr_clr;
    logic[15 : 0]                           csr_ndma_rd_clr;
    logic[15 : 0]                           csr_ndma_swap_clr;
    logic                                   csr_ndma_cmd_vld;
    logic                                   csr_done_clr;
    logic                                   csr_ndma_wr_clr_vld;
    logic                                   csr_ndma_rd_clr_vld;
    logic                                   csr_ndma_swap_clr_vld;
    logic[7 : 0]                            csr_done_vec;
    logic[7 : 0]                            csr_done_busy;
    logic[2 : 0]                            sel_index;
    logic                                   done_vec_vld;
    ndma_id_t                               csr_id;
    ndma_cmd_t                              csr_cmd;
    logic                                   csr_cmd_with_id_valid;
    logic                                   csr_cmd_ready;
    logic[2 : 0]                            cur_sel_index;
    ndma_id_t                               l2c_id;
    logic[7 : 0]                            nmap[31 : 0];
    ndma_cmd_t                              l2c_lcarb_cmd;
    logic[1 : 0]                            arb_sel;
    logic[1 : 0]                            arb_sel_comb;
    ndma_cmd_t                              cmdff_cmd;
    ndma_id_t                               cmdff_id;
    logic                                   cmdff_we;
    logic                                   cmdff_full;
    ndma_cmd_t                              ndma_cmd;
    ndma_id_t                               ndma_id;
    logic                                   ndma_empty;
    logic[5 : 0]                            mmap[31 : 0];
    logic                                   ndma_re;
    logic                                   single_rsv;
    logic                                   ndma_mem_we;
    logic[NDMA_LC_ADDR_WTH-1 : 0]           ndma_mem_waddr;
    logic[NDMA_LC_DATA_WTH-1 : 0]           ndma_mem_wdata;
    logic[NDMA_LC_STRB_WTH-1 : 0]           ndma_mem_wstrb;
    logic                                   lmrw_wsel;
    logic                                   lmro_wsel;
    logic                                   dtcm_wsel;
    logic                                   l2c_wsel;
    logic                                   lmrw_rsel;
    logic                                   lmro_rsel;
    logic                                   dtcm_rsel;
    logic                                   l2c_rsel;
    logic[1 : 0]                            lmrw_rsel_dlychain;
    logic[1 : 0]                            lmro_rsel_dlychain;
    logic[1 : 0]                            dtcm_rsel_dlychain;
    logic[1 : 0]                            l2c_rsel_dlychain;
    logic[1 : 0]                            other_rsel_dlychain;
    logic[15 : 0]                           ndma_tx_done_id;
    logic                                   ndma_tx_done;
    logic[15 : 0]                           ndma_rx_done_id;
    logic                                   ndma_rx_done;
    ndma_id_t                               tx_id;
    ndma_id_t                               rx_id;
    logic                                   mst_tx_done;
    logic                                   mst_rx_done;
    logic                                   csr_cmd_done;
    logic[2 : 0]                            csr_cmd_index;
    logic                                   slv_tx_done;
    logic                                   slv_rx_done;
    logic                                   slv_wr_done;
    logic[3 : 0]                            slv_wr_index;
    logic                                   slv_rd_done;
    logic[3 : 0]                            slv_rd_index;
    logic                                   slv_swap_done;
    logic[3 : 0]                            slv_swap_index;
    logic[15 : 0]                           slv_wr_done_vec;
    logic[15 : 0]                           slv_rd_done_vec;
    logic[15 : 0]                           slv_swap_done_vec;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            csr_ndma_cmd <= 2'h0;
            csr_ndma_done_vec <= 8'h0;
            csr_ndma_lcaddr <= 32'h0;
            csr_ndma_rtaddr <= 32'h0;
            csr_ndma_size <= 20'h0;
            csr_ndma_destx <= 2'h0;
            csr_ndma_desty <= 2'h0;
            csr_ndma_wr_mask <= 16'h0;
            csr_ndma_rd_mask <= 16'h0;
            csr_ndma_swap_mask <= 16'h0;
            csr_ndma_wr_clr <= 16'h0;
            csr_ndma_rd_clr <= 16'h0;
            csr_ndma_swap_clr <= 16'h0;
            csr_ndma_cmd_vld <= 1'b0;
            csr_done_clr <= 1'b0;
            csr_ndma_wr_clr_vld <= 1'b0;
            csr_ndma_rd_clr_vld <= 1'b0;
            csr_ndma_swap_clr_vld <= 1'b0;
        end else begin
            if(csr_lcarb__bus_req_i.wr_en) begin
                case(csr_lcarb__bus_req_i.waddr)
                    CSR_ADDR_NDMA_CTRL   : begin
                        csr_ndma_cmd <= csr_lcarb__bus_req_i.wdata[1:0];
                        csr_ndma_done_vec <= csr_lcarb__bus_req_i.wdata[31:24];
                    end
                    CSR_ADDR_NDMA_LCADDR : csr_ndma_lcaddr <= csr_lcarb__bus_req_i.wdata[31:0];
                    CSR_ADDR_NDMA_RTADDR : csr_ndma_rtaddr <= csr_lcarb__bus_req_i.wdata[31:0];
                    CSR_ADDR_NDMA_SIZE   : csr_ndma_size <= csr_lcarb__bus_req_i.wdata[19:0];
                    CSR_ADDR_NDMA_DESTXY : {csr_ndma_destx, csr_ndma_desty}<= csr_lcarb__bus_req_i.wdata[3:0];
                    CSR_ADDR_NDMA_WR_MASK: csr_ndma_wr_mask <= csr_lcarb__bus_req_i.wdata[15:0];
                    CSR_ADDR_NDMA_RD_MASK: csr_ndma_rd_mask <= csr_lcarb__bus_req_i.wdata[15:0];
                    CSR_ADDR_NDMA_SWAP_MASK: csr_ndma_swap_mask <= csr_lcarb__bus_req_i.wdata[15:0];
                    CSR_ADDR_NDMA_WR_CLR : csr_ndma_wr_clr <= csr_lcarb__bus_req_i.wdata[15:0];
                    CSR_ADDR_NDMA_RD_CLR : csr_ndma_rd_clr <= csr_lcarb__bus_req_i.wdata[15:0];
                    CSR_ADDR_NDMA_SWAP_CLR : csr_ndma_swap_clr <= csr_lcarb__bus_req_i.wdata[15:0];
                endcase
            end
            if(csr_lcarb__bus_req_i.wr_en && csr_lcarb__bus_req_i.waddr == CSR_ADDR_NDMA_CTRL
                && (csr_lcarb__bus_req_i.wdata[1:0] != 3'h3)) begin
                csr_ndma_cmd_vld <= 1'b1;
            end else if(csr_cmd_ready) begin
                csr_ndma_cmd_vld <= 1'b0;
            end
            if(csr_lcarb__bus_req_i.wr_en && csr_lcarb__bus_req_i.waddr == CSR_ADDR_NDMA_CTRL
                && (csr_lcarb__bus_req_i.wdata[1:0] == 3'h3)) begin
                csr_done_clr <= 1'b1;
            end else begin
                csr_done_clr <= 1'b0;
            end
            csr_ndma_wr_clr_vld <= csr_lcarb__bus_req_i.wr_en&&(csr_lcarb__bus_req_i.waddr==CSR_ADDR_NDMA_WR_CLR);
            csr_ndma_rd_clr_vld <= csr_lcarb__bus_req_i.wr_en&&(csr_lcarb__bus_req_i.waddr==CSR_ADDR_NDMA_RD_CLR);
            csr_ndma_swap_clr_vld <= csr_lcarb__bus_req_i.wr_en&&(csr_lcarb__bus_req_i.waddr==CSR_ADDR_NDMA_SWAP_CLR);
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            lcarb_csr__bus_rsp_o <= csr_bus_rsp_t'(0);
        end else begin
            case(csr_lcarb__bus_req_i.raddr)
                CSR_ADDR_NDMA_STATUS   : lcarb_csr__bus_rsp_o.rdata <= {csr_done_vec, 15'h0,
                    csr_ndma_cmd_vld, 5'h0, cur_sel_index};
                CSR_ADDR_NDMA_LCADDR   : lcarb_csr__bus_rsp_o.rdata <= csr_ndma_lcaddr;
                CSR_ADDR_NDMA_RTADDR   : lcarb_csr__bus_rsp_o.rdata <= csr_ndma_rtaddr;
                CSR_ADDR_NDMA_SIZE     : lcarb_csr__bus_rsp_o.rdata <= {12'h0, csr_ndma_size};
                CSR_ADDR_NDMA_DESTXY   : lcarb_csr__bus_rsp_o.rdata <= {28'h0, csr_ndma_destx, csr_ndma_desty};
                CSR_ADDR_NDMA_WR_DONE  : lcarb_csr__bus_rsp_o.rdata <= {16'h0, slv_wr_done_vec};
                CSR_ADDR_NDMA_RD_DONE  : lcarb_csr__bus_rsp_o.rdata <= {16'h0, slv_rd_done_vec};
                CSR_ADDR_NDMA_SWAP_DONE: lcarb_csr__bus_rsp_o.rdata <= {16'h0, slv_swap_done_vec};
                CSR_ADDR_NDMA_WR_MASK  : lcarb_csr__bus_rsp_o.rdata <= {16'h0, csr_ndma_wr_mask};
                CSR_ADDR_NDMA_RD_MASK  : lcarb_csr__bus_rsp_o.rdata <= {16'h0, csr_ndma_rd_mask};
                CSR_ADDR_NDMA_SWAP_MASK: lcarb_csr__bus_rsp_o.rdata <= {16'h0, csr_ndma_swap_mask};
                default                : lcarb_csr__bus_rsp_o.rdata <= data_t'(0);
            endcase
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<8; i=i+1) begin
                csr_done_vec[i] <= 1'b0;
                csr_done_busy[i] <= 1'b0;
            end
        end else begin
            for(integer i=0; i<8; i=i+1) begin
                if(csr_done_clr && csr_ndma_done_vec[i]) begin
                    csr_done_vec[i] <= 1'b0;
                end
                if(csr_cmd_with_id_valid && csr_cmd_ready) begin
                    csr_done_busy[sel_index] <= 1'b1;
                end
                if(csr_cmd_done && (csr_cmd_index == i)) begin
                    csr_done_vec[csr_cmd_index] <= 1'b1;
                    csr_done_busy[csr_cmd_index] <= 1'b0;
                end
            end
        end
    end
    always_comb begin
        sel_index = 3'h7;
        done_vec_vld = 1'b0;
        for(integer i=7; i>=0; i=i-1) begin
            if(!csr_done_vec[i] && !csr_done_busy[i]) begin
                sel_index = i[2:0];
                done_vec_vld = 1'b1;
            end
        end
    end
    assign csr_id = ndma_id_t'({1'b0, sel_index, csr_ndma_cmd, csr_hpu_id_i});
    assign csr_cmd.cmd = csr_ndma_cmd;
    assign csr_cmd.lcaddr = csr_ndma_lcaddr;
    assign csr_cmd.rtaddr = csr_ndma_rtaddr;
    assign csr_cmd.size = {{NDMA_TRANS_BIT-20{1'b0}}, csr_ndma_size};
    assign csr_cmd.destx = csr_ndma_destx;
    assign csr_cmd.desty = csr_ndma_desty;
    assign csr_cmd_with_id_valid = csr_ndma_cmd_vld && done_vec_vld;
    assign csr_cmd_ready = (arb_sel == CSR) ? !cmdff_full && done_vec_vld : 1'b0;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            cur_sel_index <= 3'h0;
        end else begin
            if(csr_cmd_with_id_valid && csr_cmd_ready) begin
                cur_sel_index <= sel_index;
            end
        end
    end
    assign l2c_id = ndma_id_t'({1'b1, 3'h0, l2c_lcarb__cmd_i.cmd, csr_hpu_id_i});
    always_comb begin
        for(integer i=0; i<32; i=i+1) begin
            nmap[i] = dtcm_lcarb__node_map_i[i*8 +: 8];
        end
    end
    always_comb begin
        l2c_lcarb_cmd = l2c_lcarb__cmd_i;
        l2c_lcarb_cmd.destx = nmap[l2c_lcarb_cmd.rtaddr[PC_WTH-2 : 26]][5:4];
        l2c_lcarb_cmd.desty = nmap[l2c_lcarb_cmd.rtaddr[PC_WTH-2 : 26]][1:0];
    end
    assign lcarb_l2c__cmd_ready_o = (arb_sel == L2C) ? !cmdff_full : 1'b0;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            arb_sel <= L2C;
        end else begin
            arb_sel <= arb_sel_comb;
        end
    end
    always_comb begin
        arb_sel_comb = arb_sel;
        case(arb_sel)
            L2C: begin
                if(csr_cmd_with_id_valid) begin
                    arb_sel_comb = CSR;
                end
            end
            CSR: begin
                if(l2c_lcarb__cmd_valid_i) begin
                    arb_sel_comb = L2C;
                end
            end
        endcase
    end
    assign cmdff_cmd = (arb_sel == L2C) ? l2c_lcarb_cmd : csr_cmd;
    assign cmdff_id = (arb_sel == L2C) ? l2c_id : csr_id;
    assign cmdff_we = (arb_sel == L2C) ? l2c_lcarb__cmd_valid_i : csr_cmd_with_id_valid;
    sync_fifo #(
        .FIFO_LEN           (2),
        .DATA_WTH           (12+NDMA_LC_ADDR_WTH+NDMA_ADDR_WTH+NDMA_TRANS_BIT+NDMA_NDX_WTH+NDMA_NDY_WTH),
        .ADDR_WTH           (1),
        .FULL_ASSERT_VALUE  (2),
        .FULL_NEGATE_VALUE  (2),
        .EMPTY_ASSERT_VALUE (0),
        .EMPTY_NEGATE_VALUE (0)
    ) cmdff_inst (
        .clk_i                          (clk_i),
        .rst_i                          (rst_i),
        .wr_data_i                      ({cmdff_id, cmdff_cmd}),
        .wr_en_i                        (cmdff_we),
        .full_o                         (cmdff_full),
        .a_full_o                       (),
        .rd_data_o                      ({ndma_id, ndma_cmd}),
        .rd_en_i                        (ndma_re),
        .empty_o                        (ndma_empty),
        .a_empty_o                      ()
    );
    always_comb begin
        for(integer i=0; i<32; i=i+1) begin
            mmap[i] = dtcm_lcarb__mem_map_i[i*8 +: 6];
        end
    end
    assign ndma_cmd_op_o = {2'h0, ndma_cmd.cmd};
    assign ndma_cmd_id_o = {6'h0, ndma_id};
    assign ndma_cmd_size_o = ndma_cmd.size;
    assign ndma_cmd_lcaddr_o = ndma_cmd.lcaddr;
    assign ndma_cmd_rtaddr_o = ndma_cmd.rtaddr[PC_WTH-1] ? {mmap[ndma_cmd.rtaddr[PC_WTH-2:26]], ndma_cmd.rtaddr[25:0]}
                                                         : ndma_cmd.rtaddr;
    assign ndma_cmd_destx_o = ndma_cmd.destx;
    assign ndma_cmd_desty_o = ndma_cmd.desty;
    assign ndma_cmd_valid_o = safemd_ndma_single_cmd_i ? !ndma_empty && !single_rsv: !ndma_empty;
    assign ndma_re = ndma_cmd_valid_o && ndma_cmd_ready_i;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            single_rsv <= 1'b0;
        end else begin
            if(ndma_cmd_valid_o && ndma_cmd_ready_i) begin
                single_rsv <= 1'b1;
            end else if(lcarb_l2c__cmd_done_o || csr_cmd_done) begin
                single_rsv <= 1'b0;
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ndma_mem_we <= 1'b0;
            ndma_mem_waddr <= {NDMA_LC_ADDR_WTH{1'b0}};
            ndma_mem_wdata <= {NDMA_LC_DATA_WTH{1'b0}};
            ndma_mem_wstrb <= {NDMA_LC_STRB_WTH{1'b0}};
        end else begin
            ndma_mem_we <= ndma_mem_we_i;
            ndma_mem_waddr <= ndma_mem_waddr_i;
            ndma_mem_wdata <= ndma_mem_wdata_i;
            ndma_mem_wstrb <= ndma_mem_wstrb_i;
        end
    end
    assign lmrw_wsel = (ndma_mem_waddr[NDMA_LC_ADDR_WTH-1 : 18] == MEM_LCMEM_ADDR_S[NDMA_LC_ADDR_WTH-1 : 18]);
    assign lmro_wsel = (ndma_mem_waddr[NDMA_LC_ADDR_WTH-1 : 18] == MEM_LCMEM_ADDR_S[NDMA_LC_ADDR_WTH-1 : 18] + 1'b1);
    assign dtcm_wsel = (ndma_mem_waddr[NDMA_LC_ADDR_WTH-1 : 14] == MEM_DTCM_ADDR_S[NDMA_LC_ADDR_WTH-1 : 14]);
    assign l2c_wsel = ndma_mem_waddr[NDMA_LC_ADDR_WTH-1];
    assign lcarb_lmrw__mem_we_o = ndma_mem_we & lmrw_wsel;
    assign lcarb_lmrw__mem_waddr_o = ndma_mem_waddr[17 : 0];
    assign lcarb_lmrw__mem_wdata_o = ndma_mem_wdata;
    assign lcarb_lmrw__mem_wstrb_o = ndma_mem_wstrb;
    assign lcarb_lmro__mem_we_o = ndma_mem_we & lmro_wsel;
    assign lcarb_lmro__mem_waddr_o = ndma_mem_waddr[17 : 0];
    assign lcarb_lmro__mem_wdata_o = ndma_mem_wdata;
    assign lcarb_lmro__mem_wstrb_o = ndma_mem_wstrb;
    assign lcarb_dtcm__mem_we_o = ndma_mem_we & dtcm_wsel;
    assign lcarb_dtcm__mem_waddr_o = ndma_mem_waddr[13 : 0];
    assign lcarb_dtcm__mem_wdata_o = ndma_mem_wdata;
    assign lcarb_dtcm__mem_wstrb_o = ndma_mem_wstrb;
    assign lcarb_l2c__mem_req_o.wr_en = ndma_mem_we & l2c_wsel;
    assign lcarb_l2c__mem_req_o.waddr = ndma_mem_waddr;
    assign lcarb_l2c__mem_req_o.wdata = ndma_mem_wdata;
    assign lcarb_l2c__mem_req_o.wstrb = ndma_mem_wstrb;
    assign ndma_mem_atom_ready_o = dtcm_lcarb__mem_atom_ready_i;
    assign lmrw_rsel = (ndma_mem_raddr_i[NDMA_LC_ADDR_WTH-1 : 18] == MEM_LCMEM_ADDR_S[NDMA_LC_ADDR_WTH-1 : 18]);
    assign lmro_rsel = (ndma_mem_raddr_i[NDMA_LC_ADDR_WTH-1 : 18] == MEM_LCMEM_ADDR_S[NDMA_LC_ADDR_WTH-1 : 18] + 1'b1);
    assign dtcm_rsel = (ndma_mem_raddr_i[NDMA_LC_ADDR_WTH-1 : 14] == MEM_DTCM_ADDR_S[NDMA_LC_ADDR_WTH-1 : 14]);
    assign l2c_rsel = ndma_mem_raddr_i[NDMA_LC_ADDR_WTH-1];
    assign lcarb_lmrw__mem_re_o = ndma_mem_re_i & lmrw_rsel;
    assign lcarb_lmrw__mem_raddr_o = ndma_mem_raddr_i[17 : 0];
    assign lcarb_lmro__mem_re_o = ndma_mem_re_i & lmro_rsel;
    assign lcarb_lmro__mem_raddr_o = ndma_mem_raddr_i[17 : 0];
    assign lcarb_dtcm__mem_re_o = ndma_mem_re_i & dtcm_rsel;
    assign lcarb_dtcm__mem_raddr_o = ndma_mem_raddr_i[13 : 0];
    assign lcarb_l2c__mem_req_o.rd_en = ndma_mem_re_i & l2c_rsel;
    assign lcarb_l2c__mem_req_o.raddr = ndma_mem_raddr_i;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            lmrw_rsel_dlychain <= 2'h0;
            lmro_rsel_dlychain <= 2'h0;
            dtcm_rsel_dlychain <= 2'h0;
            l2c_rsel_dlychain <= 2'h0;
            other_rsel_dlychain <= 2'h0;
        end else begin
            lmrw_rsel_dlychain <= {lmrw_rsel_dlychain[0], lmrw_rsel};
            lmro_rsel_dlychain <= {lmro_rsel_dlychain[0], lmro_rsel};
            dtcm_rsel_dlychain <= {dtcm_rsel_dlychain[0], dtcm_rsel};
            l2c_rsel_dlychain <= {l2c_rsel_dlychain[0], l2c_rsel};
            other_rsel_dlychain <= {other_rsel_dlychain[0], ndma_mem_re_i};
        end
    end
    assign ndma_mem_rdata_o = lmrw_rsel_dlychain[1] ? lmrw_lcarb__mem_rdata_i
        : lmro_rsel_dlychain[1] ? lmro_lcarb__mem_rdata_i
        : dtcm_rsel_dlychain[1] ? dtcm_lcarb__mem_rdata_i
        : l2c_rsel_dlychain[1] ? l2c_lcarb__mem_rsp_i.rdata
        : 256'h0;
    assign ndma_mem_rdata_act_o = lmrw_rsel_dlychain[1] ? lmrw_lcarb__mem_rdata_act_i
        : lmro_rsel_dlychain[1] ? lmro_lcarb__mem_rdata_act_i
        : dtcm_rsel_dlychain[1] ? dtcm_lcarb__mem_rdata_act_i
        : l2c_rsel_dlychain[1] ? l2c_lcarb__mem_rsp_i.rdata_act
        : other_rsel_dlychain[1];
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ndma_tx_done_id <= ndma_id_t'(0);
            ndma_tx_done <= 1'b0;
            ndma_rx_done_id <= ndma_id_t'(0);
            ndma_rx_done <= 1'b0;
        end else begin
            ndma_tx_done_id <= ndma_tx_done_id_i;
            ndma_tx_done <= ndma_tx_done_i;
            ndma_rx_done_id <= ndma_rx_done_id_i;
            ndma_rx_done <= ndma_rx_done_i;
        end
    end
    assign tx_id = ndma_id_t'(ndma_tx_done_id[9:0]);
    assign rx_id = ndma_id_t'(ndma_rx_done_id[9:0]);
    assign mst_tx_done = (tx_id.hpu_id == csr_hpu_id_i) && ndma_tx_done;
    assign mst_rx_done = (rx_id.hpu_id == csr_hpu_id_i) && ndma_rx_done;
    assign lcarb_l2c__cmd_done_o =
        (tx_id.cls && tx_id.cmd == 2'h0 && mst_tx_done)
        || (rx_id.cls && rx_id.cmd == 2'h1 && mst_rx_done)
        || (rx_id.cls && rx_id.cmd == 2'h2 && mst_rx_done);
    assign csr_cmd_done =
        (!tx_id.cls && tx_id.cmd == 2'h0 && mst_tx_done)
        || (!rx_id.cls && rx_id.cmd == 2'h1 && mst_rx_done)
        || (!rx_id.cls && rx_id.cmd == 2'h2 && mst_rx_done);
    assign csr_cmd_index = mst_tx_done ? tx_id.index : rx_id.index;
    assign slv_tx_done = !tx_id.cls && (tx_id.hpu_id != csr_hpu_id_i) && ndma_tx_done;
    assign slv_rx_done = !rx_id.cls && (rx_id.hpu_id != csr_hpu_id_i) && ndma_rx_done;
    assign slv_wr_done = slv_rx_done && (rx_id.cmd == 2'h0);
    assign slv_wr_index = rx_id.hpu_id;
    assign slv_rd_done = slv_tx_done && (rx_id.cmd == 2'h1);
    assign slv_rd_index = tx_id.hpu_id;
    assign slv_swap_done = slv_tx_done && (rx_id.cmd == 2'h2);
    assign slv_swap_index = tx_id.hpu_id;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<16; i=i+1) begin
                slv_wr_done_vec[i] <= 1'b0;
                slv_rd_done_vec[i] <= 1'b0;
                slv_swap_done_vec[i] <= 1'b0;
            end
        end else begin
            for(integer i=0; i<16; i=i+1) begin
                if(slv_wr_done && (slv_wr_index == i)) begin
                    slv_wr_done_vec[i] <= 1'b1;
                end
                if(slv_rd_done && (slv_rd_index == i)) begin
                    slv_rd_done_vec[i] <= 1'b1;
                end
                if(slv_swap_done && (slv_swap_index == i)) begin
                    slv_swap_done_vec[i] <= 1'b1;
                end
                if(csr_ndma_wr_clr_vld && csr_ndma_wr_clr[i]) begin
                    slv_wr_done_vec[i] <= 1'b0;
                end
                if(csr_ndma_rd_clr_vld && csr_ndma_rd_clr[i]) begin
                    slv_rd_done_vec[i] <= 1'b0;
                end
                if(csr_ndma_swap_clr_vld && csr_ndma_swap_clr[i]) begin
                    slv_swap_done_vec[i] <= 1'b0;
                end
            end
        end
    end
    assign lcarb_clint__ndma_intr_o = |csr_done_vec;
    assign lcarb_clint__slv_wr_intr_o = |(slv_wr_done_vec & ~csr_ndma_wr_mask);
    assign lcarb_clint__slv_rd_intr_o = |(slv_rd_done_vec & ~csr_ndma_rd_mask);
    assign lcarb_clint__slv_swap_intr_o = |(slv_swap_done_vec & ~csr_ndma_swap_mask);
endmodule : hpu_lcarb
