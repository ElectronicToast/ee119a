--------------------------------------------------------------------------------
-- BCD2BinaryN.vhd - VHDL implementation of an N-bit BCD to binary converter.
--
-- Description:
--      This VHDL file contains an entity `BCD2Binary8` which specifies the 
--      input for a N-bit BCD - to - binary converter. In addition, this file 
--      contains an architecture `DataFlow`that implements the entity for N-bit 
--      BCD to N-bit binary conversion. The number of bits is specified by 
--      a generic constant `N_BITS` in the entity declaration.
--
--      Submission for EE 119a Homework 4, extra credit.
--
-- Table of Contents:
--      entity              BCD2BinaryN
--          architecture        DataFlow
--
-- Revision History:
--      11/01/2018      Ray Sun         Initial revision.
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


--------------------------------------------------------------------------------
--                             ENTITY BCD2BinaryN                             --
--------------------------------------------------------------------------------


entity BCD2BinaryN is 

    generic (
        -- Constant for the number of bits in the converter
        -- ##### SET TO SYNTHESIZE `N_BITS`-bit BCD-BINARY CONVERTER #####
        N_BITS:     integer := 16 );
    port (
        -- BCD input and binary output are SLVs of length `N_BITS`
        BCD:    in  std_logic_vector (N_BITS-1 downto 0);
        B:      out std_logic_vector (N_BITS-1 downto 0) );
        
end entity;


--------------------------------------------------------------------------------
--                           ARCHITECTURE DataFlow                            --
--------------------------------------------------------------------------------


architecture DataFlow of BCD2BinaryN is
    -- Number of bits in a nibble (one BCD digit)
    constant    BITS_NIB:       integer := 4;
	 -- Number of nibbles
    constant 	 N_NIBS:         integer := N_BITS / 4;
	
    -- Custom type for an array of unsigned, and a "3D SLV"
    --      Used for converting each of the BCD digits (binary nibbles)
    type        uns_arr  is array (natural range <>) 
                         of unsigned(N_BITS-1 downto 0);
    type        uns_arr2 is array (natural range <>) 
                         of uns_arr(N_NIBS-1 downto 0);
	 
    -- Running array of [nibble_i] * 10^i
    --      dimensions: (nibbles)(powers of 0, 1, 2, ... i)
    signal      Bin_nibs:       uns_arr2 (N_NIBS-1 downto 1);
	 
	 -- Running sum of binary values from each nibble
    signal      Bin_nibs_sum:   uns_arr (N_NIBS-1 downto 0);

begin

    -- The 0th nibble is already in binary (ranges from 0 to 9 in binary)
    --      Assign to the first element in the running sum
    Bin_nibs_sum(0) <= resize( 
        unsigned( BCD(BITS_NIB-1 downto 0) ), N_BITS );
    
    -- Get each nibble in `unsigned` type and multiply by the appropriate power
	 -- of 10, and convert each (N_NIBS-1 to 1) nibble to binary:
    
    -- The ith nibble (from N_NIBS-1 to 1) represent 10i times the value of the 
    -- nibble bits in decimal.
    --      Loop from the 1st to the most significant nibble
    ConvBin: for i in 1 to N_NIBS-1 generate 
		  -- Put the ith nibble in `Bin_nibs(i)(0)` (equal to [nibble]_binary
          -- times 1) and extend to full range 
		  --     ith nibble is BCD (NIB_SIZE*(i+1) -1 to NIB_SIZE * i)
        Bin_nibs(i)(0) <= resize( 
		      unsigned( BCD( BITS_NIB*(i+1)-1 downto BITS_NIB*i ) ),
										    N_BITS );

        -- Loop from 1 to i to compute nibble_1 * 10^i		  
        ConvBinInner: for j in 1 to i generate
            -- If first iteration,  Bin_nibs(i)(1) = 10 * Bin_nibs(i)(0)
            -- Otherwise,           Bin_nibs(i)(j) = 10 * Bin_nibs(i)(j-1)
            -- The last element Bin_nibs(i)(i) is equal to nibble_1 * 10^i	
            with j-1 select
                Bin_nibs(i)(j) <= (Bin_nibs(i)(0) sll 3) + 
                                  (Bin_nibs(i)(0) sll 1) when 0,
				                  (Bin_nibs(i)(j-1) sll 3) + 
                                  (Bin_nibs(i)(j-1) sll 1) when others;
        end generate;
		  
        -- Keep a running sum of nibble_1 * 10^i - add to previous sum
        Bin_nibs_sum(i) <= Bin_nibs_sum(i-1) + Bin_nibs(i)(i);
    end generate;
    
	 -- Binary output is the final running sum element
	 B <= std_logic_vector(Bin_nibs_sum(N_NIBS-1));
end architecture; 