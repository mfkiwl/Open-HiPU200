`timescale 1ns / 1ps
`include "hpu_head.sv"
import hpu_pkg::*;
module hpu_csr (
    input   logic                                   clk_i,
    input   logic                                   rst_i,
    input   csr_bus_req_t                           lsu_csr__bus_req_i,
    output  csr_bus_rsp_t                           csr_lsu__bus_rsp_o,
    output  csr_bus_req_t                           csr_ic__bus_req_o,
    input   csr_bus_rsp_t                           ic_csr__bus_rsp_i,
    output  csr_bus_req_t                           csr_dc__bus_req_o,
    input   csr_bus_rsp_t                           dc_csr__bus_rsp_i,
    output  csr_bus_req_t                           csr_l2c__bus_req_o,
    input   csr_bus_rsp_t                           l2c_csr__bus_rsp_i,
    output  csr_bus_req_t                           csr_ctrl__bus_req_o,
    input   csr_bus_rsp_t                           ctrl_csr__bus_rsp_i,
    output  csr_bus_req_t                           csr_lcarb__bus_req_o,
    input   csr_bus_rsp_t                           lcarb_csr__bus_rsp_i,
    output  csr_bus_req_t                           csr_trig__bus_req_o,
    input   csr_bus_rsp_t                           trig_csr__bus_rsp_i,
    input   logic[INST_DEC_BIT : 0]                 hpm_inst_retire_sum_i,
    input   data_t[INST_DEC_PARAL-1 : 0]            hpm_inst_cmt_eve_i,
    input   data_t                                  hpm_mco_arch_eve_i,
    input   logic                                   csr_vmu_iq_empty_i,
    input   logic                                   csr_vmu_rt_empty_i,
    input   logic                                   csr_vmu_mtx_idle_i,
    input   logic[3:0]                              csr_hpu_id_i,
    input   logic[5:0]                              csr_dm_id_i
);
    csr_addr_t                              raddr;
    logic[INST_DEC_PARAL-1 : 0]             event0_act[3 : 7];
    logic[INST_DEC_BIT : 0]                 event0_act_sum[3 : 7];
    logic                                   event1_act[3 : 7];
    logic[INST_DEC_BIT : 0]                 event0_act_sum_ff[3 : 7];
    logic                                   event1_act_ff[3 : 7];
    data_t                                  mcycleh, mcycle;
    data_t                                  minstreth, minstret;
    data_t                                  mhpmcounterh[3 : 7];
    data_t                                  mhpmcounter[3 : 7];
    data_t                                  mcountinhibit;
    data_t                                  mhpmevent[3 : 7];
    logic[1:0]                              csr_ndma_cmd;
    logic                                   csr_ndma_done;
    logic[31:0]                             csr_ndma_lcaddr;
    logic[31:0]                             csr_ndma_rtaddr;
    logic[19:0]                             csr_ndma_size;
    logic[1:0]                              csr_ndma_destx;
    logic[1:0]                              csr_ndma_desty;
    logic                                   csr_ndma_cmd_vld;
    assign csr_ic__bus_req_o = lsu_csr__bus_req_i;
    assign csr_dc__bus_req_o = lsu_csr__bus_req_i;
    assign csr_l2c__bus_req_o = lsu_csr__bus_req_i;
    assign csr_ctrl__bus_req_o = lsu_csr__bus_req_i;
    assign csr_lcarb__bus_req_o = lsu_csr__bus_req_i;
    assign csr_trig__bus_req_o = lsu_csr__bus_req_i;
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            raddr <= csr_addr_t'(0);
            csr_lsu__bus_rsp_o <= csr_bus_rsp_t'(0);
        end else begin
            raddr <= lsu_csr__bus_req_i.raddr;
            case(raddr)
                CSR_ADDR_MIR_VID         : csr_lsu__bus_rsp_o.rdata <= 32'h060a;
                CSR_ADDR_MIR_AID         : csr_lsu__bus_rsp_o.rdata <= 32'hcaca_caca;
                CSR_ADDR_MIR_IID         : csr_lsu__bus_rsp_o.rdata <= 32'h2020_0302;
                CSR_ADDR_MIR_HTID        : csr_lsu__bus_rsp_o.rdata <= 32'h0000_0001;
                CSR_ADDR_MIR_DMID        : csr_lsu__bus_rsp_o.rdata <= {26'h0000_0000, csr_dm_id_i};
                CSR_ADDR_MIR_HPUID       : csr_lsu__bus_rsp_o.rdata <= {28'h0000_0000, csr_hpu_id_i};
                CSR_ADDR_MTPS_MSTATUS    : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_MTPS_MISA       : csr_lsu__bus_rsp_o.rdata <= {2'b01,4'h0,
                                                                        26'b00_0000_0000_0001_0001_0000_0001};
                CSR_ADDR_MTPS_MEDELEG    : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_MTPS_MIDELEG    : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_MTPS_MIE        : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_MTPS_MTVEC      : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_MTPS_MCOUNTEREN : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_MTPH_MSCRATCH   : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_MTPH_MEPC       : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_MTPH_MCAUSE     : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_MTPH_MTVAL      : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_MTPH_MIP        : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_MCT_CYCLE      : csr_lsu__bus_rsp_o.rdata <= mcycle;
                CSR_ADDR_MCT_INSTRET    : csr_lsu__bus_rsp_o.rdata <= minstret;
                CSR_ADDR_MCT_HPMCNT03   : csr_lsu__bus_rsp_o.rdata <= mhpmcounter[3];
                CSR_ADDR_MCT_HPMCNT04   : csr_lsu__bus_rsp_o.rdata <= mhpmcounter[4];
                CSR_ADDR_MCT_HPMCNT05   : csr_lsu__bus_rsp_o.rdata <= mhpmcounter[5];
                CSR_ADDR_MCT_HPMCNT06   : csr_lsu__bus_rsp_o.rdata <= mhpmcounter[6];
                CSR_ADDR_MCT_HPMCNT07   : csr_lsu__bus_rsp_o.rdata <= mhpmcounter[7];
                CSR_ADDR_MCT_CYCLEH     : csr_lsu__bus_rsp_o.rdata <= mcycleh;
                CSR_ADDR_MCT_INSTRETH   : csr_lsu__bus_rsp_o.rdata <= minstreth;
                CSR_ADDR_MCT_HPMCNT03H  : csr_lsu__bus_rsp_o.rdata <= mhpmcounterh[3];
                CSR_ADDR_MCT_HPMCNT04H  : csr_lsu__bus_rsp_o.rdata <= mhpmcounterh[4];
                CSR_ADDR_MCT_HPMCNT05H  : csr_lsu__bus_rsp_o.rdata <= mhpmcounterh[5];
                CSR_ADDR_MCT_HPMCNT06H  : csr_lsu__bus_rsp_o.rdata <= mhpmcounterh[6];
                CSR_ADDR_MCT_HPMCNT07H  : csr_lsu__bus_rsp_o.rdata <= mhpmcounterh[7];
                CSR_ADDR_MCS_MCNTINHIBIT : csr_lsu__bus_rsp_o.rdata <= mcountinhibit;
                CSR_ADDR_MCS_MHPMEVENT03 : csr_lsu__bus_rsp_o.rdata <= mhpmevent[3];
                CSR_ADDR_MCS_MHPMEVENT04 : csr_lsu__bus_rsp_o.rdata <= mhpmevent[4];
                CSR_ADDR_MCS_MHPMEVENT05 : csr_lsu__bus_rsp_o.rdata <= mhpmevent[5];
                CSR_ADDR_MCS_MHPMEVENT06 : csr_lsu__bus_rsp_o.rdata <= mhpmevent[6];
                CSR_ADDR_MCS_MHPMEVENT07 : csr_lsu__bus_rsp_o.rdata <= mhpmevent[7];
                CSR_ADDR_DBG_TSELECT      : csr_lsu__bus_rsp_o.rdata <= trig_csr__bus_rsp_i.rdata;
                CSR_ADDR_DBG_TDATA1       : csr_lsu__bus_rsp_o.rdata <= trig_csr__bus_rsp_i.rdata;
                CSR_ADDR_DBG_TDATA2       : csr_lsu__bus_rsp_o.rdata <= trig_csr__bus_rsp_i.rdata;
                CSR_ADDR_DBG_TDATA3       : csr_lsu__bus_rsp_o.rdata <= trig_csr__bus_rsp_i.rdata;
                CSR_ADDR_DBG_TINFO        : csr_lsu__bus_rsp_o.rdata <= trig_csr__bus_rsp_i.rdata;
                CSR_ADDR_DBG_TCONTROL     : csr_lsu__bus_rsp_o.rdata <= trig_csr__bus_rsp_i.rdata;
                CSR_ADDR_DBG_MCONTEXT     : csr_lsu__bus_rsp_o.rdata <= trig_csr__bus_rsp_i.rdata;
                CSR_ADDR_DBG_SCONTEXT     : csr_lsu__bus_rsp_o.rdata <= trig_csr__bus_rsp_i.rdata;
                CSR_ADDR_DBG_DCSR         : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_DBG_DPC          : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_DBG_SCRATCH0     : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_DBG_SCRATCH1     : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_DBG_SCRATCH2     : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_DBG_SCRATCH3     : csr_lsu__bus_rsp_o.rdata <= ctrl_csr__bus_rsp_i.rdata;
                CSR_ADDR_NDMA_CTRL     : csr_lsu__bus_rsp_o.rdata <= lcarb_csr__bus_rsp_i.rdata;
                CSR_ADDR_NDMA_STATUS   : csr_lsu__bus_rsp_o.rdata <= lcarb_csr__bus_rsp_i.rdata;
                CSR_ADDR_NDMA_LCADDR   : csr_lsu__bus_rsp_o.rdata <= lcarb_csr__bus_rsp_i.rdata;
                CSR_ADDR_NDMA_RTADDR   : csr_lsu__bus_rsp_o.rdata <= lcarb_csr__bus_rsp_i.rdata;
                CSR_ADDR_NDMA_SIZE     : csr_lsu__bus_rsp_o.rdata <= lcarb_csr__bus_rsp_i.rdata;
                CSR_ADDR_NDMA_DESTXY   : csr_lsu__bus_rsp_o.rdata <= lcarb_csr__bus_rsp_i.rdata;
                CSR_ADDR_NDMA_WR_DONE  : csr_lsu__bus_rsp_o.rdata <= lcarb_csr__bus_rsp_i.rdata;
                CSR_ADDR_NDMA_RD_DONE  : csr_lsu__bus_rsp_o.rdata <= lcarb_csr__bus_rsp_i.rdata;
                CSR_ADDR_NDMA_SWAP_DONE: csr_lsu__bus_rsp_o.rdata <= lcarb_csr__bus_rsp_i.rdata;
                CSR_ADDR_NDMA_WR_MASK  : csr_lsu__bus_rsp_o.rdata <= lcarb_csr__bus_rsp_i.rdata;
                CSR_ADDR_NDMA_RD_MASK  : csr_lsu__bus_rsp_o.rdata <= lcarb_csr__bus_rsp_i.rdata;
                CSR_ADDR_NDMA_SWAP_MASK: csr_lsu__bus_rsp_o.rdata <= lcarb_csr__bus_rsp_i.rdata;
                CSR_ADDR_VMU_STATUS    : csr_lsu__bus_rsp_o.rdata <= {29'h0, csr_vmu_iq_empty_i,
                    csr_vmu_rt_empty_i, csr_vmu_mtx_idle_i};
                CSR_ADDR_IC_CTRL   : csr_lsu__bus_rsp_o.rdata <= ic_csr__bus_rsp_i.rdata;
                CSR_ADDR_IC_STATUS : csr_lsu__bus_rsp_o.rdata <= {31'h0, ic_csr__bus_rsp_i.rdata[0]};
                CSR_ADDR_IC_MODEL  : csr_lsu__bus_rsp_o.rdata <= ic_csr__bus_rsp_i.rdata;
                CSR_ADDR_DC_FINISH : csr_lsu__bus_rsp_o.rdata <= {31'h0,dc_csr__bus_rsp_i.rdata[0]};
                CSR_ADDR_DC_ADDR   : csr_lsu__bus_rsp_o.rdata <= dc_csr__bus_rsp_i.rdata;
                CSR_ADDR_DC_MODEL  : csr_lsu__bus_rsp_o.rdata <= dc_csr__bus_rsp_i.rdata;
                CSR_ADDR_L2C_FINISH       : csr_lsu__bus_rsp_o.rdata <= {31'h0,l2c_csr__bus_rsp_i.rdata[0]};
                CSR_ADDR_L2C_ADDR_SET_WAY : csr_lsu__bus_rsp_o.rdata <= l2c_csr__bus_rsp_i.rdata;
                CSR_ADDR_L2C_MODEL        : csr_lsu__bus_rsp_o.rdata <= l2c_csr__bus_rsp_i.rdata;
                default:    csr_lsu__bus_rsp_o.rdata <= data_t'(0);
            endcase
        end
    end
    always_comb begin
        for(integer i=3; i<8; i=i+1) begin
            for(integer j=0; j<INST_DEC_PARAL; j=j+1) begin
                event0_act[i][j] = |(hpm_inst_cmt_eve_i[j][31 : 8] & mhpmevent[i][31 : 8]);
                if(j==0) begin
                    event0_act_sum[i] = event0_act[i][0];
                end else begin
                    event0_act_sum[i] += {{INST_DEC_BIT{1'b0}}, event0_act[i][j]};
                end
            end
            event1_act[i] = |(hpm_mco_arch_eve_i[31 : 8] & mhpmevent[i][31 : 8]);
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            for(integer i=3; i<8; i=i+1) begin
                event0_act_sum_ff[i] <= {(INST_DEC_BIT+1){1'b0}};
                event1_act_ff[i] <= 1'b0;
            end
        end else begin
            for(integer i=3; i<8; i=i+1) begin
                event0_act_sum_ff[i] <= event0_act_sum[i];
                event1_act_ff[i] <= event1_act[i];
            end
        end
    end
    always_ff @(posedge clk_i or `RST_DECL(rst_i)) begin
        if(`RST_TRUE(rst_i)) begin
            {mcycleh, mcycle} <= 64'h0;
            {minstreth, minstret} <= 64'h0;
            {mhpmcounterh[3], mhpmcounter[3]} <= 64'h0;
            {mhpmcounterh[4], mhpmcounter[4]} <= 64'h0;
            {mhpmcounterh[5], mhpmcounter[5]} <= 64'h0;
            {mhpmcounterh[6], mhpmcounter[6]} <= 64'h0;
            {mhpmcounterh[7], mhpmcounter[7]} <= 64'h0;
            mcountinhibit <= data_t'(0);
            mhpmevent[3] <= data_t'(0);
            mhpmevent[4] <= data_t'(0);
            mhpmevent[5] <= data_t'(0);
            mhpmevent[6] <= data_t'(0);
            mhpmevent[7] <= data_t'(0);
        end else begin
            if(!mcountinhibit[0]) begin
                {mcycleh, mcycle} <= {mcycleh, mcycle} + 1'b1;
            end
            if(|hpm_inst_retire_sum_i && !mcountinhibit[2]) begin
                {minstreth, minstret} <= {minstreth, minstret} + {{(63-INST_DEC_BIT){1'b0}}, hpm_inst_retire_sum_i};
            end
            for(integer i=3; i<8; i=i+1) begin
                if( (mhpmevent[i][7:0] == 8'h0) && !mcountinhibit[i] ) begin
                    {mhpmcounterh[i], mhpmcounter[i]} <= {mhpmcounterh[i], mhpmcounter[i]}
                                                       + {{(63-INST_DEC_BIT){1'b0}}, event0_act_sum_ff[i]};
                end else if( (mhpmevent[i][7:0] == 8'h0) && !mcountinhibit[i] ) begin
                    {mhpmcounterh[i], mhpmcounter[i]} <= {mhpmcounterh[i], mhpmcounter[i]}
                                                       + {{(64-INST_DEC_BIT){1'b0}}, event1_act_ff[i]};
                end
            end
            if(lsu_csr__bus_req_i.wr_en) begin
                case(lsu_csr__bus_req_i.waddr)
                    CSR_ADDR_MCT_CYCLE: mcycle <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCT_INSTRET: minstret <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCT_HPMCNT03: mhpmcounter[3] <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCT_HPMCNT04: mhpmcounter[4] <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCT_HPMCNT05: mhpmcounter[5] <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCT_HPMCNT06: mhpmcounter[6] <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCT_HPMCNT07: mhpmcounter[7] <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCT_CYCLEH: mcycleh <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCT_INSTRETH: minstreth <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCT_HPMCNT03H: mhpmcounterh[3] <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCT_HPMCNT04H: mhpmcounterh[4] <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCT_HPMCNT05H: mhpmcounterh[5] <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCT_HPMCNT06H: mhpmcounterh[6] <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCT_HPMCNT07H: mhpmcounterh[7] <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCS_MCNTINHIBIT: mcountinhibit <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCS_MHPMEVENT03: mhpmevent[3] <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCS_MHPMEVENT04: mhpmevent[4] <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCS_MHPMEVENT05: mhpmevent[5] <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCS_MHPMEVENT06: mhpmevent[6] <= lsu_csr__bus_req_i.wdata;
                    CSR_ADDR_MCS_MHPMEVENT07: mhpmevent[7] <= lsu_csr__bus_req_i.wdata;
                endcase
            end
        end
    end
endmodule : hpu_csr
