/*
**************************************************************************
*       			  	    spi 
*
* Filename  : spi.v
* Programmer: jose.huang
* Project   : 
* Version   : V1.0
* TOP MODULE: SpiModule.v
* Describel	: spi总线,数据移位处理模块;
* 						发送,接收均为8位数据;
*							接收时,上升沿移入数据;
*							发送时,上升沿来之前放上数据
*							用于SPI从动模式
* ************************************************************************
* Date        Comment 				Author    		Email								TEL
* 08-31				original 				jose.huang   work_email@msn.com		
*	-------			----				
* 
**************************************************************************
*/
module spi (rst_n,clk,
			sdi,sdo,sck,cs,
			OData,IData,
			ReceiveFlag,TransFlag,TransEndFlag);

input	rst_n;													// 异步清零
input	sdi;													// spi data input
input	sck;													// spi clk, MAX 25MHz
input	cs;														// spi enable
input	clk;													// cpld main clk,MIN 50MHz
input[7:0]	IData;									// Input 8bit Data want to transmit to mcu
input	TransFlag;										// 发送标志
output	reg	sdo;										// spi data output
output 	reg[7:0]	OData;						// Receive 8bit Data 命令字或数据
output	reg	ReceiveFlag;						// 收到8bit Data 标志
output	reg TransEndFlag;           // 发送结束标志

/*
*********************************************************************
* CPLD IO sampling process
*/
reg[2:0]	CPLDPort;
reg[2:0]	TempPort;
reg[2:0] 	BufferPort;								// sampling CPLD IO Data to BufferPort
reg[8:0] 	samplnum;

always@(posedge clk)
begin
	CPLDPort[0]	<= sdi;
	CPLDPort[1]	<= sck;
	CPLDPort[2]	<= cs; 
end
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)													// 异步清零 
	begin
		samplnum <= 9'b0;
	end
	else if(TempPort == CPLDPort)
	begin
		samplnum <= samplnum + 1'b1;
	end
	else 
	begin
		samplnum <= 9'b0;
		TempPort <= CPLDPort;
	end
end

always@(posedge clk  or negedge rst_n)
begin
	if(!rst_n)                  				// 异步清零 
	begin                     		
		BufferPort[0] <= 1'b0;					//CPLDPort[0]	<= sdi;
		BufferPort[1] <= 1'b0;					//CPLDPort[1]	<= sck;
		BufferPort[2] <= 1'b1;					//CPLDPort[2]	<= cs; 
	end                       		
	else                      		
	begin                     		
		if(samplnum > 10)								// set by cpld main clk and spi clk 
		begin
			BufferPort <= TempPort;
		end
		else BufferPort <= BufferPort;
	end
end

/*
*********************************************************************
* SPI Data receive and transmit shift process
*/
wire wsdi;
wire wsck;
wire wcs;
assign wsdi = BufferPort[0];						//CPLDPort[0]	<= sdi;
assign wsck = BufferPort[1];						//CPLDPort[1]	<= sck;
assign wcs  = BufferPort[2];						//CPLDPort[2]	<= cs; 

// 计数
reg[7:0] ShiftCounter;
reg[7:0] ClrFlagCounter;
reg Bwsck;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)															// 异步清零 
	begin
		ShiftCounter <= 8'b0;
		ReceiveFlag <= 1'b0;	
		TransEndFlag <= 1'b0;								// shift状态清接收标志
		Bwsck <= 1'b0;	
	end
	else if(wcs)													// 结束异步清零
	begin
		ShiftCounter <= 8'b0;
		Bwsck <= 1'b0;
		if(ClrFlagCounter == 10)
		begin
			ReceiveFlag <= 1'b0;							// SPI操作结束清接收标志
			TransEndFlag <= 1'b0;							// shift状态清接收标志
		end
		else ClrFlagCounter <= ClrFlagCounter + 1'b1;	
	end
	else
	begin
		Bwsck <= wsck;
		ClrFlagCounter <= 8'b0;
		if(wsck && (!Bwsck))								 	// 上升沿处理
		begin
			if(ShiftCounter == 7)
			begin
				ShiftCounter <= 8'b0;
				if(!TransFlag)										// receive data from mcu
					ReceiveFlag <= 1'b1;						// 收到8bit data
				else 
					TransEndFlag <= 1'b1;						// 发送完成
			end
			else 
			begin
				ShiftCounter <= ShiftCounter + 1'b1;
				ReceiveFlag <= 1'b0;							// shift状态清接收标志
				TransEndFlag <= 1'b0;							// shift状态清接收标志
			end
		end
	end
end

// 移位
always@(posedge clk or negedge rst_n or posedge wcs)
begin
	if(!rst_n)
		sdo <= 1'b0;
	else if(wcs)
		sdo <= 1'b0;
	else if(wsck && (!Bwsck))									//上升沿处理
	begin
		if(!TransFlag)													// receive data from mcu
		begin
				OData <= {OData[6:0],wsdi};
		end
		else																		// transmit data to mcu
		begin
				sdo <= IData[7-ShiftCounter];	
		end 
	end
end 

endmodule
