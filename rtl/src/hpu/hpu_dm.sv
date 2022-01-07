import dm::*;

module hpu_dm #(
    parameter int unsigned        NrHarts          = 1,
    parameter int unsigned        BusWidth         = 32,
    parameter int unsigned        NrDM_W           = 6,
    parameter logic [NrHarts-1:0] SelectableHarts  = {NrHarts{1'b1}}
) (
    input  logic                                    tck_i,
    input  logic                                    trst_ni,
    input  logic                                    clk_i,
    input  logic                                    rst_ni,
    input   logic                                   testmode_i,
    output  logic                                   dm_rst__ndmreset_o,
    output  logic                                   dm_ctrl__dmactive_o,
    output  logic [NrHarts-1:0]                     dm_ctrl__halt_req_o,
    output  logic [NrHarts-1:0]                     dm_ctrl__resume_req_o,
    output  logic [NrHarts-1:0]                     dm_ctrl__req_resethalt_o,
    output  logic                                   dm_ctrl__cmd_valid_o,
    input   logic [NrHarts-1:0]                     ctrl_dm__unavailable_i,
    input   hartinfo_t [NrHarts-1:0]                ctrl_dm__hartinfo_i,
    input   logic                                   darb_dm__req_i,
    input   logic                                   darb_dm__we_i,
    input   logic [BusWidth-1:0]                    darb_dm__addr_i,
    input   logic [BusWidth/8-1:0]                  darb_dm__be_i,
    input   logic [BusWidth-1:0]                    darb_dm__wdata_i,
    output  logic [BusWidth-1:0]                    dm_darb__rdata_o,
    output  logic                                   dm_dtcm__sba_req_o,
    output  logic [BusWidth-1:0]                    dm_dtcm__sba_addr_o,
    output  logic                                   dm_dtcm__sba_we_o,
    output  logic [BusWidth-1:0]                    dm_dtcm__sba_wdata_o,
    output  logic [BusWidth/8-1:0]                  dm_dtcm__sba_be_o,
    input   logic                                   dtcm_dm__sba_gnt_i,
    input   logic [BusWidth-1:0]                    dtcm_dm__sba_rdata_i,
    input   logic                                   dtcm_dm__sba_rdata_act_i,
    input   logic                                   dmi_req_valid_i,
    output  logic                                   dmi_req_ready_o,
    input   dmi_req_t                               dmi_req_i,
    output  logic                                   dmi_resp_valid_o,
    input   logic                                   dmi_resp_ready_i,
    output  dmi_resp_t                              dmi_resp_o,
    input   logic[5 : 0]                            dmi_dmid_i
);


endmodule : hpu_dm
