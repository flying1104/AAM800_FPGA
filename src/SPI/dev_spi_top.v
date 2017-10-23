module spi_top(
   rst_n,
   clk,
   sdi,sdo,sck,cs,
   idata1,idata2,
   odata0,odata1,odata2,odata3,odata4,odata5,odata6,odata7,odata8,odata9,odata10,odata11,odata12
   );

input	rst_n;														// 异步清零                                    
input	clk;														// spi data input                              
input	sdi;														// spi clk, MAX 25MHz                          
input	cs;															// spi enable                                  
input	sck; 														// cpld main clk,MIN 50MHz                     
input[7:0]	idata1;										// input data1 want to send
input[7:0]	idata2;                   // input data2 want to send
output	sdo;													// spi data output 
output  reg[7:0]    odata0;
output 	reg[7:0]	odata1;							// receive data1 write to cpld
output  reg[7:0]    odata2;
output  reg[7:0]    odata3;
output  reg[7:0]    odata4;
output  reg[7:0]    odata5;
output  reg[7:0]    odata6;
output  reg[7:0]    odata7;
output  reg[7:0]    odata8;
output  reg[7:0]    odata9;
output  reg[7:0]    odata10;
output  reg[7:0]    odata11;
output  reg[7:0]    odata12;

/*
**********************************************************************
*/
wire 	ReceiveFlag;										// SPI收到8位数据标志
wire 	TransEndFlag;										// 发送结束标志
reg		CmdFlag;												// 命令为1,数据为0     
reg		TransFlag;											// 告诉SPI发送数据标志,并处于发送状态
reg		RFstRunFlag;										// run once time by once receivceflag
reg[7:0]		CmdStore;									// 保存指令和操作地址
reg[7:0]		SPIData;									// 发送的数据寄存器
wire[7:0]		SPICoder;									// 命令字和操作地址
parameter 	CODER0CMD	=	8'b11110000,				// 操作指令和操作地址0//f0
			CODER1CMD	=	8'b11110001,				// 操作指令和操作地址1//f1
			CODER2CMD	=	8'b11110010,		    	// 操作指令和操作地址2//f2
			CODER3CMD   =   8'b11110011,                // 操作指令和操作地址3//f3
			CLK_CMD     =   8'ha0,
			IN_CHS_CMD  =   8'ha1,
			OUT_CHS_CMD =   8'ha2,
			DELAY_CMD1  =   8'hb0,
			DELAY_CMD2  =   8'hb1,
			DELAY_CMD3  =   8'hb2,
			DUMP_CMD    =   8'hc1,
			D2_8_CMD    =   8'hc2,
			COUGH_CMD1  =   8'hc3,
			COUGH_CMD2  =   8'hc4,
			ID_CMD      =   8'h7d;

spi spi_u1(	.rst_n(rst_n),.clk(clk),.sdi(sdi),.sdo(sdo),.sck(sck),.cs(cs),
			.OData(SPICoder),.IData(SPIData),
			.ReceiveFlag(ReceiveFlag),.TransFlag(TransFlag),.TransEndFlag(TransEndFlag));
					
/*
**********************************************************************
*/
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)															// 异步清零
	begin                               	
		RFstRunFlag <= 1'b0;              	
		TransFlag <= 1'b0;									// 写状态
		CmdFlag <= 1'b0;										// 命令状态,写指令状态
	end
	else if(ReceiveFlag)									// 收到数据(指令或数据)
	begin
		if(!RFstRunFlag)										// 是否处理?
		begin
			RFstRunFlag <= 1'b1;					    // 发送指令完成
			if(!CmdFlag)											// 第一个8位数据为SPI指令
			begin
// 读,MCU read CPLD		
				CmdStore <= SPICoder;						// 保存指令和操作地址
				case(SPICoder)
				   CODER0CMD:begin										// 读线信号计数寄存器高8位
					  TransFlag <= 1'b1;					// 读CPLD指令,mcu read cpld command by spi
					  SPIData <= idata1;
					  CmdFlag		<= CmdFlag;				// 读数据,向MCU发送数据
				   end
				   CODER1CMD:begin										// 读线信号计数寄存器低8位
					  TransFlag <= 1'b1;					// 读CPLD指令,mcu read cpld command by spi
					  SPIData <= idata2;
					  CmdFlag		<= CmdFlag;				// 读数据,向MCU发送数据
				   end
// 写,MCU write CPLD
				   ID_CMD:begin
					  TransFlag <= 1'b0;					
				  	  CmdFlag	<= 1'b1;					
				   end
				   CODER2CMD:begin
				      TransFlag <= 1'b0;					// 写CPLD指令,mcu write cpld command by spi
				  	  CmdFlag	<= 1'b1;					// 写数据状态
				   end
				   CODER3CMD:begin
					  TransFlag <= 1'b0;					
				  	  CmdFlag	<= 1'b1;					
				   end
				   CLK_CMD:begin
					  TransFlag <= 1'b0;					
				  	  CmdFlag	<= 1'b1;					
				   end
				   IN_CHS_CMD:begin
					  TransFlag <= 1'b0;					
				  	  CmdFlag	<= 1'b1;					
				   end
				   OUT_CHS_CMD:begin
					  TransFlag <= 1'b0;					
				  	  CmdFlag   <= 1'b1;					
				   end				   
				   DELAY_CMD1:begin
					  TransFlag <= 1'b0;					
				  	  CmdFlag   <= 1'b1;					
				   end
				   DELAY_CMD2:begin
					  TransFlag <= 1'b0;					
				  	  CmdFlag   <= 1'b1;					
				   end
				   DELAY_CMD3:begin
					  TransFlag <= 1'b0;					
				  	  CmdFlag   <= 1'b1;					
				   end
				   DUMP_CMD:begin
					  TransFlag <= 1'b0;					
				  	  CmdFlag   <= 1'b1;					
				   end
				   D2_8_CMD:begin
					  TransFlag <= 1'b0;					
				  	  CmdFlag   <= 1'b1;					
				   end
				   COUGH_CMD1:begin
					  TransFlag <= 1'b0;					
				  	  CmdFlag   <= 1'b1;					
				   end
				   COUGH_CMD2:begin
					  TransFlag <= 1'b0;					
				  	  CmdFlag   <= 1'b1;					
				   end				   
				   default:
				   begin
					  TransFlag <= 1'b0;					// 默认写状态
				  	  CmdFlag   <= 1'b1;					// 写数据状态
				  end
				endcase
			end		// 处理指令结束,CmdFlag
			else	// SPI写数据,CPLD读第二个数据
			begin
			  	CmdFlag		<= 1'b0;							// 清为写指令状态 
			  	case(CmdStore)									// SPICoder old value
				  		ID_CMD:begin
				            odata0 <= SPICoder;
				        end
						CODER2CMD:begin
							odata1 <= SPICoder;					// 写数据
				  	    end
				  	    CODER3CMD:begin
				            odata2 <= SPICoder;
				        end 
				        CLK_CMD:begin
				            odata3 <= SPICoder;
				        end
			            IN_CHS_CMD:begin
				            odata4 <= SPICoder;
				        end
			            OUT_CHS_CMD:begin
				            odata5 <= SPICoder;
				        end				        
				        DELAY_CMD1:begin
				            odata6 <= SPICoder;
				        end
				        DELAY_CMD2:begin
				            odata7 <= SPICoder;
				        end
				        DELAY_CMD3:begin
				            odata8 <= SPICoder;
				        end
				        DUMP_CMD:begin
				            odata9 <= SPICoder;
				        end
				        D2_8_CMD:begin
				            odata10 <= SPICoder;
				        end
				        COUGH_CMD1:begin
				            odata11 <= SPICoder;
				        end
				        COUGH_CMD2:begin
				            odata12 <= SPICoder;
				        end				  		        
				  	default:
				  	begin

				  	end
				  endcase			  					
			end			
		end	// 处理接收标志完成 
	end		// 受到SPI指令处理完成
	else if(TransEndFlag)	// 发送结束
	begin
		TransFlag <= 1'b0;
	end
	else	// 发送数据或接收下个数据状态
	begin
		 RFstRunFlag <= 1'b0;
		 TransFlag <= TransFlag;
	end
end

endmodule 
