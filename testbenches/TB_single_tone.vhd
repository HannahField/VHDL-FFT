library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.textio.all;

use work.fft_pkg.all;

entity TB_single_tone is
end entity;

architecture SIM of TB_single_tone is

	constant CLK_PERIOD : time := 20 ns;
	constant logN : integer := 10; -- 1024 FFT
	constant N : integer := 2**logN;
	
	signal CLK : std_logic := '0';
	signal RST : std_logic := '1';
	
	signal MODE : std_logic := '1'; -- 1 = FFT
	
	signal VALID_IN : std_logic := '0';
	signal VALID_OUT : std_logic;
	
	signal INPUT_RE : std_logic_vector(31 downto 0);
	signal INPUT_IM : std_logic_vector(31 downto 0);
	
	signal OUTPUT_RE : std_logic_vector(31 downto 0);
	signal OUTPUT_IM : std_logic_vector(31 downto 0);
	
	file outfile : text open write_mode is "single_tone_out.txt";
	
	-- Frequency of single tone is
	-- FREQ = CLK_FREQ * STEP/N
	-- CLK_FREQ is 50MHz
	-- Step size required for desired single-tone frequency is then
	-- STEP = N*FREQ/FREQ_CLK
	-- STEP must be an integer, so we can only do integer div of CLK_FREQ
	
	constant STEP : integer:= 37; 
	constant INDEX_SCALING : integer := (LUT_SIZE/N); -- Scaling the indexing to fit correctly
	
	signal BIN_INDEX : integer := 0;
	
	signal i : integer := 0;
	
begin
	
	
	
	 assert (LUT_SIZE mod N = 0)
    report "Single-tone testbench requires LUT_SIZE divisible by N"
    severity failure;

	 
	-- Generate Device Under Test
	
	DUT : entity work.FFT
		generic map(
			logN => logN
		)
		port map(
			CLK => CLK,
			RST => RST,
			MODE => MODE,
			VALID_IN => VALID_IN,
			VALID_OUT => VALID_OUT,
			INPUT_RE => INPUT_RE,
			INPUT_IM => INPUT_IM,
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
			variable INDEX : integer := 0;
		begin
			
			if rising_edge(CLK) then
				if (RST = '0') then
					if (i < N) then
						INDEX := ((STEP*i) mod N) * INDEX_SCALING;
						VALID_IN <= '1';
						INPUT_RE <= std_logic_vector(resize(signed(COS_LUT(INDEX)),32));
						INPUT_IM <= std_logic_vector(resize(signed(SIN_LUT(INDEX)),32));
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