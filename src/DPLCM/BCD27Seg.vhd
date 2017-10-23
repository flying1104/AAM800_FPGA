----------------------------------------------------------------------------------
-- www.Beis.de
-- Uwe Beis
--
-- Create Date:		2006-04-01
-- Project Name:	DigitalLevelMeter
-- Design Name:		DigitalLevelMeter
-- Module Name:		BCD27Segment - Behavioral 
-- Description:		Converts one 4-binary value to seven segment
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity BCD27Seg is
	port
	(	BCDIn		: in  std_logic_vector(3 downto 0);
		SegmentOut	: out  std_logic_vector(7 downto 1)
	);
end BCD27Seg;

architecture Behavioral of BCD27Seg is
begin
	with BCDIn select
	--				 gfedcba
	SegmentOut <=	"0111111" when "0000",
					"0000110" when "0001",
					"1011011" when "0010",
					"1001111" when "0011",
					"1100110" when "0100",
					"1101101" when "0101",
					"1111101" when "0110",
					"0000111" when "0111",
					"1111111" when "1000",
					"1101111" when "1001",
					"0111001" when "1010", -- "C"
					"0111000" when "1011", -- "L"
					"1110011" when "1100", -- "P"
					"1000110" when "1101", -- "-1"
					"1000000" when "1110", -- "-"
					"0000000" when others; -- blank
end Behavioral;

