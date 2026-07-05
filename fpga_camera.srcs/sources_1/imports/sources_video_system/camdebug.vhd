----------------------------------------------------------------------------------
-- small test module
--
-- description: status LED blinks if camera is delivering images
--
-- optional / not required for regular camera operation
--
-- written by H. Hinkelmann / FRA-UAS
-- 2019
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;


entity camdebug is port(
    pclk  : in  std_logic;
    vsync : in  std_logic;
    led   : out std_logic);
end camdebug;

architecture Behavioral of camdebug is

    signal vprev : std_logic := '0';
    signal vcount : std_logic_vector(4 downto 0) := (others => '0');

begin

    led <= vcount(4);  -- camera delivering images -> blink every 16th frame
    
    process(pclk)
    begin
        if rising_edge(pclk) then
            vprev <= vsync;
            if (vprev='1') and (vsync='0') then
                vcount <= vcount + '1';
            end if;
        end if;
    end process;

end Behavioral;
