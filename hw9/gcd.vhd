--------------------------------------------------------------------------------
--                                  gcd.vhd                                   --
--                  Serial Euclid's Subtraction GCD Calculator                --
--------------------------------------------------------------------------------
--
-- Description:
--      This file contains a VHDL entity `Gcd` with architecture `DataFlow` that
--      implements a N-bit GCD calculator using Euclid's subtraction
--      algorithm and a bit-serial subtracter. This module is used by the 
--      top-level entity `system` to implement a 16-bit GCD calculator with 
--      multiplexed seven-segment display output, debounced keypad input,
--      and a GCD operand select switch.
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
--                              REPEAT
--                                  WHILE a >= b 
--                                      a = a - b 
--                                  ENDWHILE
--                                  swap (a, b)
--                              UNTIL (b = 0)
--                              gcd = a
--
--      where `a` and `b` are unsigned integers. This VHDL entity implements 
--      Euclid's subtraction algorithm using a full serial subtracter and 
--      a pair of internal 16-bit registers. In the interest of design size,
--      the design uses the following interpretation of Euclid's subtraction
--
--                              WHILE (b != 0)
--                                  WHILE (a - b) >= 0
--                                      a = a - b 
--                                  ENDWHILE
--                                  a = a + b
--                                  swap (a, b)
--                              ENDWHILE
--                              gcd = a      
--
--      which uses a restoring comparison. This is done so that (a < b) may 
--      be determined just by observing the carry out of the last serial 
--      bit subtraction operation in the calculation of (a - b). If there is 
--      no carry out (i.e. there is a borrow out), (a - b) < 0. The value of 
--      a must then be restored by adding b once.
--
--      The ending condition b = 0 is checked at the beginning of the loop to 
--      prevent the case GCD(a, 0), where a >= 0, from causing an infinite 
--      loop, as we do not handle such a case with case-specific logic.
--
--      The GCD calculation is begun when `nCalculate` becomes active (low). 
--      The calculation result is returned in `Result`. When the GCD calculation
--      finishes, `Result` will be held until `CanReadVals` is active, if it 
--      is not already active. Once this occurs, the GCD calculator will assert 
--      the `ResultRdy` active high flag, indicating a valid result. The result 
--      is valid for one clock. 
--
--      The GCD calculator is controlled by a Moore finite state machine with 
--      the following states
--              IDLE        Awaiting calculation start (`nCalculate` go active)
--                          Operand inputs are constantly loaded into internal 
--                          registers.
--              CHECK_ZERO  Check if the `B` input is zero. 
--              SUB         Subtracting A - B until A - B < 0
--              RESTORE     Adding B back to A 
--              SWAP        Swapping the operand registers
--              DONE        Done with computation, waiting for active 
--                          `CanReadVals` to indicate valid result. 
--
--      The active low `nCalculate` input is synchronized with a pair of DFFs.
--      The synchronized input controls the state transition from idle to 
--      calculation. Whenever the calculator is in the IDLE state, the 
--      GCD operands `A` and `B` are loaded into the internal register pair. 
--      When calculation begins, `B` = 0 is checked so that clocks may be 
--      saved should `B` indeed be zero.
--
--      Subtraction is performed with a N-bit full serial adder/subtracter. The 
--      registers `regA` and `regB` are shifted right and the LSBs are
--      subtracted. The difference is shifted into `regA` from the left while 
--      the rest of `regA` is shifted right. Meanwhile, `regB` is rotated 
--      right to keep the bits of the registers aligned. Serial subtraction 
--      is performed until `regA` < `regB` (when a serial subtract finishes 
--      with a borrow out). Then `regB` is added back (restore) to `regA` 
--      with one addition. An "addition/subtraction counter" `addSubCntr` is 
--      used to keep track of serial arithmetic; the counter runs from 0 to a 
--      top value of the number of bits of the operands.
--
--      The result is always whatever the system takes to be "A" (which may or 
--      may not be valid at any given time). A `ResultRdy` flag is generated 
--      to indicate valid result when the GCD calculation finishes (`regB` is 
--      zero) and the can read result input is active. If it is not, the 
--      FSM done state is latched until it is. Once `CanReadVals` is active,
--      the FSM transitions back to the idle state in one clock. 
--
-- Extra Credit Attempted:
--    - Size :  I chose to implement Euclid's subtraction with serial subtract 
--              and restoring compare to try for the smallest design possible.
--    - Speed : Yeah, no. Running this will take A While [TM]. In particular,
--              GCD(1, FFFF) will produce 
--
--                  (1 subtraction + 1 addition to swap 1 and FFFF) * 16
--              +   (2^16 + 1 subtracts + 1 add to have FFFF -> 0) * 16
--
--              for a nice, slow,
--
--                  2(16) + (2^(16) + 1)(16) = 1,048,624 clocks
--
-- Notes:
--    - The Calculate input is denoted as `nCalculate` to reflect the 
--      active low button input on the physical system board.
--    - Calculating GCD(a, 0) or GCD(0, a), where a != 0, will always result 
--      in `a`. This is due to the implementation of Euclid's subtraction.
--    - This Euclid's subtraction implementation was designed with a completely 
--      generic operand size, but is only used as a 16-bit GCD calculator 
--      in the overall system.
--    - This calculator was designed for minimum size.
--
-- Revision History:
--      12/07/2018          Ray Sun         Initial revision.
--      12/07/2018          Ray Sun         Implemented 'in-place' Euclid's 
--                                          subtraction with serial subtract
--      12/07/2018          Ray Sun         Fixed cases where B > A
--      12/08/2018          Ray Sun         Added 1 extra clock per subtraction 
--                                          to perform comparison correctly
--      12/08/2018          Ray Sun         Verified functionality with 
--                                          testbench
--      12/09/2018          Ray Sun         Made `bSelect` fully synchronous
--      12/09/2018          Ray Sun         Added more states for easier
--                                          handling of state transitions.
--                                          Namely, swap comparison.
--      12/09/2018          Ray Sun         Could not get swap-in-place to 
--                                          work on board. Re-designed to 
--                                          actually swap `aReg` and `bReg`
--      12/09/2018          Ray Sun         Got design working on board 
--      12/09/2018          Ray Sun         Implemented restoring comparison 
--                                          for efficiency
--      12/09/2018          Ray Sun         Got design working on board again
--      12/09/2018          Ray Sun         Improved documentation
--------------------------------------------------------------------------------


library ieee;                   -- Import the requisite packages
use ieee.std_logic_1164.all;    -- For 9-valued logic types
use ieee.numeric_std.all;       -- For unsigned type


--------------------------------------------------------------------------------
--                           Gcd ENTITY DECLARATION                           --
--------------------------------------------------------------------------------


-- GCD Calculator entity:
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
entity Gcd is 
    generic(
        N_BITS      :           integer := 16
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
    constant N_ZEROES :     std_logic_vector(N_BITS-1 downto 0) :=  
                                (others => '0');
                            
    -- Top value of serial arithmetic counter (number of bits - 1)
    constant ASCNTR_TOP :   unsigned(3 downto 0) := x"F";
    ----------------------------------------------------------------------------
    
    ---------------------- INPUT HANDLING SIGNALS ------------------------------
    -- A pair of registered signals (DFFs) for synchrnonizing calculate input
    signal nCalculateS :    std_logic_vector(1 downto 0);
    ----------------------------------------------------------------------------
    
    ------------------------- STATE SIGNALS ------------------------------------
    -- GCD calculator FSM states (2 state bits for 4 states)
    type GCDCALCSTATE is (  IDLE,       -- Awaiting calculation start 
                            CHECK_ZERO, -- Check if B = 0
                            SUB,        -- A <= A - B until A < B
                            RESTORE,    -- Add B back
                            SWAP,       -- A <=> B
                            DONE );     -- done calculating
    
    signal currState :  GCDCALCSTATE;   -- Current and next state signals
    signal nextState :  GCDCALCSTATE;
    
    -- Counter for control of the serial subtraction and restore (addition)
    --    - Need 0 to `N_BITS`-1 range since each serial arithmetic operation 
    --      takes `N_BITS` clocks
    --    - Hard-code in range for synthesis
    --signal addSubCntr :    unsigned(integer(
    --                          ceil(log2(real(N_BITS))))-1 downto 0);
    signal addSubCntr :    unsigned(3 downto 0);
    ----------------------------------------------------------------------------
    
    --------------------------- REGISTERS --------------------------------------
    -- Shift registers for the operands `A` and `B`
    --      Serially loaded when calculation starts
    signal regA     :   std_logic_vector(N_BITS-1 downto 0);
    signal regB     :   std_logic_vector(N_BITS-1 downto 0);
    ----------------------------------------------------------------------------
    
    ----------------- SERIAL FULL SUBTRACTER SIGNALS ---------------------------
    signal subtract   : std_logic;      -- active high subtraction select
                                        -- adding when low
                                        
    signal minuend :    std_logic;      -- Bits for the full subtracter 
    signal subtrahend : std_logic;      --    minuend - subtrahend = difference
    signal difference : std_logic;
    
    signal carryOut   : std_logic;      -- The carry out (carry = !borrow)
    signal carryFlag  : std_logic;      -- Registered borrow in
    ----------------------------------------------------------------------------
    
begin

    ----------------------------------------------------------------------------
    --                              INPUT                                     --
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
    
    
    -------------------------- State logic process -----------------------------
    -- Determine the next FSM state combinationally
    process ( currState, nCalculateS(1), CanReadVals, 
              regB, addSubCntr, carryOut)
    begin
        case currState is
            -- If in the idle state, the synchronized `nCalculate` is low, 
            -- and we can read, start calculating
            when IDLE => 
                if nCalculateS(1) = '0' and CanReadVals = '1' then 
                    nextState <= CHECK_ZERO;
                else 
                    nextState <= IDLE;     -- Don't infer latch
                end if;
            -- Check if `B` is zero - if so, then done
            when CHECK_ZERO =>
                if (regB = N_ZEROES) then
                    nextState <= DONE;
                else 
                    nextState <= SUB;
                end if;
            -- If subtracting, keep subtracting until `A` becomes negative
            -- (there is a borrow out).
            --    - Done with current subtraction operation (counter is at top)
            --    - Borrow out.
            when SUB =>
                if (addSubCntr = ASCNTR_TOP) and
                   (carryOut = '0') then 
                    nextState <= RESTORE;
                else 
                    nextState <= SUB;     -- Don't infer latch
                end if;
            -- Add back `B` whenever `A - B` is less than `B` - do one addition
            -- (add until the counter is at top)
            when RESTORE =>
                if (addSubCntr = ASCNTR_TOP) then 
                    nextState <= SWAP;
                else 
                    nextState <= RESTORE; -- Don't infer latch
                end if;
            -- Swap state takes 1 clock only; go check if `B` is zero
            when SWAP =>
                nextState <= CHECK_ZERO;
            -- Only leave the done state if `CanReadVals` is active (high)
            -- so the system can read outputs
            when DONE =>
                if CanReadVals = '1' then
                    nextState <= IDLE;
                else 
                    nextState <= DONE;     -- Don't infer latch
                end if;    
        end case;
    end process;
    ----------------------------------------------------------------------------
    
    ------------------------ Update state process ------------------------------
    -- register the new current state on `SysClk`
    process (SysClk)
    begin 
        if rising_edge(SysClk) then 
            currState <= nextState;
        end if;
    end process;
    ----------------------------------------------------------------------------
    
    
    ----------------------------------------------------------------------------
    --                        GCD CALCULATOR STATE                            --
    ----------------------------------------------------------------------------
    
    
    ------------------------ Add/sub counter process ---------------------------
    -- Process to increment or clear add/sub counter 
    --    - Synchronously cleared whenever not subtracting or restoring 
    --    - Synchronously incremented otherwise
    process (SysClk)
    begin 
        if rising_edge(SysClk) then 
            -- If subtracting or restoring for compare, increment the counter
            if (currState = SUB) or 
               (currState = RESTORE) then
                addSubCntr <= addSubCntr + 1;
            -- Otherwise reset 
            else 
                addSubCntr <= (others => '0');
            end if;
        end if;
    end process;
    ----------------------------------------------------------------------------
    
    
    ------------------------ Full adder/subtracter -----------------------------
    -- We are subtracting if in the subtracting state 
    subtract    <=  '1' when currState = SUB else 
                    '0';
    
    -- The minuend is the LSB of A, the subtrahend is the LSB of B
    minuend     <=  regA(regA'right);
    subtrahend  <=  regB(regB'right);
                
    -- Compute the difference bit (full adder sum with inverted subtrahend)
    difference  <=  minuend xor 
                    subtrahend xor 
                    subtract xor carryFlag;
                    
    -- Compute the carry out (full adder carry out with inverted subtrahend)
    carryOut    <=  ( carryFlag and 
                        ( minuend xor subtrahend xor subtract ) ) or
                    ( minuend and (subtrahend xor subtract) );     
                    
    -- Process that determines when to enable or preset the carry flag
    --      Effectively a DFF with preset 
    process (SysClk)
    begin
        if rising_edge(SysClk) then 
            -- Preset the carry (clear the borrow) before subtraction is done
            if (currState = CHECK_ZERO) then 
                carryFlag <= '1';
            -- Otherwise register the carry out for the next operation
            else
                carryFlag <= carryOut;
            end if;
        end if;
    end process;
    ----------------------------------------------------------------------------
    
    
    ----------------------------------------------------------------------------
    --                        GCD REGISTER CONTROL                            --
    ----------------------------------------------------------------------------
    
    
    ----------------------- Register update process ----------------------------
    -- Updates each of the operand registers synchronously based on the 
    -- current state
    process (SysClk)
    begin 
        if rising_edge(SysClk) then 
            -- Determine operations based on current system state
            case currState is 
                -- Load the operands when in the idle state 
                when IDLE =>
                    regA <= A;
                    regB <= B;
                -- When subtracting (or restoring), the difference (or sum) 
                -- is shifted into `A` from the left, `A` is shifted right, and 
                -- `B` is rotated right 
                when SUB =>
                    regA <= difference     & regA(regA'high downto regA'low+1);
                    regB <= regB(regB'low) & regB(regB'high downto regB'low+1);
                when RESTORE =>
                    regA <= difference     & regA(regA'high downto regA'low+1);
                    regB <= regB(regB'low) & regB(regB'high downto regB'low+1);
                -- When swapping, swap the registers
                when SWAP =>
                    regA <= regB;
                    regB <= regA;
                -- Otherwise, don't change (do not infer latch)
                when others =>
                    regA <= regA;
                    regB <= regB;
            end case;
        end if;
    end process;
    ----------------------------------------------------------------------------
    
    
    ----------------------------------------------------------------------------
    --                              OUTPUT                                    --
    ----------------------------------------------------------------------------
    
    
    -- The GCD result is always just whatever `A` is when the result is ready
    Result  <=  std_logic_vector(regA);
    
    -- Set the result ready flag high when appropriate for the system to read -
    -- when done and `CanReadVals` is active
    ResultRdy <=    '1' when (currState = DONE) and 
                             (CanReadVals = '1') else
                    '0';

end architecture;


--------------------------------------------------------------------------------