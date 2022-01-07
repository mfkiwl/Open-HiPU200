`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_ctrl (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   sys_hpu__restart_i,
    input   logic                                   sys_hpu__mode_single_step_i,
    input   logic                                   sys_hpu__mode_scalar_i,
    input   logic                                   sys_hpu__mode_super_scalar_i,
    input   pc_t                                    sys_hpu__init_pc_i,
    output  logic                                   hpu_sys__wfi_act_o,
    input   rob_cmd_t                               rob_ctrl__cmd_i,
    input   csr_mip_t                               clint_ctrl__intr_act_i,
    output  logic                                   ctrl__inst_flush_en_o,
    output  logic                                   ctrl_if__normal_fetch_en_o,
    output  logic                                   ctrl_if__single_fetch_en_o,
    input   logic                                   if_ctrl__inst_fetch_suc_i,
    output  logic                                   ctrl_if__update_npc_en_o,
    output  pc_t                                    ctrl_if__update_npc_o,
    output  logic                                   ctrl_rob__stall_en_o,
    output  logic                                   ctrl__hpu_dmode_o,
    output  logic                                   ctrl_if__btb_flush_en_o,
    output  logic                                   ctrl_if__ras_flush_en_o,
    output  logic                                   ctrl_if__fgpr_flush_en_o,
    output  logic                                   ctrl_ic__flush_req_o,
    input   logic                                   ic_ctrl__flush_done_i,
    input   logic                                   lsu_ctrl__sq_retire_empty_i,
    input   logic                                   dm_ctrl__req_halt_i,
    input   logic                                   dm_ctrl__req_resume_i,
    input   logic                                   dm_ctrl__req_setrsthalt_i,
    input   logic                                   dm_ctrl__start_cmd_i,
    output  logic                                   ctrl_dm__status_halted_o,
    output  logic                                   ctrl_dm__status_running_o,
    output  logic                                   ctrl_dm__status_havereset_o,
    output  logic                                   ctrl_dm__unavailable_o,
    output  data_t                                  ctrl_dm__hartinfo_o,
    output  logic                                   ctrl_darb__rspd_en_o,
    output  rspd_e                                  ctrl_darb__rspd_data_o,
    input   csr_bus_req_t                           csr_ctrl__bus_req_i,
    output  csr_bus_rsp_t                           ctrl_csr__bus_rsp_o,
    output  csr_mie_t                               csr_mie_o,
    output  csr_mcause_t                            csr_mcause_o,
    output  csr_mip_t                               csr_mip_o,
    output  logic                                   csr_excp_req_o,
    output  csr_mtvec_t                             csr_mtvec_o,
    output  csr_mstatus_t                           csr_mstatus_o,
    output  data_t                                  csr_mtval_o,
    output  pc_t                                    csr_mepc_o,
    output  data_t                                  hpm_mco_arch_eve_o,
    output  pc_t                                    safemd_arc_pc_o
);
    logic                                   restart, restart_sync0;
    logic                                   mode_single_step, mode_single_step_sync0;
    logic                                   mode_scalar, mode_scalar_sync0;
    logic                                   mode_super_scalar, mode_super_scalar_sync0;
    pc_t                                    init_pc, init_pc_sync0;
    pc_t                                    arc_pc_pre;
    pc_t                                    arc_pc;
    hpu_mode_e                              proc_mode;
    logic                                   hpu_reset_req;
    logic                                   hpu_dbg_req;
    logic                                   hpu_dbgexit_req;
    logic                                   intr_halt_en;
    logic                                   hpu_intr_req;
    logic                                   hpu_wakeup_req;
    logic                                   hpu_excp_req;
    excp_e                                  hpu_excp_type;
    inst_t                                  hpu_excp_inst;
    pc_t                                    hpu_excp_addr;
    pc_t                                    hpu_excp_pc;
    logic                                   hpu_trapexit_req;
    logic                                   hpu_wfi_req;
    logic                                   hpu_fencei_req;
    logic                                   mispred_en;
    logic                                   instr_retire_en;
    typedef enum logic[3 : 0] {
        PIP_INIT, PIP_RUNNING, PIP_RUNNING_DLY,
        PIP_HARD_STEP, PIP_HARD_STEP_DLY,
        PIP_FLUSH_IC, PIP_FLUSH_IC_DLY,
        PIP_SLEEP,
        PIP_DBG_HALT, PIP_DBG_RUNNING
    } pip_fsm;
    pip_fsm                                 cur_st, last_st;
    pip_fsm                                 next_st, last_st_comb;
    logic                                   hpu_intr_rsp_p1;
    logic                                   hpu_intr_rsp;
    logic                                   hpu_wakeup_rsp_p1;
    logic                                   hpu_wakeup_rsp;
    logic                                   hpu_dbg_rsp_p1;
    logic                                   hpu_dbg_rsp;
    logic                                   set_rsthalt_rsp ;
    logic                                   hpu_intr_rsp_p2;
    logic                                   hpu_wakeup_rsp_p2;
    logic                                   hpu_excp_rsp;
    logic                                   hpu_trapexit_rsp;
    logic                                   hpu_dbg_rsp_p2;
    logic                                   hpu_dbgexit_rsp;
    logic                                   hpu_fencei_rsp;
    logic                                   hpu_wfi_rsp;
    typedef enum logic[2 : 0] {
        STEP_IDLE, FET_INST, FET_INST_DLY, JUDGE_SUC, WAIT_RETIRE
    } step_fsm;
    step_fsm                                step_st;
    logic                                   step_fetch_en;
    pri_e                                   hpu_pri;
    logic                                   hpu_dmode;
    data_t                                  wdata;
    csr_mstatus_t                           csr_mstatus;
    csr_mie_t                               csr_mie;
    csr_mtvec_t                             csr_mtvec;
    data_t                                  csr_mscratch;
    csr_mcause_t                            csr_mcause;
    data_t                                  csr_mtval;
    pc_t                                    csr_mepc;
    csr_dcsr_t                              csr_dcsr;
    pc_t                                    csr_dpc;
    data_t                                  csr_dscratch0;
    data_t                                  csr_dscratch1;
    data_t                                  csr_dscratch2;
    data_t                                  csr_dscratch3;
    csr_mip_t                               csr_mip;
    intr_e                                  intr_code;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            {restart, restart_sync0} <= 2'h3;
            {mode_single_step, mode_single_step_sync0} <= 2'h0;
            {mode_scalar, mode_scalar_sync0} <= 2'h0;
            {mode_super_scalar, mode_super_scalar_sync0} <= 2'h0;
            {init_pc, init_pc_sync0} <= {2{pc_t'(0)}};
        end else begin
            {restart, restart_sync0} <= {restart_sync0, sys_hpu__restart_i};
            {mode_single_step, mode_single_step_sync0} <= {mode_single_step_sync0, sys_hpu__mode_single_step_i};
            {mode_scalar, mode_scalar_sync0} <= {mode_scalar_sync0, sys_hpu__mode_scalar_i};
            {mode_super_scalar, mode_super_scalar_sync0} <= {mode_super_scalar_sync0, sys_hpu__mode_super_scalar_i};
            {init_pc, init_pc_sync0} <= {init_pc_sync0, sys_hpu__init_pc_i};
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            arc_pc_pre <= pc_t'(0);
        end else begin
            if(ctrl_if__update_npc_en_o) begin
                arc_pc_pre <= ctrl_if__update_npc_o;
            end else begin
                arc_pc_pre <= arc_pc;
            end
        end
    end
    always_comb begin
        arc_pc = arc_pc_pre;
        if(rob_ctrl__cmd_i.en) begin
            arc_pc = rob_ctrl__cmd_i.npc;
        end
        if(cur_st == PIP_INIT) begin
            arc_pc = init_pc;
        end
    end
    assign safemd_arc_pc_o = arc_pc;
    always_comb begin
        if(mode_super_scalar) begin
            proc_mode = PRC_MULTI;
        end else if(mode_scalar) begin
            proc_mode = PRC_SINGLE;
        end else begin
            proc_mode = PRC_STEP;
        end
        if(cur_st == PIP_DBG_RUNNING || cur_st == PIP_HARD_STEP) begin
            proc_mode = PRC_STEP;
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            hpu_reset_req <= 1'b1;
        end else begin
            if(restart) begin
                hpu_reset_req <= 1'b1;
            end else if(cur_st == PIP_INIT) begin
                hpu_reset_req <= 1'b0;
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            hpu_dbg_req <= 1'b0;
        end else begin
            if(rob_ctrl__cmd_i.en && ((rob_ctrl__cmd_i.cmd == CMD_SYSC && rob_ctrl__cmd_i.sysc == EBREAK)
            || rob_ctrl__cmd_i.cmd == CMD_TRIG)) begin
                hpu_dbg_req <= 1'b1;
            end else if(dm_ctrl__req_halt_i) begin
                hpu_dbg_req <= 1'b1;
            end 
            if(hpu_dbg_req && hpu_dbg_rsp) begin
                hpu_dbg_req <= 1'b0;
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            hpu_dbgexit_req <= 1'b0;
        end else begin
            if(rob_ctrl__cmd_i.en && (rob_ctrl__cmd_i.cmd == CMD_SYSC && rob_ctrl__cmd_i.sysc == DRET)) begin
                hpu_dbgexit_req <= 1'b1;
            end else if(dm_ctrl__req_resume_i) begin
                hpu_dbgexit_req <= 1'b1;
            end 
            if(hpu_dbgexit_req && hpu_dbgexit_rsp) begin
                hpu_dbgexit_req <= 1'b0;
            end
        end
    end
    assign intr_halt_en = (|(csr_mie & csr_mip) && csr_mstatus.MIE);
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            hpu_intr_req <= 1'b0;
        end else begin
            if(intr_halt_en) begin
                hpu_intr_req <= 1'b1;
            end
            if(hpu_intr_req && hpu_intr_rsp) begin
                hpu_intr_req <= 1'b0;
            end
            if(hpu_wakeup_req && hpu_wakeup_rsp) begin
                hpu_intr_req <= 1'b0;
            end
        end
    end
    assign wakeup_en = |(csr_mie & csr_mip) && (cur_st == PIP_SLEEP);
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            hpu_wakeup_req <= 1'b0;
        end else begin
            if(wakeup_en) begin
                hpu_wakeup_req <= 1'b1;
            end 
            if(hpu_wakeup_req && hpu_wakeup_rsp) begin
                hpu_wakeup_req <= 1'b0;
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            hpu_excp_req <= 1'b0;
            hpu_excp_type <= excp_e'(0);
            hpu_excp_inst <= inst_t'(0);
            hpu_excp_addr <= pc_t'(0);
            hpu_excp_pc <= pc_t'(0);
        end else begin
            if(rob_ctrl__cmd_i.en && rob_ctrl__cmd_i.cmd == CMD_EXCP) begin
                hpu_excp_req <= 1'b1;
                hpu_excp_type <= rob_ctrl__cmd_i.excp_type;
                hpu_excp_inst <= rob_ctrl__cmd_i.excp_inst;
                hpu_excp_addr <= rob_ctrl__cmd_i.excp_addr;
                hpu_excp_pc <= rob_ctrl__cmd_i.npc;
            end else if(rob_ctrl__cmd_i.en && rob_ctrl__cmd_i.cmd == CMD_SYSC && rob_ctrl__cmd_i.sysc == ECALL) begin
                hpu_excp_req <= 1'b1;
                hpu_excp_type <= ENV_CALL_FROM_M_MODE;
                hpu_excp_pc <= rob_ctrl__cmd_i.npc;
            end else if(hpu_excp_req && hpu_excp_rsp) begin
                hpu_excp_req <= 1'b0;
            end
        end
    end
    assign csr_excp_req_o = hpu_excp_req;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            hpu_trapexit_req <= 1'b0;
        end else begin
            if(rob_ctrl__cmd_i.en && rob_ctrl__cmd_i.cmd == CMD_SYSC && rob_ctrl__cmd_i.sysc == MRET) begin
                hpu_trapexit_req <= 1'b1;
            end 
            if(hpu_trapexit_req && hpu_trapexit_rsp) begin
                hpu_trapexit_req <= 1'b0;
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            hpu_wfi_req <= 1'b0;
        end else begin
            if(rob_ctrl__cmd_i.en && rob_ctrl__cmd_i.cmd == CMD_SYSC && rob_ctrl__cmd_i.sysc == WFI) begin
                hpu_wfi_req <= 1'b1;
            end 
            if(hpu_wfi_req && hpu_wfi_rsp) begin
                hpu_wfi_req <= 1'b0;
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            hpu_fencei_req <= 1'b0;
        end else begin
            if(rob_ctrl__cmd_i.en && rob_ctrl__cmd_i.cmd == CMD_SYSC && rob_ctrl__cmd_i.sysc == FENCEI) begin
                hpu_fencei_req <= 1'b1;
            end 
            if(hpu_fencei_req && hpu_fencei_rsp) begin
                hpu_fencei_req <= 1'b0;
            end
        end
    end
    assign mispred_en = rob_ctrl__cmd_i.en && (rob_ctrl__cmd_i.cmd == CMD_MISPRED);
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            instr_retire_en <= 1'b0;
        end else begin
            instr_retire_en <= rob_ctrl__cmd_i.en;
        end
    end
    
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            cur_st <= PIP_INIT;
            last_st <= PIP_INIT;
        end else begin
            cur_st <= next_st;
            last_st <= last_st_comb;
        end
    end
    always_comb begin
        next_st = cur_st;
        set_rsthalt_rsp = 1'b0;
        last_st_comb = last_st;
        hpu_intr_rsp_p2 = 1'b0;
        hpu_wakeup_rsp_p2 = 1'b0;
        hpu_excp_rsp = 1'b0;
        hpu_trapexit_rsp = 1'b0;
        hpu_dbg_rsp_p2 = 1'b0;
        hpu_dbgexit_rsp = 1'b0;
        hpu_fencei_rsp = 1'b0;
        hpu_wfi_rsp = 1'b0;
        case(cur_st)
            PIP_INIT: begin
                if(!hpu_reset_req) begin
                    if(dm_ctrl__req_setrsthalt_i) begin
                        next_st = PIP_DBG_HALT;
                        set_rsthalt_rsp = 1'b1;
                    end else begin
                        next_st = PIP_RUNNING;
                    end
                end
            end
            PIP_RUNNING: begin
                if(hpu_dbg_req | hpu_fencei_req | hpu_wfi_req) begin
                    next_st = PIP_RUNNING_DLY;
                end
                hpu_intr_rsp_p2 = hpu_intr_req;
                hpu_excp_rsp = hpu_excp_req;
                hpu_trapexit_rsp = hpu_trapexit_req;
            end
            PIP_RUNNING_DLY: begin
                if(lsu_ctrl__sq_retire_empty_i) begin
                    if(hpu_dbg_req && hpu_dbg_rsp) begin
                        next_st = PIP_DBG_HALT;
                    end else if(hpu_fencei_req) begin
                        next_st = PIP_FLUSH_IC;
                        last_st_comb = PIP_RUNNING;
                        hpu_fencei_rsp = 1'b1;
                    end else if(hpu_wfi_req) begin
                        next_st = PIP_SLEEP;
                        hpu_wfi_rsp = 1'b1;
                    end
                    hpu_dbg_rsp_p2 = hpu_dbg_req;
                end
            end
            PIP_DBG_HALT: begin
                if(hpu_dbgexit_req) begin
                    if(csr_dcsr.stepie) begin
                        next_st = PIP_HARD_STEP;
                    end else begin
                        next_st = PIP_RUNNING;
                    end
                    hpu_dbgexit_rsp = 1'b1;
                end else if(dm_ctrl__start_cmd_i) begin
                    next_st = PIP_DBG_RUNNING;
                end
            end
            PIP_DBG_RUNNING: begin
                if(hpu_dbgexit_req) begin
                    if(csr_dcsr.stepie) begin
                        next_st = PIP_HARD_STEP;
                    end else begin
                        next_st = PIP_RUNNING;
                    end
                    hpu_dbgexit_rsp = 1'b1;
                end else if(hpu_dbg_req && hpu_dbg_rsp) begin
                    next_st = PIP_DBG_HALT;
                end else if(hpu_fencei_req) begin
                    next_st = PIP_FLUSH_IC;
                    last_st_comb = PIP_DBG_RUNNING;
                    hpu_fencei_rsp = 1'b1;
                end
                hpu_dbg_rsp_p2 = hpu_dbg_req;
            end
            PIP_HARD_STEP: begin
                if(rob_ctrl__cmd_i.en) begin
                    next_st = PIP_HARD_STEP_DLY;
                end
            end
            PIP_HARD_STEP_DLY: begin
                if(hpu_fencei_req) begin
                    next_st = PIP_FLUSH_IC;
                    last_st_comb = PIP_DBG_HALT;
                    hpu_fencei_rsp = 1'b1;
                end else if(lsu_ctrl__sq_retire_empty_i) begin
                    next_st = PIP_DBG_HALT;
                end
            end
            PIP_SLEEP: begin
                if(hpu_dbg_req && hpu_dbg_rsp) begin
                    next_st = PIP_DBG_HALT;
                end else if(hpu_wakeup_req && hpu_wakeup_rsp) begin
                    next_st = PIP_RUNNING;
                end
                hpu_dbg_rsp_p2 = hpu_dbg_req;
                hpu_wakeup_rsp_p2 = hpu_wakeup_req;
            end
            PIP_FLUSH_IC: begin
                next_st = PIP_FLUSH_IC_DLY;
            end
            PIP_FLUSH_IC_DLY: begin
                if(ic_ctrl__flush_done_i) begin
                    next_st = last_st;
                end
            end
        endcase
        if(hpu_reset_req) begin
            next_st = PIP_INIT;
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            hpu_intr_rsp_p1 <= 1'b0;
            hpu_intr_rsp <= 1'b0;
            hpu_wakeup_rsp_p1 <= 1'b0;
            hpu_wakeup_rsp <= 1'b0;
            hpu_dbg_rsp_p1 <= 1'b0;
            hpu_dbg_rsp <= 1'b0;
        end else begin
            {hpu_intr_rsp, hpu_intr_rsp_p1} <= {hpu_intr_rsp_p1, hpu_intr_rsp_p2};
            {hpu_wakeup_rsp, hpu_wakeup_rsp_p1} <= {hpu_wakeup_rsp_p1, hpu_wakeup_rsp_p2};
            {hpu_dbg_rsp, hpu_dbg_rsp_p1} <= {hpu_dbg_rsp_p1, hpu_dbg_rsp_p2};
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ctrl_darb__rspd_en_o <= 1'b0;
            ctrl_darb__rspd_data_o <= RSPD_EXCP;
        end else begin
            if((cur_st != PIP_DBG_HALT) && (next_st == PIP_DBG_HALT)) begin
                ctrl_darb__rspd_en_o <= 1'b1;
                ctrl_darb__rspd_data_o <= RSPD_HALT;
            end else if((cur_st != PIP_DBG_RUNNING) && (next_st == PIP_DBG_RUNNING)) begin
                ctrl_darb__rspd_en_o <= 1'b1;
                ctrl_darb__rspd_data_o <= RSPD_CMD;
            end else if((cur_st == PIP_DBG_HALT) && (next_st == PIP_RUNNING)) begin
                ctrl_darb__rspd_en_o <= 1'b1;
                ctrl_darb__rspd_data_o <= RSPD_RESUME;
            end else if((cur_st == PIP_DBG_RUNNING) && (hpu_excp_req)) begin
                ctrl_darb__rspd_en_o <= 1'b1;
                ctrl_darb__rspd_data_o <= RSPD_EXCP;
            end else begin
                ctrl_darb__rspd_en_o <= 1'b0;
                ctrl_darb__rspd_data_o <= RSPD_EXCP;
            end
        end
    end
    assign ctrl_dm__status_halted_o = (cur_st == PIP_DBG_HALT) || (cur_st == PIP_DBG_RUNNING);
    assign ctrl_dm__status_running_o = (cur_st == PIP_RUNNING) || (cur_st == PIP_HARD_STEP);
    assign ctrl_dm__status_havereset_o = (cur_st == PIP_INIT);
    assign ctrl_dm__unavailable_o = (cur_st == PIP_INIT);
    assign ctrl_dm__hartinfo_o = 32'h0040_47b2;
    assign ctrl_ic__flush_req_o = (cur_st == PIP_FLUSH_IC);
    assign hpu_sys__wfi_act_o = (cur_st == PIP_SLEEP);
    assign ctrl_rob__stall_en_o = hpu_intr_req || hpu_dbg_req
        || (restart || hpu_reset_req);
    always_comb begin
        ctrl_if__single_fetch_en_o = 1'b0;
        ctrl_if__normal_fetch_en_o = 1'b0;
        if(cur_st == PIP_RUNNING || cur_st == PIP_HARD_STEP || cur_st == PIP_DBG_RUNNING) begin
            case(proc_mode)
                PRC_STEP: begin
                    ctrl_if__single_fetch_en_o = step_fetch_en;
                end
                PRC_SINGLE: begin
                    ctrl_if__single_fetch_en_o = 1'b1;
                end
                PRC_MULTI: begin
                    ctrl_if__normal_fetch_en_o = 1'b1;
                end
            endcase
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            step_st <= STEP_IDLE;
        end else begin
            if((cur_st == PIP_RUNNING || cur_st == PIP_HARD_STEP || cur_st == PIP_DBG_RUNNING)
            && (proc_mode == PRC_STEP)) begin
                case(step_st)
                    STEP_IDLE: begin
                        step_st <= FET_INST;
                    end
                    FET_INST: begin
                        step_st <= FET_INST_DLY;
                    end
                    FET_INST_DLY: begin
                        step_st <= JUDGE_SUC;
                    end
                    JUDGE_SUC: begin
                        if(if_ctrl__inst_fetch_suc_i) begin
                            step_st <= WAIT_RETIRE;
                        end else begin
                            step_st <= FET_INST;
                        end
                    end
                    WAIT_RETIRE: begin
                        if(instr_retire_en) begin
                            step_st <= FET_INST;
                        end
                    end
                endcase
                if(ctrl__inst_flush_en_o) begin
                    step_st <= STEP_IDLE;
                end
            end else begin
                step_st <= STEP_IDLE;
            end
        end
    end
    assign step_fetch_en = (step_st == FET_INST);
    always_comb begin
        ctrl__inst_flush_en_o = 1'b0;
        ctrl_if__update_npc_en_o = 1'b0;
        ctrl_if__update_npc_o = pc_t'(0);
        case(cur_st)
            PIP_INIT: begin
                ctrl__inst_flush_en_o = 1'b1;
                ctrl_if__update_npc_en_o = 1'b1;
                if(dm_ctrl__req_setrsthalt_i) begin
                    ctrl_if__update_npc_o = LCM_DEBUG_START;
                end else begin
                    ctrl_if__update_npc_o = init_pc;
                end
            end
            PIP_RUNNING: begin
                ctrl__inst_flush_en_o = mispred_en
                    || (hpu_intr_req&& hpu_intr_rsp)
                    || (hpu_excp_req && hpu_excp_rsp)
                    || (hpu_trapexit_req && hpu_trapexit_rsp);
                ctrl_if__update_npc_en_o = mispred_en
                    || (hpu_intr_req&& hpu_intr_rsp)
                    || (hpu_excp_req && hpu_excp_rsp)
                    || (hpu_trapexit_req && hpu_trapexit_rsp);
                if(mispred_en) begin
                    ctrl_if__update_npc_o = rob_ctrl__cmd_i.npc;
                end else if(hpu_intr_req&& hpu_intr_rsp) begin
                    ctrl_if__update_npc_o = (csr_mtvec.MODE == MODE_DIRECT) ? {csr_mtvec.BASE, 2'h0}
                        : {csr_mtvec.BASE, 2'h0} + pc_t'({csr_mcause.ecode, 2'h0});
                end else if(hpu_excp_req && hpu_excp_rsp) begin
                    ctrl_if__update_npc_o = {csr_mtvec.BASE, 2'h0};
                end else if(hpu_trapexit_req && hpu_trapexit_rsp) begin
                    ctrl_if__update_npc_o = csr_mepc;
                end
            end
            PIP_RUNNING_DLY: begin
                ctrl__inst_flush_en_o = (hpu_dbg_req && hpu_dbg_rsp)
                    || (hpu_wfi_req && hpu_wfi_rsp)
            || (hpu_fencei_req && hpu_fencei_rsp);
                ctrl_if__update_npc_en_o = (hpu_dbg_req && hpu_dbg_rsp);
                if(hpu_dbg_req && hpu_dbg_rsp) begin
                    ctrl_if__update_npc_o = LCM_DEBUG_START;
                end
            end
            PIP_FLUSH_IC_DLY: begin
                ctrl__inst_flush_en_o = ic_ctrl__flush_done_i;
                ctrl_if__update_npc_en_o = ic_ctrl__flush_done_i;
                ctrl_if__update_npc_o = arc_pc + 4;
            end
            PIP_SLEEP: begin
                ctrl__inst_flush_en_o = (hpu_dbg_req && hpu_dbg_rsp) || (hpu_wakeup_req && hpu_wakeup_rsp);
                ctrl_if__update_npc_en_o = (hpu_dbg_req && hpu_dbg_rsp) || (hpu_wakeup_req && hpu_wakeup_rsp);
                if(hpu_dbg_req && hpu_dbg_rsp) begin
                    ctrl_if__update_npc_o = LCM_DEBUG_START;
                end else if(hpu_wakeup_req && hpu_wakeup_rsp) begin
                    if(hpu_intr_req) begin
                        ctrl_if__update_npc_o = (csr_mtvec.MODE == MODE_DIRECT) ? {csr_mtvec.BASE, 2'h0}
                            : {csr_mtvec.BASE, 2'h0} + pc_t'({csr_mcause.ecode, 2'h0});
                    end else begin
                        ctrl_if__update_npc_o = arc_pc + 4;
                    end
                end
            end
            PIP_DBG_HALT: begin
                ctrl__inst_flush_en_o = (hpu_dbgexit_req && hpu_dbgexit_rsp);
                ctrl_if__update_npc_en_o = (hpu_dbgexit_req && hpu_dbgexit_rsp);
                if(hpu_dbgexit_req && hpu_dbgexit_rsp) begin
                    ctrl_if__update_npc_o = csr_dpc;
                end
            end
            PIP_DBG_RUNNING: begin
                ctrl__inst_flush_en_o = mispred_en || (hpu_excp_req && hpu_excp_rsp)
                    || (hpu_dbg_req && hpu_dbg_rsp) || (hpu_fencei_req && hpu_fencei_rsp)
                    || (hpu_dbgexit_req && hpu_dbgexit_rsp);
                ctrl_if__update_npc_en_o = mispred_en || (hpu_dbg_req && hpu_dbg_rsp)
                    || (hpu_dbgexit_req && hpu_dbgexit_rsp);
                if(mispred_en) begin
                    ctrl_if__update_npc_o = rob_ctrl__cmd_i.npc;
		end else if(hpu_dbgexit_req && hpu_dbgexit_rsp) begin
                    ctrl_if__update_npc_o = csr_dpc;
                end else if(hpu_dbg_req && hpu_dbg_rsp) begin
                    ctrl_if__update_npc_o = LCM_DEBUG_START;
                end
            end
        endcase
    end
    assign ctrl_if__btb_flush_en_o = (cur_st == PIP_INIT) ? 1'b1 : 1'b0;
    assign ctrl_if__ras_flush_en_o = (cur_st == PIP_INIT) ? 1'b1 : 1'b0;
    assign ctrl_if__fgpr_flush_en_o = (cur_st == PIP_INIT) ? 1'b1 : 1'b0;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            hpm_mco_arch_eve_o <= data_t'(0);
        end else begin
            hpm_mco_arch_eve_o <= data_t'(0);
            hpm_mco_arch_eve_o[BID_MISP] <= rob_ctrl__cmd_i.en && rob_ctrl__cmd_i.bid_mispred;
            hpm_mco_arch_eve_o[JBR_MISP] <= rob_ctrl__cmd_i.en && (rob_ctrl__cmd_i.cmd == CMD_MISPRED);
            hpm_mco_arch_eve_o[CSR_FLUSH] <= 1'b0;
            hpm_mco_arch_eve_o[MISC_FLUSH] <= rob_ctrl__cmd_i.en && (rob_ctrl__cmd_i.cmd != CMD_NORMAL)
                && !hpm_mco_arch_eve_o[BID_MISP]
                && !hpm_mco_arch_eve_o[JBR_MISP]
                && !hpm_mco_arch_eve_o[CSR_FLUSH];
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            hpu_pri <= M_MODE;
            hpu_dmode <= 1'b0;
        end else begin
            if(hpu_trapexit_req && hpu_trapexit_rsp) begin
                hpu_pri <= pri_e'(csr_mstatus.MPP);
            end
            if(hpu_dbg_req && hpu_dbg_rsp) begin
                hpu_dmode <= 1'b1;
            end else if(hpu_dbgexit_req && hpu_dbgexit_rsp) begin
                hpu_dmode <= 1'b0;
            end
        end
    end
    assign ctrl__hpu_dmode_o = hpu_dmode;
    assign wdata = csr_ctrl__bus_req_i.wdata;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            csr_mstatus <= csr_mstatus_t'(0);
            csr_mie <= csr_mie_t'(0);
            csr_mtvec <= csr_mtvec_t'(32'h8000_0000);
            csr_mscratch <= data_t'(0);
            csr_mcause <= csr_mcause_t'(0);
            csr_mtval <= data_t'(0);
            csr_mepc <= pc_t'(32'h8000_0000);
            csr_dcsr <= csr_dcsr_t'(32'h4000_0003);
            csr_dpc <= pc_t'(0);
            csr_dscratch0 <= data_t'(0);
            csr_dscratch1 <= data_t'(0);
            csr_dscratch2 <= data_t'(0);
            csr_dscratch3 <= data_t'(0);
        end else begin
            if(csr_ctrl__bus_req_i.wr_en) begin
                case(csr_ctrl__bus_req_i.waddr)
                    CSR_ADDR_MTPS_MSTATUS: csr_mstatus <= csr_mstatus_t'(wdata);
                    CSR_ADDR_MTPS_MIE: csr_mie <= csr_mie_t'(wdata);
                    CSR_ADDR_MTPS_MTVEC: csr_mtvec <= csr_mtvec_t'(wdata);
                    CSR_ADDR_MTPH_MSCRATCH: csr_mscratch <= wdata;
                    CSR_ADDR_MTPH_MCAUSE: csr_mcause <= csr_mcause_t'(wdata);
                    CSR_ADDR_MTPH_MTVAL: csr_mtval <= wdata;
                    CSR_ADDR_MTPH_MEPC: csr_mepc <= pc_t'(wdata);
                    CSR_ADDR_DBG_DCSR: csr_dcsr <= csr_dcsr_t'({16'h4000,wdata[15:9],csr_dcsr[8:5],wdata[4],
                                                                1'b0,wdata[2:0]});
                    CSR_ADDR_DBG_DPC: csr_dpc <= pc_t'(wdata);
                    CSR_ADDR_DBG_SCRATCH0: csr_dscratch0 <= data_t'(wdata);
                    CSR_ADDR_DBG_SCRATCH1: csr_dscratch1 <= data_t'(wdata);
                    CSR_ADDR_DBG_SCRATCH2: csr_dscratch2 <= data_t'(wdata);
                    CSR_ADDR_DBG_SCRATCH3: csr_dscratch3 <= data_t'(wdata);
                endcase
            end
            if((hpu_intr_req && hpu_intr_rsp) || (hpu_excp_req && hpu_excp_rsp)
                || (hpu_wakeup_req && hpu_wakeup_rsp && hpu_intr_req) ) begin
                csr_mepc <= (cur_st == PIP_SLEEP) ? arc_pc + 4 : arc_pc;
                csr_mstatus.MPP <= hpu_pri;
                csr_mstatus.MPIE <= csr_mstatus.MIE;
                csr_mstatus.MIE <= 1'b0;
            end
            if(hpu_trapexit_req && hpu_trapexit_rsp) begin
                csr_mstatus.MPP <= M_MODE;
                csr_mstatus.MPIE <= 1'b0;
                csr_mstatus.MIE <= csr_mstatus.MPIE;
            end
            if((dm_ctrl__req_setrsthalt_i && set_rsthalt_rsp) || (hpu_dbg_req && hpu_dbg_rsp)) begin
                if(cur_st == PIP_INIT || cur_st == PIP_RUNNING || cur_st == PIP_RUNNING_DLY) begin
                    csr_dpc <= arc_pc;
                end else if(cur_st == PIP_SLEEP) begin
                    csr_dpc <= arc_pc + 4;
                end
            end
            if(|(csr_mie & csr_mip) && csr_mstatus.MIE) begin
                csr_mcause.is_intr <= 1'b1;
                csr_mcause.ecode.intr <= intr_code;
                csr_mtval <= data_t'(0);
            end else if(hpu_excp_req && hpu_excp_rsp) begin
                csr_mcause.is_intr <= 1'b0;
                csr_mcause.ecode.excp <= hpu_excp_type;
                case(hpu_excp_type)
                    ILLEGAL_INST: begin
                        csr_mtval <= hpu_excp_inst;
                    end
                    BREAK_POINT, INST_ADDR_MISALIGNED, INST_ACCESS_FAULT, INST_PAGE_FAULT: begin
                        csr_mtval <= hpu_excp_pc;
                    end
                    LD_ADDR_MISALIGNED, LD_ACCESS_FAULT, LD_PAGE_FAULT,
                    ST_AMO_ACCESS_FAULT, ST_AMO_ADDR_MISALIGNED, ST_AMO_PAGE_FAULT: begin
                        csr_mtval <= data_t'(hpu_excp_addr);
                    end
                    ENV_CALL_FROM_M_MODE: begin
                        csr_mtval <= hpu_excp_pc;
                    end
                    default: begin
                        csr_mtval <= data_t'(0);
                    end
                endcase
            end
        end
    end
    assign csr_mip = clint_ctrl__intr_act_i;
    always_comb begin
        if(csr_mie.COPIE && csr_mip.COPIP) begin
            intr_code = COP_MODE;
        end else if(csr_mie.NDMAIE && csr_mip.NDMAIP) begin
            intr_code = NDMA_MODE;
        end else if(csr_mie.ICIE && csr_mip.ICIP) begin
            intr_code = IC_MODE;
        end else if(csr_mie.DCIE && csr_mip.DCIP) begin
            intr_code = DC_MODE;
        end else if(csr_mie.L2CIE && csr_mip.L2CIP) begin
            intr_code = L2C_MODE;
        end else if(csr_mie.MEIE && csr_mip.MEIP) begin
            intr_code = EXT_M_MODE;
        end else if(csr_mie.MSIE && csr_mip.MSIP) begin
            intr_code = SOFTWARE_M_MODE;
        end else if(csr_mie.MTIE && csr_mip.MTIP) begin
            intr_code = TIMER_M_MODE;
        end else begin
            intr_code = SOFTWARE_U_MODE;
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            ctrl_csr__bus_rsp_o.rdata <= data_t'(0);
        end else begin
            if(csr_ctrl__bus_req_i.rd_en) begin
                case(csr_ctrl__bus_req_i.raddr)
                    CSR_ADDR_MTPS_MSTATUS: ctrl_csr__bus_rsp_o.rdata <= data_t'(csr_mstatus);
                    CSR_ADDR_MTPS_MIE: ctrl_csr__bus_rsp_o.rdata <= data_t'(csr_mie);
                    CSR_ADDR_MTPS_MTVEC: ctrl_csr__bus_rsp_o.rdata <= data_t'(csr_mtvec);
                    CSR_ADDR_MTPH_MSCRATCH: ctrl_csr__bus_rsp_o.rdata <= data_t'(csr_mscratch);
                    CSR_ADDR_MTPH_MIP: ctrl_csr__bus_rsp_o.rdata <= data_t'(csr_mip);
                    CSR_ADDR_MTPH_MCAUSE: ctrl_csr__bus_rsp_o.rdata <= data_t'(csr_mcause);
                    CSR_ADDR_MTPH_MTVAL: ctrl_csr__bus_rsp_o.rdata <= csr_mtval;
                    CSR_ADDR_MTPH_MEPC: ctrl_csr__bus_rsp_o.rdata <= data_t'(csr_mepc);
                    CSR_ADDR_DBG_DCSR: ctrl_csr__bus_rsp_o.rdata <= data_t'(csr_dcsr);
                    CSR_ADDR_DBG_DPC: ctrl_csr__bus_rsp_o.rdata <= data_t'(csr_dpc);
                    CSR_ADDR_DBG_SCRATCH0: ctrl_csr__bus_rsp_o.rdata <= csr_dscratch0;
                    CSR_ADDR_DBG_SCRATCH1: ctrl_csr__bus_rsp_o.rdata <= csr_dscratch1;
                    CSR_ADDR_DBG_SCRATCH2: ctrl_csr__bus_rsp_o.rdata <= csr_dscratch2;
                    CSR_ADDR_DBG_SCRATCH3: ctrl_csr__bus_rsp_o.rdata <= csr_dscratch3;
                endcase
            end
        end
    end
    assign csr_mstatus_o = csr_mstatus;
    assign csr_mie_o = csr_mie;
    assign csr_mip_o = csr_mip;
    assign csr_mtvec_o = csr_mtvec;
    assign csr_mcause_o = csr_mcause;
    assign csr_mtval_o = csr_mtval;
    assign csr_mepc_o = csr_mepc;
    pc_t prb_arc_pc;
    pip_fsm prb_hpu_st;
    hpu_mode_e prb_proc_mode;
    assign prb_arc_pc = arc_pc;
    assign prb_hpu_st = cur_st;
    assign prb_proc_mode = proc_mode;
endmodule : hpu_ctrl
