--------------------------------------------------------------------------------
-- AudioPlayer.vhd - VHDL implementation of a 8-bit PWM audio player.
--
-- Description:
--      This VHDL file contains an entity `AudioPlayer` with architecture 
--      `DataFlow` that is the top-level entity for the PWM Audio Player.
--
--      Submission for EE 119a Homework 6.
--
--      This is the extra credit implementation.
--
--      We arbitrarily choose to play Message 1 using the first two switches.
--      Switch 1 is oversampling, while Switch 2 is oversampling with the LFSR.
--
--      THIS IS THE `DEMO VERSION`. Since Xilinx ISE apparently cannot find my 
--      `AudioPlayerConfig` package when assigning pins, I copy all the
--      constants used from that library to the respective files in which 
--      they are used. They are demarcated with --########-- comment lines.
--      Generic constants are placed in entity declarations as appropriate.
--
-- File organization:
--      Entity          Architecture        Description
--      ------------------------------------------------------------------------
--      AudioPlayer     DataFlow            Top-level module of PWM Audio Player 
--      SysCounter      DataFlow            System counter, 12-bit up counter 
--                                          with synchronous reset.
--      SysLfsr         DataFlow            System LFSR used for playing audio 
--                                          with an LFSR and no oversampling.
--      PlayerFsm       Structural          Mealy FSM for button reading and
--                                          handling state transitions.
--      AddrSel         DataFlow            Address selector module that 
--                                          implements pipelining; outputs 
--                                          correct address and registers 
--                                          PWM data to/from EPROM.
--      PwmComparator   DataFlow            PWM output module.
--
--      Package                 Description
--      ------------------------------------------------------------------------
--      AudioPlayerConfig       A library of constants for the audio player.
--
-- Table of Contents:
--      entity          AudioPlayer
--          inputs      Clock      SL   System clock 
--                      Switch4    SL   System switch inputs
--                      Switch3
--                      Switch2
--                      Switch1
--                      AudioData  SLV  8-bit data bus input from EPROM 
--          outputs     PWMOut     SL   PWM output signal 
--                      AudioAddr  SLV  19-bit EPROM reading address bus
--      architecture    DataFlow
--
-- Details:
--      Pressing one of the following switches plays the respective message.
--              SW4         Message 1
--              SW3         Message 2
--              SW2         Message 3
--              SW1         Message 4
--      The message will repeat should the switch be pressed at the end of 
--      playing the current message.
--
--      The system has a 32 MHz clock input, which is divided by 4096 via a 
--      12-bit up counter to generate an approximately 8 kHz audio signal. (An
--      actual 8 MHz clock is 4000 system clocks; we take that to be 4096). A 
--      single sample of the PWM takes 256 system clocks. Therefore there are 
--      16 periods of PWM output per 128 us (which we take to be approximately 
--      125 us). The low 4 bits of this counter are used to enable an 8-bit 
--      LFSR that allows audio output with no oversampling and an LFSR.
--
--      A five-state Mealy finite state machine is used to determine if the 
--      system should be playing audio and what the starting and ending EPROM 
--      addresses of the current message are. If no message is to be played, the 
--      addresses are set to `EPROM_ADDR_IDLE` and an Enable signal is
--      inactive. If a message is to be played the correct start and end
--      addresses are output and the Enable signal is set active. A Done signal 
--      set when the end address has been read is used to transition back to 
--      the idle, not-playing state. Depending on which switch was pressed, 
--      a LFSR enable signal is set or cleared to indicate that the LFSR is
--      to be used in playing non-oversampled output.
--
--      The "address selector" module implements data pipelining by incrementing
--      the current reading address once the 12-bit counter reaches its top 
--      value and registering the previous PWM data read from the EPROM to 
--      be output. This PWM signal is set low if playing is not enabld. This 
--      module also sets the Done signal.
--
--      The PWM comparator generates the output PWM signal from the registered 
--      PWM data by comparing the rolling up-count from the system counter to 
--      the registered PWM data. When the count is less than the data, the PWM 
--      signal is high. This module determines the appropriate count source
--      - the system counter or the LFSR - using the LFSR enable signal.
--
-- Limitations:
--      - Because of the design of the PWM cmparator that compares the 12-bit 
--        up-counter to the registered PWM data, 100% duty cycle is not 
--        achievable (data of 255).
--      - Due to the synchronous design of the address select module and the 
--        PWM output, the first PWM wave high time after the next address is 
--        read lags by one clock.
--      - I could not get this to fit on the Lattice ISPLSI1016PGA.
--      - Xilinx ISE seems to not like dealing with package libraries when
--        using the PACE pin assignment tool. So I have attached a "demo
--        version" of the code, where all the constants in the 
--        `AudioPlayerConfig` package are defined as GENERICs in entity 
--        declarations or CONSTANTS in architectures. The demo version is 
--        identical to this version in the VHDL entities and architectures.
--
-- Revision History:
--      11/14/2018      Ray Sun         Initial revision.
--      11/14/2018      Ray Sun         Got 12 bit counter process working and 
--                                      verified with Quartus waveform viewer.
--      11/15/2018      Ray Sun         Added switch FSM implementation.
--      11/15/2018      Ray Sun         Revised FSM implementation to create a 
--                                      Moore machine instead of a Mealy machine 
--                                      to simplify the output logic. 
--      11/15/2018      Ray Sun         Added process for handling PWM output 
--                                      and verified functionality with 
--                                      Quartus waveform viewer.
--      11/18/2018      Ray Sun         Split module into multiple entities.
--      11/18/2018      Ray Sun         Verified playing dummy messages with 
--                                      ModelSim-Altera.
--      11/19/2018      Ray Sun         Updated documentation.
--      11/19/2018      Ray Sun         Verified functionality with the demo 
--                                      version on board.
--      11/19/2018      Ray Sun         Split EC version from nonEC version.
--      11/19/2018      Ray Sun         Verified EC functionality on board.
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use work.AudioPlayerConfig.all;


--------------------------------------------------------------------------------


entity AudioPlayer is
    port(
        --------------------------- INPUTS -------------------------------------
        Clock:      in      std_logic;          -- System clock
        Switch4:    in      std_logic;          -- Switch inputs
        Switch3:    in      std_logic;
        Switch2:    in      std_logic;
        Switch1:    in      std_logic;
        -- Audio data input from EPROM
        AudioData:  in      std_logic_vector (7 downto 0); 
       
        -------------------------- OUTPUTS -------------------------------------
        -- PWM output signal 
        PWMOut:     out     std_logic;          
        -- Audio address bus to EPROM
        AudioAddr:  out     std_logic_vector (18 downto 0)
    );
end entity;


--------------------------------------------------------------------------------


architecture DataFlow of AudioPlayer is 
    --####################### SHARED CONSTANTS ###############################--
    -- From `AudioPlayerConfig` package
    constant    N_DATA_BITS: integer := 8;      -- Number of audio data lines
    constant    N_ADDR_BITS: integer := 19;     -- Number of audio address lines
    constant    CNTR_SIZE:   integer := 12;     -- Number of bits in counter
    constant    CNTR_CMP_BOTTOM:    integer := 4;   -- Top & bottom of compare
    constant    CNTR_CMP_TOP:       integer := 11;   -- range - range of bits 
                                                    -- in count to compare to 
                                                    -- PWM data 
    constant    LFSR_CNTR_IN_SIZE:  integer := 4;   -- LFSR input counter size
    constant    LFSR_SIZE:          integer := 8;   -- LFSR size. Must equal
                                                    -- data bus width
    --########################################################################--
    
    -- System internal signals
    signal msgEnable:   std_logic;      -- Active when playing audio is enabled
    signal msgLfsrEn:   std_logic;      -- Active when LFSR is to be used
    signal msgDone:     std_logic;      -- Active when done playing message
    
    -- Start and end addresses for current message in EPROM
    signal startAddr:   std_logic_vector(N_ADDR_BITS-1 downto 0);
    signal endAddr:     std_logic_vector(N_ADDR_BITS-1 downto 0);
    
    -- Counter value
    signal count:       std_logic_vector(CNTR_SIZE-1 downto 0);
    
    -- LFSE value 
    signal lfsrVal:     std_logic_vector(LFSR_SIZE-1 downto 0);
    
    -- PWM output (high time value)
    signal pwmData:     std_logic_vector(N_DATA_BITS-1 downto 0);
    
    -- Internal active high system counter reset
    signal counterReset: std_logic;
    
    ---------------------------- COMPONENTS ------------------------------------
       
    component SysCounter        -- The system counter
        port(
            Clock:          in          std_logic; 
            Reset:          in          std_logic;      
            Count:          buffer      std_logic_vector(CNTR_SIZE-1 downto 0)  
        );
    end component;
    
    component SysLfsr           -- The system LFSR for no-oversample with LFSR 
        port(
            Clock:      in      std_logic;
            Reset:      in      std_logic;
            Count:      in      std_logic_vector(LFSR_CNTR_IN_SIZE-1 downto 0);
            LfsrCount:  out     std_logic_vector(LFSR_SIZE-1 downto 0)  
        );
    end component;
    
    component PlayerFsm         -- FSM for switch presses
        port(
            Clock:          in      std_logic;      
            Switch4:        in      std_logic;      
            Switch3:        in      std_logic;
            Switch2:        in      std_logic;   
            Switch1:        in      std_logic;   
            MsgDone:        in      std_logic;
            MsgEnable:      out     std_logic;   
            MsgLfsrEn:      out     std_logic;
            MsgStartAddr:   out     std_logic_vector(N_ADDR_BITS - 1 downto 0);  
            MsgEndAddr:     out     std_logic_vector(N_ADDR_BITS - 1 downto 0) 
        );
    end component;
    
    component AddrSelect        -- Address select and data pipelining
        port(
            Clock:          in      std_logic;       
            MsgStartAddr:   in      std_logic_vector(N_ADDR_BITS-1 downto 0);
            MsgEndAddr:     in      std_logic_vector(N_ADDR_BITS-1 downto 0);
            MsgEnable:      in      std_logic;       
            Count:          in      std_logic_vector(CNTR_SIZE-1 downto 0);   
            EPROMData:      in      std_logic_vector(N_DATA_BITS-1 downto 0); 
            CurrAddr:       buffer  std_logic_vector(N_ADDR_BITS-1 downto 0);
            PWMData:        out     std_logic_vector(N_DATA_BITS-1 downto 0);  
            MsgDone:        out     std_logic
        );
    end component;
    
    component PwmComparator     -- The PWM output module
        port(
            Clock:          in      std_logic; 
            Count:          in      std_logic_vector(N_DATA_BITS-1 downto 0);
            LfsrCount:      in      std_logic_vector(N_DATA_BITS-1 downto 0);
            MsgLfsrEn:      in      std_logic;
            Threshold:      in      std_logic_vector(N_DATA_BITS-1 downto 0);
            PWMOut:         out     std_logic
        );
    end component;
    
begin
 
    -- Reset the counter if playing is not enabled
    counterReset <= not msgEnable;
    
    ---------------------------- PORT MAPS -------------------------------------

    -- Connect up to the submodules
    Fsm: PlayerFsm    port map(  
                Clock          => Clock,
                Switch4        => Switch4,
                Switch3        => Switch3,
                Switch2        => Switch2,
                Switch1        => Switch1,
                MsgDone        => msgDone,
                MsgEnable      => msgEnable,
                MsgLfsrEn      => msgLfsrEn,
                MsgStartAddr   => startAddr,
                MsgEndAddr     => endAddr
                );
                
    Counter: SysCounter port map(
                Clock          => Clock,
                Reset          => counterReset,
                Count          => count
                );
                
    Lfsr: SysLfsr port map(
                Clock          => Clock,
                Reset          => counterReset,
                -- Use low nibble of system counter count as input 
                -- to LFSR
                Count          => count(LFSR_CNTR_IN_SIZE-1 downto 0),
                LfsrCount      => lfsrVal
                );
                
    AddrSel: AddrSelect port map( 
                Clock          => Clock,
                MsgStartAddr   => startAddr,
                MsgEndAddr     => endAddr,
                MsgEnable      => msgEnable, 
                Count          => count,
                EPROMData      => AudioData,
                CurrAddr       => AudioAddr, 
                PWMData        => pwmData,
                MsgDone        => msgDone
                );
                
    Comp: PwmComparator  port map( 
                Clock          => Clock,
                -- The high byte - the high 8 bits - of the count is used 
                -- for the extra credit implementation
                Count          => count(CNTR_CMP_TOP downto CNTR_CMP_BOTTOM),
                -- Also pass in the LFSR value
                LfsrCount      => lfsrVal,
                MsgLfsrEn      => msgLfsrEn,
                Threshold      => pwmData,
                PWMOut         => PWMOut
                );
                                 
end architecture;