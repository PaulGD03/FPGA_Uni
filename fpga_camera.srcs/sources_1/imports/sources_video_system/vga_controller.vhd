----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: H. Hinkelmann 
-- 
-- Latest Update: 03.12.2021
-- Module Name: VGA Controller
-- 
----------------------------------------------------------------------------------
-- (c) Heiko Hinkelmann
-- Frankfurt University of Applied Sciences
-- Die Verwendung dieses Moduls ist nur innerhalb der Lehrveranstaltung 
-- "FPGA-Schaltungsentwurf" der FRA-UAS gestattet.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

entity vga_controller is port(
    clk       : in  std_logic; -- 25.175 MHz
    reset     : in  std_logic;
    pixxaddr  : out std_logic_vector(8 downto 0); -- frame buffer read x-address
    pixyaddr  : out std_logic_vector(7 downto 0); -- frame buffer read y-address
    pixdata   : in  std_logic_vector(15 downto 0); -- pixel data
    debugmode : in  std_logic;                     -- activates a test pattern output
    -- VGA output ports
    vga_red   : out std_logic_vector(3 downto 0);
    vga_green : out std_logic_vector(3 downto 0);
    vga_blue  : out std_logic_vector(3 downto 0);
    vga_hsync : out std_logic;
    vga_vsync : out std_logic);    
end vga_controller;

architecture Behavioral of vga_controller is

    -- HORIZONTAL:
    -- 96 sync + 48 front + 640 image + 16 back
    --  2 sync + 33 front + 480 image + 10 back
    constant HMAX   : natural := 799;
    constant HSYC   : natural := 96; 
    constant HACT   : natural := 144;--152;
    constant HEND   : natural := 784;--792;
    constant VMAX   : natural := 524;
    constant VSYC   : natural := 2;
    constant VACT   : natural := 35;
    constant VEND   : natural := 515;

    signal hcount : std_logic_vector(9 downto 0) := (others => '0');
    signal vcount : std_logic_vector(9 downto 0) := (others => '0');
    signal nextline  : std_logic;
    signal nextframe : std_logic;
    signal pixvalid  : std_logic;
    signal hsync   : std_logic_vector(2 downto 0) := "111";
    signal vsync   : std_logic_vector(2 downto 0) := "111";
    signal hactive : std_logic := '0';
    signal vactive : std_logic := '0';
    signal xcount : std_logic_vector(9 downto 0) := (others => '0');
    signal ycount : std_logic_vector(9 downto 0) := (others => '0');
    signal rpix : std_logic_vector(3 downto 0) := "0000";
    signal gpix : std_logic_vector(3 downto 0) := "0000";
    signal bpix : std_logic_vector(3 downto 0) := "0000";
    signal rgb1  : std_logic_vector(11 downto 0);
    --signal rgb2, rgb3 : std_logic_vector(11 downto 0);
    
    

begin

    -------------------------------------
    -- VGA frame timing
    -------------------------------------
    
    -- counter signals
    nextline  <= '1' when (hcount=HMAX) else '0';
    nextframe <= '1' when ((vcount=VMAX) and (nextline='1')) else '0';
    
    -- horizontal pixel counter (=row counter)
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset='1') then
                hcount <= (others => '0');
            elsif (nextline='1') then
                hcount <= (others => '0');
            else
                hcount <= hcount + '1';
            end if;
        end if;
    end process;
    
    -- vertical pixel counter (= line counter)
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset='1') then
                vcount <= (others => '0');
            elsif (nextframe='1') then
                vcount <= (others => '0');
            elsif (nextline='1') then
                vcount <= vcount + '1';
            end if;
        end if;
    end process;
    
    -- generate sync signals (pipelined)
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset='1') then
                hsync(2 downto 0) <= (others => '0');
                vsync(2 downto 0) <= (others => '0');
            else
                hsync(2 downto 1) <= hsync(1 downto 0);
                vsync(2 downto 1) <= vsync(1 downto 0);                
                if (hcount<HSYC) then
                    hsync(0) <= '0';
                else
                    hsync(0) <= '1';
                end if;
                if (vcount<VSYC) then
                    vsync(0) <= '0';
                else
                    vsync(0) <= '1';
                end if;
            end if;
        end if;
    end process;
    
    -- determine active image area
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset='1') then
                hactive <= '0';
                vactive <= '0';
            else
                if (hcount>=HACT) and (hcount<HEND) then
                    hactive <= '1';
                else
                    hactive <= '0';
                end if;
                if (vcount>=VACT) and (vcount<VEND) then
                    vactive <= '1';
                else
                    vactive <= '0';
                end if;
            end if;
        end if;
    end process;
    
    ---------------------------------
    -- generate colour signals,
    -- active image area
    ---------------------------------
    
    -- x: horizontal active pixel counter
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset='1') or (hactive='0') then
                xcount <= (others => '0');
            else
                xcount <= xcount + '1';
            end if;
        end if;
    end process;
    
    -- y: horizontal active pixel counter
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset='1') or (vactive='0') then
                ycount <= (others => '0');
            else
                ycount <= ycount + nextline;
            end if;
        end if;
    end process;
    
    -- indicate valid pixel positions (= active image area)
    process(clk)
    begin
        if rising_edge(clk) then
            pixvalid <= hactive and vactive;
        end if;
    end process;
    
    -- frame buffer address:
    pixxaddr <= xcount(9 downto 1);
    pixyaddr <= ycount(8 downto 1);
    -- note: 
    -- An image of size 320x240 is read from the camera frame buffer.
    -- The output image size is 640x480 (=VGA).
    -- => 1 input pixel = 2x2 output pixels
    
    -- pixels from frame buffer:
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset='1') or (pixvalid='0') then 
            	-- invalid pixels are black
                rpix <= "0000";
                gpix <= "0000"; -- display test
                bpix <= "0000";
            elsif (debugmode='1') then
                -- activate debug mode to display a test pattern on the screen
                rpix <= rgb1( 3 downto 0);
                gpix <= rgb1( 7 downto 4);
                bpix <= rgb1(11 downto 8);
            else
            	-- pixel data from camera,
                -- assumes RGB565 format
                rpix <= pixdata(15 downto 12); -- red
                gpix <= pixdata(10 downto 7);  -- green
                bpix <= pixdata(4 downto 1);   -- blue
            end if;
        end if;
    end process;
    
    -- debug mode, test pattern generation
    process(clk)
    begin
        if rising_edge(clk) then
            if (xcount(9 downto 1)="000000000") or (xcount(9 downto 1)=319) or
               (ycount(8 downto 1)="00000000") or (ycount(8 downto 1)=239) then
                rgb1 <= "000011111111"; -- yellow border
            else
                rgb1(11 downto 8) <= ycount(5 downto 2); -- blue
                rgb1( 7 downto 0) <= xcount(7 downto 0); -- green+red
            end if;
            --rgb2 <= rgb1;
            --rgb3 <= rgb2;
         end if;
     end process;
    
    -----------------------------------------
    -- VGA output ports
    -----------------------------------------
    vga_red   <= rpix;
    vga_blue  <= bpix;
    vga_green <= gpix;
    vga_hsync <= hsync(2);
    vga_vsync <= vsync(2);

end Behavioral;
