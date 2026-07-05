----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: FPGA-Schaltungsentwurf SS2026
--
-- Module Name: channel_select - Behavioral
-- Description:
--   RGB channel selector with bidirectional cycling.
--   Advances forward (R->G->B->R) or backward (R->B->G->R) on each tick,
--   depending on the 'dir' input.
--   Uses an integer state (0/1/2) internally and provides both a
--   one-hot encoded output and a binary encoded index output.
--   Reset sets the active channel to Red (index "00").
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity channel_select is port(
    clk         : in  std_logic;
    reset       : in  std_logic;
    tick        : in  std_logic;     -- 1-cycle pulse to advance channel
    dir         : in  std_logic;     -- '1' = forward (R->G->B), '0' = backward (R->B->G)
    channel_idx : out std_logic_vector(1 downto 0);  -- "00"=R, "01"=G, "10"=B
    channel_sel : out std_logic_vector(2 downto 0)   -- one-hot: "100"=R, "010"=G, "001"=B
);
end channel_select;

architecture Behavioral of channel_select is

    signal channel : integer range 0 to 2 := 0;

begin

    -- channel advance on tick (bidirectional)
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                channel <= 0;  -- default to Red
            elsif tick = '1' then
                if dir = '1' then
                    -- forward: R(0) -> G(1) -> B(2) -> R(0) ...
                    if channel = 2 then
                        channel <= 0;
                    else
                        channel <= channel + 1;
                    end if;
                else
                    -- backward: R(0) -> B(2) -> G(1) -> R(0) ...
                    if channel = 0 then
                        channel <= 2;
                    else
                        channel <= channel - 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- drive binary encoded index output
    channel_idx <= "00" when channel = 0 else
                   "01" when channel = 1 else
                   "10";  -- channel = 2 (Blue)

    -- combinational one-hot decode
    channel_sel <= "100" when channel = 0 else
                   "010" when channel = 1 else
                   "001";  -- channel = 2 (Blue)

end Behavioral;
