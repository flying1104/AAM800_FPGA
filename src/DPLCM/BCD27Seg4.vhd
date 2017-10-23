----------------------------------------------------------------------------------
-- www.Beis.de
-- Uwe Beis
--
-- Create Date:		2006-04-01
-- Project Name:	DigitalLevelMeter
-- Design Name:		DigitalLevelMeter
-- Module Name:		BCD27Segment4 - Behavioral 
-- Description:		Converts 4 4-binary values to seven segment
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity BCD27Seg4 is
	port
	(	BCDIn		: in  std_logic_vector(15 downto 0);
		DecPointIn	: in  std_logic_vector(4 downto 1);
		SegmentOut	: out  std_logic_vector(32 downto 1)
	);
end BCD27Seg4;

architecture Behavioral of BCD27Seg4 is

component BCD27Seg is
	port
	(	BCDIn		: in  std_logic_vector(3 downto 0);
		SegmentOut	: out  std_logic_vector(7 downto 1)
	);
end component BCD27Seg;

begin

	SegmentOut(32)  <= DecPointIn(4);
	Digit1000 : BCD27Seg
	port map
	(	BCDIn		=> BCDIn(15 downto 12),
		SegmentOut	=> SegmentOut(31 downto 25)
	);

	SegmentOut(24)  <= DecPointIn(3);
	Digit100 : BCD27Seg
	port map
	(	BCDIn		=> BCDIn(11 downto 8),
		SegmentOut	=> SegmentOut(23 downto 17)
	);

	SegmentOut(16)  <= DecPointIn(2);
	Digit10 : BCD27Seg
	port map
	(	BCDIn		=> BCDIn(7 downto 4),
		SegmentOut	=> SegmentOut(15 downto 9)
	);

	SegmentOut(8)  <= DecPointIn(1);
	Digit1 : BCD27Seg
	port map
	(	BCDIn		=> BCDIn(3 downto 0),
		SegmentOut	=> SegmentOut(7 downto 1)
	);

end Behavioral;

