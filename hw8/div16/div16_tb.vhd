--------------------------------------------------------------------------------
--                              div16_tb.vhd                                  --
--                     16-bit Serial Divider Testbench                        --
--------------------------------------------------------------------------------
--
-- Description:
--      This is a testbench for a 16-bit serial divider design with entity 
--      `Div16` and architecture `DataFlow`. The testbench architecture 
--      `TB_ARCHITECTURE` exercises the entity by checking that inputs are 
--      correctly entered and that division of edge cases and random cases 
--      returns the correct quotient.
--
-- Table of Contents:
--      entity          SerialDivider16_tb
--      architecture    TB_ARCHITECTURE
--
-- Notes:
--      - This testbench was ran with ModelSim-Altera.
--      - For best results (not waiting for several minutes for the simulation 
--        to run), adjust the `resolution` selector to `100 ns` in the 
--        dialog that prompts for the architecture to simulate.
--      - For 20 testvectors (as given), simulate to around 2.25 seconds.
--
-- Revision History:
--      11/29/2018      Ray Sun     Initial revision.
--      11/29/2018      Ray Sun     Replaced the clock period (actual system 
--                                  clock period) with a smaller value so that 
--                                  the ModelSim simulation runs faster
--      12/01/2018      Ray Sun     Added some division tests.
--      12/03/2018      Ray Sun     Restored actual system clock period once 
--                                  resolution feature in simulation found.
--      12/03/2018      Ray Sun     Added more division tests.
--------------------------------------------------------------------------------


library ieee;                   -- Import the requisite packages
use ieee.std_logic_1164.all;    -- For 9-valued logic types
use ieee.numeric_std.all;       -- For numeric types


--------------------------------------------------------------------------------


entity SerialDivider16_tb is 
end entity;


--------------------------------------------------------------------------------


architecture TB_ARCHITECTURE of SerialDivider16_tb is

    ---------------------------- CONSTANTS -------------------------------------
    constant CLOCK_PERIOD  :    time := 1 us;   -- System clock period
    constant CLOCK_HALFPER :    time := CLOCK_PERIOD / 2;
    
    -- `std_logic` constants 
    constant  SL_TRUE       :   std_logic := '1';
    constant  SL_FALSE      :   std_logic := '0';
    constant  SL_HIGH       :   std_logic := '1';
    constant  SL_LOW        :   std_logic := '0';
    
    constant WORD_SIZE      :   integer := 16;
    
    constant DIV_SIZE       :   integer := 16;      -- Size of divider
    constant DIGIT_SIZE     :   integer := 4;       -- Size of output digits 
    constant NUM_DIGITS     :   integer := 13;      -- Number of output digits 
    constant MUXCNT_SIZE    :   integer := 10;      -- Size of mux counter
    constant MUXCNT_TOP     :   integer := 1023;    -- Top value of mux counter 
    
    -- Test constants 
    constant NUM_TESTVECS   :   integer := 20;      -- Number of test vectors
    ----------------------------------------------------------------------------
    
    ------------------------------ TYPES ---------------------------------------
    -- An integer array for storing the count sequence of the muxed digit
    type int_array is array (0 to NUM_DIGITS-1) of 
                      integer range 0 to WORD_SIZE-1;
    
    -- Type for arrays of test vectors
    type tv_array is array (0 to NUM_TESTVECS-1) of 
                     std_logic_vector(DIV_SIZE-1 downto 0);
    ----------------------------------------------------------------------------
    
    ------------------------- STIMULUS SIGNALS ---------------------------------
    signal Clock        :  std_logic;
    signal nCalculate   :  std_logic;
    signal Divisor      :  std_logic;
    signal KeypadRdy    :  std_logic;
    signal KeypadVal    :  std_logic_vector(3 downto 0);
    ----------------------------------------------------------------------------
    
    ------------------------- OBSERVED SIGNALS ---------------------------------
    signal SsdOutput    : std_logic_vector(3 downto 0);
    signal SsdDigit     : std_logic_vector(3 downto 0);
    signal DecoderEn    : std_logic;
    ----------------------------------------------------------------------------
    
    --------------------------- TEST SIGNALS -----------------------------------
    signal END_SIM  :       boolean := FALSE;       -- End-of-sim flag
   
   -- Expected mux count - for timing and comparing against UUT
    signal ExpectedMuxCnt : integer range 0 to MUXCNT_TOP;
    
    -- Expected `CurDigit` in the SSD - useful for timing and to compare against
    -- internal signal in UUT. Initialize to the dividend high digit
    signal ExpectedDigit :  integer range 0 to WORD_SIZE-1 := 3;
    
    -- For simulation use - current dividend, divisor, and quotient 
    signal TestDividend :   std_logic_vector(WORD_SIZE-1 downto 0);
    signal TestDivisor  :   std_logic_vector(WORD_SIZE-1 downto 0);
    signal TestQuotient :    std_logic_vector(WORD_SIZE-1 downto 0);
    ----------------------------------------------------------------------------
    
    -------------------------- TEST VECTORS ------------------------------------
    -- The sequence of muxed digits
    --          | Dividend | Divisor | Quotient | Calculation |      
    --          | 3      0 | 7     4 | 11     8 |     15      |
    constant SSD_MUX_SEQUENCE : int_array := 
                            (3, 2, 1, 0, 7, 6, 5, 4, 11, 10, 9, 8, 15);
                            
    -- TEST CASES:
    --      - Since division by 0 is not accounted for, dividing by 0 will 
    --        produce distinct (incorrect) output.
    --
    --        Dividend    /    Divisor     =   Quotient
    --  Edge cases:
    --          0000            0000            FFFF
    --          0000            FFFF            0000
    --          0000            0001            0000
    --          0000            1F00            0000    - Caltech10 RTS 
    --          0000            DEAD            0000    - Totally Random
    --          0000            BEEF            0000      Values [TM]
    --          FFFF            0000            FFFF    - Miscellaneous 
    --          0001            0000            FFFF      division by 0
    --          BAAD            0000            FFFF
    --          0001            0001            0001    - Some divide by self
    --          FFFF            FFFF            0001      cases
    --          D00D            D00D            0001          
    --
    -- Simple cases:
    --          0004            0002            0002    - 4 / 2 = 2
    --          C001            0FFF            000C
    --          FACE            B00C            0001
    --
    -- Primes:
    --          003D            0011            0003    - 61 / 17 = 3
    --          BB2D            26C9            0004    - 47917 / 9929 = 4
    --
    -- Composites:
    --          0AB5            0002            055A    - 2741 / 2 = 1380
    --          000A            034F            0000    - 10 / 847 = 0
    --          BB51            0119            00AA    - 47953 / 281 = 170
    
    -- Vector of dividend inputs
    constant DIVIDEND_VALS: tv_array := (
        x"0000",
        x"0000",
        x"0000",
        x"0000",
        x"0000",
        x"0000",
        x"FFFF",
        x"0001",
        x"BAAD",
        x"0001",
        x"FFFF",
        x"D00D",
        x"0004",
        x"C001",
        x"FACE",
        x"0035",
        x"BB2D",
        x"0AB5",
        x"000A",
        x"BB51"
    );
    
    -- Vector of divisor inputs
    constant DIVISOR_VALS : tv_array := (
        x"0000",
        x"FFFF",
        x"0001",
        x"1F00",
        x"DEAD",
        x"BEEF",
        x"0000",
        x"0000",
        x"0000",
        x"0001",
        x"FFFF",
        x"D00D",
        x"0002",
        x"0FFF",
        x"B00C",
        x"0011",
        x"26C9",
        x"0002",
        x"034F",
        x"0119"
    );
    
    -- Expected quotient output 
    constant QUOTIENT_VALS : tv_array := (
        x"FFFF",
        x"0000",
        x"0000",
        x"0000",
        x"0000",
        x"0000",
        x"FFFF",
        x"FFFF",
        x"FFFF",
        x"0001",
        x"0001",
        x"0001",
        x"0002",
        x"000C",
        x"0001",
        x"0003",
        x"0004",
        x"055A",
        x"0000",
        x"00AA"
    );
    ----------------------------------------------------------------------------

    --------------------- UNIT UNDER TEST COMPONENT ----------------------------
    component Div16 is
    port (
        nCalculate  :  in   std_logic;
        Divisor     :  in   std_logic;
        KeypadRdy   :  in   std_logic;
        Keypad      :  in   std_logic_vector(3 downto 0);
        HexDigit    :  out  std_logic_vector(3 downto 0);
        DecoderEn   :  out  std_logic;
        DecoderBit  :  out  std_logic_vector(3 downto 0);
        CLK         :  in   std_logic
    );
    end component;
    ----------------------------------------------------------------------------
    
begin
    
    --------------------- UNIT UNDER TEST PORT MAP -----------------------------
    UUT : Div16
        port map  (
            CLK        => Clock,
            nCalculate => nCalculate,
            Divisor    => Divisor,
            KeypadRdy  => KeypadRdy,
            Keypad     => KeypadVal,
            HexDigit   => SsdOutput,
            DecoderBit => SsdDigit,
            DecoderEn  => DecoderEn
        );
    ----------------------------------------------------------------------------
    
    --------------------------- TEST PROCESS -----------------------------------
    STIMULUS : process 
        -- Variables for keeping track of the expected output: expected 
        -- hex digit output (checking that digit input is OK) and quotient
        variable ExpectedDigitVal  : std_logic_vector(DIGIT_SIZE-1 downto 0);
        variable ExpectedQuotient  : std_logic_vector(DIGIT_SIZE-1 downto 0);
    begin 
    
        nCalculate  <= SL_HIGH;         -- Initialize to not calculating
        
        --------------------------- CHECK INPUTS -------------------------------
        
        Divisor    <= SL_LOW;           -- Select dividend input
        KeypadRdy  <= SL_LOW;           -- Have `KeypadRdy` low 
        
        -- Input values into the dividend to check key input
        for i in 3 downto 0 loop
            -- Wait until the digit is the low digit for dividend entry
            wait until ExpectedMuxCnt = to_unsigned(0, MUXCNT_SIZE);
            wait until ExpectedDigit = 3;
            
            -- Toggle (asynchronous, to be synchronized) inputs on the falling 
            -- edge of the clock
            wait until falling_edge(Clock);
            
            -- Enter the digits in the 1st entry in the testvectors
            KeypadVal  <= DIVIDEND_VALS(0)( (4 * i) + 3 downto (4 * i) );
            KeypadRdy  <= SL_HIGH;          -- Key is ready
            
            wait until falling_edge(Clock);
            KeypadRdy  <= SL_LOW;           -- Bring low on next period
        end loop;
        
        -- Input values into the divisor to check key input
        wait until ExpectedMuxCnt = to_unsigned(0, MUXCNT_SIZE);
        divisor    <= '1';                  -- Select Divisor entry 
        for i in 3 downto 0 loop
            -- Wait until the digit is the low digit for divisor entry
            wait until ExpectedMuxCnt = to_unsigned(0, 10);
            wait until ExpectedDigit = 7;
            
            -- Toggle (asynchronous, to be synchronized) inputs on the falling 
            -- edge of the clock
            wait until falling_edge(Clock);
            
            -- Enter the digits in the 1st entry in the testvectors 
            keypadVal  <= DIVISOR_VALS(0)( (4 * i) + 3 downto (4 * i) );
            keypadRdy  <= SL_HIGH;          -- Key is ready
            
            wait until falling_edge(Clock);
            keypadRdy  <= SL_LOW;           -- Bring low on next period
        end loop;
        
        -- Check that the dividend was entered and is displayed correctly
        for i in 0 to 3 loop
            -- Wait until the digit displayed is a dividend digit (0 to 3)
            wait until ExpectedDigit = SSD_MUX_SEQUENCE(i);
            wait until falling_edge(Clock);
            -- Get the current expected dividend digit 
            ExpectedDigitVal := DIVIDEND_VALS(0)( (4 * i) + 3 downto (4 * i) );
            -- and compare it to the result from the UUT (`SsdOutput`)
            assert(std_match(SsdOutput, ExpectedDigitVal))
                report "Dividend digit mismatch! Actual: " &
                       integer'image(to_integer(unsigned(SsdOutput))) &
                       ". Expected: " &
                       integer'image(to_integer(unsigned(ExpectedDigitVal))) &
                       "."
                severity ERROR;
        end loop;
        
        -- Check that the divisor was entered and is displayed correctly
        for i in 0 to 3 loop
            -- Wait until the digit displayed is a divisor digit (4 to 7) 
            wait until ExpectedDigit = SSD_MUX_SEQUENCE(i + 4);
            wait until falling_edge(Clock);
            -- Get the current expected divisor digit 
            ExpectedDigitVal := DIVISOR_VALS(0)( (4 * i) + 3 downto (4 * i) );
            -- and compare it to the result from the UUT (`SsdOutput`)
            assert(std_match(SsdOutput, ExpectedDigitVal))
                report "Divisor digit mismatch! Actual: " &
                       integer'image(to_integer(unsigned(SsdOutput))) &
                       ". Expected: " &
                       integer'image(to_integer(unsigned(ExpectedDigitVal))) &
                       "."
                severity ERROR;
        end loop;
        
        ----------------------- DIVISION TESTS ---------------------------------
        
        -- Now load the test vector values for dividend and divisor into the 
        -- UUT, let it find the quotient, and check if the output is correct.
        for j in 0 to NUM_TESTVECS-1 loop
            
            -- Set the signals to look at in simulation 
            TestDividend <= DIVIDEND_VALS(j);
            TestDivisor  <= DIVISOR_VALS(j);
            TestQuotient <= QUOTIENT_VALS(j);
            
            -- Input to dividend (like before)
            Divisor    <= SL_LOW;
            KeypadRdy  <= SL_LOW;
            
            for i in 3 downto 0 loop
                wait until ExpectedMuxCnt = to_unsigned(0, MUXCNT_SIZE);
                wait until ExpectedDigit = 3;
                wait until falling_edge(Clock);
                KeypadVal  <= DIVIDEND_VALS(j)( (4 * i) + 3 downto (4 * i) );
                KeypadRdy  <= SL_HIGH;
                wait until falling_edge(Clock);
                KeypadRdy  <= SL_LOW;
            end loop;
            
            -- Input to divisor (like before)
            wait until ExpectedMuxCnt = to_unsigned(0, MUXCNT_SIZE);
            divisor    <= '1';
            for i in 3 downto 0 loop
                wait until ExpectedMuxCnt = to_unsigned(0, MUXCNT_SIZE);
                wait until ExpectedDigit = 7;
                wait until falling_edge(Clock);
                KeypadVal  <= DIVISOR_VALS(j)( (4 * i) + 3 downto (4 * i) );
                KeypadRdy  <= SL_HIGH;
                wait until falling_edge(Clock);
                KeypadRdy  <= SL_LOW;
            end loop;
            
            -- Calculate the quotient
            nCalculate <= SL_LOW;
            -- Bring `nCalculate` low during calculation digit time
            wait until ExpectedDigit = SSD_MUX_SEQUENCE(12);
            wait until ExpectedDigit = SSD_MUX_SEQUENCE(0);
            wait until falling_edge(Clock);
            nCalculate <= SL_LOW;
            
            -- Check quotient
            for i in 0 to 3 loop
                wait until ExpectedDigit = SSD_MUX_SEQUENCE(i + 8);
                wait until falling_edge(Clock);
                ExpectedQuotient := QUOTIENT_VALS(j)( (4 * i) + 3 downto (4 * i) );
                assert(std_match(SsdOutput, ExpectedQuotient))
                    report "Quotient digit mismatch! Actual: " &
                           integer'image(to_integer(unsigned(
                                SsdOutput))) &
                           ". Expected: " &
                           integer'image(to_integer(unsigned(
                                ExpectedQuotient))) &
                           "."
                    severity ERROR;
            end loop;
        end loop;
        
        -- When done, set end of sim flag
        END_SIM <= TRUE;
        wait;
    end process;
    ----------------------------------------------------------------------------
    
    -------------------- EXPECTED DIGIT MUXING PROCESS -------------------------
    -- Update the expected mux count and digit according to the UUT to keep 
    -- track of timing
    process(Clock)
    begin
        if rising_edge(Clock) then
            -- If the mux count is at the top
            if ExpectedMuxCnt = MUXCNT_TOP then
                ExpectedMuxCnt <= 0;
                -- If at the top of the sequence, reset
                if ExpectedDigit = SSD_MUX_SEQUENCE(12) then
                    ExpectedDigit <= SSD_MUX_SEQUENCE(0);
                -- Otherwise move to the next digit in the `CurDigit` sequence
                else
                    for i in 0 to NUM_DIGITS-2 loop
                        if ExpectedDigit = SSD_MUX_SEQUENCE(i) then
                            ExpectedDigit <= SSD_MUX_SEQUENCE(i + 1);
                        end if;
                    end loop;
                end if;
            -- Otherwise increment the mux count
            else
                ExpectedMuxCnt <= ExpectedMuxCnt + 1;
            end if;
        end if;
    end process;
    ----------------------------------------------------------------------------
    
    ------------------------ CLOCK GEN PROCESS ---------------------------------
    CLOCK_CLK : process
    begin
        -- This process generates a `CLOCK_PERIOD` ns period, 
        -- 50% duty cycle clock. Only generate clock if still simulating.
        if END_SIM = FALSE then
            Clock <= SL_LOW;
            wait for CLOCK_HALFPER;
        else
            wait;
        end if;
        if END_SIM = FALSE then
            Clock <= SL_HIGH;
            wait for CLOCK_HALFPER;
        else
            wait;
        end if;
    end process;
    ----------------------------------------------------------------------------
end architecture;