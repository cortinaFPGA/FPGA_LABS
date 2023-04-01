`timescale 1ns / 1ps

module viterbi(
clk,
rst,
codein, // input: the code word sequence; length = param(lenin) = 10.
states, // input: state; length: 2^(k-1)*2*r = 16. 8 expected parity bits
codeout, // output: decoded message; length: lenout = 5.
finish // output: 1 bit flag signal.
    );

parameter r=2; // Number of parity bits in each cycle.
parameter K=3; // Max convolutional window size.
parameter lenin=10; // Length of the input code word.
parameter lenout=5; // Length of the output decoded message.

parameter maskcode=(1<<r)-1; // 11.
parameter maskstate=(1<<(K-1))-1; // 11.
parameter maskpath=(1<<K)-1; // 111. take lower 3 bits.

input clk,rst;
input[lenin-1:0] codein;
input[(1<<(K-1))*2*r-1:0] states; // input: state; length: 2^(k-1)*2*r = 16.
output reg[lenout-1:0] codeout;
output reg finish;

reg[r-1:0] code; // code word we test each time.
wire[(1<<(K-1))*2*r-1:0] dis_path_out; // length: 16.

// Branch Metric Unit
 bmu #(.r(r),.K(K)) b0(
 clk,
 rst,
 code,
 states,
 dis_path_out
     );

 reg[lenout*K-1:0] paths[(1<<(K-1))-1:0]; //each K: [input dir 0/1: 1bit][last state: (K-1)bits]

 reg[(1<<(K-1))*8-1:0] dis[1:0]; // 4*8 // path metrics
 wire[(1<<(K-1))*K-1:0] pmu_path_out;
 wire[(1<<(K-1))*8-1:0] pmu_dis_out;
 
// Path Metric Unit
 pmu #(.r(r),.K(K)) p0(
 clk,
 rst,
 dis[1],
 dis_path_out,
 pmu_path_out,
 pmu_dis_out
     );

 reg[7:0] state; //state
 reg[7:0] code_count; //# of code we have received
 reg[2:0] count; //count cycles
 reg[7:0] i;
 reg[7:0] mindis;
 reg[1:0] mins;
 reg[lenout-1:0] codeout2;
 

 
 localparam state0 = 'b000;
 localparam state1 = 'b001;
 localparam state2 = 'b010;
 localparam state3 = 'b011;
 localparam state4 = 'b100;

always@(posedge clk or negedge rst)begin
    if(~rst)begin
        i<=0;
        mindis<=0;
        mins<=0;
        codeout2<=0;
        code<=0;
        finish<=0;
        count<=0;
        code_count<=0;
        state<=0;
        dis[0] <= (~(0)) & ((~(0))<<8); // 11111111 11111111 11111111 00000000
        dis[1] <= 'b11111111111111111111111111111111;
        paths[0]<=0;
        paths[1]<=0;
        paths[2]<=0;
        paths[3]<=0;
    end
    else begin
        case(state)
            state0:
            begin
                code=(codein>>((lenin-2)-(code_count*2))) & 'b11;
                dis[1] = dis[0];
                dis[0] = 'b11111111111111111111111111111111;
                state = state1;
            end
            
            state1:
            begin
                if(count == 2) begin
                    state = state2;
                end
                count = count + 1;
            end
            
            state2:
            begin
                if(code_count >= 5) begin
                    state = state3;
                end
                else begin
                    count = 0;
                    dis[0] = pmu_dis_out;
                    
                    if(code_count == 0) begin
                        paths[0][2:0] = pmu_path_out[2:0];
                        paths[1][2:0] = pmu_path_out[5:3];
                        paths[2][2:0] = pmu_path_out[8:6];
                        paths[3][2:0] = pmu_path_out[11:9];
                    end
                    
                    else if(code_count == 1) begin
                        paths[0][5:3] = pmu_path_out[2:0];
                        paths[1][5:3] = pmu_path_out[5:3];
                        paths[2][5:3] = pmu_path_out[8:6];
                        paths[3][5:3] = pmu_path_out[11:9];
                    end
                    
                    else if(code_count == 2) begin
                        paths[0][8:6] = pmu_path_out[2:0];
                        paths[1][8:6] = pmu_path_out[5:3];
                        paths[2][8:6] = pmu_path_out[8:6];
                        paths[3][8:6] = pmu_path_out[11:9];
                    end
                    
                    else if(code_count == 3) begin
                        paths[0][11:9] = pmu_path_out[2:0];
                        paths[1][11:9] = pmu_path_out[5:3];
                        paths[2][11:9] = pmu_path_out[8:6];
                        paths[3][11:9] = pmu_path_out[11:9];
                    end
                    
                    else if(code_count == 4) begin
                        paths[0][14:12] = pmu_path_out[2:0];
                        paths[1][14:12] = pmu_path_out[5:3];
                        paths[2][14:12] = pmu_path_out[8:6];
                        paths[3][14:12] = pmu_path_out[11:9];
                    end
                    code_count = code_count +1;
                    state = state0;
                end
            end
            
            state3:
            begin
                mindis = dis[1][7:0];
                mins = 0;
                if(dis[1][15:8] < mindis) begin
                    mindis = dis[1][15:8];
                    mins = 1;
                    if(dis[1][23:16] < mindis) begin
                        mindis = dis[1][23:16];
                        mins = 2;
                        if(dis[1][31:24] < mindis) begin
                            mindis = dis[1][31:24];
                            mins = 3;
                        end
                    end
                    
                    else if(dis[1][31:24] < mindis) begin
                        mindis = dis[1][31:24];
                        mins = 3;
                    end
                end
                
                if(dis[1][23:16] < mindis) begin
                    mindis = dis[1][23:16];
                    mins = 2;
                    if(dis[1][31:24] < mindis) begin
                        mindis = dis[1][31:24];
                        mins = 3;
                    end
                end
                    else if(dis[1][31:24] < mindis) begin
                        mindis = dis[1][31:24];
                        mins = 3;
                    end
            state = state4;
            end
            
            state4:
            begin
                if(i<=lenout-1) begin
                    if(mins == 0) begin
                        codeout2[0] = ((paths[0]>>((lenout-1-i)*3))&'b111)>>2;
                        mins = (paths[0]>>((lenout-1-i)*3))& 'b11;
                        
                        if(i!=lenout-1)
                            codeout2 = codeout2<<1;
                            i = i + 1;
                    end
                    
                    else if(mins == 1) begin
                        codeout2[0] = ((paths[1]>>((lenout-1-i)*3))&'b111)>>2;
                        mins = (paths[1]>>((lenout-1-i)*3))& 'b11;
                        
                        if(i!=lenout-1)
                            codeout2 = codeout2<<1;
                            i = i + 1;
                    end
                    
                    else if(mins == 2) begin
                        codeout2[0] = ((paths[2]>>((lenout-1-i)*3))&'b111)>>2;
                        mins = (paths[2]>>((lenout-1-i)*3))& 'b11;
                        
                        if(i!=lenout-1)
                            codeout2 = codeout2<<1;
                            i = i + 1;
                    end
                    
                    else if(mins == 3) begin
                        codeout2[0] = ((paths[3]>>((lenout-1-i)*3))&'b111)>>2;
                        mins = (paths[3]>>((lenout-1-i)*3))& 'b11;
                        
                        if(i!=lenout-1)
                            codeout2 = codeout2<<1;
                            i = i + 1;
                    end
                end
                else begin
                    for (i = 0; i < lenout; i = i + 1) begin
                        codeout[i] = codeout2[lenout-1-i];
                    end
                    finish = 1;
                end
            end
            
        endcase
    end
end

endmodule
