--------------------------------------------------------------------------------
--                                  gcd.vhd                                   --
--                  Serial Euclid's Subtraction GCD Calculator                --
--------------------------------------------------------------------------------
--
-- Description:
--      This file contains a VHDL entity `Gcd` with architecture `DataFlow` that
--      implements a N-bit GCD calculator using Euclid's subtraction
--      algorithm and a bit-serial subtracter. This module is used by the 
--      top-level entity 
--
-- Generic Parameters:
--      N_BITS              Number of bits in the GCD operands. 
--
-- Inputs:
--      SysClk              The system clock 
--      A (N_BITS-1 ... 0)  GCD operand A
--      B (N_BITS-1 ... 0)  GCD operand B
--      nCalculate          Active low calculation start input (unsynch)
--      CanReadVals         Active high ready to receive output signal  (synch)
--
-- Outputs:
--      Result (N_BITS-1 ... 0)         The GCD result 
--      ResultRdy                       Active high result is valid output
--
-- Table of Contents:
--      entity              Gcd
--      architecture        DataFlow
--
-- Details:
--      Euclid's subtraction algorithm, in pseudocode, is given by
--
--              DO
--                  WHILE a >= b 
--                      a = a - b 
--                  ENDWHILE
--                  swap (a, b)
--              UNTIL (b = 0)
--              gcd = a
--
--      where `a` and `b` are unsigned integers.
--
-- Notes:
--    - Calculating GCD(a, 0) or GCD(0, a), where a != 0, will always result 
--      in `a`. This is due to the implementation of Euclid's subtraction.
--    - This Euclid's subtraction implementation was designed with a completely 
--      generic operand size, but is only used as a 16-bit GCD calculator 
--      in the overall system.
--    - This calculator was designed for minimum size, but I am too lazy to 
--      implement a compare instruction (A <= A - B, check high bit, then 
--      add B back). Could just refactor the Caltech10 ALU into VHDL...
--
-- Revision History:
--      12/07/2018          Ray Sun         Initial revision.
--      12/07/2018          Ray Sun         Implemented 'in-place' Euclid's 
--                                          subtraction with serial subtract
--      12/07/2018          Ray Sun         Fixed cases where B > A
--------------------------------------------------------------------------------


library ieee;                   -- Import the requisite packages
use ieee.std_logic_1164.all;    -- For 9-valued logic types
use ieee.numeric_std.all;       -- For unsigned type


--------------------------------------------------------------------------------
--                           Gcd ENTITY DECLARATION                           --
--------------------------------------------------------------------------------


entity Gcd is 
    generic(
        N_BITS      :           integer
    );
    port(
        SysClk      : in        std_logic;
        A           : in        std_logic_vector(N_BITS-1 downto 0);
        B           : in        std_logic_vector(N_BITS-1 downto 0);
        nCalculate  : in        std_logic;
        CanReadVals : in        std_logic;
        Result      : out       std_logic_vector(N_BITS-1 downto 0);
        ResultRdy   : out       std_logic
    );
end entity;


--------------------------------------------------------------------------------
--                           Gcd ARCHITECTURE                                 --
--------------------------------------------------------------------------------


architecture DataFlow of Gcd is 

    -------------------------- CONSTANTS ---------------------------------------
    -- Zero for input bus size
    constant N_ZEROES :     unsigned(N_BITS-1 downto 0) :=  (others => '0');
                                
    -- High value for subtraction counter 
    constant SUB_CNTR_TOP   :   integer := N_BITS-1;
    ----------------------------------------------------------------------------
    
    ---------------------- INPUT HANDLING SIGNALS ------------------------------
    -- A pair of registered signals (DFFs) for synchrnonizing calculate input
    signal nCalculateS :    std_logic_vector(1 downto 0);
    ----------------------------------------------------------------------------
    
    ------------------------- STATE SIGNALS ------------------------------------
    -- GCD calculator FSM states (2 state bits for 4 states)
    type GCDCALCSTATE is (  IDLE,       -- Awaiting calculation start  
                            CALC,       -- is calculating 
                            DONE );     -- done calculating
    
    signal currState :  GCDCALCSTATE;   -- Current and next state signals
    signal nextState :  GCDCALCSTATE;
    
    signal aleb :       std_logic;      -- Active high flag indicating that 
                                        -- whatever register is currently A is 
                                        -- less than whatever register is B
    
    signal bSelect :    std_logic;      -- Active high select for `B`. When 
                                        -- active, indicates that what the 
                                        -- algorithm considers `B` was initially
                                        -- the input `A`
                                        
    -- In particular,
    --      bSelect =   0       A = `regA`      B = `regB`
    --      bSelect =   1       A = `regB`      B = `regA`
                                        
    signal doneCalc :   std_logic;      -- Active high done with GCD calculation 
                                        -- indicator. Only high if whatever is 
                                        -- currently `B` is zero; namely,
                                        --          regA when bSelect = 1
                                        --          regB when bSelect = 0
    
    -- Counter for control of the serial subtraction
    signal subCntr :    integer range 0 to N_BITS-1;
    ----------------------------------------------------------------------------
    
    --------------------------- REGISTERS --------------------------------------
    -- Shift registers for the operands `A` and `B`
    --      Serially loaded when calculation starts
    signal regA     :   unsigned(N_BITS-1 downto 0);
    signal regB     :   unsigned(N_BITS-1 downto 0);
    
    -- Register control signals:
    signal loadEn   :   std_logic;      -- Active high parallel load enable for 
                                        -- both registers - for loading 
                                        -- in operands when IDLE. Takes
                                        -- precedence over shift enable
    signal shiftEn  :   std_logic;      -- Active high shift enables for each 
                                        -- register - when active, each register 
                                        -- is shifted right with either the 
                                        -- difference A - B, or the old LSB,
                                        -- shifted in depending on `bSelect`
    ----------------------------------------------------------------------------
    
    ----------------- SERIAL FULL SUBTRACTER SIGNALS ---------------------------
    signal minuend :    std_logic;      -- Bits for the full subtracter 
    signal subtrahend : std_logic;      --    minuend - subtrahend = difference
    signal difference : std_logic;
    
    signal carryOut   : std_logic;      -- The carry out (carry = !borrow)
    signal carryFlag  : std_logic;      -- Registered borrow in
    ----------------------------------------------------------------------------
    
begin

    ----------------------------------------------------------------------------
    --                              INPUTS                                    --
    ----------------------------------------------------------------------------
    
    
    ------------------------ Synchronize Inputs --------------------------------
    -- Pass `nCalculate` through a pair of DFFs to synchronize 
    process (SysClk)
    begin 
        -- On rising edge, shift the signals
        if rising_edge(SysClk) then 
            nCalculateS <= nCalculateS(0) & nCalculate;
        end if;
        -- Use high bit of `nCalculateS` - the synchronized input - to determine 
        -- when to start GCD calculation
    end process;
    ----------------------------------------------------------------------------
    
    
    ----------------------------------------------------------------------------
    --                         GCD CALCULATOR FSM                             --
    ----------------------------------------------------------------------------
    
    
    -- Combinational process for state logic 
    process ( nCalculateS(1), doneCalc, CanReadVals )
    begin
        case currState is
            -- If in the idle state and the synchronized `nCalculate` is low, 
            -- start calculating
            when IDLE => 
                if nCalculateS(1) = '0' then 
                    nextState <= CALC;
                else 
                    nextState <= nextState;     -- Don't infer latch
                end if;
            -- If calculating and the register that is currently `B` is zero, 
            -- then transition to done 
            when CALC  =>
                if doneCalc = '1' then 
                    nextState <= DONE;
                else 
                    nextState <= nextState;     -- Don't infer latch
                end if;
            -- Only leave the done state if `CanReadVals` is active (high)
            -- so the system can read outputs
            when DONE =>
                if CanReadVals = '1' then 
                    nextState <= IDLE;
                else 
                    nextState <= nextState;     -- Don't infer latch
                end if;    
        end case;
    end process;
    
    
    -- FSM output decoding 
    --      Output register control signals depending on current state
    
    -- Keep parallel loading operands into registers if IDLE
    loadEn <=   '1' when currState = IDLE else 
                '0';
    -- Enable shifting only when calculating and not done
    shiftEn <=  '1' when currState = CALC and doneCalc = '0' else 
                '0';
    
    -- Update state process - register the new current state on `SysClk`
    process (SysClk)
    begin 
        if rising_edge(SysClk) then 
            currState <= nextState;
        end if;
    end process;
    
    
    ----------------------------------------------------------------------------
    --                        GCD CALCULATOR STATE                            --
    ----------------------------------------------------------------------------
    
    
    -- Process to increment or clear subtraction counter 
    process (SysClk)
    begin 
        if rising_edge(SysClk) then 
            -- If not calculating or at top value, clear
            if (currState = IDLE) or 
               (subCntr = SUB_CNTR_TOP) then
                subCntr <= 0;
            -- Otherwise increment 
            else
                subCntr <= subCntr + 1;
            end if;
        end if;
    end process;
    
    -- Combinationally determine if the current `A` is less than the 
    -- current `B`
    aleb <= '1' when ( ( (bSelect = '0') and (regA < regB) ) or 
                       ( (bSelect = '1') and (regA > regB) ) ) else 
            '0';
    
    -- Process to swap which register is considered `A` and `B` by toggling
    -- `bSelect` when appropriate 
    process (SysClk, currState, aleb)
    begin
        -- If not calculating, reset (initially A is `regA`) unless
        -- A < B - handles edge case of GCD(0, 1), etc.
        if currState = IDLE then 
            if regA < regB then 
                bSelect <= '1';
            else 
                bSelect <= '0';
            end if;
        -- When the register that is currently `A` becomes less than the 
        -- register that is currently `B`, at the end of a subtraction 
        -- swap
        --
        -- If A is `regA` and B is `regB`, and A < B, swap 
        -- Otherwise A is `regB` and B is `regA`; if A < B, swap 
        elsif rising_edge(SysClk) and 
              (subCntr = SUB_CNTR_TOP ) and 
              (aleb = '1') then
            bSelect <= not bSelect;
        end if;
    end process;
    
    
    -- Combinational process to determine when done calculating - when the 
    -- register considered to be `B` is zero 
    process (regA, regB, bSelect)
    begin 
        -- If B is currently `regB`, check its equality 
        if bSelect = '0' then 
            if regB = N_ZEROES then 
                doneCalc <= '1';
            else 
                doneCalc <= '0';
            end if;
        -- Otherwise, B is `regA`, so check its equality
        else
            if regA = N_ZEROES then 
                doneCalc <= '1';
            else 
                doneCalc <= '0';
            end if;
        end if;
    end process;
    
    
    ----------------------------------------------------------------------------
    --                          FULL SSUBTRACTER                              --
    ----------------------------------------------------------------------------
    
    
    -- Select the minuend and subtrahend 
    --      When `bSelect` is inactive : `regA`(LSB) - `regB`(LSB)
    --      When `bSelect` is active :   `regB`(LSB) - `regA`(LSB)
    minuend     <=  regA(regA'right) when bSelect = '0' else 
                    regB(regB'right);
    subtrahend  <=  regB(regB'right) when bSelect = '0' else 
                    regA(regA'right);
                
    -- Compute the difference bit
    difference <=   minuend xor 
                    (not subtrahend) xor 
                    carryFlag;
                    
    -- Compute the carry out 
    carryOut   <=   ( carryFlag and 
                    ( minuend xor (not subtrahend) ) ) or
                    ( minuend and (not subtrahend) );     
                    
    -- Process that determines when to enable or preset the carry flag
    --      Effectively a DFF with preset 
    process (SysClk)
    begin
        if rising_edge(SysClk) then 
            -- If not calculating or at the end of a subtraction, set the 
            -- carry flag (start the next subtraction with no borrow)
            if (currState = IDLE) or (subCntr = SUB_CNTR_TOP) then 
                carryFlag <= '1';
            -- Otherwise register the carry out 
            else
                carryFlag <= carryOut;
            end if;
        end if;
    end process;
    
    
    ----------------------------------------------------------------------------
    --                        GCD REGISTER CONTROL                            --
    ----------------------------------------------------------------------------
    
    
    -- Process for updating each of the operand registers on system clock
    process (SysClk)
    begin 
        if rising_edge(SysClk) then 
            -- If parallel loading, then load the operands into the registers 
            --      This takes precedence over serial shift
            if loadEn = '1' then
                regA <= unsigned(A);
                regB <= unsigned(B);
            -- Otherwise, if serial loading, shift
            elsif shiftEn = '1' then 
                -- Shift in the new bit (MSB) from left 
                -- For `regA`, the new MSB is the difference whenever A is 
                -- `regA` and the old LSB otherwise
                -- For `regB`, the new MSB is the difference whenever A is 
                -- `regB` and the  old LSB otherwise
                if bSelect = '0' then
                    regA(regA'left) <= Difference;
                    regB(regB'left) <= regB(regB'right);
               else
                    regA(regA'left) <= regA(regA'right);
                    regB(regB'left) <= Difference;
                end if;
                -- Shift the other bits right 
                regA(regA'left-1 downto regA'right) <=
                    regA(regA'left downto regA'right+1);
                regB(regB'left-1 downto regB'right) <=
                    regB(regB'left downto regB'right+1);
            -- Otherwise don't infer latch
            else 
                regA <= regA;
                regB <= regB;
            end if;
        end if;
    end process;
    
    
    ----------------------------------------------------------------------------
    --                              OUTPUT                                    --
    ----------------------------------------------------------------------------
    
    
    -- The GCD result is always just whatever `A` is at the end of calculation 
    -- (may or may not be valid) - since the GCD is done in place
    Result  <=  std_logic_vector(regA) when bSelect = '0' else 
                std_logic_vector(regB);
    
    -- Set the result ready flag high when appropriate for the system to read -
    -- when done and `CanReadVals` is active
    ResultRdy <=    '1' when (currState = DONE) and 
                             (CanReadVals = '1') else
                    '0';

end architecture;


--------------------------------------------------------------------------------