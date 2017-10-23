/*
**************************************************************************
*       			  	    spi 
*
* Filename  : spi.v
* Programmer: jose.huang
* Project   : 
* Version   : V1.0
* TOP MODULE: SpiModule.v
* Describel	: spi����,������λ����ģ��;
* 						����,���վ�Ϊ8λ����;
*							����ʱ,��������������;
*							����ʱ,��������֮ǰ��������
*							����SPI�Ӷ�ģʽ
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

input	rst_n;													// �첽����
input	sdi;													// spi data input
input	sck;													// spi clk, MAX 25MHz
input	cs;														// spi enable
input	clk;													// cpld main clk,MIN 50MHz
input[7:0]	IData;									// Input 8bit Data want to transmit to mcu
input	TransFlag;										// ���ͱ�־
output	reg	sdo;										// spi data output
output 	reg[7:0]	OData;						// Receive 8bit Data �����ֻ�����
output	reg	ReceiveFlag;						// �յ�8bit Data ��־
output	reg TransEndFlag;           // ���ͽ�����־

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
	if(!rst_n)													// �첽���� 
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
	if(!rst_n)                  				// �첽���� 
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

// ����
reg[7:0] ShiftCounter;
reg[7:0] ClrFlagCounter;
reg Bwsck;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)															// �첽���� 
	begin
		ShiftCounter <= 8'b0;
		ReceiveFlag <= 1'b0;	
		TransEndFlag <= 1'b0;								// shift״̬����ձ�־
		Bwsck <= 1'b0;	
	end
	else if(wcs)													// �����첽����
	begin
		ShiftCounter <= 8'b0;
		Bwsck <= 1'b0;
		if(ClrFlagCounter == 10)
		begin
			ReceiveFlag <= 1'b0;							// SPI������������ձ�־
			TransEndFlag <= 1'b0;							// shift״̬����ձ�־
		end
		else ClrFlagCounter <= ClrFlagCounter + 1'b1;	
	end
	else
	begin
		Bwsck <= wsck;
		ClrFlagCounter <= 8'b0;
		if(wsck && (!Bwsck))								 	// �����ش���
		begin
			if(ShiftCounter == 7)
			begin
				ShiftCounter <= 8'b0;
				if(!TransFlag)										// receive data from mcu
					ReceiveFlag <= 1'b1;						// �յ�8bit data
				else 
					TransEndFlag <= 1'b1;						// �������
			end
			else 
			begin
				ShiftCounter <= ShiftCounter + 1'b1;
				ReceiveFlag <= 1'b0;							// shift״̬����ձ�־
				TransEndFlag <= 1'b0;							// shift״̬����ձ�־
			end
		end
	end
end

// ��λ
always@(posedge clk or negedge rst_n or posedge wcs)
begin
	if(!rst_n)
		sdo <= 1'b0;
	else if(wcs)
		sdo <= 1'b0;
	else if(wsck && (!Bwsck))									//�����ش���
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
