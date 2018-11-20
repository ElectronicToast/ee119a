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
--                      MsgStartAddr SLV    SLVs for the starting and ending 
--                      MsgEndAddr   SLV    addresses for the message currently 
--                                          being played.
--      architecture    Structural
--
-- Details:
--      This VHDL code contains an entity `PlayerFsm` that implements a 9-state 
--      Moore machine for the PWM Audio Player. The state machine takes 
--      the system clock, the switch inputs, and whether the player is done
--      playing the current message as inputs. The machine outputs an enable 
--      signal that is active when the system should be playing audio and the 
--      starting and ending addresses of the current message. The state diagram
--      is shown below.
--
--
--                                              done playing
--                                   +-----------------------------------+
--                                   |                                   |
--                                   |                                   |
--                           +-------v-------+     SW1 press             |
--              SW4 press    |     IDLE      +--------------+            |
--             +-------------+  EN = false   |              |            |
--             |             | StartAddr = X |    SW2       |            |
--             |             |  EndAddr = X  +--+ press     |            |
--             |             +---------------+  |           |            |
--             |               |                |           |            |
--             |               | SW2            |           |            |
--    +--------v---------+     | P   +----------v-------+   |            |
--    |     PLAY_MSG1    |     | R   |     PLAY_MSG3    |   |            |
--    |    EN = true     |     | E   |    EN = true     |   |            |
--    | StartAddr = MSG1 |     | S   | StartAddr = MSG3 |   |            |
--    |  EndAddr = MSG1  |     | S   |  EndAddr = MSG3  |   |            |
--    +------------------+     |     +------------------+   |            |
--             |               |             |              |            |
--             |               |             |              |            |
--             |   +-----------v------+      |    +---------v--------+   |
--             |   |     PLAY_MSG2    |      |    |     PLAY_MSG4    |   |
--             |   |    EN = true     |      |    |    EN = true     |   |
--             |   | StartAddr = MSG2 |      |    | StartAddr = MSG4 +--->
--             |   |  EndAddr = MSG2  |      |    |  EndAddr = MSG4  |   |
--             |   +------------------+      |    +------------------+   |
--             |              |              |                           |
--             |              |              |                           |
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
    --########################################################################--
        
    --------------- SW INPUT FSM ---------------
    -- FSM states
    --      - IDLE                  Waiting for a switch press
    --      - PLMSG1..PLMSG4        Respective message being played
    
    type        playerstates is (IDLE, 
                                 PLMSG1, PLMSG2, PLMSG3, PLMSG4);
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
                if    Switch4 = SW_PRESSED then 
                    nextState <= PLMSG1; 
                elsif Switch3 = SW_PRESSED then 
                    nextState <= PLMSG2; 
                elsif Switch2 = SW_PRESSED then 
                    nextState <= PLMSG3; 
                elsif Switch1 = SW_PRESSED then 
                    nextState <= PLMSG4; 
                else 
                    nextState <= IDLE;
                end if;
            
            -- If in a playing state, check if done
            when PLMSG1 => 
                if MsgDone = MSG_DONE then 
                    nextState <= IDLE; 
                else 
                    nextState <= PLMSG1; 
                end if; 
            when PLMSG2 => 
                if MsgDone = MSG_DONE then 
                    nextState <= IDLE; 
                else 
                    nextState <= PLMSG2; 
                end if; 
            when PLMSG3 => 
                if MsgDone = MSG_DONE then 
                    nextState <= IDLE; 
                else 
                    nextState <= PLMSG3; 
                end if; 
           when PLMSG4 =>
                if MsgDone = MSG_DONE then 
                    nextState <= IDLE; 
                else 
                    nextState <= PLMSG4; 
                end if; 
        end case;
    end process;
    
    ------------------------------ Output update -------------------------------
    
    PlayerFsmOutput: process (currState)
    begin
        case currState is 
            when IDLE =>
                msgLoad      <= MSG_DIS;        -- Not enabled
                MsgStartAddr <= EPROM_ADDR_IDLE;-- Start and end doesn't matter
                MsgEndAddr   <= EPROM_ADDR_IDLE;
            when PLMSG1 =>
                msgLoad      <= MSG_EN;         -- enabled
                MsgStartAddr <= EPROM_M1_START; -- Start and end for message 1
                MsgEndAddr   <= EPROM_M1_END;
            when PLMSG2 =>
                msgLoad      <= MSG_EN;         -- enabled
                MsgStartAddr <= EPROM_M2_START; -- Start and end for message 2
                MsgEndAddr   <= EPROM_M2_END;
            when PLMSG3 =>
                msgLoad      <= MSG_EN;         -- enabled
                MsgStartAddr <= EPROM_M3_START; -- Start and end for message 3
                MsgEndAddr   <= EPROM_M3_END;
            when PLMSG4 =>
                msgLoad      <= MSG_EN;         -- enabled
                MsgStartAddr <= EPROM_M4_START; -- Start and end for message 4
                MsgEndAddr   <= EPROM_M4_END;
        end case;
    end process;
    
    ------------------------------ State update --------------------------------
    
    -- Update switch FSM state on the rising edge of every system clock
    PlayerFsmUpdate: process (Clock)
    begin
        if rising_edge(Clock) then
            -- Update the state
            currState <= nextState;      
            -- Delay the enable signal by one clock with a DFF
            MsgEnable <= msgLoad;
        end if;
    end process;
end architecture;
