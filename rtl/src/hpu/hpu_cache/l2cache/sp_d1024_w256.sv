`timescale 1ns/1ps
module sp_d1024_w256 (
    input           clk_i,
    input           cs_i,
    input           we_i,
    input [9:0]     addr_i,
    input [255:0]   wdata_i,
    input [31:0]    wdata_strob_i,
    output[255:0]   rdata_o
);
logic         raddr_msb_d0;
logic [255:0] rdata0 ;
logic [255:0] rdata1 ;
sp_d512_w256 sp_d512_w256_inst0
(
    .clk_i          (clk_i),
    .cs_i			(cs_i),
    .we_i           (we_i & (~addr_i[9])),
    .addr_i			(addr_i[8:0]),
    .wdata_i        (wdata_i),
    .wdata_strob_i  (wdata_strob_i),
    .rdata_o        (rdata0)
);



sp_d512_w256 sp_d512_w256_inst1
(
    .clk_i          (clk_i),
    .cs_i			(cs_i),
    .we_i           (we_i & addr_i[9]),
    .addr_i			(addr_i[8:0]),
    .wdata_i        (wdata_i),
    .wdata_strob_i  (wdata_strob_i),
    .rdata_o        (rdata1)
);

always_ff@(posedge clk_i)
begin
    raddr_msb_d0 <= addr_i[9];
end

assign rdata_o = raddr_msb_d0 == 1'b0 ?  rdata0 : rdata1 ;

endmodule
