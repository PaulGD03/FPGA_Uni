----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: Heiko Hinkelmann 
-- 
-- Latest Update: 07.04.2022
-- OV7670 Camera Module
--
-- image size is 320x240 in RGB565 format
----------------------------------------------------------------------------------
-- Description:
-- Top Module of the OV7670 camera.
-- Connects two sub-modules:
-- * OV7670_capture formats the incoming pixel stream.
-- * OV7670_control controls the camera settings.
----------------------------------------------------------------------------------
-- credits: inspired by a design by Mike Field
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity ov7670_cam is port (
    clk  : in  std_logic; -- 50 MHz
    -- camera ports
    OV7670_SIOC  : out   STD_LOGIC;
    OV7670_SIOD  : inout STD_LOGIC;
    OV7670_RESET : out   STD_LOGIC;
    OV7670_PWDN  : out   STD_LOGIC;
    OV7670_VSYNC : in    STD_LOGIC;
    OV7670_HREF  : in    STD_LOGIC;
    OV7670_PCLK  : in    STD_LOGIC;
    OV7670_XCLK  : out   STD_LOGIC;
    OV7670_D     : in    STD_LOGIC_VECTOR(7 downto 0);
    -- board I/O
    --reset        : in    std_logic; -- reset
    configured   : out std_logic; -- status LED: camera config finished
    running      : out std_logic; -- status LED: blinks once every 16 frames
    -- Cam Interface output ports
    vsync        : out std_logic;
    hsync        : out std_logic;
    pix_data     : out std_logic_vector(15 downto 0); -- RGB565
    pix_valid    : out std_logic); 
end ov7670_cam;

architecture Behavioral of ov7670_cam is

    signal camclk : std_logic; -- clock returned from camera module

begin

    -- clock returned from camera
    camclk  <= OV7670_PCLK;
    
    -- camera controller
    -- responsible for configuring and running the OV7670 camera module
    cami2c: entity work.ov7670_control port map(
        clk   => clk,
        reset => '0',
        done  => configured,
        OV7670_SIOC  => OV7670_SIOC,
        OV7670_SIOD  => OV7670_SIOD,
        OV7670_PWDN  => OV7670_PWDN,
        OV7670_RESET => OV7670_RESET,
        OV7670_XCLK  => OV7670_XCLK);  
    
    -- small test module; optional; can be removed
    debug0: entity work.camdebug port map(
        pclk  => camclk,
        vsync => OV7670_VSYNC,
        led   => running);    

    -- camera frontend: data capturing
    cam0: entity work.ov7670_capture port map(
        cam_pclk  => camclk,
        cam_vsync => OV7670_VSYNC,
        cam_href  => OV7670_HREF,
        cam_d     => OV7670_D,
        vsync     => vsync,
        hsync     => hsync,
        pix_we    => pix_valid,
        pix_data  => pix_data);

end Behavioral;
