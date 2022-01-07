// +FHDR------------------------------------------------------------------------
// XJTU IAIR Corporation All Rights Reserved
// -----------------------------------------------------------------------------
// FILE NAME  : sync_fifo.sv
// DEPARTMENT : CAG of IAIR
// AUTHOR     : XXXX
// AUTHOR'S EMAIL :XXXX@mail.xjtu.edu.cn
// -----------------------------------------------------------------------------
// Ver 1.0  2019--01--01 initial version.
// -----------------------------------------------------------------------------
// KEYWORDS   : common, fifo,
// -----------------------------------------------------------------------------
// PURPOSE    :
// -----------------------------------------------------------------------------
// PARAMETERS :
// -----------------------------------------------------------------------------
// REUSE ISSUES
// Reset Strategy   :
// Clock Domains    :
// Critical Timing  :
// Test Features    :
// Asynchronous I/F :
// Scan Methodology : N
// Instantiations   : N
// Synthesizable    : Y
// Other :
// -FHDR------------------------------------------------------------------------
`timescale 1ns / 1ps

module write_buffer_fifo #(
    parameter OFT_WTH = 12,
    parameter TAG_WTH = 17,
    parameter INDEX_WTH = 3,
    parameter FIFO_LEN = 16,
    parameter DATA_D_WTH = 8,
    parameter DATA_A_WTH = 32,
    parameter ADDR_WTH = 4,
    parameter FULL_ASSERT_VALUE = FIFO_LEN,
    parameter FULL_NEGATE_VALUE = FIFO_LEN,
    parameter EMPTY_ASSERT_VALUE = 0,
    parameter EMPTY_NEGATE_VALUE = 0
) (
    // clock & reset
    input                               clk_i,
    input                               rst_i,
    // compare interface
    input                               cmp_en_i     ,
    input [TAG_WTH+INDEX_WTH-1 : 0]     cmp_data_a_i ,
    output                              cmp_result_o ,
    // write interface
    input [DATA_D_WTH-1 : 0]            wr_data_d_i,
    input [DATA_A_WTH-1 : 0]            wr_data_a_i,
    input                               wr_en_i,
    output                              full_o,
    output                              a_full_o,
    // read interface
    output[DATA_D_WTH-1 : 0]            rd_data_d_o,
    output[DATA_A_WTH-1 : 0]            rd_data_a_o,
    input                               rd_en_i,
    output                              empty_o,
    output                              a_empty_o
);

//=============================================================================
// variables declaration
//=============================================================================
reg   [DATA_D_WTH-1 : 0]        mem_d[0 : FIFO_LEN-1];
reg   [DATA_A_WTH   : 0]        mem_a[0 : FIFO_LEN-1];
wire                            wr_en;
reg   [ADDR_WTH : 0]            wr_addr;
reg                             wr_mark;
wire                            rd_en;
reg   [ADDR_WTH : 0]            rd_addr;
reg                             rd_mark;
wire                            empty, full;
reg                             a_empty, a_full;
logic                           cmp_en_wr_en_both_cmp_result;

//=============================================================================
// instance
//=============================================================================
// write logic
assign wr_en = wr_en_i & (~full);

always_ff@(posedge clk_i, `RST_DECL(rst_i))begin
    if(`RST_TRUE(rst_i))begin
        wr_addr <= {(ADDR_WTH+1){1'b0}};
        wr_mark <= 1'b0;
        for(int i=0;i<FIFO_LEN;i=i+1)
            begin
            mem_a[i] <= {1'b1,{DATA_A_WTH{1'b0}}};
            end
    end else begin
        if(wr_en) begin
            if(wr_addr == FIFO_LEN - 1'b1) begin
                wr_addr <= {(ADDR_WTH+1){1'b0}};
                wr_mark <= ~wr_mark;
            end else begin
                wr_addr <= wr_addr + 1'b1;
            end
            mem_d[wr_addr[ADDR_WTH-1:0]] <= wr_data_d_i;
            mem_a[wr_addr[ADDR_WTH-1:0]] <= {1'b0,wr_data_a_i};
        end
    end
end

// read logic
assign rd_en = rd_en_i & (~empty);
always_ff@(posedge clk_i, `RST_DECL(rst_i))begin
    if(`RST_TRUE(rst_i))begin
        rd_addr <= {(ADDR_WTH+1){1'b0}};
        rd_mark <= 1'b0;
    end else begin
        if(rd_en) begin
            if(rd_addr == FIFO_LEN - 1'b1) begin
                rd_addr <= {(ADDR_WTH+1){1'b0}};
                rd_mark <= ~rd_mark;
            end else begin
                rd_addr <= rd_addr + 1'b1;
            end
        end
    end
end
assign rd_data_d_o = mem_d[rd_addr[ADDR_WTH-1:0]];
assign rd_data_a_o = mem_a[rd_addr[ADDR_WTH-1:0]][DATA_A_WTH-1:0];

// full/empty signal logic
assign empty = (wr_addr == rd_addr) && (wr_mark == rd_mark);
assign full = (wr_addr == rd_addr) && (wr_mark != rd_mark);

assign empty_o = empty;
assign full_o = full;

// almost full/empty signal logic
always_ff@(posedge clk_i, `RST_DECL(rst_i))begin
    if(`RST_TRUE(rst_i))begin
        a_empty <= 1'b1;
        a_full <= 1'b0;
    end else begin
        if(rd_en & (~wr_en)) begin
            if(wr_addr < rd_addr) begin
                if(wr_addr + FIFO_LEN - rd_addr == EMPTY_ASSERT_VALUE + 1'b1)
                    a_empty <= 1'b1;
                if(wr_addr + FIFO_LEN - rd_addr == FULL_NEGATE_VALUE)
                    a_full <= 1'b0;
            end else begin
                if(wr_addr - rd_addr == EMPTY_ASSERT_VALUE + 1'b1)
                    a_empty <= 1'b1;
                if(wr_addr - rd_addr == FULL_NEGATE_VALUE)
                    a_full <= 1'b0;
            end
        end else if((~rd_en) & wr_en) begin
            if(wr_addr < rd_addr) begin
                if(wr_addr + FIFO_LEN - rd_addr == EMPTY_NEGATE_VALUE)
                    a_empty <= 1'b0;
                if(wr_addr + FIFO_LEN - rd_addr == FULL_ASSERT_VALUE - 1'b1)
                    a_full <= 1'b1;
            end else begin
                if(wr_addr - rd_addr == EMPTY_NEGATE_VALUE)
                    a_empty <= 1'b0;
                if(wr_addr - rd_addr == FULL_ASSERT_VALUE - 1'b1)
                    a_full <= 1'b1;
            end
        end
    end
end

assign a_empty_o = a_empty;
assign a_full_o = a_full;
/*
compare
*/
integer i;
logic [FIFO_LEN-1:0] cmp_result;
always_ff@(posedge clk_i, `RST_DECL(rst_i))
begin
    if(`RST_TRUE(rst_i))
        begin
        for(i=0;i<FIFO_LEN;i++)
            begin
            cmp_result[i] <= 1'b0; 
            end
        end
    else if( cmp_en_i ) 
        begin
        for(i=0;i<FIFO_LEN;i++)
            begin
            if(empty)
                cmp_result[i] <=  1'b0; 
            else if(full)
                cmp_result[i] <=  (mem_a[i][TAG_WTH+INDEX_WTH+OFT_WTH:OFT_WTH] == {1'b0,cmp_data_a_i}); 
            else if((wr_mark == rd_mark) && (i >= rd_addr && i < wr_addr))
                cmp_result[i] <=  (mem_a[i][TAG_WTH+INDEX_WTH+OFT_WTH:OFT_WTH] == {1'b0,cmp_data_a_i}); 
            else if((wr_mark != rd_mark) && (i >= rd_addr || i < wr_addr))
                cmp_result[i] <=  (mem_a[i][TAG_WTH+INDEX_WTH+OFT_WTH:OFT_WTH] == {1'b0,cmp_data_a_i}); 
            else 
                cmp_result[i] <=  1'b0;    
            end
        end
    else
	    begin
        for(i=0;i<FIFO_LEN;i++)
            begin
            cmp_result[i] <= 1'b0; 
            end
        end
end

always_ff@(posedge clk_i, `RST_DECL(rst_i))begin
    if(`RST_TRUE(rst_i)) begin
        cmp_en_wr_en_both_cmp_result <= 1'b0;
    end else begin
        if(cmp_en_i && wr_en_i) begin
            cmp_en_wr_en_both_cmp_result <= (wr_data_a_i[TAG_WTH+INDEX_WTH+OFT_WTH-1:OFT_WTH] == cmp_data_a_i);
        end else  begin
            cmp_en_wr_en_both_cmp_result <= 1'b0;
        end
    end
end

assign cmp_result_o = ( (|cmp_result) ||  cmp_en_wr_en_both_cmp_result );

endmodule
