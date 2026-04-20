library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.textio.all;

use work.fft_pkg.all;

entity TB_inverting is
end entity;

architecture SIM of TB_inverting is

	constant CLK_PERIOD : time := 20 ns;
	constant logN : integer := 10; -- 1024 FFT
	constant N : integer := 2**logN;
	
	signal CLK : std_logic := '0';
	signal RST : std_logic := '1';
	
	signal MODE_0 : std_logic := '0';
	signal MODE_1 : std_logic := '1'; -- 1 = FFT
	
	
	signal VALID_IN : std_logic := '0';
	signal VALID_OUT : std_logic;
	signal MIDDLE_VALID : std_logic;
	
	signal INPUT_RE : std_logic_vector(31 downto 0);
	signal INPUT_IM : std_logic_vector(31 downto 0);
	
	signal OUTPUT_RE : std_logic_vector(31 downto 0);
	signal OUTPUT_IM : std_logic_vector(31 downto 0);
	
	signal MIDDLE_RE : std_logic_vector(31 downto 0);
	signal MIDDLE_IM : std_logic_vector(31 downto 0);
	
	type ram_N is array (0 to N-1) of word64;

	signal RAM : ram_N;
	
	file outfile : text open write_mode is "inverting.txt";
	
	-- Frequency of single tone is
	-- FREQ = CLK_FREQ * STEP/N
	-- CLK_FREQ is 50MHz
	-- Step size required for desired single-tone frequency is then
	-- STEP = N*FREQ/FREQ_CLK
	-- STEP must be an integer, so we can only do integer div of CLK_FREQ
	-- Multitone signal is then just sum of several single tone signals
	
	constant STEP_1 : integer := 12; -- FREQ = 50MHz*(16/1024) = 586kHz
	constant STEP_2 : integer := 205; -- FREQ = 50MHz*(256/1024) = 10MHz
	constant STEP_3 : integer := -45; -- FREQ = 50MHz*(-128/1024) = -2.2MHz. Adding N for mod safety
	constant INDEX_SCALING : integer := LUT_SIZE/N; -- Scaling the indexing to fit correctly
	
	signal BIN_INDEX : integer := 0;
	signal i : integer := 0;
	
begin
	
	
	
	 assert (LUT_SIZE mod N = 0)
    report "Single-tone testbench requires LUT_SIZE divisible by N"
    severity failure;

	 
	-- Generate Device Under Test
	-- FFT
	DUT1 : entity work.FFT
		generic map(
			logN => logN
		)
		port map(
			CLK => CLK,
			RST => RST,
			MODE => MODE_1,
			VALID_IN => VALID_IN,
			VALID_OUT => MIDDLE_VALID,
			INPUT_RE => INPUT_RE,
			INPUT_IM => INPUT_IM,
			OUTPUT_RE => MIDDLE_RE,
			OUTPUT_IM => MIDDLE_IM
		);	
	--IFFT
	DUT2 : entity work.FFT
		generic map(
			logN => logN
		)
		port map(
			CLK => CLK,
			RST => RST,
			MODE => MODE_0,
			VALID_IN => MIDDLE_VALID,
			VALID_OUT => VALID_OUT,
			INPUT_RE => MIDDLE_RE,
			INPUT_IM => MIDDLE_IM,
			OUTPUT_RE => OUTPUT_RE,
			OUTPUT_IM => OUTPUT_IM
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
			variable INDEX_1 : integer := 0;
			variable INDEX_2 : integer := 0;
			variable INDEX_3 : integer := 0;
			variable Y1 : complex_S32;
			variable Y2 : complex_S32;
			variable Y3 : complex_S32;
			
		begin

			if rising_edge(CLK) then
				if (RST = '0') then
					if (i < N) then
						INDEX_1 := ((STEP_1*i) mod N) * INDEX_SCALING;
						
						INDEX_2 := ((STEP_2*i) mod N) * INDEX_SCALING;
						
						INDEX_3 := ((STEP_3*i) mod N) * INDEX_SCALING;
						
						-- Note the scaling
						-- We have to make sure |x[k]| <= 1 for all k
						
						Y1.re := resize(signed(COS_LUT(INDEX_1)),32) sra 3;
						Y1.im := resize(signed(SIN_LUT(INDEX_1)),32) sra 3;
						
						Y2.re := resize(signed(COS_LUT(INDEX_2)),32) sra 3;
						Y2.im := resize(signed(SIN_LUT(INDEX_2)),32) sra 3;
						
						Y3.re := resize(signed(COS_LUT(INDEX_3)),32) sra 3;
						Y3.im := resize(signed(SIN_LUT(INDEX_3)),32) sra 3;
						
						
						VALID_IN <= '1';
						INPUT_RE <= std_logic_vector(Y1.re + Y2.re + Y3.re);
						INPUT_IM <= std_logic_vector(Y1.im + Y2.im + Y3.im);
						i <= i + 1;
					else
						VALID_IN <= '0';
						INPUT_RE <= (others => '0');
						INPUT_IM <= (others => '0');
					end if;
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
					if VALID_OUT = '1' then
						write(L, integer'image(BIN_INDEX));
						write(L, string'(", "));
						write(L, integer'image(to_integer(signed(output_re))));
						write(L, string'(", "));
						write(L, integer'image(to_integer(signed(output_im))));
						writeline(outfile, L);
						BIN_INDEX <= (BIN_INDEX + 1) mod N;
					end if;
				end if;
			end if;
		end process;
end SIM;