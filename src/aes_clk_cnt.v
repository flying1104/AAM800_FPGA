/*=================================================================*\
Filename				:	audio_adc_ctl.v
Author				:	Wisely
Description			:	
Revision	History	:	2017-04-07
							V1.0
Company				:
Email					:
Copyright(c) ,DreamFly Technology Inc,All right reserved
\*=================================================================*/
module aes_clk_cnt(
	input rst_n,
	input sclk,
	input lrck,
	
	input aes1_sclk,
	input aes1_lrck,
	
	input aes2_sclk,
	input aes2_lrck,

	input aes3_sclk,
	input aes3_lrck,

	input aes4_sclk,
	input aes4_lrck,

	input aes5_sclk,
	input aes5_lrck,

	input aes6_sclk,
	input aes6_lrck,

	input aes7_sclk,
	input aes7_lrck,

	input aes8_sclk,
	input aes8_lrck,
	
	output [5:0]sclk_cnt,
	output [5:0]aes1_sclk_cnt
);
//============================================================
//Local Var
//============================================================

//reg
//GLOBAL
reg blrck = 1'b0;
reg [5:0]sclk_cnt_r = 6'h0;
//AES1
reg aes1_blrck = 1'b0;
reg [5:0]aes1_sclk_cnt_r = 6'h0;

//wire

//============================================================
//Alway block
//============================================================

//GLOBAL
always@(posedge sclk or negedge rst_n)
begin
	if(!rst_n) begin
		blrck <= 1'b0;
	end
	else begin
		blrck <= lrck;
	end
end

always@(posedge sclk or negedge rst_n)
begin
	if(!rst_n) begin
		sclk_cnt_r = 6'h0;
	end
	else begin
		if(lrck == 1'b0 && blrck == 1'b1)	sclk_cnt_r = 6'h0;			
		else 											sclk_cnt_r = sclk_cnt_r + 1'b1;
	end
end

assign sclk_cnt = sclk_cnt_r;

//AES1
always@(posedge aes1_sclk or negedge rst_n)
begin
	if(!rst_n) begin
		aes1_blrck <= 1'b0;
	end
	else begin
		aes1_blrck <= aes1_lrck;
	end
end

always@(posedge aes1_sclk or negedge rst_n)
begin
	if(!rst_n) begin
		aes1_sclk_cnt_r = 6'h0;
	end
	else begin
		if(aes1_lrck == 1'b0 && aes1_blrck == 1'b1)	aes1_sclk_cnt_r = 6'h0;			
		else 														aes1_sclk_cnt_r = aes1_sclk_cnt_r + 1'b1;
	end
end

assign aes1_sclk_cnt = aes1_sclk_cnt_r;

endmodule
