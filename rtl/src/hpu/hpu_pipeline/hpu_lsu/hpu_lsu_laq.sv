`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_lsu_laq (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   flush_en_i,
    input   update_ckpt_t                           ckpt_rcov_i,
    input   ckpt_t                                  id__prefet_ckpt_i,
    input   logic                                   laq_cmd_ins_i,
    input   laq_item_t                              laq_cmd_i,
    output  logic                                   laq_full_o,
    output  logic[LAQ_INDEX-1 : 0]                  laq_ins_index_o,
    output  lsu_commit_t                            lsu_rob__ld_commit_o,
    output  awake_index_t                           laq_awake_o,
    output  phy_sr_index_t                          lsu_prf__rdst_index_o,
    output  logic                                   lsu_prf__rdst_en_o,
    output  data_t                                  lsu_prf__rdst_data_o,
    input   pc_t                                    chk_dpend_addr_i,
    input   data_strobe_t                           chk_dpend_strb_i,
    input   lsu_acc_type_e                          chk_dpend_type_i,
    output  logic                                   ld_dpend_avail_o,
    output  logic[LAQ_INDEX-1 : 0]                  ld_dpend_index_o,
    input   logic                                   rmv_sq_dpend_en_i,
    input   logic[SQ_INDEX-1 : 0]                   rmv_sq_dpend_index_i,
    output  logic                                   update_sq_en_o,
    output  logic[SQ_INDEX-1 : 0]                   update_sq_index_o,
    output  data_t                                  update_sq_data_o,
    input   logic                                   awake_amo_en_i,
    input   logic[LAQ_INDEX-1 : 0]                  awake_amo_index_i,
    output  logic                                   acqlock_amo_en_o,
    output  logic[LAQ_INDEX-1 : 0]                  acqlock_amo_index_o,
    input   logic                                   delete_order_en_i,
    input   logic[LAQ_INDEX-1 : 0]                  delete_order_index_i,
    output  logic                                   shortcut_en_o,
    output  logic[SQ_INDEX-1 : 0]                   shortcut_index_o,
    input   logic                                   shortcut_rd_suc_i,
    input   data_t                                  shortcut_rdata_i,
    output  mem_rd_req_t                            lsu_mem__rd_req_o,
    input   mem_rd_rsp_t                            mem_lsu__rd_rsp_i,
    output  logic                                   lsu_csr__rd_en_o,
    output  csr_addr_t                              lsu_csr__raddr_o,
    input   data_t                                  csr_lsu__rdata_i
);
    laq_item_t                              lsu_laq[LAQ_LEN-1 : 0];
    logic                                   lsu_laq_exec_v[LAQ_LEN-1 : 0];
    logic                                   lsu_laq_order_v[LAQ_LEN-1 : 0];
    logic                                   lsu_laq_amo_rdy[LAQ_LEN-1 : 0];
    logic[2 : 0]                            lsu_laq_busy[LAQ_LEN-1 : 0];
    laq_item_t                              lsu_laq_ins[LAQ_LEN-1 : 0];
    logic                                   lsu_laq_exec_v_ins[LAQ_LEN-1 : 0];
    logic                                   lsu_laq_order_v_ins[LAQ_LEN-1 : 0];
    logic                                   lsu_laq_amo_rdy_ins[LAQ_LEN-1 : 0];
    logic[2 : 0]                            lsu_laq_busy_ins[LAQ_LEN-1 : 0];
    laq_item_t                              lsu_laq_comb[LAQ_LEN-1 : 0];
    logic                                   lsu_laq_exec_v_comb[LAQ_LEN-1 : 0];
    logic                                   lsu_laq_order_v_comb[LAQ_LEN-1 : 0];
    logic                                   lsu_laq_amo_rdy_comb[LAQ_LEN-1 : 0];
    logic[2 : 0]                            lsu_laq_busy_comb[LAQ_LEN-1 : 0];
    logic                                   lsu_laq_empty;
    logic                                   lsu_laq_full;
    logic                                   ins_flag, ins_flag_comb;
    logic[LAQ_INDEX-1 : 0]                  ins_index, ins_index_comb;
    logic                                   rcov_flag;
    logic[LAQ_INDEX-1 : 0]                  rcov_index;
    logic                                   del_flag, del_flag_comb;
    logic[LAQ_INDEX-1 : 0]                  del_index, del_index_comb;
    logic                                   sel_en, sel_en_comb;
    logic[LAQ_INDEX-1 : 0]                  sel_index, sel_index_comb;
    logic                                   ld_cmd_en;
    laq_item_t                              ld_cmd_mem;
    logic                                   ld_cmd_en_dly1;
    logic[LAQ_INDEX-1 : 0]                  sel_index_mem;
    logic                                   ld_cmd_en_mem;
    logic                                   ld_cmd_suc;
    laq_item_t                              ld_cmd_mem1;
    logic                                   ld_cmd_suc_dly1;
    logic                                   ld_cmd_suc_mem1;
    data_t                                  rdata_mem1;
    laq_item_t                              ld_cmd_wb;
    logic                                   ld_cmd_suc_mem1_dly1;
    data_t                                  rdata_wb;
    logic                                   ld_cmd_suc_wb;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<LAQ_LEN; i=i+1) begin
                lsu_laq[i] <= laq_item_t'(0);
                lsu_laq_exec_v[i] <= 1'b0;
                lsu_laq_order_v[i] <= 1'b0;
                lsu_laq_amo_rdy[i] <= 1'b0;
                lsu_laq_busy[i] <= 3'h0;
            end
        end else begin
            lsu_laq <= lsu_laq_comb;
            lsu_laq_exec_v <= lsu_laq_exec_v_comb;
            lsu_laq_order_v <= lsu_laq_order_v_comb;
            lsu_laq_amo_rdy <= lsu_laq_amo_rdy_comb;
            lsu_laq_busy <= lsu_laq_busy_comb;
        end
    end
    always_comb begin
        lsu_laq_ins = lsu_laq;
        lsu_laq_exec_v_ins = lsu_laq_exec_v;
        lsu_laq_order_v_ins = lsu_laq_order_v;
        lsu_laq_amo_rdy_ins = lsu_laq_amo_rdy;
        lsu_laq_busy_ins = lsu_laq_busy;
        if(laq_cmd_ins_i) begin
            lsu_laq_ins[ins_index] = laq_cmd_i;
            lsu_laq_exec_v_ins[ins_index] = (laq_cmd_i.ld_type != LAQ_FENCE);
            lsu_laq_order_v_ins[ins_index] = (laq_cmd_i.ld_type == LAQ_AMO) || (laq_cmd_i.ld_type == LAQ_FENCE);
            lsu_laq_amo_rdy_ins[ins_index] = 1'b0;
            lsu_laq_busy_ins[ins_index] = 3'h0;
        end
    end
    always_comb begin
        lsu_laq_comb = lsu_laq_ins;
        lsu_laq_exec_v_comb = lsu_laq_exec_v_ins;
        lsu_laq_order_v_comb = lsu_laq_order_v_ins;
        lsu_laq_amo_rdy_comb = lsu_laq_amo_rdy_ins;
        lsu_laq_busy_comb = lsu_laq_busy_ins;
        for(integer i=0; i<LAQ_LEN; i=i+1) begin
            if(sel_en_comb && (i == sel_index_comb)) begin
                lsu_laq_busy_comb[i] = 3'h7;
            end else if(lsu_laq_busy_ins[i] == 3'h0) begin
                lsu_laq_busy_comb[i] = 3'h0;
            end else begin
                lsu_laq_busy_comb[i] = lsu_laq_busy_ins[i] - 1'b1;
            end
            if(rmv_sq_dpend_en_i && (rmv_sq_dpend_index_i == lsu_laq_ins[i].st_dpend_index)) begin
                lsu_laq_comb[i].st_dpend_avail = 1'b0;
            end
            if(update_sq_en_o && (update_sq_index_o == lsu_laq_ins[i].st_dpend_index)) begin
                lsu_laq_comb[i].st_dpend_fwd = 1'b1;
            end
            if(ld_cmd_suc && (i == sel_index_mem)) begin
                lsu_laq_exec_v_comb[i] = 1'b0;
            end
            if(ld_cmd_suc && (sel_index_mem == lsu_laq_ins[i].ld_dpend_index)) begin
                lsu_laq_comb[i].ld_dpend_avail = 1'b0;
            end
            if(awake_amo_en_i && (i == awake_amo_index_i)) begin
                lsu_laq_amo_rdy_comb[i] = 1'b1;
            end
            if(delete_order_en_i && (i == delete_order_index_i)) begin
                lsu_laq_order_v_comb[i] = 1'b0;
            end
        end
    end
    assign lsu_laq_empty = {ins_flag, ins_index} == {del_flag, del_index};
    assign lsu_laq_full = {ins_flag, ins_index} == {~del_flag, del_index};
    assign laq_full_o = lsu_laq_full;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            {ins_flag, ins_index} <= {(LAQ_INDEX+1){1'b0}};
        end else begin
            {ins_flag, ins_index} <= {ins_flag_comb, ins_index_comb};
        end
    end
    assign laq_ins_index_o = ins_index;
    always_comb begin
        {ins_flag_comb, ins_index_comb} = {ins_flag, ins_index};
        if(flush_en_i) begin
            {ins_flag_comb, ins_index_comb} = {del_flag_comb, del_index_comb};
        end else if(ckpt_rcov_i.en) begin
            {ins_flag_comb, ins_index_comb} = {rcov_flag, rcov_index};
        end else if(laq_cmd_ins_i) begin
            {ins_flag_comb, ins_index_comb} = {ins_flag, ins_index} + 1'b1;
        end
    end
    always_comb begin
        if(laq_cmd_ins_i && !chk_ckpt(laq_cmd_i.ckpt, ckpt_rcov_i.ckpt, id__prefet_ckpt_i)) begin
            {rcov_flag, rcov_index} = {ins_flag, ins_index} + 1'b1;
        end else begin
            {rcov_flag, rcov_index} = {ins_flag, ins_index};
        end
        for(integer i=LAQ_LEN*2-1; i>=0; i=i-1) begin
            if( (i >= {1'b0, del_index_comb}) && (i < {ins_flag^del_flag_comb, ins_index})
            &&  (chk_ckpt(lsu_laq[i[LAQ_INDEX-1 : 0]].ckpt, ckpt_rcov_i.ckpt, id__prefet_ckpt_i))
            ) begin
                {rcov_flag, rcov_index} = {i[LAQ_INDEX]^del_flag_comb, i[LAQ_INDEX-1 : 0]};
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            {del_flag, del_index} <= {(LAQ_INDEX+1){1'b0}};
        end else begin
            {del_flag, del_index} <= {del_flag_comb, del_index_comb};
        end
    end
    always_comb begin
        {del_flag_comb, del_index_comb} = {del_flag, del_index};
        if(!(lsu_laq_exec_v[del_index] || lsu_laq_order_v[del_index]) && !lsu_laq_empty) begin
            {del_flag_comb, del_index_comb} = {del_flag, del_index} + 1'b1;
        end
    end
    always_comb begin
        ld_dpend_avail_o = 1'b0;
        ld_dpend_index_o = {LAQ_INDEX{1'b0}};
        for(integer i=0; i<LAQ_LEN*2; i=i+1) begin
            if( (i >= {1'b0, del_index}) && (i < {del_flag^ins_flag, ins_index})
            &&  (lsu_laq_exec_v[i[LAQ_INDEX-1 : 0]])
            &&  (lsu_laq[i[LAQ_INDEX-1 : 0]].ld_type != LAQ_FENCE)
            &&  (  ((lsu_laq[i[LAQ_INDEX-1 : 0]].ld_type == LAQ_CSR) && (chk_dpend_type_i == ACC_CSR))
                || ((lsu_laq[i[LAQ_INDEX-1 : 0]].ld_type != LAQ_CSR) && (chk_dpend_type_i != ACC_CSR)))
            &&  (lsu_laq[i[LAQ_INDEX-1 : 0]].addr[PC_WTH-1 : 2] == chk_dpend_addr_i[PC_WTH-1 : 2])
            &&  ((lsu_laq[i[LAQ_INDEX-1 : 0]].strb & chk_dpend_strb_i)  != 0)
            ) begin
                ld_dpend_avail_o = 1'b1;
                ld_dpend_index_o = i[LAQ_INDEX-1 : 0];
            end
        end
    end
    always_comb begin
        sel_en_comb = 1'b0;
        sel_index_comb = {LAQ_INDEX{1'b0}};
        for(integer i=LAQ_LEN*2-1; i>=0; i=i-1) begin
            if((i >= {1'b0, del_index}) && (i < {ins_flag^del_flag, ins_index})) begin
                if(lsu_laq_order_v[i[LAQ_INDEX-1:0]] && lsu_laq[i[LAQ_INDEX-1:0]].order_succ) begin
                    sel_en_comb = 1'b0;
                end
                if((lsu_laq_exec_v[i[LAQ_INDEX-1:0]])
                && (lsu_laq_busy[i[LAQ_INDEX-1:0]] == 3'h0)
                && (!(lsu_laq_order_v[i[LAQ_INDEX-1:0]]&&lsu_laq[i[LAQ_INDEX-1:0]].order_pred)
                    || (LAQ_INDEX'(i)==del_index))
                && (lsu_laq[i[LAQ_INDEX-1:0]].ld_type != LAQ_AMO || lsu_laq_amo_rdy[i[LAQ_INDEX-1:0]])
                && (!lsu_laq[i[LAQ_INDEX-1:0]].st_dpend_avail || lsu_laq[i[LAQ_INDEX-1:0]].st_dpend_fwd)
                && (!lsu_laq[i[LAQ_INDEX-1:0]].ld_dpend_avail)
                ) begin
                    sel_en_comb = 1'b1;
                    sel_index_comb = i[LAQ_INDEX-1 : 0];
                end
            end
        end
        if(flush_en_i
            || (ckpt_rcov_i.en && chk_ckpt(lsu_laq[sel_index_comb].ckpt, ckpt_rcov_i.ckpt, id__prefet_ckpt_i))) begin
            sel_en_comb = 1'b0;
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            sel_en <= 1'b0;
            sel_index <= {LAQ_INDEX{1'b0}};
        end else begin
            sel_en <= sel_en_comb;
            sel_index <= sel_index_comb;
        end
    end
    assign ld_cmd_en = sel_en
        && !flush_en_i
        && !(ckpt_rcov_i.en && chk_ckpt(lsu_laq[sel_index].ckpt, ckpt_rcov_i.ckpt, id__prefet_ckpt_i));
    always_comb begin
        shortcut_en_o = 1'b0;
        shortcut_index_o = lsu_laq[sel_index].st_dpend_index;
        lsu_mem__rd_req_o.rd_en = 1'b0;
        lsu_mem__rd_req_o.raddr = {lsu_laq[sel_index].addr[PC_WTH-1 : 2], 2'h0};
        lsu_mem__rd_req_o.aq_lock = (lsu_laq[sel_index].ld_type == LAQ_AMO);
        lsu_csr__rd_en_o = 1'b0;
        lsu_csr__raddr_o = lsu_laq[sel_index].addr[CSR_ADDR_WTH+1 : 2];
        if(ld_cmd_en) begin
            if(lsu_laq[sel_index].st_dpend_avail) begin
                shortcut_en_o = 1'b1;
            end else if(lsu_laq[sel_index].ld_type == LAQ_CSR) begin
                lsu_csr__rd_en_o = 1'b1;
            end else begin
                lsu_mem__rd_req_o.rd_en = 1'b1;
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ld_cmd_mem <= laq_item_t'(0);
            ld_cmd_en_dly1 <= 1'b0;
            sel_index_mem <= {LAQ_INDEX{1'b0}};
        end else begin
            ld_cmd_mem <= lsu_laq[sel_index];
            ld_cmd_en_dly1 <= ld_cmd_en;
            sel_index_mem <= sel_index;
        end
    end
    assign ld_cmd_en_mem = ld_cmd_en_dly1
        && !flush_en_i
        && !(ckpt_rcov_i.en && chk_ckpt(ld_cmd_mem.ckpt, ckpt_rcov_i.ckpt, id__prefet_ckpt_i));
    always_comb begin
        if(ld_cmd_mem.st_dpend_avail) begin
            ld_cmd_suc = ld_cmd_en_mem && shortcut_rd_suc_i;
        end else if(ld_cmd_mem.ld_type == LAQ_CSR) begin
            ld_cmd_suc = ld_cmd_en_mem;
        end else begin
            ld_cmd_suc = ld_cmd_en_mem && mem_lsu__rd_rsp_i.rd_suc;
        end
    end
    assign acqlock_amo_en_o = (ld_cmd_mem.ld_type == LAQ_AMO) && ld_cmd_en_mem;
    assign acqlock_amo_index_o = ld_cmd_mem.crsp_sq_index;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ld_cmd_mem1 <= laq_item_t'(0);
            ld_cmd_suc_dly1 <= 1'b0;
        end else begin
            ld_cmd_mem1 <= ld_cmd_mem;
            ld_cmd_suc_dly1 <= ld_cmd_suc;
        end
    end
    assign ld_cmd_suc_mem1 = ld_cmd_suc_dly1
        && !flush_en_i
        && !(ckpt_rcov_i.en && chk_ckpt(ld_cmd_mem1.ckpt, ckpt_rcov_i.ckpt, id__prefet_ckpt_i));
    always_comb begin
        if(ld_cmd_mem1.st_dpend_avail) begin
            rdata_mem1 = shortcut_rdata_i;
        end else if(ld_cmd_mem1.ld_type == LAQ_CSR) begin
            rdata_mem1 = csr_lsu__rdata_i;
        end else begin
            rdata_mem1 = mem_lsu__rd_rsp_i.rdata;
        end
    end
    assign laq_awake_o.en = ld_cmd_suc_mem1;
    assign laq_awake_o.rdst_index = ld_cmd_mem1.phy_rdst_index;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ld_cmd_wb <= laq_item_t'(0);
            ld_cmd_suc_mem1_dly1 <= 1'b0;
            rdata_wb <= data_t'(0);
        end else begin
            ld_cmd_wb <= ld_cmd_mem1;
            ld_cmd_suc_mem1_dly1 <= ld_cmd_suc_mem1;
            rdata_wb <= rdata_mem1;
        end
    end
    assign ld_cmd_suc_wb = ld_cmd_suc_mem1_dly1
        && !flush_en_i
        && !(ckpt_rcov_i.en && chk_ckpt(ld_cmd_wb.ckpt, ckpt_rcov_i.ckpt, id__prefet_ckpt_i));
    always_comb begin
        lsu_prf__rdst_index_o = ld_cmd_wb.phy_rdst_index;
        lsu_prf__rdst_en_o = ld_cmd_suc_wb && (ld_cmd_wb.phy_rdst_index != phy_sr_index_t'(0));
        lsu_prf__rdst_data_o = data_t'(0);
        case(ld_cmd_wb.ld_size)
            BYTE: begin
                case(ld_cmd_wb.addr[1:0])
                    2'b00: lsu_prf__rdst_data_o = ld_cmd_wb.is_unsigned ? data_t'(rdata_wb[7:0])
                        : data_t'({{(DATA_WTH-8){rdata_wb[7]}}, rdata_wb[7:0]});
                    2'b01: lsu_prf__rdst_data_o = ld_cmd_wb.is_unsigned ? data_t'(rdata_wb[15:8])
                        : data_t'({{(DATA_WTH-8){rdata_wb[15]}}, rdata_wb[15:8]});
                    2'b10: lsu_prf__rdst_data_o = ld_cmd_wb.is_unsigned ? data_t'(rdata_wb[23:16])
                        : data_t'({{(DATA_WTH-8){rdata_wb[23]}}, rdata_wb[23:16]});
                    2'b11: lsu_prf__rdst_data_o = ld_cmd_wb.is_unsigned ? data_t'(rdata_wb[31:24])
                        : data_t'({{(DATA_WTH-8){rdata_wb[31]}}, rdata_wb[31:24]});
                endcase
            end
            HALF: begin
                case(ld_cmd_wb.addr[1:0])
                    2'b00: lsu_prf__rdst_data_o = ld_cmd_wb.is_unsigned ? data_t'(rdata_wb[15:0])
                        : data_t'({{(DATA_WTH-16){rdata_wb[15]}}, rdata_wb[15:0]});
                    2'b01: lsu_prf__rdst_data_o = ld_cmd_wb.is_unsigned ? data_t'(rdata_wb[23:8])
                        : data_t'({{(DATA_WTH-16){rdata_wb[23]}}, rdata_wb[23:8]});
                    2'b10: lsu_prf__rdst_data_o = ld_cmd_wb.is_unsigned ? data_t'(rdata_wb[31:16])
                        : data_t'({{(DATA_WTH-16){rdata_wb[31]}}, rdata_wb[31:16]});
                endcase
            end
            WORD: begin
                lsu_prf__rdst_data_o = rdata_wb;
            end
        endcase
    end
    assign update_sq_en_o = (ld_cmd_wb.ld_type == LAQ_AMO || ld_cmd_wb.ld_type == LAQ_CSR) && ld_cmd_suc_wb
        && ld_cmd_wb.crsp_sq_avail;
    assign update_sq_index_o = ld_cmd_wb.crsp_sq_index;
    assign update_sq_data_o = lsu_prf__rdst_data_o;
    always_comb begin
        lsu_rob__ld_commit_o.en = ld_cmd_suc_wb && (ld_cmd_wb.ld_type != LAQ_FENCE);
        lsu_rob__ld_commit_o.rob_index = ld_cmd_wb.rob_index;
        lsu_rob__ld_commit_o.rob_offset = ld_cmd_wb.rob_offset;
        lsu_rob__ld_commit_o.excp_en = 1'b0;
        lsu_rob__ld_commit_o.excp = INST_ADDR_MISALIGNED;
        lsu_rob__ld_commit_o.is_ldst = (ld_cmd_wb.ld_type == LAQ_LD);
        lsu_rob__ld_commit_o.ldst_addr = ld_cmd_wb.addr;
        lsu_rob__ld_commit_o.ldst_data = lsu_prf__rdst_data_o;
    end
endmodule : hpu_lsu_laq
