`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_rob_trigger (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   logic                                   ctrl__hpu_dmode_i,
    input   csr_bus_req_t                           csr_trig__bus_req_i,
    output  csr_bus_rsp_t                           trig_csr__bus_rsp_o,
    input   logic                                   inst_could_retire_i,
    input   logic[INST_DEC_BIT-1 : 0]               inst_offset_first_i,
    input   logic[INST_DEC_BIT-1 : 0]               inst_offset_last_i,
    input   inst_trig_info_t[INST_DEC_PARAL-1 : 0]  inst_trig_info_i,
    input   logic                                   rob_is_stall_i,
    input   data_t                                  csr_mie_i,
    input   data_t                                  csr_mcause_i,
    input   data_t                                  csr_mip_i,
    input   logic                                   csr_excp_req_i,
    output  logic                                   trig_hit_en_o,
    output  logic[INST_DEC_BIT : 0]                 trig_hit_fence_o,
    output  logic                                   trig_hit_timing_o
);
    logic                                   debug_mode_en;
    data_t                                  csr_wdata;
    logic[TRIG_NUM_BIT-1 : 0]               csr_trig_tselect;
    csr_trig_tdata1_t[TRIG_NUM-1 : 0]       csr_trig_tdata1;
    data_t[TRIG_NUM-1 : 0]                  csr_trig_tdata2;
    csr_trig_tdata3_t[TRIG_NUM-1 : 0]       csr_trig_tdata3;
    data_t[TRIG_NUM-1 : 0]                  csr_trig_tinfo;
    data_t[TRIG_NUM-1 : 0]                  csr_trig_tcontrol;
    data_t[TRIG_NUM-1 : 0]                  csr_trig_mcontext;
    data_t[TRIG_NUM-1 : 0]                  csr_trig_scontext;
    data_t[TRIG_NUM-1 : 0]                  icount_per_inst[INST_DEC_PARAL-1 : 0];
    logic[INST_DEC_BIT : 0]                 inst_act_psum[INST_DEC_PARAL-1 : 0];
    logic[INST_DEC_BIT : 0]                 inst_act_sum;
    data_t[TRIG_NUM-1 : 0]                  trig_match_mask;
    logic[TRIG_NUM-1 : 0]                   trig_chain;
    logic[TRIG_NUM-1 : 0]                   trig_timing;
    data_t[TRIG_NUM-1 : 0][INST_DEC_PARAL-1 : 0]    trig_probe_data;
    logic[TRIG_NUM-1 : 0][INST_DEC_PARAL-1 : 0]     trig_probe_act;
    logic[TRIG_NUM-1 : 0][INST_DEC_PARAL-1 : 0]     trig_match;
    logic[TRIG_NUM-1 : 0][INST_DEC_PARAL-1 : 0]     tsel_is_hit;
    logic[TRIG_NUM-1 : 0]                   trig_chain_r1;
    logic[TRIG_NUM-1 : 0]                   trig_timing_r1;
    logic[TRIG_NUM-1 : 0][INST_DEC_PARAL-1 : 0]     tsel_is_hit_r1;
    logic                                   debug_mode_en_r1;
    logic                                   inst_could_retire_r1;
    logic[TRIG_NUM-1 : 0]                   logi_and_rslt[INST_DEC_PARAL-1 : 0];
    logic[INST_DEC_PARAL-1 : 0]             trig_hit;
    logic[INST_DEC_PARAL-1 : 0]             trig_mask;
    assign debug_mode_en = ctrl__hpu_dmode_i;
    assign csr_wdata = csr_trig__bus_req_i.wdata;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            csr_trig_tselect <= {TRIG_NUM_BIT{1'b0}};
            for(integer i=0; i<TRIG_NUM; i=i+1) begin
                csr_trig_tdata1[i] <= csr_trig_tdata1_t'(0);
                csr_trig_tdata2[i] <= data_t'(0);
                csr_trig_tdata3[i] <= csr_trig_tdata3_t'(0);
                csr_trig_tinfo[i] <= data_t'(6'h3c);
                csr_trig_tcontrol[i] <= data_t'(0);
                csr_trig_mcontext[i] <= data_t'(0);
                csr_trig_scontext[i] <= data_t'(0);
                for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                    icount_per_inst[j] <= data_t'(0);
                end
            end
        end else begin
            if(csr_trig__bus_req_i.wr_en && debug_mode_en) begin
                case(csr_trig__bus_req_i.waddr)
                    CSR_ADDR_DBG_TSELECT: csr_trig_tselect <= csr_wdata[TRIG_NUM_BIT-1 : 0];
                    CSR_ADDR_DBG_TDATA1: csr_trig_tdata1[csr_trig_tselect] <= csr_trig_tdata1_t'(csr_wdata);
                    CSR_ADDR_DBG_TDATA2: csr_trig_tdata2[csr_trig_tselect] <= csr_wdata;
                    CSR_ADDR_DBG_TDATA3: csr_trig_tdata3[csr_trig_tselect] <= csr_trig_tdata3_t'(csr_wdata);
                    CSR_ADDR_DBG_TCONTROL: csr_trig_tcontrol[csr_trig_tselect] <= csr_wdata;
                    CSR_ADDR_DBG_MCONTEXT: csr_trig_mcontext[csr_trig_tselect] <= csr_wdata;
                    CSR_ADDR_DBG_SCONTEXT: csr_trig_scontext[csr_trig_tselect] <= csr_wdata;
                endcase
            end 
            if(!debug_mode_en) begin
                for(integer i=0; i<TRIG_NUM; i=i+1) begin
                    case(csr_trig_tdata1[i].common.typ)
                        TRIG_TYPE_MCONTROL: begin
                            if(tsel_is_hit[i]) begin
                                csr_trig_tdata1[i].mcontrol.hit <= 1'b1;
                            end
                        end
                        TRIG_TYPE_ICOUNT: begin
                            if(tsel_is_hit[i]) begin
                                csr_trig_tdata1[i].icount.hit <= 1'b1;
                            end
                            if(inst_act_sum) begin
                                if($signed(csr_trig_tdata1[i].icount.count - inst_act_sum) > 0) begin
                                    csr_trig_tdata1[i].icount.count <= csr_trig_tdata1[i].icount.count - inst_act_sum;
                                end else begin
                                    csr_trig_tdata1[i].icount.count <= 0;
                                end
                                for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                                    icount_per_inst[j] <= csr_trig_tdata1[i].icount.count - inst_act_psum[j];
                                end
                            end
                        end
                        TRIG_TYPE_ITRIGGER, TRIG_TYPE_ETRIGGER: begin
                            if(tsel_is_hit[i]) begin
                                csr_trig_tdata1[i].ietrigger.hit <= 1'b1;
                            end
                        end
                    endcase
                end
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            trig_csr__bus_rsp_o.rdata <= data_t'(0);
        end else begin
            if(csr_trig__bus_req_i.rd_en) begin
                case(csr_trig__bus_req_i.raddr)
                    CSR_ADDR_DBG_TSELECT: trig_csr__bus_rsp_o.rdata <= data_t'(csr_trig_tselect);
                    CSR_ADDR_DBG_TDATA1: trig_csr__bus_rsp_o.rdata <= data_t'(csr_trig_tdata1[csr_trig_tselect]);
                    CSR_ADDR_DBG_TDATA2: trig_csr__bus_rsp_o.rdata <= data_t'(csr_trig_tdata2[csr_trig_tselect]);
                    CSR_ADDR_DBG_TDATA3: trig_csr__bus_rsp_o.rdata <= data_t'(csr_trig_tdata3[csr_trig_tselect]);
                    CSR_ADDR_DBG_TCONTROL: trig_csr__bus_rsp_o.rdata <= csr_trig_tcontrol[csr_trig_tselect];
                    CSR_ADDR_DBG_MCONTEXT: trig_csr__bus_rsp_o.rdata <= csr_trig_mcontext[csr_trig_tselect];
                    CSR_ADDR_DBG_SCONTEXT: trig_csr__bus_rsp_o.rdata <= csr_trig_scontext[csr_trig_tselect];
                    default: trig_csr__bus_rsp_o.rdata <= data_t'(0);
                endcase
            end
        end
    end
    always_comb begin
        for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
            if(i==0) begin
                inst_act_psum[0] = inst_could_retire_i && inst_trig_info_i[0].avail
                    && (i>=inst_offset_first_i && i<=inst_offset_last_i);
            end else begin
                inst_act_psum[i] = inst_act_psum[i-1] + (inst_could_retire_i && inst_trig_info_i[1].avail
                    && (i>=inst_offset_first_i && i<=inst_offset_last_i));
            end
        end
        inst_act_sum = inst_act_psum[INST_DEC_PARAL-1];
    end
    for(genvar gi=0; gi<TRIG_NUM; gi=gi+1) begin : trig_sub_blk
        assign trig_match_mask[gi] = csr_trig_tdata2[gi] & (csr_trig_tdata2[gi] + 1'b1);
        assign trig_chain[gi] = (csr_trig_tdata1[gi].common.typ == TRIG_TYPE_MCONTROL) ?
            csr_trig_tdata1[gi].mcontrol.chain : 1'b0;
        assign trig_timing[gi] = get_trig_timing(csr_trig_tdata1[gi]);
        
        assign trig_probe_data[gi] = get_trig_probe(csr_trig_tdata1[gi], inst_trig_info_i);
        assign trig_probe_act[gi] = get_trig_probe_act(csr_trig_tdata1[gi], inst_trig_info_i, inst_could_retire_i);
        for(genvar gj=0; gj<INST_DEC_PARAL; gj=gj+1) begin : trig_dec_paral
            always_comb begin
                trig_match[gi][gj] = 1'b0;
                case(csr_trig_tdata1[gi].common.typ)
                    TRIG_TYPE_MCONTROL: begin
                        case(csr_trig_tdata1[gi].mcontrol.match)
                            4'h0: trig_match[gi][gj] = (trig_probe_data[gi][gj] == csr_trig_tdata2[gi]);
                            4'h1: trig_match[gi][gj] = (trig_probe_data[gi][gj] & trig_match_mask[gi])
                                                     == (csr_trig_tdata2[gi] & trig_match_mask[gi]);
                            4'h2: trig_match[gi][gj] = (trig_probe_data[gi][gj] >= csr_trig_tdata2[gi]);
                            4'h3: trig_match[gi][gj] = (trig_probe_data[gi][gj] < csr_trig_tdata2[gi]);
                            4'h4: trig_match[gi][gj] = (trig_probe_data[gi][gj][15:0] & csr_trig_tdata2[gi][31:16])
                                                     == csr_trig_tdata2[gi][15:0];
                            4'h5: trig_match[gi][gj] = (trig_probe_data[gi][gj][31:16] & csr_trig_tdata2[gi][31:16])
                                                     == csr_trig_tdata2[gi][15:0];
                        endcase
                    end
                    TRIG_TYPE_ICOUNT: begin
                        trig_match[gi][gj] = (icount_per_inst[gj][gi] == 0);
                    end
                    TRIG_TYPE_ITRIGGER: begin
                        trig_match[gi][gj] = |(csr_trig_tdata2[gi] & csr_mie_i & csr_mip_i);
                    end
                    TRIG_TYPE_ETRIGGER: begin
                        trig_match[gi][gj] = |(csr_trig_tdata2[gi] & csr_mcause_i) & csr_excp_req_i;
                    end
                    default: begin
                        trig_match[gi][gj] = 1'b0;
                    end
                endcase
            end
            assign tsel_is_hit[gi][gj] = trig_match[gi][gj] & trig_probe_act[gi][gj]
                && (gj>=inst_offset_first_i && gj<=inst_offset_last_i);
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=0; i<TRIG_NUM; i=i+1) begin
                trig_chain_r1[i] <= 1'b0;
                trig_timing_r1[i] <= 1'b0;
                tsel_is_hit_r1[i] <= {INST_DEC_PARAL{1'b0}};
            end
            debug_mode_en_r1 <= 1'b0;
            inst_could_retire_r1 <= 1'b0;
        end else begin
            if(!rob_is_stall_i) begin
                trig_chain_r1 <= trig_chain;
                trig_timing_r1 <= trig_timing;
                tsel_is_hit_r1 <= tsel_is_hit;
            end
            debug_mode_en_r1 <= debug_mode_en;
            inst_could_retire_r1 <= inst_could_retire_i;
        end
    end
    always_comb begin
        for(integer i=0; i<TRIG_NUM; i=i+1) begin
            for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                if(i==0) begin
                    logi_and_rslt[j][0] = tsel_is_hit_r1[0][j];
                end else begin
                    logi_and_rslt[j][i] = trig_chain_r1[i-1] ? logi_and_rslt[j][i-1] & tsel_is_hit_r1[i][j]
                                                          : tsel_is_hit_r1[i][j];
                end
            end
        end
    end
    always_comb begin
        trig_hit_en_o = 1'b0;
        trig_hit_fence_o = {1'b1, {INST_DEC_BIT{1'b0}}};
        trig_hit_timing_o = 1'b0;
        for(integer i=INST_DEC_PARAL-1; i>=0; i=i-1) begin
            trig_hit[i] = |(logi_and_rslt[i] & ~trig_chain_r1);
            if(trig_hit[i]) begin
                trig_hit_en_o = trig_hit[i] & ~trig_mask[i] & ~debug_mode_en;
                trig_hit_fence_o = i;
                trig_hit_timing_o = |(trig_timing_r1 & ~trig_chain_r1);
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            trig_mask <= INST_DEC_PARAL'(0);
        end else begin
            for(integer i=0; i<INST_DEC_PARAL; i=i+1) begin
                if(trig_hit[i] && trig_hit_fence_o == $unsigned(i) && trig_hit_timing_o == 1'b0) begin
                    trig_mask[i] <= 1'b1;
                end else if(!debug_mode_en_r1 && inst_could_retire_r1) begin
                    trig_mask[i] <= 1'b0;
                end
            end
        end
    end
endmodule : hpu_rob_trigger
