----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: Heiko Hinkelmann 
-- 
-- Latest Update: 25.05.2026
-- Module Name: top - Behavioral
-- 
-- Project "FPGA-Schaltungsentwurf"
----------------------------------------------------------------------------------
-- (c) Heiko Hinkelmann
-- Frankfurt University of Applied Sciences
-- Die Verwendung dieses Moduls und aller Untermodule ist nur innerhalb der 
-- Lehrveranstaltung "FPGA-Schaltungsentwurf" der FRA-UAS gestattet.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top is port(
    CLK : in  std_logic; -- 100 MHz
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
    RESETN       : in    std_logic; -- reset button (active low)
    SW0          : in    std_logic; -- switch0 activates test image output
    LED          : out   std_logic_vector(1 downto 0); -- status LEDs
                   -- status LED(0): on if camera settings have been loaded
                   -- status LED(1): blinks while images are received from camera
    -- VGA output ports
    VGA_R  : out std_logic_vector(3 downto 0);
    VGA_G  : out std_logic_vector(3 downto 0);
    VGA_B  : out std_logic_vector(3 downto 0);
    VGA_HS : out std_logic;
    VGA_VS : out std_logic;
    -- User Interface Buttons
    BTNR   : in  std_logic;
    BTNU   : in  std_logic;
    BTNL   : in  std_logic;
    BTNC   : in  std_logic;
    BTND   : in  std_logic;
    -- User Interface 7-Segment Display
    SSEG_CA : out std_logic_vector(7 downto 0);
    SSEG_AN : out std_logic_vector(7 downto 0);
    -- RGB LED for channel indication
    LED1_R : out std_logic;
    LED1_G : out std_logic;
    LED1_B : out std_logic);
end top;

architecture Behavioral of top is

    -- clock signals
    signal vga_clk25 : std_logic; -- internal 25.175 MHz clock
    signal clk50 : std_logic;     -- internal 50 MHz clock
    signal cam_clk : std_logic;   -- external clock from camera
    -- reset button
    signal reset : std_logic;
    -- signals of camera frontend
    signal cam_pix_data  : std_logic_vector(15 downto 0);
    signal cam_pix_valid : std_logic;
    signal cam_vsync, cam_hsync : std_logic;
    -- signals of color balancing module
    signal col_pix_data  : std_logic_vector(15 downto 0);
    signal col_pix_valid : std_logic;
    signal col_vsync, col_hsync : std_logic;
    -- signals of VGA controller
    signal ram_rxaddr : std_logic_vector(8 downto 0);
    signal ram_ryaddr : std_logic_vector(7 downto 0);
    signal ram_rdata : std_logic_vector(15 downto 0);
    -- white balance gain signals from user interface to color balancing
    signal cam_gain_r : std_logic_vector(11 downto 0) := "000100000000";
    signal cam_gain_g : std_logic_vector(11 downto 0) := "000100000000";
    signal cam_gain_b : std_logic_vector(11 downto 0) := "000100000000";
    -- others
    constant zero : std_logic := '0';
    
    -- component declaration of clock generator IP core
    component clk_wiz_1 port(
        clk_in1  : in  std_logic;
        reset    : in  std_logic;
        locked   : out std_logic;
        clk50    : out std_logic; 
        clk25    : out std_logic); 
    end component;

begin

    ---------------------------------------------------
    -- Clocking
    ---------------------------------------------------
    
    -- generate this IP by using the IP Catalog -> Clock Wizard
    clkgen0: clk_wiz_1 port map(
        clk_in1  => CLK,    -- 100 MHz
        reset    => zero,
        locked   => open,
        clk50    => clk50,      -- 50 MHz
        clk25    => vga_clk25); -- 25.175 MHz

    -- clock signal returned from camera
    cam_clk <= OV7670_PCLK;
    
    ---------------------------------------------------
    reset <= not RESETN;  -- reset button
    -- changes reset to active high
    
    ---------------------------------------------------
    -- Camera Frontend
    ---------------------------------------------------

    cam0: entity work.ov7670_cam port map(
        clk          => clk50,
        OV7670_SIOC  => OV7670_SIOC,
        OV7670_SIOD  => OV7670_SIOD,
        OV7670_RESET => OV7670_RESET,
        OV7670_PWDN  => OV7670_PWDN,
        OV7670_VSYNC => OV7670_VSYNC,
        OV7670_HREF  => OV7670_HREF,
        OV7670_PCLK  => OV7670_PCLK,
        OV7670_XCLK  => OV7670_XCLK,
        OV7670_D     => OV7670_D,
        configured   => LED(0),   -- status LED0, on if camera settings have been loaded
        running      => LED(1),   -- status LED1, blinks while images are received from camera
        pix_data     => cam_pix_data,
        pix_valid    => cam_pix_valid, 
        vsync        => cam_vsync,
        hsync        => cam_hsync);
        
    ---------------------------------------------------
    -- Color Balancing / Color Adjustment
    ---------------------------------------------------
    col0: entity work.colorbalancing port map(
        clk           => cam_clk,
        gain_red      => cam_gain_r,
        gain_green    => cam_gain_g,
        gain_blue     => cam_gain_b,
        pix_valid_in  => cam_pix_valid,
        pix_data_in   => cam_pix_data,
        vsync_in      => cam_vsync,
        hsync_in      => cam_hsync,
        pix_valid_out => col_pix_valid,
        pix_data_out  => col_pix_data,
        vsync_out     => col_vsync,
        hsync_out     => col_hsync);
    
    ---------------------------------------------------
    -- White Balance User Interface
    ---------------------------------------------------
    wb_ui: entity work.wb_ui_top port map(
        clk      => clk50,
        reset    => reset,
        btn_inc  => BTNU,
        btn_dec  => BTND,
        btn_ch_l => BTNL,
        btn_ch_r => BTNR,
        btn_rst  => BTNC,
        sseg_ca  => SSEG_CA,
        sseg_an  => SSEG_AN,
        gain_r   => cam_gain_r,
        gain_g   => cam_gain_g,
        gain_b   => cam_gain_b,
        led1_r   => LED1_R,
        led1_g   => LED1_G,
        led1_b   => LED1_B
    );


    
    ---------------------------------------------------
    -- Frame Buffer
    ---------------------------------------------------
        
    -- image frame buffer
    buf0: entity work.framebuffer port map(
        -- write port
        wclk   => cam_clk,
        wen    => col_pix_valid, -- write enable,
        vsync  => col_vsync,
        hsync  => col_hsync, 
        wdata  => col_pix_data,
        -- read port
        rclk   => vga_clk25,
        rxaddr => ram_rxaddr,
        ryaddr => ram_ryaddr, 
        rdata  => ram_rdata);
        
    ---------------------------------------------------
    -- VGA Interface Controller
    ---------------------------------------------------
    
    vga0: entity work.vga_controller port map(
        clk => vga_clk25,
        reset => '0',
        pixxaddr => ram_rxaddr,
        pixyaddr => ram_ryaddr,
        pixdata => ram_rdata,
        debugmode => SW0,
        vga_red => VGA_R,
        vga_green => VGA_G,
        vga_blue => VGA_B,
        vga_hsync => VGA_HS,
        vga_vsync => VGA_VS);
        
    ------------------------------------------
    
       
end Behavioral;
