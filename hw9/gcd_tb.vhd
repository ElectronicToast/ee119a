--------------------------------------------------------------------------------
--                                 gcd_tb.vhd                                 --
--                          GCD Calculator Testbench                          --
--------------------------------------------------------------------------------
--
-- Description:
--      This is a testbench for the N-bit GCD calculator defined by the entity 
--      `Gcd` with architecture `DataFlow`. It thoroughly tests the entity by 
--      testing GCD calculations on edge cases and randomly generated test 
--      cases.
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
    constant CLOCK_PERIOD  :    time := 500 ns;   -- System clock, 2 MHz
    constant CLOCK_HALFPER :    time := CLOCK_PERIOD / 2;
    
    -- Test constants 
    constant N_BITS_TEST   :   integer := 16;   -- Number of bits in operands   
    constant N_RAND_TESTS  :   integer := 10;   -- Number of random tests
    ----------------------------------------------------------------------------
    
    ------------------------- STIMULUS SIGNALS ---------------------------------
    signal SysClk       :  std_logic;
    signal A            :  std_logic_vector(N_BITS_TEST-1 downto 0);
    signal B            :  std_logic_vector(N_BITS_TEST-1 downto 0);
    signal nCalculate   :  std_logic;
    signal CanReadVals  :  std_logic;
    ----------------------------------------------------------------------------
    
    ------------------------- OBSERVED SIGNALS ---------------------------------
    signal Result       :  std_logic_vector(N_BITS_TEST-1 downto 0);
    signal ResultRdy    :  std_logic;
    ----------------------------------------------------------------------------
    
    --------------------------- TEST SIGNALS -----------------------------------
    signal END_SIM      : boolean := FALSE;       -- End-of-sim flag
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
        CanReadVals <= '0';
        
        -- Wait a few clocks 
        wait for 3 * CLOCK_PERIOD;
        
        A <= std_logic_vector(to_unsigned(64, N_BITS_TEST));
        B <= std_logic_vector(to_unsigned(88, N_BITS_TEST));
        
        -- Bring calculate input low for a clock
        wait until falling_edge(SysClk);
        nCalculate <= '0';
        wait until falling_edge(SysClk);
        nCalculate <= '1';
        
        -- Wait a decent number of clocks
        wait for 300 * CLOCK_PERIOD;
        
        -- Bring CanReadVals active for a clock
        wait until falling_edge(SysClk);
        CanReadVals <= '1';
        wait until falling_edge(SysClk);
        CanReadVals <= '0';
        
        -- Wait a few clocks 
        wait for 3 * CLOCK_PERIOD;
        
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
    ----------------------------------------------------------------------------
end architecture;


--------------------------------------------------------------------------------