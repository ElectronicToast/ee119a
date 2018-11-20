--------------------------------------------------------------------------------
-- AddrSelect.vhd - VHDL implementation of a synchronous EEPROM read address
-- generating circuit with registered output for the PWM Audio Player.
--
-- Description:
--      This VHDL file contains an entity `AddrSelect` with architecture 
--      `DataFlow` that implements an EPROM address selector and EPROM PWM 
--      data register for the PWM Audio Player. Pipelining is used to allow 
--      sufficient time for the EPROM data to be read into the module. The 
--      module also generates a `MsgDone` signal that is active when the 
--      message is finished playing (when at the final address) and outputs 
--      the correct address to read from the EPROM depending on the current 
--      state of the FSM (whether playing is enabled).
--
--      Submission for EE 119a Homework 6.
--
-- Table of Contents:
--      entity          PwmComparator
--          inputs      Clock      SL   System clock.
--                      MsgStartAddr  SLV  EPROM address from which to start 
--                                      reading the PWM data for the current
--                                      message.
--                      MsgEndAddr SLV  EPROM address corresponding to the 
--                                      end of the current message.
--                      MsgEnable  SL   `MSG_EN` is a message is playing and 
--                                      `MSG_DIS` otherwise.
--                      Count      SL   Input of system counter. Used to 
--                                      increment the current address once the 
--                                      count hits the top value. 
--          buffer      CurrAddr   SLV  Address bus output to EPROM.
--          outputs     PWMData    SLV  Output to PWM comparator; sets PWM 
--                                      high time. Is registered data from EPROM 
--                                      updated once `Count` reaches its top 
--                                      value. 
--                      MsgDone    SL  `MS_DONE` when the current message end 
--                                      address is reached, and `MS_NOTDONE`
--                                      otherwise.
--      architecture    DataFlow
--
-- Details:
--      This VHDL module 
--      - Produces the correct address to output to the EPROM
--          - If playing sound is not enabled (`MsgEnable` is inactive), 
--            the current starting address is synchronously loaded. This is 
--            so that when playing is enabled, the correct start is loaded.
--          - If playing sound is enabled and the counter is at the 
--            top value, increments the address.
--          - If playing and not at the top value, holds the address.
--      - Produces a `MsgDone` signal that indicates when playing the 
--        current message is finished (when the reading address is the end).
--      - Registers the PWM data from the EPROM to implement pipelining.
--
-- Revision History:
--      11/18/2018      Ray Sun         Initial revision. Split from old 
--                                      top-level entity.
--      11/18/2018      Ray Sun         Added TOC and docuentation.
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use work.AudioPlayerConfig.all;


--------------------------------------------------------------------------------


entity AddrSelect is 
    generic (
        ----------------------- SHARED CONSTANTS -------------------------------
        -- From `AudioPlayerConfig` package
        N_DATA_BITS:    integer := 8;      -- Number of data lines
        N_ADDR_BITS:    integer := 19;     -- Number of address lines
        CNTR_SIZE:      integer := 12      -- Number of bits in counter
        ------------------------------------------------------------------------
    );
    port (
        --------------------------- INPUTS -------------------------------------
        Clock:      in  std_logic;       -- System clock 
        MsgStartAddr:  in  std_logic_vector(N_ADDR_BITS-1 downto 0); -- Msg start
        MsgEndAddr:    in  std_logic_vector(N_ADDR_BITS-1 downto 0); -- Msg end
        MsgEnable:  in  std_logic;       -- Message enable
        Count:      in  std_logic_vector(CNTR_SIZE-1 downto 0);   -- Input count
        EPROMData:  in  std_logic_vector(N_DATA_BITS-1 downto 0); -- EEROM data
        
        ------------------------ BIDIRECTIONAL ---------------------------------
        -- Curent reading address
        CurrAddr:   buffer  std_logic_vector(N_ADDR_BITS-1 downto 0);
        
        -------------------------- OUTPUTS -------------------------------------
        PWMData:   out std_logic_vector(N_DATA_BITS-1 downto 0);  -- Output PWM data
        MsgDone:   out std_logic
    );
end entity;


--------------------------------------------------------------------------------


architecture DataFlow of AddrSelect is 
    --####################### SHARED CONSTANTS ###############################--
    -- From `AudioPlayerConfig` library
    constant    SL_TRUE:    std_logic := '1';   -- true and false for a 
    constant    SL_FALSE:   std_logic := '0';   -- std_logic used as a Boolean
    constant    MSG_DONE:   std_logic := '1';   -- Message done playing
    constant    MSG_NOTDONE:std_logic := '0';   -- Message not done playing   
    constant    DATA_ZERO: 
        std_logic_vector(N_DATA_BITS-1 downto 0) := "00000000";  
    constant    CNTR_TOP:                        
        std_logic_vector (CNTR_SIZE-1 downto 0) := x"FFF";  -- Top of range
    --########################################################################--
    
    constant    N_ADDR_MUX_SEL: integer := 2;   -- Number of select lines in MUX
    
    -- Internal signal for the incremented value of the current address
    signal  nextAddr:   std_logic_vector(N_ADDR_BITS-1 downto 0);
    
    -- Input to the DFF (output of the MUX) that updates the current EPROM 
    -- address with either the start address, `nextAddr`, or no change (latched)
    signal  newAddr:    std_logic_vector(N_ADDR_BITS-1 downto 0);
    
    -- EPROM address MUX select lines
    signal  addrMuxSel: std_logic_vector(N_ADDR_MUX_SEL-1 downto 0);
    
begin
    -- The next address is one plus the current address
    nextAddr <= std_logic_vector(unsigned(CurrAddr) + 1);
    
    -- MUX select bit 0 - if count is at top value 
    process(Count)
    begin
        if Count = CNTR_TOP then
            addrMuxSel(0) <= SL_TRUE;
        else
            addrMuxSel(0) <= SL_FALSE;
        end if;
    end process;
    
    -- MUX select bit 1 - active if we are playing
    addrMuxSel(1) <= MsgEnable;
    
    -- Generate the new address to load
    with addrMuxSel select newAddr 
         <= MsgStartAddr    when "00",      -- Mot enabled - load
            MsgStartAddr    when "01",      -- Also not enabled
            CurrAddr        when "10",      -- Not at top of counter - hold
            nextAddr        when others;    -- At top of counter, so increment
    
    -- and register it on rising edges of the system clock
    process (Clock)
    begin
        if rising_edge(Clock) then
           -- Register the new output EPROM reading addres
           CurrAddr <= newAddr;
           -- If at the top of the counter, register the EPROM data as the 
           -- output PWM data for the next roll of the counter.
           if addrMuxSel(1) = SL_FALSE then 
               PWMData <= DATA_ZERO;
           elsif addrMuxSel(0) = SL_TRUE then
               PWMData <= EPROMData;
           end if;
        end if;
    end process;
    
    -- Concurrently generate the done playing signal
    process(CurrAddr, MsgEndAddr)
    begin
        -- If we are reading from the final address in the message, then we 
        -- are done playing.
        if(CurrAddr = MsgEndAddr) then
            MsgDone <= MSG_DONE;
        -- Otherwise, not done playing.
        else
            MsgDone <= MSG_NOTDONE;
        end if;
    end process;
end architecture;