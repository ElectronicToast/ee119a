--------------------------------------------------------------------------------
-- AudioPlayerConfig.vhd - VHDL package containing constants for the PWM audio
-- player. For Magic Number Avoidance [TM]
--
-- Description:
--      This VHDL file contains a package `AudioPlayerConfig` that defines 
--      constants for the PWM audio player, such as the number of switches 
--      and the width of the data and address busses.
--
--      Submission for EE 119a Homework 6.
--
-- Table of Contents:
--      package         AudioPlayerConfig
--
-- Revision History:
--      11/18/2018      Ray Sun         Initial revision. Created from 
--                                      old top-level entity.
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;


--------------------------------------------------------------------------------


package AudioPlayerConfig is
 
    --########################### CONSTANTS ####################################
    
    -- System constants
    constant    N_DATA_BITS: integer := 8;      -- Number of audio data lines
    constant    N_ADDR_BITS: integer := 19;     -- Number of audio address lines
    
    constant    BYTE_SIZE:  integer := 8;
    
    constant    CNTR_SIZE:  integer := 12;      -- Number of bits in counter
    constant    CNTR_TOP:                        
        std_logic_vector (CNTR_SIZE-1 downto 0) := x"FFF";  -- Top of range
    constant    CNTR_BOTTOM:
        std_logic_vector (CNTR_SIZE-1 downto 0) := x"000";  -- Bottom of range
    constant    CNTR_CMP_BOTTOM:    integer := 0;   -- Top & bottom of compare
    constant    CNTR_CMP_TOP:       integer := 7;   -- range - range of bits 
                                                    -- in count to compare to 
                                                    -- PWM data 
                                                
    -- General Boolean constants
    constant    SL_TRUE:    std_logic := '1';   -- true and false for a 
    constant    SL_FALSE:   std_logic := '0';   -- std_logic used as a Boolean
    constant    MSG_EN:     std_logic := '1';   -- Message playing enabled       
    constant    MSG_DIS:    std_logic := '0';   -- Message playing disabled
    constant    MSG_DONE:   std_logic := '1';   -- Message done playing
    constant    MSG_NOTDONE:std_logic := '0';   -- Message not done playing                                
    constant    SW_PRESSED: std_logic := '1';   -- Switch input when pressed
    constant    SW_NOTPRSD: std_logic := '0';   -- Switch in when not pressed
    
    -- Starting and ending addresses for each message in the EPROM 
    --      Since hex literals have sizes in multiples of 4 bits, concatenate
    --      in order to get `N_ADDR_BITS` size constants.
    constant EPROM_ADDR_IDLE: 
        std_logic_vector (N_ADDR_BITS-1 downto 0) := "0000000000000000000"; -- Dummy
    constant EPROM_M1_START:     
        std_logic_vector (N_ADDR_BITS-1 downto 0) := "1000000" & x"000";    -- h40000
    constant EPROM_M2_START:
        std_logic_vector (N_ADDR_BITS-1 downto 0) := "1001000" & x"000";    -- h48000
    constant EPROM_M3_START:
        std_logic_vector (N_ADDR_BITS-1 downto 0) := "1011000" & x"000";    -- h58000
    constant EPROM_M4_START:                     
        std_logic_vector (N_ADDR_BITS-1 downto 0) := "1111100" & x"000";    -- h7C000
                                                    
    constant EPROM_M1_END:
        std_logic_vector (N_ADDR_BITS-1 downto 0) := "1001000" & x"000";    -- h48000
    constant EPROM_M2_END:
        std_logic_vector (N_ADDR_BITS-1 downto 0) := "1011000" & x"000";    -- h58000
    constant EPROM_M3_END:
        std_logic_vector (N_ADDR_BITS-1 downto 0) := "1111100" & x"000";    -- h7C000
    constant EPROM_M4_END:
        std_logic_vector (N_ADDR_BITS-1 downto 0) := "0000000" & x"000";    -- h00000 (ovf))
    
    -- PWM output value definitions
    constant PWM_HIGH:  std_logic := '1';
    constant PWM_LOW:   std_logic := '0';     
end package;


package body AudioPlayerConfig is
end package body;
