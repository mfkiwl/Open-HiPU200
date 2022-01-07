`ifndef HPU_SOC_INTF_SVH
`define HPU_SOC_INTF_SVH

parameter int HPU_CORE_NUM = 13;

function automatic logic [7 : 0] get_8bit_data(logic [31-1 : 0] i_data);
    return { i_data[7 : 0] };
endfunction

typedef struct packed {
    logic  [5:0]                                    pll_refdiv;
    logic  [11:0]                                   pll_fbdiv;
    logic  [2:0]                                    pll_postdiv1;
    logic  [2:0]                                    pll_postdiv2;
    logic                                           pll_pd;
    logic                                           pll_dsmpd;
    logic                                           pll_foutvcopd;
    logic                                           pll_foutpostdivpd;
} pll_config_t;

typedef enum logic[2:0] {
    core_rst = 3'h0, // the reset & clock is not enable, current HPU core is not used.
    core_idle = 3'h1, // HPU is idle, all interrupt are processed.
    core_busy = 3'h2, // HPU is processing its own task.
    core_halt = 3'h3  // HPU is paused by some reasons, including Debug, WFI, etc..
} sys_status_e;

typedef struct packed {
    logic                           pcie_rst_done;
    logic                           ddr_rst_done;
    logic                           ddr_calib_done;
    logic                           spi_init_done;
    logic                           uart_init_done;
    logic                           pll0_init_done; //for HPU
    logic                           pll1_init_done; //for NoC ?
    logic                           pll2_init_done; //for MCU, PCIe, SPI, UART
    logic                           pll3_init_done; //for MCU, PCIe, SPI, UART
    logic                           pll4_init_done; //for MCU, PCIe, SPI, UART
    logic                           pll5_init_done; //for MCU, PCIe, SPI, UART
} mcu_status_t;


`endif
