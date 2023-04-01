#include"basic_cordic.h"
#include <iostream>

using namespace std;

void cordic_sin_cos(data_t x0, data_t y0, data_t z0, data_t &sin_out, data_t &cos_out){
/*
This function is the core part of calculating sin and cos using CORDIC.

Input:
	x0, y0: initial values for the CORDIC process
	z0	  : input angle for your sin or cos output (should be in range [-PI, PI])
Output:
	sin_out: output result of sin(z0)
	cos_out: output result of cos(z0)
*/

	data_t xi[N];
	data_t yi[N];
	data_t zi[N];

	xi[0] = (data_t) 1/G * x0;
	yi[0] = (data_t) 1/G * y0;

	// determine zi[0]
	if(z0 > PI/2){
		// original theta is larger than 90 degree (PI/2)
		zi[0] = PI - z0;
	}
	else if(z0 < -PI/2){
		// original theta is smaller than -90 degree (-PI/2)
		zi[0] = -PI - z0;
	}
	else{
		// else don't need to change
		zi[0] = z0;
	}

	//CORDIC
	#pragma HLS pipeline II=1
	for(int m=0; m<N; m++){
		if(zi[m] >= 0){
			xi[m+1] = xi[m] - (yi[m] >> m);
			yi[m+1] = yi[m] + (xi[m] >> m);
			zi[m+1] = zi[m] - atan4cordic[m];
		}
		else{
			xi[m+1] = xi[m] + (yi[m] >> m);
			yi[m+1] = yi[m] - (xi[m] >> m);
			zi[m+1] = zi[m] + atan4cordic[m];
		}
	}

	// Select the proper result
	sin_out = yi[N-1];
	if(z0 > PI/2 || z0 < -PI/2){
		cos_out = -xi[N-1];
	}
	else{
		cos_out = xi[N-1];
	}
}

void cordic_arctan(data_t sin_in, data_t cos_in, data_t &atan_out){
/*
This function is the core part of calculating arctan using CORDIC.

Input:
	sin_in: sine value (should be in range [-1, 1])
	cos_in: cosine value (should be in range [0, 1])
Output:
	atan_out: output angle of atan(sin_in/cos_in) (should be in range [-PI/2, PI/2])
*/

	data_t xi[N];
	data_t yi[N];
	data_t zi[N];

	//set correct initial values
	xi[0] = cos_in;
	yi[0] = sin_in;
	zi[0] = 0;

	//CORDIC
	#pragma HLS pipeline II=1
	for(int m=0; m<N; m++){
		if(yi[m] <= 0){
			xi[m+1] = xi[m] - (yi[m] >> m);
			yi[m+1] = yi[m] + (xi[m] >> m);
			zi[m+1] = zi[m] - atan4cordic[m];
		}
		else{
			xi[m+1] = xi[m] + (yi[m] >> m);
			yi[m+1] = yi[m] - (xi[m] >> m);
			zi[m+1] = zi[m] + atan4cordic[m];
		}
	}

	//fix output angle based on bounds [-PI/2, PI/2]
	if(zi[N-1] > PI/2 || zi[N-1] < -PI/2){
		atan_out = -zi[N-1];
	}
	else{
		atan_out = zi[N-1];
	}
}
