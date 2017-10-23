/*=================================================================*\
Filename				:	audio_delay_fifo.v
Author				:	Wisely
Description			:	
Revision	History	:	2017-04-07
							V1.0
Company				:
Email					:
Copyright(c) ,DreamFly Technology Inc,All right reserved
\*=================================================================*/
module GlobalClk(	
	input adc_mclk_channel0,
	input adc_sclk_channel0,
	input adc_lrck_channel0,	
	output [5:0]adc_sclk_cnt_channel0
	
);


//============================================================
//Parameter
//============================================================

//============================================================
//Local Var
//============================================================

//reg
//adc_channel0
reg adc_blrck_channel0 = 1'b0;
reg [5:0]adc_sclk_cnt_channel0_r = 6'h0;

//wire

//============================================================
//Assignment
//============================================================

//============================================================
//Module 
//============================================================

//============================================================
//Alway block
//============================================================
always@(posedge adc_sclk_channel0)
begin
	adc_blrck_channel0 <= adc_lrck_channel0;
end

always@(posedge adc_sclk_channel0)
begin
	if(adc_lrck_channel0 == 1'b0 && adc_blrck_channel0 == 1'b1)	adc_sclk_cnt_channel0_r = 6'h0;			
	else 																			adc_sclk_cnt_channel0_r = adc_sclk_cnt_channel0_r + 1'b1;
end

assign adc_sclk_cnt_channel0 = adc_sclk_cnt_channel0_r;







endmodule


