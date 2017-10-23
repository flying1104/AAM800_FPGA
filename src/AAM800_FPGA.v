/*=================================================================*\
Filename				:	AAM800_FPGA.v
Author				:	Wisely
Description			:	
Revision	History	:	2017-10-10
							V1.0
Company				:
Email					:
Copyright(c) ,DreamFly Technology Inc,All right reserved
\*=================================================================*/
module AAM800_FPGA(
	input clk24567M,
	input clk256FS,
	
	input clk27M,

	input i2sMclkChannel0,
	input i2sSclkChannel0,
	input i2sLrckChannel0,
	input i2sDataChannel0,
	
	output [6:1]LEDGroup,
	output [32:1]LEDSegment,
	
	output led,
	
	output [1:0]clkFs,
	output clkSr
);
//============================================================
//Parameter
//============================================================

parameter FREQ_32K	=  16'h1,
			 FREQ_441K	=	16'h2,
			 FREQ_48K	=  16'h3,
			 FREQ_96k	=	16'h4;
			 
//============================================================
//Local Var
//============================================================

//reg

//wire
wire RST = 1'b1;
wire [15:0]audioFreqMode;	
wire [5:0]i2sSclkCntChannel0;

wire [2:0]HoldTime = 3'd4;
wire HoldRelease = 1'd1;

//============================================================
//Assignment
//============================================================

assign audioFreqMode = FREQ_441K;

assign Key1 = 1'b1;
assign Key2 = 1'b1;

assign spdifInSel = 1'b1;

//============================================================
//Module 
//============================================================
GlobalClk GlobalClk_U1
(
	.adc_mclk_channel0(i2sMclkChannel0),
	.adc_sclk_channel0(i2sSclkChannel0),
	.adc_lrck_channel0(i2sLrckChannel0),	
	.adc_sclk_cnt_channel0(i2sSclkCntChannel0)
	
);

DigitalLevelMeter DigitalLevelMeter_U1
(
	.Lrck(i2sLrckChannel0),
	.Sclk(i2sSclkChannel0),
	.SclkCnt(i2sSclkCntChannel0),
	.Data(i2sDataChannel0),
	.OscClk(clk27M),
	.SPDIFInput1(SPDIFInput1),
	.SPDIFInput2(),
	.HoldTime(HoldTime),
	.HoldRelease(HoldRelease),
	.SPDIFInSel(spdifInSel),
	.SPDIFOutput(SPDIFOutput),
	.LEDGroup(LEDGroup),
	.LEDSegment(LEDSegment),
	.Key1(Key1),
	.Key2(Key2)
);

dev_pll1707 dev_pll1707_u1(
	.fs(clkFs),
	.sr(clkSr),
	.audio_freq_mode(audioFreqMode)
);

dev_led dev_led(
	.led(led)
);
//============================================================
//Alway block
//============================================================










endmodule

