library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.textio.all;

use work.fft_pkg.all;

entity TB_continuous is
end entity;

architecture SIM of TB_continuous is

	constant CLK_PERIOD : time := 20 ns;
	constant logN : integer := 12; -- 4096 FFT
	constant N : integer := 2**logN;
	
	constant MODE_FFT : std_logic := '1'; -- 1 = FFT
	
	signal CLK : std_logic := '0';
	signal RST : std_logic := '1';
	
	
	
	constant STEP_0 : integer := 512;
	constant STEP_1 : integer := 77;
	constant STEP_2 : integer := 800;
	constant STEP_3 : integer := -213;	
	
	
	signal FFT_VALID_IN : std_logic := '0';
	
	signal FFT_VALID_OUT : std_logic;
	
	signal FFT_INPUT_RE : std_logic_vector(31 downto 0);
	signal FFT_INPUT_IM : std_logic_vector(31 downto 0);
	
	signal FFT_OUTPUT_RE : std_logic_vector(31 downto 0);
	signal FFT_OUTPUT_IM : std_logic_vector(31 downto 0);
	
	
	file outfile : text open write_mode is "testbenches/continuous.txt";
	
	
	signal BIN_INDEX : integer := 0;
	
	
	signal FRAME_ID : integer := 0;
	
	signal i : integer := 0;
	
begin
	
	


	 
	-- Generate Device Under Test
	-- FFT
	DUT1 : entity work.FFT
		generic map(
			logN => logN,
			MODE => MODE_FFT
		)
		port map(
			CLK => CLK,
			RST => RST,
			VALID_IN => FFT_VALID_IN,
			VALID_OUT => FFT_VALID_OUT,
			INPUT_RE => FFT_INPUT_RE,
			INPUT_IM => FFT_INPUT_IM,
			OUTPUT_RE => FFT_OUTPUT_RE,
			OUTPUT_IM => FFT_OUTPUT_IM
		);	
		
		-- Clock Generation
		
		CLK <= not CLK after CLK_PERIOD/2;
		
		-- Reset, run once at the beginning
		
		reset_process : process
		begin
			RST <= '1';
			wait for 5 * CLK_PERIOD;
			RST <= '0';
			wait; -- never ends the process
		end process;
		
		-- Stimulation
		
		stim : process(CLK)
			constant N : integer := 2**logN;
			variable INDEX_0 : integer := 0;
			variable INDEX_1 : integer := 0;
			variable INDEX_2 : integer := 0;
			variable INDEX_3 : integer := 0;
			variable Y1 : complex_S32;
			variable Y2 : complex_S32;
			variable Y3 : complex_S32;
			
		begin

			if rising_edge(CLK) then
				if (RST = '0') then
					-- IMPULSE TEST
					-- X[0] = 0.5
					-- X[i > 0] = 0
					if (i < N) then
						
						FFT_VALID_IN <= '1';

						if (i = 0) then		
							FFT_INPUT_RE <= (14 => '1', others => '0'); -- 0.5 in Q1.15
							FFT_INPUT_IM <= (14 => '1', others => '0');
						else
							FFT_INPUT_RE <= (others => '0'); -- 0.5 in Q1.15
							FFT_INPUT_IM <= (others => '0');
						end if;
						
					-- DC TEST
					-- X[i] = 0.5
					elsif (i < 2*N) then
					
						FFT_VALID_IN <= '1';
						
						FFT_INPUT_RE <= (14 => '1', others => '0'); -- 0.5 in Q1.15
						FFT_INPUT_IM <= (14 => '1', others => '0');
					
					-- SINGLE TONE TEST
					-- F = 50 MHz * 512/4096 = 6.25 MHz
					elsif (i < 3*N) then
					
						FFT_VALID_IN <= '1';
						
						FFT_INPUT_RE <= std_logic_vector(resize(signed(COS_LUT((STEP_0 * i) mod 4096)),32));
						FFT_INPUT_IM <= std_logic_vector(resize(signed(SIN_LUT((STEP_0 * i) mod 4096)),32));
						
					-- THREE TONE TEST
					-- F1 = 50 MHz * 77/4096 = 940 kHz
					-- F2 = 50 MHz * 800/4096 = 9.77 MHz
					-- F3 = 50 MHz * -213/4096 = -2.6 MHz
					elsif (i < 4*N) then
						
						Y1.re := resize(signed(COS_LUT((STEP_1*i) mod N)),32);
						Y1.im := resize(signed(SIN_LUT((STEP_1*i) mod N)),32);
						
						Y2.re := resize(signed(COS_LUT((STEP_2*i) mod N)),32);
						Y2.im := resize(signed(SIN_LUT((STEP_2*i) mod N)),32);
						
						Y3.re := resize(signed(COS_LUT((STEP_3*i) mod N)),32);
						Y3.im := resize(signed(SIN_LUT((STEP_3*i) mod N)),32);
						
						
						FFT_VALID_IN <= '1';
						
						FFT_INPUT_RE <= std_logic_vector(Y1.re + Y2.re + Y3.re);
						FFT_INPUT_IM <= std_logic_vector(Y1.im + Y2.im + Y3.im);
						
					else
						FFT_VALID_IN <= '0';
						FFT_INPUT_RE <= (others => '0');
						FFT_INPUT_IM <= (others => '0');
						
					end if;
					i <= i + 1;
				else
					
					FFT_VALID_IN <= '0';
					
					FFT_INPUT_RE <= (others => '0');
					FFT_INPUT_IM <= (others => '0');					
					
				end if;
			end if;
		end process;
		
		-- Write output to file
		
		capture : process(CLK)
			variable L : line;
		begin
			if rising_edge(CLK) then
				if RST = '1' then
					BIN_INDEX <= 0;
				else
					if FFT_VALID_OUT = '1' then
						write(L, integer'image(FRAME_ID));
						write(L, string'(", "));
						write(L, integer'image(BIN_INDEX));
						write(L, string'(", "));
						write(L, integer'image(to_integer(signed(FFT_OUTPUT_RE))));
						write(L, string'(", "));
						write(L, integer'image(to_integer(signed(FFT_OUTPUT_IM))));
						writeline(outfile, L);
						
						if (BIN_INDEX = N-1) then
							BIN_INDEX <= 0;
							FRAME_ID <= FRAME_ID + 1;
						else
							BIN_INDEX <= BIN_INDEX + 1;
						end if;
					end if;
				end if;
			end if;
		end process;
end SIM;