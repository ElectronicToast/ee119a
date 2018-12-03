--------------------------------------------------------------------------------
--                              div16_tb.vhd                                  --
--                     16-bit Serial Divider Testbench                        --
--------------------------------------------------------------------------------
--
-- Description:
--      This is a testbench for a 16-bit serial divider design with entity 
--      `Div16` and architecture `DataFlow`.
--
-- Table of Contents:
--      entity          SerialDivider16_tb
--      architecture    TB_ARCHITECTURE
--
-- Notes:
--      - This testbench was ran with ModelSim-Altera.
--
-- Revision History:
--      11/29/2018      Ray Sun     Initial revision.
--      11/29/2018      Ray Sun     Replaced the clock period (actual system 
--                                  clock period) with a smaller value so that 
--                                  the ModelSim simulation runs faster
--      12/01/2018      Ray Sun     Added some division tests.
--------------------------------------------------------------------------------


library ieee;                   -- Import the requisite packages
use ieee.std_logic_1164.all;    -- For 9-valued logic types
use ieee.numeric_std.all;       -- For numeric types


--------------------------------------------------------------------------------


entity SerialDivider16_tb is 
end entity;


--------------------------------------------------------------------------------


architecture TB_ARCHITECTURE of SerialDivider16_tb is
    -- Fast clock period to make simulation faster
    constant CLOCK_PERIOD:      time := 1 ns;
    constant CLOCK_HALFPER:     time := CLOCK_PERIOD / 2;

    signal END_SIM  :      boolean := FALSE;       -- End-of-sim flag
    
    ------------------------- STIMULUS SIGNALS ---------------------------------
    signal Clock        :  std_logic;
    signal nCalculate   :  std_logic;
    signal Divisor      :  std_logic;
    signal KeypadRdy    :  std_logic;
    signal KeypadVal    :  std_logic_vector(3 downto 0);
    ----------------------------------------------------------------------------
    
    ------------------------- OBSERVED SIGNALS ---------------------------------
    signal SsdVal       : std_logic_vector(3 downto 0);
    signal SsdDigit     : std_logic_vector(3 downto 0);
    signal DecoderEn    : std_logic;
    ----------------------------------------------------------------------------
    
    ----------------------------TEST SIGNALS -----------------------------------
    ----------------------------------------------------------------------------

    --------------------- UNIT UNDER TEST COMPONENT ----------------------------
    component Div16 is
    port (
        nCalculate  :  in   std_logic;
        Divisor     :  in   std_logic;
        KeypadRdy   :  in   std_logic;
        Keypad      :  in   std_logic_vector(3 downto 0);
        HexDigit    :  out  std_logic_vector(3 downto 0);
        DecoderEn   :  out  std_logic;
        DecoderBit  :  out  std_logic_vector(3 downto 0);
        CLK         :  in   std_logic
    );
    end component;
    ----------------------------------------------------------------------------
    
begin
    
    --------------------- UNIT UNDER TEST PORT MAP -----------------------------
    UUT : Div16
        port map  (
            CLK        => Clock,
            nCalculate => nCalculate,
            Divisor    => Divisor,
            KeypadRdy  => KeypadRdy,
            Keypad     => KeypadVal,
            HexDigit   => SsdVal,
            DecoderBit => SsdDigit,
            DecoderEn  => DecoderEn
        );
    ----------------------------------------------------------------------------
    
    STIMULUS : process 
    begin 
        nCalculate <= '1';
        Divisor <= '0';
        
        wait for 100 us;
        -- When done, set end of sim flag
        END_SIM <= TRUE;
        wait;
    end process;
    ----------------------------------------------------------------------------
    
    ------------------------ CLOCK GEN PROCESS ---------------------------------
    CLOCK_CLK : process
    begin
        -- This process generates a `CLOCK_PERIOD` ns period, 
        -- 50% duty cycle clock. Only generate clock if still simulating.
        if END_SIM = FALSE then
            Clock <= '0';
            wait for CLOCK_HALFPER;
        else
            wait;
        end if;
        if END_SIM = FALSE then
            Clock <= '1';
            wait for CLOCK_HALFPER;
        else
            wait;
        end if;
    end process;
    ----------------------------------------------------------------------------
end architecture;