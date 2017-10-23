----------------------------------------------------------------------------------
-- www.Beis.de
-- Uwe Beis
--
-- Create Date:		2006-04-01
-- Project Name:	DigitalLevelMeter
-- Design Name:		DigitalLevelMeter
-- Module Name:		FrequCount5 - Behavioral 
-- Description:		5 digit Frequency counter for 4 digit sample rate display
--             		Output 4 digits, 100 Hz resolution
--                  Counted frequency rounded by 50 Hz to avoid display jitter
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity FrequencyCounter is
	generic
	(	MClkFreq	: integer := 50 -- Master Clock in MHz
	);
	port
	(	MClk		: in std_logic;
		FrequCntIn	: in std_logic;	-- Must be only one MClk high
		FrequOut	: out std_logic_vector(15 downto 0);
		Clk100msOut	: out std_logic
	);
end FrequencyCounter;

architecture Behavioral of FrequencyCounter is
signal TCnt100ms	: std_logic_vector(23 downto 0);
signal BCDCount_P	: std_logic_vector(3 downto 0); -- Pre divider (10 Hz)
signal BCDCount_E	: std_logic_vector(3 downto 0); -- 100 Hz
signal BCDCount_Z	: std_logic_vector(3 downto 0); -- 1 kHz
signal BCDCount_H	: std_logic_vector(3 downto 0); -- 10 kHz
signal BCDCount_T	: std_logic_vector(3 downto 0); -- 100 kHz

begin
	Timer100ms : process (MClk)
	begin
		if MClk = '1' and MClk'event then
			if TCnt100ms = 100000 * MClkFreq - 1 then
				TCnt100ms <= (others => '0');
			else
				TCnt100ms <= TCnt100ms + 1;
			end if;
		end if;
	end process;
	Clk100msOut <= '1' when TCnt100ms = 100000 * MClkFreq - 1 else '0';
	CountFrequency : process (MClk)
	begin
		if MClk = '1' and MClk'event then
			if TCnt100ms = 100000 * MClkFreq - 1 then
				FrequOut <= BCDCount_T & BCDCount_H & BCDCount_Z & BCDCount_E;
				BCDCount_P <= "0101"; -- Rounding
				BCDCount_E <= "0000";
				BCDCount_Z <= "0000";
				BCDCount_H <= "0000";
				BCDCount_T <= "0000";
			else
				if FrequCntIn = '1' then
					-- Predivider
					if BCDCount_P = 9 then
						BCDCount_P <= "0000";
					else
						BCDCount_P <= BCDCount_P + 1;
					end if;
					-- 1st Digit
					if BCDCount_P = 9 then
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
		end if;
	end process;

end Behavioral;
