--
-- Program memory ROM implemented using a case statement.
-- Its content was generated by the microCore cross compiler.
-- It will be statically synthesized into the design as cold bootrom.

LIBRARY IEEE;
USE     IEEE.STD_LOGIC_1164.ALL;
USE     IEEE.NUMERIC_STD.ALL;
USE     work.architecture_pkg.ALL;

ENTITY boot_rom IS PORT (
   addr  : IN   boot_addr_bus;
   data  : OUT  inst_bus
); END boot_rom;

ARCHITECTURE sim_model OF boot_rom IS

SUBTYPE rom_address IS NATURAL RANGE 0 TO 2**boot_addr_width-1;

FUNCTION program(addr : rom_address) RETURN UNSIGNED IS
BEGIN
   CASE addr IS
      WHEN 16#0000# => RETURN "10100010";
      WHEN 16#0001# => RETURN "00001001";
      WHEN 16#0002# => RETURN "10000011";
      WHEN 16#0003# => RETURN "11110100";
      WHEN 16#0004# => RETURN "00000000";
      WHEN 16#0005# => RETURN "11111000";
      WHEN 16#0006# => RETURN "01010000";
      WHEN 16#0007# => RETURN "00001000";
      WHEN 16#0008# => RETURN "00101000";
      WHEN 16#0009# => RETURN "00010000";
      WHEN 16#000A# => RETURN "00011011";
      WHEN 16#000B# => RETURN "11111100";
      WHEN 16#000C# => RETURN "00001010";
      WHEN 16#000D# => RETURN "00001000";
      WHEN 16#000E# => RETURN "01011101";
      WHEN 16#000F# => RETURN "00010000";
      WHEN 16#0010# => RETURN "00011000";
      WHEN 16#0011# => RETURN "11110111";
      WHEN 16#0012# => RETURN "01001000";
      WHEN 16#0013# => RETURN "00001000";
      WHEN 16#0014# => RETURN "00010000";
      WHEN 16#0015# => RETURN "00101000";
      WHEN 16#0016# => RETURN "00010000";
      WHEN 16#0017# => RETURN "10001000";
      WHEN 16#0018# => RETURN "00000011";
      WHEN 16#0019# => RETURN "00001100";
      WHEN 16#001A# => RETURN "10000011";
      WHEN 16#001B# => RETURN "00001010";
      WHEN 16#001C# => RETURN "00001000";
      WHEN 16#001D# => RETURN "10000001";
      WHEN 16#001E# => RETURN "00000000";
      WHEN 16#001F# => RETURN "00010000";
      WHEN 16#0020# => RETURN "11110111";
      WHEN 16#0021# => RETURN "01001000";
      WHEN 16#0022# => RETURN "00001000";
      WHEN 16#0023# => RETURN "01011101";
      WHEN 16#0024# => RETURN "10000001";
      WHEN 16#0025# => RETURN "00000000";
      WHEN 16#0026# => RETURN "11100111";
      WHEN 16#0027# => RETURN "01000110";
      WHEN 16#0028# => RETURN "11011000";
      WHEN 16#0029# => RETURN "01000110";
      WHEN 16#002A# => RETURN "11111010";
      WHEN 16#002B# => RETURN "00001001";
      WHEN 16#002C# => RETURN "01011101";
      WHEN OTHERS   => RETURN "--------";
   END CASE;
END program;

BEGIN

data <= program(to_integer(addr));

END sim_model;