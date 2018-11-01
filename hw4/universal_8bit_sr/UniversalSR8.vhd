--------------------------------------------------------------------------------
-- UniversalSR8.vhd - VHDL implementation of an 8-bit bidirectional universal 
-- shift register using an implementation of the 74xx194 4-bit bidirectional
-- universal shift register as a component.
--
-- Description:
--      This VHDL file contains a top-level entity `UniversalSR8` that 
--      instantiates two instances of the component `ic74194`, an implementation
--      of the 74xx194 4-bit bidirectional shift register, to create an 8-bit 
--      bidirectional shift register.
--
--      Submission for EE 119a Homework 4.
--
-- Table of Contents:
--      entity              UniversalSR8
--          architecture        Structural
--
-- Revision History:
--      10/30/2018      Ray Sun         Initial revision.
--      10/31/2018      Ray Sun         Renamed port signals to match what is 
--                                      in the testbenches.
--      10/31/2018      Ray Sun         Split the entities into two different
--                                      .vhd files.
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;


--------------------------------------------------------------------------------
--                            ENTITY UniversalSR8                             --
--------------------------------------------------------------------------------


entity UniversalSR8 is
    generic(
        BITS :      integer := 8;
        BITS_HALF : integer := 4 );
    port(
        D    : in      std_logic_vector(BITS-1 downto 0);   -- Parallel input
        LSer : in      std_logic;                           -- Serial left in
        RSer : in      std_logic;                           -- Serial right in
        Mode : in      std_logic_vector(1 downto 0);        -- Mode select bits
        CLR  : in      std_logic;                           -- Asynch. clear
        CLK  : in      std_logic;                     
        Q    : buffer  std_logic_vector(BITS-1 downto 0) ); -- Outputs
end entity;


--------------------------------------------------------------------------------
--               ARCHITECTURE Structural -- ENTITY UniversalSR8               --
--------------------------------------------------------------------------------


architecture Structural of UniversalSR8 is

    -- Component declaration for the two 74xx194 4-bit SRs
    component ic74194 port(
        CLR:    in      std_logic;
        S:      in      std_logic_vector (1 downto 0);      -- (S1, S0)
        CLK:    in      std_logic;
        LSI:    in      std_logic;
        RSI:    in      std_logic;
        DO:     buffer  std_logic_vector (0 to 3);   -- Map (A, B, C, D) as 
        DI:     in      std_logic_vector (0 to 3) ); -- (0 to 3) for DI and DO
    end component;
        
begin
    -- Graphical portmap:
    --
    --    RSer -->  | Q7  | Q6  | Q5  | Q4  || Q3  | Q2  | Q1  | Q0  |  <-- LSer
    --              | DO0 | DO1 | DO2 | DO3 || DO0 | DO1 | DO2 | DO3 |
    --              | DI0 | DI1 | DI2 | DI3 || DI0 | DI1 | DI2 | DI3 |   
    --              |       Left 74194      ||      Right 74194      |
    --
    -- Component instantiation for 74194 on the left
    --      Serial left input is the top-level serial left input 
    --      Serial right input is the leftmost `Q` from the right 74194
    ic74194_L : ic74194 
        port map (
            CLR, Mode, CLK, Q(BITS_HALF-1), RSer, 
            Q(BITS-1 downto BITS_HALF), D(BITS-1 downto BITS_HALF));
            
    -- Component instantiation for 74194 on the right
    --      Serial right input is the top-level serial right input 
    --      Serial left input is the rightmost `Q` from the left 74194
    ic74194_R : ic74194 
        port map (
            CLR, Mode, CLK, LSer, Q(BITS_HALF), 
            Q(BITS_HALF-1 downto 0), D(BITS_HALF-1 downto 0));
            
end architecture;