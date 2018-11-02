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
--      11/01/2018      Ray Sun         Modified the high nibble conversion to 
--                                      use bit-shifting instead of a truth
--                                      table. Verified functionality with 
--                                      testbench.
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


--------------------------------------------------------------------------------
--                             ENTITY BCD2Binary8                             --
--------------------------------------------------------------------------------


entity BCD2Binary8 is 

    generic (
        -- Constant for the number of bits in the converter
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
    constant    BITS_NIB:   integer := 4;
    
    -- Signals for the binary representations of the upper and lower nibbles
    -- in unsigned type
    signal      Bin_nib_h:  unsigned (BITS-1 downto 0);
    signal      Bin_nib_l:  unsigned (BITS_NIB-1 downto 0);
    
    -- The high nibble of the input, extended to BITS-bits
    signal      Bcd_nib_h:  unsigned (BITS-1 downto 0);
    
begin

    -- The lower nibble is already in binary (ranges from 0 to 9 in binary)
    Bin_nib_l <= unsigned(BCD(BITS_NIB-1 downto 0));
    
    -- The upper nibble (0 to 9) represents 10 times the value of the nibble 
    -- in decimal
    --      Use bit-shifts (10x = 8x + 2x)
    -- Intermediate signal: "0000" & high nibble 
    Bcd_nib_h <= resize(unsigned(BCD(BITS-1 downto BITS_NIB)), BITS);
    Bin_nib_h <= (Bcd_nib_h sll 3) + (Bcd_nib_h sll 1);
    
    -- The binary output is the sum of the converted binary nibbles
    B <= std_logic_vector(Bin_nib_h + Bin_nib_l);
	 
end architecture; 