/*=================================================================*\
Filename				:	dev_cs8416.v
Author				:	Wisely
Description			:	
Revision	History	:	2017-04-07
							V1.0
Company				:
Email					:
Copyright(c) ,DreamFly Technology Inc,All right reserved
\*=================================================================*/
module dev_cs8416(
	rst_n,
	aes_sclk,
	aes_sclk_cnt,
	aes_ldata_out,
	aes_rdata_out,
	aes_data_out,
	sdin
);

//============================================================
//Post in/out
//============================================================
input rst_n;
input aes_sclk;
input [5:0]aes_sclk_cnt;
output [23:0]aes_ldata_out;
output [23:0]aes_rdata_out;
output [47:0]aes_data_out;
input sdin;

//============================================================
//Local Var
//============================================================

//reg
reg [47:0]aes_data_out_r;
reg [23:0]aes_ldata_out_r;
reg [23:0]aes_rdata_out_r;
reg [23:0]aes_ldata_tmp_out_r;
reg [23:0]aes_rdata_tmp_out_r;
//wire

//============================================================
//Assignment
//============================================================

//assign sdout = sdin;
assign aes_ldata_out = aes_ldata_out_r;
assign aes_rdata_out = aes_rdata_out_r;
assign aes_data_out  = aes_data_out_r;

//============================================================
//Alway block
//============================================================

always@(posedge aes_sclk or negedge rst_n)
begin
	if(!rst_n) begin
		aes_ldata_out_r <= 24'h0;
		aes_rdata_out_r <= 24'h0;
		aes_ldata_tmp_out_r <= 24'h0;
		aes_rdata_tmp_out_r <= 24'h0;
	end
	else begin
		if(aes_sclk_cnt >= 6'd0 && aes_sclk_cnt <= 6'd23) begin
			aes_ldata_tmp_out_r <= {aes_ldata_tmp_out_r[22:0],sdin};
			aes_rdata_tmp_out_r <= 24'h0;
		end
		else if(aes_sclk_cnt >= 6'd32 && aes_sclk_cnt <= 6'd55) begin
			aes_ldata_tmp_out_r <= 24'h0;
			aes_rdata_tmp_out_r <= {aes_rdata_tmp_out_r[22:0],sdin};
		end
		
		if(aes_sclk_cnt == 6'd25) aes_ldata_out_r <= aes_ldata_tmp_out_r;
		if(aes_sclk_cnt == 6'd57) aes_rdata_out_r <= aes_rdata_tmp_out_r;
		if(aes_sclk_cnt == 6'd59) aes_data_out_r  <= {aes_ldata_out_r,aes_rdata_out_r};
	end
end



endmodule



