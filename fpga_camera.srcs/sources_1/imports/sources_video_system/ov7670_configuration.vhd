----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: Heiko Hinkelmann 
-- 
-- Latest Update: 07.04.2022
-- Module Name: ov7670_config - Behavioral
----------------------------------------------------------------------------------
-- Description:
-- Contains the camera configuration register settings.  
-- see datasheet "OV7670 Implementation Guide v1.0"           
----------------------------------------------------------------------------------
-- based on a design by: Mike Field <hamster@snap.net.nz>
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

entity ov7670_config is port( 
    clk      : in  std_logic;
    reset    : in  std_logic;
    getnext  : in  std_logic;
    finished : out std_logic;
    data     : out std_logic_vector(15 downto 0));
end entity;

architecture Behavioral of ov7670_config is

    signal addr : std_logic_vector(7 downto 0) := (others => '0');
    signal dout : std_logic_vector(15 downto 0);
    signal fin  : std_logic := '0';
    
    -- ROM with configuration data:
    -- Each 16-bit-entry corresponds to one OV7670 register setting: 
    -- The upper byte is the OV7670 register address.
    -- The lower byte is the data byte which will be written to this register address.
    type mem_type is array (natural range <>) of std_logic_vector(15 downto 0);
    constant mem : mem_type(0 to 255) := (
        X"1280", -- COM7   Reset / 1ms delay required after reset!
        X"1204", -- COM7   Size & RGB output
        X"1101", -- CLKRC  Prescaler - Fin/(1+1)
        X"0C04", -- COM3   Lots of stuff, enable DCW scaling, all others off
        X"3E19", -- COM14  PCLK divide by 2; enable DCW and (manual) scaling
        X"703a", -- SCALING_XSC horizontal scale factor (default = x3A)
        X"7135", -- SCALING_YSC vertical scale factor (default = x35)
        X"7211", -- SCALING_DCWCTR (default = x11), downsampling by 2x2
        X"73f1", -- SCALING_PCLK_DIV (divide by 2)
        X"a202", -- SCALING_PCLK_DELAY  PCLK scaling = 4, (default value; must match COM14 ?)
        --
        x"1715", -- 1713 HSTART HREF start (high 8 bits) -> 00010101_110 = 0x0AE
        x"1803", -- 1801 HSTOP  HREF stop (high 8 bits)  -> 00000011_110 = 0x01E
        x"32B6", -- HREF   Edge offset and low 3 bits of HSTART and HSTOP
        x"1902", -- VSTART VSYNC start (high 8 bits) -> 00000010_10 = 0x00A
        x"1A7A", -- VSTOP  VSYNC stop (high 8 bits)  -> 01111010_10 = 0x1EA
        x"030a", -- VREF   VSYNC low two bits
        --
        x"8C00", -- RGB444 Set RGB format = RGB565
        x"0400", -- COM1   no CCIR601
        x"40D0", -- COM15  Full 0-255 output, RGB 565 (former setting was 0x4010)
        x"3a04", -- TSLB   Set UV ordering,  do not auto-reset window
        x"1438", -- COM9  - AGC Ceiling
        x"4f40", --x"4fb3"; -- MTX1  - colour conversion matrix
        x"5034", --x"50b3"; -- MTX2  - colour conversion matrix
        x"510C", --x"5100"; -- MTX3  - colour conversion matrix
        x"5217", --x"523d"; -- MTX4  - colour conversion matrix
        x"5329", --x"53a7"; -- MTX5  - colour conversion matrix
        x"5440", --x"54e4"; -- MTX6  - colour conversion matrix
        x"581e", --x"589e"; -- MTXS  - Matrix sign and auto contrast
        x"3dc0", -- COM13 - Turn on GAMMA and UV Auto adjust
        --
        x"0e61", -- COM5(0x0E) 0x61
        x"0f4b", -- COM6(0x0F) 0x4B 
        x"1602", --
        x"1e17", -- MVFP (0x1E) 0x07  -- FLIP AND MIRROR IMAGE 0x3x
        x"2102",
        x"2291",
        x"2907",
        x"330b",
        x"350b",
        x"371d",
        x"3871",
        x"392a",
        x"3c78", -- COM12 (0x3C) 0x78
        x"4d40", 
        x"4e20",
        x"6900", -- GFIX (0x69) 0x00
        x"6b4a",
        x"7410",
        x"8d4f",
        x"8e00",
        x"8f00",
        x"9000",
        x"9100",
        x"9600",
        x"9a00",
        x"b084",
        x"b10c",
        x"b20e",
        x"b382",
        x"b80a",
            
        others => X"FFFF"); -- unsed entries must be set to FFFF
        
        -- As soon as the data "FF.." is read, the configuration stops.


begin

    -----------------------------
    -- address control
    -----------------------------

    process(clk)
    begin
        if rising_edge(clk) then
            if (reset='1') then
                -- start at address 0 after reset
                addr <= (others => '0');
            else
                -- increase address on request
                addr <= addr + getnext;
            end if;
        end if;
    end process;
    
    ----------------------------
    -- reading from ROM
    ----------------------------
    
    dout <= mem(conv_integer(addr));
    data <= dout;
    
    --------------------------------------
    -- detect end of configuration
    --------------------------------------
    
    process(clk)
    begin
       if rising_edge(clk) then
           if (dout(15 downto 8)=X"FF") then
           -- Register address value "FF" indicates an invalid ROM entry
           -- => This marks the end of the configuration data in ROM.
               fin <= '1';
           else
               fin <= '0';
           end if;
       end if;
    end process;
    
    finished <= fin;

end Behavioral;