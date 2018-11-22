--------------------------------------------------------------------------------
-- TAPController.vhd - VHDL implementation of a JTAG interface.
--
-- Description:
--      This VHDL file contains an entity `TAPController` with architecture 
--      `DataFlow` that implements a JTAG interface. The JTAG is able to 
--      shif data into and out of a data register and an instruction register.
--
--      Submission for EE 119a Homework 7.
--
-- Table of Contents:
--      entity          TAPController
--      architecture    DataFlow
--
-- I/O:
--      TRST    input   std_logic;     optional Test Reset input
--      TMS     input   std_logic;     Test Mode Select input
--      TDI     input   std_logic;     Test Data Input line input
--      TCK     input   std_logic;     Test Clock input
--      TDO     output  std_logic      Test Data Output line output
--
-- Revision History:
--      11/20/2018      Ray Sun         Initial revision. 
--      11/20/2018      Ray Sun         Shifting data out appears to be broken 
--                                      according to ModelSim. Update
--                                      documentation.
--      11/21/2018      Ray Sun         Corrected shifting logic and 
--                                      replaced TDO output with a combinational
--                                      MUX.
--      11/21/2018      Ray Sun         Verified functionality with the second
--                                      version of Glen's testbench.
--------------------------------------------------------------------------------

library ieee;                   -- Import the requisite packages
use ieee.std_logic_1164.all;    -- For 9-valued logic types

--------------------------------------------------------------------------------

entity TAPController is 
    generic(                                -- The generic constants
        INST_REG_LEN    : integer := 7;     -- Instruction register length
        DATA_REG_LEN    : integer := 32     -- Data register length
    );
    port(
        TRST  :  in  std_logic;     -- Optional Test Reset input
        TMS   :  in  std_logic;     -- Test Mode Select input
        TDI   :  in  std_logic;     -- Test Data Input line input
        TCK   :  in  std_logic;     -- Test Clock input
        TDO   :  out std_logic      -- Test Data Output line output
    );
end entity;

--------------------------------------------------------------------------------

architecture DataFlow of TAPController is
    -- Boolean logical values for `std_logic` types
    constant    SL_HIGH:    std_logic := '1';
    constant    SL_LOW:     std_logic := '0';
    
    -- Internal data and instruction registers
    signal      instReg:    std_logic_vector(INST_REG_LEN-1 downto 0);
    signal      dataReg:    std_logic_vector(DATA_REG_LEN-1 downto 0);
    
    -- FSM states
    --      There are 16 total states for a minimum of 4 state bits.
    --      These are from the JTAG state transition diagram.
    type tap_states is (
        TST_LOG_RST,
        RUN_TEST_IDLE,
        SEL_DR, CAP_DR, SHIFT_DR, EX_1_DR, PAUSE_DR, EX_2_DR, UPDATE_DR, 
        SEL_IR, CAP_IR, SHIFT_IR, EX_1_IR, PAUSE_IR, EX_2_IR, UPDATE_IR
    );
    
    -- Current and next FSM states 
    signal      currState:      tap_states := TST_LOG_RST;
    signal      nextState:      tap_states;
    
    -- FSM outputs 
    signal      ShiftEnable:    std_logic;  -- `SL_HIGH` when in shift state 
                                            -- and `SL_LOW` otherwise 
    signal      RegSelect:      std_logic;  -- `SL_HIGH` when IR is used,
                                            -- `SL_LOW` when DR is used, 
                                            -- and 'X' otherwise.
    
begin

    ----------------------------------------------------------------------------
    --                          NEXT STATE PROCESS                            --
    ----------------------------------------------------------------------------
    
    -- All signals used in conditions and assignments in sensitivity list 
    -- for a combinational process.
    TapNextState: process (TMS, TRST, currState)
    begin
        case currState is 
            -- In the test logic reset state, transition to idle if TMS is low
            -- and hold if high.
            when TST_LOG_RST =>
                if TMS = SL_LOW then
                    nextState <= RUN_TEST_IDLE;
                else 
                    nextState <= TST_LOG_RST;
                end if;
            -- In the idle state, transition to select DR scan only when TMS
            -- is high and hold when low.
            when RUN_TEST_IDLE =>
                if TMS = SL_HIGH then
                    nextState <= SEL_DR;
                else 
                    nextState <= RUN_TEST_IDLE;
                end if;
            ---------------------------- DR STATES -----------------------------
            -- In the select DR state, transition to select IR if TMS is high;
            -- otherwise transition to capture DR.
            when SEL_DR =>
                if TMS = SL_HIGH then
                    nextState <= SEL_IR;
                else 
                    nextState <= CAP_DR;
                end if;
            -- In the capture DR state, transition to shift DR if TMS is low and
            -- transition to exit 1 DR if TMS is high.
            when CAP_DR =>
                if TMS = SL_HIGH then
                    nextState <= EX_1_DR;
                else 
                    nextState <= SHIFT_DR;
                end if;
            -- In the shift DR state, transition to exit 1 DR if TMS is high
            -- and hold if low.
            when SHIFT_DR =>
                if TMS = SL_HIGH then
                    nextState <= EX_1_DR;
                else 
                    nextState <= SHIFT_DR;
                end if;
            -- In the exit 1 DR state, transition to update DR if TMS is high
            -- or to pause DR if low
            when EX_1_DR =>
                if TMS = SL_HIGH then
                    nextState <= UPDATE_DR;
                else 
                    nextState <= PAUSE_DR;
                end if;
            -- In the pause DR state, transition to exit 2 DR if TMS is high 
            -- and hold otherwise.
            when PAUSE_DR =>
                if TMS = SL_HIGH then
                    nextState <= EX_2_DR;
                else 
                    nextState <= PAUSE_DR;
                end if;
            -- In the exit 2 DR state, transition to update DR if TMS is high
            -- or back to shift DR if low
            when EX_2_DR =>
                if TMS = SL_HIGH then
                    nextState <= UPDATE_DR;
                else 
                    nextState <= SHIFT_DR;
                end if;
            -- In the update DR state, transition to select DR scan if TMS is
            -- high or back to idle if low
            when UPDATE_DR =>
                if TMS = SL_HIGH then
                    nextState <= SEL_DR;
                else 
                    nextState <= RUN_TEST_IDLE;
                end if;
            ---------------------------- IR STATES -----------------------------
            -- In the select IR state, transition back to reset if TMS is high;
            -- otherwise transition to capture IR.
            when SEL_IR =>
                if TMS = SL_HIGH then
                    nextState <= TST_LOG_RST;
                else 
                    nextState <= CAP_IR;
                end if;
            -- In the capture IR state, transition to shift IR if TMS is low and
            -- transition to exit 1 IR if TMS is high.
            when CAP_IR =>
                if TMS = SL_HIGH then
                    nextState <= EX_1_IR;
                else 
                    nextState <= SHIFT_IR;
                end if;
            -- In the shift IR state, transition to exit 1 IR if TMS is high
            -- and hold if low.
            when SHIFT_IR =>
                if TMS = SL_HIGH then
                    nextState <= EX_1_IR;
                else 
                    nextState <= SHIFT_IR;
                end if;
            -- In the exit 1 IR state, transition to update IR if TMS is high
            -- or to pause IR if low
            when EX_1_IR =>
                if TMS = SL_HIGH then
                    nextState <= UPDATE_IR;
                else 
                    nextState <= PAUSE_IR;
                end if;
            -- In the pause IR state, transition to exit 2 DR if TMS is high 
            -- and hold otherwise.
            when PAUSE_IR =>
                if TMS = SL_HIGH then
                    nextState <= EX_2_IR;
                else 
                    nextState <= PAUSE_IR;
                end if;
            -- In the exit 2 IR state, transition to update IR if TMS is high
            -- or back to shift IR if low
            when EX_2_IR =>
                if TMS = SL_HIGH then
                    nextState <= UPDATE_IR;
                else 
                    nextState <= SHIFT_IR;
                end if;
            -- In the update DR state, transition to select DR scan if TMS is
            -- high or back to idle if low
            when UPDATE_IR =>
                if TMS = SL_HIGH then
                    nextState <= SEL_DR;
                else 
                    nextState <= RUN_TEST_IDLE;
                end if;
        end case;
    end process;
    
    ----------------------------------------------------------------------------
    --                        UPDATE STATE PROCESS                            --
    ----------------------------------------------------------------------------
    
    TapUpdateState: process (TCK)
    begin 
        -- Since all signals are synchronous with the rising edge of TCK,
        -- the state updates whenever there is a rising edge on TCK.
        if rising_edge(TCK) then 
            -- If TRST is active, synchronously reset the TAP FSM
            if TRST = SL_HIGH then 
                currState <= TST_LOG_RST;
            -- Otherwise update state as usual
            else         
                currState <= nextState;
            end if;
        end if;
    end process;
    
    ----------------------------------------------------------------------------
    --                            OUTPUT DECODE                               --
    ----------------------------------------------------------------------------
    
    -- Combinationally decode outputs 
    -- Shift enable is active only when in a shifting state and the next state 
    -- is also the shift state, otherwise inactive.
    ShiftEnable <= SL_HIGH  when (currState = SHIFT_DR and 
                                  nextState = SHIFT_DR)
                              or (currState = SHIFT_IR and 
                                  nextState = SHIFT_IR) else 
                   SL_LOW;
                   
    -- Register select is `SL_HIGH` when in a DR state, `SL_LOW` when in 
    -- an IR state, and undefined otherwise
    RegSelect <=    SL_HIGH  when ((currState = SEL_IR   )  
                                or (currState = CAP_IR   ) 
                                or (currState = SHIFT_IR ) 
                                or (currState = EX_1_IR  ) 
                                or (currState = PAUSE_IR ) 
                                or (currState = EX_2_IR  ) 
                                or (currState = UPDATE_IR)) else
                    SL_LOW   when ((currState = SEL_DR   ) 
                                or (currState = CAP_DR   ) 
                                or (currState = SHIFT_DR ) 
                                or (currState = EX_1_DR  ) 
                                or (currState = PAUSE_DR ) 
                                or (currState = EX_2_DR  ) 
                                or (currState = UPDATE_DR)) else
                    'X';
    --RegSelect <=    SL_LOW   when ((currState = SEL_DR   ) 
    --                            or (currState = CAP_DR   ) 
    --                            or (currState = SHIFT_DR ) 
    --                            or (currState = EX_1_DR  ) 
    --                            or (currState = PAUSE_DR ) 
    --                            or (currState = EX_2_DR  ) 
    --                            or (currState = UPDATE_DR)) else
    --                SL_HIGH;
    
    ----------------------------------------------------------------------------
    --                        JTAG SHIFTING / OUTPUT                          --
    ----------------------------------------------------------------------------
    
    -- Process to handle shifting the data and instruction registers on the 
    -- shifting states.
    ShiftRegs: process (TCK)
    begin 
        if rising_edge(TCK) then 
            -- If in the shifting DR state, shift the DR left (shift in TDI
            -- from the right)
            --if currState = SHIFT_DR and nextState = SHIFT_DR then 
            --    -- Shift data register left
            --    dataReg(0) <= TDI;
            --    for i in 1 to dataReg'left loop 
            --        dataReg(i) <= dataReg(i-1);
            --    end loop;
            ---- If in the shifting IR state, shift the IR
            --elsif currState = SHIFT_IR and nextState = SHIFT_IR then 
            --    -- Shift instruction register left
            --    instReg(0) <= TDI;
            --    for i in 1 to instReg'left loop 
            --        instReg(i) <= instReg(i-1);
            --    end loop;
            --end if;
        
            -- If in the shifting DR state, shift the DR left (shift in TDI
            -- from the right)
            if ShiftEnable = SL_HIGH and RegSelect = SL_LOW then 
                -- Shift data register left
                dataReg(0) <= TDI;
                for i in 1 to dataReg'left loop 
                    dataReg(i) <= dataReg(i-1);
                end loop;
            -- If in the shifting IR state, shift the IR
            elsif ShiftEnable = SL_HIGH and RegSelect = SL_HIGH then
                -- Shift instruction register left
                instReg(0) <= TDI;
                for i in 1 to instReg'left loop 
                    instReg(i) <= instReg(i-1);
                end loop;
            end if;
        end if;
    end process;
    
    -- Combinational logic to output TDO - basically a MUX
    --      When in a DR state - is high bit of DR 
    --      When in an IR state - is high bit of IR 
    --      Otherwise don't care (do not infer a latch)
    with RegSelect select TDO <=
        instReg(instReg'left) when  SL_HIGH,
        dataReg(dataReg'left) when SL_LOW,
        'X'                   when others;
    --TDO <= instReg(instReg'left) when RegSelect = SL_HIGH else
    --       dataReg(dataReg'left) when RegSelect = SL_LOW;
        
end architecture;