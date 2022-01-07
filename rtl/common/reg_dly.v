module reg_dly #(
	parameter		width = 1,
	parameter		delaynum =1
) (
	input 					    clk,    // Clock
	input [width-1:0]		d,  
	output[width-1:0]		q
);

	reg [(delaynum*width)-1:0]			d_tmp_reg;
	wire[((delaynum+1)*width)-1:0]		d_tmp;

	genvar i;
	generate
  for (i = 0; i < delaynum; i=i+1) begin : dly_chain
		always @(posedge clk) begin
			d_tmp_reg[(i+1)*width-1:i*width] <= d_tmp[(i+1)*width-1:i*width];
		end
		assign d_tmp[(i+2)*width-1:(i+1)*width] = d_tmp_reg[(i+1)*width-1:i*width];
	end
	endgenerate

	assign d_tmp[width-1:0] = d;
	assign q = d_tmp_reg[delaynum*width-1:(delaynum-1)*width];

endmodule
