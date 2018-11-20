--------------------------------------------------------------------------------
-- PwmComparator.vhd - VHDL implementation of a PWM generator that creates a 
-- PWM signal by comparing an input count to an input threshold, the desired 
-- high time of the PWM signal.
--
-- Description:
--      This VHDL file contains an entity `PwmComparator` with architecture 
--      `DataFlow` that implements a 8-bit comparator for outputting a PWM 
--      signal.
--
--      Submission for EE 119a Homework 6.
--
-- Table of Contents:
--      entity          PwmComparator
--          inputs      Clock      SL   System clock 
--                      Count      SLV  Input count 
--                      Threshold  SLV  Input threshold 
--          outputs     PWMOut     SL   Registered output PWM signal
--      architecture    DataFlow
--
-- Details:
--      This is a VHDL code that implements a synchronous PWM output generator
--      by comparing an input count to an input threshold (the desired PWM high 
--      time). This is used to generate an approximately 8 kHz PWM signal.
--      The output of the comparator is registered.
--
-- Revision History:
--      11/18/2018      Ray Sun         Initial revision. Split from old 
--                                      top-level entity.
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use work.AudioPlayerConfig.all;


--------------------------------------------------------------------------------


entity PwmComparator is 
    generic (
        N_DATA_BITS:    integer := 8        -- Data bus size
    );
    port (
        --------------------------- INPUTS -------------------------------------
        Clock:      in  std_logic;       -- System clock 
        Count:      in  std_logic_vector(N_DATA_BITS-1 downto 0); -- Input count
        Threshold:  in  std_logic_vector(N_DATA_BITS-1 downto 0); -- Input thresh
        
        -------------------------- OUTPUTS -------------------------------------
        PWMOut:     out std_logic       -- Output PWM signal
    );
end entity;


--------------------------------------------------------------------------------


architecture DataFlow of PwmComparator is
    --########################################################################--
    constant PWM_HIGH:  std_logic := '1';   -- PWN output value definitions
    constant PWM_LOW:   std_logic := '0';  
    --########################################################################--
begin
    -- Compare on every clock rising edge
    process (Clock)
    begin
        -- Register the PWM signal with a DFF to avoid glitching output
        if rising_edge(Clock) then
            -- If the count is less than the threshold, the PWM is high
            if Count < Threshold then
                PWMOut <= PWM_HIGH;
            -- Otherwise, the PWM is low
            else
                PWMOut <= PWM_LOW;
            end if;
      end if;
    end process;
end architecture;
