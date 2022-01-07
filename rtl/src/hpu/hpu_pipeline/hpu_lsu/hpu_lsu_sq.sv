`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_lsu_sq (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   flush_en_i,
    input   update_ckpt_t                           ckpt_rcov_i,
    output  logic                                   lsu_ctrl__sq_retire_empty_o,
    input   ckpt_t                                  id__prefet_ckpt_i,
    input   logic                                   sq_cmd_ins_i,
    input   sq_item_t                               sq_cmd_i,
    output  logic                                   sq_full_o,
    output  logic[SQ_INDEX-1 : 0]                   sq_ins_index_o,
    input   lsu_retire_t                            rob_lsu__st_retire_i,
    input   pc_t                                    chk_dpend_addr_i,
    input   data_strobe_t                           chk_dpend_strb_i,
    input   lsu_acc_type_e                          chk_dpend_type_i,
    output  logic                                   st_dpend_avail_o,
    output  logic[SQ_INDEX-1 : 0]                   st_dpend_index_o,
    output  logic                                   st_dpend_fwd_o,
    output  logic                                   rmv_sq_dpend_en_o,
    output  logic[SQ_INDEX-1 : 0]                   rmv_sq_dpend_index_o,
    input   logic                                   update_sq_en_i,
    input   logic[SQ_INDEX-1 : 0]                   update_sq_index_i,
    input   data_t                                  update_sq_data_i,
    output  logic                                   awake_amo_en_o,
    output  logic[LAQ_INDEX-1 : 0]                  awake_amo_index_o,
    input   logic                                   acqlock_amo_en_i,
    input   logic[LAQ_INDEX-1 : 0]                  acqlock_amo_index_i,
    output  logic                                   delete_order_en_o,
    output  logic[LAQ_INDEX-1 : 0]                  delete_order_index_o,
    input   logic                                   shortcut_en_i,
    input   logic[SQ_INDEX-1 : 0]                   shortcut_index_i,
    output  logic                                   shortcut_rd_suc_o,
    output  data_t                                  shortcut_rdata_o,
    output  mem_wr_req_t                            lsu_mem__wr_req_o,
    input   mem_wr_rsp_t                            mem_lsu__wr_rsp_i,
    output  logic                                   lsu_csr__wr_en_o,
    output  csr_addr_t                              lsu_csr__waddr_o,
    output  data_t                                  lsu_csr__wdata_o,
    output  data_strobe_t                           lsu_csr__wstrb_o
);
    sq_item_t                               lsu_sq[SQ_LEN-1 : 0];
    logic                                   lsu_sq_exec_v[SQ_LEN-1 : 0];
    logic                                   lsu_sq_order_v[SQ_LEN-1 : 0];
    logic                                   lsu_sq_amo_rdy[SQ_LEN-1 : 0];
    logic                                   lsu_sq_amo_lock[SQ_LEN-1 : 0];
    logic[2 : 0]                            lsu_sq_busy[SQ_LEN-1 : 0];
    sq_item_t                               lsu_sq_ins[SQ_LEN-1 : 0];
    logic                                   lsu_sq_exec_v_ins[SQ_LEN-1 : 0];
    logic                                   lsu_sq_order_v_ins[SQ_LEN-1 : 0];
    logic                                   lsu_sq_amo_rdy_ins[SQ_LEN-1 : 0];
    logic                                   lsu_sq_amo_lock_ins[SQ_LEN-1 : 0];
    logic[2 : 0]                            lsu_sq_busy_ins[SQ_LEN-1 : 0];
    sq_item_t                               lsu_sq_comb[SQ_LEN-1 : 0];
    logic                                   lsu_sq_exec_v_comb[SQ_LEN-1 : 0];
    logic                                   lsu_sq_order_v_comb[SQ_LEN-1 : 0];
    logic                                   lsu_sq_amo_rdy_comb[SQ_LEN-1 : 0];
    logic                                   lsu_sq_amo_lock_comb[SQ_LEN-1 : 0];
    logic[2 : 0]                            lsu_sq_busy_comb[SQ_LEN-1 : 0];
    logic                                   lsu_sq_empty;
    logic                                   lsu_sq_full;
    logic                                   rt_empty;
    logic                                   ins_flag, ins_flag_comb;
    logic[SQ_INDEX-1 : 0]                   ins_index, ins_index_comb;
    logic                                   rcov_flag;
    logic[SQ_INDEX-1 : 0]                   rcov_index;
    logic                                   rls_lock_en;
    pc_t                                    rls_lock_addr;
    logic                                   rt_flag, rt_flag_comb;
    logic[SQ_INDEX-1 : 0]                   rt_index, rt_index_comb;
    logic[SQ_INDEX-1 : 0]                   awake_sq_index;
    logic                                   del_flag, del_flag_comb;
    logic[SQ_INDEX-1 : 0]                   del_index, del_index_comb;
    logic                                   sel_en, sel_en_comb;
    logic[SQ_INDEX-1 : 0]                   sel_index, sel_index_comb;
    logic                                   rls_lock_en_dly;
    pc_t                                    rls_lock_addr_dly;
    sq_item_t                               st_cmd_mem;
    logic                                   st_cmd_en_mem;
    logic[SQ_INDEX-1 : 0]                   sel_index_mem;
    logic                                   st_cmd_suc;
    logic                                   shortcut_en_mem;
    logic[SQ_INDEX-1 : 0]                   shortcut_index_mem;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<SQ_LEN; i=i+1) begin
                lsu_sq[i] <= sq_item_t'(0);
                lsu_sq_exec_v[i] <= 1'b0;
                lsu_sq_order_v[i] <= 1'b0;
                lsu_sq_amo_rdy[i] <= 1'b0;
                lsu_sq_amo_lock[i] <= 1'b0;
                lsu_sq_busy[i] <= 3'h0;
            end
        end else begin
            lsu_sq <= lsu_sq_comb;
            lsu_sq_exec_v <= lsu_sq_exec_v_comb;
            lsu_sq_order_v <= lsu_sq_order_v_comb;
            lsu_sq_amo_rdy <= lsu_sq_amo_rdy_comb;
            lsu_sq_amo_lock <= lsu_sq_amo_lock_comb;
            lsu_sq_busy <= lsu_sq_busy_comb;
        end
    end
    always_comb begin
        lsu_sq_ins = lsu_sq;
        lsu_sq_exec_v_ins = lsu_sq_exec_v;
        lsu_sq_order_v_ins = lsu_sq_order_v;
        lsu_sq_amo_rdy_ins = lsu_sq_amo_rdy;
        lsu_sq_amo_lock_ins = lsu_sq_amo_lock;
        lsu_sq_busy_ins = lsu_sq_busy;
        if(sq_cmd_ins_i) begin
            lsu_sq_ins[ins_index] = sq_cmd_i;
            lsu_sq_exec_v_ins[ins_index] = (sq_cmd_i.st_type != SAQ_FENCE);
            lsu_sq_order_v_ins[ins_index] = (sq_cmd_i.st_type == SAQ_FENCE) || (sq_cmd_i.st_type == SAQ_AMO);
            lsu_sq_amo_rdy_ins[ins_index] = 1'b0;
            lsu_sq_amo_lock_ins[ins_index] = 1'b0;
            lsu_sq_busy_ins[ins_index] = 3'h0;
        end
    end
    always_comb begin
        lsu_sq_comb = lsu_sq_ins;
        lsu_sq_exec_v_comb = lsu_sq_exec_v_ins;
        lsu_sq_order_v_comb = lsu_sq_order_v_ins;
        lsu_sq_amo_rdy_comb = lsu_sq_amo_rdy_ins;
        lsu_sq_amo_lock_comb = lsu_sq_amo_lock_ins;
        lsu_sq_busy_comb = lsu_sq_busy_ins;
        for(integer i=0; i<SQ_LEN; i=i+1) begin
            if(sel_en_comb && (i == sel_index_comb)) begin
                lsu_sq_busy_comb[i] = 3'h7;
            end else if(lsu_sq_busy_ins[i] == 3'h0) begin
                lsu_sq_busy_comb[i] = 3'h0;
            end else begin
                lsu_sq_busy_comb[i] = lsu_sq_busy_ins[i] - 1'b1;
            end
            if(st_cmd_suc && (i == sel_index_mem)) begin
                lsu_sq_exec_v_comb[i] = 1'b0;
            end
            if(st_cmd_suc && (sel_index_mem == lsu_sq_ins[i].st_dpend_index)) begin
                lsu_sq_comb[i].st_dpend_avail = 1'b0;
            end
            if(update_sq_en_i && (i == update_sq_index_i)) begin
                lsu_sq_comb[i].data_rdy = 1'b1;
                if(lsu_sq_ins[i].st_type == SAQ_AMO) begin
                    case(lsu_sq_ins[i].atom_func)
                        ATOM_ADD: lsu_sq_comb[i].data = lsu_sq_ins[i].data + update_sq_data_i;
                        ATOM_XOR: lsu_sq_comb[i].data = lsu_sq_ins[i].data ^ update_sq_data_i;
                        ATOM_AND: lsu_sq_comb[i].data = lsu_sq_ins[i].data & update_sq_data_i;
                        ATOM_OR: lsu_sq_comb[i].data = lsu_sq_ins[i].data | update_sq_data_i;
                        ATOM_MAX: lsu_sq_comb[i].data = ($signed(lsu_sq_ins[i].data) > $signed(update_sq_data_i)) ?
                            lsu_sq_ins[i].data : update_sq_data_i;
                        ATOM_MIN: lsu_sq_comb[i].data = ($signed(lsu_sq_ins[i].data) < $signed(update_sq_data_i)) ?
                            lsu_sq_ins[i].data : update_sq_data_i;
                        ATOM_MAXU: lsu_sq_comb[i].data = (lsu_sq_ins[i].data > update_sq_data_i) ?
                            lsu_sq_ins[i].data : update_sq_data_i;
                        ATOM_MINU: lsu_sq_comb[i].data = (lsu_sq_ins[i].data < update_sq_data_i) ?
                            lsu_sq_ins[i].data : update_sq_data_i;
                    endcase
                end else if(lsu_sq_ins[i].st_type == SAQ_CSR) begin
                    case(lsu_sq_ins[i].csr_func)
                        CSR_RS, CSR_RSI: lsu_sq_comb[i].data = lsu_sq_ins[i].data | update_sq_data_i;
                        CSR_RC, CSR_RCI: lsu_sq_comb[i].data = ~lsu_sq_ins[i].data & update_sq_data_i;
                    endcase
                end
            end
            if(awake_amo_en_o && (i == awake_sq_index)) begin
                lsu_sq_amo_rdy_comb[i] = 1'b1;
            end
            if(acqlock_amo_en_i && (i == acqlock_amo_index_i)) begin
                lsu_sq_amo_lock_comb[i] = 1'b1;
            end
            if(delete_order_en_o && (i == del_index)) begin
                lsu_sq_order_v_comb[i] = 1'b0;
            end
        end
    end
    assign lsu_sq_empty = ({ins_flag, ins_index} == {del_flag, del_index});
    assign lsu_sq_full = ({~ins_flag, ins_index} == {del_flag, del_index});
    assign rt_empty = ({del_flag,del_index} == {rt_flag, rt_index});
    assign sq_full_o = lsu_sq_full;
    assign lsu_ctrl__sq_retire_empty_o = rt_empty;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            {ins_flag, ins_index} <= {(SQ_INDEX+1){1'b0}};
        end else begin
            {ins_flag, ins_index} <= {ins_flag_comb, ins_index_comb};
        end
    end
    always_comb begin
        {ins_flag_comb, ins_index_comb} = {ins_flag, ins_index};
        if(flush_en_i) begin
            {ins_flag_comb, ins_index_comb} = {rt_flag_comb, rt_index_comb};
        end else if(ckpt_rcov_i.en) begin
            {ins_flag_comb, ins_index_comb} = {rcov_flag, rcov_index};
        end else if(sq_cmd_ins_i) begin
            {ins_flag_comb, ins_index_comb} = {ins_flag, ins_index} + 1'b1;
        end
    end
    assign sq_ins_index_o = ins_index;
    always_comb begin
        if( sq_cmd_ins_i && !chk_ckpt(sq_cmd_i.ckpt, ckpt_rcov_i.ckpt, id__prefet_ckpt_i) ) begin
            {rcov_flag, rcov_index} = {ins_flag, ins_index} + 1'b1;
        end else begin
            {rcov_flag, rcov_index} = {ins_flag, ins_index};
        end
        for(integer i=SQ_LEN*2-1; i>=0; i=i-1) begin
            if( (i >= {1'b0, rt_index_comb}) && (i < {ins_flag^rt_flag_comb, ins_index})
            &&  (chk_ckpt(lsu_sq[i[SQ_INDEX-1:0]].ckpt, ckpt_rcov_i.ckpt, id__prefet_ckpt_i))
            ) begin
                {rcov_flag, rcov_index} = {i[SQ_INDEX]^rt_flag_comb, i[SQ_INDEX-1 : 0]};
            end
        end
    end
    always_comb begin
        rls_lock_en = 1'b0;
        rls_lock_addr = pc_t'(0);
        for(integer i=SQ_LEN*2-1; i>=0; i=i-1) begin
            if((i >= {1'b0, rt_index}) && (i < {ins_flag^rt_flag, ins_index})
            && (lsu_sq_amo_lock[i[SQ_INDEX-1 : 0]])
            && ((ckpt_rcov_i.en && chk_ckpt(lsu_sq[i[SQ_INDEX-1 : 0]].ckpt, ckpt_rcov_i.ckpt, id__prefet_ckpt_i))
                || flush_en_i)
            ) begin
                rls_lock_en = 1'b1;
                rls_lock_addr = lsu_sq[i[SQ_INDEX-1:0]].addr;
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            {rt_flag, rt_index} <= {(SQ_INDEX+1){1'b0}};
        end else begin
            {rt_flag, rt_index} <= {rt_flag_comb, rt_index_comb};
        end
    end
    always_comb begin
        {rt_flag_comb, rt_index_comb} = {rt_flag, rt_index};
        if(rob_lsu__st_retire_i.en) begin
            {rt_flag_comb, rt_index_comb} = {rt_flag, rt_index}
                + {{(SQ_INDEX-1){1'b0}}, rob_lsu__st_retire_i.rob_rt_sum};
        end
    end
    always_comb begin
        if(lsu_sq_order_v[del_index] && !lsu_sq_amo_rdy[del_index]) begin
            awake_amo_en_o = 1'b1;
            awake_amo_index_o = lsu_sq[del_index].crsp_laq_index;
            awake_sq_index = del_index;
        end else if(lsu_sq_order_v[rt_index] && !lsu_sq[rt_index].order_pred && !lsu_sq_amo_rdy[rt_index]) begin
            awake_amo_en_o = 1'b1;
            awake_amo_index_o = lsu_sq[rt_index].crsp_laq_index;
            awake_sq_index = rt_index;
        end else begin
            awake_amo_en_o = 1'b0;
            awake_amo_index_o = {LAQ_INDEX{1'b0}};
            awake_sq_index = {SQ_INDEX{1'b0}};
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            {del_flag, del_index} <= {(SQ_INDEX+1){1'b0}};
        end else begin
            {del_flag, del_index} <= {del_flag_comb, del_index_comb};
        end
    end
    always_comb begin
        {del_flag_comb, del_index_comb} = {del_flag, del_index};
        if(!lsu_sq_exec_v[del_index] && !rt_empty && !lsu_sq_empty) begin
            {del_flag_comb, del_index_comb} = {del_flag, del_index} + 1'b1;
        end
    end
    always_comb begin
        delete_order_en_o = 1'b0;
        delete_order_index_o = lsu_sq[del_index].crsp_laq_index;
        if(!lsu_sq_exec_v[del_index] && !rt_empty && !lsu_sq_empty) begin
            delete_order_en_o = (lsu_sq[del_index].st_type == SAQ_AMO) || (lsu_sq[del_index].st_type == SAQ_FENCE);
        end
    end
    always_comb begin
        st_dpend_avail_o = 1'b0;
        st_dpend_index_o = {SQ_INDEX{1'b0}};
        st_dpend_fwd_o = 1'b0;
        for(integer i=0; i<SQ_LEN*2; i=i+1) begin
            if( (i >= {1'b0, del_index}) && (i < {del_flag^ins_flag, ins_index})
            &&  (lsu_sq_exec_v[i[SQ_INDEX-1:0]])
            &&  (lsu_sq[i[SQ_INDEX-1:0]].st_type != SAQ_FENCE)
            &&  ( ((lsu_sq[i[SQ_INDEX-1:0]].st_type == SAQ_CSR) && (chk_dpend_type_i == ACC_CSR))
                || ((lsu_sq[i[SQ_INDEX-1:0]].st_type != SAQ_CSR) && (chk_dpend_type_i != ACC_CSR)))
            &&  (lsu_sq[i[SQ_INDEX-1:0]].addr[PC_WTH-1 : 2] == chk_dpend_addr_i[PC_WTH-1 : 2])
            &&  ((lsu_sq[i[SQ_INDEX-1:0]].strb & chk_dpend_strb_i) != 0)
            ) begin
                st_dpend_avail_o = 1'b1;
                st_dpend_index_o = i[SQ_INDEX-1 : 0];
                st_dpend_fwd_o = ((~lsu_sq[i[SQ_INDEX-1:0]].strb & chk_dpend_strb_i) == 0)
                               && lsu_sq[i[SQ_INDEX-1:0]].data_rdy;
            end
        end
    end
    always_comb begin
        sel_en_comb = 1'b0;
        sel_index_comb = {SQ_INDEX{1'b0}};
        for(integer i=SQ_LEN*2-1; i>=0; i=i-1) begin
            if((i >= {1'b0, del_index}) && (i < {del_flag^rt_flag, rt_index})) begin
                if(lsu_sq_order_v[i[SQ_INDEX-1:0]] && lsu_sq[i[SQ_INDEX-1:0]].order_succ) begin
                    sel_en_comb = 1'b0;
                end
                if((lsu_sq_exec_v[i[SQ_INDEX-1:0]])
                && (lsu_sq_busy[i[SQ_INDEX-1:0]] == 3'h0)
                && (!(lsu_sq_order_v[i[SQ_INDEX-1:0]]&&lsu_sq[i[SQ_INDEX-1:0]].order_pred)
                    || (i[SQ_INDEX-1:0]==del_index))
                && (!lsu_sq[i[SQ_INDEX-1:0]].st_dpend_avail)
                && (lsu_sq[i[SQ_INDEX-1:0]].data_rdy)
                ) begin
                    sel_en_comb = 1'b1;
                    sel_index_comb = i[SQ_INDEX-1 : 0];
                end
            end
        end
        if(rls_lock_en) begin
            sel_en_comb = 1'b0;
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            sel_en <= 1'b0;
            sel_index <= {SQ_INDEX{1'b0}};
            rls_lock_en_dly <= 1'b0;
            rls_lock_addr_dly <= pc_t'(0);
        end else begin
            sel_en <= sel_en_comb;
            sel_index <= sel_index_comb;
            rls_lock_en_dly <= rls_lock_en;
            rls_lock_addr_dly <= rls_lock_addr;
        end
    end
    always_comb begin
        lsu_mem__wr_req_o.wr_en = 1'b0;
        lsu_mem__wr_req_o.rl_lock = (lsu_sq[sel_index].st_type == SAQ_AMO);
        lsu_mem__wr_req_o.waddr = {lsu_sq[sel_index].addr[PC_WTH-1 : 2], 2'h0};
        lsu_mem__wr_req_o.wdata = lsu_sq[sel_index].data;
        lsu_mem__wr_req_o.wstrb = lsu_sq[sel_index].strb;
        lsu_csr__wr_en_o = 1'b0;
        lsu_csr__waddr_o = lsu_sq[sel_index].addr[CSR_ADDR_WTH+1 : 2];
        lsu_csr__wdata_o = lsu_sq[sel_index].data;
        lsu_csr__wstrb_o = lsu_sq[sel_index].strb;
        if(sel_en) begin
            if(lsu_sq[sel_index].st_type == SAQ_CSR) begin
                lsu_csr__wr_en_o = 1'b1;
            end else begin
                lsu_mem__wr_req_o.wr_en = 1'b1;
            end
        end
        if(rls_lock_en_dly) begin
            lsu_mem__wr_req_o.wr_en = 1'b1;
            lsu_mem__wr_req_o.rl_lock = 1'b1;
            lsu_mem__wr_req_o.waddr = rls_lock_addr_dly;
            lsu_mem__wr_req_o.wstrb = data_strobe_t'(0);
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            st_cmd_mem <= sq_item_t'(0);
            st_cmd_en_mem <= 1'b0;
            sel_index_mem <= {SQ_INDEX{1'b0}};
        end else begin
            st_cmd_mem <= lsu_sq[sel_index];
            st_cmd_en_mem <= sel_en;
            sel_index_mem <= sel_index;
        end
    end
    always_comb begin
        if(st_cmd_mem.st_type == SAQ_CSR) begin
            st_cmd_suc = st_cmd_en_mem;
        end else begin
            st_cmd_suc = st_cmd_en_mem && mem_lsu__wr_rsp_i.wr_suc;
        end
    end
    assign rmv_sq_dpend_en_o = st_cmd_suc;
    assign rmv_sq_dpend_index_o = sel_index_mem;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            shortcut_en_mem <= 1'b0;
            shortcut_index_mem <= {SQ_INDEX{1'b0}};
            shortcut_rdata_o <= data_t'(0);
        end else begin
            shortcut_en_mem <= shortcut_en_i;
            shortcut_index_mem <= shortcut_index_i;
            shortcut_rdata_o <= lsu_sq[shortcut_index_mem].data;
        end
    end
    assign shortcut_rd_suc_o = lsu_sq_exec_v[shortcut_index_mem] && shortcut_en_mem;
endmodule : hpu_lsu_sq
