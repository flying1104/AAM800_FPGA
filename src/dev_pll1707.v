/*=================================================================*\
Filename				:	dev_pll1707.v
Author				:	Wisely
Description			:	
Revision	History	:	2017-04-07
							V1.0
Company				:
Email					:
Copyright(c) ,DreamFly Technology Inc,All right reserved
\*=================================================================*/
module dev_pll1707(
	fs,
	sr,
	audio_freq_mode
);

//============================================================
//Post in/out
//============================================================
output [2:1]fs;
output sr;
input [15:0]audio_freq_mode;

//assign sr = 0;
//assign fs = 2'b00;

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
reg sr_r;
reg [2:1]fs_r;
//wire

//============================================================
//Assignment
//============================================================

assign sr = sr_r;
assign fs = fs_r;

//============================================================
//Alway block
//============================================================

always@(audio_freq_mode)
begin
	case(audio_freq_mode)
		FREQ_32K: begin
			sr_r = 1'b0;
			fs_r = 2'b10;
		end
		FREQ_441K: begin
			sr_r = 1'b0;
			fs_r = 2'b01;
		end
		FREQ_48K: begin
			sr_r = 1'b0;
			fs_r = 2'b00;
		end
		FREQ_96k: begin
			sr_r = 1'b1;
			fs_r = 2'b00;
		end
	endcase
end





endmodule
