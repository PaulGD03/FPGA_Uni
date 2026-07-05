----------------------------------------------------------------------------------
-- Company:  Frankfurt University of Applied Sciences
-- Engineer: Heiko Hinkelmann 
-- 
-- Latest Update: 07.04.2022
-- Module Name: i2c_tx - Behavioral
----------------------------------------------------------------------------------
-- Description:
-- Master / Sender for a 2-wire interface called
-- "OV7670 Serial Camera Control Bus (SCCB) interface".
-- Very similar to I2C.
-- This module configures the OV7670 camera register settings
-- by transmitting the configuration data serially over the SCCB interface.               
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

entity i2c_tx is 
generic(
    bytes     : natural := 2); 
    -- number of data bytes to be sent, excluding device ID. 
    -- maximum allowed is 6, otherwise enlarge bitcount.
port(
    clk    : in    std_logic;
    data   : in    std_logic_vector(bytes*8-1 downto 0); -- data to be sent
    start  : in    std_logic; -- start a new i2c access
    ready  : out   std_logic; -- 1=ready for new i2c access; 0=busy
    -- 2-wire-interface:
    sclk   : out   std_logic;  -- serial clock
    sdata  : inout std_logic); -- serial data
end i2c_tx;

architecture Behavioral of i2c_tx is

    constant device_id : std_logic_vector(7 downto 0) := X"42";
    -- device ID of the OV7670 camera is X"42".
    
    constant quarterperiod : natural := 32;
    -- clock frequency / i2c frequency / 4 - 1 (rounded up)
    -- input clock frequency is 50 MHz
    -- target OV7670 camera i2c frequency is 400 kHz
  
    -- timing control signals
    signal timer : std_logic_vector(7 downto 0) := (others => '0');
    signal phase : std_logic_vector(1 downto 0) := "00";
    signal timer_tick : std_logic := '0';
    signal nextbit : std_logic;
    -- bit counting
    signal bitcount : std_logic_vector(5 downto 0) := "000000";
    signal last_bit_of_byte : std_logic;
    signal last_byte : std_logic;
    
    -- flow control: state machine
    type   state_type is (idle, startbit, w_data, w_ack, stopbit, pause);
    signal state : state_type := idle;
    signal nextstate : state_type;
    signal start_valid : std_logic;
        
    -- shift register
    signal sreg : std_logic_vector(bytes*8+7 downto 0);
    signal shift : std_logic;
    
    -- serial output signals
    signal scl  : std_logic := '1'; -- sclk reg
    signal sda  : std_logic := '1'; -- sdata reg
    signal sden : std_logic := '0'; -- sdata enable (1=active, 0=disabled)
    
begin

    -------------------------------------
    -- bit timing
    -------------------------------------
    
    -- The timer counts a quarter of a bit period.
    -- A complete bit period consists of four quarters named "phases": 00, 01, 10, 11. 

    process(clk)
    begin
        if rising_edge(clk) then
            if (state=idle) then
                -- reset all timers
                timer <= (others => '0');
                timer_tick <= '0';
            elsif (timer=quarterperiod) then
                 -- every quarter of a bit period
                timer <= (others => '0');
                timer_tick <= '1';
            else
                timer <= timer + '1';
                timer_tick <= '0';
            end if;
            if (state=idle) then
                phase <= "00";
            elsif (timer_tick='1') then
                phase <= phase + '1';
            end if;
        end if;
    end process;
    
    nextbit <= timer_tick and phase(1) and phase(0);
    
    -------------------------------------
    -- bit counter (maximum is 6 bytes)
    -------------------------------------
    
    -- Counts all data bits of one i2c access.
    -- Start, stop, and ACK bits are not counted.
    -- Note: Maximum allowed is 6 bytes, otherwise bitcount width must be enlarged.
    
    process(clk)
    begin
        if rising_edge(clk) then
            if (start_valid='1') then
                bitcount <= "000000";
            elsif (shift='1') and (nextbit='1') then
                bitcount <= bitcount + '1';
            end if;
        end if;
    end process;
    
    last_bit_of_byte <= '1' when (bitcount(2 downto 0)="111") else '0';
    last_byte <= '1' when (bitcount(5 downto 3)>bytes) else '0'; 
    
    ----------------------------------------
    -- state machine for i2c write access
    ----------------------------------------
    
    start_valid <= '1' when ((state=idle) and (start='1')) else '0';
    
    -- state register:
    process(clk)
    begin
        if rising_edge(clk) then
            if (start_valid='1') or (nextbit='1') then
                state <= nextstate;
            end if;
        end if;
    end process;
    
    -- next-state logic 
    process(all)
    begin
        case state is
        when idle => 
            -- waiting for the start of a new i2c access
            if (start='1') then
                nextstate <= startbit;
            else
                nextstate <= idle;
            end if;
        when startbit => nextstate <= w_data; -- send startbit
        when w_data => -- send data bits
            if (last_bit_of_byte='1') then
                nextstate <= w_ack;
            else
                nextstate <= w_data;
            end if;
        when w_ack => -- send ACK bit
            if (last_byte='1') then
                nextstate <= stopbit;
            else
                nextstate <= w_data;
            end if;
        when stopbit => nextstate <= pause; -- send stopbit
        when pause => nextstate <= idle; -- pause 1 bit period before next i2c access may start
        when others => nextstate <= idle;
        end case;
    end process;
    
    ----------------------------------------------------------
    -- output signals of state machine
    -- * SCL, SDA, SDA_en (for 2-wire serial output)
    -- * shift-enable used by shift register
    -- * ready
    ----------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            case state is
            when startbit =>
                scl   <= not (phase(1) and phase(0)); -- 1.1.1.0
                sda   <= not phase(1);                -- 1.1.0.0
                sden  <= '1';
                shift <= '0';
            when w_data =>
                scl   <= phase(1) xor phase(0); -- 0.1.1.0
                sda   <= sreg(sreg'high);       -- data bit
                sden  <= '1';
                shift <= '1';
            when w_ack => 
                scl   <= phase(1) xor phase(0); -- 0.1.1.0
                sda   <= '1'; -- disabled
                sden  <= '0';
                shift <= '0';
            when stopbit => 
                scl   <= phase(1) or phase(0); -- 0.1.1.1
                sda   <= phase(1);             -- 0.0.1.1 
                sden  <= '1'; 
                shift <= '0';
            when others =>  -- idle, pause, others
                scl   <= '1'; -- 1.1.1.1
                sda   <= '1'; -- disabled
                sden  <= '0';  
                shift <= '0';
            end case;
        end if;
    end process;
    
    sclk  <= scl;
    sdata <= sda when (sden='1') else 'Z'; -- tristate logic
    -- driver is active when sden=1
    -- driver is high impedance if sden=0
    
    ready <= '1' when (state=idle) else '0';
    -- module is ready to start a new i2c transmission
    
    --------------------------------------------
    -- shift register, for serial data
    --------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if (start_valid='1') then
                sreg(sreg'high downto sreg'high-7) <= device_id;
                sreg(sreg'high-8 downto 0) <= data;
            elsif ((shift='1') and (nextbit='1')) then
                sreg <= sreg(sreg'high-1 downto 0) & sdata;
            end if;
        end if;
    end process; 
            
end Behavioral;
