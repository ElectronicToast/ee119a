--------------------------------------------------------------------------------
-- bitserme.vhd - n-bit Bit-Serial Multiplier
--
-- This is an implementation of an n-bit bit serial multiplier.  The
-- calculation will take 2n^2 clocks after the START signal is activated.
-- The multiplier is implemented with a single full adder.
--
-- Generic Parameters:
--      numbits - number of bits in the multiplicand and multiplier (n)
--
-- Inputs:
--      A       - `numbits`-bit unsigned multiplicand
--      B       - `numbits`-bit unsigned multiplier
--      START   - active high signal indicating a multiplication is to start
--      CLK     - clock input (rising edge active)
--
-- Outputs:
--      Q       - (2*numbits-1)-bit product (multiplication result)
--      DONE    - Active high signal indicating the multiplication is complete
--                and the Q output is valid
--
-- Details:
--      This VHDL module implements a bit-serial multiplier that carries out 
--      multiplication of two `numbits`-bit long unsigned numbers (SLV input)
--      that closely resembles a binary form of grade-school multiplication.
--      The bit-serial multiplier was designed according to the general serial 
--      multiplier layout presented in EE 119a. In considering grade-school 
--      multiplication of binary numbers, e.g.
--
--                      5               101
--                    x 5             x 101
--                   -----           -------
--                     25               101
--                                     000
--                                  + 101
--                                  --------
--                                    11001 = 25
--
--      we may perform this with the serial multiplier layout presented in 
--      class as follows
--
--       Multiplicand (A)   Multiplier (B)    Product (Q)
--            101               101             000000  Carry
--      Start
--            101               101          -> 100000      \
--              ^                 ^             ^           |
--            110               101          -> 010000      |   Multiply each
--              ^                 ^             ^           |   bit in A by LSB
--            011               101          -> 101000      |   of B
--              ^                 ^             ^           /
--                               |              010100      \
--                            Rotate B          001010      |   Rotate Q right 
--                               |              000101      |   until 2s place
--                              \|/             100010      /   is LSB
--            101               110          -> 010001      \
--              ^                 ^             ^           |
--            110               110          -> 101000      |   Multiply each
--              ^                 ^             ^           |   bit in A by 1st
--            011               110          -> 010100      |   bit of B
--              ^                 ^             ^           /
--                               |              001010      \
--                            Rotate B          000101      |   Rotate Q right 
--                               |              100010      |   until 4s place
--                              \|/             010001      /   is LSB
--            101               011          -> 001000  C=1 \
--              ^                 ^             ^           |
--            110               011          -> 100100      |   Multiply each
--              ^                 ^             ^           |   bit in A by 1st
--            011               011          -> 110010      |   bit of B
--              ^                 ^             ^           /
--                                           -> 011001          Propagate 
--                                              = 25            final carry 
--
--      In general, the serial multiplication algorithm is:
--          1) Multiply each bit in A by the LSB of B and shift the result 
--            into Q.
--          2) Rotate Q until the 2's place is in the LSB of Q =
--          3) Multiply each bit in A by the 2's place bit in B, and propagate
--             carry.
--          4) Rotate Q with carry (propagate final carry from the `numbits`
--             additions when rotating A around, if necessary, into the first 
--             rotation).
--          5) Repeat (3) and (4) until at MSB of B. Then multiply each bit 
--             in A by the MSB in B serially as before.
--          6) Rotate Q one final time to propagate the final carry and obtain
--             the result.
--
--      This sort of cyclic multiplication is implemented with a three-state 
--      Mealy finite state machine. The default state is IDLE, in which the 
--      system awaits a START signal. On the rising edge of CLK with an 
--      active START, the FSM transitions into a MULTIPLYING state, indicating 
--      multiplication is in progress. When the multiplication is complete, 
--      the FSM transitions to a FINISHED state, which asserts the active high 
--      DONE signal for one clock. On the next clock, the FSM transitions back 
--      to IDLE. The output decoding of the FSM is designed so that the 
--      multiplication output is valid until the next rising edge of CLK 
--      with START active.
--
--      To simplify the implementation of the "rotate A, then rotate Q, then 
--      rotate B" logic in the bit-serial multiplication algorithm, three 
--      internal system counters are used.
--          - A shift counter - counts the number of shifts (i.e. right rotates)
--                              done on A. This counter goes from 0 to a top 
--                              value of `numbits`-1 for each bit in `B`, from 
--                              LSB to MSB.
--          - B shift counter - counts the number of right rotates done on B.
--                              This counter goes from 0 to a top value of 
--                              `numbits` once per multiplication. 
--                              Multiplication is finished when this counter 
--                              reaches the top value.
--          - Q shift counter - counts the number of right rotates (with carry
--                              into the full adder) done on Q when rotating 
--                              around after multiplying every bit in A with 
--                              a bit in B. This counter goes from 0 to a top 
--                              value of `numbits`+1, as that many rotates 
--                              are required to effectively right shift the 
--                              value in Q once (move the "cursor" up a digit).
--
--      With these counts (denoted a, b, and q) annotated, the sample
--      calculation would look like this 
--
--             A        a        B       b         Q        q
--            101       0       101      0      000000      0
--      Start
--            101       0       101      0   -> 100000      0
--              ^                 ^             ^       
--            110       1       101      0   -> 010000      0
--              ^                 ^             ^       
--            011       2       101      0   -> 101000      0
--              ^                 ^             ^       
--                               |              010100      1
--                            Rotate B   1      001010      2
--                               |              000101      3
--                              \|/             100010      4
--            101       0       110      1   -> 010001      0
--              ^                 ^             ^       
--            110       1       110      1   -> 101000      0
--              ^                 ^             ^       
--            011       2       110      1   -> 010100      0
--              ^                 ^             ^       
--                               |              001010      1
--                            Rotate B   2      000101      2
--                               |              100010      3
--                              \|/             010001      4
--            101       0       011      2   -> 001000      0
--              ^                 ^             ^       
--            110       1       011      2   -> 100100      0
--              ^                 ^             ^       
--            011       2       011      2   -> 110010      0
--              ^                 ^             ^       
--                                       3   -> 011001      1
--                                              = 25    
--
--      The B count increments whenever the A count reaches top. The Q count 
--      runs from 0 to `numbits`+1 whenever the A count reaches top.
--
--      The FSM uses these counter values in addition to the current state to 
--      generate outputs 
--          - AND enable      - The FSM control line to the AND gate that 
--                              performs the serial multiplication. The AND 
--                              gate is inactive when Q is being rotated around
--                              and also for the final carry propagate rotate 
--                              of Q.
--          - Carry DFF clear - The carry DFF that registers the carry out 
--                              of the full adder as the next 
--          - Serial enable signals for the shift registers A, B, and Q. The 
--            former shift registers are internal registered signals.
--          - Parallel load enables for the registers that allow inputs A and B 
--            to be loaded in during IDLE, and for the Q buffer to be cleared.
--
-- Usage notes:
--      - DONE is active for one clock period after the multiplication 
--        operation completes.
--      - After a multiplication, the product is valid until the first rising 
--        edge on CLK where START is active.
--      - The product register is cleared synchronously whenever START is
--        active. Thus, when a multiplication operation completes, the 
--        product register is valid until the next operation.
--
-- Implementation notes:
--      - The extra credit is not attempted. The multiplication process will 
--        always run for at least 2 * n^2 clocks.
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
--      11/21/2018      Ray Sun     Gave signals more sensible names.
--      11/22/2018      Ray Sun     Verified functionality exhaustively for 
--                                  `numbits` from 2 to 4 with testbench.
--      11/22/2018      Ray Sun     Increased upper range of B shift counter 
--                                  by 1 to allow the multiplier to handle the 
--                                  1-bit case.
--      11/22/2018      Ray Sun     Improved documentation.
--      11/22/2018      Ray Sun     Improved documentation.
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
    constant SL_ONE:    std_logic := '1';
    constant SL_ZERO:   std_logic := '0';
    
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
    signal  serEnQ:     std_logic;      -- These are synchronous.
    signal  loadRegs:   std_logic;      -- Active high parallel load signal
                                        -- Used to load in multiplication
                                        -- inputs. Synchronous
    signal  clearQ:     std_logic;      -- Active high synchronous clear for
                                        -- Q to clear product register
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
    signal  shiftCountB:    integer range 0 to numbits+1;
    
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
    -- Clear Q on start (and synchronously with the register)
    clearQ <=       SL_HIGH when (currState = IDLE) and 
                                 (START = SL_HIGH) else 
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
                Areg(numbits-1) <= Areg(0);
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
                Breg(numbits-1) <= Breg(0);
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
            -- If the clear signal is active, then clear the product register 
            if clearQ = SL_HIGH then 
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