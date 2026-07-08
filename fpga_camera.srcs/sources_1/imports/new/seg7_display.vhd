----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: FPGA-Schaltungsentwurf SS2026
--
-- Module Name: seg7_display - Behavioral
-- Beschreibung:
--   7-Segment Anzeige für Nexys4 DDR (common-anode, active-low Kathoden/Anoden).
--   Layout (AN7 ganz links .. AN0 ganz rechts):
--     AN7: Kanalbuchstabe (r, g, b)
--     AN6..AN3: Aus (komplett aus)
--     AN2: Ganzzahl-Ziffer + Dezimalpunkt
--     AN1: Zehntel
--     AN0: Hunderstel
--   Ergebnis: "r    1.00"
--   CA-Bits: [7]=DP, [6]=G, [5]=F, [4]=E, [3]=D, [2]=C, [1]=B, [0]=A
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity seg7_display is port(
    clk         : in  std_logic;
    reset       : in  std_logic;
    bcd         : in  std_logic_vector(23 downto 0);
    channel_sel : in  std_logic_vector(2 downto 0);   -- "100"=R, "010"=G, "001"=B
    sseg_ca     : out std_logic_vector(7 downto 0);   -- Kathoden (active low)
    sseg_an     : out std_logic_vector(7 downto 0)    -- Anoden  (active low)
);
end seg7_display;

architecture Behavioral of seg7_display is

    signal scan_cnt : unsigned(14 downto 0) := (others => '0');
    signal digit_sel : std_logic_vector(2 downto 0);

    -- Segmentmuster: '1' = Segment leuchtet
    signal seg_pattern : std_logic_vector(7 downto 0);

    -- Hilfsfunktion: wandelt 4-bit Nibble (0-9 gültig, sonst -> aus) in 7-Seg
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
            when others => return "00000000"; -- aus
        end case;
    end function;

begin

    -- Scan-Zähler
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
    -- Segmentmuster und Anodenauswahl (kombinatorisch)
    -----------------------------------------------------------
    process(digit_sel, bcd, channel_sel)
    begin
        -- default: Ziffer aus
        seg_pattern <= (others => '0');
        sseg_an     <= (others => '1');  -- alle Anoden aus

        case digit_sel is

            -- AN7: Kanalbuchstabe
            when "111" =>
                sseg_an <= "01111111";
                case channel_sel is
                    when "100"  => seg_pattern <= "01010000"; -- r (E,G)
                    when "010"  => seg_pattern <= "01111101"; -- g (A,C,D,E,F,G)
                    when "001"  => seg_pattern <= "01111100"; -- b (C,D,E,F,G)
                    when others => seg_pattern <= (others => '0');
                end case;

            -- AN6..AN3: aus
            when "110" | "101" | "100" | "011" =>
                null;  -- bleibt aus

            -- AN2: Ganzzahl + DP
            when "010" =>
                sseg_an     <= "11111011";
                seg_pattern <= seg7(bcd(19 downto 16));
                seg_pattern(7) <= '1';  -- DP an

            -- AN1: Zehntel
            when "001" =>
                sseg_an     <= "11111101";
                seg_pattern <= seg7(bcd(15 downto 12));

            -- AN0: Hunderstel
            when "000" =>
                sseg_an     <= "11111110";
                seg_pattern <= seg7(bcd(11 downto 8));

            when others =>
                null;

        end case;
    end process;

    -- Kathoden: active-low = Muster invertieren
    sseg_ca <= not seg_pattern;

end Behavioral;
