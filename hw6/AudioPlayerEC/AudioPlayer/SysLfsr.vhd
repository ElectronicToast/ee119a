--------------------------------------------------------------------------------
-- SysLfsr.vhd - VHDL implementation of a LFSR for playing non-oversampled 
-- audio with the PWM Audio Player for extra credit.
--
-- Description:
--      This VHDL file contains an entity `SysLfsr` with architecture 
--      `DataFlow` that implements a LSFR for generating non-oversampled 
--      messages. For this a four-bit count input is used to enable 
--      updating the LFSR.
--
--      Submission for EE 119a Homework 6.
--
-- Table of Contents:
--      entity          SysLfsr
--          inputs      Clock      SL   System clock 
--                      Reset      SL   Synchronous counter reset
--                      Count      SLV  4-bit up counter count
--          buffer      LfsrCount  SLV  The 8-bit LFSR count
--      architecture    DataFlow
--
-- Details:
--      Since we want non-oversampled output, we design the LFSR as follows.
--      
--                  LFSR7 ... LFSR0 | Count3 ... Count0 
--                      8 bits      |      4 bits
--                  non-oversampled 
--
--      Rather than using a 12-bit LFSR and taking the upper 8 bits (which would
--      result in oversampling), we use an 8-bit LFSR and a 4-bit counter.
--      If we update the LFSR value only when the count is at its top value, we 
--      will obtain a non-oversampled 8 kHz LFSR count for determining the PWM 
--      output. So we design our LFSR to take in the low four bits of the 
--      system counter (which is a free 4-bit counter clocked from the system 
--      clock) and output the LFSR count.
--
--      We use a maximal length LFSR with an illegal state of all zeroes. While
--      this only provides 255 states instead of 256, we will assume that 
--      this is good enough for our purposes. 
--
-- Revision History:
--      11/19/2018      Ray Sun         Initial revision. 
--      11/19/2018      Ray Sun         Fixed wrong reset state value and 
--                                      LFSR update logic.
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.AudioPlayerConfig.all;


--------------------------------------------------------------------------------


entity SysLfsr is 
    port(
        --------------------------- INPUTS -------------------------------------
        Clock:      in      std_logic;      -- System clock 
        Reset:      in      std_logic;      -- Synchronous reset signal 
        -- Input counter count
        Count:      in      std_logic_vector(LFSR_CNTR_IN_SIZE-1 downto 0);
        
        ----------------------- BIDIRECTIONAL ----------------------------------
        LfsrCount:  buffer  std_logic_vector(LFSR_SIZE-1 downto 0)  
    );
end entity;


--------------------------------------------------------------------------------


architecture DataFlow of SysLfsr is 
    -- Signal for the next LFSR output 
    signal    nextLfsrCount:      std_logic_vector(LFSR_SIZE-1 downto 0);

    -- LFSR feedback bits
    constant    FDBK1:      integer := 3;
    constant    FDBK2:      integer := 4;
    constant    FDBK3:      integer := 5;
    constant    FDBK4:      integer := 7;
    
begin
    -- Combinationally determine the next LFSR value 
    -- The 0th bit is the XOR of the feedback bits
    -- Reset sets LFSR output to all zeroes.
    nextLfsrCount(0) <= (LfsrCount(FDBK1) xor LfsrCount(FDBK2) xor
                         LfsrCount(FDBK3) xor LfsrCount(FDBK4));
    -- Shift it down the LFSR chain
    nextLfsrCountLoop: for i in 1 to LFSR_SIZE-1 generate
        nextLfsrCount(i) <= LfsrCount(i - 1);
    end generate;
        
    -- LFSR update / output registering process
    process (Clock)
    begin
        -- Synchronously update the LFSR whenever the input counter is at the 
        -- top value.
        if rising_edge(Clock) then
            -- If reset is active, then reset
            if Reset = SL_TRUE then 
                LfsrCount <= LFSR_RESET_VAL;
            elsif Count = LFSR_CNTR_IN_TOP then
                LfsrCount <= nextLfsrCount;
            end if;
        end if;
        -- Otherwise implicitly latch the count
    end process;
end architecture;
