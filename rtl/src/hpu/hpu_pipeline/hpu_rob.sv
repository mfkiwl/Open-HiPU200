`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_rob (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   ctrl__inst_flush_en_i,
    input   update_ckpt_t                           id__ckpt_rcov_i,
    input   logic                                   ctrl_rob__stall_en_i,
    input   logic                                   ctrl__hpu_dmode_i,
    output  rob_cmd_t                               rob_ctrl__cmd_o,
    input   rob_inst_pkg_t[INST_DEC_PARAL-1 : 0]    id_rob__inst_pkg_i,
    input   rob_slot_pkg_t                          id_rob__slot_pkg_i,
    input   logic                                   id_rob__inst_vld_i,
    output  logic                                   rob_id__inst_rdy_o,
    output  logic[ROB_INDEX-1 : 0]                  rob_id__rob_index_o,
    output  logic                                   rob_id__rob_flag_o,
    input   alu_commit_t                            alu0_rob__commit_i,
    input   alu_commit_t                            alu1_rob__commit_i,
    input   lsu_commit_t                            lsu_rob__ld_commit_i,
    input   lsu_commit_t                            lsu_rob__ste_commit_i,
    input   vmu_commit_t                            vmu_rob__commit_i,
    input   mdu_commit_t                            mdu_rob__commit_i,
    output  lsu_retire_t                            rob_lsu__st_retire_o,
    output  vmu_retire_t                            rob_vmu__retire_o,
    output  update_btb_t                            rob_if__update_btb_o,
    output  update_fgpr_t                           rob_if__update_fgpr_o,
    output  update_arat_t                           rob_id__update_arat_o,
    output  update_ckpt_t[1 : 0]                    rob_id__update_ckpt_o,
    output  update_arc_ckpt_t                       rob_id__update_arc_ckpt_o,
    input   csr_bus_req_t                           csr_trig__bus_req_i,
    output  csr_bus_rsp_t                           trig_csr__bus_rsp_o,
    input   data_t                                  csr_mie_i,
    input   data_t                                  csr_mcause_i,
    input   data_t                                  csr_mip_i,
    input   logic                                   csr_excp_req_i,
    output  logic[INST_DEC_BIT : 0]                 hpm_inst_retire_sum_o,
    output  data_t[INST_DEC_PARAL-1 : 0]            hpm_inst_cmt_eve_o,
    input   logic                                   safemd_rcov_disable_i
);
    logic                                   flush_en;
    update_ckpt_t                           ckpt_rcov;
    rob_inst_pkg_t[INST_DEC_PARAL-1 : 0]    rob_inst_pkg[ROB_LEN-1 : 0];
    rob_inst_ls_t[INST_DEC_PARAL-1 : 0]     rob_inst_ls[ROB_LEN-1 : 0];
    rob_slot_pkg_t                          rob_slot_pkg[ROB_LEN-1 : 0];
    pc_t                                    rob_next_pc[ROB_LEN-1 : 0];
    logic                                   rob_br_taken[ROB_LEN-1 : 0];
    logic                                   rob_rcov_flag[ROB_LEN-1 : 0];
    logic[ROB_INDEX-1 : 0]                  ins_addr;
    logic                                   ins_flag;
    logic[ROB_INDEX-1 : 0]                  ckpt_ins_addr[CKPT_LEN-1 : 0];
    logic                                   ckpt_ins_flag[CKPT_LEN-1 : 0];
    logic                                   retire_flag;
    logic[ROB_INDEX-1 : 0]                  retire_addr;
    logic[INST_DEC_BIT-1 : 0]               retire_offset;
    logic                                   rob_empty, rob_full;
    rob_slot_pkg_t                          alu0_slot, alu1_slot;
    update_ckpt_t[1:0]                      update_ckpt;
    rob_slot_pkg_t                          rt_slot;
    rob_inst_pkg_t[INST_DEC_PARAL-1 : 0]    rt_inst;
    rob_inst_ls_t[INST_DEC_PARAL-1 : 0]     rt_inst_ls;
    pc_t                                    rt_next_pc;
    logic                                   rt_br_taken;
    logic[INST_DEC_PARAL-1 : 0]             rt_inst_ready;
    inst_trig_info_t[INST_DEC_PARAL-1 : 0]  inst_trig_info;
    logic                                   slot_allow_retire;
    logic[INST_DEC_BIT : 0]                 retire_fence;
    logic                                   rob_retire_en;
    logic[INST_DEC_BIT : 0]                 rob_retire_num;
    logic                                   inst_retire_en;
    logic[INST_DEC_BIT-1 : 0]               inst_offset_last;
    logic                                   trig_hit_en;
    logic[INST_DEC_BIT : 0]                 trig_hit_fence;
    logic                                   trig_hit_timing;
    logic                                   inst_retire_en_r1;
    logic[INST_DEC_BIT-1 : 0]               inst_offset_first_r1;
    logic[INST_DEC_BIT-1 : 0]               inst_offset_last_r1;
    logic                                   slot_retire_en;
    logic[ROB_INDEX-1 : 0]                  rt_addr_r1;
    rob_slot_pkg_t                          rt_slot_r1;
    rob_inst_pkg_t[INST_DEC_PARAL-1 : 0]    rt_inst_r1;
    rob_inst_ls_t[INST_DEC_PARAL-1 : 0]     rt_inst_ls_r1;
    pc_t                                    rt_next_pc_r1;
    logic                                   rt_br_taken_r1;
    logic[INST_DEC_PARAL-1 : 0]             rt_is_sysc_r1;
    logic[INST_DEC_PARAL-1 : 0]             rt_is_excp_r1;
    logic[INST_DEC_PARAL-1 : 0]             rt_is_vmu_r1;
    logic[INST_DEC_PARAL-1 : 0]             rt_is_lsu_r1;
    ctrl_cmd_e                              ctrl_cmd;
    pc_t                                    next_pc;
    logic                                   bid_mispred;
    excp_e                                  ctrl_excp;
    scl_sysc_e                              ctrl_sysc;
    inst_t                                  excp_inst;
    pc_t                                    excp_addr;
    logic[INST_DEC_BIT : 0]                 rt_fence;
    logic                                   rob_is_stall_ff;
    logic                                   rob_is_stall;
    logic[INST_DEC_BIT : 0]                 rt_is_vmu_psum;
    logic[INST_DEC_PARAL-1 : 0]             rt_is_saq_r1;
    logic[INST_DEC_BIT : 0]                 rt_is_saq_psum[INST_DEC_PARAL-1 : 0];
    logic[INST_DEC_PARAL-1 : 0]             update_arat_act;
    logic[INST_DEC_BIT : 0]                 retire_sum;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            flush_en <= 1'b0;
            ckpt_rcov <= update_ckpt_t'(0);
        end else begin
            flush_en <= ctrl__inst_flush_en_i;
            ckpt_rcov <= id__ckpt_rcov_i;
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<ROB_LEN; i=i+1) begin
                for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                    rob_inst_pkg[i][j] <= rob_inst_pkg_t'(0);
                    rob_inst_ls[i][j] <= rob_inst_ls_t'(0);
                end
                rob_slot_pkg[i] <= rob_slot_pkg_t'(0);
                rob_next_pc[i] <= pc_t'(0);
                rob_br_taken[i] <= 1'b0;
                rob_rcov_flag[i] <= 1'b0;
            end
        end else begin
            for(integer i=0; i<ROB_LEN; i=i+1) begin
                if((ins_addr == i) && id_rob__inst_vld_i && rob_id__inst_rdy_o) begin
                    rob_inst_pkg[i] <= id_rob__inst_pkg_i;
                    rob_slot_pkg[i] <= id_rob__slot_pkg_i;
                    rob_rcov_flag[i] <= 1'b0;
                end
                for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                    if((alu0_rob__commit_i.rob_index==i) && (alu0_rob__commit_i.rob_offset==j)
                        && alu0_rob__commit_i.en ) begin
                        rob_inst_pkg[i][j].complete <= 1'b1;
                        rob_inst_pkg[i][j].excp_en <= alu0_rob__commit_i.excp_en;
                        rob_inst_pkg[i][j].excp <= alu0_rob__commit_i.excp;
                    end else if((alu1_rob__commit_i.rob_index==i) && (alu1_rob__commit_i.rob_offset==j)
                        && alu1_rob__commit_i.en ) begin
                        rob_inst_pkg[i][j].complete <= 1'b1;
                        rob_inst_pkg[i][j].excp_en <= alu1_rob__commit_i.excp_en;
                        rob_inst_pkg[i][j].excp <= alu1_rob__commit_i.excp;
                    end else if((lsu_rob__ld_commit_i.rob_index==i) && (lsu_rob__ld_commit_i.rob_offset==j)
                        && lsu_rob__ld_commit_i.en ) begin
                        rob_inst_pkg[i][j].complete <= 1'b1;
                        rob_inst_pkg[i][j].excp_en <= lsu_rob__ld_commit_i.excp_en;
                        rob_inst_pkg[i][j].excp <= lsu_rob__ld_commit_i.excp;
                    end else if((lsu_rob__ste_commit_i.rob_index==i) && (lsu_rob__ste_commit_i.rob_offset==j)
                        && lsu_rob__ste_commit_i.en ) begin
                        rob_inst_pkg[i][j].complete <= 1'b1;
                        rob_inst_pkg[i][j].excp_en <= lsu_rob__ste_commit_i.excp_en;
                        rob_inst_pkg[i][j].excp <= lsu_rob__ste_commit_i.excp;
                    end else if((mdu_rob__commit_i.rob_index==i) && (mdu_rob__commit_i.rob_offset==j)
                        && mdu_rob__commit_i.en ) begin
                        rob_inst_pkg[i][j].complete <= 1'b1;
                        rob_inst_pkg[i][j].excp_en <= 1'b0;
                        rob_inst_pkg[i][j].excp <= INST_ADDR_MISALIGNED;
                    end else if((vmu_rob__commit_i.rob_index==i) && (vmu_rob__commit_i.rob_offset==j)
                        && vmu_rob__commit_i.en ) begin
                        rob_inst_pkg[i][j].complete <= 1'b1;
                        rob_inst_pkg[i][j].excp_en <= 1'b0;
                        rob_inst_pkg[i][j].excp <= INST_ADDR_MISALIGNED;
                    end
                end
                for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                    if(ckpt_rcov.en && (ckpt_ins_addr[ckpt_rcov.ckpt.index] == i)) begin
                        rob_rcov_flag[i] <= 1'b1;
                    end
                end
                if((alu0_rob__commit_i.rob_index==i) && (alu0_rob__commit_i.is_jbr)
                    && alu0_rob__commit_i.en) begin
                    rob_next_pc[i] <= alu0_rob__commit_i.next_pc;
                    rob_br_taken[i] <= alu0_rob__commit_i.br_taken;
                end else if((alu1_rob__commit_i.rob_index==i) && (alu1_rob__commit_i.is_jbr)
                    && alu1_rob__commit_i.en) begin
                    rob_next_pc[i] <= alu1_rob__commit_i.next_pc;
                    rob_br_taken[i] <= alu1_rob__commit_i.br_taken;
                end
                for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                    if((lsu_rob__ld_commit_i.rob_index==i) && (lsu_rob__ld_commit_i.rob_offset==j)
                        && lsu_rob__ld_commit_i.is_ldst && lsu_rob__ld_commit_i.en ) begin
                        rob_inst_ls[i][j].ldst_addr <= lsu_rob__ld_commit_i.ldst_addr;
                        rob_inst_ls[i][j].ldst_data <= lsu_rob__ld_commit_i.ldst_data;
                    end else if((lsu_rob__ste_commit_i.rob_index==i) && (lsu_rob__ste_commit_i.rob_offset==j)
                        && lsu_rob__ste_commit_i.is_ldst && lsu_rob__ste_commit_i.en ) begin
                        rob_inst_ls[i][j].ldst_addr <= lsu_rob__ste_commit_i.ldst_addr;
                        rob_inst_ls[i][j].ldst_data <= lsu_rob__ste_commit_i.ldst_data;
                    end
                end
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ins_addr <= {ROB_INDEX{1'b0}};
            ins_flag <= 1'b0;
        end else begin
            if(id_rob__inst_vld_i && rob_id__inst_rdy_o && !rob_full) begin
                {ins_flag, ins_addr} <= {ins_flag, ins_addr} + 1'b1;
            end
            if(ckpt_rcov.en) begin
                {ins_flag, ins_addr} <= {ckpt_ins_flag[ckpt_rcov.ckpt.index],
                                         ckpt_ins_addr[ckpt_rcov.ckpt.index]} + 1'b1;
            end
            if(flush_en) begin
                {ins_flag, ins_addr}<= (ROB_INDEX+1)'(0);
            end
        end
    end
    assign rob_id__rob_index_o = ins_addr;
    assign rob_id__rob_flag_o = ins_flag;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<CKPT_LEN; i=i+1) begin
                ckpt_ins_addr[i] <= {ROB_INDEX{1'b0}};
                ckpt_ins_flag[i] <= 1'b0;
            end
        end else begin
            if(id_rob__inst_vld_i && rob_id__inst_rdy_o && id_rob__slot_pkg_i.ckpt_act) begin
                ckpt_ins_addr[id_rob__slot_pkg_i.ckpt.index] <= ins_addr;
                ckpt_ins_flag[id_rob__slot_pkg_i.ckpt.index] <= ins_flag;
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            retire_flag <= 1'b0;
            retire_addr <= {ROB_INDEX{1'b0}};
            retire_offset <= {INST_DEC_BIT{1'b0}};
        end else begin
            if(rob_retire_en && !rob_empty) begin
                {retire_flag,retire_addr,retire_offset} <= {retire_flag,retire_addr,retire_offset}
                    + {{ROB_INDEX{1'b0}}, rob_retire_num};
            end
            if(flush_en) begin
                retire_flag <= 1'b0;
                retire_addr <= {ROB_INDEX{1'b0}};
                retire_offset <= {INST_DEC_BIT{1'b0}};
            end
        end
    end
    assign rob_empty = (ins_addr == retire_addr) && (ins_flag == retire_flag);
    assign rob_full = (ins_addr == retire_addr) && (ins_flag != retire_flag);
    assign rob_id__inst_rdy_o = !rob_full;
    assign alu0_slot = rob_slot_pkg[alu0_rob__commit_i.rob_index];
    assign alu1_slot = rob_slot_pkg[alu1_rob__commit_i.rob_index];
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            update_ckpt[0] <= update_ckpt_t'(0);
            update_ckpt[1] <= update_ckpt_t'(0);
        end else begin
            update_ckpt[0].en <= (alu0_slot.ckpt_act && alu0_rob__commit_i.is_jbr && alu0_rob__commit_i.en);
            update_ckpt[0].ckpt <= alu0_slot.ckpt;
            update_ckpt[0].ckpt_suc <= (alu0_slot.pred_npc == alu0_rob__commit_i.next_pc);
            update_ckpt[0].next_pc <= alu0_rob__commit_i.next_pc;
            update_ckpt[1].en <= (alu1_slot.ckpt_act && alu1_rob__commit_i.is_jbr && alu1_rob__commit_i.en);
            update_ckpt[1].ckpt <= alu1_slot.ckpt;
            update_ckpt[1].ckpt_suc <= (alu1_slot.pred_npc == alu1_rob__commit_i.next_pc);
            update_ckpt[1].next_pc <= alu1_rob__commit_i.next_pc;
        end
    end
    assign rob_id__update_ckpt_o = flush_en ? {update_ckpt_t'(0), update_ckpt_t'(0)} : update_ckpt;
    assign rt_slot = rob_slot_pkg[retire_addr];
    assign rt_inst = rob_inst_pkg[retire_addr];
    assign rt_inst_ls = rob_inst_ls[retire_addr];
    assign rt_next_pc = rob_next_pc[retire_addr];
    assign rt_br_taken = rob_br_taken[retire_addr];
    for(genvar gj=0; gj<INST_DEC_PARAL; gj=gj+1) begin : trig_input
        assign rt_inst_ready[gj] = rt_inst[gj].complete || !rt_inst[gj].avail;
        assign inst_trig_info[gj].avail = rt_inst[gj].avail;
        assign inst_trig_info[gj].pc = rt_slot.cur_pc + (gj<<2);
        assign inst_trig_info[gj].inst = rt_inst[gj].rob_inst.inst;
        assign inst_trig_info[gj].is_ld = rt_inst[gj].rob_inst.is_ld;
        assign inst_trig_info[gj].is_st = rt_inst[gj].rob_inst.is_st;
        assign inst_trig_info[gj].ldst_addr = rt_inst_ls[gj].ldst_addr;
        assign inst_trig_info[gj].ldst_data = rt_inst_ls[gj].ldst_data;
    end
    assign slot_allow_retire = safemd_rcov_disable_i ? !rob_empty && !rob_is_stall
        : !(rt_slot.is_jbr && rt_slot.ckpt_act && !rob_rcov_flag[retire_addr] && (rt_slot.pred_npc != rt_next_pc))
        && !rob_empty && !rob_is_stall;
    always_comb begin
        retire_fence = (INST_DEC_BIT+1)'(INST_DEC_PARAL);
        for(integer i=INST_DEC_PARAL-1; i>=0; i=i-1) begin
            if(i >= retire_offset && !rt_inst_ready[i]) begin
                retire_fence = (INST_DEC_BIT+1)'(i);
            end
        end
    end
    always_comb begin
        rob_retire_en = 1'b0;
        rob_retire_num = (INST_DEC_BIT+1)'(0);
        inst_retire_en = 1'b0;
        inst_offset_last = retire_offset;
        for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
            if(i >= retire_offset && i < retire_fence && slot_allow_retire) begin
                rob_retire_en = 1'b1;
                rob_retire_num += 1'b1;
                if(rt_inst[i].avail && rt_inst[i].complete) begin
                    inst_retire_en = 1'b1;
                    inst_offset_last = INST_DEC_BIT'(i);
                end
            end
        end
    end
    hpu_rob_trigger hpu_rob_trigger_inst (
        .clk_i                                          (clk_i),
        .rst_i                                          (rst_i),
        .ctrl__hpu_dmode_i                              (ctrl__hpu_dmode_i),
        .csr_trig__bus_req_i                            (csr_trig__bus_req_i),
        .trig_csr__bus_rsp_o                            (trig_csr__bus_rsp_o),
        .inst_could_retire_i                            (inst_retire_en),
        .inst_offset_first_i                            (retire_offset),
        .inst_offset_last_i                             (inst_offset_last),
        .inst_trig_info_i                               (inst_trig_info),
        .rob_is_stall_i                                 (rob_is_stall),
        .csr_mie_i                                      (csr_mie_i),
        .csr_mcause_i                                   (csr_mcause_i),
        .csr_mip_i                                      (csr_mip_i),
        .csr_excp_req_i                                 (csr_excp_req_i),
        .trig_hit_en_o                                  (trig_hit_en),
        .trig_hit_fence_o                               (trig_hit_fence),
        .trig_hit_timing_o                              (trig_hit_timing)
    );
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            inst_retire_en_r1 <= 1'b0;
            inst_offset_first_r1 <= INST_DEC_BIT'(0);
            inst_offset_last_r1 <= INST_DEC_BIT'(0);
            slot_retire_en <= 1'b0;
            rt_addr_r1 <= {ROB_INDEX{1'b0}};
            rt_slot_r1 <= rob_slot_pkg_t'(0);
            rt_inst_r1 <= rob_inst_pkg_t'(0);
            rt_inst_ls_r1 <= {INST_DEC_PARAL{rob_inst_ls_t'(0)}};
            rt_next_pc_r1 <= pc_t'(0);
            rt_br_taken_r1 <= 1'b0;
            for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                rt_is_sysc_r1[j] <= 1'b0;
                rt_is_excp_r1[j] <= 1'b0;
                rt_is_vmu_r1[j] <= 1'b0;
                rt_is_lsu_r1[j] <= 1'b0;
            end
        end else begin
            inst_retire_en_r1 <= inst_retire_en;
            inst_offset_first_r1 <= retire_offset;
            inst_offset_last_r1 <= inst_offset_last;
            slot_retire_en <= inst_retire_en && (inst_offset_last == rt_slot.last_pc_offset);
            rt_addr_r1 <= retire_addr;
            rt_slot_r1 <= rt_slot;
            rt_inst_r1 <= rt_inst;
            rt_inst_ls_r1 <= rt_inst_ls;
            rt_next_pc_r1 <= rt_next_pc;
            rt_br_taken_r1 <= rt_br_taken;
            for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                rt_is_sysc_r1[j] <= (rt_inst[j].rob_inst.issue_type == TO_NONE) && rt_inst[j].avail;
                rt_is_excp_r1[j] <= rt_inst[j].excp_en && rt_inst[j].avail;
                rt_is_vmu_r1[j] <= (rt_inst[j].rob_inst.issue_type == TO_VMU) && rt_inst[j].avail;
                rt_is_lsu_r1[j] <= (rt_inst[j].rob_inst.issue_type == TO_LSU) && rt_inst[j].avail;
            end
        end
    end
    always_comb begin
        ctrl_cmd = CMD_NORMAL;
        next_pc = slot_retire_en ? rt_slot_r1.pred_npc : rt_slot_r1.cur_pc + ((inst_offset_last_r1+1)<<2);
        bid_mispred = 1'b0;
        ctrl_excp = excp_e'(0);
        ctrl_sysc = scl_sysc_e'(0);
        excp_inst = inst_t'(0);
        excp_addr = pc_t'(0);
        rt_fence = inst_offset_last_r1 + 1;
        if(slot_retire_en && rt_slot_r1.is_jbr && (rt_slot_r1.pred_npc != rt_next_pc_r1) ) begin
            next_pc = rt_next_pc_r1;
            if(safemd_rcov_disable_i
            || !rt_slot_r1.ckpt_act) begin
                ctrl_cmd = CMD_MISPRED;
            end
        end
        if(slot_retire_en && rt_slot_r1.is_bid && (rt_slot_r1.pred_bid_taken != rt_next_pc_r1)) begin
            bid_mispred = 1'b1;
        end
        for(integer j=INST_DEC_PARAL-1; j>=0; j=j-1) begin
            if(j >= inst_offset_first_r1 && j <= inst_offset_last_r1) begin
                if(rt_is_sysc_r1[j]) begin
                    ctrl_cmd = CMD_SYSC;
                    ctrl_sysc = rt_inst_r1[j].rob_inst.sysc;
                    next_pc = rt_slot_r1.cur_pc + (j<<2);
                    rt_fence = j;
                end
                if(trig_hit_en && (j == trig_hit_fence)) begin
                    ctrl_cmd = CMD_TRIG;
                    if(trig_hit_timing == 1'b0) begin
                        next_pc = rt_slot_r1.cur_pc + (j<<2);
                        rt_fence = j;
                    end else begin
                        if((j == rt_slot_r1.last_pc_offset) && rt_slot_r1.is_jbr) begin
                            next_pc = rt_next_pc_r1;
                        end else begin
                            next_pc = rt_slot_r1.cur_pc + ((j+1)<<2);
                        end
                        rt_fence = j+1;
                    end
                end
                if(rt_is_excp_r1[j]) begin
                    ctrl_cmd = CMD_EXCP;
                    ctrl_excp = rt_inst_r1[j].excp;
                    next_pc = rt_slot_r1.cur_pc + (j<<2);
                    excp_inst = rt_inst_r1[j].rob_inst.inst;
                    excp_addr = rt_inst_ls_r1[j].ldst_addr;
                    rt_fence = j;
                end
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            rob_is_stall_ff <= 1'b0;
        end else begin
            if(flush_en) begin
                rob_is_stall_ff <= 1'b0;
            end else begin
                rob_is_stall_ff <= rob_is_stall;
            end
        end
    end
    assign rob_is_stall = rob_is_stall_ff
                        || ((ctrl_cmd != CMD_NORMAL) && inst_retire_en_r1)
                        || ctrl_rob__stall_en_i;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            rob_ctrl__cmd_o <= rob_cmd_t'(0);
        end else begin
            rob_ctrl__cmd_o.en <= inst_retire_en_r1;
            rob_ctrl__cmd_o.cmd <= ctrl_cmd;
            rob_ctrl__cmd_o.npc <= next_pc;
            rob_ctrl__cmd_o.excp_type <= ctrl_excp;
            rob_ctrl__cmd_o.excp_inst <= excp_inst;
            rob_ctrl__cmd_o.excp_addr <= excp_addr;
            rob_ctrl__cmd_o.sysc <= ctrl_sysc;
            rob_ctrl__cmd_o.bid_mispred <= bid_mispred;
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            rob_if__update_btb_o <= update_btb_t'(0);
        end else begin
            rob_if__update_btb_o <= update_btb_t'(0);
            if(slot_retire_en) begin
                if((rt_slot_r1.pred_npc != rt_next_pc_r1) && rt_slot_r1.is_jbr) begin
                    rob_if__update_btb_o.en <= 1'b1;
                    rob_if__update_btb_o.way_sel <= rt_slot_r1.btb_way_sel;
                    rob_if__update_btb_o.qdec_type <= rt_slot_r1.qdec_type;
                    rob_if__update_btb_o.pred_npc <= rt_next_pc_r1;
                    rob_if__update_btb_o.cur_pc <= {rt_slot_r1.cur_pc[INST_WTH-1 : INST_FETCH_BIT+2],
                        INST_FETCH_BIT'(rt_slot_r1.fet_pc_offset), 2'h0};
                end
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            rob_if__update_fgpr_o <= update_fgpr_t'(0);
        end else begin
            rob_if__update_fgpr_o <= update_fgpr_t'(0);
            if(slot_retire_en) begin
                if(rt_slot_r1.is_bid) begin
                    rob_if__update_fgpr_o.en <= 1'b1;
                    rob_if__update_fgpr_o.is_taken <= rt_br_taken_r1;
                    rob_if__update_fgpr_o.cur_pc <= {rt_slot_r1.cur_pc[INST_WTH-1 : INST_FETCH_BIT+2],
                        INST_FETCH_BIT'(rt_slot_r1.fet_pc_offset), 2'h0};
                end
            end
        end
    end
    always_comb begin
        rt_is_vmu_psum = 0;
        for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
            if(j>= inst_offset_first_r1 && j < rt_fence) begin
                rt_is_vmu_psum += {{INST_DEC_BIT{1'b0}}, rt_is_vmu_r1[j]};
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            rob_vmu__retire_o <= vmu_retire_t'(0);
        end else begin
            rob_vmu__retire_o.en <= 1'b0;
            if(inst_retire_en_r1) begin
                rob_vmu__retire_o.en <= |rt_is_vmu_psum;
                rob_vmu__retire_o.vmu_rt_sum <= rt_is_vmu_psum;
            end
        end
    end
    always_comb begin
        for(integer j=INST_DEC_PARAL-1; j>=0; j=j-1) begin
            rt_is_saq_r1[j] = rt_is_lsu_r1[j]
                && (j>= inst_offset_first_r1 && j < rt_fence)
                && ((rt_inst_r1[j].rob_inst.itype.lsu == STORE)
                || (rt_inst_r1[j].rob_inst.itype.lsu == ATOM)
                || (rt_inst_r1[j].rob_inst.itype.lsu == FENCE)
                || (rt_inst_r1[j].rob_inst.itype.lsu == CSR) && !rt_inst_r1[j].rob_inst.csr_we_mask);
            if(j==INST_DEC_PARAL-1) begin
                rt_is_saq_psum[INST_DEC_PARAL-1] = rt_is_saq_r1[INST_DEC_PARAL-1];
            end else begin
                rt_is_saq_psum[j] = rt_is_saq_psum[j+1] + {{INST_DEC_BIT{1'b0}}, rt_is_saq_r1[j]};
            end
            if( rt_inst_r1[j].excp_en
                && (j>= inst_offset_first_r1 && j < rt_fence)
            ) begin
                rt_is_saq_psum[j] = 0;
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            rob_lsu__st_retire_o <= lsu_retire_t'(0);
        end else begin
            rob_lsu__st_retire_o.en <= 1'b0;
            if(inst_retire_en_r1) begin
                rob_lsu__st_retire_o.en <= |rt_is_saq_r1;
                rob_lsu__st_retire_o.rob_index <= rt_addr_r1;
                rob_lsu__st_retire_o.rob_rt_sum <= rt_is_saq_psum[0];
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            rob_id__update_arc_ckpt_o <= update_arc_ckpt_t'(0);
        end else begin
            rob_id__update_arc_ckpt_o.en <= 1'b0;
            if(slot_retire_en) begin
                rob_id__update_arc_ckpt_o.en <= 1'b1;
                rob_id__update_arc_ckpt_o.ckpt <= rt_slot_r1.ckpt;
            end
        end
    end
    always_comb begin
        for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
            update_arat_act[j] = inst_retire_en_r1 && rt_inst_r1[j].rob_inst.rdst_en && rt_inst_r1[j].avail
                && (j>= inst_offset_first_r1 && j < rt_fence);
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            rob_id__update_arat_o <= update_arat_t'(0);
        end else begin
            rob_id__update_arat_o.en <= |update_arat_act;
            for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                rob_id__update_arat_o.avail[j] <= update_arat_act[j];
                rob_id__update_arat_o.arc_rdst_index[j] <= rt_inst_r1[j].rob_inst.arc_rdst_index;
                rob_id__update_arat_o.phy_rdst_index[j] <= rt_inst_r1[j].rob_inst.phy_rdst_index;
                rob_id__update_arat_o.phy_old_rdst_index[j] <= rt_inst_r1[j].rob_inst.phy_old_rdst_index;
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
                hpm_inst_cmt_eve_o[i] <= data_t'(0);
            end
        end else begin
            for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
                hpm_inst_cmt_eve_o[i] <= data_t'(0);
                hpm_inst_cmt_eve_o[i][EXCP_TAKEN] <= slot_retire_en
                    && (rt_is_excp_r1[i] || (rt_is_sysc_r1[i] && rt_inst_r1[i].rob_inst.sysc == ECALL));
                hpm_inst_cmt_eve_o[i][LD_RETIRED] <= slot_retire_en
                    && (rt_inst_r1[i].rob_inst.issue_type == TO_LSU && rt_inst_r1[i].rob_inst.itype.lsu == LOAD);
                hpm_inst_cmt_eve_o[i][ST_RETIRED] <= slot_retire_en
                    && (rt_inst_r1[i].rob_inst.issue_type == TO_LSU && rt_inst_r1[i].rob_inst.itype.lsu == STORE);
                hpm_inst_cmt_eve_o[i][ATM_RETIRED] <= slot_retire_en
                    && (rt_inst_r1[i].rob_inst.issue_type == TO_LSU && rt_inst_r1[i].rob_inst.itype.lsu == ATOM);
                hpm_inst_cmt_eve_o[i][SYSC_RETIRED] <= slot_retire_en
                    && (rt_inst_r1[i].rob_inst.issue_type == TO_NONE);
                hpm_inst_cmt_eve_o[i][ARTH_RETIRED] <= slot_retire_en
                    && (rt_inst_r1[i].rob_inst.issue_type == TO_ALU
                    && (rt_inst_r1[i].rob_inst.itype.alu == ALG) || (rt_inst_r1[i].rob_inst.itype.alu == UP));
                hpm_inst_cmt_eve_o[i][BR_RETIRED] <= slot_retire_en
                    && (rt_inst_r1[i].rob_inst.issue_type == TO_ALU && rt_inst_r1[i].rob_inst.itype.alu == BR);
                hpm_inst_cmt_eve_o[i][JAL_RETIRED] <= slot_retire_en
                    && (rt_inst_r1[i].rob_inst.issue_type == TO_ALU && rt_inst_r1[i].rob_inst.itype.alu == JAL);
                hpm_inst_cmt_eve_o[i][JALR_RETIRED] <= slot_retire_en
                    && (rt_inst_r1[i].rob_inst.issue_type == TO_ALU && rt_inst_r1[i].rob_inst.itype.alu == JALR);
                hpm_inst_cmt_eve_o[i][MUL_RETIRED] <= 1'b0;
                hpm_inst_cmt_eve_o[i][DIV_RETIRED] <= 1'b0;
                hpm_inst_cmt_eve_o[i][VEC_RETIRED] <= slot_retire_en
                    && (rt_inst_r1[i].rob_inst.issue_type == TO_VMU && rt_inst_r1[i].rob_inst.itype.vmu == VEC);
                hpm_inst_cmt_eve_o[i][VCSR_RETIRED] <= slot_retire_en
                    && (rt_inst_r1[i].rob_inst.issue_type == TO_VMU && rt_inst_r1[i].rob_inst.itype.vmu == VCSR);
                hpm_inst_cmt_eve_o[i][MTX_RETIRED] <= slot_retire_en
                    && (rt_inst_r1[i].rob_inst.issue_type == TO_VMU && rt_inst_r1[i].rob_inst.itype.vmu == MTX);
            end
        end
    end
    always_comb begin
        retire_sum = {(INST_DEC_BIT+1){1'b0}};
        for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
            if(j>= inst_offset_first_r1 && j < rt_fence) begin
                retire_sum += rt_inst_r1[j].avail;
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            hpm_inst_retire_sum_o <= {(INST_DEC_BIT+1){1'b0}};
        end else begin
            if(inst_retire_en_r1) begin
                hpm_inst_retire_sum_o <= retire_sum;
            end else begin
                hpm_inst_retire_sum_o <= {(INST_DEC_BIT+1){1'b0}};
            end
        end
    end
    typedef struct packed {
        logic complete;
        issue_type_e pc_type;
        itype_alu_e alu_op;
        itype_lsu_e lsu_op;
        itype_vmu_e vmu_op;
        itype_sysc_e sysc_op;
    } rob_inst_t;
    typedef struct packed {
        rob_inst_t[INST_DEC_PARAL-1 : 0] inst;
        logic[INST_DEC_PARAL-1 : 0] mask;
        pc_t cur_pc;
        pc_t pred_npc;
        logic is_jbr;
    } prb_rob_t;
    prb_rob_t prb_rob[ROB_LEN-1 : 0];
    logic[ROB_INDEX-1 : 0] insert_point;
    logic[ROB_INDEX-1 : 0] retire_point;
    always_comb begin
        for(integer i=0; i<ROB_LEN; i=i+1) begin
            for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                prb_rob[i].inst[j].complete = rob_inst_pkg[i][j].complete;
                prb_rob[i].inst[j].pc_type = rob_inst_pkg[i][j].rob_inst.issue_type;
                prb_rob[i].inst[j].alu_op = rob_inst_pkg[i][j].rob_inst.itype.alu;
                prb_rob[i].inst[j].lsu_op = rob_inst_pkg[i][j].rob_inst.itype.lsu;
                prb_rob[i].inst[j].vmu_op = rob_inst_pkg[i][j].rob_inst.itype.vmu;
                prb_rob[i].inst[j].sysc_op = rob_inst_pkg[i][j].rob_inst.itype.sysc;
                prb_rob[i].mask[j] = (retire_flag == ins_flag) ? (i >= retire_addr) && (i < ins_addr)
                                                               : (i >= retire_addr) || (i < ins_addr);
                prb_rob[i].mask[j] = prb_rob[i].mask[j] && rob_inst_pkg[i][j].avail;
            end
            prb_rob[i].cur_pc = rob_slot_pkg[i].cur_pc;
            prb_rob[i].pred_npc = rob_slot_pkg[i].pred_npc;
            prb_rob[i].is_jbr = rob_slot_pkg[i].is_jbr;
        end
    end
    assign insert_point = ins_addr;
    assign retire_point = retire_addr;
endmodule : hpu_rob
