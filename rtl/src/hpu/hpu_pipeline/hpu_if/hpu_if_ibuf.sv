`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_if_ibuf (
    input  logic                                    clk_i,
    input  logic                                    rst_i,
    input  logic                                    flush_en_i,
    input  if_inst_t[IBUF_PARAL-1 : 0]              ibuf_inst_i,
    input  logic[IBUF_PARAL-1 : 0]                  ibuf_inst_en_i,
    output logic                                    ibuf_afull_o,
    output if_inst_t                                if_id__inst_o,
    output logic                                    if_id__inst_vld_o,
    input  logic                                    id_if__inst_rdy_i
);
    logic                                   sel0, sel1;
    if_inst_t                               ibuf_wr_data[IBUF_PARAL-1 : 0];
    logic[IBUF_INDEX-1 : 0]                 ibuf_wr_addr[IBUF_PARAL-1 : 0];
    logic                                   ibuf_wr_en[IBUF_PARAL-1 : 0];
    logic[1 : 0]                            ibuf_wr_num;
    if_inst_t[IBUF_PARAL-1 : 0]             ibuf[IBUF_LEN-1 : 0];
    logic                                   ibuf_wr_flag;
    logic[IBUF_INDEX-1 : 0]                 ibuf_wr_index;
    logic                                   ibuf_wr_offset;
    logic                                   ibuf_rd_flag;
    logic[IBUF_INDEX-1 : 0]                 ibuf_rd_index;
    logic                                   ibuf_rd_offset;
    logic                                   ibuf_empty;
    logic[IBUF_INDEX+1 : 0]                 ibuf_left_size;
    assign sel0 = !(ibuf_inst_en_i[0] ^ ibuf_wr_offset);
    assign sel1 = !sel0;
    always_comb begin
        ibuf_wr_data[0] = sel0 ? ibuf_inst_i[1] : ibuf_inst_i[0];
        ibuf_wr_data[1] = sel1 ? ibuf_inst_i[1] : ibuf_inst_i[0];
        ibuf_wr_addr[0] = ibuf_wr_offset ? ibuf_wr_index+1'b1 : ibuf_wr_index;
        ibuf_wr_addr[1] = ibuf_wr_index;
        ibuf_wr_en[0] = ibuf_wr_offset ? &ibuf_inst_en_i : |ibuf_inst_en_i;
        ibuf_wr_en[1] = ibuf_wr_offset ? |ibuf_inst_en_i : &ibuf_inst_en_i;
        ibuf_wr_num = ibuf_inst_en_i[0] + ibuf_inst_en_i[1];
    end
    for(genvar gi=0; gi<IBUF_PARAL; gi=gi+1) begin : ibuf_inter
        always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
            if(`RST_TRUE(rst_i)) begin
                for(integer j=0; j<IBUF_LEN; j=j+1) begin
                    ibuf[j][gi] <= if_inst_t'(0);
                end
            end else begin
                if(ibuf_wr_en[gi]) begin
                    ibuf[ibuf_wr_addr[gi]][gi] <= ibuf_wr_data[gi];
                end
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ibuf_wr_flag <= 1'b0;
            ibuf_wr_index <= {IBUF_INDEX{1'b0}};
            ibuf_wr_offset <= 1'b0;
        end else begin
            if(flush_en_i) begin
                {ibuf_wr_flag, ibuf_wr_index, ibuf_wr_offset} <= (IBUF_INDEX+2)'(0);
            end else begin
                {ibuf_wr_flag, ibuf_wr_index, ibuf_wr_offset} <= {ibuf_wr_flag, ibuf_wr_index, ibuf_wr_offset}
                    + {{IBUF_INDEX{1'b0}}, ibuf_wr_num};
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ibuf_rd_flag <= 1'b0;
            ibuf_rd_index <= {IBUF_INDEX{1'b0}};
            ibuf_rd_offset <= 1'b0;
        end else begin
            if(flush_en_i) begin
                {ibuf_rd_flag, ibuf_rd_index, ibuf_rd_offset} <= {(IBUF_INDEX+2){1'b0}};
            end else if(if_id__inst_vld_o && id_if__inst_rdy_i) begin
                {ibuf_rd_flag, ibuf_rd_index, ibuf_rd_offset} <= {ibuf_rd_flag, ibuf_rd_index, ibuf_rd_offset} + 1'b1;
            end
        end
    end
    assign ibuf_empty = {ibuf_rd_flag, ibuf_rd_index, ibuf_rd_offset} == {ibuf_wr_flag, ibuf_wr_index, ibuf_wr_offset};
    assign ibuf_left_size = {1'b1, ibuf_rd_index, ibuf_rd_offset}
                          - {ibuf_rd_flag^ibuf_wr_flag, ibuf_wr_index, ibuf_wr_offset};
    assign ibuf_afull_o = (ibuf_left_size <= 2*IBUF_PARAL + 1);
    assign if_id__inst_vld_o = !ibuf_empty;
    assign if_id__inst_o = ibuf[ibuf_rd_index][ibuf_rd_offset];
    pc_t[IBUF_PARAL-1 : 0] prb_ibuf_pc[IBUF_LEN-1 : 0];
    logic[IBUF_PARAL-1 : 0] prb_ibuf_avail[IBUF_LEN-1 : 0];
    always_comb begin
        for(integer i=0; i<IBUF_LEN; i++) begin
            for(integer j=0; j<IBUF_PARAL; j++) begin
                prb_ibuf_pc[i][j] = ibuf[i][j].cur_pc;
                if(ibuf_rd_flag == ibuf_wr_flag) begin
                    prb_ibuf_avail[i][j] = |ibuf[i][j].avail && (i*IBUF_PARAL+j >= {ibuf_rd_index,ibuf_rd_offset})
                        && (i*IBUF_PARAL+j < {ibuf_wr_index, ibuf_wr_offset});
                end else begin
                    prb_ibuf_avail[i][j] = |ibuf[i][j].avail && ((i*IBUF_PARAL+j >= {ibuf_rd_index,ibuf_rd_offset})
                        || (i*IBUF_PARAL+j < {ibuf_wr_index, ibuf_wr_offset}));
                end
            end
        end
    end
endmodule : hpu_if_ibuf
