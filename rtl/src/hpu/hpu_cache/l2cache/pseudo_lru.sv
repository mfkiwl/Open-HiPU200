`timescale 1ns/1ps
`include "hpu_head.sv"
import hpu_pkg::*;
/*support WAY_WTH=2 or 3 
  INDEX_WTH = any number
 */
module pseudo_lru # (parameter INDEX_WTH = 3,LINE_NUM = 8, WAY_WTH = 2)
(
    input  logic clk_i                     ,
    input  logic rst_i                     ,
    input  logic srst_lru_i                ,
    input  logic update_lru_i              ,
    input  logic [INDEX_WTH-1:0] windex_i  ,
    input  logic [INDEX_WTH-1:0] rindex_i  ,
    input  logic [WAY_WTH  -1:0] cur_way_i ,
    output logic [WAY_WTH  -1:0] vtm_way_o 
);

// WAY_WTH=2
logic [2:0] data [LINE_NUM-1:0] ;  //  WAY_WTH = 2 , 2 + 1 = 3

integer i;
always_ff@(posedge clk_i, `RST_DECL(rst_i))
begin
if(`RST_TRUE(rst_i))
        begin
            data[0] <= 3'b110;//vtm way0
            data[2] <= 3'b001;//vtm way2
            data[1] <= 3'b100;//vtm way1
            data[3] <= 3'b000;//vtm way3
        end
    else if(srst_lru_i)
        begin
            data[0] <= 3'b110;//vtm way0
            data[2] <= 3'b001;//vtm way2
            data[1] <= 3'b100;//vtm way1
            data[3] <= 3'b000;//vtm way3        
        end
    else if (update_lru_i)
        begin
            data[windex_i][2] <= cur_way_i[1];

            if( !cur_way_i[1] )
                data[windex_i][1] <= cur_way_i[0];
            else if( cur_way_i[1]  )
                data[windex_i][0] <= cur_way_i[0];
        end
end



always_comb
begin
    if (data[rindex_i][2])
        vtm_way_o = {1'b0,~data[rindex_i][1]};
    else
        vtm_way_o = {1'b1,~data[rindex_i][0]};
end

// WAY_WTH = 3
/*

logic [6:0] data [LINE_NUM-1:0] ;  //  WAY_WTH = 3 , 4 + 2 + 1 = 7


integer i;
always_ff@(posedge clk_i, `RST_DECL(rst_i))
begin
if(`RST_TRUE(rst_i))
        begin
            for (i=0; i<LINE_NUM; i++) 
                data[i] <= 1'b0;
        end
    else if(srst_lru_i)
        begin
            for (i=0; i<LINE_NUM; i++) 
                data[i] <= 1'b0;
        end
    else if (update_lru_i)
        begin
            data[windex_i][6] <= cur_way_i[2];

            if( !cur_way_i[2]  )
                data[windex_i][5] <= cur_way_i[1];
            else if( cur_way_i[2]  )
                data[windex_i][4] <= cur_way_i[1];

            if( cur_way_i[2:1] == 2'b00 )
                data[windex_i][3] <= cur_way_i[0];
            else if( cur_way_i[2:1] == 2'b01 )
                data[windex_i][2] <= cur_way_i[0];
            else if( cur_way_i[2:1] == 2'b11 )
                data[windex_i][1] <= cur_way_i[0];
            else if( cur_way_i[2:1] == 2'b11 )
                data[windex_i][0] <= cur_way_i[0];

        end
end


always_comb
begin
    if (data[rindex_i][6])
        begin
            if (data[rindex_i][5])
                vtm_way_o = {2'b00,~data[rindex_i][3]};
            else
                vtm_way_o = {2'b00,~data[rindex_i][2]};
        end
    else
        begin
            if (data[rindex_i][4])
                vtm_way_o = {2'b00,~data[rindex_i][1]};
            else
                vtm_way_o = {2'b00,~data[rindex_i][0]};
        end
end

*/

endmodule : pseudo_lru