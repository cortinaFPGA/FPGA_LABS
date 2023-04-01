`timescale 1ns / 1ps

module kalman(
clk,
rst,
n,      // Input: Index of the inputs.
u,      // Input: Scalar: Acceleration.
z,      // Input: 2x1 Z Vector; Measurement of x.
x0,     // Initial state of x.
P0,     // Initial state of P Matrix.
F,      // Input: 2x2 F Matrix.
B,      // Input: 2x1 B Vector.
Q,      // Input: 2x2 Q Matrix.
H,      // Input: 2x2 H Matrix.
R,      // Input: 2x2 R Matrix.
no,     // Output: 
xo,     // Output: 
outen   // Output: output enable: a flag signal. 
    );

parameter len=2;//# of input data
parameter dsize=16;//the length of each data
parameter decimal=4;

input clk,rst;
input[dsize-1:0] n;
input[dsize-1:0] u;
input[dsize*len-1:0] z;
input[dsize*len-1:0] x0;
input[dsize*len*len-1:0] P0;
input[dsize*len*len-1:0] F,H,Q,R;
input[dsize*len-1:0] B;
output reg[dsize-1:0] no;
output reg[dsize*len-1:0] xo;
output reg outen;

reg[dsize*len*len-1:0] temp;
reg[dsize-1:0] temp2,temp3;

reg[dsize-1:0] mi[1:0][3:0];
wire[dsize-1:0] mo[3:0];

wire[dsize*2*2-1:0] mmin1;
wire[dsize*2*2-1:0] mmin2;
wire[dsize*2*2-1:0] mmout;

assign mmin1[dsize-1:0]=mi[0][0];            
assign mmin1[2*dsize-1:dsize]=mi[0][1];
assign mmin1[3*dsize-1:2*dsize]=mi[0][2];
assign mmin1[4*dsize-1:3*dsize]=mi[0][3];

assign mmin2[dsize-1:0]=mi[1][0];
assign mmin2[2*dsize-1:dsize]=mi[1][1];
assign mmin2[3*dsize-1:2*dsize]=mi[1][2];
assign mmin2[4*dsize-1:3*dsize]=mi[1][3];

assign mo[0]=mmout[dsize-1:0];
assign mo[1]=mmout[2*dsize-1:dsize];
assign mo[2]=mmout[3*dsize-1:2*dsize];
assign mo[3]=mmout[4*dsize-1:3*dsize];


/////////////////////////////////////////////////////////////////////
//  | mo[0] mo[1] | =   | mi[0][0] mi[0][1] | x | mi[1][0] mi[1][1] |
//  | mo[2] mo[3] |     | mi[0][2] mi[0][3] |   | mi[1][2] mi[1][3] |
/////////////////////////////////////////////////////////////////////
matmul22 #(.size(dsize),.decimal(decimal)) mm0(mmin1,mmin2,mmout);
reg[dsize-1:0] divin;
wire[dsize-1:0] divout;

// divout = 1 / divin.
divider #(.size(dsize),.decimal(decimal)) d0(divin,divout);

reg[dsize-1:0] nk;
reg zenk;
reg[dsize*len-1:0] uk,zk,xkm,xkp,yk;    // Vector; Width = 16x2 = 32.
reg[dsize*len*len-1:0] Pkm,Kk,Pkp;      // Matrix; Width = 16x2x2 = 64.

parameter IDLE=0;
parameter XKM=1;    // X-
parameter PKM=2;    // P-
parameter YK=3;     // Yk
parameter KK=4;     // Kk
parameter XKP=5;    // X+
parameter PKP=6;    // P+
parameter OUT=7;    // Output
parameter TEST=8;

reg[7:0] count;

reg[7:0] state;

reg[7:0] i,j;

always@(posedge clk or negedge rst)begin
    if(~rst)begin
        outen<=0;
        for(i=0;i<len;i=i+1)begin
            for(j=0;j<len;j=j+1)begin
                mi[i][j]<=0;
            end
        end
        count<=0;
        no<=0;
        xkp<=x0;
        Pkp<=P0;
        state<=IDLE;
    end
    else begin
        case(state)
        IDLE:begin//sampling
            outen<=0;
            nk<=n;
            zk<=z;
            uk<=u;
            count<=0;
            state<=XKM;
        end
        XKM:begin
            if(count==0)begin
                mi[0][0]<=F[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0];   // mi[0][0] = F[15:0]    = F[0][0].
                mi[0][1]<=F[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];   // mi[0][1] = F[31:16]   = F[0][1].
                mi[0][2]<=F[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];   // mi[0][2] = F[47:32]  = F[1][0].
                mi[0][3]<=F[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];   // mi[0][3] = F[63:48]  = F[1][1].
                mi[1][0]<=xkp[dsize*0+dsize-1:dsize*0];                         // mi[1][0] = X_k_plus[0].
                mi[1][2]<=xkp[dsize*1+dsize-1:dsize*1];                         // mi[1][2] = X_k_plus[1]
                count<=count+1;
                // mo = F * [X_k_plus;0].
            end
            else if(count==1)begin
                xkm[dsize-1:0]<=mo[0];                  // X_k_minus = F * X_k_plus. X- = F * X+
                xkm[2*dsize-1:dsize]<=mo[2];
                mi[0][0]<=B[dsize*0+dsize-1:dsize*0];   // mi_0 = B.
                mi[0][1]<=0;
                mi[0][2]<=B[dsize*1+dsize-1:dsize*1];
                mi[0][3]<=0;
                mi[1][0]<=uk;                           // mi_1 = u.
                mi[1][2]<=0;
                count<=count+1;
                // mo = B * u.
            end
            else if(count==2)begin
                xkm[dsize-1:0]<=xkm[dsize-1:0]+mo[0];               // X- = X- + B*u.
                xkm[2*dsize-1:dsize]<=xkm[2*dsize-1:dsize]+mo[2];
                count<=0;
                state<=PKM;
            end
        end
        PKM:begin
            if(count==0)begin
                mi[0][0]<=F[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0];   // mi_0 = F.
                mi[0][1]<=F[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];
                mi[0][2]<=F[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];
                mi[0][3]<=F[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];
                mi[1][0]<=Pkp[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0]; // mi_1 = P+.
                mi[1][1]<=Pkp[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];
                mi[1][2]<=Pkp[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];
                mi[1][3]<=Pkp[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];
                count<=count+1;
            end
            else if(count==1)begin                                              
                mi[0][0]<=mo[0];                                                // mi_0 = F * P+.
                mi[0][1]<=mo[1];
                mi[0][2]<=mo[2];
                mi[0][3]<=mo[3];
                mi[1][0]<=F[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0];   // mi_1 = F'.
                mi[1][1]<=F[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];
                mi[1][2]<=F[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];
                mi[1][3]<=F[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];
                count<=count+1;
            end
            else if(count==2)begin                                              // P- = F * (P+) * F'.
                Pkm[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0]<=Q[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0]+mo[0];
                Pkm[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1]<=Q[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1]+mo[1];
                Pkm[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0]<=Q[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0]+mo[2];
                Pkm[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1]<=Q[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1]+mo[3];
                count<=0;
                state<=YK;
            end
        end
        YK:begin    // 
            if(count==0)begin   // mo = H * X-. 
                mi[0][0]<=H[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0];
                mi[0][1]<=H[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];
                mi[0][2]<=H[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];
                mi[0][3]<=H[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];
                mi[1][0]<=xkm[dsize*0+dsize-1:dsize*0];
                mi[1][2]<=xkm[dsize*1+dsize-1:dsize*1];
                count<=count+1;
            end
            else if(count==1)begin  // y = z - H * X-.
                yk[dsize-1:0]<=zk[dsize-1:0]-mo[0];
                yk[2*dsize-1:dsize]<=zk[2*dsize-1:dsize]-mo[2];
                count<=0;
                state<=KK;
            end
        end
        KK:begin    
            if(count==0)begin   // mo = H * P-
                mi[0][0]<=H[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0];
                mi[0][1]<=H[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];
                mi[0][2]<=H[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];
                mi[0][3]<=H[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];
                mi[1][0]<=Pkm[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0];
                mi[1][1]<=Pkm[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];
                mi[1][2]<=Pkm[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];
                mi[1][3]<=Pkm[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];
                count<=count+1;
            end
            else if(count==1)begin  // mo = mo * H'
                mi[0][0]<=mo[0];
                mi[0][1]<=mo[1];
                mi[0][2]<=mo[2];
                mi[0][3]<=mo[3];
                mi[1][0]<=H[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0];
                mi[1][1]<=H[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];
                mi[1][2]<=H[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];
                mi[1][3]<=H[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];
                count<=count+1;
            end
            else if(count==2)begin // temp = R + H * P- * H'.
                temp[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0]<=R[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0]+mo[0];
                temp[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1]<=R[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1]+mo[1];
                temp[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0]<=R[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0]+mo[2];
                temp[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1]<=R[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1]+mo[3];
                count<=count+1;
            end
            else if(count==3)begin // mo = P- * H'
                mi[0][0]<=Pkm[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0];
                mi[0][1]<=Pkm[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];
                mi[0][2]<=Pkm[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];
                mi[0][3]<=Pkm[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];
                mi[1][0]<=H[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0];
                mi[1][1]<=H[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];
                mi[1][2]<=H[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];
                mi[1][3]<=H[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];
                count<=count+1;
            end
            else if(count==4)begin  // mo = (p- * H') * temp^(-1).
                mi[0][0]<=mo[0];
                mi[0][1]<=mo[1];
                mi[0][2]<=mo[2];
                mi[0][3]<=mo[3];
                mi[1][0]<=temp[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];
                mi[1][1]<=-temp[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];
                mi[1][2]<=-temp[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];
                mi[1][3]<=temp[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0];
                count<=count+1;
            end
            else if(count==5)begin  // Kk = (p- * H') * temp' = (p- * H') * (R + H * P- * H')^(-1).
                Kk[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0]<=mo[0];
                Kk[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1]<=mo[1];
                Kk[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0]<=mo[2];
                Kk[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1]<=mo[3];
                mi[0][0]<=temp[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0];    // mi[0][0] = temp[0][0].
                mi[0][1]<=temp[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];    // mi[0][1] = temp[0][1].
                mi[0][2]<=0;
                mi[0][3]<=0;
                mi[1][0]<=temp[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];    // mi[1][0] = temp[1][1].
                mi[1][1]<=0;
                mi[1][2]<=-temp[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];   // mi[1][2] = -temp[1][0].
                mi[1][3]<=0;
                count<=count+1;
            end
            else if(count==6)begin
                divin<=mo[0];                                                       // mo[0][0] = temp[0][0]*temp[1][1]-temp[0][1]*temp[1][0].
                count<=count+1;
            end
            else if(count>=7&&count<12)begin
                count<=count+1;
            end
            else if(count==12)begin
                temp2<=divout;      // temp2 = 1/|temp|
                count<=count+1;
            end
            else if(count==13)begin
                mi[0][0]<=temp2;    // diagonal matrix of 1/|temp|.
                mi[0][1]<=0;
                mi[0][2]<=0;
                mi[0][3]<=temp2;
                mi[1][0]<=Kk[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0]; // Kk.
                mi[1][1]<=Kk[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];
                mi[1][2]<=Kk[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];
                mi[1][3]<=Kk[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];
                count<=count+1;
            end
            else if(count==14)begin
                Kk[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0]<=mo[0]; // Now the calculation of Kk is done.
                Kk[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1]<=mo[1];
                Kk[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0]<=mo[2];
                Kk[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1]<=mo[3];
                count<=0;
                state<=XKP;
            end
        end
        XKP:begin
            if(count==0)begin   //  Kk * y
                mi[0][0]<=Kk[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0];
                mi[0][1]<=Kk[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];
                mi[0][2]<=Kk[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];
                mi[0][3]<=Kk[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];
                mi[1][0]<=yk[dsize*0+dsize-1:dsize*0];
                mi[1][2]<=yk[dsize*1+dsize-1:dsize*1];
                count<=count+1;
            end
            else if(count==1)begin  // x+ = x- + Kk * Y.
                xkp[dsize-1:0]<=xkm[dsize-1:0]+mo[0];
                xkp[2*dsize-1:dsize]<=xkm[2*dsize-1:dsize]+mo[2];
                count<=0;
                state<=PKP;
            end
        end
        PKP:begin
            if(count==0)begin   // Kk * H
                mi[0][0]<=Kk[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0];
                mi[0][1]<=Kk[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];
                mi[0][2]<=Kk[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];
                mi[0][3]<=Kk[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];
                mi[1][0]<=H[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0];
                mi[1][1]<=H[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];
                mi[1][2]<=H[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];
                mi[1][3]<=H[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];
                count<=count+1;
            end
            else if(count==1)begin  // (1-Kk*h)*P-
                mi[0][0]<=(1<<decimal)-mo[0];
                mi[0][1]<=-mo[1];
                mi[0][2]<=-mo[2];
                mi[0][3]<=(1<<decimal)-mo[3];
                mi[1][0]<=Pkm[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0];
                mi[1][1]<=Pkm[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1];
                mi[1][2]<=Pkm[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0];
                mi[1][3]<=Pkm[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1];
                count<=count+1;
            end
            else if(count==2)begin  // P+ = (1-Kk*h)*P-
                Pkp[dsize*len*0+dsize*0+dsize-1:dsize*len*0+dsize*0]<=mo[0];
                Pkp[dsize*len*0+dsize*1+dsize-1:dsize*len*0+dsize*1]<=mo[1];
                Pkp[dsize*len*1+dsize*0+dsize-1:dsize*len*1+dsize*0]<=mo[2];
                Pkp[dsize*len*1+dsize*1+dsize-1:dsize*len*1+dsize*1]<=mo[3];
                count<=0;
                state<=OUT;
            end
        end
        TEST:begin
            mi[0][0]<=(1<<decimal);
            mi[0][1]<=(2<<decimal);
            mi[0][2]<=(3<<decimal);
            mi[0][3]<=(4<<decimal);
            mi[1][0]<=(5<<decimal);
            mi[1][1]<=(6<<decimal);
            mi[1][2]<=(7<<decimal);
            mi[1][3]<=(8<<decimal);
            if(count>=1)
            state<=OUT;
            else
            count<=count+1;
        end
        OUT:begin   // Output.
            outen<=1;
            xo<=xkm;
            no<=nk;
            state<=IDLE;
        end
        endcase
    end
end

endmodule
