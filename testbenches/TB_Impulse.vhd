library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.textio.all;

use work.fft_pkg.all;

entity TB_Impulse is
end entity;

architecture SIM of TB_Impulse is

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
	
	file outfile : text open write_mode is "impulse_out.txt";

	signal BIN_INDEX : integer := 0;
	
	signal i : integer := 0;
	
begin
	
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
		begin
			
			if rising_edge(CLK) then
				
			-- Impulse test
			-- x[0] = 0.5, x[i > 0] = 0
				if (RST = '0') then
					if (i = 0) then
						VALID_IN <= '1';
						INPUT_RE <= (30 => '1', others => '0'); -- 0.5 in Q1.31
						INPUT_IM <= (others => '0');
						i <= i + 1;
					elsif (i < N) then
						INPUT_RE <= (others => '0');
						INPUT_IM <= (others => '0');
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