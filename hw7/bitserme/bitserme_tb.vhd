--------------------------------------------------------------------------------
-- bitserme_tb.vhd - n-bit Bit-Serial Multiplier Testbench
--
-- This is a testbench for the n-bit bit-serial multiplier defined by the 
-- entity `bitserme` with architecture `DataFlow`. It thorougly tests the 
-- entity by exhaustively computing and checking the products of all unsigned 
-- integers of up to a generic constant number of bits.
--
-- Revision History:
--      11/21/2018      Ray Sun     Initial revision.
--------------------------------------------------------------------------------

library ieee;                   -- Import the requisite packages
use ieee.std_logic_1164.all;    -- For 9-valued logic types
use ieee.numeric_std.all;       -- For numeric types

--------------------------------------------------------------------------------

entity BitSerialMultiplier_Tb is 
    generic(
        -- Number of bits of multiplicand/multiplier to test
        NUM_BITS_TEST:  integer := 3
    );
end entity;

--------------------------------------------------------------------------------

architecture TB_ARCHITECTURE of BitSerialMultiplier_Tb is 
    constant CLOCK_PERIOD:      time := 10 ns;
    constant CLOCK_HALFPER:     time := CLOCK_PERIOD / 2;
    
    constant SL_ZERO:           std_logic := '0';
    constant SL_LOW:            std_logic := '0';
    constant SL_HIGH:           std_logic := '1';
    constant Q_CLEARED:         std_logic_vector(2*NUM_BITS_TEST-1 downto 0)
                                := (others => '0');
    -- Integer array type to hold test values
    type int_array is array (natural range <>) of integer;
    
    signal   END_SIM:           boolean := FALSE;       -- End-of-sim flag
    
    ------------------------- STIMULUS SIGNALS ---------------------------------
    signal CLK:     std_logic;
    signal START:   std_logic;
    signal DONE:    std_logic;
    signal A:       std_logic_vector(NUM_BITS_TEST-1 downto 0);
    signal B:       std_logic_vector(NUM_BITS_TEST-1 downto 0);
    signal Q:       std_logic_vector(2*NUM_BITS_TEST-1 downto 0);
    ----------------------------------------------------------------------------

    --------------------- UNIT UNDER TEST COMPONENT ----------------------------
    component BitSerialMultiplier is
        generic (
            numbits : integer
        );
        port (
            A     : in     std_logic_vector(numbits-1 downto 0);   
            B     : in     std_logic_vector(numbits-1 downto 0);   
            START : in     std_logic;                              
            CLK   : in     std_logic;                              
            Q     : buffer std_logic_vector(2*numbits-1 downto 0); 
            DONE  : out    std_logic                               
        );
    end component;
    ----------------------------------------------------------------------------
begin
    
    --------------------- UNIT UNDER TEST PORT MAP -----------------------------
    UUT : BitSerialMultiplier
        generic map(
            numbits => NUM_BITS_TEST
        )
        port map(
            A     => A,    
            B     => B,    
            START => START,
            CLK   => CLK,  
            Q     => Q,    
            DONE  => DONE
        );
    ----------------------------------------------------------------------------
        
    ------------------------ MAIN TEST PROCESS ---------------------------------
    process 
    begin 
        -- Initially set everything to 0 and inactive 
        A <= (others => '0');
        B <= (others => '0');
        START <= SL_LOW;
        
        -- Wait for some clocks
        wait for 20 ns;
        
        -- Check that the product buffer is cleared
        assert (std_match(Q, Q_CLEARED))
                report  "Test Failure - Q not cleared"
                severity  ERROR;
        -- Check that DONE is not active
        assert (std_match(DONE, SL_LOW))
                report  "Test Failure - DONE not inactive"
                severity  ERROR;
        
        A <= (others => '1');
        B <= (others => '1');
        
        wait for 20 ns;
        
        START <= SL_HIGH;
        wait for 20 ns;
        START <= SL_LOW;
        
        wait for 200 ns;
                
        -- Set end of sim flag
        END_SIM <= TRUE;
        wait;
    end process;
    ----------------------------------------------------------------------------
    
    ------------------------ CLOCK GEN PROCESS ---------------------------------
    CLOCK_CLK : process
    begin
        -- This process generates a `CLOCK_PERIOD` ns period, 
        -- 50% duty cycle clock. Only generate clock if still simulating.
        if END_SIM = FALSE then
            CLK <= '0';
            wait for CLOCK_HALFPER;
        else
            wait;
        end if;
        if END_SIM = FALSE then
            CLK <= '1';
            wait for CLOCK_HALFPER;
        else
            wait;
        end if;
    end process;
    ----------------------------------------------------------------------------
end architecture;