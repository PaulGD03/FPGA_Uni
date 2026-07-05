----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: FPGA-Schaltungsentwurf SS2026
--
-- Module Name: seg7_display - Behavioral
-- Description:
--   7-segment display for Nexys4 DDR (common-anode, active-low cathodes/anodes).
--   Layout (AN7 leftmost .. AN0 rightmost):
--     AN7: Channel letter (r, g, b)
--     AN6..AN3: Blank (fully off)
--     AN2: Integer digit + decimal point
--     AN1: Tenths
--     AN0: Hundredths
--   Result: "r    1.00"
--   CA bits: [7]=DP, [6]=G, [5]=F, [4]=E, [3]=D, [2]=C, [1]=B, [0]=A
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity seg7_display is port(
    clk         : in  std_logic;
    reset       : in  std_logic;
    bcd         : in  std_logic_vector(23 downto 0);
    channel_sel : in  std_logic_vector(2 downto 0);   -- "100"=R, "010"=G, "001"=B
    sseg_ca     : out std_logic_vector(7 downto 0);   -- cathodes (active low)
    sseg_an     : out std_logic_vector(7 downto 0)    -- anodes  (active low)
);
end seg7_display;

architecture Behavioral of seg7_display is

    signal scan_cnt : unsigned(14 downto 0) := (others => '0');
    signal digit_sel : std_logic_vector(2 downto 0);

    -- segment pattern: '1' = segment lit
    signal seg_pattern : std_logic_vector(7 downto 0);

    -- helper: converts a 4-bit nibble (0-9 valid, others => blank) to 7-seg
    function seg7(nibble : std_logic_vector(3 downto 0)) return std_logic_vector is
    begin
        case nibble is
            when "0000" => return "00111111"; -- 0
            when "0001" => return "00000110"; -- 1
            when "0010" => return "01011011"; -- 2
            when "0011" => return "01001111"; -- 3
            when "0100" => return "01100110"; -- 4
            when "0101" => return "01101101"; -- 5
            when "0110" => return "01111101"; -- 6
            when "0111" => return "00000111"; -- 7
            when "1000" => return "01111111"; -- 8
            when "1001" => return "01101111"; -- 9
            when others => return "00000000"; -- blank
        end case;
    end function;

begin

    -- scan counter
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                scan_cnt <= (others => '0');
            else
                scan_cnt <= scan_cnt + 1;
            end if;
        end if;
    end process;

    digit_sel <= std_logic_vector(scan_cnt(14 downto 12));

    -----------------------------------------------------------
    -- Segment pattern and anode selection (combinational)
    -----------------------------------------------------------
    process(digit_sel, bcd, channel_sel)
    begin
        -- default: digit off
        seg_pattern <= (others => '0');
        sseg_an     <= (others => '1');  -- all anodes off

        case digit_sel is

            -- AN7: channel letter
            when "111" =>
                sseg_an <= "01111111";
                case channel_sel is
                    when "100"  => seg_pattern <= "01010000"; -- r (E,G)
                    when "010"  => seg_pattern <= "01111101"; -- g (A,C,D,E,F,G)
                    when "001"  => seg_pattern <= "01111100"; -- b (C,D,E,F,G)
                    when others => seg_pattern <= (others => '0');
                end case;

            -- AN6..AN3: blank
            when "110" | "101" | "100" | "011" =>
                null;  -- stays off

            -- AN2: integer + DP
            when "010" =>
                sseg_an     <= "11111011";
                seg_pattern <= seg7(bcd(19 downto 16));
                seg_pattern(7) <= '1';  -- DP on

            -- AN1: tenths
            when "001" =>
                sseg_an     <= "11111101";
                seg_pattern <= seg7(bcd(15 downto 12));

            -- AN0: hundredths
            when "000" =>
                sseg_an     <= "11111110";
                seg_pattern <= seg7(bcd(11 downto 8));

            when others =>
                null;

        end case;
    end process;

    -- cathodes: active-low = invert pattern
    sseg_ca <= not seg_pattern;

end Behavioral;
