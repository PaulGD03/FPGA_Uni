----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: Heiko Hinkelmann 
-- 
-- Latest Update: 07.04.2022
-- Module Name: ov7670_capture - Behavioral
----------------------------------------------------------------------------------
-- Description:
-- Captures the pixels coming from the OV760 camera and 
-- reformats data and control signals of image stream.
-- Optional address signals may be used to write image to a RAM.             
----------------------------------------------------------------------------------
-- inspired by a design by: Mike Field <hamster@snap.net.nz>
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

entity ov7670_capture is port( 
    -- OV7670 camera ports
    cam_pclk  : in std_logic;
    cam_vsync : in std_logic; -- active low
    cam_href  : in std_logic; -- active high
    cam_d     : in std_logic_vector(7 downto 0);
    -- output interface / to frame buffer
    vsync     : out std_logic; -- active high
    hsync     : out std_logic; -- active high
    pix_we    : out std_logic;
    pix_data  : out std_logic_vector(15 downto 0));
    --pix_xaddr : out std_logic_vector(8 downto 0);  -- 320
    --pix_yaddr : out std_logic_vector(7 downto 0)); -- 240
end ov7670_capture;

architecture Behavioral of ov7670_capture is

    signal dreg, d1 : std_logic_vector(7 downto 0);
    signal vs : std_logic := '0';
    signal hs : std_logic := '0';
    signal hprev : std_logic := '0';
    signal lineinc : std_logic := '0';

    signal xaddr : std_logic_vector(9 downto 0) := "0000000000"; -- row counter (divide by 2: two bytes per pixel)
    signal yaddr : std_logic_vector(7 downto 0) := "00000000"; -- line counter 
   
begin
    
    ----------------------------------------
    -- output interface:
    ----------------------------------------
    pix_data <= d1 & dreg;  -- pixel data
    pix_we   <= xaddr(0);   -- pixel valid 
    -- note: every pixel consists of 2 bytes
    -- thus, it takes 2 clock cycles to receive 2 bytes = 1 pixel.
    -- d1 represents the upper byte.
    -- dreg represents the lower byte.
    -- the valid signal gets high if pix_data contains 2 valid bytes of 1 valid pixel.
    
    -- horizontal and vertical sync signals
    vsync <= not vs; -- change to active high
    hsync <= hs;
    
    -- pixel address output / not used at the moment
    -- pix_xaddr <= xaddr(9 downto 1);
    -- pix_yaddr <= yaddr;
    
    ----------------------------------------
    -- control signals
    ----------------------------------------
    
    process(cam_pclk)
    begin
        if rising_edge(cam_pclk) then
            -- input registers
            vs <= cam_vsync;
            hs <= cam_href;
            dreg <= cam_d;
            -- pipelining and control
            d1 <= dreg;
            hprev <= hs;
            lineinc <= hprev and not hs; -- falling edge of href
        end if;
    end process;
    
    -- vertical pixel counter (line counter)
    process(cam_pclk)
    begin
        if rising_edge(cam_pclk) then
            if (vs='1') then
                yaddr <= (others => '0');
            elsif (lineinc='1') and (yaddr < "11110000") then  -- <240, no overflow
                yaddr <= yaddr + '1';
            end if;
        end if;
    end process;
    
    -- horizontal pixel counter
    process(cam_pclk)
    begin
        if rising_edge(cam_pclk) then
            if (hs='0') then
                xaddr <= (others => '0');
            elsif (xaddr < "1010000000") then   -- if < 320
                xaddr <= xaddr + '1';
            end if;
        end if;
    end process;
         
 
end Behavioral;