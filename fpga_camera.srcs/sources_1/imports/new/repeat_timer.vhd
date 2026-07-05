----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: FPGA-Schaltungsentwurf SS2026
--
-- Module Name: repeat_timer - Behavioral
-- Description:
--   Auto-repeat timer with generous dead zone for clean tap vs. hold detection.
--   On 'pressed': fires one immediate tick, then waits DEAD_ZONE_CYCLES
--   (500 ms at 50 MHz) with NO ticks. After the dead zone, fires ticks at
--   REPEAT_CYCLES intervals (200 ms = 5 Hz).
--   If 'released' at any point, returns to IDLE immediately.
--   A quick tap (< 500 ms) produces exactly 1 tick.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity repeat_timer is port(
    clk      : in  std_logic;
    reset    : in  std_logic;
    pressed  : in  std_logic;
    released : in  std_logic;
    tick     : out std_logic
);
end repeat_timer;

architecture Behavioral of repeat_timer is

    -- at 50 MHz: 25,000,000 = 500 ms dead zone, 10,000,000 = 200 ms repeat (5 Hz)
    constant DEAD_ZONE_CYCLES : integer := 25000000;
    constant REPEAT_CYCLES    : integer := 10000000;

    type timer_state is (IDLE, DEAD_ZONE, REPEAT);
    signal state   : timer_state := IDLE;
    signal counter : integer range 0 to DEAD_ZONE_CYCLES - 1 := 0;

begin

    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then
                state   <= IDLE;
                counter <= 0;
                tick    <= '0';
            else
                tick <= '0';  -- default

                case state is

                    when IDLE =>
                        counter <= 0;
                        if pressed = '1' then
                            tick  <= '1';      -- single tap tick
                            state <= DEAD_ZONE;
                        end if;

                    when DEAD_ZONE =>
                        if released = '1' then
                            state   <= IDLE;
                            counter <= 0;
                        elsif counter = DEAD_ZONE_CYCLES - 1 then
                            -- dead zone elapsed, begin repeat (no tick here)
                            counter <= 0;
                            state   <= REPEAT;
                        else
                            counter <= counter + 1;
                        end if;

                    when REPEAT =>
                        if released = '1' then
                            state   <= IDLE;
                            counter <= 0;
                        elsif counter = REPEAT_CYCLES - 1 then
                            tick    <= '1';
                            counter <= 0;
                        else
                            counter <= counter + 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
