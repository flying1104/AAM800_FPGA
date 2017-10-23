----------------------------------------------------------------------------------
-- www.Beis.de
-- Uwe Beis
--
-- Create Date:		2006-04-01
-- Project Name:	DigitalLevelMeter
-- Design Name:		DigitalLevelMeter
-- Module Name:		PeakHold - Behavioral 
-- Description:		Holds the peak signal level
--             		Hold time is 0, 0.5s, 1s, 1.5s, 2s, 2.5s, 3s, 3.5s or infinite
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity PeakHold is
	generic
	(	MClkFreq	: integer := 50 -- Master Clock in MHz
	);
	port
	(	MClk		: in std_logic;
		Clk1msEn	: in std_logic;
		DecibelBin	: in std_logic_vector(10 downto 0);
		DecibelBCD	: in std_logic_vector(15 downto 0);
		Clip		: in std_logic;
		HoldTime	: in std_logic_vector(2 downto 0);
		HoldRelease	: in std_logic;
		HoldBin		: out std_logic_vector(10 downto 0);
		HoldBCD		: out std_logic_vector(15 downto 0);
		HoldClip	: out std_logic
	);
end PeakHold;

architecture Behavioral of PeakHold is
   
signal Timer500ms	: std_logic_vector(8 downto 0); -- 500 x 1 ms
signal HoldTimer	: std_logic_vector(2 downto 0); -- 7 x 500 ms max.
signal iHoldBin		: std_logic_vector(10 downto 0); -- 2048 steps, 0.1 db each
signal iHoldClip	: std_logic;

begin
	PeakHold : process (MClk)
	begin
		if MClk = '1' and MClk'event then
			if Clk1msEn = '1' then
				if (not HoldTime) = 0 then --> if HoldTime = -1 --> if HoldTime = 7
					HoldTimer <= (others => '0');
					Timer500ms <= (others => '0');					
				else
					if Timer500ms = 499 then
						Timer500ms <= (others => '0');
						HoldTimer <= HoldTimer + 1;
					else
						Timer500ms <= Timer500ms + 1;
					end if;
				end if;
				if ((iHoldBin >= DecibelBin) and iHoldClip = '0') or Clip = '1' or (HoldTime = 0) or (HoldRelease = '1') or (((HoldTime) < 7) and (Timer500ms = 499) and (HoldTimer = HoldTime - 1) and (Clk1msEn = '1' )) then
					iHoldBin <= DecibelBin;
					HoldBCD <= DecibelBCD;
					iHoldClip <= Clip;
					HoldTimer <= (others => '0');
					Timer500ms <= (others => '0');
				end if;
			end if;
		end if;
	end process PeakHold;

	HoldBin <= iHoldBin;
	HoldClip <= iHoldClip;

end  Behavioral;