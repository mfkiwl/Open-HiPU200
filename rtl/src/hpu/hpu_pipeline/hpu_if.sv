`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
import dm::*;
module hpu_if (
    input  logic                                    clk_i,
    input  logic                                    rst_i,
    input   logic                                   ctrl__inst_flush_en_i,
    input   update_ckpt_t                           id__ckpt_rcov_i,
    input   logic                                   ctrl_if__normal_fetch_en_i,
    input   logic                                   ctrl_if__single_fetch_en_i,
    output  logic                                   if_ctrl__inst_fetch_suc_o,
    input   logic                                   ctrl_if__update_npc_en_i,
    input   pc_t                                    ctrl_if__update_npc_i,
    input   logic                                   ctrl_if__btb_flush_en_i,
    input   logic                                   ctrl_if__ras_flush_en_i,
    input   logic                                   ctrl_if__fgpr_flush_en_i,
    output  logic                                   if_ic__npc_en_o,
    output  pc_t                                    if_ic__npc_o,
    input   logic                                   ic_if__suc_i,
    input   inst_t[INST_FETCH_PARAL-1 : 0]          ic_if__inst_i,
    output  logic                                   if_darb__rd_en_o,
    output  pc_t                                    if_darb__raddr_o,
    input   inst_t                                  darb_if__inst_i,
    output  if_inst_t                               if_id__inst_o,
    output  logic                                   if_id__inst_vld_o,
    input   logic                                   id_if__inst_rdy_i,
    input   update_btb_t                            rob_if__update_btb_i,
    input   update_fgpr_t                           rob_if__update_fgpr_i
);
    logic                                   flush_en;
    logic                                   update_npc_en;
    pc_t                                    update_npc;
    logic                                   normal_fetch_en;
    logic                                   single_fetch_en;
    logic                                   fetch_en;
    pc_t                                    next_pc;
    logic                                   dm_path_en;
    logic                                   fetch_inst_en_if0;
    logic                                   single_fetch_en_if0;
    logic                                   dm_path_en_if0;
    pc_t                                    cur_pc;
    logic                                   cur_pc_en;
    logic                                   cgpr_is_taken;
    pc_t                                    cgpr_pred_npc;
    pc_t                                    cgpr_ras_pred_npc;
    logic[BTB_WAY_BIT-1 : 0]                btb_way_sel;
    logic                                   cur_pc_en_if1;
    pc_t                                    cur_pc_if1;
    pc_t                                    next_pc_if1;
    logic                                   cgpr_is_taken_if1;
    pc_t                                    cgpr_pred_npc_if1;
    pc_t                                    cgpr_ras_pred_npc_if1;
    logic[BTB_WAY_BIT-1 : 0]                btb_way_sel_if1;
    logic                                   single_fetch_en_if1;
    logic                                   dm_path_en_if1;
    logic                                   cur_inst_en;
    pc_t                                    cur_inst_pc_if1[INST_FETCH_PARAL-1 : 0];
    inst_t                                  cur_inst[INST_FETCH_PARAL-1 : 0];
    logic                                   inst_may_be_call[INST_FETCH_PARAL : 0];
    data_t                                  inst_may_be_call_rs1[INST_FETCH_PARAL : 0];
    qdec_type_e                             qdec_type[INST_FETCH_PARAL-1 : 0];
    pc_t                                    qdec_pred_npc[INST_FETCH_PARAL-1 : 0];
    logic                                   last_inst_may_be_call;
    data_t                                  last_inst_may_be_call_rs1;
    logic[INST_FETCH_BIT-1 : 0]             first_pc_offset;
    logic[INST_FETCH_BIT-1 : 0]             pred_last_pc_offset;
    qdec_type_e                             qdec_grp_type;
    pc_t                                    qdec_grp_pred_npc;
    logic[INST_FETCH_BIT-1 : 0]             last_pc_offset;
    logic                                   fgpr_is_taken;
    pc_t                                    fgpr_pred_npc;
    logic                                   fgpr_bid_taken;
    if_inst_t[IBUF_PARAL-1 : 0]             ibuf_inst;
    logic[IBUF_PARAL-1 : 0]                 ibuf_inst_en;
    logic                                   ibuf_afull;
    update_ras_t                            update_ras;
    logic                                   fgpr_is_taken_if2;
    pc_t                                    fgpr_pred_npc_if2;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            flush_en <= 1'b0;
            update_npc_en <= 1'b0;
            update_npc <= pc_t'(0);
            normal_fetch_en <= 1'b0;
            single_fetch_en <= 1'b0;
        end else begin
            flush_en <= ctrl__inst_flush_en_i | id__ckpt_rcov_i.en;
            if(ctrl_if__update_npc_en_i) begin
                update_npc_en <= ctrl_if__update_npc_en_i;
                update_npc <= ctrl_if__update_npc_i;
            end else begin
                update_npc_en <= id__ckpt_rcov_i.en;
                update_npc <= id__ckpt_rcov_i.next_pc;
            end
            normal_fetch_en <= ctrl_if__normal_fetch_en_i;
            single_fetch_en <= ctrl_if__single_fetch_en_i;
        end
    end
    assign fetch_en = (normal_fetch_en | single_fetch_en) & ~ibuf_afull;
    always_comb begin
        next_pc = cur_pc;
        if(fetch_en && cur_pc_en) begin
            if(single_fetch_en) begin
                next_pc = cur_pc + 3'h4;
            end else begin
                next_pc = {fet_pc_base(cur_pc)+1, {(INST_FETCH_BIT+2){1'b0}} };
            end
        end
        if(cgpr_is_taken) begin
            next_pc = cgpr_pred_npc;
        end
        if(fgpr_is_taken_if2) begin
            next_pc = fgpr_pred_npc_if2;
        end
        if(update_npc_en) begin
            next_pc = update_npc;
        end
    end
    assign dm_path_en = (next_pc >= MEM_DEBUG_ADDR_S && next_pc <= MEM_DEBUG_ADDR_E);
    assign if_ic__npc_en_o = ~dm_path_en & fetch_en;
    assign if_ic__npc_o = {fet_pc_base(next_pc), {(INST_FETCH_BIT+2){1'b0}} };
    assign if_darb__rd_en_o = dm_path_en & fetch_en;
    assign if_darb__raddr_o = next_pc;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            fetch_inst_en_if0 <= 1'b0;
            single_fetch_en_if0 <= 1'b0;
            dm_path_en_if0 <= 1'b0;
            cur_pc <= pc_t'(0);
        end else begin
            fetch_inst_en_if0 <= fetch_en;
            single_fetch_en_if0 <= single_fetch_en;
            dm_path_en_if0 <= dm_path_en;
            cur_pc <= next_pc;
        end
    end
    assign cur_pc_en = fetch_inst_en_if0
        & (dm_path_en_if0 | ic_if__suc_i)
        & ~fgpr_is_taken_if2
        & ~flush_en;
    assign if_ctrl__inst_fetch_suc_o = cur_pc_en;
    hpu_if_cgpr hpu_if_cgpr_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .ctrl_if__btb_flush_en_i                        (ctrl_if__btb_flush_en_i),
        .ctrl_if__ras_flush_en_i                        (ctrl_if__ras_flush_en_i),
        .cur_pc_en_i                                    (cur_pc_en),
        .next_pc_i                                      (next_pc),
        .cgpr_is_taken_o                                (cgpr_is_taken),
        .cgpr_pred_npc_o                                (cgpr_pred_npc),
        .cgpr_ras_pred_npc_o                            (cgpr_ras_pred_npc),
        .btb_way_sel_o                                  (btb_way_sel),
        .rob_if__update_btb_i                           (rob_if__update_btb_i),
        .update_ras_i                                   (update_ras)
    );
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            cur_pc_en_if1 <= 1'b0;
            cur_pc_if1 <= pc_t'(0);
            next_pc_if1 <= pc_t'(0);
            cgpr_is_taken_if1 <= 1'b0;
            cgpr_pred_npc_if1 <= pc_t'(0);
            cgpr_ras_pred_npc_if1 <= pc_t'(0);
            btb_way_sel_if1 <= {BTB_WAY_BIT{1'b0}};
            single_fetch_en_if1 <= 1'b0;
            dm_path_en_if1 <= 1'b0;
        end else begin
            cur_pc_en_if1 <= cur_pc_en;
            cur_pc_if1 <= cur_pc;
            next_pc_if1 <= next_pc;
            cgpr_is_taken_if1 <= cgpr_is_taken;
            cgpr_pred_npc_if1 <= cgpr_pred_npc;
            cgpr_ras_pred_npc_if1 <= cgpr_ras_pred_npc;
            btb_way_sel_if1 <= btb_way_sel;
            single_fetch_en_if1 <= single_fetch_en_if0;
            dm_path_en_if1 <= dm_path_en_if0;
        end
    end
    assign cur_inst_en = cur_pc_en_if1
        & ~fgpr_is_taken_if2
        & ~flush_en;
    for(genvar gi=0; gi<INST_FETCH_PARAL; gi=gi+1) begin: qdec_blk
        assign cur_inst_pc_if1[gi] = {fet_pc_base(cur_pc_if1), gi[INST_FETCH_BIT-1:0], 2'h0};
        assign cur_inst[gi] = dm_path_en_if1 ? darb_if__inst_i : ic_if__inst_i[gi];
        hpu_if_qdec hpu_if_qdec_inst (
            .cur_inst_i                                     (cur_inst[gi]),
            .cur_inst_pc_if1_i                              (cur_inst_pc_if1[gi]),
            .inst_may_be_call_i                             (inst_may_be_call[gi]),
            .inst_may_be_call_rs1_i                         (inst_may_be_call_rs1[gi]),
            .inst_may_be_call_o                             (inst_may_be_call[gi+1]),
            .inst_may_be_call_rs1_o                         (inst_may_be_call_rs1[gi+1]),
            .qdec_type_o                                    (qdec_type[gi]),
            .qdec_pred_npc_o                                (qdec_pred_npc[gi])
        );
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            last_inst_may_be_call <= 1'b0;
            last_inst_may_be_call_rs1 <= data_t'(0);
        end else begin
            if(cur_inst_en) begin
                last_inst_may_be_call <= inst_may_be_call[INST_FETCH_PARAL];
                last_inst_may_be_call_rs1 <= inst_may_be_call_rs1[INST_FETCH_PARAL];
            end
        end
    end
    assign inst_may_be_call[0] = last_inst_may_be_call;
    assign inst_may_be_call_rs1[0] = last_inst_may_be_call_rs1;
    assign first_pc_offset = cur_pc_if1[2 +: INST_FETCH_BIT];
    assign pred_last_pc_offset = single_fetch_en_if1 ? first_pc_offset : {INST_FETCH_BIT{1'b1}};
    always_comb begin
        qdec_grp_type = IS_NORMAL;
        qdec_grp_pred_npc = qdec_pred_npc[pred_last_pc_offset];
        last_pc_offset = pred_last_pc_offset;
        for(integer i=INST_FETCH_PARAL-1; i>=0; i=i-1) begin
            if(i >= first_pc_offset && i <= pred_last_pc_offset) begin
                case(qdec_type[i])
                    IS_BRANCH, IS_JALR: begin
                        qdec_grp_type = qdec_type[i];
                        if(cgpr_is_taken_if1) begin
                            qdec_grp_pred_npc = cgpr_pred_npc_if1;
                        end else begin
                            qdec_grp_pred_npc = {{fet_pc_base(cur_pc_if1), i[INST_FETCH_BIT-1 : 0]} + 1, 2'h0};
                        end
                        last_pc_offset = i[INST_FETCH_BIT-1 : 0];
                    end
                    IS_RET: begin
                        qdec_grp_type = qdec_type[i];
                        qdec_grp_pred_npc = cgpr_ras_pred_npc_if1;
                        last_pc_offset = i[INST_FETCH_BIT-1 : 0];
                    end
                    IS_JAL, IS_CALL: begin
                        qdec_grp_type = qdec_type[i];
                        qdec_grp_pred_npc = qdec_pred_npc[i];
                        last_pc_offset = i[INST_FETCH_BIT-1 : 0];
                    end
                endcase
            end
        end
    end
    hpu_if_fgpr hpu_if_fgpr_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .ctrl_if__fgpr_flush_en_i                       (ctrl_if__fgpr_flush_en_i),
        .cur_inst_en_i                                  (cur_inst_en),
        .next_pc_i                                      (next_pc),
        .cur_pc_i                                       (cur_pc),
        .cur_pc_if1_i                                   (cur_pc_if1),
        .next_pc_if1_i                                  (next_pc_if1),
        .qdec_grp_type_i                                (qdec_grp_type),
        .qdec_grp_pred_npc_i                            (qdec_grp_pred_npc),
        .last_pc_offset_i                               (last_pc_offset),
        .fgpr_is_taken_o                                (fgpr_is_taken),
        .fgpr_pred_npc_o                                (fgpr_pred_npc),
        .fgpr_bid_taken_o                               (fgpr_bid_taken),
        .rob_if__update_fgpr_i                          (rob_if__update_fgpr_i)
    );
    always_comb begin
        for(integer i=0; i<IBUF_PARAL; i=i+1) begin
            for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                ibuf_inst[i].avail[j] = (i*INST_DEC_PARAL+j >= first_pc_offset)
                    && (i*INST_DEC_PARAL+j <= last_pc_offset);
                ibuf_inst[i].inst[j] = cur_inst[i*INST_DEC_PARAL+j];
                ibuf_inst[i].qdec_type[j] = qdec_type[i*INST_DEC_PARAL+j];
            end
        end
    end
    always_comb begin
        for(integer i=0; i<IBUF_PARAL; i=i+1) begin
            ibuf_inst[i].cur_pc = {fet_pc_base(cur_pc_if1), {(INST_FETCH_BIT+2){1'b0}}} + ((i*INST_DEC_PARAL)<<2);
            ibuf_inst[i].pred_npc = {dec_pc_base(ibuf_inst[i].cur_pc) + 1, {(INST_DEC_BIT+2){1'b0}}};
            for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                if(ibuf_inst[i].avail[j] && (INST_FETCH_BIT'(i*INST_DEC_PARAL+j) == last_pc_offset)) begin
                    ibuf_inst[i].pred_npc = fgpr_pred_npc;
                end
            end
            ibuf_inst[i].btb_way_sel = btb_way_sel_if1;
            ibuf_inst[i].fet_pc_offset = cur_pc_if1[INST_FETCH_BIT +: 2];
            ibuf_inst[i].pred_bid_taken = fgpr_bid_taken;
        end
    end
    always_comb begin
        for(integer i=0; i<IBUF_PARAL; i=i+1) begin
            ibuf_inst_en[i] = cur_inst_en & |ibuf_inst[i].avail;
        end
    end
    hpu_if_ibuf hpu_if_ibuf_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .flush_en_i                                     (flush_en),
        .ibuf_inst_i                                    (ibuf_inst),
        .ibuf_inst_en_i                                 (ibuf_inst_en),
        .ibuf_afull_o                                   (ibuf_afull),
        .if_id__inst_o                                  (if_id__inst_o),
        .if_id__inst_vld_o                              (if_id__inst_vld_o),
        .id_if__inst_rdy_i                              (id_if__inst_rdy_i)
    );
    assign update_ras.push_en = (qdec_grp_type == IS_CALL) && cur_inst_en;
    assign update_ras.push_pred_npc =  {{fet_pc_base(cur_pc_if1), last_pc_offset[INST_FETCH_BIT-1 : 0]} + 1, 2'h0};
    assign update_ras.pop_en = (qdec_grp_type == IS_RET) && cur_inst_en;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            fgpr_is_taken_if2 <= 1'b0;
            fgpr_pred_npc_if2 <= pc_t'(0);
        end else begin
            fgpr_is_taken_if2 <= fgpr_is_taken;
            fgpr_pred_npc_if2 <= fgpr_pred_npc;
        end
    end
    logic prb_rt_fet_en;
    pc_t prb_rt_fet_pc;
    logic prb_if0_en;
    pc_t prb_if0_fet_pc;
    logic prb_if0_cgpr_taken;
    pc_t prb_if0_cgpr_pred_npc;
    logic prb_if1_en;
    pc_t prb_if1_fet_pc;
    pc_t prb_if1_pred_npc;
    logic[INST_FETCH_PARAL-1 : 0] prb_if1_pc_mask;
    inst_t[INST_FETCH_PARAL-1 : 0] prb_if1_pc_type;
    logic prb_if2_fgpr_taken;
    pc_t prb_if2_fgpr_pred_npc;
    assign prb_rt_fet_en = fetch_en;
    assign prb_rt_fet_pc = next_pc;
    assign prb_if0_en = cur_pc_en;
    assign prb_if0_fet_pc = cur_pc_en ? cur_pc : pc_t'(0);
    assign prb_if0_cgpr_taken = cur_pc_en && cgpr_is_taken;
    assign prb_if0_cgpr_pred_npc = cur_pc_en ? cgpr_pred_npc : pc_t'(0);
    assign prb_if1_en = cur_inst_en;
    assign prb_if1_fet_pc = cur_inst_en ? cur_pc_if1 : pc_t'(0);
    assign prb_if1_pred_npc = cur_inst_en ? fgpr_pred_npc : pc_t'(0);
    for(genvar i=0; i<INST_FETCH_PARAL; i=i+1) begin
        assign prb_if1_pc_mask[i] = cur_inst_en && (i >= first_pc_offset) && (i <= last_pc_offset);
        assign prb_if1_pc_type[i] = qdec_type[i];
    end
    assign prb_if2_fgpr_taken = fgpr_is_taken_if2;
    assign prb_if2_fgpr_pred_npc = fgpr_pred_npc_if2;
endmodule : hpu_if
