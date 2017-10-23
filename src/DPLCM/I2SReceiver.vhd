-----------------------------------------------------------------------
-- Filename				:	I2S_Receiver.vhl
-- Author				:	Wisely
-- Description			:	
-- Revision	History	:	2017-05-22
--  							V1.0
-- Company				:
-- Email					:
-- Copyright(c) ,DreamFly Technology Inc,All right reserved
------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity I2SReceiver is
	generic
	(
		MClkFreq : integer := 108;
		Verision : bit_vector := x"0003"
	);
	port
	(
		MClk		: 	in std_logic;
		Sclk		:	in std_logic;
		Lrck		:  in std_logic;
		SclkCnt	:	in std_logic_vector(5 downto 0);
		Data		:	in std_logic;
		LQ			:	out std_logic_vector(23 downto 0);
		RQ			:	out std_logic_vector(23 downto 0);
		Q			:	out std_logic_vector(23 downto 0);
		AudioDataEn : out std_logic
	);
end I2SReceiver;

architecture Behavioral of I2sReceiver is
signal LqTmp	:	std_logic_vector(23 downto 0);
signal RqTmp	:	std_logic_vector(23 downto 0);
signal LrckShift : std_logic_vector(2 downto 1);
begin

	I2SData	:	process (Sclk)
	begin
		if Sclk = '1' and Sclk'event then
			if (SclkCnt >= 0) and (SclkCnt <= 23) then
				LqTmp <= LqTmp(22 downto 0) & Data;
				RqTmp <= "000000000000000000000000";
			else 
				if (SclkCnt >= 32) and (SclkCnt <= 55) then
					LqTmp <= "000000000000000000000000";
					RqTmp <= RqTmp(22 downto 0) & Data;
				end if;
			end if;
			
			if (SclkCnt = 25) then 
				LQ <= LqTmp; 
				Q  <= LqTmp;
			end if;
			if (SclkCnt = 57) then 
				RQ <= RqTmp; 
				Q	<= RqTmp;
			end if;
									
		end if;		
	end process I2SData;
	
	AudioDataEnOut : process	(MClk)
	begin
		if MClk = '1' and MClk'event then
			LrckShift <= LrckShift(1) & Lrck;
		end if;
		
		if(LrckShift = "10") then
			AudioDataEn <= '1';
		else
			AudioDataEn <= '0';
		end if;
	end process AudioDataEnOut;
	
end Behavioral;




