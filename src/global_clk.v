/*=================================================================*\
Filename				:	global_clk.v
Author				:	Wisely
Description			:	
Revision	History	:	2017-04-07
							V1.0
Company				:
Email					:
Copyright(c) ,DreamFly Technology Inc,All right reserved
\*=================================================================*/
module global_clk(
	rst_n,
	clk_in,
	mclk,
	sclk,
	lrck,
	xlr_mclk,
	xlr_sclk,
	xlr_lrck,
	aes_mclk,
	aes_sclk,
	aes_lrck,
	cs4272_mclk,
	cs4272_sclk,
	cs4272_lrck,
	cs8416_mclk, 
	cs8416_sclk, 
	cs8416_lrck,
	cs8406_mclk,
	cs8406_sclk,
	cs8406_lrck,
	i2s_sclk,
	i2s_lrck,
	wav_mclk,
	wav_sclk,
	wav_lrck
);

//============================================================
//Post in/out
//============================================================
input rst_n;

input clk_in;

output mclk;
output sclk;
output lrck;

output xlr_mclk;
output xlr_sclk;
output xlr_lrck;

output aes_mclk;
output aes_sclk;
output aes_lrck;

output cs4272_mclk;
output cs4272_sclk;
output cs4272_lrck;

output cs8416_mclk;
output cs8416_sclk;
output cs8416_lrck;

output cs8406_mclk;
output cs8406_sclk;
output cs8406_lrck;

output i2s_sclk;
output i2s_lrck;

output wav_mclk;
output wav_sclk;
output wav_lrck;

//============================================================
//Local Var
//============================================================

//reg
reg [7:0]div256_cnt;
reg [6:0]div128_cnt;
reg [5:0]div64_cnt;
reg [1:0]div4_cnt;
reg [0:0]div2_cnt;

//wire
wire global_clk_select;
wire clk_lfs;
wire clk_mfs;
wire clk_hfs;
wire clk_l64fs;
wire clk_m64fs;

//============================================================
//Assignment
//============================================================
assign global_clk_select = 1'b0;
assign clk_lfs = (div256_cnt >= 8'd128) ? 1'b1 : 1'b0;
assign clk_mfs = (div128_cnt >= 7'd64) ? 1'b1 : 1'b0;
assign clk_hfs = (div64_cnt >= 6'd32) ? 1'b1 : 1'b0;
assign clk_l64fs = div4_cnt[1];

assign clk_m64fs = div2_cnt[0];


assign sclk = clk_l64fs;
assign lrck = clk_lfs;

assign xlr_mclk = mclk;
assign xlr_sclk = sclk;
assign xlr_lrck = lrck;

assign aes_mclk = mclk;
assign aes_sclk = sclk;
assign aes_lrck = lrck;

assign cs4272_mclk = mclk;
assign cs4272_sclk = sclk;
assign cs4272_lrck = lrck;

assign cs8416_mclk = mclk;
assign cs8416_sclk = sclk;
assign cs8416_lrck = lrck;

assign cs8406_mclk = mclk;
assign cs8406_sclk = sclk;
assign cs8406_lrck = lrck;

assign i2s_sclk = sclk;
assign i2s_lrck = lrck;

assign wav_mclk = mclk;
assign wav_sclk = sclk;
assign wav_lrck = lrck;

//============================================================
//Module 
//============================================================
global_clk_ip global_clk_ip_u1(
	.clkselect(global_clk_select),
	.inclk0x(clk_in),
	.inclk1x(),
	.outclk(mclk)
);
//============================================================
//Alway block
//============================================================
always@(posedge mclk or negedge rst_n)
begin
	if(!rst_n) begin
		div256_cnt = 8'h0;
	end
	else begin
		div256_cnt = div256_cnt + 1'b1;
	end
end

always@(posedge mclk or negedge rst_n)
begin
	if(!rst_n) begin
		div128_cnt = 7'h0;
	end
	else begin
		div128_cnt = div128_cnt + 1'b1;
	end
end

always@(posedge mclk or negedge rst_n)
begin
	if(!rst_n) begin
		div64_cnt = 6'h0;
	end
	else begin
		div64_cnt = div64_cnt + 1'b1;
	end
end

always@(posedge mclk or negedge rst_n)
begin
	if(!rst_n) begin
		div4_cnt = 2'h0;
	end
	else begin
		div4_cnt = div4_cnt + 1'b1;
	end
end

always@(posedge mclk or negedge rst_n)
begin
	if(!rst_n) begin
		div2_cnt = 1'h0;
	end
	else begin
		div2_cnt = div2_cnt + 1'b1;
	end
end

endmodule
