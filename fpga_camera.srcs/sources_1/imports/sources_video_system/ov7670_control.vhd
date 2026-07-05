----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: Heiko Hinkelmann 
-- 
-- Latest Update: 07.04.2022
-- Module Name: ov7670_control - Behavioral
----------------------------------------------------------------------------------
-- Description:
-- Controls reset and configuration register settings of OV7670 camera.
-- Register settings are send to the camera by a i2c-like 2-wire serial interface.            
----------------------------------------------------------------------------------
-- credits: inspired by a design by Mike Field
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

entity ov7670_control is port(
    clk   : in  std_logic;
    reset : in  std_logic; 
    done  : out std_logic;
    -- camera interface
    OV7670_SIOC  : out   std_logic;
    OV7670_SIOD  : inout std_logic;
    OV7670_XCLK  : out   std_logic;
    OV7670_RESET : out   std_logic;
    OV7670_PWDN  : out   std_logic);
end entity;

architecture Behavioral of ov7670_control is
   
   type state_type is (init,rst,rst_wait,transmit,i2c_confirm,finished);
   signal state : state_type := init;
   
   signal timer1ms : std_logic_vector(16 downto 0) := (others => '0'); 
   signal tick1ms  : std_logic; -- ticks every 1.3 ms
   signal timer_enable : std_logic;
   
   signal i2c_send : std_logic := '0';
   signal i2c_ready : std_logic;
   signal rom_finished : std_logic;
   signal rom_reset : std_logic;
   signal i2c_data : std_logic_vector(15 downto 0);
   
   signal cam_clk : std_logic := '0'; -- 1/2 frequency of clk
   
begin

    rom0: entity work.ov7670_config port map(
        clk      => clk,
        reset    => rom_reset,
        getnext  => i2c_send,
        finished => rom_finished,
        data     => i2c_data);
        
    i2ctx0: entity work.i2c_tx
    generic map(
        bytes => 2) 
    port map(
        clk   => clk,
        data  => i2c_data,
        start => i2c_send,
        ready => i2c_ready,
        sclk  => OV7670_SIOC,
        sdata => OV7670_SIOD);

    rom_reset <= '1' when ((reset='1') or (state=init)) else '0';

    process(clk)
    begin
       if rising_edge(clk) then
           i2c_send <= '0';
           if (reset='1') then
               state <= init;
           else
               state <= state;
               case state is
               when init => 
                   -- wait 1 ms after startup (no requirement)
                   if (tick1ms='1') then
                       state <= rst;
                   end if;
               when rst => 
                   -- transmit reset command to camera via i2c
                   if (i2c_ready='1') then
                       i2c_send <= '1';
                       state <= rst_wait;
                   end if;
               when rst_wait => 
                   -- wait 1 ms after reset (required according to OV7670 datasheet)
                   if (tick1ms='1') then
                       state <= transmit;
                   end if;
               when transmit => 
                   -- perform all i2c accesses defined in ROM
                   if (rom_finished='1') then
                       state <= finished;
                   elsif (i2c_ready='1') then
                       state <= i2c_confirm;
                       i2c_send <= '1';
                   end if;
               when i2c_confirm => 
                   -- ensure that i2c_ready signal goes down, 
                   -- then return to transmit state and wait until i2c_ready goes high.
                   if (i2c_ready='0') then
                       state <= transmit;
                   end if;
               when others => 
                   -- finished
                   state <= state;
               end case;
           end if;
       end if;
    end process;

    done <= '1' when (state=finished) else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if (reset='1') then
                timer1ms <= (others => '0');
            elsif (timer_enable='1') then
                timer1ms <= ('0' & timer1ms(15 downto 0)) + '1';
            end if;
        end if;
    end process;
    
    tick1ms <= timer1ms(16);
    timer_enable <= '1' when ((state=init) or (state=rst_wait)) else '0';


    OV7670_XCLK  <= cam_clk;
    OV7670_RESET <= '1';
    OV7670_PWDN  <= '0';

    process(clk)
    begin
        if rising_edge(clk) then
            cam_clk <= not cam_clk;
        end if;
    end process;
    
end Behavioral;