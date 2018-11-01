--------------------------------------------------------------------------------
-- BCD2Binary8.vhd - VHDL implementation of an 8-bit BCD to binary converter.
--
-- Description:
--      This VHDL file contains an entity `BCD2Binary8` which specifies the 
--      input for a 8-bit BCD - to - binary converter. In addition, this file 
--      contains an architecture `DataFlow`that implements the entity for 8-bit 
--      BCD to 8-bit binary conversion.
--
--      Submission for EE 119a Homework 4.
--
-- Table of Contents:
--      entity              BCD2Binary8
--          architecture        DataFlow
--
-- Revision History:
--      10/29/2018      Ray Sun         Initial revision.
--      10/30/2018      Ray Sun         Changed entity and architecture names
--                                      to match those in the test bench
--      10/31/2018      Ray Sun         Verified entity functionality with 
--                                      the provided `BCD2Binary8_tb` testbench
--                                      with ModelSim-Altera.
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


--------------------------------------------------------------------------------
--                             ENTITY BCD2Binary8                             --
--------------------------------------------------------------------------------


entity BCD2Binary8 is 

    generic (
        -- Non-synthesized constant for the number of bits in the converter
        BITS:       integer := 8 );
    port (
        -- BCD input and binary output are SLVs of length `BITS`
        BCD:    in  std_logic_vector (BITS-1 downto 0);
        B:      out std_logic_vector (BITS-1 downto 0) );
        
end entity;


--------------------------------------------------------------------------------
--                           ARCHITECTURE DataFlow                            --
--------------------------------------------------------------------------------


architecture DataFlow of BCD2Binary8 is

    -- Number of bits in a nibble (one BCD digit)
    constant    BITS_NIBBLE: positive := 4;
    
    -- Signals for the binary representations of the upper and lower nibbles
    signal      Bin_nib_h:  std_logic_vector (BITS-1 downto 0);
    signal      Bin_nib_l:  std_logic_vector (BITS_NIBBLE-1 downto 0);
    
begin

    -- The lower nibble is already in binary (ranges from 0 to 9 in binary)
    Bin_nib_l <= BCD(BITS_NIBBLE-1 downto 0);
    
    -- The upper nibble (0 to 9) represents 10 times the value of the nibble 
    -- in decimal
    --      Use a with-select to assign a truth table of values
    with BCD(BITS-1 downto BITS_NIBBLE) select
        Bin_nib_h <=    "00000000" when "0000",     -- [0000]bcd -> [0]dec
                        "00001010" when "0001",     -- [0001]bcd -> [10]dec
                        "00010100" when "0010",     -- [0010]bcd -> [20]dec
                        "00011110" when "0011",     -- [0011]bcd -> [30]dec
                        "00101000" when "0100",     -- [0100]bcd -> [40]dec
                        "00110010" when "0101",     -- [0101]bcd -> [50]dec
                        "00111100" when "0110",     -- [0110]bcd -> [60]dec
                        "01000110" when "0111",     -- [0111]bcd -> [70]dec
                        "01010000" when "1000",     -- [1000]bcd -> [80]dec
                        "01011010" when "1001",     -- [1001]bcd -> [90]dec
                        "XXXXXXXX" when others;     -- error case
    
    -- The binary output is the sum of the converted binary nibbles
    B <= std_logic_vector(unsigned(Bin_nib_h) + unsigned(Bin_nib_l));
	 
end architecture; 