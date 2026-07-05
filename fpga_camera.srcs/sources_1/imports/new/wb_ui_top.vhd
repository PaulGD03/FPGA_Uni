----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: FPGA-Schaltungsentwurf SS2026
--
-- Module Name: wb_ui_top - Behavioral
-- Description:
--   Top-level white balance user interface.
--   Provides button-controlled per-channel RGB gain adjustment with
--   7-segment display feedback and RGB LED channel indication.
--
--   Button functions:
--     btn_inc  (Up)    : Increase gain of active channel (with auto-repeat)
--     btn_dec  (Down)  : Decrease gain of active channel (with auto-repeat)
--     btn_ch_l (Left)  : Previous channel (R<-B<-G<-R)
--     btn_ch_r (Right) : Next channel (R->G->B->R)
--     btn_rst  (Center): Reset active channel gain to neutral (1.0)
--
--   Sub-modules instantiated:
--     5x debounce      -- one per button
--     1x repeat_timer  -- auto-repeat for inc/dec (shared)
--     1x channel_select -- bidirectional RGB channel cycling
--     3x gain_adjust   -- per-channel gain (R, G, B)
--     1x bcd_converter -- 4.8 fixed-point to BCD display
--     1x seg7_display  -- 7-segment multiplexer and decoder
--
--   Clock: 50 MHz (clk50 from clock wizard)
--   Reset: active high, synchronous
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity wb_ui_top is port(
    clk       : in  std_logic;                      -- 50 MHz system clock
    reset     : in  std_logic;                      -- synchronous reset (active high)
    -- button inputs (raw, active high)
    btn_inc   : in  std_logic;                      -- Up:    increase gain
    btn_dec   : in  std_logic;                      -- Down:  decrease gain
    btn_ch_l  : in  std_logic;                      -- Left:  previous channel
    btn_ch_r  : in  std_logic;                      -- Right: next channel
    btn_rst   : in  std_logic;                      -- Center: reset gain to neutral
    -- 7-segment display outputs
    sseg_ca   : out std_logic_vector(7 downto 0);   -- cathodes (segments, active low)
    sseg_an   : out std_logic_vector(7 downto 0);   -- anodes (digit select, active low)
    -- gain outputs to colorbalancing module (4.8 fixed-point)
    gain_r    : out std_logic_vector(11 downto 0);
    gain_g    : out std_logic_vector(11 downto 0);
    gain_b    : out std_logic_vector(11 downto 0);
    -- RGB LED1 channel indicator
    led1_r    : out std_logic;
    led1_g    : out std_logic;
    led1_b    : out std_logic
);
end wb_ui_top;

architecture Behavioral of wb_ui_top is

    ---------------------------------------------------------------
    -- Debounced button signals
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
    -- Combined inc/dec signals for shared repeat timer
    ---------------------------------------------------------------
    signal combined_pressed  : std_logic;
    signal combined_released : std_logic;

    ---------------------------------------------------------------
    -- Gain adjustment direction
    -- '1' = increase, '0' = decrease
    ---------------------------------------------------------------
    signal direction : std_logic := '0';

    ---------------------------------------------------------------
    -- Repeat timer output (tick for gain adjust)
    ---------------------------------------------------------------
    signal gain_tick : std_logic;

    ---------------------------------------------------------------
    -- Acceleration: track how long inc/dec button is held
    -- Decoded to step_sel: "00"=100, "01"=1000, "10"/"11"=10000
    ---------------------------------------------------------------
    signal accel_count : integer range 0 to 7 := 0;
    signal step_sel    : std_logic_vector(1 downto 0) := "00";

    ---------------------------------------------------------------
    -- Channel selection signals
    ---------------------------------------------------------------
    signal ch_tick : std_logic;                     -- combined left+right tick
    signal ch_dir  : std_logic;                     -- '1'=forward(right), '0'=backward(left)
    signal ch_idx  : std_logic_vector(1 downto 0);  -- "00"=R, "01"=G, "10"=B
    signal ch_sel  : std_logic_vector(2 downto 0);  -- one-hot: "100"=R, "010"=G, "001"=B

    ---------------------------------------------------------------
    -- Per-channel tick and reset routing
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

    -- combined tick and reset for each channel (needed for port map compatibility)
    signal tick_r : std_logic;
    signal tick_g : std_logic;
    signal tick_b : std_logic;
    signal reset_r : std_logic;
    signal reset_g : std_logic;
    signal reset_b : std_logic;

    ---------------------------------------------------------------
    -- Gain values from gain_adjust instances
    ---------------------------------------------------------------
    signal gain_r_int : std_logic_vector(11 downto 0);
    signal gain_g_int : std_logic_vector(11 downto 0);
    signal gain_b_int : std_logic_vector(11 downto 0);

    ---------------------------------------------------------------
    -- Active gain for BCD display
    ---------------------------------------------------------------
    signal active_gain : std_logic_vector(11 downto 0);

    ---------------------------------------------------------------
    -- BCD converter output
    ---------------------------------------------------------------
    signal bcd_data : std_logic_vector(23 downto 0);

begin

    ---------------------------------------------------------------
    -- Combine inc/dec pressed and released for shared repeat timer
    ---------------------------------------------------------------
    combined_pressed  <= db_inc_pressed or db_dec_pressed;
    combined_released <= db_inc_released or db_dec_released;

    ---------------------------------------------------------------
    -- Channel tick and direction from Left/Right buttons
    -- Right (forward) has priority if both pressed simultaneously
    ---------------------------------------------------------------
    ch_tick <= db_ch_l_pressed or db_ch_r_pressed;
    ch_dir  <= '1' when db_ch_r_pressed = '1' else '0';  -- right=forward, left=backward

    ---------------------------------------------------------------
    -- Direction latch: remember which direction was last requested
    ---------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                direction <= '0';
            else
                if db_inc_pressed = '1' then
                    direction <= '1';   -- increase
                elsif db_dec_pressed = '1' then
                    direction <= '0';   -- decrease
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------
    -- Acceleration counter: increments on each auto-repeat tick,
    -- resets when inc/dec button is released.
    -- step_sel decoding:
    --   ticks 0..2  -> "00" (step =   100, fine)
    --   ticks 3..4  -> "01" (step =  1000, medium)
    --   ticks 5+    -> "10" (step = 10000, coarse)
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
    -- Tick and reset routing to active channel
    -- Uses synchronous process instead of concurrent AND gates
    ---------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            -- defaults: all ticks and resets inactive
            tick_r_inc <= '0'; tick_g_inc <= '0'; tick_b_inc <= '0';
            tick_r_dec <= '0'; tick_g_dec <= '0'; tick_b_dec <= '0';
            rst_r <= '0'; rst_g <= '0'; rst_b <= '0';

            if reset = '1' then
                null;  -- gain_adjust instances handle their own reset
            else
                -- route gain tick with direction to active channel
                if gain_tick = '1' then
                    if direction = '1' then  -- increase
                        case ch_sel is
                            when "100"  => tick_r_inc <= '1';
                            when "010"  => tick_g_inc <= '1';
                            when "001"  => tick_b_inc <= '1';
                            when others => null;
                        end case;
                    else  -- decrease
                        case ch_sel is
                            when "100"  => tick_r_dec <= '1';
                            when "010"  => tick_g_dec <= '1';
                            when "001"  => tick_b_dec <= '1';
                            when others => null;
                        end case;
                    end if;
                end if;

                -- route reset press to active channel
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
    -- Combine per-channel tick and reset signals (Vivado requires
    -- these to be simple signal names in port maps)
    ---------------------------------------------------------------
    tick_r  <= tick_r_inc or tick_r_dec;
    tick_g  <= tick_g_inc or tick_g_dec;
    tick_b  <= tick_b_inc or tick_b_dec;
    reset_r <= reset or rst_r;
    reset_g <= reset or rst_g;
    reset_b <= reset or rst_b;

    ---------------------------------------------------------------
    -- Active gain multiplexer for BCD display
    ---------------------------------------------------------------
    active_gain <= gain_r_int when ch_idx = "00" else
                   gain_g_int when ch_idx = "01" else
                   gain_b_int;

    ---------------------------------------------------------------
    -- LED1 channel indicator (direct from one-hot select)
    ---------------------------------------------------------------
    led1_r <= ch_sel(2);   -- "100" -> Red LED
    led1_g <= ch_sel(1);   -- "010" -> Green LED
    led1_b <= ch_sel(0);   -- "001" -> Blue LED

    ---------------------------------------------------------------
    -- Gain outputs to colorbalancing module
    ---------------------------------------------------------------
    gain_r <= gain_r_int;
    gain_g <= gain_g_int;
    gain_b <= gain_b_int;

    ---------------------------------------------------------------
    -- SUB-MODULE INSTANTIATIONS
    ---------------------------------------------------------------

    -- Increase button debouncer (Up)
    deb_inc: entity work.debounce port map(
        clk      => clk,
        btn_in   => btn_inc,
        pressed  => db_inc_pressed,
        released => db_inc_released
    );

    -- Decrease button debouncer (Down)
    deb_dec: entity work.debounce port map(
        clk      => clk,
        btn_in   => btn_dec,
        pressed  => db_dec_pressed,
        released => db_dec_released
    );

    -- Channel left button debouncer
    deb_ch_l: entity work.debounce port map(
        clk      => clk,
        btn_in   => btn_ch_l,
        pressed  => db_ch_l_pressed,
        released => db_ch_l_released
    );

    -- Channel right button debouncer
    deb_ch_r: entity work.debounce port map(
        clk      => clk,
        btn_in   => btn_ch_r,
        pressed  => db_ch_r_pressed,
        released => db_ch_r_released
    );

    -- Reset button debouncer (Center)
    deb_rst: entity work.debounce port map(
        clk      => clk,
        btn_in   => btn_rst,
        pressed  => db_rst_pressed,
        released => db_rst_released
    );

    -- Auto-repeat timer for inc/dec buttons (shared)
    rpt_timer: entity work.repeat_timer port map(
        clk      => clk,
        reset    => reset,
        pressed  => combined_pressed,
        released => combined_released,
        tick     => gain_tick
    );

    -- Bidirectional RGB channel selector (no auto-repeat — single press per advance)
    ch_sel_inst: entity work.channel_select port map(
        clk         => clk,
        reset       => reset,
        tick        => ch_tick,
        dir         => ch_dir,
        channel_idx => ch_idx,
        channel_sel => ch_sel
    );

    -- Red channel gain adjuster
    gain_adj_r: entity work.gain_adjust port map(
        clk         => clk,
        reset       => reset_r,
        tick        => tick_r,
        inc_not_dec => tick_r_inc,
        step_sel    => step_sel,
        gain        => gain_r_int
    );

    -- Green channel gain adjuster
    gain_adj_g: entity work.gain_adjust port map(
        clk         => clk,
        reset       => reset_g,
        tick        => tick_g,
        inc_not_dec => tick_g_inc,
        step_sel    => step_sel,
        gain        => gain_g_int
    );

    -- Blue channel gain adjuster
    gain_adj_b: entity work.gain_adjust port map(
        clk         => clk,
        reset       => reset_b,
        tick        => tick_b,
        inc_not_dec => tick_b_inc,
        step_sel    => step_sel,
        gain        => gain_b_int
    );

    -- BCD converter: 4.8 fixed-point gain to 6-digit BCD (runs continuously)
    bcd_conv: entity work.bcd_converter port map(
        clk   => clk,
        reset => reset,
        gain  => active_gain,
        bcd   => bcd_data
    );

    -- 7-segment display controller: BCD + channel letter to cathodes/anodes
    seg7: entity work.seg7_display port map(
        clk         => clk,
        reset       => reset,
        bcd         => bcd_data,
        channel_sel => ch_sel,
        sseg_ca     => sseg_ca,
        sseg_an     => sseg_an
    );

end Behavioral;
