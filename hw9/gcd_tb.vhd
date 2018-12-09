--------------------------------------------------------------------------------
--                                 gcd_tb.vhd                                 --
--                          GCD Calculator Testbench                          --
--------------------------------------------------------------------------------
--
-- Description:
--      This is a testbench for the N-bit GCD calculator defined by the entity 
--      `Gcd` with architecture `DataFlow`. It thoroughly tests the entity by 
--      testing GCD calculations on edge cases and randomly generated test 
--      cases in a set of test vectors.
--
-- Table of Contents
--      entity              Gcd_Tb
--      architecture        TB_ARCHITECTURE
--
-- Notes:
--      - This testbench was ran with ModelSim-Altera.
--      - For best results (not waiting for several minutes for the simulation 
--        to run), adjust the `resolution` selector to `100 ns` in the 
--        dialog that prompts for the architecture to simulate.
--      - To disable warnings due to uninitialized `unsigned` signals in the 
--        UUT from the ModelSim TCL environment, execute the command
--                          > set NumericStdNoWarnings 1
--
-- Revision History:
--      12/07/2018          Ray Sun         Initial revision.
--      12/08/2018          Ray Sun         Added more tests.
--      12/08/2018          Ray Sun         Added comprehensive set of edge 
--                                          case tests.
--------------------------------------------------------------------------------


library ieee;                   -- Import the requisite packages
use ieee.std_logic_1164.all;    -- For 9-valued logic types
use ieee.numeric_std.all;       -- For unsigned type


--------------------------------------------------------------------------------


entity Gcd_Tb is 
end entity;


--------------------------------------------------------------------------------


architecture TB_ARCHITECTURE of Gcd_Tb is 

    ---------------------------- CONSTANTS -------------------------------------
    -- System clock constants
    constant CLOCK_PERIOD  :    time := 500 ns;   -- System clock, 2 MHz
    constant CLOCK_HALFPER :    time := CLOCK_PERIOD / 2;
    
    -- High and low times for the CanReadVals signal 
    --      These values are for the actual physical system
    constant T_CRV_HIGH    :    time := (32000) * CLOCK_PERIOD;
    constant T_CRV_LOW     :    time := (400000 - 32000) * CLOCK_PERIOD;
    
    -- Test constants 
    constant N_BITS_TEST   :    integer := 16;  -- Number of bits in operands   
    constant N_TESTVECS    :    integer := 24;  -- Number of tests
    ----------------------------------------------------------------------------
    
    ------------------------------ TYPES ---------------------------------------
    -- Type for arrays of test vectors
    type tv_array is array (0 to N_TESTVECS-1) of 
                     std_logic_vector(N_BITS_TEST-1 downto 0);
    ----------------------------------------------------------------------------
    
    ------------------------- STIMULUS SIGNALS ---------------------------------
    signal SysClk       :   std_logic;
    signal A            :   std_logic_vector(N_BITS_TEST-1 downto 0);
    signal B            :   std_logic_vector(N_BITS_TEST-1 downto 0);
    signal nCalculate   :   std_logic;
    signal CanReadVals  :   std_logic;
    ----------------------------------------------------------------------------
    
    ------------------------- OBSERVED SIGNALS ---------------------------------
    signal Result       :   std_logic_vector(N_BITS_TEST-1 downto 0);
    signal ResultRdy    :   std_logic;
    ----------------------------------------------------------------------------
    
    --------------------------- TEST SIGNALS -----------------------------------
    signal END_SIM      :   boolean := FALSE;       -- End-of-sim flag
    -- The expected GCD of each calculation
    signal ExpectedGcd  :   std_logic_vector(N_BITS_TEST-1 downto 0);
    ----------------------------------------------------------------------------
    
    --------------------------- TEST VECTORS -----------------------------------
    -- Test edge cases and some primes, coprimes, small composites, and 
    -- highly composite values.
    --
    --  (1) GCD(0, 0) = 0; GCD(a, 0) = GCD(0, a) = a
    --  (2) GCD(a, 1) = GCD(1, a) = a; GCD(a, a) = a
    --  (3) Primes and coprimes
    --  (4) The composite cases from the example handout
    --- (5) Composites
    --
    -- Operand A test values
    constant A_VALS : tv_array := (
        -- Test GCD(0, 0) = 0 and GCD(a, 0) = GCD(0, a) = a
        x"0000", x"0001", x"0000", x"FFFF", x"0000", x"DEAD", x"0000",
        -- Test edge cases
        x"0001", x"FFFF", x"0001", x"AFAF", x"0001", x"C001", x"00FF",
        -- Primes and coprimes
        std_logic_vector(to_unsigned(61,    N_BITS_TEST)), 
        std_logic_vector(to_unsigned(9929,  N_BITS_TEST)),
        std_logic_vector(to_unsigned(21819, N_BITS_TEST)),
        -- Test examples
        std_logic_vector(to_unsigned(255,   N_BITS_TEST)), 
        std_logic_vector(to_unsigned(60,    N_BITS_TEST)), 
        std_logic_vector(to_unsigned(25,    N_BITS_TEST)), 
        std_logic_vector(to_unsigned(64,    N_BITS_TEST)),
        -- Composites 
        std_logic_vector(to_unsigned(12,    N_BITS_TEST)),
        std_logic_vector(to_unsigned(48000, N_BITS_TEST)),
        std_logic_vector(to_unsigned(41314, N_BITS_TEST))
    );
        
    -- Operand B test values
    constant B_VALS : tv_array := (
        -- Test GCD(0, 0) = 0 and GCD(a, 0) = GCD(0, a) = a
        x"0000", x"0000", x"0001", x"0000", x"FFFF", x"0000", x"BEEF", 
        -- Test edge cases
        x"0001", x"0001", x"FFFF", x"0001", x"1F80", x"C001", x"00FF",
        -- Primes and coprimes
        std_logic_vector(to_unsigned(17,    N_BITS_TEST)), 
        std_logic_vector(to_unsigned(47917, N_BITS_TEST)), 
        std_logic_vector(to_unsigned(20243, N_BITS_TEST)),
        -- Test examples
        std_logic_vector(to_unsigned(110,   N_BITS_TEST)), 
        std_logic_vector(to_unsigned(84,    N_BITS_TEST)), 
        std_logic_vector(to_unsigned(11,    N_BITS_TEST)), 
        std_logic_vector(to_unsigned(88,    N_BITS_TEST)),
        -- Composites 
        std_logic_vector(to_unsigned(9 ,    N_BITS_TEST)),
        std_logic_vector(to_unsigned(36000, N_BITS_TEST)),
        std_logic_vector(to_unsigned(20236, N_BITS_TEST))
    );
    
    -- Expected result values 
    constant GCD_VALS : tv_array := (
        -- Test GCD(0, 0) = 0 and GCD(a, 0) = GCD(0, a) = a
        x"0000", x"0001", x"0001", x"FFFF", x"FFFF", x"DEAD", x"BEEF", 
        -- Test edge cases
        x"0001", x"0001", x"0001", x"0001", x"0001", x"C001", x"00FF",
        -- Primes and coprimes
        x"0001", x"0001", x"0001", 
        -- Test examples
        std_logic_vector(to_unsigned(5,     N_BITS_TEST)), 
        std_logic_vector(to_unsigned(12,    N_BITS_TEST)), 
        std_logic_vector(to_unsigned(1,     N_BITS_TEST)), 
        std_logic_vector(to_unsigned(8,     N_BITS_TEST)),
        -- Composites 
        std_logic_vector(to_unsigned(3,     N_BITS_TEST)),
        std_logic_vector(to_unsigned(12000, N_BITS_TEST)),
        std_logic_vector(to_unsigned(2,     N_BITS_TEST))
    );
    ----------------------------------------------------------------------------
    
    --------------------- UNIT UNDER TEST COMPONENT ----------------------------
    component Gcd is 
        generic(
            N_BITS      :           integer
        );
        port (
            SysClk      : in        std_logic;
            A           : in        std_logic_vector(N_BITS-1 downto 0);
            B           : in        std_logic_vector(N_BITS-1 downto 0);
            nCalculate  : in        std_logic;
            CanReadVals : in        std_logic;
            Result      : out       std_logic_vector(N_BITS-1 downto 0);
            ResultRdy   : out       std_logic
        );
    end component;
    ----------------------------------------------------------------------------
    
begin 

    --------------------- UNIT UNDER TEST PORT MAP -----------------------------
    UUT : Gcd 
        generic map (
            N_BITS       =>  N_BITS_TEST
        )
        port map (
            SysClk       =>  SysClk,      
            A            =>  A,           
            B            =>  B,           
            nCalculate   =>  nCalculate,  
            CanReadVals  =>  CanReadVals, 
            Result       =>  Result,      
            ResultRdy    =>  ResultRdy   
        );
    ----------------------------------------------------------------------------
    
    --------------------------- TEST PROCESS -----------------------------------
    -- This process provides the stimulus inputs (tests) to the UUT, 
    -- observes the outputs, and asserts failed tests.
    STIMULUS : process 
    begin 
        -- Initially disable calculation
        nCalculate <= '1';
        
        -- Wait a few clocks 
        wait for 5 * CLOCK_PERIOD;
        
        -- Loop over each of the testvectors:
        -- Load the operands A and B in each test vector into the UUT, wait for 
        -- calculation to finish, and check result
        for i in 0 to N_TESTVECS-1 loop
            -- Load the values into the operands 
            A <= A_VALS(i);
            B <= B_VALS(i);
            
            -- Get the expected GCD 
            ExpectedGcd <= GCD_VALS(i);
            
            -- Bring calculate input low for a clock
            wait until falling_edge(SysClk);    -- Transition on falling edges 
            nCalculate <= '0';                  -- of the system clock
            wait until falling_edge(SysClk);
            nCalculate <= '1';
                    
            -- Wait for calculation to finish 
            wait until ResultRdy = '1';
            
            -- Check the result on the next falling edge of the clock
            wait until falling_edge(SysClk);
            assert (std_match(Result, ExpectedGcd))
                report "Incorrect GCD! Actual: " &
                       integer'image(to_integer(unsigned(Result))) &
                       ". Expected: " &
                       integer'image(to_integer(unsigned(ExpectedGcd))) &
                       "."
                severity ERROR;
                
            -- Wait a few clocks 
            wait for 5 * CLOCK_PERIOD;
        end loop;

        -- When done, set end of sim flag
        END_SIM <= TRUE;
        wait;
    end process;
    ----------------------------------------------------------------------------
    
    ------------------------ CLOCK GEN PROCESS ---------------------------------
    -- This process generates a `CLOCK_PERIOD` period, 50% duty cycle clock. 
    CLOCK_CLK : process
    begin
        -- Only generate clock if still simulating.
        if END_SIM = FALSE then
            SysClk <= '0';
            wait for CLOCK_HALFPER;
        else
            wait;
        end if;
        if END_SIM = FALSE then
            SysClk <= '1';
            wait for CLOCK_HALFPER;
        else
            wait;
        end if;
    end process;
    
    -- This process generates the `CanReadVals` signal seen by the UUT 
    CLOCK_CRV : process 
    begin 
        if END_SIM = FALSE then
            CanReadVals <= '1';
            wait for T_CRV_HIGH;
        else 
            wait;
        end if;
        if END_SIM = FALSE then
            CanReadVals <= '0';
            wait for T_CRV_LOW;
        else 
            wait;
        end if;
    end process;
    ----------------------------------------------------------------------------
end architecture;


--------------------------------------------------------------------------------