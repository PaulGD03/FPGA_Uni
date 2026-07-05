----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: FPGA-Schaltungsentwurf SS2026
--
-- Module Name: debounce - Behavioral
-- Description:
--   Button debouncer using a saturation counter.
--   Counts up by 1 when btn_in is high, down by 2 when btn_in is low.
--   Saturates at 0 and DEBOUNCE_LIMIT (50000 = 1 ms at 50 MHz).
--   Asserts 'pressed' for one cycle when counter reaches the upper threshold
--   and the debounced state transitions from released to pressed.
--   Asserts 'released' for one cycle when counter reaches 0 and the
--   debounced state transitions from pressed to released.
--   The asymmetric count (up 1 / down 2) biases toward the released state
--   for improved noise immunity with mechanical buttons.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity debounce is port(
    clk      : in  std_logic;
    btn_in   : in  std_logic;     -- raw button input (active high)
    pressed  : out std_logic;     -- 1-cycle pulse on press detection
    released : out std_logic      -- 1-cycle pulse on release detection
);
end debounce;

architecture Behavioral of debounce is

    -- debounce threshold: 50000 cycles = 1 ms at 50 MHz
    constant DEBOUNCE_LIMIT : integer := 50000;

    -- saturation counter, range 0 to DEBOUNCE_LIMIT
    signal counter    : integer range 0 to DEBOUNCE_LIMIT := 0;

    -- debounced button state: '0' = not pressed, '1' = pressed
    signal btn_state  : std_logic := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then

            -- default: no edge events
            pressed  <= '0';
            released <= '0';

            -- saturation counter logic
            if btn_in = '1' then
                if counter < DEBOUNCE_LIMIT then
                    counter <= counter + 1;
                end if;
            else  -- btn_in = '0'
                if counter > 1 then
                    counter <= counter - 2;
                elsif counter > 0 then
                    counter <= 0;  -- clamp to 0
                end if;
            end if;

            -- state transitions based on counter thresholds
            if counter = DEBOUNCE_LIMIT and btn_state = '0' then
                -- button has been stable high long enough: register press
                btn_state <= '1';
                pressed   <= '1';
            elsif counter = 0 and btn_state = '1' then
                -- button has been stable low long enough: register release
                btn_state <= '0';
                released  <= '1';
            end if;

        end if;
    end process;

end Behavioral;
