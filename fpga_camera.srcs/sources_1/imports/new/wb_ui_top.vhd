----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: FPGA-Schaltungsentwurf SS2026
--
-- Module Name: wb_ui_top - Behavioral
-- Beschreibung:
--   Top-Level Weissabgleich Benutzerschnitstelle.
--   Bietet tastaturgesteuerte RGB-Kanal-Verstärkungsanpasung mit
--   7-Segment-Anzeige und RGB-LED-Kanalindikation.
--
--   Tastenfunktionen:
--     btn_inc  (Oben)   : Verstärkung des aktiven Kanals erröhen (mit auto-repeat)
--     btn_dec  (Unten)  : Verstärkung des aktiven Kanals verringern (mit auto-repeat)
--     btn_ch_l (Links)  : Vorheriger Kanal (R<-B<-G<-R)
--     btn_ch_r (Rechts) : Nächster Kanal (R->G->B->R)
--     btn_rst  (Mitte)  : Aktiven Kanal auf neutral zurüksetzen (1.0)
--
--   Instanziierte Untermodule:
--     5x debounce      -- einer pro Taste
--     1x repeat_timer  -- auto-repeat für erröhen/verringern (geteilt)
--     1x channel_select -- bidirektionales RGB-Kanal-Umschalten
--     3x gain_adjust   -- Kanalverstärkung (R, G, B)
--     1x bcd_converter -- 4.8 Festkomma zu BCD Umwandlung
--     1x seg7_display  -- 7-Segment Multiplexer und Dekodierer
--
--   Takt: 50 MHz (clk50 vom Clock Wizard)
--   Reset: active high, synchron
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity wb_ui_top is port(
    clk       : in  std_logic;                      -- 50 MHz Systemtakt
    reset     : in  std_logic;                      -- synchroner Reset (active high)
    -- Tasteneingänge (roh, active high)
    btn_inc   : in  std_logic;                      -- Oben:    Verstärkung erröhen
    btn_dec   : in  std_logic;                      -- Unten:   Verstärkung verringern
    btn_ch_l  : in  std_logic;                      -- Links:   vorheriger Kanal
    btn_ch_r  : in  std_logic;                      -- Rechts:  nächster Kanal
    btn_rst   : in  std_logic;                      -- Mitte:   Gain zurüksetzen auf neutral
    -- 7-Segment Anzeige Ausgänge
    sseg_ca   : out std_logic_vector(7 downto 0);   -- Kathoden (Segmente, active low)
    sseg_an   : out std_logic_vector(7 downto 0);   -- Anoden (Stellenauswahl, active low)
    -- Gain-Ausgänge zum colorbalancing Modul (4.8 Festkomma)
    gain_r    : out std_logic_vector(11 downto 0);
    gain_g    : out std_logic_vector(11 downto 0);
    gain_b    : out std_logic_vector(11 downto 0);
    -- RGB LED1 Kanalindikator
    led1_r    : out std_logic;
    led1_g    : out std_logic;
    led1_b    : out std_logic
);
end wb_ui_top;

architecture Behavioral of wb_ui_top is

    ---------------------------------------------------------------
    -- Debouncte Tastensignale
    ---------------------------------------------------------------
    signal db_inc_pressed   : std_logic;
    signal db_inc_released  : std_logic;

    signal db_dec_pressed   : std_logic;
    signal db_dec_released  : std_logic;

    signal db_ch_l_pressed  : std_logic;
    signal db_ch_l_released : std_logic;

    signal db_ch_r_pressed  : std_logic;
    signal db_ch_r_released : std_logic;

    signal db_rst_pressed   : std_logic;
    signal db_rst_released  : std_logic;

    ---------------------------------------------------------------
    -- Zusammengefasste erhöhen/verringern Signale für geteilten repeat_timer
    ---------------------------------------------------------------
    signal combined_pressed  : std_logic;
    signal combined_released : std_logic;

    ---------------------------------------------------------------
    -- Gain-Richtung
    -- '1' = erhöhen, '0' = verringern
    ---------------------------------------------------------------
    signal direction : std_logic := '0';

    ---------------------------------------------------------------
    -- Repeat-Timer Ausgang (Tick für gain_adjust)
    ---------------------------------------------------------------
    signal gain_tick : std_logic;

    ---------------------------------------------------------------
    -- Beschleunigung: zählt wie lange erhöhen/verringern gehalten wird
    -- Dekodiert zu step_sel: "00"=100, "01"=1000, "10"/"11"=10000
    ---------------------------------------------------------------
    signal accel_count : integer range 0 to 7 := 0;
    signal step_sel    : std_logic_vector(1 downto 0) := "00";

    ---------------------------------------------------------------
    -- Kanalauswahlsignale
    ---------------------------------------------------------------
    signal ch_tick : std_logic;                     -- kombinierter links+rechts Tick
    signal ch_dir  : std_logic;                     -- '1'=vorwärts(rechts), '0'=rückwärts(links)
    signal ch_idx  : std_logic_vector(1 downto 0);  -- "00"=R, "01"=G, "10"=B
    signal ch_sel  : std_logic_vector(2 downto 0);  -- one-hot: "100"=R, "010"=G, "001"=B

    ---------------------------------------------------------------
    -- Kanalweise Tick- und Reset-Verteilung
    ---------------------------------------------------------------
    signal tick_r_inc : std_logic;
    signal tick_g_inc : std_logic;
    signal tick_b_inc : std_logic;
    signal tick_r_dec : std_logic;
    signal tick_g_dec : std_logic;
    signal tick_b_dec : std_logic;
    signal rst_r : std_logic;
    signal rst_g : std_logic;
    signal rst_b : std_logic;

    -- kombinierter Tick und Reset für jeden Kanal (nötig für Port-Map-Kompatibilität)
    signal tick_r : std_logic;
    signal tick_g : std_logic;
    signal tick_b : std_logic;
    signal reset_r : std_logic;
    signal reset_g : std_logic;
    signal reset_b : std_logic;

    ---------------------------------------------------------------
    -- Gain-Werte von den gain_adjust Instanzen
    ---------------------------------------------------------------
    signal gain_r_int : std_logic_vector(11 downto 0);
    signal gain_g_int : std_logic_vector(11 downto 0);
    signal gain_b_int : std_logic_vector(11 downto 0);

    ---------------------------------------------------------------
    -- Aktiver Gain für BCD-Anzeige
    ---------------------------------------------------------------
    signal active_gain : std_logic_vector(11 downto 0);

    ---------------------------------------------------------------
    -- BCD-Wandler Ausgang
    ---------------------------------------------------------------
    signal bcd_data : std_logic_vector(23 downto 0);

begin

    ---------------------------------------------------------------
    -- Erhöhen/Verringern pressed und released für geteilten repeat_timer kombinieren
    ---------------------------------------------------------------
    combined_pressed  <= db_inc_pressed or db_dec_pressed;
    combined_released <= db_inc_released or db_dec_released;

    ---------------------------------------------------------------
    -- Kanal-Tick und Richtung von Links/Rechts Tasten
    -- Rechts (vorwärts) hat Priorität wenn beide gleichzeitig gedrückt
    ---------------------------------------------------------------
    ch_tick <= db_ch_l_pressed or db_ch_r_pressed;
    ch_dir  <= '1' when db_ch_r_pressed = '1' else '0';  -- rechts=vorwärts, links=rückwärts

    ---------------------------------------------------------------
    -- Richtungs-Latch: merkt sich welche Richtung zuletzt angefordert wurde
    ---------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                direction <= '0';
            else
                if db_inc_pressed = '1' then
                    direction <= '1';   -- erhöhen
                elsif db_dec_pressed = '1' then
                    direction <= '0';   -- verringern
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------
    -- Beschleunigungszähler: erhöht bei jedem auto-repeat Tick,
    -- zurüksetzen wenn erhöhen/verringern losgelassen wird.
    -- step_sel Dekodierung:
    --   Ticks 0..2  -> "00" (Schritt =   100, fein)
    --   Ticks 3..4  -> "01" (Schritt =  1000, mittel)
    --   Ticks 5+    -> "10" (Schritt = 10000, grob)
    ---------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                accel_count <= 0;
                step_sel    <= "00";
            else
                if combined_released = '1' then
                    accel_count <= 0;
                    step_sel    <= "00";
                elsif gain_tick = '1' then
                    if accel_count < 7 then
                        accel_count <= accel_count + 1;
                    end if;

                    if accel_count < 3 then
                        step_sel <= "00";   --   100
                    elsif accel_count < 5 then
                        step_sel <= "01";   --  1000
                    else
                        step_sel <= "10";   -- 10000
                    end if;
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------
    -- Tick- und Reset-Verteilung zum aktiven Kanal
    -- Verwendet synchronen Prozess statt nebenläufiger AND-Gatter
    ---------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            -- defaults: alle Ticks und Resets inaktiv
            tick_r_inc <= '0'; tick_g_inc <= '0'; tick_b_inc <= '0';
            tick_r_dec <= '0'; tick_g_dec <= '0'; tick_b_dec <= '0';
            rst_r <= '0'; rst_g <= '0'; rst_b <= '0';

            if reset = '1' then
                null;  -- gain_adjust Instanzen behandeln ihren eigenen Reset
            else
                -- Gain-Tick mit Richtung zum aktiven Kanal leiten
                if gain_tick = '1' then
                    if direction = '1' then  -- erhöhen
                        case ch_sel is
                            when "100"  => tick_r_inc <= '1';
                            when "010"  => tick_g_inc <= '1';
                            when "001"  => tick_b_inc <= '1';
                            when others => null;
                        end case;
                    else  -- verringern
                        case ch_sel is
                            when "100"  => tick_r_dec <= '1';
                            when "010"  => tick_g_dec <= '1';
                            when "001"  => tick_b_dec <= '1';
                            when others => null;
                        end case;
                    end if;
                end if;

                -- Reset-Tastendruck zum aktiven Kanal leiten
                if db_rst_pressed = '1' then
                    case ch_sel is
                        when "100"  => rst_r <= '1';
                        when "010"  => rst_g <= '1';
                        when "001"  => rst_b <= '1';
                        when others => null;
                    end case;
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------
    -- Kanalweise Tick- und Reset-Signale kombinieren (Vivado braucht
    -- einfache Signalnamen in Port Maps)
    ---------------------------------------------------------------
    tick_r  <= tick_r_inc or tick_r_dec;
    tick_g  <= tick_g_inc or tick_g_dec;
    tick_b  <= tick_b_inc or tick_b_dec;
    reset_r <= reset or rst_r;
    reset_g <= reset or rst_g;
    reset_b <= reset or rst_b;

    ---------------------------------------------------------------
    -- Aktiver Gain Multiplexer für BCD-Anzeige
    ---------------------------------------------------------------
    active_gain <= gain_r_int when ch_idx = "00" else
                   gain_g_int when ch_idx = "01" else
                   gain_b_int;

    ---------------------------------------------------------------
    -- LED1 Kanalindikator (direkt von one-hot Auswahl)
    ---------------------------------------------------------------
    led1_r <= ch_sel(2);   -- "100" -> Rote LED
    led1_g <= ch_sel(1);   -- "010" -> Grüne LED
    led1_b <= ch_sel(0);   -- "001" -> Blaue LED

    ---------------------------------------------------------------
    -- Gain-Ausgänge zum colorbalancing Modul
    ---------------------------------------------------------------
    gain_r <= gain_r_int;
    gain_g <= gain_g_int;
    gain_b <= gain_b_int;

    ---------------------------------------------------------------
    -- UNTERMODUL-INSTANZIIERUNGEN
    ---------------------------------------------------------------

    -- Erhöhen-Taste Debouncer (Oben)
    deb_inc: entity work.debounce port map(
        clk      => clk,
        btn_in   => btn_inc,
        pressed  => db_inc_pressed,
        released => db_inc_released
    );

    -- Verringern-Taste Debouncer (Unten)
    deb_dec: entity work.debounce port map(
        clk      => clk,
        btn_in   => btn_dec,
        pressed  => db_dec_pressed,
        released => db_dec_released
    );

    -- Kanal-Links-Taste Debouncer
    deb_ch_l: entity work.debounce port map(
        clk      => clk,
        btn_in   => btn_ch_l,
        pressed  => db_ch_l_pressed,
        released => db_ch_l_released
    );

    -- Kanal-Rechts-Taste Debouncer
    deb_ch_r: entity work.debounce port map(
        clk      => clk,
        btn_in   => btn_ch_r,
        pressed  => db_ch_r_pressed,
        released => db_ch_r_released
    );

    -- Reset-Taste Debouncer (Mitte)
    deb_rst: entity work.debounce port map(
        clk      => clk,
        btn_in   => btn_rst,
        pressed  => db_rst_pressed,
        released => db_rst_released
    );

    -- Auto-Repeat Timer für Erhöhen/Verringern Tasten (geteilt)
    rpt_timer: entity work.repeat_timer port map(
        clk      => clk,
        reset    => reset,
        pressed  => combined_pressed,
        released => combined_released,
        tick     => gain_tick
    );

    -- Bidirektionaler RGB-Kanalwähler (kein auto-repeat - ein Tastendruck pro Wechsel)
    ch_sel_inst: entity work.channel_select port map(
        clk         => clk,
        reset       => reset,
        tick        => ch_tick,
        dir         => ch_dir,
        channel_idx => ch_idx,
        channel_sel => ch_sel
    );

    -- Roter Kanal Gain-Regler
    gain_adj_r: entity work.gain_adjust port map(
        clk         => clk,
        reset       => reset_r,
        tick        => tick_r,
        inc_not_dec => tick_r_inc,
        step_sel    => step_sel,
        gain        => gain_r_int
    );

    -- Grüner Kanal Gain-Regler
    gain_adj_g: entity work.gain_adjust port map(
        clk         => clk,
        reset       => reset_g,
        tick        => tick_g,
        inc_not_dec => tick_g_inc,
        step_sel    => step_sel,
        gain        => gain_g_int
    );

    -- Blauer Kanal Gain-Regler
    gain_adj_b: entity work.gain_adjust port map(
        clk         => clk,
        reset       => reset_b,
        tick        => tick_b,
        inc_not_dec => tick_b_inc,
        step_sel    => step_sel,
        gain        => gain_b_int
    );

    -- BCD-Wandler: 4.8 Festkomma-Gain zu 6-stelligem BCD (läuft kontinuierlich)
    bcd_conv: entity work.bcd_converter port map(
        clk   => clk,
        reset => reset,
        gain  => active_gain,
        bcd   => bcd_data
    );

    -- 7-Segment Anzeigesteuerung: BCD + Kanalbuchstabe zu Kathoden/Anoden
    seg7: entity work.seg7_display port map(
        clk         => clk,
        reset       => reset,
        bcd         => bcd_data,
        channel_sel => ch_sel,
        sseg_ca     => sseg_ca,
        sseg_an     => sseg_an
    );

end Behavioral;
