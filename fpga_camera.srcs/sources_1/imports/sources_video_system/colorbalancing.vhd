----------------------------------------------------------------------------------
-- Color Balancing / Color Adjustment:
--
-- Multiplies each color (red, green, blue) with a specific gain factor.
-- The gain factors are specied as unsigned numbers
-- in 4.8 fixed point format (4 bit integer part; 8 bit fractional part). 
-- The neutral value of a gain factor is "000100000000" (equals 1.0).
----------------------------------------------------------------------------------
-- (c) Heiko Hinkelmann
-- Frankfurt University of Applied Sciences
-- 25.05.2026
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity colorbalancing is port(
    clk           : in  std_logic;
    gain_red      : in  std_logic_vector(11 downto 0);
    gain_green    : in  std_logic_vector(11 downto 0);
    gain_blue     : in  std_logic_vector(11 downto 0);
    pix_valid_in  : in  std_logic;
    pix_data_in   : in  std_logic_vector(15 downto 0);
    vsync_in      : in  std_logic;
    hsync_in      : in  std_logic;
    pix_valid_out : out std_logic;
    pix_data_out  : out std_logic_vector(15 downto 0);
    vsync_out     : out std_logic;
    hsync_out     : out std_logic);
end colorbalancing;

architecture Behavioral of colorbalancing is

    -- pipeline registers
    signal valid_reg1, valid_reg2 : std_logic := '0'; 
    signal vsync_reg1, vsync_reg2 : std_logic := '0';
    signal hsync_reg1, hsync_reg2 : std_logic := '0';
    -- color-specific control and data signals
    signal ctrl_r, ctrl_g, ctrl_b : std_logic_vector(11 downto 0);
    signal data_r : std_logic_vector(5 downto 0);
    signal data_g : std_logic_vector(5 downto 0);
    signal data_b : std_logic_vector(5 downto 0);
    signal mult_reg_r : std_logic_vector(17 downto 0) := (others => '0');
    signal mult_reg_g : std_logic_vector(17 downto 0) := (others => '0');
    signal mult_reg_b : std_logic_vector(17 downto 0) := (others => '0');
    signal clip_reg_r : std_logic_vector(4 downto 0) := (others => '0');
    signal clip_reg_g : std_logic_vector(5 downto 0) := (others => '0');
    signal clip_reg_b : std_logic_vector(4 downto 0) := (others => '0');

begin
    
    -- extract colors from pix_data_in and extend to 6 bit format
    data_r <= pix_data_in(15 downto 11) & '0';
    data_g <= pix_data_in(10 downto  5);
    data_b <= pix_data_in( 4 downto  0) & '0';
    
    -- pipeline registers for valid, hsync, vsync
    process(clk)
    begin
        if rising_edge(clk) then
            valid_reg1 <= pix_valid_in;
            valid_reg2 <= valid_reg1;
            hsync_reg1 <= hsync_in;
            hsync_reg2 <= hsync_reg1;
            vsync_reg1 <= vsync_in;
            vsync_reg2 <= vsync_reg1;
        end if;
    end process;
    
    ---------------------------------------------
    -- pipeline stage 1: apply color gains
    ---------------------------------------------
    
    -- multipliers with output registers
    process(clk) 
    begin
        if rising_edge(clk) then
            mult_reg_r <= gain_red   * data_r;
            mult_reg_g <= gain_green * data_g;
            mult_reg_b <= gain_blue  * data_b;
        end if;
    end process;
    
    ---------------------------------------------
    -- pipeline stage 2: clipping
    ---------------------------------------------
    -- Color values which are too large are
    -- clipped to maximal allowed value.
    ---------------------------------------------
    
    -- RED
    process(clk)
    begin
        if rising_edge(clk) then
            -- if resulting sum is larger than maximum ...
            if (mult_reg_r(17 downto 14)/="0000") then
                clip_reg_r <= "11111"; -- ... clip to maximum
            else
                clip_reg_r <= mult_reg_r(13 downto 9);
            end if;
        end if;
    end process;
    
    -- GREEN
    process(clk)
    begin
        if rising_edge(clk) then
            -- if resulting sum is larger than maximum ...
            if (mult_reg_g(17 downto 14)/="0000") then
                clip_reg_g <= "111111"; -- ... clip to maximum
            else
                clip_reg_g <= mult_reg_g(13 downto 8);
            end if;
        end if;
    end process;
    
    -- BLUE
    process(clk)
    begin
        if rising_edge(clk) then
            -- if resulting sum is larger than maximum ...
            if (mult_reg_b(17 downto 14)/="0000") then
                clip_reg_b <= "11111"; -- ... clip to maximum
            else
                clip_reg_b <= mult_reg_b(13 downto 9);
            end if;
        end if;
    end process;
    
    ---------------------------------------------
    -- output signals
    ---------------------------------------------
    pix_data_out  <= clip_reg_r & clip_reg_g & clip_reg_b;
    pix_valid_out <= valid_reg2;
    vsync_out <= vsync_reg2; 
    hsync_out <= hsync_reg2;

end Behavioral;
