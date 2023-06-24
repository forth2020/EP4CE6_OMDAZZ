-- ---------------------------------------------------------------------
-- @file : bench.vhd testbench for the EP4CE6 OMDAZZ Board
-- ---------------------------------------------------------------------
--
-- Last change: KS 21.06.2023 23:12:44
-- @project: microCore
-- @language: VHDL-93
-- @copyright (c): Klaus Schleisiek, All Rights Reserved.
-- @contributors:
--
-- @license: Do not use this file except in compliance with the License.
-- You may obtain a copy of the Public License at
-- https://github.com/microCore-VHDL/microCore/tree/master/documents
-- Software distributed under the License is distributed on an "AS IS"
-- basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
-- See the License for the specific language governing rights and
-- limitations under the License.
--
-- @brief: General simulation test bench for microCore with RS232 umbilical
-- interface. Following ARCHITECTURE, one out of a set of constants can be
-- set to '1' in order to test specific aspects of debugger.vhd.
-- When all of the constants are set to '0', bootload_sim.vhd will be
-- executed that has been cross-compiled from bootload_sim.fs.
-- The program memory will be initialized at the start of simulation when
-- MEM_FILE := "../software/program.mem". Program.mem will be generated by
-- the cross compiler.
--
-- Version Author   Date       Changes
--  1000     ks   14-May-2023  initial version
-- ---------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.VITAL_timing.ALL;
USE IEEE.VITAL_primitives.ALL;
USE STD.TEXTIO.ALL;

USE work.functions_pkg.ALL;
USE work.architecture_pkg.ALL;
USE work.gen_utils.ALL;

ENTITY bench IS
END bench;

ARCHITECTURE testbench OF bench IS

CONSTANT prog_len   : NATURAL := 10;    -- length of sim_boot.fs
CONSTANT progload   : STD_LOGIC := '0'; -- use sim_progload.fs   progload.do   MEM_file := ""                         37 usec
CONSTANT debug      : STD_LOGIC := '0'; -- use sim_debug.fs      debug.do      MEM_FILE := "../software/program.mem"  38 usec
CONSTANT handshake  : STD_LOGIC := '0'; -- use sim_handshake.fs  handshake.do  MEM_FILE := "../software/program.mem"  60 usec
CONSTANT upload     : STD_LOGIC := '0'; -- use sim_upload.fs     upload.do     MEM_FILE := "../software/program.mem"  35 usec
CONSTANT download   : STD_LOGIC := '0'; -- use sim_download.fs   download.do   MEM_FILE := "../software/program.mem"  45 usec
CONSTANT break      : STD_LOGIC := '0'; -- use sim_break.fs      break.do      MEM_FILE := "../software/program.mem" 210 usec

COMPONENT fpga PORT (                        -- pins
   reset_n     : IN    STD_LOGIC;             --  25
   clock       : IN    STD_LOGIC;             --  23  external clock input
-- Demoboard specific pins
   keys_n      : IN    UNSIGNED(3 DOWNTO 0);  --  91, 90, 89, 88 <= used as interrupt input during simulation
   beep        : OUT   STD_LOGIC;             -- 110
   leds_n      : OUT   UNSIGNED(3 DOWNTO 0);  --  84, 85, 86, 87
-- temp sensor
   scl         : OUT   STD_LOGIC;             -- 112
   sda         : INOUT STD_LOGIC;             -- 113
-- serial E2prom
   i2c_scl     : OUT   STD_LOGIC;             --  99
   i2c_sda     : INOUT STD_LOGIC;             --  98
-- IR es ist mir unklar, ob das ein Sender oder ein Empf�nger ist, deshal erstmal auskommentiert
--   IR          : ????? STD_LOGIC;             -- 100
-- VGA
--   vga_hsync   : OUT   STD_LOGIC;             -- 101 Pin 101 can not be used!
   vga_vsync   : OUT   STD_LOGIC;             -- 103
   vga_bgr     : OUT   UNSIGNED(2 DOWNTO 0);  -- 104, 105, 106
-- LCD
   lcd_rs      : OUT   STD_LOGIC;             -- 141
   lcd_rw      : OUT   STD_LOGIC;             -- 138
   lcd_e       : OUT   STD_LOGIC;             -- 143
   lcd_data    : OUT   UNSIGNED(7 DOWNTO 0);  --  11, 7, 10, 2, 3, 144, 1, 142
-- 7-Segment
   dig         : OUT   UNSIGNED(3 DOWNTO 0);  -- 137, 136, 135, 133
   seg         : OUT   UNSIGNED(7 DOWNTO 0);  -- 127, 124, 126, 132, 129, 125, 121, 128
-- SDRAM
   sd_clk      : OUT   STD_LOGIC;             -- 43
   sd_cke      : OUT   STD_LOGIC;             -- 58
   sd_cs_n     : OUT   STD_LOGIC;             -- 72
   sd_we_n     : OUT   STD_LOGIC;             -- 69
   sd_a        : OUT   UNSIGNED(11 DOWNTO 0); -- 59, 75, 60, 64, 65, 66, 67, 68, 83, 80, 77, 76
   sd_ba       : OUT   UNSIGNED( 1 DOWNTO 0); -- 74, 73
   sd_ras_n    : OUT   STD_LOGIC;             -- 71
   sd_cas_n    : OUT   STD_LOGIC;             -- 70
   sd_ldqm     : OUT   STD_LOGIC;             -- 42
   sd_udqm     : OUT   STD_LOGIC;             -- 55
   sd_dq       : INOUT UNSIGNED(15 DOWNTO 0); -- 44, 46, 49, 50, 51, 52, 53, 54, 39, 38, 34, 33, 32, 31, 30, 28
-- umbilical uart for debugging
   dsu_rxd     : IN    STD_LOGIC;             -- 115  UART receive
   dsu_txd     : OUT   STD_LOGIC              -- 114  UART transmit
); END COMPONENT fpga;

SIGNAL reset_n    : STD_LOGIC;
SIGNAL xtal       : STD_LOGIC;
SIGNAL int_n      : STD_LOGIC;
SIGNAL bitout     : STD_LOGIC;

COMPONENT program_rom PORT (
   addr  : IN    program_addr;
   data  : OUT   inst_bus
); END COMPONENT;

SIGNAL debug_data   : inst_bus;
SIGNAL debug_addr   : program_addr;

COMPONENT mt48lc4m16 GENERIC (
    -- tipd delays: interconnect path delays
    tipd_BA0        : VitalDelayType01 := VitalZeroDelay01;
    tipd_BA1        : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQML       : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQMH       : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ0        : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ1        : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ2        : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ3        : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ4        : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ5        : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ6        : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ7        : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ8        : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ9        : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ10       : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ11       : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ12       : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ13       : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ14       : VitalDelayType01 := VitalZeroDelay01;
    tipd_DQ15       : VitalDelayType01 := VitalZeroDelay01;
    tipd_CLK        : VitalDelayType01 := VitalZeroDelay01;
    tipd_CKE        : VitalDelayType01 := VitalZeroDelay01;
    tipd_A0         : VitalDelayType01 := VitalZeroDelay01;
    tipd_A1         : VitalDelayType01 := VitalZeroDelay01;
    tipd_A2         : VitalDelayType01 := VitalZeroDelay01;
    tipd_A3         : VitalDelayType01 := VitalZeroDelay01;
    tipd_A4         : VitalDelayType01 := VitalZeroDelay01;
    tipd_A5         : VitalDelayType01 := VitalZeroDelay01;
    tipd_A6         : VitalDelayType01 := VitalZeroDelay01;
    tipd_A7         : VitalDelayType01 := VitalZeroDelay01;
    tipd_A8         : VitalDelayType01 := VitalZeroDelay01;
    tipd_A9         : VitalDelayType01 := VitalZeroDelay01;
    tipd_A10        : VitalDelayType01 := VitalZeroDelay01;
    tipd_A11        : VitalDelayType01 := VitalZeroDelay01;
    tipd_WENeg      : VitalDelayType01 := VitalZeroDelay01;
    tipd_RASNeg     : VitalDelayType01 := VitalZeroDelay01;
    tipd_CSNeg      : VitalDelayType01 := VitalZeroDelay01;
    tipd_CASNeg     : VitalDelayType01 := VitalZeroDelay01;
    -- tpd delays  tAC tHZ
    tpd_CLK_DQ0              : VitalDelayType01Z := UnitDelay01Z; --CL2
    tpd_CLK_DQ1              : VitalDelayType01Z := UnitDelay01Z; --CL3
    -- tpw values: pulse widths
    tpw_CLK_posedge          : VitalDelayType    := UnitDelay; --tCH
    tpw_CLK_negedge          : VitalDelayType    := UnitDelay; --tCL
    -- tsetup values: setup times
    tsetup_A0_CLK            : VitalDelayType    := UnitDelay; --tAS
    tsetup_DQ0_CLK           : VitalDelayType    := UnitDelay; --tDS
    tsetup_CKE_CLK           : VitalDelayType    := UnitDelay; --tCKS
    tsetup_CSNeg_CLK         : VitalDelayType    := UnitDelay; --tCMS
    -- thold values: hold times
    thold_A0_CLK             : VitalDelayType    := UnitDelay; --tAH
    thold_DQ0_CLK            : VitalDelayType    := UnitDelay; --tDH
    thold_CKE_CLK            : VitalDelayType    := UnitDelay; --tCKH
    thold_CSNeg_CLK          : VitalDelayType    := UnitDelay; --tCMH
    -- tperiod_min: minimum clock period = 1/max freq tCK
    tperiod_CLK              : VitalDelayType    := UnitDelay; --CL2
    tperiod_CLK_CAS3             : VitalDelayType    := UnitDelay; --CL3
    -- tdevice values: values for internal delays
    tdevice_REF              : VitalDelayType    := 15_625 ns;
    tdevice_TRC              : VitalDelayType    := 66 ns;
    tdevice_TRCD             : VitalDelayType    := 20 ns;
    tdevice_TRP              : VitalDelayType    := 20 ns;
    tdevice_TRCAR            : VitalDelayType    := 66 ns;
    tdevice_TRAS             : VitalDelayType01  := (42 ns, 120_000 ns);
    -- tpowerup: Power up initialization time. Data sheets say 100 us.
    -- May be shortened during simulation debug.
    tpowerup        : TIME      := 100 us;
    -- generic control parameters
    InstancePath    : STRING    := DefaultInstancePath;
    TimingChecksOn  : BOOLEAN   := DefaultTimingChecks;
    MsgOn           : BOOLEAN   := DefaultMsgOn;
    XOn             : BOOLEAN   := DefaultXon;
    SeverityMode    : SEVERITY_LEVEL := WARNING;
    -- memory file to be loaded
    mem_file_name   : STRING    := "none";
    -- preload variable
    UserPreload     : BOOLEAN   := FALSE;
    -- For FMF SDF technology file usage
    TimingModel     : STRING    := DefaultTimingModel
); PORT (
    BA0       : IN    STD_LOGIC;
    BA1       : IN    STD_LOGIC;
    DQML      : IN    STD_LOGIC;
    DQMH      : IN    STD_LOGIC;
    DQ0       : INOUT STD_LOGIC;
    DQ1       : INOUT STD_LOGIC;
    DQ2       : INOUT STD_LOGIC;
    DQ3       : INOUT STD_LOGIC;
    DQ4       : INOUT STD_LOGIC;
    DQ5       : INOUT STD_LOGIC;
    DQ6       : INOUT STD_LOGIC;
    DQ7       : INOUT STD_LOGIC;
    DQ8       : INOUT STD_LOGIC;
    DQ9       : INOUT STD_LOGIC;
    DQ10      : INOUT STD_LOGIC;
    DQ11      : INOUT STD_LOGIC;
    DQ12      : INOUT STD_LOGIC;
    DQ13      : INOUT STD_LOGIC;
    DQ14      : INOUT STD_LOGIC;
    DQ15      : INOUT STD_LOGIC;
    CLK       : IN    STD_LOGIC;
    CKE       : IN    STD_LOGIC;
    A0        : IN    STD_LOGIC;
    A1        : IN    STD_LOGIC;
    A2        : IN    STD_LOGIC;
    A3        : IN    STD_LOGIC;
    A4        : IN    STD_LOGIC;
    A5        : IN    STD_LOGIC;
    A6        : IN    STD_LOGIC;
    A7        : IN    STD_LOGIC;
    A8        : IN    STD_LOGIC;
    A9        : IN    STD_LOGIC;
    A10       : IN    STD_LOGIC;
    A11       : IN    STD_LOGIC;
    WENeg     : IN    STD_LOGIC;
    RASNeg    : IN    STD_LOGIC;
    CSNeg     : IN    STD_LOGIC;
    CASNeg    : IN    STD_LOGIC
); END COMPONENT mt48lc4m16;

SIGNAL sd_clk       : STD_LOGIC;
SIGNAL sd_cke       : STD_LOGIC;
SIGNAL sd_cs_n      : STD_LOGIC;
SIGNAL sd_we_n      : STD_LOGIC;
SIGNAL sd_a         : UNSIGNED(11 DOWNTO 0);
SIGNAL sd_ba        : UNSIGNED( 1 DOWNTO 0);
SIGNAL sd_ras_n     : STD_LOGIC;
SIGNAL sd_cas_n     : STD_LOGIC;
SIGNAL sd_ldqm      : STD_LOGIC;
SIGNAL sd_udqm      : STD_LOGIC;
SIGNAL sd_dq        : UNSIGNED(15 DOWNTO 0);

SIGNAL host_rxd     : STD_LOGIC;
SIGNAL host_txd     : STD_LOGIC;
SIGNAL tx_buf       : byte;
SIGNAL send_byte    : STD_LOGIC;
SIGNAL sending      : STD_LOGIC;
SIGNAL downloading  : STD_LOGIC;
SIGNAL uploading    : STD_LOGIC;
SIGNAL host_reg     : UNSIGNED((octetts*8)-1 DOWNTO 0);
SIGNAL out_buf      : UNSIGNED((octetts*8)-1 DOWNTO 0);
SIGNAL host_buf     : byte;
SIGNAL host_full    : STD_LOGIC; -- umbilical received a data word
SIGNAL host_ack     : STD_LOGIC; -- umbilical received an ack

CONSTANT xtal_cycle : TIME := (1000000000 / xtal_frequency) * 1 ns;
CONSTANT cycle      : TIME := (1000000000 / clk_frequency) * 1 ns;
CONSTANT baud       : TIME := (cycle*clk_frequency)/umbilical_rate;
-- CONSTANT int_time   : TIME := 114260 ns + 8 * 40 ns; -- sim_handshake test
CONSTANT int_time   : TIME := 26500 ns + 0 * 40 ns;

-- Demoboard specific signals

SIGNAL leds_n       : UNSIGNED(3 DOWNTO 0);
SIGNAL keys_n       : UNSIGNED(3 DOWNTO 0);

BEGIN

-- ---------------------------------------------------------------------
-- demoboard pins
-- ---------------------------------------------------------------------

keys_n(0)          <= int_n;
keys_n(3 DOWNTO 1) <= (OTHERS => '0');

-- ---------------------------------------------------------------------
-- Test vector generation
-- ---------------------------------------------------------------------

int_n  <= '1', '0' AFTER int_time, '1' AFTER int_time + 600 ns;

bitout <= '1' WHEN  leds_n(0) = '0' OR (debug = '1' AND host_reg = 16#4002#)  ELSE '0';

-- ---------------------------------------------------------------------
-- Communicating with the uCore debugger via umbilical
-- ---------------------------------------------------------------------

make_initROM: IF  prog_len /= 0  GENERATE
   debug_mem: program_rom PORT MAP(debug_addr, debug_data);
END GENERATE make_initROM;

umbilical_proc: PROCESS

	VARIABLE text  : line;

   PROCEDURE tx_byte (number : IN byte) IS
   BEGIN
     WHILE  sending = '1' LOOP WAIT FOR cycle; END LOOP;
     send_byte <= '1';
     tx_buf <= number;
     WAIT UNTIL sending = '1';
     send_byte <= '0';
     tx_buf <= (OTHERS => 'Z');
   END tx_byte;

   PROCEDURE tx_word (number : IN data_bus) IS
   BEGIN
     out_buf <= (OTHERS => '0');
     out_buf(data_width-1 DOWNTO 0) <= number;
     FOR  i IN octetts DOWNTO 1  LOOP
        tx_byte(out_buf(i*8-1 DOWNTO (i-1)*8));
     END LOOP;
   END tx_word;

   PROCEDURE wait_ack IS
   BEGIN
      WHILE NOT (host_full = '1' AND host_buf = mark_ack) LOOP  WAIT FOR cycle;  END LOOP;
      WAIT UNTIL host_full = '0';
   END wait_ack;

   PROCEDURE rx_word (number : IN data_bus) IS
   BEGIN
      WHILE NOT (host_full = '1' AND host_reg(data_width-1 DOWNTO 0) = number)  LOOP  WAIT FOR cycle;  END LOOP;
      WAIT UNTIL host_full = '0';
   END rx_word;

   PROCEDURE rx_debug (number : IN data_bus) IS
   BEGIN
      WHILE NOT (host_full = '1' AND host_reg(data_width-1 DOWNTO 0) = number)  LOOP  WAIT FOR cycle;  END LOOP;
      host_ack <= '1';
      WAIT UNTIL host_full = '0';
      WAIT FOR cycle;
      host_ack <= '0';
   END rx_debug;

   PROCEDURE rx_byte (number : IN byte) IS
   BEGIN
      WHILE NOT (host_full = '1' AND host_reg(7 DOWNTO 0) = number)  LOOP  WAIT FOR cycle;  END LOOP;
      WAIT FOR cycle;
   END rx_byte;

   PROCEDURE tx_debug ( number : IN data_bus) IS
   BEGIN
      tx_byte(mark_debug);
      tx_word(number);
      wait_ack;
   END tx_debug;

BEGIN
--   switch_n     <= (OTHERS => '0');
   reset_n      <= '0';
   send_byte    <= '0';
   tx_buf       <= "ZZZZZZZZ";
   host_ack     <= '0';
   downloading  <= '0';
   uploading    <= '0';
   debug_addr   <= (OTHERS => '0');
   WAIT FOR 1000 ns;
   reset_n      <= '1';

   WAIT FOR 20 us;

   IF  prog_len /= 0 AND progload = '1'  THEN
		text := NEW string'("starting progload test ...");
      writeline(output, text);

-- send a string of NAK's, just in case
      FOR  i IN octetts DOWNTO 1  LOOP
         tx_byte(mark_nack);
      END LOOP;

-- load memory with reset
      tx_byte(mark_reset);  -- $CC
      tx_word(to_unsigned(0, data_width));        -- start address
      tx_word(to_unsigned(prog_len, data_width)); -- length
      FOR  i IN 0 TO  prog_len-1  LOOP         -- transfer memory image
         debug_addr <= to_unsigned(i, prog_addr_width);
         tx_byte(debug_data);
      END LOOP;
      wait_ack;
		text := NEW string'("progload test ok ");
      writeline(output, text);
      WAIT;
   END IF;

   IF  handshake = '1'  THEN -- debugger handshake see: monitor.fs
		text := NEW string'("starting handshake test ...");
      writeline(output, text);
      tx_debug(to_unsigned(0, data_width));
      rx_debug(slice('1', data_width));
      tx_debug(to_unsigned(16#3F5#, data_width));
      rx_debug(to_unsigned(16#305#, data_width));
      tx_debug(to_unsigned(0, data_width));
-- entering monitor loop
      rx_debug (to_unsigned(0, data_width)); -- now monitor waits for executable address

-- transfer "#c-bitout Ctrl-reg ! EXIT" to addr $200 and execute it
      tx_byte(mark_start);
      tx_word(to_unsigned(16#200#, data_width)); -- addr
      tx_word(to_unsigned( 6, data_width));      -- length
      tx_byte(to_unsigned(exp2(c_bitout) + 128, 8));
      tx_byte(op_NOOP);
      tx_byte(unsigned(to_signed(CTRL_REG, 8)));
      tx_byte(op_STORE);
      tx_byte(op_DROP);
      tx_byte(op_EXIT);
      wait_ack; -- now uCore waits for an execution address
      tx_debug(to_unsigned(16#200#, data_width)); -- execute it
      rx_debug (to_unsigned(0, data_width));
      tx_byte(mark_ack);
		text := NEW string'("handshake test ok ");
      writeline(output, text);
      WAIT;
   END IF;

   IF  debug = '1'  THEN
		text := NEW string'("starting debug register test ...");
      writeline(output, text);
      tx_debug(to_unsigned(16#8001#, data_width));
      rx_debug(to_unsigned(16#8001#, data_width));
      tx_debug(to_unsigned(16#4002#, data_width));
      rx_debug(to_unsigned(16#4002#, data_width));
      tx_byte(mark_ack);
      WHILE  sending = '1'  LOOP WAIT FOR baud/2;  END LOOP;
		text := NEW string'("debug register test ok ");
      writeline(output, text);
      WAIT;
   END IF;

   IF  upload = '1'  THEN  -- upload to data memory
		text := NEW string'("starting upload test ...");
      writeline(output, text);
      WAIT FOR 0 * 40 ns;
      uploading <= '1';
      tx_byte(mark_upload);
      IF  byte_addr_width = 0  THEN            -- cell addressing
         tx_word(to_unsigned( 8, data_width)); -- start address internal memory
         tx_word(to_unsigned( 4, data_width)); -- length
         FOR i IN 1 TO 4 LOOP
            tx_word(to_unsigned((16+i), data_width));
         END LOOP;
      ELSE                                     -- byte addressing
         tx_word(to_unsigned( 8 * bytes_per_cell, data_width)); -- start address internal memory
         tx_word(to_unsigned( 6, data_width)); -- length
         FOR i IN 1 TO 6 LOOP
            tx_byte(to_unsigned((16+i), 8));
         END LOOP;
      END IF;
      wait_ack;
      uploading <= '0';
      WAIT FOR cycle;
      IF  WITH_EXTMEM  THEN
         uploading <= '1';
         tx_byte(mark_upload);
         tx_word(to_unsigned(exp2(cache_addr_width), data_width)); -- start address external memory
         tx_word(to_unsigned( 4, data_width));                     -- length
         FOR i IN 5 TO 8 LOOP
            tx_word(to_unsigned((32+i), data_width));
         END LOOP;
         wait_ack;
         uploading <= '0';
      END IF;
      WHILE  bitout = '0'  LOOP WAIT FOR cycle;  END LOOP;
		text := NEW string'("upload test ok ");
      writeline(output, text);
      WAIT;
   END IF;

   IF  download = '1'  THEN  -- download from data memory
		text := NEW string'("starting download test ...");
      writeline(output, text);
      WAIT FOR 1200 ns + 3 * 40 ns;
      downloading <= '1';
      tx_byte(mark_download);
      tx_word(to_unsigned(bytes_per_cell, data_width));     -- start address internal memory
      tx_word(to_unsigned(8, data_width)); -- length
      IF  byte_addr_width = 0  THEN
         rx_word(to_unsigned(16#2211#, data_width));
         rx_word(to_unsigned(16#2211#, data_width));
         rx_word(to_unsigned(16#2211#, data_width));
         rx_word(to_unsigned(16#2211#, data_width));
         rx_word(to_unsigned(16#2211#, data_width));
         rx_word(to_unsigned(16#2211#, data_width));
         rx_word(to_unsigned(16#2211#, data_width));
         rx_word(to_unsigned(16#2211#, data_width));
         IF  WITH_EXTMEM  THEN
            tx_byte(mark_ack);
            WHILE  sending = '1'  LOOP WAIT FOR baud/2;  END LOOP;
            downloading <= '0';
            WAIT FOR baud;
            downloading <= '1';
            tx_byte(mark_download);
            tx_word(to_unsigned(exp2(cache_addr_width), data_width)); -- start address external memory
            tx_word(to_unsigned(2, data_width)); -- length
            rx_word(to_unsigned(16#6655#, data_width));
            rx_word(to_unsigned(16#8877#, data_width));
         END IF;
      ELSE
         rx_byte(to_unsigned(16#11#, 8));
         rx_byte(to_unsigned(16#22#, 8));
         rx_byte(to_unsigned(16#00#, 8));
         rx_byte(to_unsigned(16#00#, 8));
         rx_byte(to_unsigned(16#11#, 8));
         rx_byte(to_unsigned(16#22#, 8));
         rx_byte(to_unsigned(16#00#, 8));
         rx_byte(to_unsigned(16#00#, 8));
      END IF;
      tx_byte(mark_ack);
      WHILE  sending = '1'  LOOP WAIT FOR baud/2;  END LOOP;
      downloading <= '0';
		text := NEW string'("download test ok ");
      IF  bitout = '0'  THEN
         writeline(output, text);
      END IF;
      WAIT;
   END IF;

   IF  break = '1'  THEN -- multitasking: put terminal to sleep
		text := NEW string'("starting break test ...");
      writeline(output, text);
      WAIT FOR 80 us;
      tx_byte(mark_break);  -- put terminal to sleep
      WAIT FOR 80 us;
      tx_byte(mark_nbreak); -- wake terminal again
      WHILE  bitout = '0'  LOOP WAIT FOR cycle;  END LOOP;
		text := NEW string'("break test ok ");
      writeline(output, text);
      WAIT;
   END IF;

-- coretest
   text := NEW string'("starting core test ...");
   writeline(output, text);
   WAIT UNTIL bitout = '1';
   WAIT UNTIL bitout = '0';
   WAIT UNTIL bitout = '1';
   ASSERT false REPORT "core test ok" SEVERITY note;
   WAIT;

END PROCESS umbilical_proc;

to_target_proc: PROCESS
   VARIABLE number : byte := (OTHERS => 'Z');
BEGIN
   host_txd <= '1';
   sending <= '0';
   WAIT FOR 980 ns;
   LOOP
      WHILE  host_ack = '0' AND send_byte = '0'  LOOP  WAIT FOR cycle; END LOOP;
      sending <= '1';
      IF  host_ack = '1'  THEN
         number := mark_ack;
      ELSE
         number := tx_buf;
      END IF;
      host_txd <= '0';  -- start bit
      WAIT FOR baud;
      FOR  i IN 0 TO 7  LOOP
        host_txd <= number(i);
        WAIT FOR baud;
      END LOOP;
      host_txd <= '1';  -- stop bit
      sending <= '0';
      WAIT FOR baud;   -- wait for full stop bit
   END LOOP;
END PROCESS to_target_proc ;

from_target_proc : PROCESS

   PROCEDURE rx_uart IS
   BEGIN
     WHILE  host_rxd /= '0'  LOOP WAIT FOR cycle/2; END LOOP;
     WAIT FOR baud/2;
     FOR  i IN 0 TO 7  LOOP
        WAIT FOR baud;
        host_buf(i) <= host_rxd;
     END LOOP;
     WAIT FOR baud/2;
   END rx_uart;

BEGIN
   host_full <= '0';
   host_reg <= (OTHERS => '1');
   WAIT FOR 1 us;
   LOOP
      WAIT FOR cycle;
      host_full <= '0';
      WHILE  host_rxd = '1'  LOOP WAIT FOR cycle;  END LOOP;
      IF  downloading = '1'  THEN
         IF  byte_addr_width = 0  THEN
            FOR i IN octetts-1 DOWNTO 0 LOOP
               rx_uart;
               host_reg <= host_reg(host_reg'high-8 DOWNTO 0) & host_buf;
            END LOOP;
         ELSE
            rx_uart;
            host_reg <= resize(host_buf, host_reg'length);
         END IF;
         host_full <= '1';
      ELSE
         rx_uart;
         IF  host_buf = mark_ack  THEN
            host_full <= '1';
         ELSIF  host_buf = mark_debug  THEN
            FOR i IN octetts-1 DOWNTO 0 LOOP
               rx_uart;
               host_reg <= host_reg(host_reg'high-8 DOWNTO 0) & host_buf;
            END LOOP;
            host_full <= '1';
         END IF;
      END IF;
   END LOOP;

END PROCESS from_target_proc ;

-- ---------------------------------------------------------------------
-- The clock oscillator
-- ---------------------------------------------------------------------

xtal_clock: PROCESS
BEGIN
  xtal <= '0';
  WAIT FOR 500 ns;
  LOOP
    xtal <= '1';
    WAIT FOR cycle/2;
    xtal <= '0';
    WAIT FOR cycle/2;
  END LOOP;
END PROCESS xtal_clock;

-- ---------------------------------------------------------------------
-- external SDRAM
-- ---------------------------------------------------------------------

SDRAM: mt48lc4m16 PORT MAP (
    BA0      => sd_ba(0),
    BA1      => sd_ba(1),
    DQML     => sd_ldqm,
    DQMH     => sd_udqm,
    DQ0      => std_logic(sd_dq( 0)),
    DQ1      => std_logic(sd_dq( 1)),
    DQ2      => std_logic(sd_dq( 2)),
    DQ3      => std_logic(sd_dq( 3)),
    DQ4      => std_logic(sd_dq( 4)),
    DQ5      => std_logic(sd_dq( 5)),
    DQ6      => std_logic(sd_dq( 6)),
    DQ7      => std_logic(sd_dq( 7)),
    DQ8      => std_logic(sd_dq( 8)),
    DQ9      => std_logic(sd_dq( 9)),
    DQ10     => std_logic(sd_dq(10)),
    DQ11     => std_logic(sd_dq(11)),
    DQ12     => std_logic(sd_dq(12)),
    DQ13     => std_logic(sd_dq(13)),
    DQ14     => std_logic(sd_dq(14)),
    DQ15     => std_logic(sd_dq(15)),
    CLK      => sd_clk,
    CKE      => sd_cke,
    A0       => std_logic(sd_a( 0)),
    A1       => std_logic(sd_a( 1)),
    A2       => std_logic(sd_a( 2)),
    A3       => std_logic(sd_a( 3)),
    A4       => std_logic(sd_a( 4)),
    A5       => std_logic(sd_a( 5)),
    A6       => std_logic(sd_a( 6)),
    A7       => std_logic(sd_a( 7)),
    A8       => std_logic(sd_a( 8)),
    A9       => std_logic(sd_a( 9)),
    A10      => std_logic(sd_a(10)),
    A11      => std_logic(sd_a(11)),
    WENeg    => sd_we_n,
    RASNeg   => sd_ras_n,
    CSNeg    => sd_cs_n,
    CASNeg   => sd_cas_n
);

-- ---------------------------------------------------------------------
-- uCore FPGA
-- ---------------------------------------------------------------------

myFPGA: fpga PORT MAP (
   reset_n    => reset_n,
   clock      => xtal,
-- Demoboard specific pins
   keys_n     => keys_n,
--   beep       => OUT   STD_LOGIC;
   leds_n     => leds_n,
-- temp sensor
--   scl        => OUT   STD_LOGIC;
--   sda        => INOUT STD_LOGIC;
-- serial E2prom
--   i2c_scl    => OUT   STD_LOGIC;
--   i2c_sda    => INOUT STD_LOGIC;
-- IR es ist mir unklar, ob das ein Sender oder ein Empf�nger ist, deshal erstmal auskommentiert
--   IR         => ????? STD_LOGIC;
-- VGA
--   vga_hsync  => OUT   STD_LOGIC;
--   vga_vsync  => OUT   STD_LOGIC;
--   vga_bgr    => OUT   UNSIGNED(2 DOWNTO 0);
-- LCD
--   lcd_rs     => OUT   STD_LOGIC;
--   lcd_rw     => OUT   STD_LOGIC;
--   lcd_e      => OUT   STD_LOGIC;
--   lcd_data   => OUT   UNSIGNED(7 DOWNTO 0);
-- 7-Segment
--   dig        => OUT   UNSIGNED(3 DOWNTO 0);
--   seg        => OUT   UNSIGNED(7 DOWNTO 0);
-- SDRAM
   sd_clk     => sd_clk,
   sd_cke     => sd_cke,
   sd_cs_n    => sd_cs_n,
   sd_we_n    => sd_we_n,
   sd_a       => sd_a,
   sd_ba      => sd_ba,
   sd_ras_n   => sd_ras_n,
   sd_cas_n   => sd_cas_n,
   sd_ldqm    => sd_ldqm,
   sd_udqm    => sd_udqm,
   sd_dq      => sd_dq,
-- umbilical port for debugging
   dsu_rxd    => host_txd, -- host -> target
   dsu_txd    => host_rxd  -- target -> host
);

END testbench;
