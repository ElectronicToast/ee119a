--------------------------------------------------------------------------------
-- AudioPlayerTb.vhd - VHDL test bench for the PWM Audio Player.
--
-- Description:
--      This VHDL file contains an entity `AudioPlayerTb` with architecture 
--      `TB_ARCHITECUTRE` that implements a test bench for the `DataFlow`
--      architecture of the `AudioPlayer` entity. This file simulates
--      approximately 30 seconds of pressing various switches. Dummy addresses
--      are associated with each message (physically corresponding to messages
--      with a single tone) in order to verify the outputs with the ModelSim
--      waveform viewer.
--
--      Submission for EE 119a Homework 6.
--
--      This is the extra-credit implementation.
--
-- Limitations:
--      - Running this thing takes approximately a minute a second with ModelSim.
--
-- Revision History:
--      11/18/2018      Ray Sun         Initial revision.
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.AudioPlayerConfig.all;


--------------------------------------------------------------------------------


entity AudioPlayerTb is
end AudioPlayerTb;

architecture TB_ARCHITECTURE of AudioPlayerTb is
    constant CLK_PERIOD: integer  := 32;    -- System clock in ns
    constant MSG_DATA_1 : integer := 10;    -- PWM data values for each switch
    constant MSG_DATA_2 : integer := 63;    -- in order to tell them apart
    
    -- UUT component declaration
    component AudioPlayer
        port(
            Clock:      in  std_logic;
            Switch4:    in  std_logic;
            Switch3:    in  std_logic;
            Switch2:    in  std_logic;
            Switch1:    in  std_logic;
            AudioData:  in  std_logic_vector(N_DATA_BITS-1 downto 0);
            AudioAddr:  out std_logic_vector(N_ADDR_BITS-1 downto 0);
            PWMOut:     out std_logic);
    end component;

    -- Stimulus signals mapping to UUT port inports
    signal clk:       std_logic;
    signal sw4:       std_logic;
    signal sw3:       std_logic;
    signal sw2:       std_logic;
    signal sw1:       std_logic;
    signal epromData: std_logic_vector(N_DATA_BITS-1 downto 0);

    -- Observed signals mapp
    signal epromAddr:   std_logic_vector(N_ADDR_BITS-1 downto 0);
    signal pwmOut:      std_logic;
    
    -- End of simulation flag to stop clock generation
    signal END_SIM:     boolean := false;

begin
    -- Port map for the UUT
    UUT : AudioPlayer
        port map  (
            Clock     => clk,
            Switch4   => sw4,
            Switch3   => sw3,
            Switch2   => sw2,
            Switch1   => sw1,
            AudioData => epromData,
            AudioAddr => epromAddr,
            PWMOut    => pwmOut
        );
    
    -- Stimulus process
    process
    begin
        -- Initialize with all switches not pressed
        sw4       <= '0';
        sw3       <= '0';
        sw2       <= '0';
        sw1       <= '0';
        -- and the dummy input
        epromData <= std_logic_vector(to_unsigned(MSG_DATA_2, N_DATA_BITS));
        
        -- Wait for 5 clocks
        wait for 160 ns;
        
        -- Press switch 2; play with LFSR
        sw2       <= '1';
        -- Wait some clocks, then release
        wait for 96 ns;
        sw2       <= '0';
        -- Let Message 1 play to end (~ 4 s)
        wait for 4 sec;
        
        epromData <= std_logic_vector(to_unsigned(MSG_DATA_1, N_DATA_BITS));
        
        -- Press switch 1; play without LFSR
        sw1       <= '1';
        wait for 96 ns;
        sw1       <= '0';
        -- Let Message 1 play to end (~ 4 s)
        wait for 4 sec;
        
        -- Set end-of-simulation flag
        END_SIM <= true;
    --end of the stimulus process
    end process;
        
    -- Process to generate a 32 MHz clock (period of 30 ns)
    -- Stops clock generation if `END_SIM` is active.
    CLOCK_clk : process
    begin
        if END_SIM = FALSE then
            CLK <= '0';
            wait for 15 ns;
        else
            wait;
        end if;

        if END_SIM = FALSE then
            CLK <= '1';
            wait for 15 ns;
        else
            wait;
        end if;
    end process;

end TB_ARCHITECTURE;
