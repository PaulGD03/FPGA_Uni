----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: FPGA-Schaltungsentwurf SS2026
--
-- Module Name: debounce - Behavioral
-- Beschreibung:
--   Tasten-Debouncer mit Sättigungszähler.
--   Zählt um 1 hoch wenn btn_in high ist, um 2 runter wenn btn_in low ist.
--   Sättigt bei 0 und DEBOUNCE_LIMIT (50000 = 1 ms bei 50 MHz).
--   Setzt 'pressed' für einen Taktzyklus wenn der Zähler die obere Schwelle
--   errreicht und der debouncte Zustand von released nach pressed wechselt.
--   Setzt 'released' für einen Taktzyklus wenn der Zähler 0 errreicht und
--   der debouncte Zustand von pressed nach released wechselt.
--   Die asymmetrische Zählung (hoch 1 / runter 2) bevorzugt den released-
--   Zustand für bessere Störsicherheit bei mechanischen Tastern.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity debounce is port(
    clk      : in  std_logic;
    btn_in   : in  std_logic;     -- roher Tasteneingang (active high)
    pressed  : out std_logic;     -- 1-Takt Puls bei Druckerkennung
    released : out std_logic      -- 1-Takt Puls bei Loslasser-kennung
);
end debounce;

architecture Behavioral of debounce is

    -- Debounce-Schwelle: 50000 Takte = 1 ms bei 50 MHz
    constant DEBOUNCE_LIMIT : integer := 50000;

    -- Sättigungszähler, Bereich 0 bis DEBOUNCE_LIMIT
    signal counter    : integer range 0 to DEBOUNCE_LIMIT := 0;

    -- debouncter Tastenzustand: '0' = nicht gedrückt, '1' = gedrückt
    signal btn_state  : std_logic := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then

            -- default: keine Flankenereignisse
            pressed  <= '0';
            released <= '0';

            -- Sättigungszähler-Logik
            if btn_in = '1' then
                if counter < DEBOUNCE_LIMIT then
                    counter <= counter + 1;
                end if;
            else  -- btn_in = '0'
                if counter > 1 then
                    counter <= counter - 2;
                elsif counter > 0 then
                    counter <= 0;  -- auf 0 klemmen
                end if;
            end if;

            -- Zustandsübergänge basierend auf Zählerschwellen
            if counter = DEBOUNCE_LIMIT and btn_state = '0' then
                -- Taste war lange genug stabil high: Druck registrieren
                btn_state <= '1';
                pressed   <= '1';
            elsif counter = 0 and btn_state = '1' then
                -- Taste war lange genug stabil low: Loslassen registrieren
                btn_state <= '0';
                released  <= '1';
            end if;

        end if;
    end process;

end Behavioral;
