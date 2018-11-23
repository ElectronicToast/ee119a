--------------------------------------------------------------------------------
-- bitserme.vhd - n-bit Bit-Serial Multiplier
--
-- This is an implementation of an n-bit bit serial multiplier.  The
-- calculation will take 2n^2 clocks after the START signal is activated.
-- The multiplier is implemented with a single full adder.
--
-- Parameters:
--      numbits - number of bits in the multiplicand and multiplier (n)
--
-- Inputs:
--      A       - n-bit unsigned multiplicand
--      B       - n-bit unsigned multiplier
--      START   - active high signal indicating a multiplication is to start
--      CLK     - clock input (active high)
--
-- Outputs:
--      Q       - (2n-1)-bit product (multiplication result)
--      DONE    - active high signal indicating the multiplication is complete
--                and the Q output is valid
--
-- Implementation notes:
--      - DONE is active for one clock period after the multiplication 
--        operation completes.
--      - The product is valid for at least two clocks after the FSM state 
--        becomes DONE. 
--      - The product register is cleared synchronously whenever the FSM state 
--        is IDLE.
--
-- Notes:
--      - The extra credit is not attempted. The multiplication process will 
--        always run for 2 * n^2 clocks.
--
-- Revision History:
--      7 Apr 00  Glen George       Initial revision.
--     12 Apr 00  Glen George       Changed Q to be type buffer instead of
--                                  type out.
--     21 Nov 05  Glen George       Changed nobits to numbits for clarity
--                                  and updated comments.
--      11/21/2018      Ray Sun     Updated entity declaration provided
--                                  by Glen, thirteen years later...
--      11/21/2018      Ray Sun     Initial architecture revision.
--------------------------------------------------------------------------------


library ieee;                   -- Import the requisite packages
use ieee.std_logic_1164.all;    -- For 9-valued logic types


--------------------------------------------------------------------------------


entity BitSerialMultiplier is
    generic (
        numbits : integer    -- generic number of bits in the inputs
    );
    port (
        A     : in     std_logic_vector(numbits-1 downto 0);   -- Multiplicand
        B     : in     std_logic_vector(numbits-1 downto 0);   -- Multiplier
        START : in     std_logic;                              -- Start calculation
        CLK   : in     std_logic;                              -- Clock
        Q     : buffer std_logic_vector(2*numbits-1 downto 0); -- Product
        DONE  : out    std_logic                               -- Calculation completed
    );
end entity;


--------------------------------------------------------------------------------


architecture DataFlow of BitSerialMultiplier is 
    -- Boolean constants for std_logic types 
    constant SL_HIGH:   std_logic := '1';
    constant SL_LOW:    std_logic := '0';
    
    ---------------------------- REGISTERS -------------------------------------
    -- Internal (shift) registers for the multiplicand A and multiplier B
    signal  Areg:       std_logic_vector(numbits-1 downto 0); 
    signal  Breg:       std_logic_vector(numbits-1 downto 0);
    
    -- Adder output (serial input to Q, shifted into MSB)
    signal  Qin:        std_logic;
    ----------------------------------------------------------------------------
    
    --------------------------- FSM OUTPUTS ------------------------------------
    signal  serEnA:     std_logic;      -- Active high erial shift enable 
    signal  serEnB:     std_logic;      -- signals for the A, B, and Q registers 
    signal  serEnQ:     std_logic;
    signal  loadRegs:   std_logic;      -- Active high parallel load signal
                                        -- Used to load in multiplication
                                        -- inputs and clear product register
    signal  adderEnable:    std_logic;  -- Adder enable: FSM output to the 
                                        -- 3-input AND gate
    signal  carryClear: std_logic;      -- Synchronous carry clear (DFF clear)
    ----------------------------------------------------------------------------
    
    ---------------------- FSM OUTPUT DECODE LOGIC -----------------------------
    -- Count that keeps track of the number of times the multiplicand has 
    -- been shifted (rotated) right in multiplying. 
    --      A full rotation (LSB, 2ndLSB, 3rdLSB,..., MSB rotating into the LSB 
    --      position of A sequentially) occurs once for each bit in the 
    --      multiplier B.
    signal  shiftCountA:    integer range 0 to numbits-1;
    
    -- Count that keeps track of the number of times the multiplier has 
    -- been shifted (rotated) right in multiplying. 
    --      A full shift (MSB of B rotated into the LSB position) occurs once 
    --      per complete multiply operation. So this count increments only when 
    --      the A shift count is at its top value
    signal  shiftCountB:    integer range 0 to numbits;
    
    -- Counter that keeps track of the number of times Q has to be shifted 
    -- between successive multiplications of A by each bit in B 
    signal  shiftCountQ:    integer range 0 to numbits+1;
    
    -- Ranges for the A and B shift counters
    constant    SCA_BOTTOM:     integer := 0;
    constant    SCB_BOTTOM:     integer := 0;
    constant    SCQ_BOTTOM:     integer := 0;
    constant    SCA_TOP:        integer := numbits-1;
    constant    SCB_TOP:        integer := numbits;
    constant    SCQ_TOP:        integer := numbits+1;
    
    -- Need to shift in carry out one final time when done with multiplication 
    -- (the last carry when adding the most significant intermediate product in 
    -- 'grade school'-esque multiplication)
    constant    SCQ_FINISH:     integer := 1;
    ----------------------------------------------------------------------------

    ------------------- FSM STATES + TRANSITION LOGIC --------------------------
    type mul_states is(
        IDLE,           -- Awaiting multiplying start state
        MULTIPLYING,    -- Multiplying ongoing state 
        FINISHED        -- Done state
    );
    signal  currState:  mul_states := IDLE;     -- The current state
                                                -- Start off in IDLE 
    signal  nextState:  mul_states;             -- The next state on clock
    ----------------------------------------------------------------------------
    
    ---------------------- FULL ADDER + CARRY DFF ------------------------------
    signal  adderA:     std_logic;      -- Adder addend 1 - Q LSB 
    signal  adderB:     std_logic;      -- Adder addend 2 - AND gate output
                                        --      A(LSB) & B(LSB) & adderEnable
    signal  carryIn:    std_logic;      -- The current carry input (registered)
    signal  carryOut:   std_logic;      -- The carry out (registered to become 
                                        -- the carry input)
    ----------------------------------------------------------------------------
    
begin
    
    ----------------------------------------------------------------------------
    --                          MULTIPLIER FSM                                --
    ----------------------------------------------------------------------------
    
    
    ------------------------ NEXT STATE PROCESS --------------------------------
    process (CLK, START, currState)
    begin
        case currState is 
            when IDLE =>
                -- If not multiplying and START goes high, transition to the 
                -- multiplying state
                if START = SL_HIGH then 
                    nextState <= MULTIPLYING;
                -- Otherwise stay in IDLE
                else
                    nextState <= IDLE;
                end if;
            when MULTIPLYING =>
                -- If both A shift counter has reached top, B shift counter 
                -- has reached top (done multiplying the MSB in the multiplier)
                -- and Q shift counter is `SCQ_FINISH` (to shift in the carry 
                -- from the final serial addition), we are done 
                --if (shiftCountA = SCA_TOP) and (shiftCountB = SCB_TOP) and 
                --   (shiftCountQ = SCQ_FINISH) then 
                --if (shiftCountB = SCB_TOP) and (shiftCountQ = SCQ_FINISH) then 
                if shiftCountB = SCB_TOP then
                    nextState <= FINISHED;
                -- Otherwise stay in the multiplying state
                else 
                    nextState <= MULTIPLYING;
                end if;
            when FINISHED =>
                -- Always go back to IDLE (DONE is active for one clock period)
                nextState <= IDLE;
        end case;
    end process;
    ----------------------------------------------------------------------------
    
    ----------------------- STATE UPDATE PROCESS -------------------------------
    -- State updates are synchronous with clock rising edges.
    process (CLK)
    begin
        if rising_edge(CLK) then 
            currState <= nextState;
        end if;
    end process;
    ----------------------------------------------------------------------------
    
    ---------------------- OUTPUT DECODE PROCESS -------------------------------
    -- Done is active when in the finished state and inactive otherwise
    DONE <=         SL_HIGH when currState = FINISHED else 
                    SL_LOW;
    -- Parallel load signal is only active when not multiplying 
    loadRegs <=     SL_HIGH when currState = IDLE else 
                    SL_LOW;
    -- Carry DFF is only cleared when not multiplying 
    carryClear <=   SL_HIGH when currState = IDLE else 
                    SL_LOW;  
    -- Enable A shifting when multiplying and the Q counter is at bottom
    serEnA <=       SL_HIGH when (currState = MULTIPLYING) and 
                                 (shiftCountQ = SCQ_BOTTOM) else 
                    SL_LOW;
    -- Enable B shifting when multiplying and the A counter has reached top 
    serEnB <=       SL_HIGH when (currState = MULTIPLYING) and 
                                 (shiftCountA = SCA_TOP) else 
                    SL_LOW;
    -- Enable Q shifting when multiplying (Q is shifted on every clock 
    -- when multiplying)
    serEnQ <=       SL_HIGH when currState = MULTIPLYING else 
                    SL_LOW;
    -- Enable adding A(LSB) & B(LSB) only when multiplying and the Q shift 
    -- counter is at the bottom value
    adderEnable <=  SL_HIGH when (currState = MULTIPLYING) and 
                                 (shiftCountQ = SCQ_BOTTOM) else 
                    SL_LOW;      
    ----------------------------------------------------------------------------
    
    --------------------- SHIFT COUNTERS PROCESSES -----------------------------
    -- A shift counter 
    --      Increment whenever Q shift counter is zero and we are multiplying
    process (CLK, currState, shiftCountQ)
    begin 
        if rising_edge(CLK) then 
            -- Reset synchronously if in IDLE or at the top value
            if (currState = IDLE) or (shiftCountA = SCA_TOP) then
                shiftCountA <= SCA_BOTTOM;
            -- Increment whenever Q shift counter is zero and we are multiplying
            --elsif (currState = MULTIPLYING) and (shiftCountQ = SCQ_BOTTOM) then
            elsif serEnA = SL_HIGH then
                shiftCountA <= shiftCountA + 1;
            end if;
        end if;
    end process;
    
    -- B shift counter 
    --      Increment whenever A shift counter reaches top and we are multiplying
    process (CLK, currState, shiftCountA)
    begin 
        if rising_edge(CLK) then
            -- If IDLE, reset synchronously
            if currState = IDLE then 
                shiftCountB <= SCB_BOTTOM;
            -- Increment when we are multiplying and the A counter reaches top
            --elsif (currState = MULTIPLYING) and (shiftCountA = SCA_TOP) then
            elsif serEnB = SL_HIGH then
                shiftCountB <= shiftCountB + 1;
                -- No need to reset if at top since top value must persist for 
                -- two clocks. Also no need to reset during multiplication
            end if;
        end if;
    end process;
    
    -- Q shift counter 
    process (CLK, currState, shiftCountA)
    begin 
        if rising_edge(CLK) then
            -- If IDLE or at top value, then reset synchronously
            if (currState = IDLE) or (shiftCountQ = SCQ_TOP) then 
                shiftCountQ <= SCQ_BOTTOM;
            -- Otherwise increment if multiplying and
            --      A counter is at top value, or 
            --      the current count is nonzero
            elsif (serEnB = SL_HIGH) or (shiftCountQ /= SCQ_BOTTOM) then
                shiftCountQ <= shiftCountQ + 1;
            end if;
        end if;
    end process;
    ----------------------------------------------------------------------------

    
    ----------------------------------------------------------------------------
    --                         SHIFT REGISTERS                                --
    ----------------------------------------------------------------------------
    
    
    ----------------------- MULTIPLICAND REGISTER ------------------------------
    -- Update the register on clock rising edges
    process (CLK)
    begin
        if rising_edge(CLK) then
            -- If the parallel load signal is active, load in the multiplicand
            -- Parallel load takes precedence over serial enable
            if loadRegs = SL_HIGH then
                Areg <= A;
            -- Otherwise, if serial enable is active, rotate the register
            -- LSB becomes MSB, everything else shifted right
            elsif serEnA = SL_HIGH then
                Areg(0) <= Areg(numbits-1);
                rotate_a_loop : for i in 0 to numbits-2 loop 
                    Areg(i) <= Areg(i+1);
                end loop;
            end if;
        end if;
    end process;
    ----------------------------------------------------------------------------
    
    ------------------------ MULTIPLIER REGISTER -------------------------------
    -- Update the register on clock rising edges
    process (CLK)
    begin
        if rising_edge(CLK) then
            -- If the parallel load signal is active, load in the multiplier
            -- Parallel load takes precedence over serial enable
            if loadRegs = SL_HIGH then
                Breg <= B;
            -- Otherwise, if serial enable is active, rotate the register
            -- LSB becomes MSB, everything else shifted right
            elsif serEnB = SL_HIGH then
                Breg(0) <= Breg(numbits-1);
                rotate_b_loop : for i in 0 to numbits-2 loop 
                    Breg(i) <= Breg(i+1);
                end loop;
            end if;
        end if;
    end process;
    ----------------------------------------------------------------------------
    
    ----------------------------- PRODUCT REGISTER -----------------------------
    -- Update the register on clock rising edges
    process (CLK)
    begin
        if rising_edge(CLK) then
            -- If the load signal is active, then clear the product register 
            if loadRegs = SL_HIGH then 
                Q <= (others => SL_LOW);
            -- Otherwise, if the serial enable is active, then shift in 
            -- adder output from the left and cycle the LSB as the first addend
            elsif serEnQ = SL_HIGH then 
                Q(2*numbits-1) <= Qin;      -- Shift in adder output from left 
                -- Shift all non-LSB bits right 
                shift_q_loop : for i in 0 to 2*numbits-2 loop
                    Q(i) <= Q(i+1);
                end loop;
                -- The new 1st addend is the shifted out LSB 
            end if;
        end if;
    end process;
    ----------------------------------------------------------------------------
    
    
    ----------------------------------------------------------------------------
    --                           ADDER LOGIC                                  --
    ----------------------------------------------------------------------------
    
    
    --------------------------- ADDER INPUT ------------------------------------
    adderA <= Q(0);         -- The 1st addend is the LSB of Q
    adderB <= Areg(0) and BReg(0) and adderEnable;  -- The 2nd addend is A(LSB)
                                                    -- & B(LSB) & EN from FSM
    ----------------------------------------------------------------------------
    
    --------------------------- FULL ADDER -------------------------------------
    Qin <= adderA xor adderB xor carryIn;           -- Adder sum 
    carryOut <= (adderA and AdderB) or
                (carryIn and (adderA xor adderB));  -- Adder carry out
    ----------------------------------------------------------------------------
    
    ---------------------------- CARRY DFF -------------------------------------
    -- DFF is clocked from system clock
    process (CLK)
    begin
        if rising_edge(CLK) then 
            -- Synchronous clear - if active, clear the DFF output (carry in)
            if carryClear = SL_HIGH then 
                carryIn <= SL_LOW;
            -- Otherwise 'this' carry in is the 'previous' carry out
            else 
                carryIn <= carryOut;
            end if;
        end if;
    end process;
    ----------------------------------------------------------------------------
end architecture;