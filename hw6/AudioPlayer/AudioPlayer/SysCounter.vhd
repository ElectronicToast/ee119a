--------------------------------------------------------------------------------
-- SysCounter.vhd - VHDL implementation of a bit counter for the PWM
-- Audio Player
--
-- Description:
--      This VHDL file contains an entity `SysCounter` with architecture 
--      `DataFlow` that implements a 12-bit counter for generating an 
--      oversampled PWM output.
--
--      Submission for EE 119a Homework 6.
--
-- Table of Contents:
--      entity          SysCounter
--          inputs      Clock      SL   System clock 
--                      Reset      SL   Synchronous counter reset
--          buffer      Count      SLV  The counter count
--      architecture    DataFlow
--
-- Details:
--      This is a VHDL code for a 12-bit synchronous counter with synchronous 
--      reset. The count output is used to generate 8kHz PWM and to read from 
--      the EPROM on the Audio Player.
--
-- Revision History:
--      11/18/2018      Ray Sun         Initial revision. Split from old 
--                                      top-level entity.
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.AudioPlayerConfig.all;


--------------------------------------------------------------------------------


entity SysCounter is 
    port(
        --------------------------- INPUTS -------------------------------------
        Clock:      in      std_logic;      -- System clock 
        Reset:      in      std_logic;      -- Synchronous reset signal 
        
        ------------------------ BIDIRECTONAL ----------------------------------
        Count:      buffer  std_logic_vector(CNTR_SIZE-1 downto 0)  
    );
end entity;


--------------------------------------------------------------------------------


architecture DataFlow of SysCounter is 
begin 
    -- Counter process
    process (Clock)
    begin
        -- If the reset is active, reset the count
        if Reset = SL_TRUE then 
            Count <= CNTR_BOTTOM;
        elsif rising_edge(Clock) then
            -- Increment (and overflow back to 0 if at top value)
            Count <= std_logic_vector(unsigned(Count) + 1);
        end if;
        -- Otherwise implicitly latch the count
    end process;
end architecture;
