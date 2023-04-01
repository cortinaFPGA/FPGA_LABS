`timescale 1ns / 1ps

module IIR_unfold(
clk,
rst,
a,b,c,d,
x2k,x2k1,
y2k,y2k1
);

input clk,rst;
input[7:0] a,b,c,d;
input[7:0] x2k,x2k1;
output[7:0] y2k,y2k1;

reg[7:0] x_1;
reg[7:0] y_1,y_2;

wire[7:0] r0,r1,r2,r3,r4,r5,r6,r7;

multiply m0(a,x2k,r0); //(input,input,output)
multiply m1(a,x2k1,r1);
multiply m2(b,x2k,r2);
multiply m3(b,x_1,r3);
multiply m4(d,y_2,r4);
multiply m5(c,y_1,r5);
multiply m6(d,y_1,r6);
multiply m7(c,y2k,r7);

assign y2k = r0 + r3 + r5 + r4;
assign y2k1 = r1 + r2 + r6 + r7;

always@(posedge clk or negedge rst)begin
    if(~rst)begin
        x_1<=0;
        y_1<=0;
        y_2<=0;
    end
    else begin
        x_1<=x2k1;
        y_1<=y2k1;
        y_2<=y2k;
    end
end

endmodule
