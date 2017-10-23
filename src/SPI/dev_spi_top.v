module spi_top(
   rst_n,
   clk,
   sdi,sdo,sck,cs,
   idata1,idata2,
   odata0,odata1,odata2,odata3,odata4,odata5,odata6,odata7,odata8,odata9,odata10,odata11,odata12
   );

input	rst_n;														// �첽����                                    
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
wire 	ReceiveFlag;										// SPI�յ�8λ���ݱ�־
wire 	TransEndFlag;										// ���ͽ�����־
reg		CmdFlag;												// ����Ϊ1,����Ϊ0     
reg		TransFlag;											// ����SPI�������ݱ�־,�����ڷ���״̬
reg		RFstRunFlag;										// run once time by once receivceflag
reg[7:0]		CmdStore;									// ����ָ��Ͳ�����ַ
reg[7:0]		SPIData;									// ���͵����ݼĴ���
wire[7:0]		SPICoder;									// �����ֺͲ�����ַ
parameter 	CODER0CMD	=	8'b11110000,				// ����ָ��Ͳ�����ַ0//f0
			CODER1CMD	=	8'b11110001,				// ����ָ��Ͳ�����ַ1//f1
			CODER2CMD	=	8'b11110010,		    	// ����ָ��Ͳ�����ַ2//f2
			CODER3CMD   =   8'b11110011,                // ����ָ��Ͳ�����ַ3//f3
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
	if(!rst_n)															// �첽����
	begin                               	
		RFstRunFlag <= 1'b0;              	
		TransFlag <= 1'b0;									// д״̬
		CmdFlag <= 1'b0;										// ����״̬,дָ��״̬
	end
	else if(ReceiveFlag)									// �յ�����(ָ�������)
	begin
		if(!RFstRunFlag)										// �Ƿ���?
		begin
			RFstRunFlag <= 1'b1;					    // ����ָ�����
			if(!CmdFlag)											// ��һ��8λ����ΪSPIָ��
			begin
// ��,MCU read CPLD		
				CmdStore <= SPICoder;						// ����ָ��Ͳ�����ַ
				case(SPICoder)
				   CODER0CMD:begin										// �����źż����Ĵ�����8λ
					  TransFlag <= 1'b1;					// ��CPLDָ��,mcu read cpld command by spi
					  SPIData <= idata1;
					  CmdFlag		<= CmdFlag;				// ������,��MCU��������
				   end
				   CODER1CMD:begin										// �����źż����Ĵ�����8λ
					  TransFlag <= 1'b1;					// ��CPLDָ��,mcu read cpld command by spi
					  SPIData <= idata2;
					  CmdFlag		<= CmdFlag;				// ������,��MCU��������
				   end
// д,MCU write CPLD
				   ID_CMD:begin
					  TransFlag <= 1'b0;					
				  	  CmdFlag	<= 1'b1;					
				   end
				   CODER2CMD:begin
				      TransFlag <= 1'b0;					// дCPLDָ��,mcu write cpld command by spi
				  	  CmdFlag	<= 1'b1;					// д����״̬
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
					  TransFlag <= 1'b0;					// Ĭ��д״̬
				  	  CmdFlag   <= 1'b1;					// д����״̬
				  end
				endcase
			end		// ����ָ�����,CmdFlag
			else	// SPIд����,CPLD���ڶ�������
			begin
			  	CmdFlag		<= 1'b0;							// ��Ϊдָ��״̬ 
			  	case(CmdStore)									// SPICoder old value
				  		ID_CMD:begin
				            odata0 <= SPICoder;
				        end
						CODER2CMD:begin
							odata1 <= SPICoder;					// д����
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
		end	// ������ձ�־��� 
	end		// �ܵ�SPIָ������
	else if(TransEndFlag)	// ���ͽ���
	begin
		TransFlag <= 1'b0;
	end
	else	// �������ݻ�����¸�����״̬
	begin
		 RFstRunFlag <= 1'b0;
		 TransFlag <= TransFlag;
	end
end

endmodule 
