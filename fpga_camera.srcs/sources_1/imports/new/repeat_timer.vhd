----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: FPGA-Schaltungsentwurf SS2026
--
-- Module Name: repeat_timer - Behavioral
-- Beschreibung:
--   Auto-Repeat Timer mit grosszügiger Totzone für saubere
--   Kurzdrück-/Halte-Unterscheidung.
--   Bei 'pressed': feuert einen sofortigen Tick, wartet dann DEAD_ZONE_CYCLES
--   (500 ms bei 50 MHz) mit KEINEN Ticks. Nach der Totzone feuert es Ticks im
--   REPEAT_CYCLES Intervall (200 ms = 5 Hz).
--   Wenn 'released' zu irgendeinem Zeitpunkt kommt, geht es sofort zurück zu IDLE.
--   Ein kurzes Antippen (< 500 ms) erzeugt genau 1 Tick.
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

    -- bei 50 MHz: 25.000.000 = 500 ms Totzone, 10.000.000 = 200 ms Wiederhohlung (5 Hz)
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
                            tick  <= '1';      -- einzelner Antipp-Tick
                            state <= DEAD_ZONE;
                        end if;

                    when DEAD_ZONE =>
                        if released = '1' then
                            state   <= IDLE;
                            counter <= 0;
                        elsif counter = DEAD_ZONE_CYCLES - 1 then
                            -- Totzone abgelaufen, beginne Wiederhohlung (kein Tick hier)
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
