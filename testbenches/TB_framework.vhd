library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library std;
use std.textio.all;

use work.fft_pkg.all;

entity TB is
	generic (
		logN : integer := 12;
		FFT_MODE : std_logic := '1'; -- 1 = FFT

		PRINT_INVALID : std_logic := '0';

		INPUT_FILE : string := "samples.txt";
		OUTPUT_FILE : string := "results.txt"
	);
end entity;

architecture SIM of TB is

	constant N : integer := 2 ** logN;

	constant CLK_PERIOD : time := 20 ns; -- 50 MHz
	signal CLK : std_logic := '0';
	signal RST : std_logic := '1';

	signal VALID_IN : std_logic := '0';

	signal VALID_OUT : std_logic;

	signal INPUT_RE : std_logic_vector(31 downto 0);
	signal INPUT_IM : std_logic_vector(31 downto 0);

	signal OUTPUT_RE : std_logic_vector(31 downto 0);
	signal OUTPUT_IM : std_logic_vector(31 downto 0);
	file out_file : text open write_mode is OUTPUT_FILE;

	file in_file : text open read_mode is INPUT_FILE;

begin

	-- Generate Device Under Test
	-- FFT
	DUT : entity work.FFT
		generic map(
			logN => logN,
			MODE => FFT_MODE
		)
		port map(
			CLK => CLK,
			RST => RST,
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

	stim : process
		variable L : line;

		variable RE_VALUE : integer;
		variable IM_VALUE : integer;
		variable VALID_VALUE : integer;

		variable comma : character;
	begin

		wait until RST = '0';

		while not endfile(in_file) loop
			readline(in_file, L);

			read(L, RE_VALUE);
			read(L, comma);

			read(L, IM_VALUE);
			read(L, comma);

			read(L, VALID_VALUE);

			wait until falling_edge(CLK);

			INPUT_RE <= std_logic_vector(to_signed(RE_VALUE, INPUT_RE'length));
			INPUT_IM <= std_logic_vector(to_signed(IM_VALUE, INPUT_IM'length));

			VALID_IN <= to_signed(VALID_VALUE, 1)(0);

		end loop;

		wait until falling_edge(CLK);
		VALID_IN <= '0';

		wait;
	end process;

	-- Write output to file

	capture : process (CLK)
		variable L : line;
	begin
		if rising_edge(CLK) then
			if (VALID_OUT = '1') then
				write(L, integer'image(to_integer(signed(OUTPUT_RE))));
				write(L, string'(","));
				write(L, integer'image(to_integer(signed(OUTPUT_IM))));
				write(L, string'(","));
				write(L, 1);
			elsif (PRINT_INVALID = '1') then
				write(L, 0);
				write(L, string'(","));
				write(L, 0);
				write(L, string'(","));
				write(L, 0);
			end if;
			writeline(out_file, L);
		end if;
	end process;
end SIM;