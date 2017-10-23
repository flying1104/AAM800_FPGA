----------------------------------------------------------------------------------
-- www.Beis.de
-- Uwe Beis
--
-- Create Date:		2006-04-01
-- Project Name:	DigitalLevelMeter
-- Design Name:		DigitalLevelMeter
-- Module Name:		S/PDIF-Rx - Behavioral 
-- Description:		S/PDIF-receiver with direct S/PDIF data stream input
--             		Up to 196 kHz sample rate with MClk >= 80 MHz
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity SPDIFReceiver is
	port
	(	MClk		: in std_logic;
		SPDIFInput	: in std_logic;
		AudioData0	: out std_logic_vector(23 downto 0);
		AudioData1	: out std_logic_vector(23 downto 0);
		SPDIFLock	: out std_logic;
		Validity	: out std_logic;
		UserData	: out std_logic;
		ChStatus	: out std_logic;
		Parity		: out std_logic;
		AudioDataEn	: out std_logic;
		BlockStart	: out std_logic;
		ChIndex		: out std_logic;
		FrameStart	: out std_logic;
		-- Test
		SPDIFInShft	: out std_logic;
		SampleEn	: out std_logic;
		TestVector1	: out  std_logic_vector(7 downto 0);
		TestVector2	: out  std_logic_vector(7 downto 0)
	);
end SPDIFReceiver;

architecture Behavioral of SPDIFReceiver is
-- SPDIF Edge detection
signal SPDIFInputShift	: std_logic_vector(2 downto 1);
-- Approximate SPDIF bit time evaluation
signal SPDIFEdgeTimeCnt	: std_logic_vector(7 downto 0) := (others => '0'); -- max. 256 clocks für "10"-sequence
signal SPDIFEdgeMinTime	: std_logic_vector(7 downto 0) := (others => '1'); --      -> < 400/6,3 kHz @ 100 MHz
signal SPDIFEdgeTimeReg	: std_logic_vector(7 downto 0);
signal MinTimeIncPreCnt	: std_logic_vector(15 downto 0); -- 2 ^ 16 MClks wait until increment SPDIFEdgeMinTime
-- SPDIF word time evaluation
signal HalfBitMaskTime	: std_logic_vector(7 downto 0) := (others => '0'); -- max. 192 (3/4 MinTime)
signal HalfBitMaskCnt	: std_logic_vector(7 downto 0) := (others => '0'); -- max. 192 clocks (3/4 MinTime)
signal SPDIFBitCnt		: std_logic_vector(5 downto 0)  := (others => '0'); -- counts up to 61 for 1 word = 64 bits
signal SPDIFWordTimeCnt	: std_logic_vector(13 downto 0) := (others => '1'); -- max. 64 x MinTime
signal SPDIFWordTime	: std_logic_vector(13 downto 0) := (others => '1'); -- max. 64 x MinTime
--
signal SPDIFWordTimeLPF	: std_logic_vector(29 downto 0); -- Avarage of recent WordTime
signal SPDIFLockCnt		: std_logic_vector(12 downto 0); -- 10^13 frames, i.e., 0.1 s @ 48kHz
signal iSPDIFLock		: std_logic;
-- Sample points for SPDDIF signal sampling
signal BitSamplePoint1	: std_logic_vector(17 downto 0); -- max.      64 x MinTime
signal BitSamplePoint2	: std_logic_vector(17 downto 0); -- max.  3 x 64 x MinTime
signal BitSamplePoint3	: std_logic_vector(17 downto 0); -- max.  5 x 64 x MinTime
signal BitSamplePoint4	: std_logic_vector(17 downto 0); -- max.  7 x 64 x MinTime
signal BitSamplePoint5	: std_logic_vector(17 downto 0); -- max.  9 x 64 x MinTime
signal BitSamplePoint6	: std_logic_vector(17 downto 0); -- max. 11 x 64 x MinTime
signal BitSampleLatch1	: std_logic_vector(5 downto 0);
signal BitSampleLatch2	: std_logic_vector(7 downto 0);
signal BitSampleLatch3	: std_logic_vector(8 downto 0);
signal BitSampleLatch4	: std_logic_vector(8 downto 0);
signal BitSampleLatch5	: std_logic_vector(9 downto 0);
signal BitSampleLatch6	: std_logic_vector(9 downto 0);
-- Sample S/PDIF input bits, decode preambles and extract audio and other data
signal iSampleEn		: std_logic; -- The moment when a sample from the S/PDIF data stream is taken
signal SPDIFSampleCnt	: std_logic_vector(9 downto 0) := (others => '0'); -- max. 768 clocks for "111000"-sequence
signal SPDIFSampleShift	: std_logic_vector(7 downto 0)  := (others => '0'); -- Shift register for 8 SPDIF-bits
signal SampleIndex		: std_logic;
signal SPDIFDataShift	: std_logic_vector(32 downto 0);
signal AudioDataBuf0	: std_logic_vector(23 downto 0);
signal AudioDataBuf1	: std_logic_vector(23 downto 0);
signal AudioDataOut0	: std_logic_vector(23 downto 0);
signal AudioDataOut1	: std_logic_vector(23 downto 0);
signal VUCP				: std_logic_vector(3 downto 0); -- 3: Parity, 2: Channel Status, 1: User Data, 0: Validity 
signal iChannelIndex	: std_logic;
signal iAudioDataEn		: std_logic;
signal iFrameStart		: std_logic;
signal iBlockStart		: std_logic;

begin

	ShiftSPDIFInput : process (MClk)
	-- For SPDIF edge detection:
	--     Falling edge: SPDIFInputShift = "10" 
	--     Rising  edge: SPDIFInputShift = "01" 
	begin
		if MClk = '1' and MClk'event then
			SPDIFInputShift <= SPDIFInputShift(1) & SPDIFInput;
		end if;
	end process ShiftSPDIFInput;
	
	DetermineSPDIFEdgeMinTime : process (MClk)
	-- The minimum time SPDIFEdgeMinTime (in MClks) between two falling edges
	-- This time represents approximately the length one data bit in the received signal
	-- (Note: Two signal bits represent one audio data bit)
	-- (Due to possible poor pulse symmetry rising edges not taken into account)
	-- The least time between two falling edges detected is stored in SPDIFEdgeMinTime
	begin
		if MClk = '1' and MClk'event then
			if SPDIFInputShift = "10" then
				if (SPDIFEdgeTimeCnt <= SPDIFEdgeMinTime) and (SPDIFEdgeTimeCnt > 4) then
					SPDIFEdgeMinTime <= SPDIFEdgeTimeCnt;
				end if;
				SPDIFEdgeTimeCnt <= (others => '0');
				SPDIFEdgeTimeReg <= SPDIFEdgeTimeCnt;
			else
				if SPDIFEdgeTimeCnt < 2**SPDIFEdgeTimeCnt'length -1 then
					SPDIFEdgeTimeCnt <= SPDIFEdgeTimeCnt + 1;
				else
					SPDIFEdgeTimeReg <= SPDIFEdgeTimeCnt;
				end if;
			end if;
			-- Slowly increase SPDIFEdgeMinTime in case of e. g. a reduction the of the sample rate
			-- One 8 kHz-word (64 data bits) at 100 Mhz -> 12500 MClks
			-- One 192 kHz-word (64 data bits) at 100 Mhz -> 500 MClks
			-- SPDIFEdgeMinTime for 8 kHz at 100 Mhz = 195 MClks
			-- SPDIFEdgeMinTime for 192 kHz at 100 Mhz = 8 MClks
			-- Increase SPDIFEdgeMinTime every 65536 MClks by one: 256 * 65536 = 16,777,216 MClks = 168 ms from SPDIFEdgeMinTime = 0 to 255
			if SPDIFEdgeTimeReg <= SPDIFEdgeMinTime then
				-- Ok, sample rate is still the same
				MinTimeIncPreCnt <= (others => '0');
			else
				-- Wait 65536 MClks until increment SPDIFEdgeMinTime by 1 (up to 255)
				MinTimeIncPreCnt <= MinTimeIncPreCnt + 1;
				if MinTimeIncPreCnt = 2**(MinTimeIncPreCnt'length - 1) then
					SPDIFEdgeMinTime <= SPDIFEdgeMinTime + 1;
				end if;
			end if;
		end if;
	end process DetermineSPDIFEdgeMinTime;

	DetermineSPDIFWordTime : process (MClk)
	-- Detect the time SPDIFWordTime (in MClks) for 64 audio data bits
	-- Needed for preciser determination of sample points for data extraction than SPDIFMinTime
	-- At least one SPDIF-edge must appear each audio data bit, but in case of audio data bit = 1 two edges appear 
	-- All edges appearing during 0 to 3/4 of SPDIFEdgeMinTime are masked
	-- During each preamble 2 edges less appear
	-- After 62 edges (excl. the masked ones) = 64 audio data bits SPDIFWordTime is stored
	begin
		if MClk = '1' and MClk'event then
			HalfBitMaskTime <= SPDIFEdgeMinTime(SPDIFEdgeMinTime'left downto 2) + ('0' & SPDIFEdgeMinTime(SPDIFEdgeMinTime'left downto 1)); -- Registered wg. Timing
			SPDIFWordTimeCnt <= SPDIFWordTimeCnt + 1;
			if HalfBitMaskCnt <= HalfBitMaskTime then
				HalfBitMaskCnt <= HalfBitMaskCnt + 1;
			else
				if (SPDIFInputShift = "10") or (SPDIFInputShift = "01") then
					HalfBitMaskCnt <= (others => '0');
					if SPDIFBitCnt /= 61 then
						SPDIFBitCnt <= SPDIFBitCnt + 1;
					else
						SPDIFBitCnt <= (others => '0');
						SPDIFWordTime <= SPDIFWordTimeCnt; 
						SPDIFWordTimeCnt <= (others => '0');
						-- Lock Detect
						-- A significant deviation (> +/-3) from the average SPDIFWordTime (= SPDIFWordTimeLPF) is detected as unlock. Then:
						-- 		SPDIFLock is cleared
						-- 		Timer SPDIFLockCnt is set to zero
						--		SPDIFWordTimeLPF is set to the actual SPDIFWordTime
						-- If afterwards no deviation is detected:
						--		Timer SPDIFLockCnt counts up to -1 an then SPDIFLock is set
						if	(SPDIFWordTimeLPF(29 downto 29 - 11) - SPDIFWordTime(13 downto 13 - 11) /= "000000000000") and
							(SPDIFWordTime(13 downto 13 - 11) - SPDIFWordTimeLPF(29 downto 29 - 11) /= "111111111111") then
							-- Timing error (= significant deviation): SPDIF unlocked!
							SPDIFLockCnt <= (others => '0');
							SPDIFWordTimeLPF <= SPDIFWordTime & "0000000000000000";
						else
							-- No timing error:
							if (not SPDIFLockCnt) = 0 then -- i.e., if SPDIFLockCnt = (others => '1')
								-- ... and no timing error occurred recently: S/PDIF is locked 
								-- SPDIFWordTime -> low-pass filter, time constant: 2^16 frames (0.6s at 48 kHz approx.)
								SPDIFWordTimeLPF <= SPDIFWordTimeLPF - ("0000000000000000" & SPDIFWordTimeLPF(29 downto 29 - 13)) + ("0000000000000000" & SPDIFWordTime);
							else
								-- ... but a timing error occurred recently:
								SPDIFLockCnt <= SPDIFLockCnt + 1;
							end if;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process DetermineSPDIFWordTime;
	
	TestVector1 <= SPDIFWordTime(12 downto 12 - 7);
	TestVector2 <= SPDIFWordTime(7 downto 0);

	SetSPDIFLock : process (MClk)
	begin
		if MClk = '1' and MClk'event then
			if (not SPDIFLockCnt) = 0 then -- i.e., if SPDIFLockCnt = (others => '1')
				iSPDIFLock <= '1';
			else
				iSPDIFLock <= '0';
			end if;
		end if;
	end process SetSPDIFLock;
	
	LatchSamplePoints : process (MClk, SPDIFWordTime, BitSamplePoint1, BitSamplePoint2) -- Registered wg. Timing
	-- Calculate 6 sample points for data extraction
	-- The sample points are used to sample the signal after a falling edge
	-- Each sample point is in the middle of one signal bit (Note: Two signal bits represent one audio data bit)
	-- Worst Case: During preamble X starting with a falling edge 6 samples must be taken until the next falling edge
	begin
		BitSamplePoint1 <= ("0000" & SPDIFWordTime);						-- SPDIFWordTime x 1
		BitSamplePoint2 <= ("000" & SPDIFWordTime & '0') + BitSamplePoint1;	-- SPDIFWordTime x 3
		BitSamplePoint3 <= ("00" & SPDIFWordTime & "00") + BitSamplePoint1;	-- SPDIFWordTime x 5
		BitSamplePoint4 <= ("00" & SPDIFWordTime & "00") + BitSamplePoint2;	-- SPDIFWordTime x 7
		BitSamplePoint5 <= ('0' & SPDIFWordTime & "000") + BitSamplePoint1;	-- SPDIFWordTime x 9
		BitSamplePoint6 <= ('0' & SPDIFWordTime & "000") + BitSamplePoint2;	-- SPDIFWordTime x 11
		-- 1 x SPDIFWordTime = 128 signal bits
		-- Sample point at (n x SPDIFWordTime) / 256 = 0.5, 1.5, 2.5, 3.5, 4.5 and 5.5 signal bits
		if MClk = '1' and MClk'event then
			BitSampleLatch1 <= BitSamplePoint1(13 downto 8) - 1; 
			BitSampleLatch2 <= BitSamplePoint2(15 downto 8) - 1; 
			BitSampleLatch3 <= BitSamplePoint3(16 downto 8) - 1; 
			BitSampleLatch4 <= BitSamplePoint4(16 downto 8) - 1; 
			BitSampleLatch5 <= BitSamplePoint5(17 downto 8) - 1; 
			BitSampleLatch6 <= BitSamplePoint6(17 downto 8) - 1; 
			if	(SPDIFSampleCnt = BitSampleLatch1) or 
				(SPDIFSampleCnt = BitSampleLatch2) or
				(SPDIFSampleCnt = BitSampleLatch3) or
				(SPDIFSampleCnt = BitSampleLatch4) or
				(SPDIFSampleCnt = BitSampleLatch5) or
				(SPDIFSampleCnt = BitSampleLatch6) then 
				iSampleEn <= '1';
			else
				iSampleEn <= '0';
			end if;
		end if;
	end process LatchSamplePoints;

--	iSampleEn	<= '1' when	(SPDIFSampleCnt = BitSampleLatch1) or
--							(SPDIFSampleCnt = BitSampleLatch2) or
--							(SPDIFSampleCnt = BitSampleLatch3) or
--							(SPDIFSampleCnt = BitSampleLatch4) or
--							(SPDIFSampleCnt = BitSampleLatch5) or
--							(SPDIFSampleCnt = BitSampleLatch6) else '0';

	DecodeSPDIF : process (MClk)
	-- Sample the SPDIF signal bits (not audio data bits) and indicate SPDIF synchronization
	-- After each falling edge up to 6 signal bit samples are sampled "free-running" and shifted into SPDIFSampleShift
	-- Each falling edge restarts or re-synchronizes the sampling phasde
	-- Preambles in the signal generate ChannelIndex (-> "left/right clock" or "word clock") and BlockStart
	--
	-- SPDIF signal bits are decoded as 0 and 1 in the signal and shifted in SPDIFDataShift
	-- At each start of a frame the contents of SPDIFDataShift is copied into AudioData0, AudioData1 and/or VUCP
	-- SPDIF single channel dual sample rate transmission is supported (hoepfully...)
	--
	-- MClk		  /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
	--            __         _______                          ______________________         _______         _______                 _______________
	-- SPDIFInput   \_______/       \________________________/                      \_______/       \_______/       \_______________/               \_____
	--             __         _______                          ______________________         _______         _______                 _______________
	-- SPDIFShift(1) \_______/       \________________________/                      \_______/       \_______/       \_______________/               \_____
	--               __         _______                          ______________________         _______         _______                 _______________
	-- SPDIFShift(2)   \_______/       \________________________/                      \_______/       \_______/       \_______________/               \_____
	--                 |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |
	--                 |  Parity (=1)  | -------------------------- Preamble --------------------------|   Data0 (=1)  |   Data1 (=0)  |   Data2 (=0)  |
	--                _               _                                               _               _               _                               _
	-- SPDIFEdge    _/ \_____________/ \_____________________________________________/ \_____________/ \_____________/ \_____________________________/ \___
	--
	-- SPDIFSampleCnt  X0X1X2X3X4X5X6X7X0X1.....
	--                      _       _       _       _       _       _       _       _       _       _       _       _       _       _       _       _       _
	-- SamplePoint    _____/ \_____/ \_____/ \_____/ \_____/ \_____/ \_____/ \_____/ \_____/ \_____/ \_____/ \_____/ \_____/ \_____/ \_____/ \_____/ \_____/ \___
	--                _______         _______         _______         _______         _______         _______         _______         _______         _______
	-- SampleIndex   /       \_______/       \_______/       \_______/       \_______/       \_______/       \!______/       \_______/       \_______/       \
	--                   ____         _______                          ______________________         _______         _______                 _______________
	-- SPDIFSampleShift(0)   \_______/       \________________________/                      \_______/       \_______/       \_______________/               \_____
	--                           ____         _______                         _______________________         _______         _______                 _______________
	-- SPDIFSampleShift(1)           \_______/       \_______________________/                       \_______/       \_______/       \_______________/               \_____
	--                                                                                                        _
	-- FrameStart     _______________________________________________________________________________________/ \_____________________________________________________________
	--                      _ _______________ _______________                 _______________                 _______________________________
	-- SPDIFDataShift(MSBit)_X_______?_______X               \_______________/               \_______________/                               \_______________________________
	--
	--                       |  Ch. Status   |  Parity (=1)  | --------------------- ignore (Preamble) --------------------- |   Data0 (=1)  |   Data1 (=0)  |   Data2 (=0)  |	begin

	begin
		if MClk = '1' and MClk'event then
			if SPDIFInputShift = "10" then
				SPDIFSampleCnt <= (others => '0');
			else
				SPDIFSampleCnt <= SPDIFSampleCnt + 1;
			end if;
			if iSampleEn	= '1' then
				-- Each signal bit sample
				SPDIFSampleShift <= SPDIFSampleShift(SPDIFSampleShift'left - 1 downto 0) & SPDIFInputShift(2);
				SampleIndex <= not SampleIndex;
				if SampleIndex = '1' then
					-- Each second signal bit sample extract one data bit
					SPDIFDataShift <= (SPDIFSampleShift(0) xor SPDIFSampleShift(1)) & SPDIFDataShift(SPDIFDataShift'left downto 1);
				end if;
				If (SPDIFSampleShift = "00011101") or (SPDIFSampleShift = "11100010") then
					-- Preamble X: Subframe 1 (left)
					-- Output both channels (or, in case of single channel dual sample rate, one only)
					AudioDataOut0	<= AudioDataBuf0;
					AudioDataOut1	<= AudioDataBuf1;
					AudioDataBuf0	<= (others => '0');
					AudioDataBuf1	<= (others => '0');
					-- Transfer audio data received in the previous subframe into its corresponding buffer
					If iChannelIndex = '0' then -- (Allow single channel dual sample rate transmission)
						AudioDataOut0 <= SPDIFDataShift(SPDIFDataShift'left - 7 downto SPDIFDataShift'left - 30);
					else
						AudioDataOut1 <= SPDIFDataShift(SPDIFDataShift'left - 7 downto SPDIFDataShift'left - 30);
					end if;
					VUCP <= SPDIFDataShift(SPDIFDataShift'left - 3 downto SPDIFDataShift'left - 6);
					SampleIndex <= '0';
					iAudioDataEn <= '1';
					iChannelIndex <= '0';
					iFrameStart <= '1';
				end if;
				If (SPDIFSampleShift = "00011011") or (SPDIFSampleShift = "11100100") then
					-- Preamble Y: Subframe 2 (right)
					-- Transfer audio data received in the previous subframe into its corresponding buffer
					If iChannelIndex = '0' then -- (Allow single channel dual sample rate transmission)
						AudioDataBuf0 <= SPDIFDataShift(SPDIFDataShift'left - 7 downto SPDIFDataShift'left - 30);
					else -- (This "else", i.e., consecutive subrames 2, never should happen)
						AudioDataBuf1 <= SPDIFDataShift(SPDIFDataShift'left - 7 downto SPDIFDataShift'left - 30);
					end if;
					VUCP <= SPDIFDataShift(SPDIFDataShift'left - 3 downto SPDIFDataShift'left - 6);
					SampleIndex <= '0';
					iChannelIndex <= '1';
					iFrameStart <= '1';
				end if;
				If (SPDIFSampleShift = "00010111") or (SPDIFSampleShift = "11101000") then
				-- Preamble Z: Block start (left)
					-- Preamble X: Subframe 1 (left)
					-- Output both channels (or, in case of single channel dual sample rate, one only)
					AudioDataOut0	<= AudioDataBuf0;
					AudioDataOut1	<= AudioDataBuf1;
					AudioDataBuf0	<= (others => '0');
					AudioDataBuf1	<= (others => '0');
					-- Transfer audio data received in the previous subframe into its corresponding buffer
					If iChannelIndex = '0' then -- (Allow single channel dual sample rate transmission)
						AudioDataOut0 <= SPDIFDataShift(SPDIFDataShift'left - 7 downto SPDIFDataShift'left - 30);
					else
						AudioDataOut1 <= SPDIFDataShift(SPDIFDataShift'left - 7 downto SPDIFDataShift'left - 30);
					end if;
					VUCP <= SPDIFDataShift(SPDIFDataShift'left - 3 downto SPDIFDataShift'left - 6);
					SampleIndex <= '0';
					iBlockStart <= '1';
					iAudioDataEn <= '1';
					iChannelIndex <= '0';
					iFrameStart <= '1';
				end if;
			else
				iAudioDataEn <= '0';
				iFrameStart <= '0';
				iBlockStart <= '0';
			end if;
		end if;
	end process DecodeSPDIF;
	
	AudioOut : process (MClk)
	begin
		if MClk = '1' and MClk'event then
			if iSPDIFLock ='1' then
				AudioData0	<= AudioDataOut0;
				AudioData1	<= AudioDataOut1;
			else
				AudioData0 <= (others => '0');
				AudioData1 <= (others => '0');
			end if;
			BlockStart	<= iBlockStart;
			ChIndex		<= iChannelIndex;
			FrameStart	<= iFrameStart;
			AudioDataEn <= iAudioDataEn;
			Validity	<= VUCP(0);
			UserData	<= VUCP(1);
			ChStatus	<= VUCP(2);
			Parity		<= VUCP(3);
		end if;
	end process AudioOut;

	SPDIFLock	<= iSPDIFLock;
	SampleEn	<= iSampleEn;
	SPDIFInShft	 <= SPDIFInputShift(2);
	
end Behavioral;
