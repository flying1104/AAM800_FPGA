----------------------------------------------------------------------------------
-- www.Beis.de
-- Uwe Beis
--
-- Create Date:		2006-04-16
-- Project Name:	DigitalLevelMeter
-- Design Name:		DigitalLevelMeter
-- Module Name:		Correlation - Behavioral 
-- Description:		Calculates Correlation of 2 9-bit audio signals
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity CorrelationMeter is
	port
	(	MClk		: in  std_logic;
		Clk1usEn	: in  std_logic;
		AudioInL	: in  std_logic_vector(8 downto 0);
		AudioInR	: in  std_logic_vector(8 downto 0);
		Correlation	: out  std_logic_vector(7 downto 0);
		LowLevel	: out  std_logic;
		TestSel		: in  std_logic_vector(2 downto 0);
		TestVector	: out  std_logic_vector(7 downto 0)
	);
end CorrelationMeter;

architecture Behavioral of CorrelationMeter is

--             +-->[     ]   16U   [     ]         
--         9S  |   [ Sqr ]--/----->[ LPF ]------+
-- Left --/----+-->[     ]         [     ]      |  
--             |                                |
--             |                                |
--             |                                |
--             +-->[     ]   16S   [     ]      |   24S  [     ]        [     ]        24S
--                 [ Mul ]--/----->[ LPF ]---------/---->[ Dly ]------->[ Dly ]-------/----->[       ]   
--             +-->[     ]         [     ]      |        [     ]        [     ]        16U   [  Div  ]--+
--             |                                |                                  +--/----->[       ]  |
--             |                                |   16U                            |                    |
--         9S  |                                +--/---->[     ]   32U  [       ]  |                    |
-- Right--/----+-->[     ]   16U   [     ]      |   16U  [ Mul ]--/---->[ SqrRt ]--+                    |
--             |   [ Sqr ]--/----->[ LPF ]--+------/---->[     ]        [       ]                       |
--             +-->[     ]         [     ]  |   |                                                       |
--                                          |   |                                         Correlation   |
--                                          |   |          +--------------------------------------------+
--                                          |   |          |
--                                          |   |          |
--                                          |   |          |
--                                          |   |          |   8S     [ Satu ]   8S   
--                                          |   |          +--/------>[ rate ]--/---+---------------->[0  \
--                                          |   |                     [      ]      |                 [    \    8S   [ To Un- ]   8U 
--                                          |   |                                   |                 [ Mux }--/---->[ signed ]--/----> Correlation
--                                          |   |                                   +->[     ]   8S   [    /         [        ]      
--                                          |   |                     [      ]   8U    [ Mul ]--/---->[1  /               
--                                          |   |                 +-->[ Mod  ]--/----->[     ]          ^               
--                                          |   |                 |   [ 4096 ]                          |
--                                          |   |                 |                                     |
--                                          |   +->[     ]   20U  |   [        ]                        |
--                                          |      [ Min ]--/-----+-->[ <-33dB ]------------------------+-----------------------------> LowLevel
--                                          +----->[     ]            [        ]
--
-- Except Saturate, Mod 4096 and To Unsigned: Each block clocked with MClk and clock-enabled with Clk1usEn 

signal AudioLimitL	: std_logic_vector(8 downto 0);
signal AudioLimitR	: std_logic_vector(8 downto 0);
signal AudioLxR		: std_logic_vector(17 downto 0);
signal AudioLxL		: std_logic_vector(17 downto 0);
signal AudioRxR		: std_logic_vector(17 downto 0);
signal LowPassLxR	: std_logic_vector(34 downto 0)	:= "10000000000000000000000000000000000";
signal LowPassLxL	: std_logic_vector(33 downto 0);
signal LowPassRxR	: std_logic_vector(33 downto 0);
signal LevelLxLxRxR	: std_logic_vector(31 downto 0);
signal SqrRtLxLxRxR	: std_logic_vector(15 downto 0);
signal DivClkEn		: std_logic;
signal LowPassDly1	: std_logic_vector(23 downto 0);
signal LowPassDly2	: std_logic_vector(23 downto 0);
signal CorrQuotient	: std_logic_vector(23 downto 0);
signal CorrSaturate	: std_logic_vector(7 downto 0);
signal MinLxLRxR	: std_logic_vector(19 downto 0);
signal FadeFactor	: std_logic_vector(8 downto 0);
signal CorrMult		: std_logic_vector(17 downto 0);
signal FadeSelect	: std_logic;
signal CorrFaded	: std_logic_vector(7 downto 0);
signal CorrUnsigned	: std_logic_vector(7 downto 0);

component Mult9Sx9SClkEn is
	port
	(	clken		: in std_logic;
		clock		: in std_logic;
		dataa		: in std_logic_vector (8 downto 0);
		datab		: in std_logic_vector (8 downto 0);
		result		: out std_logic_vector (17 downto 0)
	);
end component;

component Mult16Ux16UClkEn is
	port
	(	clken		: in std_logic;
		clock		: in std_logic;
		dataa		: in std_logic_vector (15 downto 0);
		datab		: in std_logic_vector (15 downto 0);
		result		: out std_logic_vector (31 downto 0)
	);
end component;

component SqrRt32ClkEn is
	port
	(	clk			: in std_logic;
		ena			: in std_logic;
		radical		: in std_logic_vector (31 downto 0);
		q			: out std_logic_vector (15 downto 0);
		remainder	: out std_logic_vector (16 downto 0)
	);
end component;

component Div24Sby16UClkEn is
	port
	(	clken		: in std_logic;
		clock		: in std_logic;
		denom		: in std_logic_vector (15 downto 0);
		numer		: in std_logic_vector (23 downto 0);
		quotient	: out std_logic_vector (23 downto 0);
		remain		: out std_logic_vector (15 downto 0)
	);
end component;

begin

	-- Limit Audio to -255
	AudioLimitL <= "100000001" when AudioInL = "100000000" else AudioInL;
	AudioLimitR <= "100000001" when AudioInR = "100000000" else AudioInR;
	
	-- 9 bit signed x 9 bit signed multiplier output:
	-- Output is 17 bit wide valid (bit 17 = bit 16)
	-- +255 * +255 = +57039 ---> 0FF x 0FF = 00 FE01
	-- -255 * -255 = +57039 ---> 101 x 101 = 00 FE01
	-- +255 * -255 = -57039 ---> 101 x 101 = 11 01FF
	MultiplyAudioLxR : Mult9Sx9SClkEn
	port map
	(	clken	=> Clk1usEn,
		clock	=> MClk,
		dataa	=> AudioLimitL,
		datab	=> AudioLimitR,
		result	=> AudioLxR
	);

	-- 9 bit signed square output:
	-- Output is 16 bit wide valid (bit 17 = bit 16 = 0)
	-- +255 * +255 = +57039 ---> 0FF x 0FF = 00 FE01
	-- -255 * -255 = +57039 ---> 101 x 101 = 00 FE01
	SquareAudioL : Mult9Sx9SClkEn
	port map
	(	clken	=> Clk1usEn,
		clock	=> MClk,
		dataa	=> AudioLimitL,
		datab	=> AudioLimitL,
		result	=> AudioLxL
	);

	SquareAudioR : Mult9Sx9SClkEn
	port map
	(	clken	=> Clk1usEn,
		clock	=> MClk,
		dataa	=> AudioLimitR,
		datab	=> AudioLimitR,
		result	=> AudioRxR
	);

	LRLowPass : process (MClk)
	-- Time constant 0.5 s approx.
	begin
		if MClk = '1' and MClk'event then
			if Clk1usEn = '1' then
				LowPassLxR <= LowPassLxR - ("000000000000000000" & LowPassLxR(34 downto  34 - 16)) + ("000000000000000000" & (not AudioLxR(16)) & (AudioLxR(15 downto 0)));
				LowPassLxL <= LowPassLxL - ("000000000000000000" & LowPassLxL(33 downto  33 - 15)) + ("000000000000000000" & AudioLxL(15 downto 0));
				LowPassRxR <= LowPassRxR - ("000000000000000000" & LowPassRxR(33 downto  33 - 15)) + ("000000000000000000" & AudioRxR(15 downto 0));
			end if;
		end if;
	end process LRLowPass;

	MultiplierLxLxRxR : Mult16Ux16UClkEn
	port map
	(	clken	=> Clk1usEn,
		clock	=> MClk,
		dataa	=> LowPassLxL(33 downto 33 - 15),
		datab	=> LowPassRxR(33 downto 33 - 15),
		result	=> LevelLxLxRxR
	);

	SquareRootLxLxRxR : SqrRt32ClkEn
	port map
	(	clk			=> MClk,
		ena			=> Clk1usEn,
		radical		=> LevelLxLxRxR,
		q			=> SqrRtLxLxRxR,
		remainder	=> open
	);

	LowPassDelay : process (MClk)
	begin
		if MClk = '1' and MClk'event then
			if Clk1usEn = '1' then
				LowPassDly1 <= LowPassLxR(34 downto  34 - 23); -- Delay 2 cocks
				LowPassDly2 <= LowPassDly1;
			end if;
		end if;
	end process LowPassDelay;

--	DivClkEn <= '1' when ((SqrRtLxLxRxR > 0) or (TestSel(0) = '1')) and (Clk1usEn = '1') else '0';

	Divider : Div24Sby16UClkEn
	port map
	(	clken		=> Clk1usEn, -- DivClkEn,
		clock		=> MClk,
		denom		=> SqrRtLxLxRxR,
		numer		=> (not LowPassDly2(23)) & LowPassDly2(22 downto 0), -- convert to signed
		quotient	=> CorrQuotient,
		remain		=> open
	);
	
	-- After division pos. values of 80 (or even more?) may appear and must be limited,
	-- as the 8-bit output allows pos. values of 7F max..
	-- Saturation to 7F if positive or 80 resp. if negative.
	CorrSaturate <= CorrQuotient(7 downto 0) when CorrQuotient(7) = CorrQuotient(8) else 
	                "10000000" when CorrQuotient(8) = '1' else
					"01111111";

	-- Fading the correlation downto 0 starts when one input becomes < -36 dB (-33 dB approx. displayed as peak level),
	-- i.e., LowPassXxX output 12 MSBits = 0, i.e., MinLxLRxR(33 downto 22) = 0.
	MinLxLRxR <= LowPassRxR(33 downto 14) when LowPassRxR(33 downto 14) < LowPassLxL(33 downto 14) else LowPassLxL(33 downto 14);
	FadeFactor <= MinLxLRxR(8 downto 0); -- When fade active: FadeFactor(8) = 0, i.e., positiv when used as signed signal

	CorrelationFader : Mult9Sx9SClkEn
	port map
	(	clken	=> Clk1usEn,
		clock	=> MClk,
		dataa	=> CorrSaturate & '0', -- dataa is 9, but CorrSaturate is only 8 bit wide
		datab	=> FadeFactor, -- FadeFactor(8) = 0
		result	=> CorrMult
	);

	FadeSelectAndMux : Process (MClk)
	begin
		if MClk = '1' and MClk'event then
			if Clk1usEn = '1' then
				if MinLxLRxR < "00000000000100000000" then -- corresponds to SQR(-36dB) approx.
					FadeSelect <= '1';
				else
					FadeSelect <= '0';
				end if;
				-- FadeSelect 1 clock delayed, Mux out registered
				if FadeSelect = '1' then
					CorrFaded <= CorrMult(16 downto 9);
				else
					CorrFaded <= CorrSaturate; -- 2nd MSBit = MSBit = sign
				end if;
			end if;
		end if;
	end process FadeSelectAndMux;

	-- CorrQuotient, CorrSaturate and CorrFaded are signed, i.e., max. negative = 80, max. possitive = 7F, zero = 0
	-- Correlation is displayed unsigned, i.e., Correlation is: max. negative = 0, max. positive = FF, zero = 80
	CorrUnsigned <= CorrFaded + "10000000";
	
	LowLevel <= FadeSelect;
	Correlation <= CorrUnsigned;
	
	-- Test output to view 8 MSBit of internal signals using an R2R-DAC
	with TestSel select
	TestVector <=	AudioInL(8 downto 8 - 7) + "10000000"	when "000", -- 0
					AudioLxL(15 downto 15 - 7) 				when "001", -- 1
					LowPassLxL(33 downto 33 - 7)			when "010", -- 2
					MinLxLRxR(17 downto 17 - 7)				when "011", -- 3
					FadeFactor(8 downto 1)					when "100",	-- 4
					CorrMult(16 downto 9) + "10000000"		when "101", -- 5
					CorrFaded + "10000000"					when "110", -- 6
--					LevelLxLxRxR(31 downto 31 - 7)			when "011",	-- 3
--					SqrRtLxLxRxR(15 downto 15 - 7)			when "100", -- 4
--					AudioLxR(16 downto 16 - 7) + "10000000"	when "101", -- 5
--					LowPassDly2(23 downto 23 - 7)			when "110", -- 6
--					SqrRtLxLxRxR(15 downto 15 - 7)		when others; -- 7
					CorrUnsigned							when others; -- 7
	
end Behavioral;

