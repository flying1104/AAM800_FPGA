----------------------------------------------------------------------------------
-- www.Beis.de
-- Uwe Beis
--
-- Create Date:		2006-04-01
-- Project Name:	DigitalLevelMeter
-- Design Name:		DigitalLevelMeter
-- Module Name:		Bin2Decibel - Behavioral 
-- Description:		Converts a binary value to its logarithmic value as dB
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Bin2Decibel is
	port
	(	MClk		: in  std_logic;
		LevelBinIn	: in  std_logic_vector(22 downto 0);
		DecibelBCD	: out  std_logic_vector(15 downto 0);
		DecibelBin	: out  std_logic_vector(10 downto 0)
	);
end Bin2Decibel;

architecture Behavioral of Bin2Decibel is
--	23 bit correspond to a dynamic range of 2^23 = 138.5dB max.,
--	i. e., <= 1385 counts with 0.1 db each (11 bit)
signal En4ClkCnt 		: std_logic_vector(1 downto 0);
signal BinaryCount		: std_logic_vector(10 downto 0); 
signal BCDCount_E		: std_logic_vector(3 downto 0);
signal BCDCount_Z		: std_logic_vector(3 downto 0);
signal BCDCount_H		: std_logic_vector(3 downto 0);
signal BCDCount_T		: std_logic_vector(3 downto 0);
signal LogDecrementer	: std_logic_vector(31 downto 0);
signal MulAIn			: std_logic_vector(17 downto 0);
signal ReducedLevel		: std_logic_vector(49 downto 0);
signal ResultFlag		: std_logic;

--	The LogDecrementer is decreased 0.1dB each count. -0.1dB is 0.988553094657.
--	As multiplicand for an 18 bit multiplier 1 corresponds to 2^18 and
--	(2^18)*0,9885530946567 = 259143.26
--
--	Rounding: Levels from 0 to >-0.1dB are converted to 0dB.
--
--	With a 32 x 18 multiplier the converter shows an error of 
--	+0.7dB at level 1 (-137.7dB instead of -138.47dB),
--	+0.5dB at level 2 (-132.0dB instead of -132.45db),
--	<0.1dB at level 16 (-114.3dB instead of -114.39db)

component Mult32x18
	port
	(	clock		: in std_logic;
		dataa		: in std_logic_vector (31 downto 0);
		datab		: in std_logic_vector (17 downto 0);
		result		: out std_logic_vector (49 downto 0)
	);
end component;

begin
	
	Multiplier : MULT32X18
	port map
	(	clock	=> MClk,
		dataa	=> LogDecrementer,
		datab	=> conv_std_logic_vector(259143, 18),
		result	=> ReducedLevel
	);
	
	EnAll4Clks : process (MClk)
	-- As the multipliers are clocked with a latency of 2,
	-- the Convert process can not run each MClk
	begin
		if MClk = '1' and MClk'event then
			En4ClkCnt <= En4ClkCnt + 1;
		end if;
	end process EnAll4Clks;

	Convert : process (MClk)
	-- --------- Example: BinaryIn: -.05 dB (to be displayed: 0 dB)
	-- BinaryCount      0     -1     -2
	-- BCDCount      2047      0      1
	-- LogDecrementer   ?    -.1dB  -.2dB
	-- Compare          -   true   true
	-- ResultFlag       ?      0      1
	-- DecibelBCD       ?      ?      0
	-- DecibelBin       ?      ?      1

	-- --------- Example: BinaryIn: -.35 dB (to be displayed: -0.3 dB)
	-- BinaryCount      0     -1     -2     -3     -4     -5
	-- BCDCount      2047      0      1      2      3      4
	-- LogDecrementer   ?    -.1dB  -.2dB  -.3dB  -.4dB  -.5dB
	-- Compare          -  false  false  false   true   true
	-- ResultFlag       ?      0      0      0      0      1      
	-- DecibelBCD       ?      ?      ?      ?      ?      3
	-- DecibelBin       ?      ?      ?      ?      ?      4
	begin
		if MClk = '1' and MClk'event then
			if En4ClkCnt = "11" then
				BinaryCount <= BinaryCount - 1;				
				if BinaryCount = 0 then
					LogDecrementer <= conv_std_logic_vector(259143, 18) & conv_std_logic_vector(2**(LogDecrementer'length - 18), (LogDecrementer'length - 18));
					ResultFlag <= '0';
					BCDCount_E <= "0000";
					BCDCount_Z <= "0000";
					BCDCount_H <= "0000";
					BCDCount_T <= "0000";
					if ResultFlag = '0' then
						DecibelBCD <= (others => '1');  -- indicates input level is zero
						DecibelBin <= (others => '1');
					end if;
				else
					if (LogDecrementer(LogDecrementer'left downto LogDecrementer'left - LevelBinIn'length + 1) < LevelBinIn) and (ResultFlag = '0') then
						DecibelBCD <= BCDCount_T & BCDCount_H & BCDCount_Z & BCDCount_E;
						DecibelBin <= (not BinaryCount);
						ResultFlag <= '1';
					end if;
					LogDecrementer <= ReducedLevel(ReducedLevel'left downto ReducedLevel'left - LogDecrementer'length + 1);
					-- 1st Digit
					if BCDCount_E = 9 then
						BCDCount_E <= "0000";
					else
						BCDCount_E <= BCDCount_E + 1;
					end if;
					-- 2nd Digit
					if BCDCount_E = 9 then
						if BCDCount_Z = 9 then
							BCDCount_Z <= "0000";
						else
							BCDCount_Z <= BCDCount_Z + 1;
						end if;
						-- 3rd Digit
						if BCDCount_Z = 9 then
							if BCDCount_H = 9 then
								BCDCount_H <= "0000";
							else
								BCDCount_H <= BCDCount_H + 1;
							end if;
							-- 4th Digit
							if BCDCount_H = 9 then
								if BCDCount_T = 9 then
									BCDCount_T <= "0000";
								else
									BCDCount_T <= BCDCount_T + 1;
								end if;
							end if;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process Convert;
	
end Behavioral;

