----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: FPGA-Schaltungsentwurf SS2026
--
-- Module Name: channel_select - Behavioral
-- Beschreibung:
--   RGB-Kanal-Auswahl mit bidirektionalem Umschalten.
--   Schaltet vorwärts (R->G->B->R) oder rückwärts (R->B->G->R) bei jedem Tick,
--   abhängig vom 'dir' Eingang.
--   Verwendet intern einen Integer-Zustand (0/1/2) und liefert sowohl einen
--   one-hot kodierten Ausgang als auch einen binär kodierten Index.
--   Reset setzt den aktiven Kanal auf Rot (Index "00").
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity channel_select is port(
    clk         : in  std_logic;
    reset       : in  std_logic;
    tick        : in  std_logic;     -- 1-Takt Puls zum Weiterschalten
    dir         : in  std_logic;     -- '1' = vorwärts (R->G->B), '0' = rückwärts (R->B->G)
    channel_idx : out std_logic_vector(1 downto 0);  -- "00"=R, "01"=G, "10"=B
    channel_sel : out std_logic_vector(2 downto 0)   -- one-hot: "100"=R, "010"=G, "001"=B
);
end channel_select;

architecture Behavioral of channel_select is

    signal channel : integer range 0 to 2 := 0;

begin

    -- Kanal weiterschalten bei Tick (bidirektional)
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                channel <= 0;  -- Standard: Rot
            elsif tick = '1' then
                if dir = '1' then
                    -- vorwärts: R(0) -> G(1) -> B(2) -> R(0) ...
                    if channel = 2 then
                        channel <= 0;
                    else
                        channel <= channel + 1;
                    end if;
                else
                    -- rückwärts: R(0) -> B(2) -> G(1) -> R(0) ...
                    if channel = 0 then
                        channel <= 2;
                    else
                        channel <= channel - 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- binär kodierter Indexausgang
    channel_idx <= "00" when channel = 0 else
                   "01" when channel = 1 else
                   "10";  -- channel = 2 (Blau)

    -- kombinatorische one-hot Dekodierung
    channel_sel <= "100" when channel = 0 else
                   "010" when channel = 1 else
                   "001";  -- channel = 2 (Blau)

end Behavioral;
