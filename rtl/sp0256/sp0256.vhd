---------------------------------------------------------------------------------
-- sp0256 player by Dar (darfpga@aol.fr)
-- http://darfpga.blogspot.fr
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
-- sp0256 (player) releases 
--
--  rev 0.0 - 14/04/2018 
--			play only sp0256-al2 (cmd 00-3F, 12 bits rom address)
--
--	 rev 1.0 - 23/07/2018
--			extend to play sp0256b_019 + spr128_003 (cmd 00-7F, 14 bits rom address)
--
--	 rev 2.0 - 26/07/2019 - by Victor Trucco
--			sound banks handling
--
--  rev 2.1 - 24/05/2021 - By rampa
--       clock raise to 750k
--       clock at 2.5Mhz for BRAM access.
--       audio at full 16bit(for fixing the sound on turtles
--
---------------------------------------------------------------------------------
--
-- SP0256-al2 prom decoding scheme and speech synthesis algorithm are from :
--
-- Copyright Joseph Zbiciak, all rights reserved.
-- Copyright tim lindner, all rights reserved.
--
-- See C source code and license in sp0256.c from MAME source
--
-- VHDL code is by Dar.
--
---------------------------------------------------------------------------------
--
--	 One allophone is made of N parts (called here after lines), each part has a
--  16 bytes descriptor. One descriptor (for one part) contains one repeat value
--  one amplitude value, one period value and 2x6 filtering coefficients.
--
--  for line_cnt from 0 to nb_line-1 (part)
--		for line_rpt from 0 to line_rpt-1 (repeat)
--			for per_cnt from 0 to line_per-1 (period) 
--				produce 1 sample
--
--  One sample is the output of the 6 stages filter. Each filter stage is fed by
--  the output of the previous stage, the first stage is fed by the source sample
--
--  when line_per != 0 source sample is set to amplitude value only once at the
--  begin of each repeat (per_cnt==0) then source sample is set to 0
--
--  when line_per == 0 source sample is set to amplitude value only at the begin 
--  of each repeat (per_cnt==0) then source sample sign is toggled (+/-) when then
--  random noise generator lsb equal 1. In that case actual line_per is set to 64
--
--  
--  Sound sample frequency is 10kHz. I make a 25 stages linear state machine 
--  running at 250kHz that produce one sound sample per cycle.
--
--  As long as one allophones is available the state machine runs permanently and
--  there is zero latency between allophones.
--
--  During one (each) cycle the state machine:
--
--    - fetch new allophone or go on with current one if not finished
--    - get allophone first line descriptor address from rom entry table
--    - get allophone nb_line from rom entry table and jump to first line address
--    - get allophone line_rpt from rom current line descriptor
--    - get allophone amplitude from rom current line descriptor
--         manage source amplitude, reset filter if needed
--    - get allophone line_per from rom current line descriptor
--    - address filter coefficients F/B within rom current line descriptor,
--         feed filter input, update filter state with computation output 
--    - rescale last filter stage output to audio output 
--    - manage per_cnt, rpt_cnt, line_cnt and random noise generator
--
--  Filter computation:
--
--	   Filter coefficients F or B index is get from rom current line descriptor
--    (address managed by state machine), value is converted thru coeff_array
--    table. Coefficient index has a sign bit to be managed:
--
--      if index sign bit = 0, filter coefficient <= -coeff_array(index)
--      if index sign bit = 1, filter coefficient <= coeff_array(-index)
--
--    During one state machine cycle each filter is updated once.
--    One filter update require two state machine steps:
--	
--      step 1
-- 			sum_in1 <= filter input
--          sum_in2 <= filter coefficient F * filter state z1 / 256
--          sum_out <= sum_in1 + sum_in2
--      step 2
-- 			sum_in1 <= sum_out
--          sum_in2 <= filter coefficient B * filter state z2 / 512
--          sum_out <= sum_in1 + sum_in2
--          filter state z1 <= sum_in1 + sum_in2 
--          filter state z2 <= filter state z1 
--
--		(sum_out will be limited to -32768/+32767)
--

---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity sp0256 is
port
(
	clock_750k   : in std_logic;
	clock_2m5    : in std_logic;
	reset        : in std_logic;

	input_rdy      : out std_logic;

	allophone      : in  std_logic_vector(6 downto 0);
	trig_allophone : in  std_logic;
	
	audio_out    : out signed(15 downto 0)
	
		
);
end sp0256;

architecture syn of sp0256 is
  
 signal clock_750k_n  : std_logic;
 signal rom_addr 		: std_logic_vector(13 downto 0);
 signal rom_do   		: std_logic_vector( 7 downto 0);
 signal bank 			: std_logic_vector( 1 downto 0);

 signal stage : integer range 0 to 249; -- stage counter 0-24;
 
 signal allo_entry                   : std_logic_vector(8 downto 0);
 signal allo_addr_lsb, allo_addr_msb : std_logic_vector(7 downto 0);
 signal allo_nb_line                 : std_logic_vector(7 downto 0);
 signal line_rpt, line_per           : std_logic_vector(7 downto 0);
 signal line_amp_lsb, line_amp_msb   : std_logic_vector(7 downto 0);
 
 signal amp, filter, coeff : signed(15 downto 0); 
 signal sum_in2            : signed(31 downto 0);
 signal sum_in1,sum_out_ul : signed(15 downto 0);
 signal sum_out            : signed(15 downto 0);
 signal divider            : std_logic;
 signal audio              : signed(15 downto 0);

 signal is_noise  : std_logic;
 signal noise_rng : std_logic_vector(16 downto 0) := "00000000000000001";
 
 signal f0_z1,f0_z2 : signed(15 downto 0);
 signal f1_z1,f1_z2 : signed(15 downto 0);
 signal f2_z1,f2_z2 : signed(15 downto 0);
 signal f3_z1,f3_z2 : signed(15 downto 0);
 signal f4_z1,f4_z2 : signed(15 downto 0);
 signal f5_z1,f5_z2 : signed(15 downto 0);
  
 signal input_rdy_in     : std_logic;
 signal sound_on         : std_logic := '0';
 signal trig_allophone_r : std_logic;
 signal line_cnt, rpt_cnt, per_cnt : std_logic_vector(7 downto 0);
 
 signal coeff_idx : std_logic_vector(6 downto 0);
 
 type coeff_array_t is array(0 to  127) of integer range 0 to 511;
 signal coeff_array : coeff_array_t := (
    0,      9,      17,     25,     33,     41,     49,     57,
    65,     73,     81,     89,     97,     105,    113,    121,
    129,    137,    145,    153,    161,    169,    177,    185,
    193,    201,    209,    217,    225,    233,    241,    249,
    257,    265,    273,    281,    289,    297,    301,    305,
    309,    313,    317,    321,    325,    329,    333,    337,
    341,    345,    349,    353,    357,    361,    365,    369,
    373,    377,    381,    385,    389,    393,    397,    401,
    405,    409,    413,    417,    421,    425,    427,    429,
    431,    433,    435,    437,    439,    441,    443,    445,
    447,    449,    451,    453,    455,    457,    459,    461,
    463,    465,    467,    469,    471,    473,    475,    477,
    479,    481,    482,    483,    484,    485,    486,    487,
    488,    489,    490,    491,    492,    493,    494,    495,
    496,    497,    498,    499,    500,    501,    502,    503,
    504,    505,    506,    507,    508,    509,    510,    511);

begin

input_rdy <= input_rdy_in;
clock_750k_n <= not clock_750k;

-- stage counter : Fs=250k/25 = 10kHz
process (clock_750k, reset)
  begin
	if reset='1' then
		stage <= 0;
	else
      if rising_edge(clock_750k) then
			if stage >= 74 then 
				stage <= 0;
			else
				stage <= stage + 1;
			end if;
		end if;
	end if;
end process;

process (clock_750k, reset)
  begin
	if reset='1' then
		input_rdy_in <= '1'; 
		sound_on  <= '0';
		noise_rng <= "00000000000000001";
		bank <= "00";
	else
      if rising_edge(clock_750k) then
			
			trig_allophone_r <= trig_allophone;
			if trig_allophone_r = '0' and trig_allophone = '1' then -- detect rising edge (trig_allophone)
				input_rdy_in <= '0';
			end if;
			
			if sound_on = '0' then
			
				if stage = 0 and input_rdy_in = '0' then
				
						-- filter the bankswitch commands
				         if allophone = "1100100" then bank <= "00";
						elsif allophone = "1101000" then bank <= "01";
						elsif allophone = "1101001" then bank <= "10";
						elsif allophone = "1101010" then bank <= "11";
						elsif allophone <= "1011111" or allophone >= "1110000" then --filter the playable sounds
								allo_entry <=          allophone*"11"; -- alophone times 3
								rom_addr   <= "00000"&(allophone*"11");
								line_cnt   <= (others => '0');
								rpt_cnt    <= (others => '0');
								per_cnt    <= (others => '0');
								sound_on   <= '1';
						end if;
						
						input_rdy_in <= '1';
						
				end if;
				
			else -- sound is on	
					
				case stage is
					when 0 =>
						rom_addr <= "00000"&allo_entry;						
					when 3 =>
						allo_addr_msb <= rom_do;
						rom_addr <= rom_addr + '1';
					when 6 =>
						allo_addr_lsb <= rom_do;
						rom_addr <= rom_addr + '1';
					when 9 =>
						if rom_do = X"00" then
							line_cnt <= (others => '0');
							sound_on <= '0';
						else
							allo_nb_line <= rom_do - '1';
							rom_addr <= ((allo_addr_msb(1 downto 0) & allo_addr_lsb )+line_cnt) & X"0";
						end if;
					when 12 =>
						line_rpt <= rom_do - '1';
						rom_addr <= rom_addr + '1';
					when 15 =>
						line_amp_msb <= rom_do;
						rom_addr <= rom_addr + '1';
					when 18 =>
						
						if per_cnt = X"00" then
							amp <= signed(line_amp_msb & rom_do);
						else
							if is_noise = '1' then
								if noise_rng(0) = '1' then
									amp <= -amp;
								end if;
							else
								amp <= (others => '0');
							end if;
						end if;
						
						if per_cnt = X"00"then
							f0_z1 <= (others => '0'); f0_z2 <= (others => '0');
							f1_z1 <= (others => '0'); f1_z2 <= (others => '0');
							f2_z1 <= (others => '0'); f2_z2 <= (others => '0');
							f3_z1 <= (others => '0'); f3_z2 <= (others => '0');
							f4_z1 <= (others => '0'); f4_z2 <= (others => '0');
							f5_z1 <= (others => '0'); f5_z2 <= (others => '0');
						end if;
							
						rom_addr <= rom_addr + '1';
						
					when 21 =>
						if rom_do = X"00" then 
							line_per <= X"40";
							is_noise <= '1';
						else
							line_per <= rom_do - '1';
							is_noise <= '0';
						end if;
						sum_in1  <= amp;
						filter   <= f0_z1;
						divider  <= '0';
						rom_addr <= rom_addr + '1';
					when 24 =>
						sum_in1  <= sum_out;
						filter   <= f0_z2;
						divider  <= '1';
						rom_addr <= rom_addr + '1';
						
					when 27 =>
						f0_z1    <= sum_out;
						f0_z2    <= f0_z1;
						sum_in1  <= sum_out;
						filter   <= f1_z1;
						divider  <= '0';
						rom_addr <= rom_addr + '1';
					when 30 =>
						sum_in1  <= sum_out;
						filter   <= f1_z2;
						divider  <= '1';
						rom_addr <= rom_addr + '1';
						
					when 33 =>
						f1_z1    <= sum_out;
						f1_z2    <= f1_z1;
						sum_in1  <= sum_out;
						filter   <= f2_z1;
						divider  <= '0';
						rom_addr <= rom_addr + '1';
						
					when 36 =>
						sum_in1  <= sum_out;
						filter   <= f2_z2;
						divider  <= '1';
						rom_addr <= rom_addr + '1';
						
					when 39 =>
						f2_z1    <= sum_out;
						f2_z2    <= f2_z1;
						sum_in1  <= sum_out;
						filter   <= f3_z1;
						divider  <= '0';
						rom_addr <= rom_addr + '1';
						
					when 42 =>
						sum_in1  <= sum_out;
						filter   <= f3_z2;
						divider  <= '1';
						rom_addr <= rom_addr + '1';

					when 45 =>
						f3_z1    <= sum_out;
						f3_z2    <= f3_z1;
						sum_in1  <= sum_out;
						filter   <= f4_z1;
						divider  <= '0';
						rom_addr <= rom_addr + '1';
						
					when 48 =>
						sum_in1  <= sum_out;
						filter   <= f4_z2;
						divider  <= '1';
						rom_addr <= rom_addr + '1';

					when 51 =>
						f4_z1    <= sum_out;
						f4_z2    <= f4_z1;
						sum_in1  <= sum_out;
						filter   <= f5_z1;
						divider  <= '0';
						rom_addr <= rom_addr + '1';
						
					when 54 =>
						sum_in1  <= sum_out;
						filter   <= f5_z2;
						divider  <= '1';
						rom_addr <= rom_addr + '1';
						
					when 57 =>
						f5_z1    <= sum_out;
						f5_z2    <= f5_z1;
						
					   audio <= sum_out;
					when 60 =>					
						if per_cnt >= line_per then
							per_cnt <= (others => '0');
							if rpt_cnt >= line_rpt then
								rpt_cnt <= (others => '0');
								if line_cnt >= allo_nb_line then
									line_cnt <= (others => '0');
									sound_on <= '0';
								else
									line_cnt <= line_cnt + '1';
								end if;
								is_noise <= '0';
							else
								rpt_cnt <= rpt_cnt + '1';
							end if;
						else
							per_cnt <= per_cnt + '1';
						end if;
						
						noise_rng <= noise_rng(15 downto 0) & (noise_rng(16) xor noise_rng(2));
	
					when others => null;
				end case;
			
			end if;
	
		end if;
	end if;
end process;



audio_out <= audio;

-- filter computation
coeff_idx <= rom_do(6 downto 0) when rom_do(7)='0' else
				 not(rom_do(6 downto 0)) + '1';

coeff <= -to_signed(coeff_array(to_integer(unsigned(coeff_idx))),16) when  rom_do(7)='0' else
			 to_signed(coeff_array(to_integer(unsigned(coeff_idx))),16);

sum_in2 <= (filter * coeff) / 256 when divider = '0' else 
           (filter * coeff) / 512 ;

sum_out_ul <= sum_in1 + sum_in2(15 downto 0);

sum_out <= to_signed( 32767,16) when sum_out_ul >  32767 else
			  to_signed(-32768,16) when sum_out_ul < -32768 else
			  sum_out_ul;

			  
sp256_003 : ENTITY work.sp256_003
port map(
 clock  => clock_2m5,
 clken  => clock_750k_n,
 address => bank & rom_addr,
 q => rom_do  
);


end syn;
