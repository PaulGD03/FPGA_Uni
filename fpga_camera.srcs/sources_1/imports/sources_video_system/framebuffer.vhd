----------------------------------------------------------------------------------
-- image frame buffer
-- resolution = 320x240
-- RGB565 format
-- buffer type = simple dual port memory (SDP) with 1 write port and 1 read port
----------------------------------------------------------------------------------
-- (c) Heiko Hinkelmann
-- Frankfurt University of Applied Sciences
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

entity framebuffer is port(
    -- write port (input; addressing = 320x240 via hsync/vsync)
    wclk   : in  std_logic;
    wen    : in  std_logic;
    vsync  : in  std_logic;
    hsync  : in  std_logic;
    wdata  : in  std_logic_vector(15 downto 0);
    -- read port (output; addressing = 320x240)
    rclk   : in  std_logic;
    rxaddr : in  std_logic_vector(8 downto 0);
    ryaddr : in  std_logic_vector(7 downto 0);
    rdata  : out std_logic_vector(15 downto 0));
end framebuffer;

architecture Behavioral of framebuffer is

    -- define memory buffer of size 512x256
    -- can store a complete image of size 320x240 pixels
    constant SIZE : natural := 512*256;
    
    type memtype is array(0 to SIZE-1) of std_logic_vector(15 downto 0);
    signal mem : memtype := (others => X"0000"); 

    -- signals for write port addressing:
    signal waddr, raddr : std_logic_vector(16 downto 0);
    signal hcount : std_logic_vector(8 downto 0) := (others => '0'); 
    signal vcount : std_logic_vector(7 downto 0) := (others => '0'); 
    signal hs_reg : std_logic := '0';
    signal end_of_line : std_logic;
    
begin

    ------------------------------------------
    -- write port address regeneration
    ------------------------------------------

    -- x address logic: hcount counts pixels per image line
    process(wclk)
    begin
        if rising_edge(wclk) then
            if (hsync='0') then
                hcount <= (others => '0'); -- reset counter in between lines
            elsif (hcount<511) and (wen='1') and (hsync='1') and (vsync='1') then
                hcount <= hcount + '1'; -- counts up to 511 max (319 regular)
            end if;
            hs_reg <= hsync; -- auxiliary register to detect end of line
        end if;
    end process;
    
    end_of_line <= vsync and hs_reg and not hsync; -- detect end of line at falling edge of hsync 
    
    -- y address logic: vcount counts lines per image
    process(wclk)
    begin
        if rising_edge(wclk) then
            if (vsync='0') then
                vcount <= (others => '0'); -- reset counter in between frames
            elsif (vcount<255) and (end_of_line='1') then
                -- counts +1 at end of every line
                vcount <= vcount + '1'; -- counts up to 255 max (239 regular)
            end if;
        end if;
    end process;
    
    ------------------------------------------
    -- write port
    ------------------------------------------
    
    -- write port address
    waddr <= vcount & hcount;
    
    -- write port data access
    process(wclk)
    begin
        if rising_edge(wclk) then
            if (wen='1') then 
                mem(conv_integer(waddr)) <= wdata; -- write data to memory
            end if;
        end if;
    end process;
    
    ------------------------------------------
    -- read port 
    ------------------------------------------
    
    -- read port address
     raddr <= ryaddr & rxaddr;     

    -- read port data access
    process(rclk)
    begin
        if rising_edge(rclk) then
            rdata <= mem(conv_integer(raddr)); -- read data from memory
        end if;
    end process;

end Behavioral;
