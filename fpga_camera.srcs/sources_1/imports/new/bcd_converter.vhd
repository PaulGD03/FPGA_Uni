----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: FPGA-Schaltungsentwurf SS2026
--
-- Module Name: bcd_converter - Behavioral
-- Description:
--   Converts 4.8 fixed-point gain to a 2-decimal display.
--   Integer  = gain[11:8] (single digit, 0-2)
--   Fraction = gain[7:0] * 100 / 256  (2 decimal digits: tenths, hundredths)
--   4-stage pipeline, no FSM.
--
--   BCD output (24 bits, only 3 digits used):
--     bcd(19:16) = integer digit
--     bcd(15:12) = tenths
--     bcd(11:8)  = hundredths
--     rest = 0
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bcd_converter is port(
    clk   : in  std_logic;
    reset : in  std_logic;
    gain  : in  std_logic_vector(11 downto 0);
    bcd   : out std_logic_vector(23 downto 0)
);
end bcd_converter;

architecture Behavioral of bcd_converter is

    signal bcd_reg    : std_logic_vector(23 downto 0) := (others => '0');

    -- pipeline registers
    signal gain_p1    : unsigned(11 downto 0) := (others => '0');
    signal gain_p2    : unsigned(11 downto 0) := (others => '0');
    signal frac_val   : unsigned(6 downto 0)  := (others => '0');  -- gain[7:0]*100/256, 0..99
    signal frac_val_p : unsigned(6 downto 0)  := (others => '0');
    signal tenths     : unsigned(3 downto 0)  := (others => '0');
    signal hundredths : unsigned(3 downto 0)  := (others => '0');

    -- intermediate product (8-bit * 100 = 15 bits max)
    signal product : unsigned(14 downto 0) := (others => '0');

begin

    bcd <= bcd_reg;

    -- Stage 1: latch gain, compute fraction * 100
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                gain_p1 <= (others => '0');
                product <= (others => '0');
            else
                gain_p1 <= unsigned(gain);
                -- gain[7:0] * 100 + 128 (rounding: +0.5 before /256)
                -- max 255*100+128 = 25628, fits in 15 bits
                product <= unsigned(gain(7 downto 0)) * to_unsigned(100, 7)
                           + to_unsigned(128, 15);
            end if;
        end if;
    end process;

    -- Stage 2: divide by 256 (shift right 8), pipeline gain
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                gain_p2  <= (others => '0');
                frac_val <= (others => '0');
            else
                gain_p2 <= gain_p1;
                -- clamp: if product > 99*256 = 25344, cap fraction at 99
                if product > to_unsigned(25344, 15) then
                    frac_val <= to_unsigned(99, 7);
                else
                    frac_val <= product(14 downto 8);
                end if;
            end if;
        end if;
    end process;

    -- Stage 3: split into tenths and hundredths
    process(clk)
        variable f : integer range 0 to 99;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                frac_val_p <= (others => '0');
                tenths     <= (others => '0');
                hundredths <= (others => '0');
            else
                frac_val_p <= frac_val;
                f := to_integer(frac_val);
                tenths     <= to_unsigned(f / 10, 4);
                hundredths <= to_unsigned(f mod 10, 4);
            end if;
        end if;
    end process;

    -- Stage 4: assemble BCD output
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                bcd_reg <= (others => '0');
            else
                bcd_reg(23 downto 20) <= (others => '0');
                bcd_reg(19 downto 16) <= std_logic_vector(gain_p2(11 downto 8));
                bcd_reg(15 downto 12) <= std_logic_vector(tenths);
                bcd_reg(11 downto 8)  <= std_logic_vector(hundredths);
                bcd_reg(7 downto 0)   <= (others => '0');
            end if;
        end if;
    end process;

end Behavioral;
