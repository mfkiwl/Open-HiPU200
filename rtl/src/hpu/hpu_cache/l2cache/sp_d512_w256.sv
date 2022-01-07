`timescale 1ns/1ps
module sp_d512_w256 (
    input           clk_i,
    input           cs_i,
    input           we_i,
    input [8:0]     addr_i,
    input [255:0]   wdata_i,
    input [31:0]    wdata_strob_i,
    output[255:0]   rdata_o
);

sp_512x64sd1_wrap 
 sp_512x64sd1_wrap_inst0 (
    .clk_i          (clk_i),
    .cs_i			(cs_i),
    .we_i           (we_i),
    .addr_i			(addr_i),
    .wdata_i        (wdata_i[63 : 0]),
    .wdata_strob_i  (wdata_strob_i[7 :0 ]),
    .rdata_o        (rdata_o[63 : 0])
);

sp_512x64sd1_wrap 
 sp_512x64sd1_wrap_inst1 (
    .clk_i          (clk_i),
    .cs_i			(cs_i),
    .we_i           (we_i),
    .addr_i			(addr_i),
    .wdata_i        (wdata_i[127 : 64 ]),
    .wdata_strob_i  (wdata_strob_i[15:8]),
    .rdata_o        (rdata_o[127 : 64 ])
);

sp_512x64sd1_wrap 
 sp_512x64sd1_wrap_inst2 (
    .clk_i          (clk_i),
    .cs_i			(cs_i),
    .we_i           (we_i),
    .addr_i			(addr_i),
    .wdata_i        (wdata_i[191 : 128] ),
    .wdata_strob_i  (wdata_strob_i[23:16]),
    .rdata_o        (rdata_o[191 : 128] )
);

sp_512x64sd1_wrap 
 sp_512x64sd1_wrap_inst3 (
    .clk_i          (clk_i),
    .cs_i			(cs_i),
    .we_i           (we_i),
    .addr_i			(addr_i),
    .wdata_i        (wdata_i[255 : 192]),
    .wdata_strob_i  (wdata_strob_i[31:24]),
    .rdata_o        (rdata_o[255 : 192])
);

endmodule
