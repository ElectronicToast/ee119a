--------------------------------------------------------------------------------
-- bitserme_tb.vhd - n-bit Bit-Serial Multiplier Testbench
--
-- This is a testbench for the n-bit bit-serial multiplier defined by the 
-- entity `bitserme` with architecture `DataFlow`. It thorougly tests the 
-- entity by exhaustively computing and checking the products of all unsigned 
-- integers of up to a generic constant number of bits.
--
-- The testbench contains two architectures, one which exhaustively
-- tests all possible multiplications of two n-bit numbers, and one which 
-- tests edge cases.
--
-- Table of Contents:
--      entity          BitSerialMultiplier_Tb
--      architecture    TB_EXHAUSTIVE       Exhaustive tests n-bit serial 
--                                          multiplication by multiplying all 
--                                          combinations of two n-bit numbers
--      architecture    TB_EDGECASES        Tests edge cases of n-bit serial 
--                                          multiplication; namely,
--                                              0...0 * 0...0 = 0........0
--                                              0...1 * 0...0 = 0........0
--                                              0...0 * 0...1 = 0........0
--                                              0...1 * 0...1 = 0........1
--                                              1...1 * 0...1 = 0...01...1
--                                              0...1 * 1...1 = 0...01...1
--                                              1...1 * 1...1 = [(2^n -1)^2]                                   
--
-- Notes:
--      - This testbench was ran with ModelSim-Altera.
--
-- Revision History:
--      11/21/2018      Ray Sun     Initial revision.
--      11/22/2018      Ray Sun     Replaced single test with an exhaustive 
--                                  double nested for loop once UUT confirmed
--                                  working.
--      11/22/2018      Ray Sun     Verified UUT functionality exhaustively 
--                                  for `numbits` up to 4.
--      11/22/2018      Ray Sun     Added another architecture for testing 
--                                  edge cases for large numbers of bits 
--                                  where testing exhaustively may be 
--                                  prohibitive.
--------------------------------------------------------------------------------


library ieee;                   -- Import the requisite packages
use ieee.std_logic_1164.all;    -- For 9-valued logic types
use ieee.numeric_std.all;       -- For numeric types


--------------------------------------------------------------------------------


entity BitSerialMultiplier_Tb is 
    generic(
        -- Number of bits of multiplicand/multiplier to test
        NUM_BITS_TEST:  integer := 10
    );
end entity;


--------------------------------------------------------------------------------
--                        EXHAUSTIVE TEST ARCHITECTURE                        --
--------------------------------------------------------------------------------


architecture TB_EXHAUSTIVE of BitSerialMultiplier_Tb is 
    constant CLOCK_PERIOD:      time := 10 ns;
    constant CLOCK_HALFPER:     time := CLOCK_PERIOD / 2;
    
    constant SL_ZERO:           std_logic := '0';
    constant SL_LOW:            std_logic := '0';
    constant SL_HIGH:           std_logic := '1';
    constant Q_CLEARED:         std_logic_vector(2*NUM_BITS_TEST-1 downto 0)
                                := (others => '0');
    
    signal   END_SIM:           boolean := FALSE;       -- End-of-sim flag
    
    ------------------------- STIMULUS SIGNALS ---------------------------------
    signal CLK:     std_logic;
    signal START:   std_logic;
    signal A:       std_logic_vector(NUM_BITS_TEST-1 downto 0);
    signal B:       std_logic_vector(NUM_BITS_TEST-1 downto 0);
    ----------------------------------------------------------------------------
    
    ------------------------- OBSERVED SIGNALS ---------------------------------
    signal DONE:    std_logic;
    signal Q:       std_logic_vector(2*NUM_BITS_TEST-1 downto 0);
    ----------------------------------------------------------------------------
    
    ----------------------------TEST SIGNALS -----------------------------------
    -- The expected product of multiplication
    signal TESTPRODUCT:     integer;
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
        wait for 2*CLOCK_PERIOD;
        
        -- Check that DONE is not active
        assert (std_match(DONE, SL_LOW))
                report  "Test Failure - DONE not inactive"
                severity  ERROR;
        
        -- Now loop to exhaustively test NUM_BITS_TEST-bit multiplication
        for i in 0 to (2**NUM_BITS_TEST)-1 loop
            for j in 0 to (2**NUM_BITS_TEST)-1 loop
                -- Precompute the test product
                TESTPRODUCT <= i * j;
                
                -- Set up the multiplicand and multiplier
                A <= std_logic_vector(to_unsigned(i, NUM_BITS_TEST));
                B <= std_logic_vector(to_unsigned(j, NUM_BITS_TEST));
                
                -- Wait a few clocks
                wait for 2*CLOCK_PERIOD;
                
                -- Start the multiplication
                START <= SL_HIGH;
                wait for CLOCK_PERIOD;
                START <= SL_LOW;
                
                -- Wait for a half period to check outputs
                wait for CLOCK_HALFPER;
                -- Check that the product buffer is cleared
                assert (std_match(Q, Q_CLEARED))
                        report  "Test Failure - Q not cleared"
                        severity  ERROR;
                -- Check that DONE is not active
                assert (std_match(DONE, SL_LOW))
                        report  "Test Failure - DONE not inactive"
                        severity  ERROR;
                
                -- Wait for the multiplication to complete
                wait until DONE = SL_HIGH;
                
                -- Wait for a half period to check the output
                wait for CLOCK_HALFPER;
                -- Check that the product matches the expected result
                assert (std_match(
                    Q, 
                    std_logic_vector(
                            to_unsigned(TESTPRODUCT, 2*NUM_BITS_TEST)) )
                    )
                        report  "Test Failure - Incorrect product"
                        severity  ERROR;
                        
                -- Wait for a few clocks before repeating
                wait for 3*CLOCK_PERIOD;
            end loop;
        end loop;
        -- When done, set end of sim flag
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


--------------------------------------------------------------------------------
--                        EDGE CASES TEST ARCHITECTURE                        --
--------------------------------------------------------------------------------


architecture TB_EDGECASES of BitSerialMultiplier_Tb is 
    constant CLOCK_PERIOD:      time := 10 ns;
    constant CLOCK_HALFPER:     time := CLOCK_PERIOD / 2;
    
    constant SL_ZERO:           std_logic := '0';
    constant SL_ONE:            std_logic := '1';
    constant SL_LOW:            std_logic := '0';
    constant SL_HIGH:           std_logic := '1';
    constant Q_CLEARED:         std_logic_vector(2*NUM_BITS_TEST-1 downto 0)
                                := (others => '0');
    
    signal   END_SIM:           boolean := FALSE;       -- End-of-sim flag
    
    ------------------------- STIMULUS SIGNALS ---------------------------------
    signal CLK:     std_logic;
    signal START:   std_logic;
    signal A:       std_logic_vector(NUM_BITS_TEST-1 downto 0);
    signal B:       std_logic_vector(NUM_BITS_TEST-1 downto 0);
    ----------------------------------------------------------------------------
    
    ------------------------- OBSERVED SIGNALS ---------------------------------
    signal DONE:    std_logic;
    signal Q:       std_logic_vector(2*NUM_BITS_TEST-1 downto 0);
    ----------------------------------------------------------------------------
    
    ----------------------------TEST SIGNALS -----------------------------------
    -- The expected product of multiplication
    signal TESTPRODUCT:     integer;
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
        wait for 2*CLOCK_PERIOD;
        
        -- Check that DONE is not active
        assert (std_match(DONE, SL_LOW))
                report  "Test Failure - DONE not inactive"
                severity  ERROR;
        
        ------------------------------------------------------------------------
        
        -- Now test multiplication of all zeroes
        TESTPRODUCT <= 0;
        A <= (others => SL_ZERO);
        B <= (others => SL_ZERO);
        
        -- Wait a few clocks
        wait for 2*CLOCK_PERIOD;
        
        -- Start the multiplication
        START <= SL_HIGH;
        wait for CLOCK_PERIOD;
        START <= SL_LOW;
        
        -- Wait for a half period to check outputs
        wait for CLOCK_HALFPER;
        -- Check that the product buffer is cleared
        assert (std_match(Q, Q_CLEARED))
                report  "Test Failure - Q not cleared"
                severity  ERROR;
        -- Check that DONE is not active
        assert (std_match(DONE, SL_LOW))
                report  "Test Failure - DONE not inactive"
                severity  ERROR;
        
        -- Wait for the multiplication to complete
        wait until DONE = SL_HIGH;
        
        -- Wait for a half period to check the output
        wait for CLOCK_HALFPER;
        -- Check that the product matches the expected result
        assert (std_match(
            Q, 
            std_logic_vector(
                    to_unsigned(TESTPRODUCT, 2*NUM_BITS_TEST)) )
            )
                report  "Test Failure - Incorrect product"
                severity  ERROR;
                
        -- Wait for a few clocks before continuing
        wait for 3*CLOCK_PERIOD;
        
        ------------------------------------------------------------------------
        
        -- Now test multiplication of 0...1 * 0...0
        TESTPRODUCT <= 0;
        A <= (0 => SL_ONE, others => SL_ZERO);
        B <= (others => SL_ZERO);
        
        -- Wait a few clocks
        wait for 2*CLOCK_PERIOD;
        
        -- Start the multiplication
        START <= SL_HIGH;
        wait for CLOCK_PERIOD;
        START <= SL_LOW;
        
        -- Wait for a half period to check outputs
        wait for CLOCK_HALFPER;
        -- Check that the product buffer is cleared
        assert (std_match(Q, Q_CLEARED))
                report  "Test Failure - Q not cleared"
                severity  ERROR;
        -- Check that DONE is not active
        assert (std_match(DONE, SL_LOW))
                report  "Test Failure - DONE not inactive"
                severity  ERROR;
        
        -- Wait for the multiplication to complete
        wait until DONE = SL_HIGH;
        
        -- Wait for a half period to check the output
        wait for CLOCK_HALFPER;
        -- Check that the product matches the expected result
        assert (std_match(
            Q, 
            std_logic_vector(
                    to_unsigned(TESTPRODUCT, 2*NUM_BITS_TEST)) )
            )
                report  "Test Failure - Incorrect product"
                severity  ERROR;
                
        -- Wait for a few clocks before continuing
        wait for 3*CLOCK_PERIOD;
        
        ------------------------------------------------------------------------
        
        -- Now test multiplication of 0...0 * 0...1
        TESTPRODUCT <= 0;
        A <= (others => SL_ZERO);
        B <= (0 => SL_ONE, others => SL_ZERO);
        
        -- Wait a few clocks
        wait for 2*CLOCK_PERIOD;
        
        -- Start the multiplication
        START <= SL_HIGH;
        wait for CLOCK_PERIOD;
        START <= SL_LOW;
        
        -- Wait for a half period to check outputs
        wait for CLOCK_HALFPER;
        -- Check that the product buffer is cleared
        assert (std_match(Q, Q_CLEARED))
                report  "Test Failure - Q not cleared"
                severity  ERROR;
        -- Check that DONE is not active
        assert (std_match(DONE, SL_LOW))
                report  "Test Failure - DONE not inactive"
                severity  ERROR;
        
        -- Wait for the multiplication to complete
        wait until DONE = SL_HIGH;
        
        -- Wait for a half period to check the output
        wait for CLOCK_HALFPER;
        -- Check that the product matches the expected result
        assert (std_match(
            Q, 
            std_logic_vector(
                    to_unsigned(TESTPRODUCT, 2*NUM_BITS_TEST)) )
            )
                report  "Test Failure - Incorrect product"
                severity  ERROR;
                
        -- Wait for a few clocks before continuing
        wait for 3*CLOCK_PERIOD;
        
        ------------------------------------------------------------------------
        
        -- Now test multiplication of 0...1 * 0...1
        TESTPRODUCT <= 1;
        A <= (0 => SL_ONE, others => SL_ZERO);
        B <= (0 => SL_ONE, others => SL_ZERO);
        
        -- Wait a few clocks
        wait for 2*CLOCK_PERIOD;
        
        -- Start the multiplication
        START <= SL_HIGH;
        wait for CLOCK_PERIOD;
        START <= SL_LOW;
        
        -- Wait for a half period to check outputs
        wait for CLOCK_HALFPER;
        -- Check that the product buffer is cleared
        assert (std_match(Q, Q_CLEARED))
                report  "Test Failure - Q not cleared"
                severity  ERROR;
        -- Check that DONE is not active
        assert (std_match(DONE, SL_LOW))
                report  "Test Failure - DONE not inactive"
                severity  ERROR;
        
        -- Wait for the multiplication to complete
        wait until DONE = SL_HIGH;
        
        -- Wait for a half period to check the output
        wait for CLOCK_HALFPER;
        -- Check that the product matches the expected result
        assert (std_match(
            Q, 
            std_logic_vector(
                    to_unsigned(TESTPRODUCT, 2*NUM_BITS_TEST)) )
            )
                report  "Test Failure - Incorrect product"
                severity  ERROR;
                
        -- Wait for a few clocks before continuing
        wait for 3*CLOCK_PERIOD;
        
        ------------------------------------------------------------------------
        
        -- Now test multiplication of 1...1 * 0...1
        TESTPRODUCT <= 2**NUM_BITS_TEST - 1;
        A <= (others => SL_ONE);
        B <= (0 => SL_ONE, others => SL_ZERO);
        
        -- Wait a few clocks
        wait for 2*CLOCK_PERIOD;
        
        -- Start the multiplication
        START <= SL_HIGH;
        wait for CLOCK_PERIOD;
        START <= SL_LOW;
        
        -- Wait for a half period to check outputs
        wait for CLOCK_HALFPER;
        -- Check that the product buffer is cleared
        assert (std_match(Q, Q_CLEARED))
                report  "Test Failure - Q not cleared"
                severity  ERROR;
        -- Check that DONE is not active
        assert (std_match(DONE, SL_LOW))
                report  "Test Failure - DONE not inactive"
                severity  ERROR;
        
        -- Wait for the multiplication to complete
        wait until DONE = SL_HIGH;
        
        -- Wait for a half period to check the output
        wait for CLOCK_HALFPER;
        -- Check that the product matches the expected result
        assert (std_match(
            Q, 
            std_logic_vector(
                    to_unsigned(TESTPRODUCT, 2*NUM_BITS_TEST)) )
            )
                report  "Test Failure - Incorrect product"
                severity  ERROR;
                
        -- Wait for a few clocks before continuing
        wait for 3*CLOCK_PERIOD;
        
        ------------------------------------------------------------------------
        
        -- Now test multiplication of 0...1 * 1...1
        TESTPRODUCT <= 2**NUM_BITS_TEST - 1;
        A <= (0 => SL_ONE, others => SL_ZERO);
        B <= (others => SL_ONE);
        
        -- Wait a few clocks
        wait for 2*CLOCK_PERIOD;
        
        -- Start the multiplication
        START <= SL_HIGH;
        wait for CLOCK_PERIOD;
        START <= SL_LOW;
        
        -- Wait for a half period to check outputs
        wait for CLOCK_HALFPER;
        -- Check that the product buffer is cleared
        assert (std_match(Q, Q_CLEARED))
                report  "Test Failure - Q not cleared"
                severity  ERROR;
        -- Check that DONE is not active
        assert (std_match(DONE, SL_LOW))
                report  "Test Failure - DONE not inactive"
                severity  ERROR;
        
        -- Wait for the multiplication to complete
        wait until DONE = SL_HIGH;
        
        -- Wait for a half period to check the output
        wait for CLOCK_HALFPER;
        -- Check that the product matches the expected result
        assert (std_match(
            Q, 
            std_logic_vector(
                    to_unsigned(TESTPRODUCT, 2*NUM_BITS_TEST)) )
            )
                report  "Test Failure - Incorrect product"
                severity  ERROR;
                
        -- Wait for a few clocks before continuing
        wait for 3*CLOCK_PERIOD;
        
        ------------------------------------------------------------------------
        
        -- Now test multiplication of 1...1 * 1...1
        TESTPRODUCT <= (2**NUM_BITS_TEST - 1)**2;
        A <= (others => SL_ONE);
        B <= (others => SL_ONE);
        
        -- Wait a few clocks
        wait for 2*CLOCK_PERIOD;
        
        -- Start the multiplication
        START <= SL_HIGH;
        wait for CLOCK_PERIOD;
        START <= SL_LOW;
        
        -- Wait for a half period to check outputs
        wait for CLOCK_HALFPER;
        -- Check that the product buffer is cleared
        assert (std_match(Q, Q_CLEARED))
                report  "Test Failure - Q not cleared"
                severity  ERROR;
        -- Check that DONE is not active
        assert (std_match(DONE, SL_LOW))
                report  "Test Failure - DONE not inactive"
                severity  ERROR;
        
        -- Wait for the multiplication to complete
        wait until DONE = SL_HIGH;
        
        -- Wait for a half period to check the output
        wait for CLOCK_HALFPER;
        -- Check that the product matches the expected result
        assert (std_match(
            Q, 
            std_logic_vector(
                    to_unsigned(TESTPRODUCT, 2*NUM_BITS_TEST)) )
            )
                report  "Test Failure - Incorrect product"
                severity  ERROR;
                
        -- Wait for a few clocks before continuing
        wait for 3*CLOCK_PERIOD;
        
        ------------------------------------------------------------------------
        
        -- When done, set end of sim flag
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