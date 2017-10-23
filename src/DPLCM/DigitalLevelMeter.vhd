----------------------------------------------------------------------------------
-- www.Beis.de
-- Uwe Beis
--
-- Create Date:		2006-04-01
-- Project Name:	DigitalLevelMeter
-- Design Name:		DigitalLevelMeter
-- Module Name:		DigitalLevelMeter - Behavioral 
-- Target Devices:	EP2C5 (Development Board: EP2C35)
-- Description:		Audio Level Meter with S/PDIF inputs and
--             		and LED bar output, decimal display,
--             		peak hold and sample rate display
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity DigitalLevelMeter is
	generic
	(	MClkFreq	: integer := 108;	 -- Master Clock in MHz
		Version		: bit_vector := x"0003"
	);
	port
	(	Lrck			: in std_logic;
		Sclk			: in std_logic;
		SclkCnt		: in std_logic_vector(5 downto 0);
		Data			: in std_logic;
		OscClk		: in std_logic;
		SPDIFInput1	: in std_logic;
		SPDIFInput2	: in std_logic;
		HoldTime	: in std_logic_vector(2 downto 0);
		HoldRelease	: in std_logic;
		SPDIFInSel	: in std_logic;
		SPDIFOutput	: out std_logic;
		LEDGroup	: out std_logic_vector(6 downto 1);
		LEDSegment	: out std_logic_vector(32 downto 1);
		-- Test I/O:
		-- Pushbuttons on the development board
		Key1		: in std_logic; -- Force audio to zero ) Both keys together:
		Key2		: in std_logic; -- Force audio to clip ) Force audio to -6dB
		-- LEDs on the development board
		Test1		: out std_logic;
		Test2		: out std_logic;
		Test3		: out std_logic;
		Test4		: out std_logic;
		Test5		: out std_logic;
		Test6		: out std_logic;
		Test7		: out std_logic;
		Test8		: out std_logic;
		TestVector1	: out std_logic_vector(7 downto 0);
		TestVector2	: out std_logic_vector(7 downto 0)
	);
end DigitalLevelMeter;

architecture Behavioral of DigitalLevelMeter is
-- Timing
signal MClk			: std_logic;
signal Timer1usCnt	: std_logic_vector(6 downto 0); -- Max. 127 MHz -> 1 MHz
signal Clk1uSEn		: std_logic;
signal Timer1msCnt	: std_logic_vector(9 downto 0); -- 1 ms from 1 us -> 10 bit
signal Clk1msEn		: std_logic;
signal Timer2sCnt	: std_logic_vector(10 downto 0); -- 1 ms from 1 us -> 10 bit
signal Startup		: std_logic;
-- S/PDIF
signal SPDIFInput	: std_logic; -- S/PDIF from input selector
signal AudioData0	: std_logic_vector(23 downto 0); -- Audio data 24 bit, signed binary
signal AudioData1	: std_logic_vector(23 downto 0);
signal iAudioData0	: std_logic_vector(23 downto 0); -- dto., but modified by test keys
signal iAudioData1	: std_logic_vector(23 downto 0);
signal SPDIFLock	: std_logic;                     -- S/PDIF input signal is stable
signal AudioDataEn	: std_logic;                     -- One puls each sample for sample rate display
signal ChIndex		: std_logic;                     -- Left / right index
-- Signals from peak level meter
signal AudioLevelL	: std_logic_vector(22 downto 0); -- Audio level, 23 bit, unsigned binary
signal AudioLevelR	: std_logic_vector(22 downto 0);
signal DecibelBCDL	: std_logic_vector(15 downto 0); -- 4 digits representing the dB level
signal DecibelBCDR	: std_logic_vector(15 downto 0);
signal ClipL		: std_logic;                     -- Value is conjecturally clipped (0x7FFFFF or 0x800000)
signal ClipR		: std_logic;
-- Current audio level converted to dB for LED bar display
signal DecibelBinL	: std_logic_vector(10 downto 0); -- 2048 steps, 0.1 db each
signal DecibelBinR	: std_logic_vector(10 downto 0);
-- Audio level from peak hold circuit
signal HoldBinL		: std_logic_vector(10 downto 0); -- Hold level, 11 bit, unsigned binary
signal HoldBinR		: std_logic_vector(10 downto 0); -- (2048 steps, 0.1 db each)
signal HoldBCDL		: std_logic_vector(15 downto 0); -- Hold level, 16 bit, BCD
signal HoldBCDR		: std_logic_vector(15 downto 0);
signal HoldClipL	: std_logic;                     -- Clipping indicator (0x7FFFFF or 0x800000)
signal HoldClipR	: std_logic;
-- Sample rate frequency counter
signal FrequOut		: std_logic_vector(15 downto 0);
-- Signals from correlation meter
signal Correlation	: std_logic_vector(7 downto 0);  -- Unsigned, i.e., 0x80 = zero, 0xFF = 1, 0x00 = -1
signal LowLevel		: std_logic;
-- Signals used for 7 segment and bar display
signal BCDCodeL		: std_logic_vector(15 downto 0); -- 4 digits representing the dB level
signal BCDCodeR		: std_logic_vector(15 downto 0);
signal BCDCodeF		: std_logic_vector(15 downto 0); -- 4 digits sample rate
signal DecPointsL	: std_logic_vector(4 downto 1);  -- 4 possible decimal points
signal DecPointsR	: std_logic_vector(4 downto 1);
signal DecPointsF	: std_logic_vector(4 downto 1);  -- 4 possible decimal points sample rate 
signal LEDSegmentL	: std_logic_vector(32 downto 1); -- 32 LED cathodes / segments
signal LEDSegmentR	: std_logic_vector(32 downto 1);
signal LEDSegmentF	: std_logic_vector(32 downto 1); -- Sample rate 32 LED cathodes / segments
signal LEDBarL		: std_logic_vector(32 downto 1); -- 32 LED cathodes
signal LEDBarR		: std_logic_vector(32 downto 1);
signal LEDBarC		: std_logic_vector(32 downto 1); -- Correlation
signal LEDBarTest	: std_logic_vector(32 downto 1); -- Testing each other ("0101010.....")
signal LEDSegTest	: std_logic_vector(32 downto 1); -- Testing all vertical and all horizontal
-- Internal signals for LED multiplexer
signal LEDMuxChange	: std_logic;                     -- Pause for desaturation of anode drivers 
signal LEDMuxCnt	: std_logic_vector(2 downto 0);  -- Divider 6 display common anode groups
-- Internal signals for Test keys
signal KeyLeft		: std_logic_vector(2 downto 1);
signal KeyRight		: std_logic_vector(2 downto 1);

component pll27to108_ip is
	port
	(	inclk0		: in std_logic	:= '0';
		c0			: out std_logic;
		locked		: out std_logic 
	);
end component pll27to108_ip;

component I2SReceiver is
	port
	(
		MClk		:  in std_logic;
		Sclk		:	in std_logic;
		Lrck		:  in std_logic;
		SclkCnt	:	in std_logic_vector(5 downto 0);
		Data		:	in std_logic;
		LQ			:	out std_logic_vector(23 downto 0);
		RQ			:	out std_logic_vector(23 downto 0);
		Q			:	out std_logic_vector(23 downto 0);
		AudioDataEn : out std_logic
	);
end component I2SReceiver;
	
component SPDIFReceiver is
	port
	(	MClk		: in std_logic;
		SPDIFInput	: in std_logic;
		AudioData0	: out std_logic_vector(23 downto 0);
		AudioData1	: out std_logic_vector(23 downto 0);
		SPDIFLock	: out std_logic; 	-- open
		Validity	: out std_logic; 		-- open
		UserData	: out std_logic; 		-- open
		ChStatus	: out std_logic; 		-- open
		Parity		: out std_logic; 	-- open
		AudioDataEn	: out std_logic; 	-- to sampleRateDisplay
		BlockStart	: out std_logic; 	-- open
		ChIndex		: out std_logic; 	-- to PeakLevelMeter
		FrameStart	: out std_logic; 	-- open
		-- Test
		SPDIFInShft	: out std_logic;
		SampleEn	: out std_logic;
		TestVector1	: out  std_logic_vector(7 downto 0);
		TestVector2	: out  std_logic_vector(7 downto 0)
	);
end component SPDIFReceiver;

component PeakLevelMeter is
	generic
	(	MClkFreq	: integer  -- Master Clock in MHz
	);
	port
	(	MClk		: in std_logic;
		Clk1msEn	: in std_logic;
		AudioDataL	: in std_logic_vector(23 downto 0);
		AudioDataR	: in std_logic_vector(23 downto 0);
		ChIndex		: in std_logic;
		AudioLevelL	: out std_logic_vector(22 downto 0);
		AudioLevelR	: out std_logic_vector(22 downto 0);
		ClipL		: out std_logic;
		ClipR		: out std_logic
	);
end component PeakLevelMeter;

component Bin2Decibel is
	port
	(	MClk		: in std_logic;
		LevelBinIn	: in std_logic_vector(22 downto 0);
		DecibelBCD	: out std_logic_vector(15 downto 0);
		DecibelBin	: out std_logic_vector(10 downto 0)
	);
end component Bin2Decibel;

component PeakHold is
	generic
	(	MClkFreq	: integer  -- Master Clock in MHz
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
end component PeakHold;

component BCD27Seg4 is
	port
	(	BCDIn		: in  std_logic_vector(15 downto 0);
		DecPointIn	: in  std_logic_vector(4 downto 1);
		SegmentOut	: out  std_logic_vector(32 downto 1)
	);
end component BCD27Seg4;

component CorrelationMeter is
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
end component CorrelationMeter;

component FrequencyCounter is
	generic
	(	MClkFreq	: integer  -- Master Clock in MHz
	);
	port
	(	MClk		: in  std_logic;
		FrequCntIn	: in  std_logic;	-- Must be only one MClk high
		FrequOut	: out std_logic_vector(15 downto 0);
		Clk100msOut	: out std_logic
	);
end component FrequencyCounter;

begin

	-- Alternatively, if no PLL used: 
--	MClk <= OscClk; -- Can be replaced by a PLL-circuit

	MClkPLL : pll27to108_ip
	port map
	(	inclk0	=> OscClk,
		c0		=> MClk,
		locked	=> open
	);

	Timer1us1ms : process (MClk)
	begin
		if MClk = '1' and MClk'event then
			if Clk1usEn = '1' then
				Timer1usCnt <= (others => '0');
				if Clk1msEn = '1' then
					Timer1msCnt <= (others => '0');
				else
					Timer1msCnt <= Timer1msCnt + 1; 
				end if;
			else
				Timer1usCnt <= Timer1usCnt + 1; 
			end if;
		end if;
	end process Timer1us1ms;

	Clk1usEn <= '1' when Timer1usCnt = MClkFreq - 1 else '0';
	Clk1msEn <= '1' when (Timer1msCnt = 999) and (Clk1usEn = '1') else '0';

	StartupTimer : process (MClk)
	begin
		if MClk = '1' and MClk'event then
			if Clk1msEn = '1' then
				if Timer2sCnt /= "11111111111" then
					Timer2sCnt <= Timer2sCnt + 1;
					Startup <= '1';
				else
					Startup <= '0';
				end if;
			end if;
		end if;
	end process StartupTimer;
	
	I2SReceiverx1 :I2SReceiver
	port map
	(
		MClk 		=> MClk,
		Sclk		=> Sclk,
		Lrck		=> Lrck,
		SclkCnt 	=>	SclkCnt,
		Data		=>	Data,
		LQ			=> AudioData0,
		RQ			=> AudioData1,
		Q			=> open,
		AudioDataEn => AudioDataEn
	);

	SPDIFInput <= SPDIFInput1 when SPDIFInSel = '1' else SPDIFInput2;

	SPDIFRx1 : SPDIFReceiver
	port map
	(	MClk		=> MClk,
		SPDIFInput	=> SPDIFInput,
--		AudioData0	=> AudioData0,
--		AudioData1	=> AudioData1,
		AudioData0	=> open,
		AudioData1	=> open,
		SPDIFLock	=> SPDIFLock,
		Validity	=> open,
		UserData	=> open, -- Test3,
		ChStatus	=> open,
		Parity		=> open,
		AudioDataEn	=> open,
		BlockStart	=> Test3,
		ChIndex		=> ChIndex,
		FrameStart	=> Test4,
		-- Test
		SampleEn	=> Test1,
		SPDIFInShft	=> Test2,
		TestVector1	=> open, -- TestVector1,
		TestVector2	=> open -- TestVector2
	);

	KeyLeft <= Key1 & Key2;
	with KeyLeft select
		iAudioData0 <=	AudioData0 when "11",
						(others => '0') when "01",
						"100000000000000000000000" when "10",
						"010000000000000000000000" when others;
	KeyRight <= Key1 & Key2;
	with KeyRight select
		iAudioData1 <=	AudioData1 when "11",
						(others => '0') when "01",
						"100000000000000000000000" when "10",
						"010000000000000000000000" when others;

	PeakLevelMeter1 : PeakLevelMeter
	generic map
	(	MClkFreq	=> MClkFreq)
	port map
	(	MClk		=> MClk,
		Clk1msEn	=> Clk1msEn,
		AudioDataL	=> iAudioData0,
		AudioDataR	=> iAudioData1,
--		ChIndex		=> ChIndex,
		ChIndex 		=> Lrck,
		AudioLevelL	=> AudioLevelL,
		AudioLevelR	=> AudioLevelR,
		ClipL		=> ClipL,
		ClipR		=> ClipR
	);

	Bin2DecibelLevelL : Bin2Decibel
	port map
	(	MClk		=> MClk,
		LevelBinIn	=> AudioLevelL,
		DecibelBCD	=> DecibelBCDL,
		DecibelBin	=> DecibelBinL
	);

	Bin2DecibelLevelR : Bin2Decibel
	port map
	(	MClk		=> MClk,
		LevelBinIn	=> AudioLevelR,
		DecibelBCD	=> DecibelBCDR,
		DecibelBin	=> DecibelBinR
	);

	PeakHoldL : PeakHold
	generic map
	(	MClkFreq	=> MClkFreq)
	port map
	(	MClk		=> MClk,
		Clk1msEn	=> Clk1msEn,
		DecibelBin	=> DecibelBinL,
		DecibelBCD	=> DecibelBCDL,
		Clip		=> ClipL,
		HoldTime	=> not HoldTime,
		HoldRelease	=> not HoldRelease,
		HoldBin		=> HoldBinL,
		HoldBCD		=> HoldBCDL,
		HoldClip	=> HoldClipL
	);

	PeakHoldR : PeakHold
	generic map
	(	MClkFreq	=> MClkFreq)
	port map
	(	MClk		=> MClk,
		Clk1msEn	=> Clk1msEn,
		DecibelBin	=> DecibelBinR,
		DecibelBCD	=> DecibelBCDR,
		Clip		=> ClipR,
		HoldTime	=> not HoldTime,
		HoldRelease	=> not HoldRelease,
		HoldBin		=> HoldBinR,
		HoldBCD		=> HoldBCDR,
		HoldClip	=> HoldClipR
	);

	LRCorrelation : CorrelationMeter
	port map
	(	MClk		=> MClk,
		Clk1usEn	=> Clk1usEn,
		AudioInL	=> AudioData0(23 downto 23 - 8),
		AudioInR	=> AudioData1(23 downto 23 - 8),
		Correlation	=> Correlation,
		LowLevel	=> LowLevel,
		TestSel		=> "000", -- -> ext. switch set to 7 -- not HoldTime,
		TestVector	=> open -- TestVector2
	);

	SampleRateDisplay : FrequencyCounter
	generic map
	(	MClkFreq	=> MClkFreq)
	port map
	(	MClk		=> MClk,
		FrequCntIn	=> AudioDataEn,
		FrequOut	=> FrequOut
	);
				-- Display "CLIP"
				-- Display "----" if input = zero
				-- or normal numeric display
	BCDCodeL <=	"1010101100011100" when HoldClipL = '1' else							-- "CLIP"
				"1110111011101110" when (not HoldBCDL) = 0 else							-- "----"
				"1110" & HoldBCDL(15 downto 4) when HoldBCDL(15 downto 12) /= 0 else	-- "-xxx"
				"1110" & HoldBCDL(11 downto 0) when HoldBCDL(11 downto 8) /= 0 else		-- "-xx.x"
				"11101111" & HoldBCDL(7 downto 0);										-- "- x.x"

	BCDCodeR <=	"1010101100011100" when HoldClipR = '1' else
				"1110111011101110" when (not HoldBCDR) = 0 else
				"1110" & HoldBCDR(15 downto 4) when HoldBCDR(15 downto 12) /= 0 else
				"1110" & HoldBCDR(11 downto 0) when HoldBCDR(11 downto 8) /= 0 else
				"11101111" & HoldBCDR(7 downto 0);

	BCDCodeF <=	to_stdlogicvector(Version) when Startup = '1' else						-- Version
				"1110111011101110" when FrequOut = 0 else								-- "----"
				FrequOut when FrequOut(15 downto 12) /= 0 else							-- "xxx.x"
				"1111" & FrequOut(11 downto 0) when FrequOut(11 downto 8) /= 0 else		-- " xx.x"
				"11111111" & FrequOut(7 downto 0);										-- "  x.x"

	DecPointsL <= 	"0000" when HoldClipL = '1' else
					"0000" when (not HoldBCDL) = 0 else
					"0000" when HoldBCDL(15 downto 12) /= 0 else
					"0010";

	DecPointsR <= 	"0000" when HoldClipR = '1' else
					"0000" when (not HoldBCDR) = 0 else
					"0000" when HoldBCDR(15 downto 12) /= 0 else
					"0010";

	DecPointsF <= 	"0100" when Startup = '1' else						-- Version
					"0000" when FrequOut = 0 else
					"0010";

	BCD27SegL : BCD27Seg4
	port map
	(	BCDIn		=> BCDCodeL,
		DecPointIn	=> DecPointsL,
		SegmentOut	=> LEDSegmentL
	);

	BCD27SegR : BCD27Seg4
	port map
	(	BCDIn		=> BCDCodeR,
		DecPointIn	=> DecPointsR,
		SegmentOut	=> LEDSegmentR
	);

	BCD27SegF : BCD27Seg4
	port map
	(	BCDIn		=> BCDCodeF,
		DecPointIn	=> DecPointsF,
		SegmentOut	=> LEDSegmentF
	);

	BarDisplay : Process (AudioLevelL, AudioLevelR, HoldClipL, HoldClipR, DecibelBinL, DecibelBinR, HoldBinL, HoldBinR, Correlation, LowLevel)
	begin
--		-- Linear scale
--		for LEDNr in 30 downto 1 loop
--			-- Left Channel
--			if DecibelBinL < (10 * (31 - LEDNr)) or (HoldBinL < (10 * (31 - LEDNr)) and HoldBinL >= (10 * (30 - LEDNr)) and (HoldClipL = '0')) then
--				LEDBarL(LEDNr) <= '1';
--			else
--				LEDBarL(LEDNr) <= '0';
--			end if;
--			-- Right Channel
--			if DecibelBinR < (10 * (31 - LEDNr)) or (HoldBinR < (10 * (31 - LEDNr)) and HoldBinR >= (10 * (30 - LEDNr)) and (HoldClipR = '0')) then
--				LEDBarR(LEDNr) <= '1'; 
--			else
--				LEDBarR(LEDNr) <= '0';
--			end if;
--		end loop LevelDisplayLoop;
		-- LED scale  12 x 1dB,                             6 x 2dB,            6 x 3dB,            6 x 4dB
		-- LED Nr     30 29 28 27 26 25 24 23 22 21 20 19   18 17 16 15 14 13   12 11 10  9  8  7    6  5  4  3  2  1
		-- Threshold  01 02 03 04 05 06 07 08 09 10 11 12   14 16 18 20 22 24   27 30 33 36 39 42   46 50 54 58 62 66
		LevelDisplayLoop1dB:
		for LEDNr in 30 downto 19 loop
			-- Left Channel
			if DecibelBinL < (10 + 10 * (30 - LEDNr)) or (HoldBinL < (10 + 10 * (30 - LEDNr)) and HoldBinL >= (0 + 10 * (30 - LEDNr)) and (HoldClipL = '0')) then
				LEDBarL(LEDNr) <= '1';
			else
				LEDBarL(LEDNr) <= '0';
			end if;
			-- Right Channel
			if DecibelBinR < (10 + 10 * (30 - LEDNr)) or (HoldBinR < (10 + 10 * (30 - LEDNr)) and HoldBinR >= (0 + 10 * (30 - LEDNr)) and (HoldClipR = '0')) then
				LEDBarR(LEDNr) <= '1'; 
			else
				LEDBarR(LEDNr) <= '0';
			end if;
		end loop LevelDisplayLoop1dB;
		LevelDisplayLoop2dB:
		-- 20 * (25 - 18) = 140 -> 14dB
		for LEDNr in 18 downto 13 loop
			-- Left Channel
			if DecibelBinL < (140 + 20 * (18 - LEDNr)) or (HoldBinL < (140 + 20 * (18 - LEDNr)) and HoldBinL >= (120 + 20 * (18 - LEDNr)) and (HoldClipL = '0')) then
				LEDBarL(LEDNr) <= '1';
			else
				LEDBarL(LEDNr) <= '0';
			end if;
			-- Right Channel
			if DecibelBinR < (140 + 20 * (18 - LEDNr)) or (HoldBinR < (140 + 20 * (18 - LEDNr)) and HoldBinR >= (120 + 20 * (18 - LEDNr)) and (HoldClipR = '0')) then
				LEDBarR(LEDNr) <= '1'; 
			else
				LEDBarR(LEDNr) <= '0';
			end if;
		end loop LevelDisplayLoop2dB;
		LevelDisplayLoop3dB:
		-- 30 * (21 - 12) = 270 -> 27dB
		for LEDNr in 12 downto 7 loop
			-- Left Channel
			if DecibelBinL < (270 + 30 * (12 - LEDNr)) or (HoldBinL < (270 + 30 * (12 - LEDNr)) and HoldBinL >= (240 + 30 * (12 - LEDNr)) and (HoldClipL = '0')) then
				LEDBarL(LEDNr) <= '1';
			else
				LEDBarL(LEDNr) <= '0';
			end if;
			-- Right Channel
			if DecibelBinR < (270 + 30 * (12 - LEDNr)) or (HoldBinR < (270 + 30 * (12 - LEDNr)) and HoldBinR >= (240 + 30 * (12 - LEDNr)) and (HoldClipR = '0')) then
				LEDBarR(LEDNr) <= '1'; 
			else
				LEDBarR(LEDNr) <= '0';
			end if;
		end loop LevelDisplayLoop3dB;
		-- 40 * (21 - 6) = 460 -> 46dB
		LevelDisplayLoop4dB:
		for LEDNr in 6 downto 1 loop
			-- Left Channel
			if DecibelBinL < (460 + 40 * (6 - LEDNr)) or (HoldBinL < (460 + 40 * (6 - LEDNr)) and HoldBinL >= (420 + 40 * (6 - LEDNr)) and (HoldClipL = '0')) then
				LEDBarL(LEDNr) <= '1';
			else
				LEDBarL(LEDNr) <= '0';
			end if;
			-- Right Channel
			if DecibelBinR < (460 + 40 * (6 - LEDNr)) or (HoldBinR < (460 + 40 * (6 - LEDNr)) and HoldBinR >= (420 + 40 * (6 - LEDNr)) and (HoldClipR = '0')) then
				LEDBarR(LEDNr) <= '1'; 
			else
				LEDBarR(LEDNr) <= '0';
			end if;
		end loop LevelDisplayLoop4dB;

		LEDBarL(31) <= HoldClipL;
		LEDBarL(32) <= HoldClipL;
		LEDBarR(31) <= HoldClipR;
		LEDBarR(32) <= HoldClipR;
		-- Correlation using a bar of LEDs beginning in the center
		for LEDNr in 1 to 30 loop
			if (Correlation > (LEDNr * 255) / 31) xor (LEDNr <= 15) then
				LEDBarC(LEDNr) <= '1';
			else
				LEDBarC(LEDNr) <= '0';
			end if;
		end loop CorrelationDisplayLoop;
--		-- Correlation using a pair of LEDs to indicate a value
--  	if Correlation <= 2 * 256 / 31 then 
--			LEDBarC(1) <= '1';
--		else
--			LEDBarC(1) <= '0';
--		end if;
--		-- CorrelationDisplayLoop:
--		for LEDNr in 2 to 29 loop
--			if (Correlation > (LEDNr - 1) * 256 / 31) and (Correlation <= (LEDNr + 1) * 256 / 31 ) then
--				LEDBarC(LEDNr) <= '1';
--			else
--				LEDBarC(LEDNr) <= '0';
--			end if;
--		end loop CorrelationDisplayLoop;
--		if Correlation > 29 * 256 / 31 then
--			LEDBarC(30) <= '1';
--		else
--			LEDBarC(30) <= '0';
--		end if;
		LEDBarC(31) <= LowLevel;
		LEDBarC(32) <= LowLevel;
	end process BarDisplay;

	LEDMultiplexCnt : process (MClk)
	begin
		if MClk = '1' and MClk'event then
			if Clk1msEn = '1' then
				if LEDMuxCnt = 5 then
					LEDMuxCnt <= (others => '0');
				else
					LEDMuxCnt <= LEDMuxCnt + 1;
				end if;
			end if;
		end if;
	end process LEDMultiplexCnt;

	LEDBarTest <= "01010101010101010101010101010101" when Timer2sCnt(Timer2sCnt'left) = '0' else "10101010101010101010101010101010";
	LEDSegTest <= "00110110001101100011011000110110" when Timer2sCnt(Timer2sCnt'left) = '0' else "11001001110010011100100111001001";
	
	with Startup & LEDMuxCnt select
	LEDSegment <=	not LEDSegmentL when "0000",
					not LEDBarL		when "0001",
					not LEDSegmentR	when "0010",
					not LEDBarR		when "0011",
					not LEDSegmentF	when "0100",
					not LEDBarC		when "0101",
					    LEDSegTest	when "1000", -- Startup
					    LEDSegTest	when "1010",
					not LEDSegmentF	when "1100",
					    LEDBarTest	when others;

	-- Protective intervall 10us until transistors get out of saturation
	LEDMuxChange <= '1' when (Timer1msCnt > 990 - 1) else '0';
	with LEDMuxCnt & LEDMuxChange select
	LEDGroup <=	not "000001"	when "0000",	--- LEDBarL
				not "000010"	when "0010",		--- LEDSegmentL
				not "000100"	when "0100",		--- LEDBarR
				not "001000"	when "0110",      --- LEDSegmentR
				not "010000"	when "1000",		--- LEDBarC
				not "100000"	when "1010",		--- LEDSegmentF
				not "000000"	when others;

--	with LEDMuxCnt & LEDMuxChange select
--	LEDGroup <= not "000010" when "0000",
--					not "000000" when others;
				
	SPDIFOutput <= SPDIFInput;
	TestVector1 <= not AudioData0(23) & AudioData0(22 downto 16);
	TestVector2 <= not AudioData1(23) & AudioData1(22 downto 16);
	Test5 <= SPDIFLock;
	Test6 <= LEDMuxCnt(2);
	Test7 <= LEDMuxCnt(1);
	Test8 <= LEDMuxCnt(0);

end Behavioral;

