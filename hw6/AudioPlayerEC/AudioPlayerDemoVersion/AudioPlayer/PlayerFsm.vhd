--------------------------------------------------------------------------------
-- PlayerFsm.vhd - VHDL implementation of a FSM for playing audio messages using 
-- pushbutton switches.
--
-- Description:
--      This VHDL file contains an entity `PlayerFsm` with architecture 
--      `Structural` that implements a 9-state Moore finite state machine for 
--      reading button pressed from a set of four switches.
--
--      Submission for EE 119a Homework 6.
--
--      This is the extra credit version.
--
-- Table of Contents:
--      entity          PlayerFsm
--          inputs      Clock        SL System clock 
--                      Switch4      SL System switch inputs
--                      Switch3
--                      Switch2
--                      Switch1
--                      MsgDone      SL SL that is `MSG_DONE` when the message 
--                                      is done playing and `MSG_NOTDONE` 
--                                      otherwise
--          outputs     MsgEnable    SL SL that is `MSG_EN` when the player 
--                                      is playing audio and `MSG_DIS` otherwise
--                      MsgLfsrEn    SL SL that is active (true) when the 
--                                      player is playing audio using the LFST
--                      MsgStartAddr SLV    SLVs for the starting and ending 
--                      MsgEndAddr   SLV    addresses for the message currently 
--                                          being played.
--      architecture    Structural
--
-- Details:
--      This VHDL code contains an entity `PlayerFsm` that implements a 3-state 
--      Moore machine for the PWM Audio Player extra credit version. The state 
--      machine takes the system clock, the switch inputs, and whether the 
--      player is done playing the current message as inputs. The machine 
--      outputs an enable signal that is active when the system should be 
--      playing audio and the starting and ending addresses of the current 
--      message. Switch 1 and Switch 2 are used to determine if the player 
--      should play the chosen extra credit message with or without 
--      oversampling. A
--      
--      Additionally, the system outputs a flag that is active when the audio 
--      should be played without oversampling. The state diagram is shown below.
--
--      The capacity of the FSM to play more than one message is retained by 
--      keeping the `MsgStartAddr` and `MsgEndAddr` outputs in the entity. 
--
--
--                                              done playing
--                                   +----------------------------------+
--                                   |                                  |
--                                   |                                  |
--                           +-------v-------+                          |
--              SW1 press    |     IDLE      |                          |
--             +-------------+  EN = false   |                          |
--             |             | StartAddr = X |    SW2                   |
--             |             |  EndAddr = X  +--+ press                 |
--             |             +---------------+  |                       |
--             |                                |                       |
--             |                                |                       |
--    +--------v---------+           +----------v-------+               |
--    |     PL_NOS       |           |    PL_NOS_LFSR   |               |
--    |    EN = true     |           |    EN = true     |               |
--    |   LFSR = false   |           |   LFSR = true    |               |
--    | StartAddr =MSGEC |           | StartAddr =MSGEC |               |
--    |  EndAddr = MSGEC |           |  EndAddr = MSGEC |               |
--    +------------------+           +------------------+               |
--             |                             |                          |
--             |                             |                          |
--             |                             |                           |
--             +---------------------------------------------------------^
--    
--
--      where `X` denotes don't-care.
--
--      This particular FSM architecture is used to make output decoding
--      trivial and to balance between an exclusively Moore machine, where 
--      the outputs do not depend on the input history (and might have 
--      more states, but trivial output decoding) and a Mealy machine with 
--      fewer states but more complex output decoding.
--
-- Limitations:
--      - This FSM design requires one clock after a state transition for 
--        playing to become enabled.
--
-- Revision History:
--      11/18/2018      Ray Sun         Initial revision. Created from old 
--                                      top-level entity.
--      11/18/2018      Ray Sun         Packaged constants into a VHDL package.
--      11/18/2018      Ray Sun         Verified functionality with a test
--                                      bench in ModelSim-Altera.
--      11/18/2018      Ray Sun         Corrected documentation.
--      11/19/2018      Ray Sun         Split EC version from non-EC version.
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use work.AudioPlayerConfig.all;


--------------------------------------------------------------------------------


entity PlayerFsm is 
    generic(
        N_ADDR_BITS:    integer := 19       -- Number of address bits
    );
    port(
        --------------------------- INPUTS -------------------------------------
        Clock:      in      std_logic;      -- System clock 
        Switch4:    in      std_logic;      -- Switch inputs
        Switch3:    in      std_logic;
        Switch2:    in      std_logic;   
        Switch1:    in      std_logic;   
        MsgDone:    in      std_logic;      -- `MSG_DONE` if done playing
                                            -- otherwise `MSG_NOTDONE`
                                            
        --------------------------- OUTPUTS ------------------------------------
        
        MsgEnable:      out std_logic;      -- `MSG_EN` if a message is 
                                            -- currently playing and `MSG_DIS`
                                            -- otherwise.
        MsgLfsrEn:      out std_logic;      -- `MSG_EN` if the LFSR non-
                                            -- oversampling is to be used and 
                                            -- `MSG_DIS` otherwise.
        -- Starting and ending addresses of the current message
        MsgStartAddr:   out std_logic_vector (N_ADDR_BITS - 1 downto 0);  
        MsgEndAddr:     out std_logic_vector (N_ADDR_BITS - 1 downto 0) 
    );
end entity;


--------------------------------------------------------------------------------


architecture Structural of PlayerFsm is

    --########################## SHARED CONSTANTS ############################--
    -- From `AudioPlayerConfig` package
    constant    MSG_EN:     std_logic := '1';   -- Message playing enabled       
    constant    MSG_DIS:    std_logic := '0';   -- Message playing disabled
    constant    MSG_DONE:   std_logic := '1';   -- Message done playing
    constant    MSG_NOTDONE:std_logic := '0';   -- Message not done playing                                
    constant    SW_PRESSED: std_logic := '1';   -- Switch input when pressed
    constant    SW_NOTPRSD: std_logic := '0';   -- Switch in when not pressed
    --########################################################################--
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
    
    -- Message to play for the extra credit
    constant EC_MSG_START: 
        std_logic_vector (N_ADDR_BITS-1 downto 0) := EPROM_M1_START; -- MSG 1
    constant EC_MSG_END: 
        std_logic_vector (N_ADDR_BITS-1 downto 0) := EPROM_M1_END;   -- MSG 1 
    --########################################################################--
    
    --------------- SW INPUT FSM ---------------
    -- FSM states
    --      - IDLE                  Waiting for a switch press
    --      - PL_NOS                Play message without oversampling
    --      - PL_NOS_LFSR           Play message without oversampling using 
    --                              the LFSR
    
    type        playerstates is (IDLE, 
                                 PL_NOS, PL_NOS_LFSR);
    -- Current and next state signals
    signal      currState:      playerstates := IDLE;
    signal      nextState:      playerstates;
    -- Internal active low signal that delays the `MsgEnable` output by a clock 
    -- so that the system can load the start and end addresses from the 
    -- FSM output.
    signal      msgLoad:        std_logic;
    
begin

    ----------------------------- Next state logic -----------------------------
    
    CurrFsmNextState: process (Switch4, Switch3, Switch2, Switch1, 
                               MsgDone, 
                               currState)
    begin
        case currState is
            -- If in IDLE and a switch is pressed, go to the respective 
            -- load state 
            when IDLE => 
                -- Switch 2 to play using LFSR
                if Switch2 = SW_PRESSED then 
                    nextState <= PL_NOS_LFSR; 
                -- Switch 1 to play `regular` non-oversampling. 
                elsif Switch1 = SW_PRESSED then 
                    nextState <= PL_NOS; 
                else 
                    nextState <= IDLE;
                end if;
            
            -- If in a playing state, check if done and go back to IDLE if so
            when PL_NOS => 
                if MsgDone = MSG_DONE then 
                    nextState <= IDLE; 
                else 
                    nextState <= PL_NOS; 
                end if; 
            when PL_NOS_LFSR => 
                if MsgDone = MSG_DONE then 
                    nextState <= IDLE; 
                else 
                    nextState <= PL_NOS_LFSR; 
                end if; 
        end case;
    end process;
    
    ------------------------------ Output update -------------------------------
    
    PlayerFsmOutput: process (currState)
    begin
        case currState is 
            when IDLE =>
                msgLoad      <= MSG_DIS;        -- Not enabled
                MsgLfsrEn    <= MSG_DIS;        -- Don't care about LFSR
                MsgStartAddr <= EPROM_ADDR_IDLE;-- Start and end doesn't matter
                MsgEndAddr   <= EPROM_ADDR_IDLE;
            when PL_NOS =>
                msgLoad      <= MSG_EN;         -- enabled
                MsgLfsrEn    <= MSG_DIS;        -- Not ovsampling with LFSR
                MsgStartAddr <= EC_MSG_START;   -- Start and end for extra
                MsgEndAddr   <= EC_MSG_END;     -- credit message selected.
            when PL_NOS_LFSR =>
                msgLoad      <= MSG_EN;         -- enabled
                MsgLfsrEn    <= MSG_EN;         -- Not ovsampling with LFSR
                MsgStartAddr <= EC_MSG_START;   -- Start and end for extra
                MsgEndAddr   <= EC_MSG_END;     -- credit message selected.
        end case;
    end process;
    
    ------------------------------ State update --------------------------------
    
    -- Update switch FSM state on the rising edge of every system clock
    PlayerFsmUpdate: process (Clock)
    begin
        if rising_edge(Clock) then
            -- Update the state
            currState <= nextState;      
            -- Delay the enable signal by one clock with a DFF. Give rest of 
            -- system a clock to load in the addresses.
            MsgEnable <= msgLoad;
            -- The LFSR signal does not need to be delayed
        end if;
    end process;
end architecture;
