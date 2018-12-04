--------------------------------------------------------------------------------
--                                div16.vhd                                   --
--                          16-bit Serial Divider                             --
--------------------------------------------------------------------------------
--
-- Description:
--      This file contains a VHDL entity `Div16` and corresponding architecture
--      `DataFlow` that implements a 16-bit unsigned bit-serial divider. The 
--      design reads input from the keypad and displays the dividend and 
--      divisor on the seven-segment displays. When the calculate button is 
--      pressed, bit-serial division is performed and the quotient is displayed 
--      on the seven-segment displays. The input and displayed values are 
--      in hexadecimal format. For either dividend or divisor input, only the 
--      last four most recently entered digits are used. The values of the 
--      dividend and divisor inputs are preserved.
--
-- Generic Parameters:
--      None 
--
-- Inputs:
--     nCalculate               Active low calculate start input
--     Divisor                  Active high divisor input select (low for
--                              the dividend)
--     KeypadRdy                Active high key available signal
--     Keypad(3 downto 0)       Keypad input hex digit
--     CLK                      The clock (1 MHz)
--  
-- Outputs: 
--     HexDigit(3 downto 0)     The hex digit to display (to segment decoder)
--     DecoderEn                Enable for the 4:12 digit decoder
--     DecoderBit(3 downto 0)   The digit to display (to 4:12 decoder)
--
-- Table of Contents:
--      entity              Div16
--      architecture        DataFlow
--
-- Details:
--      The I/O peripherals of the divider comprise a 16-digit hex keypad and a 
--      set of three four-digit seven-segment displays. The user inputs the 
--      dividend and divisor, two unsigned 16-bit hex values, using a keypad and
--      a toggle switch to indicate which input is being entered. If more than
--      four hex digits are entered for a value, the most significant nibble is 
--      lost and new input is shifted in as the least significant nibble. 
--      Two of the four-digit SSDs are used to display the divident and quotient
--
--      The system also has a Calculate button, which when pressed performs the 
--      division. The quotient is displayed on the third four-digit SSD. The 
--      dividend and divisor are restored after the calculation and may be 
--      viewed with the quotient.
--
--      The divider design is built around a 13-nibble (13 hex digit) shift 
--      register `DigitBits` and a 4-digit (word) remainder register with the 
--      following layout 
--
--          Remainder register                Digit register
--            | Remainder |     | Quotient | Divisor | Dividend | Dummy |
--            | 16      0 |     | 51    36   35   20   19     4   3   0
--
--      The digit register comprises 48 bits (3 words) of data for the quotient,
--      divisor, and dividend. There is an extra nibble of extraneous 'dummy'
--      data that is used as calculation time. The digit register is rotated 
--      right nibble-by-nibble, and the low nibble is output to display. 
--      Division is performed if `nCalculate` is active and the dummy nibble 
--      is in the least significant digit (LSD) position. The active digit 
--      cycles according to 
--
--           3, 2, 1, 0,     7, 6, 5, 4,     11, 10, 9, 8           15
--         |    Dividend      Divisor         Quotient      |      Dummy
--         |                 Display time                   |   Calculate time |
--
--      and the active digit is cycled at a 1 kHz rate. 
--
--      The division algorithm works by performing iterative bit-serial
--      addition or subtraction on each bit in the dividend, starting with 
--      the most significant bit. 
-- 
-- Extra Credit Attempted:
--      - Preserve Dividend and Divisor
--      - Segment Decoding
--      - Digit Decoding
--
-- Revision History:
--     25 Nov 18  Glen George       Initial version (from 11/21/09 version
--                                     of addsub16.abl)
--     27 Nov 18  Glen George       Changed HaveKey logic to be flip-flop
--                                     based instead of an implied latch.
--     27 Nov 18  Glen George       Changed some constants to match Vivado
--                                     syntax.
--     11/28/2018   Ray Sun         Modified `addsub16` 16-bit full adder/ 
--                                  subtracter design by Glen into the divider
--                                  implementation.
--     11/28/2018   Ray Sun         Began implementing divider; finished  
--                                  modifying documentation.
--     11/29/2018   Ray Sun         Finished divider implementation.
--     12/01/2018   Ray Sun         Fixed divisor count logic by adding extra
--                                  clock with divisor rotate held at the end 
--                                  of an operation to propagate the correct 
--                                  Carry / !Borrow.
--     12/01/2018   Ray Sun         Fixed `CurDigit` cycling errors.
--     12/02/2018   Ray Sun         Verified functionality with `Div16_tb` 
--                                  testbench.
--     12/03/2018   Ray Sun         Verified functionality with more test cases.
--     12/03/2018   Ray Sun         Improved documentation.
--     12/03/2018   Ray Sun         Verified functionality on board.
--     12/03/2018   Ray Sun         Branched off from non-EC version.
--     12/03/2018   Ray Sun         Got segment decoding working on board.
--------------------------------------------------------------------------------


library ieee;                   -- Import the requisite packages
use ieee.std_logic_1164.all;    -- For 9-valued logic types
use ieee.numeric_std.all;       -- For unsigned type


--------------------------------------------------------------------------------
--                          Div16 ENTITY DECLARATION                          --
--------------------------------------------------------------------------------


entity Div16 is
    port (
        nCalculate  :  in   std_logic;
        Divisor     :  in   std_logic;
        KeypadRdy   :  in   std_logic;
        Keypad      :  in   std_logic_vector(3 downto 0);
        --HexDigit    :  out  std_logic_vector(3 downto 0);
        SsdDigit    :  out  std_logic_vector(0 to 6);
        --SsdSel      :  out  std_logic_vector(11 downto 0);
        DecoderEn   :  out  std_logic;
        DecoderBit  :  out  std_logic_vector(3 downto 0);
        CLK         :  in   std_logic
    );
end entity;


--------------------------------------------------------------------------------
--                          Div16 ARCHITECTURE                                --
--------------------------------------------------------------------------------


architecture DataFlow of Div16 is
    
    ---------------------------- CONSTANTS -------------------------------------
    -- `std_logic` logical values 
    constant  SL_TRUE       :   std_logic := '1';
    constant  SL_FALSE      :   std_logic := '0';
    constant  SL_HIGH       :   std_logic := '1';
    constant  SL_LOW        :   std_logic := '0';
    
    -- Data sizes
    constant  NIBBLE_SIZE   :   integer := 4;
    constant  WORD_SIZE     :   integer := 16;
    constant  DIVIDER_SIZE  :   integer := 16;
    
    -- Numeric constants
    constant  NIBBLE_THREE  :  std_logic_vector(3 downto 0) := "0011";
    constant  NIBBLE_SEVEN  :  std_logic_vector(3 downto 0) := "0111";
    -- Dummy digit in whose mux time division is performed
    constant  CALC_DIGIT    :  std_logic_vector(3 downto 0) := "1111";
    
    constant  WORD_ZERO     :  std_logic_vector(15 downto 0) := x"0000";
    
    -- Synchronized `KeyReady` rising edge 
    --      Need 3 DFFs to synchronize and then rising edge detect
    constant  KRDYS_SIZE    :  integer := 3;
    constant  KRDYS_RISING_EDGE : 
                    std_logic_vector(KRDYS_SIZE-1 downto 0) := "01-";
    
    -- Division control counter ranges 
    constant  DVD_CNTR_LOW  :   integer := 0;               -- Range for the 
    constant  DVD_CNTR_HIGH :   integer := DIVIDER_SIZE;    -- dividend count
    constant  DVR_CNTR_LOW  :   integer := 0;               -- Range for the 
    constant  DVR_CNTR_HIGH :   integer := DIVIDER_SIZE;    -- divisor count
    
    -- Shift operation select opcodes 
    constant  SHIFTOP_SIZE  :   integer := 2;
    
    constant  SHIFTOP_HOLD  : std_logic_vector(SHIFTOP_SIZE-1 downto 0) := "00";
    constant  SHIFTOP_CALC  : std_logic_vector(SHIFTOP_SIZE-1 downto 0) := "01";
    constant  SHIFTOP_KEYIN : std_logic_vector(SHIFTOP_SIZE-1 downto 0) := "10";
    constant  SHIFTOP_SHIFT : std_logic_vector(SHIFTOP_SIZE-1 downto 0) := "11";
    
    -- Mux counter 
    constant  MUXCNTR_SIZE  :   integer := 10;
    constant  MUXCNTR_TOP   :   unsigned(MUXCNTR_SIZE-1 downto 0) :=
                                                            (others => '1');
    constant  MUXCNTR_BOTTOM  : unsigned(MUXCNTR_SIZE-1 downto 0) :=
                                                            (others => '0');
    
    -- Digit shift register
    --     12 nibbles (physical digits) + 1 nibble (dummy digit for calculation)
    constant  DIGIT_BITS    :   integer := 52;  -- Size of register 
    
    -- Size of the dummy calculation digit (bits)
    constant  CALC_DIG_SIZE :  integer := 4;
    
    -- Indices of low and high (LSB and MSB) of the dividend (DVD), divisor
    -- (DVR), and quotient (QTT) in `DigitBits` 
    --      Since calculation occurs when the extraneous digit is the least 
    --      significant digit, each index must have `CALC_DIG_SIZE` added
    constant  DVD_LOW       :   integer := 0  + CALC_DIG_SIZE; 
    constant  DVD_HIGH      :   integer := 15 + CALC_DIG_SIZE;
    constant  DVR_LOW       :   integer := 16 + CALC_DIG_SIZE;
    constant  DVR_HIGH      :   integer := 31 + CALC_DIG_SIZE;
    constant  QTT_LOW       :   integer := 32 + CALC_DIG_SIZE;
    constant  QTT_HIGH      :   integer := 47 + CALC_DIG_SIZE;
                                                
    constant  DVD_2SD_HIGH  :   integer := 11;  -- High bit of second most
                                                -- significant digit in dividend
    constant  DVR_2SD_HIGH  :   integer := 27;  -- High bit of second most
                                                -- significant digit in divisor
    
    -- Remainder shift register
    constant  REM_BITS      :   integer := 17;  -- Size of remainder register
    ----------------------------------------------------------------------------
    
    
    -------------------------- KEYPAD SIGNALS ----------------------------------
    signal  HaveKey     :  std_logic;   -- Active high have a key from keypad
    
    -- Registered signals for synchronizing and rising edge detection of 
    -- `KeypadRdy`
    signal  KeypadRdyS  :  std_logic_vector(KRDYS_SIZE-1 downto 0);
    
    -- Registered signals for synchronizing `nCalculate` input and `Divisor` 
    -- divisor entry select switch
    signal  nCalculateS :  std_logic_vector(1 downto 0);
    signal  DivisorS    :  std_logic_vector(1 downto 0);
    ----------------------------------------------------------------------------
    
    --------------------- DIVISION CONTROL SIGNALS -----------------------------
    -- Counter that keeps track of the current bit in the dividend 
    --         0       1    to      DIVIDER_SIZE-1      DIVIDER_SIZE
    --         MSB    2MSB          LSB              Done with division 
    signal  DividendCount : integer range 0 to DIVIDER_SIZE := 0;
    
    -- Counter that keeps track of the addition/subtraction for each digit 
    -- in the remainder/divisor 
    --      Need to add or subtract `DIVIDER_SIZE` times per add/sub and do 
    --      a final comparison in order to propagate the carry.
    signal  DivisorCount :  integer range 0 to DIVIDER_SIZE := 0;
    ----------------------------------------------------------------------------
    
    ------------------------ DIVISION SIGNALS ----------------------------------
    signal  DivCalcEn       :  std_logic;  -- Active high division enable signal    
    
    -- One-bit full adder/subtracter 
    signal  Subtract        :   std_logic;      -- Active high subtract select 
                                                -- Low if adding
    signal  AddSubBin       :  std_logic;       -- Second addend / subtrahend 
                                                -- of add/sub 
    signal  AddSubResult    :  std_logic;       -- sum/difference output
    signal  AddSubCarryOut  :  std_logic;       -- carry/borrow out
    signal  CarryFlag       :  std_logic;       -- registered carry flag
    ----------------------------------------------------------------------------
    
    --------------------- LED MULTIPLEXING SIGNALS -----------------------------
    -- Multiplex counter (to divide 1 MHz to 1 kHz)
    signal  MuxCntr     :   unsigned(MUXCNTR_SIZE-1 downto 0) := 
                                (others => '0');
    
    signal  DigitClkEn   :  std_logic;  -- Active high enable for digit clock
    
    -- The current MUXed digit (initialize to bottom of dividend)
    signal  CurDigit    :  std_logic_vector(NIBBLE_SIZE-1 downto 0) :=
                                NIBBLE_THREE;
    ----------------------------------------------------------------------------
    
    ----------------- SHIFT REGISTER OPERATION (FSM OUT) -----------------------
    -- Signals to select shift register operation
    --     ShiftOp = 0  :  hold
    --     ShiftOp = 1  :  division shift
    --     ShiftOp = 2  :  keypad input shift
    --     ShiftOp = 3  :  display shift
    signal    ShiftOp   :  std_logic_vector(SHIFTOP_SIZE-1 downto 0);
    ----------------------------------------------------------------------------

    ------------------------- STORED DIGITS ------------------------------------
    -- 12 stored hex digits (48 bits) and a dummy digit for calculation (4 bits)
    -- in a shift register. 4 hex digits (16 bits) of remainder in a separate
    -- shift register.
    --
    -- Format:
    --
    --      | Remainder |   | Quotient | Divisor | Dividend | Dummy |
    --      | 16      0 |   | 51    36   35   20   19     4   3   0 |
    -- 
    signal  DigitBits       :  std_logic_vector(DIGIT_BITS-1 downto 0);
    signal  RemainderBits   :  std_logic_vector(REM_BITS-1 downto 0);
    ----------------------------------------------------------------------------

begin
    
    ----------------------------------------------------------------------------
    --                              INPUTS                                    --
    ----------------------------------------------------------------------------
    
    
    ------------------------ Edge & Key Detetion  ------------------------------
    -- Edge and key detection for `KeypadRdy`
    process(CLK)
    begin
        if rising_edge(CLK) then  
            -------------- Synchronize KeypadRdy -------------------------------
            -- Shift the keypad ready signal through three DFFs 
            -- to synchronize (2 DFFs) and edge detect (1 DFF) using 
            -- `KeypadRdyS` internal signal
            KeypadRdyS  <=  KeypadRdyS(1 downto 0) & KeypadRdy;
            --------------- Key input reading ----------------------------------
            -- We have a key if 
            --      - have one already that hasn't been processed, or 
            --      - a new one is coming in (rising edge of KeypadRdy), 
            -- Reset if on the last clock of Digit 3 or Digit 7 (depending on 
            -- position of the divisor switch) and held otherwise
            --
            -- Set `HaveKey` on rising edge of synchronized `KeypadRdy`
            -- (a synchronized low, then a synchronized high, detected)
            -- `KeypadRdy` is active high 
            if  (std_match(KeypadRdyS, "01-")) then
                HaveKey <=  SL_TRUE;
            -- Reset `HaveKey` if on Dividend mode and current digit is 3
            elsif ( (DigitClkEn = SL_TRUE)    and 
                    (CurDigit = NIBBLE_THREE) and 
                    (Divisor = SL_FALSE) ) then
                HaveKey <=  SL_FALSE;
            -- Reset `HaveKey` if on Divisor mode and current digit is 7
            elsif ( (DigitClkEn = SL_TRUE)    and 
                    (CurDigit = NIBBLE_SEVEN) and 
                    (Divisor = SL_TRUE) ) then
                HaveKey <=  SL_FALSE;  
            -- Otherwise, hold the value of `HaveKey`
            else
                HaveKey <=  HaveKey;
            end if;
        end if;
    end process;
    ----------------------------------------------------------------------------


    ------------------------ Synchronize Inputs --------------------------------
    -- Pass `nCalculate` and `Divisor` through a pair of DFFs to synchronize 
    process (CLK)
    begin 
        -- On rising edge, shift the signals
        if rising_edge(CLK) then 
            nCalculateS <= nCalculateS(0) & nCalculate;
            DivisorS <= DivisorS(0) & Divisor;
        end if;
        -- Use high bit of `nCalculateS` - the synchronized input - to determine 
        -- when to start dividing
    end process;
    ----------------------------------------------------------------------------
    
    
    -------------------------- Division Enable ---------------------------------
    -- Latch `DivCalcEn`, the active high division enable signal, based on the 
    -- synchronized `nCalculate` input 
    process (CLK)
    begin 
        if rising_edge(CLK) then 
            -- If at the calculation digit, 
            if (CurDigit = CALC_DIGIT) and 
               (MuxCntr = MUXCNTR_BOTTOM) and
               (nCalculateS(1) = SL_LOW) then 
                DivCalcEn <= SL_TRUE;
            -- If dividing and division counters are high, then clear 
            elsif (DividendCount = DVD_CNTR_HIGH) and 
                  (DivisorCount  = DVR_CNTR_HIGH) then 
               DivCalcEn <= SL_FALSE;
            -- Otherwise hold 
            else 
                DivCalcEn <= DivCalcEn;
            end if;
        end if;
    end process;
    ----------------------------------------------------------------------------
    
    
    ----------------------------------------------------------------------------
    --                             DIVISION                                   --
    ----------------------------------------------------------------------------
    
    
    -------------------- Adder/Subtracter Subtract Select ----------------------
    -- Check to see if need to toggle Subtract (! Add)
    process (CLK)
    begin 
        if rising_edge(CLK) then 
            -- If dividing,
            if ShiftOp = SHIFTOP_CALC then 
                -- Update when an add/sub finishes 
                if DivisorCount = DVR_CNTR_HIGH then 
                    -- Subtract if adding and there was a carry 
                    --      or subtracting and there was no borrow 
                    -- Add if subtracting and there was a borrow 
                    --      or adding and there was no carry 
                    -- So the next `Subtract` is the final carry out in the 
                    -- add/sub operation
                    Subtract <= AddSubCarryOut;
                -- Otherwise do not update
                else 
                    Subtract <= Subtract;
                end if;
            -- If not dividing, always preset (so division starts with sub)
            else 
                Subtract <= SL_TRUE;
            end if;
        end if;
    end process;
    ----------------------------------------------------------------------------
    
    ------------------------ Full Adder/Subtracter -----------------------------
    -- Adder `B` addend (addend 2, or subtractend) 
    --      This must be set to zero whenever the divisor clock reaches top 
    --      since we must do a compare operation to propagate the final carry 
    --      out whenever an operation finishes. If not at top, is the low bit 
    --      of the divisor.
    --
    --      This only really matters for CarryOut, so not used for the result
    AddSubBin <= '0' when DivisorCount = DVR_CNTR_HIGH else 
                 DigitBits(DVR_LOW);
    
    -- one-bit adder/subtracter (operation determined by Subtract active 
    -- high subtract select input)
    --
    -- Adds/subtracts low bits of the operands 
    --              Remainder       +/-         Divisor
    --              16 ... 0        +/-     DigitBits(31...16)
    --
    -- Result is Remainder(LSB) XOR DivisorSelect XOR Divisor(LSB) XOR Carry
    AddSubResult <= RemainderBits(0)  xor 
                    Subtract                xor 
                    DigitBits(DVR_LOW)      xor 
                    CarryFlag;
    -- Generate the carry out (choose to register it or not elsewhere)
    AddSubCarryOut  <= 
        ( CarryFlag and 
            ( RemainderBits(0) xor AddSubBin xor Subtract) ) or
        ( RemainderBits(0) and ( AddSubBin xor Subtract ) );
    ----------------------------------------------------------------------------
   
    ------------------------- Carry Out Register -------------------------------
    -- Carry flag needs to be stored for the next bit calculation
    process(CLK)
    begin
        if (rising_edge(CLK)) then
            -- Set it to the carry out when calculating
            if (ShiftOp = SHIFTOP_CALC) then
                CarryFlag <= AddSubCarryOut;
            -- Division always starts with subtraction. Since Carry = !Borrow,
            -- Carry must be preset before division. 
            -- So set it when not dividing 
            else 
                CarryFlag <= SL_TRUE;
            end if;
        end if;
    end process;
    ----------------------------------------------------------------------------
    
    
    ----------------------------------------------------------------------------
    --                               CLOCK                                    --
    ----------------------------------------------------------------------------
    
    
    ------------------------------ Mux Counter ---------------------------------
    -- Counter for mux rate of 1 KHz (1 MHz / 1024)
    process(CLK)
    begin
        -- Count on the rising edge (and synchronously clear on active low 
        -- reset)
        if rising_edge(CLK) then
            MuxCntr <= MuxCntr + 1;
        end if;
    end process;
    ----------------------------------------------------------------------------

    
    ----------------------------------------------------------------------------
    -- Output digit clock enable
    --      Enable clocking of the digits at a 1 lkHz rate (when mux counter 
    --      is at top 
    DigitClkEn  <=  SL_TRUE  when (MuxCntr = MUXCNTR_TOP)  else
                    SL_FALSE;
    ----------------------------------------------------------------------------

    
    --------------------------- Division Counters ------------------------------
    -- Dividend counter:
    --      This counter keeps track of the bit in the dividend currently in 
    --      the MSB of the dividend section of `DigitBits`. One complete 
    --      division cycles the MSB through the most significant bit of the 
    --      dividend to the least significant bit of the dividend.
    --
    --      Incremet once when divisor counter is at bottom of range.
    process (CLK)
    begin 
        if rising_edge(CLK) then 
            -- When dividing and divisor count is at botom of range, increment
            if (ShiftOp = SHIFTOP_CALC) and  
               (DivisorCount = DVR_CNTR_LOW) then 
                DividendCount <= DividendCount + 1;
            -- If done dividing (in the calculation digit and at the end), reset 
            elsif (CurDigit = CALC_DIGIT) and 
                  (MuxCntr = MUXCNTR_TOP) then
                DividendCount <= DVD_CNTR_LOW;
            -- Otherwise hold
            else 
                DividendCount <= DividendCount;
            end if;
        end if;
    end process;
    
    -- Divisor counter: 
    --      Always increment whenever dividing except when dividend counter is 
    --      at top of range (hold for a clock).
    process (CLK)
    begin 
        if rising_edge(CLK) then
            -- When dividing, either
            if ShiftOp = SHIFTOP_CALC then 
                -- If count is at top, then reset to bottom 
                if DivisorCount = DVR_CNTR_HIGH then 
                    DivisorCount <= DVD_CNTR_LOW;
                -- Otherwise increment
                else 
                    DivisorCount <= DivisorCount + 1;
                end if;
            -- If not dividing, then hold
            else 
                DivisorCount <= DivisorCount;
            end if;
        end if;
    end process;
    ----------------------------------------------------------------------------
    
    
    ----------------------------------------------------------------------------
    --                              OUTPUT                                    --
    ----------------------------------------------------------------------------
    
    
    ------------------------- Digit Output Muxing ------------------------------
    -- Create the counter for output the current digit
    -- Sequence:
    --
    --      3, 2, 1, 0,     7, 6, 5, 4,     11, 10, 9, 8           15
    --   |                 Display time                   |   Calculate time |
    --
    -- The display muxing counter cycles through the 4-bit sequence above. 
    -- We use the extra mux time, whose count does not correspond to a 
    -- physical display position, to do division
    --
    -- We could have 4 extra mux times (15...12), but we opt to use only 1 to 
    -- simplify the `DigitBits` update logic
    -- 
    -- Reset counter to 3, only increment if `DigitClkEn` is active
    process (CLK)
    begin
        if (rising_edge(CLK)) then
            -- Increment according to the appropriate count sequence
            -- if digit clocking is enabled. Infer latches when desired to hold
            if (DigitClkEn = SL_TRUE) then       
            
                -- If count is not 15, Digit0 is always [NOT] Digit0.
                -- If the count is 15, then set.
                if std_match(CurDigit, "11--") then 
                    CurDigit(0) <= SL_HIGH;
                else
                    CurDigit(0) <= not CurDigit(0);          
                end if; 
                
                -- Digit1 is Digit1 [XNOR] Digit0 always
                CurDigit(1) <= CurDigit(1) xor not CurDigit(0); 
                
                -- If the count is 15, reset Digit2
                if std_match(CurDigit, "11--") then 
                    CurDigit(2) <= SL_LOW;
                -- Otherwise Digit2 flips whenever the last two digits are 0
                elsif std_match(CurDigit, "--00") then
                    CurDigit(2) <= not CurDigit(2);
                end if;
    
                -- Digit 3 flips whenever Digit3 is 1 and the last two digits 
                -- match 
                if std_match(CurDigit, "-100") or 
                   std_match(CurDigit, "1111") then
                    CurDigit(3) <= not CurDigit(3);
                end if;
            -- If not, then hold the current value
            else
                CurDigit <= CurDigit;
            end if;
        end if;
    end process;
    ----------------------------------------------------------------------------

    ------------------------ DIGIT OUTPUT LOGIC --------------------------------
    -- The digit output decoder is only enabled when the display mux count 
    -- (`CurDigit`) is not 12-15 (when displaying digits)
    DecoderEn <=    SL_FALSE when std_match(CurDigit, "11--") else 
                    SL_TRUE; 
    DecoderBit <=   CurDigit;   -- Output the current digit to the digit decoder
    
    -- Decode the SSD output select (12 bits, one-hot active high)
    --      The `CurDigit`th bit is active - if in the calculate digit, don't 
    --      care since the decoder would be disabled.
    --
    --      Going down the pins on the schematic, the 12 decode lines go to 
    --      digits #
    --              7, 0, 6, 1, 8, 9, 10, 11, 3, 4, 2, 5
    --      So decode as follows
    --with to_integer(unsigned(CurDigit)) select
    --    SsdSel <=   "010000000000" when x"0",
    --                "000100000000" when x"1",
    --                "000000000010" when x"2",
    --                "000000001000" when x"3",
    --                "000000000100" when x"4",
    --                "000000000001" when x"5",
    --                "001000000000" when x"6",
    --                "100000000000" when x"7",
    --                "000010000000" when x"8",
    --                "000001000000" when x"9",
    --                "000000100000" when x"10",
    --                "000000010000" when x"11",
    --                "000000000000" when others,
                
    -- Decode the SSD output digit (seven lines, active low)
    --      The hex digit to output the low nibble of the digit shift register
    --      (Don't care if `CurDigit` is the dummy value)
    with DigitBits(NIBBLE_SIZE-1 downto 0) select
        SsdDigit <=     "0000001" when x"0",       -- "0" on SSD
                        "1001111" when x"1",       -- "1" on SSD
                        "0010010" when x"2",       -- "2" on SSD
                        "0000110" when x"3",       -- "3" on SSD
                        "1001100" when x"4",       -- "4" on SSD
                        "0100100" when x"5",       -- "5" on SSD
                        "0100000" when x"6",       -- "6" on SSD
                        "0001111" when x"7",       -- "7" on SSD
                        "0000000" when x"8",       -- "8" on SSD
                        "0000100" when x"9",       -- "9" on SSD
                        "0001000" when x"A",       -- "A" on SSD
                        "1100000" when x"B",       -- "b" on SSD
                        "0110001" when x"C",       -- "C" on SSD
                        "1000010" when x"D",       -- "d" on SSD
                        "0110000" when x"E",       -- "E" on SSD
                        "0111000" when x"F",       -- "F" on SSD
                        "1111110" when others;  -- "-" for error
    ----------------------------------------------------------------------------

    
    ----------------------------------------------------------------------------
    --                        STATE UPDATE LOGIC                              --
    ----------------------------------------------------------------------------
    
    
    ------------------ SHIFT REGISTER OPERATION SELECT -------------------------
    -- Shift register commands:
    --    Set bit 0 if shifting for display or doing a calculation
    --    Set bit 1 if shifting for display or inputting a key
    -- This is essentially a FSM
    ShiftOp <= 
    
        ----------------------- Display ----------------------------------------
        -- Shift for display if displaying is enabled
        SHIFTOP_SHIFT  when (DigitClkEn = SL_TRUE)  else
        --------------------- Read Key In --------------------------------------
        -- Read key input when 
        --      `MuxCntr` is at least 1 clock before the end of the digit count
        --      We have a key,
        --      and we are at the appropriate digit for input
        --          Entering dividend - low digit is #3
        --          Entering divisor - low digit is #7
        SHIFTOP_KEYIN  when 
            ( (HaveKey = SL_TRUE) and
              (std_match(MuxCntr, "1111111110") and
              ( ( (CurDigit = NIBBLE_THREE) and (Divisor = SL_FALSE) ) or
                ( (CurDigit = NIBBLE_SEVEN) and (Divisor = SL_TRUE)))) )  else
        -------------------- Calculation ---------------------------------------
        -- Calculate if calculation is enabled and we are on the dummy digit
        SHIFTOP_CALC   when DivCalcEn = SL_TRUE else
        ------------------------------------------------------------------------
        SHIFTOP_HOLD;
    ----------------------------------------------------------------------------


    --------------------------- DIGIT SHIFT REGISTER ---------------------------
    -- Shift register layout
    --
    --    Remainder register      Digit register
    --      | Remainder | Quotient | Divisor | Dividend | Dummy |
    --      | 16      0 | 51    36   35   20   19     4   3   0
    --
    -- The shift register
    --    bits 15-0    Dividend
    --    bits 31-16   Divisor
    --    bits 47-32   Quotient
    process (CLK)
    begin
        if rising_edge(CLK) then
            case ShiftOp is
                    
                --------------------- Dividing ---------------------------------
                -- When dividing, shift accordingly
                when SHIFTOP_CALC =>
                    ----------------- Quotient ---------------------------------
                    -- Quotient is shifted in whenever the divisor counter 
                    --      reaches top (when an add/sub completes)
                    -- The new quotient bit is Carry / !Borrow
                    if DivisorCount = DVR_CNTR_HIGH then 
                        DigitBits(QTT_HIGH downto QTT_LOW) <= 
                            DigitBits(QTT_HIGH-1 downto QTT_LOW) & 
                            AddSubCarryOut;
                    -- Otherwise hold the value 
                    else 
                        DigitBits(QTT_HIGH downto QTT_LOW) <= 
                            DigitBits(QTT_HIGH downto QTT_LOW);
                    end if;
                    ------------------------------------------------------------
                    
                    ----------------- Divisor ----------------------------------
                    -- Always rotate the divisor right, except when the divisor 
                    -- counter is at top (hold for a clock for carry 
                    -- propagation to complete).
                    if DivisorCount = DVR_CNTR_HIGH then 
                        DigitBits(DVR_HIGH downto DVR_LOW) <= 
                            DigitBits(DVR_HIGH downto DVR_LOW);
                    else 
                        DigitBits(DVR_HIGH downto DVR_LOW) <= 
                            DigitBits(DVR_LOW) & 
                            DigitBits(DVR_HIGH downto DVR_LOW+1);
                    end if;
                    ------------------------------------------------------------
                    
                    ----------------- Dividend ---------------------------------
                    -- Rotate the dividend left (to place sequentially less 
                    -- significant bits in the MSB position) whenever the 
                    -- divisor counter reaches 0 (done clocking in previous 
                    -- MSB to the remainder)
                    if DivisorCount = DVR_CNTR_LOW then 
                        DigitBits(DVD_HIGH downto DVD_LOW) <=
                            DigitBits(DVD_HIGH-1 downto DVD_LOW) &
                            DigitBits(DVD_HIGH);
                    -- Otherwise hold
                    else 
                        DigitBits(DVD_HIGH downto DVD_LOW) <=
                            DigitBits(DVD_HIGH downto DVD_LOW);
                     end if;
                    ------------------------------------------------------------
                    
                    ----------------- Dummy Digit ------------------------------
                    -- Set the dummy (lowest) nibble to 0
                    DigitBits(NIBBLE_SIZE-1 downto 0) <= (others => '0');
                    ------------------------------------------------------------
                ----------------------------------------------------------------
                    
                --------------------- Key Input --------------------------------
                -- When reading input, shift only the divisor and divident 
                -- portions of the register
                when SHIFTOP_KEYIN =>
                    -- Shift the key input into the low nibble of `DigitBits` 
                    -- and rotate the low word ("dividend")
                    DigitBits <= 
                        DigitBits(DIGIT_BITS-1 downto WORD_SIZE) &
                        DigitBits(WORD_SIZE-NIBBLE_SIZE-1 downto 0) & Keypad;
                ----------------------------------------------------------------
                
                ------------------ Displaying ----------------------------------
                -- When displaying, rotate right nibble-by-nibble
                -- Rotate hex digits into the LSD position to display them
                -- Move previous LSD to MSD position
                when SHIFTOP_SHIFT =>
                    DigitBits <= DigitBits(NIBBLE_SIZE-1 downto 0) & 
                                 DigitBits(DIGIT_BITS-1 downto NIBBLE_SIZE);
                ----------------------------------------------------------------
                
                -- Hold if otherwise
                when others =>
                    DigitBits <= DigitBits;
            end case;
        end if;
    end process;
    ----------------------------------------------------------------------------
    
    
    ------------------------ REMAINDER SHIFT REGISTER --------------------------
    process (CLK)
    begin
        if rising_edge(CLK) then
            case ShiftOp is
                -- When dividing,
                when SHIFTOP_CALC =>
                    -- If divisor counter is at top, then shift in the current 
                    -- MSB of the dividend into the low bit but do not rotate
                    if DivisorCount = DVR_CNTR_HIGH then 
                        RemainderBits <= 
                            RemainderBits(REM_BITS-1 downto 1) &
                            DigitBits(DVD_HIGH);
                    -- Otherwise, rotate the add/sub output into the remainder 
                    -- from the right 
                    else
                        RemainderBits <= 
                            AddSubResult &
                            RemainderBits(REM_BITS-1 downto 1);
                    end if;
                -- When not dividing, preload the MSB of the dividend in the 
                -- LSB of the remainder
                when others =>
                    RemainderBits(REM_BITS-1 downto 1) <= (others => '0');
                    RemainderBits(0) <= DigitBits(DVD_HIGH);
            end case;
        end if;
    end process;
    ----------------------------------------------------------------------------
end architecture;
