----------------------------------------------------------------------------
--
--  Test Bench for TAP controller state mahcine
--
--  This is a test bench for the TAP controller state machine entity.  The
--  test bench thoroughly tests the entity by exercising it and checking the
--  outputs through the use of arrays of test inputs (TestInput) and expected
--  results (TestOutput).  The test bench entity is called TAPFSM_tb.  It does
--  not include the code to specify a specific architecture of the TAP
--  controller state machine entity.
--
--  Revision History:
--     11/20/18  Glen George              Initial revision.
--     11/21/18  Glen George              Fixed output compare timing.
--
----------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity TAPFSM_tb is
end TAPFSM_tb;

architecture TB_ARCHITECTURE of TAPFSM_tb is
    -- Component declaration of the tested unit
    component TAPController
        port(
            TRST  :  in  std_logic;
            TMS   :  in  std_logic;
            TDI   :  in  std_logic;
            TCK   :  in  std_logic;
            TDO   :  out std_logic
        );
    end component;

    -- Stimulus signals - signals mapped to the input and inout ports of tested entity
    signal  TDI   :  std_logic;		-- data input
    signal  TMS   :  std_logic;		-- mode input
    signal  TRST  :  std_logic;		-- reset signal
    signal  TCK   :  std_logic;		-- clock

    -- Observed signals - signals mapped to the output ports of tested entity
    signal  TDO   :  std_logic;

    --Signal used to stop clock signal generators
    signal  END_SIM   :  BOOLEAN := FALSE;

    -- test values
    signal  TestReset   :  std_logic_vector(0 to 429);
    signal  TestMode    :  std_logic_vector(0 to 429);
    signal  TestInput   :  std_logic_vector(0 to 429);
    signal  TestOutput  :  std_logic_vector(0 to 429);


begin

    -- Unit Under Test port map
    UUT : TAPController
        port map(
            TRST => TRST,
            TMS => TMS,
            TDI => TDI,
            TCK => TCK,
            TDO => TDO
        );


    -- initialize the test inputs and expected output
    TestReset  <= "0000"                                                     & -- reset
                  "000"                                                      & -- idle
                  "000000000000000000"                                       & -- shift 7 bits into IR to idle
                  "0"                                                        & -- idle
                  "0000000000000000000000000000000000000000"                 & -- shift 32 bits into DR to select
                  "00000000"                                                 & -- load IR to idle
                  "000000000000"                                             & -- shift 5 bits into IR to select
                  "00000000000000000000"                                     & -- shift 10 bits into DR to select
                  "00000"                                                    & -- load DR to idle
                  "00000000000000000000000000000000000"                      & -- multi-shift 5 bits, 4 bits, 6 bits into IR to select
                  "1"                                                        & -- reset signal
                  "0000000"                                                  & -- reset
                  "00"                                                       & -- idle
                  "00000000000000000"                                        & -- shift 5 bits into DR to select
                  "00"                                                       & -- reset pattern
                  "0"                                                        & -- reset
                  "0"                                                        & -- idle
                  "000000000"                                                & -- load DR to select
                  "0000000000000000"                                         & -- shift 10 bits into IR to select
                  "0000000000000000000000000000000000000000000000000000000"  & -- multi-shift 10 bits, 20 bits, 10 bits into DR to select
                  "000000000"                                                & -- load DR to idle
                  "00000000000000000000000000000000000000000000000000000000" & -- shift 50 bits into DR to idle
                  "0"                                                        & -- idle
                  "0000000"                                                  & -- load IR to select
                  "000000000000000"                                          & -- shift 10 bits into DR to select
                  "00000"                                                    & -- load DR to idle
                  "000000000"                                                & -- shift 2 bits into IR to idle
                  "000"                                                      & -- idle
                  "0000000000000000000000000000000000000"                    & -- multi-shift 5 bits, 2 bits, 10 bits into DR to idle
                  "00000000000000000000000000"                               & -- multi-shift 1 bit, 2 bits, 3 bits into IR to idle
                  "00000";                                                     -- idle

    TestMode   <= "1111"                                                     & -- reset
                  "000"                                                      & -- idle
                  "110000000001000110"                                       & -- shift 7 bits into IR to idle
                  "0"                                                        & -- idle
                  "1000000000000000000000000000000000010111"                 & -- shift 32 bits into DR to select
                  "10100110"                                                 & -- load IR to idle
                  "110000000111"                                             & -- shift 5 bits into IR to select
                  "00000000000010000111"                                     & -- shift 10 bits into DR to select
                  "01100"                                                    & -- load DR to idle
                  "11000000010100000100010000000100111"                      & -- multi-shift 5 bits, 4 bits, 6 bits into IR to select
                  "0"                                                        & -- reset signal
                  "1111111"                                                  & -- reset
                  "00"                                                       & -- idle
                  "10000000100000111"                                        & -- shift 5 bits into DR to select
                  "11"                                                       & -- reset pattern
                  "1"                                                        & -- reset
                  "0"                                                        & -- idle
                  "101000111"                                                & -- load DR to select
                  "1000000000000111"                                         & -- shift 10 bits into IR to select
                  "0000000000001010000000000000000000001000100000000000111"  & -- multi-shift 10 bits, 20 bits, 10 bits into DR to select
                  "010000110"                                                & -- load DR to idle
                  "10000000000000000000000000000000000000000000000000000110" & -- shift 50 bits into DR to idle
                  "0"                                                        & -- idle
                  "1101101"                                                  & -- load IR to select
                  "000000000000111"                                          & -- shift 10 bits into DR to select
                  "01100"                                                    & -- load DR to idle
                  "110000110"                                                & -- shift 2 bits into IR to idle
                  "000"                                                      & -- idle
                  "1000000010100010000100000000000100110"                    & -- multi-shift 5 bits, 2 bits, 10 bits into DR to idle
                  "11000100001000100010000110"                               & -- multi-shift 1 bit, 2 bits, 3 bits into IR to idle
                  "00000";                                                     -- idle

    TestInput  <= "XXXX"                                                     & -- reset
                  "XXX"                                                      & -- idle
                  "XXX10011000XXXXXXX"                                       & -- shift 7 bits into IR to idle
                  "X"                                                        & --idle
                  "XX011110000111000110010101011010011XXXXX"                 & -- shift 32 bits into DR to select
                  "XXXXXXXX"                                                 & -- load IR to idle
                  "XXX110110XXX"                                             & -- shift 5 bits into IR to select
                  "X10010110011XXXXXXXX"                                     & -- shift 10 bits into DR to select
                  "XXXXX"                                                    & -- load DR to idle
                  "XXX011001XXXX0010XXXXXX010111XXXXXX"                      & -- multi-shift 5 bits, 4 bits, 6 bits into IR to select
                  "X"                                                        & -- reset signal
                  "XXXXXXX"                                                  & -- reset
                  "XX"                                                       & -- idle
                  "XX101111XXXXXXXXX"                                        & -- shift 5 bits into DR to select
                  "XX"                                                       & -- reset pattern
                  "X"                                                        & -- reset
                  "X"                                                        & -- idle
                  "XXXXXXXXX"                                                & -- load DR to select
                  "XX10100011011XXX"                                         & -- shift 10 bits into IR to select
                  "X10101110011XXX101101110010111011110XXXXX10010011010XXX"  & -- multi-shift 10 bits, 20 bits, 10 bits into DR to select
                  "XXXXXXXXX"                                                & -- load DR to idle
                  "XX010110101011010010011100101000110000111111101101110XXX" & -- shift 50 bits into DR to idle
                  "X"                                                        & -- idle
                  "XXXXXXX"                                                  & -- load IR to select
                  "X10101110101XXX"                                          & -- shift 10 bits into DR to select
                  "XXXXX"                                                    & -- load DR to idle
                  "XXX100XXX"                                                & -- shift 2 bits into IR to idle
                  "XXX"                                                      & -- idle
                  "XX100110XXXX00XXXXXXX1111101011XXXXXX"                    & -- multi-shift 5 bits, 2 bits, 10 bits into DR to idle
                  "XXX01XXXXXX101XXXXX0101XXX"                               & -- multi-shift 1 bit, 2 bits, 3 bits into IR to idle
                  "XXXXX";                                                     -- idle

    TestOutput <= "----"                                                     & -- reset
                  "---"                                                      & -- idle
                  "-----------0------"                                       & -- shift 7 bits into IR to idle
                  "-"                                                        & -- idle
                  "-----------------------------------1----"                 & -- shift 32 bits into DR to select
                  "---00---"                                                 & -- load IR to idle
                  "---0001100--"                                             & -- shift 5 bits into IR to select
                  "-111110000111-------"                                     & -- shift 10 bits into DR to select
                  "-11--"                                                    & -- load DR to idle
                  "---0001011--110110----00010010-----"                      & -- multi-shift 5 bits, 4 bits, 6 bits into IR to select
                  "-"                                                        & -- reset signal
                  "-------"                                                  & -- reset
                  "--"                                                       & -- idle
                  "--1100011--------"                                        & -- shift 5 bits into DR to select
                  "--"                                                       & -- reset pattern
                  "-"                                                        & -- reset
                  "-"                                                        & -- idle
                  "-11------"                                                & -- load DR to select
                  "--000101110100--"                                         & -- shift 10 bits into IR to select
                  "-110010101011--1101001100101100110111----111010111001--"  & -- multi-shift 10 bits, 20 bits, 10 bits into DR to select
                  "-1-------"                                                & -- load DR to idle
                  "--1110110111001011101111000100110101011010101101001001--" & -- shift 50 bits into DR to idle
                  "-"                                                        & -- idle
                  "---00--"                                                  & -- load IR to select
                  "-111100101000--"                                          & -- shift 10 bits into DR to select
                  "-00--"                                                    & -- load DR to idle
                  "---0001--"                                                & -- shift 2 bits into IR to idle
                  "---"                                                      & -- idle
                  "--0011000--0001-----111111110110-----"                    & -- multi-shift 5 bits, 2 bits, 10 bits into DR to idle
                  "---111-----1101----11100--"                               & -- multi-shift 1 bit, 2 bits, 3 bits into IR to idle
                  "-----";                                                     -- idle


    -- now generate the stimulus and test the design
    process

        -- some useful variables
        variable  i  :  integer;        -- general loop index

    begin  -- of stimulus process

        -- initially inputs are X and controller is reset
        TRST  <= '1';
        TMS   <= 'X';
        TDI   <= 'X';

        -- run for a few clocks
        wait for 100 ns;

	-- make mode input valid
        TMS <= '1';
        wait for 20 ns;

        -- now remove reset and start applying stimulus
        -- note that inputs change on the inactive clock edge
        --    and the output is checked just after that
        TRST <= '0';

        for  i  in  TestOutput'Range  loop

            -- get the new reset value (but don't go past end of vector)
            if  (i <= TestReset'High)  then
                -- not past end of vector
                TRST <= TestReset(i);
            else
                -- reset is 0 to pad at end to get last few bits
                TRST <= '1';
            end if;

            -- get the new mode value (but don't go past end of vector)
            if  (i <= TestMode'High)  then
                -- not past end of vector
                TMS <= TestMode(i);
            else
                -- mode is 1 to pad at end to get last few bits
                TMS <= '1';
            end if;

            -- get the new input value (but don't go past end of vector)
            if  (i <= TestInput'High)  then
                -- not past end of vector
                TDI <= TestInput(i);
            else
                -- just input X's to pad at end to get last few bits
                TDI <= 'X';
            end if;

            -- let the inputs propagate
            wait for 5 ns;

            -- check the output (from old input value)
            assert (std_match(TDO, TestOutput(i)))
                report  "Data Output Test Failure"
                severity  ERROR;

            -- now wait for the clock
            wait for 15 ns;

        end loop;

        END_SIM <= TRUE;        -- end of stimulus events
        wait;                   -- wait for simulation to end

    end process; -- end of stimulus process


    CLOCK_CLK : process

    begin

        -- this process generates a 20 ns period, 50% duty cycle clock

        -- only generate clock if still simulating

        if END_SIM = FALSE then
            TCK <= '0';
            wait for 10 ns;
        else
            wait;
        end if;

        if END_SIM = FALSE then
            TCK <= '1';
            wait for 10 ns;
        else
            wait;
        end if;

    end process;


end TB_ARCHITECTURE;
