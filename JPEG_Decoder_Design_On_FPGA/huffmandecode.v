`timescale 1ns / 1ps

module huffmandecode(
clk,
rst,
code,
hufftable,
huffsymbol,
data,
length,
finish
    );
input clk,rst;
input[15:0] code; // decode from highest bits first
input[8*16-1:0] hufftable; 
input[8*256-1:0] huffsymbol;
output reg[7:0] data; // output
output reg[7:0] length;
output reg finish = 0;

reg[7:0] n;
reg[7:0] i;
reg[15:0] code_to_compare;
reg[15:0] updated_UB;
reg[7:0] dis;
reg[7:0] idx;
reg[8*16-1:0] SC;
reg[7:0] updated_SC;

always@(posedge clk or negedge rst)begin
    if(~rst)begin
        finish <= 0;
        n<=0;
        updated_UB<=0;
        dis<=0;
        SC[7:0]<=0;
        SC[15:8]<=2;
        SC[23:16]<=3;
        SC[31:24]<=6;
        SC[39:32]<=9;
        SC[47:40]<=11;
        SC[55:48]<=15;
        SC[63:56]<=18;
        SC[71:64]<=23;
        SC[79:72]<=28;
        SC[87:80]<=32;
        SC[95:88]<=36;
        SC[103:96]<=36;
        SC[111:104]<=36;
        SC[119:112]<=37;
        SC[127:120]<=162;
    end
    
    else if(finish==0)begin
        if(n<=15)begin
            code_to_compare = code >> (15-n);
            updated_UB = (updated_UB << 1) + ((hufftable >> (8*n)) & 'hff);
            updated_SC = (SC >> (8*n)) & 'hff;
            
            if (code_to_compare < updated_UB) begin
                dis = updated_UB - code_to_compare;
                idx = updated_SC - dis;
                data = (huffsymbol >> (8*idx)) & 'hff;
                length = n + 1;
                finish = 1;
            end
            n = n + 1;
        end
    
    else begin
        length<=0;
        finish<=1;
        data<='hff;
    end   
    end
end

endmodule
