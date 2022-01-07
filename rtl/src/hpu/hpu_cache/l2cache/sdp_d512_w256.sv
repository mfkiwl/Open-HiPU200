`timescale 1ns/1ps
module sdp_d512_w256 (
    input           clk_i,
    input           we_i,
    input [8:0]     waddr_i,
    input [255:0]   wdata_i,
    input [31:0]    wdata_strob_i,
    input           re_i,
    input [8:0]     raddr_i,
    output[255:0]   rdata_o
);

sdp_uhd_w512x64s_r512x64d1_wrap
 sdp_w512x64_r512x64d1_wrap_inst0 (
    .clk_i          (clk_i),
    .we_i           (we_i),
    .waddr_i        (waddr_i),
    .wdata_i        (wdata_i[63 : 0]),
    .wdata_strob_i  (wdata_strob_i[7 :0 ]),
    .re_i           (re_i),
    .raddr_i        (raddr_i),
    .rdata_o        (rdata_o[63 : 0])
);


sdp_uhd_w512x64s_r512x64d1_wrap
 sdp_w512x64_r512x64d1_wrap_inst1 (
    .clk_i          (clk_i),
    .we_i           (we_i),
    .waddr_i        (waddr_i),
    .wdata_i        (wdata_i[127 : 64 ]),
    .wdata_strob_i  (wdata_strob_i[15:8]),
    .re_i           (re_i),
    .raddr_i        (raddr_i),
    .rdata_o        (rdata_o[127 : 64 ])
);

sdp_uhd_w512x64s_r512x64d1_wrap
 sdp_w512x64_r512x64d1_wrap_inst2 (
    .clk_i          (clk_i),
    .we_i           (we_i),
    .waddr_i        (waddr_i),
    .wdata_i        (wdata_i[191 : 128] ),
    .wdata_strob_i  (wdata_strob_i[23:16]),
    .re_i           (re_i),
    .raddr_i        (raddr_i),
    .rdata_o        (rdata_o[191 : 128] )
);

sdp_uhd_w512x64s_r512x64d1_wrap
 sdp_w512x64_r512x64d1_wrap_inst3 (
    .clk_i          (clk_i),
    .we_i           (we_i),
    .waddr_i        (waddr_i),
    .wdata_i        (wdata_i[255 : 192]),
    .wdata_strob_i  (wdata_strob_i[31:24]),
    .re_i           (re_i),
    .raddr_i        (raddr_i),
    .rdata_o        (rdata_o[255 : 192])
);

endmodule
