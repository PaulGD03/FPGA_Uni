----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: FPGA-Schaltungsentwurf SS2026
--
-- Module Name: gain_adjust - Behavioral
-- Description:
--   Per-channel white balance gain controller.
--   Internal 4.8 fixed-point storage. Step sizes are decimal-friendly:
--     "00" =   3 (~0.01, tap)
--     "01" =  26 (~0.10, short hold)
--     "10" = 256 (~1.00, long hold)
--   Bounds: MIN_GAIN=2 (~0.01), MAX_GAIN=767 (~3.00)
--   Reset = neutral (256 = 1.00).
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity gain_adjust is port(
    clk         : in  std_logic;
    reset       : in  std_logic;
    tick        : in  std_logic;
    inc_not_dec : in  std_logic;
    step_sel    : in  std_logic_vector(1 downto 0); -- "00"=0.01, "01"=0.10, "10"/"11"=1.00
    gain        : out std_logic_vector(11 downto 0)
);
end gain_adjust;

architecture Behavioral of gain_adjust is

    constant NEUTRAL  : unsigned(11 downto 0) := "000100000000";  -- 256 = 1.00
    constant MIN_GAIN : unsigned(11 downto 0) := "000000000010";  --   2
    constant MAX_GAIN : unsigned(11 downto 0) := "001011111111";  -- 767

    signal r_gain : unsigned(11 downto 0) := NEUTRAL;

begin

    process(clk)
        variable v_gain : unsigned(11 downto 0);
        variable step   : unsigned(11 downto 0);
    begin
        if rising_edge(clk) then
            v_gain := r_gain;

            -- decode step size
            case step_sel is
                when "00"   => step := to_unsigned(3, 12);    -- ~0.01
                when "01"   => step := to_unsigned(26, 12);   -- ~0.10
                when others => step := to_unsigned(256, 12);  -- ~1.00
            end case;

            if reset = '1' then
                v_gain := NEUTRAL;
            elsif tick = '1' then
                if inc_not_dec = '1' then
                    if v_gain <= MAX_GAIN - step then
                        v_gain := v_gain + step;
                    else
                        v_gain := MAX_GAIN;
                    end if;
                else
                    if v_gain >= MIN_GAIN + step then
                        v_gain := v_gain - step;
                    else
                        v_gain := MIN_GAIN;
                    end if;
                end if;
            end if;

            r_gain <= v_gain;
        end if;
    end process;

    gain <= std_logic_vector(r_gain);

end Behavioral;
