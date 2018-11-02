--------------------------------------------------------------------------------
-- ic74194.vhd - VHDL implementation of an 8-bit bidirectional universal 
-- shift register using an implementation of the 74xx194 4-bit bidirectional
-- universal shift register as a component.
--
-- Description:
--      This VHDL file contains an entity `ic74194` that implements a 74xx194 
--      4-bit bidirectional shift register. `ic74194`. This entity is used as 
--      a component in the `UniversalSR8` entity, which implements an 8-bit 
--      bidirectional shift register.
--
--      Submission for EE 119a Homework 4.
--
-- Table of Contents:
--      entity              ic74194
--          architecture        DataFlow
--
-- Revision History:
--      10/31/2018      Ray Sun         Initial revision.
--      10/31/2018      Ray Sun         Verified entity functionality with 
--                                      the provided `ic74194_tb` testbench
--                                      with ModelSim-Altera.
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;


--------------------------------------------------------------------------------
--                               ENTITY ic74194                               --
--------------------------------------------------------------------------------


entity ic74194 is
    generic(
        BITS: 	        integer := 4;                   -- # bits in the SR
        SEL_BITS:       integer := 2 );                 -- # select lines
    port(
        CLR:    in      std_logic;                      -- Asynch. clear
        S:      in      std_logic_vector (SEL_BITS-1 downto 0);     -- (S1, S0)
        CLK:    in      std_logic;                      -- Clock
        LSI:    in      std_logic;                      -- Serial in, left
        RSI:    in      std_logic;                      -- and right
        -- Map (A, B, C, D) as (0 to 3) for the parallel inputs `DI`
        -- and the outputs `DO`
        DO:     buffer  std_logic_vector (0 to BITS-1); -- Parallel inputs
        DI:     in      std_logic_vector (0 to BITS-1) );   -- Outputs
end entity;


--------------------------------------------------------------------------------
--                   ARCHITECTURE DataFlow -- ENTITY ic74194                  --
--------------------------------------------------------------------------------


architecture DataFlow of ic74194 is
begin
    process (CLK, CLR)
    begin 
        -- If `CLR` is low, clear the shift register outputs
        if CLR = '0' then
            DO <= "0000";
        elsif rising_edge(CLK) then 
            -- If (S1, S0) = (H, H), outputs are parallel inputs
            if S = "11" then 
                DO <= DI;
            -- If (S1, S0) = (L, H), shift right and shift in `RSI` from left
            elsif S = "01" then 
                DO <= RSI & DO(0 to BITS-2);
            -- If (S1, S0) = (H, L), shift left and shift in `LSI` from right
            elsif S = "10" then 
                DO <= DO(1 to BITS-1) & LSI;
            end if;
        end if;
    end process;
end architecture;