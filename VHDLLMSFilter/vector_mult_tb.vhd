library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use work.vector_test.all;
use ieee.numeric_std.all;
use work.io_utils.all;

entity vector_mult_tb is
end vector_mult_tb;

architecture behavior of vector_mult_tb is
  signal dataa_tb, datab_tb, result_tb, result_mod: std_logic_vector(31 downto 0);

  constant period: time := 20 ns;
begin
   uut: entity work.vector_mult port map(dataa => dataa_tb, datab => datab_tb, result => result_tb);
   umod: entity work.vector_mult_intent port map(dataa => dataa_tb, datab => datab_tb, result => result_mod);
     
   tb: process
   
    variable fileName: string(1 to 8) := "test.txt";
    variable line: LINE;
    variable data: integer;
    variable val: signed(31 downto 0);
    variable i: integer;
    file infile: TEXT open read_mode is fileName;
   begin     
    
    file_open(infile, fileName);
  
    -- Test using input file
    i := 0;
    while not endfile(infile) loop
      readline(infile, line);
      read(line, data, 16);
      dataa_tb <= std_logic_vector(TO_SIGNED(data, 32));

      readline(infile, line);
      read(line, data, 16);
      datab_tb <= std_logic_vector(TO_SIGNED(data, 32));
      wait for period;
      
      readline(infile, line);
      read(line, data, 16);
      assert (result_tb = std_logic_vector(TO_SIGNED(data, 32))) report "unexpected result in file" 
      severity error;
      i := i + 1;
    end loop;
    
    file_close(infile);

    -- Test using model
    for i in test_vectors'range loop
      dataa_tb <= test_vectors(i).a;
      datab_tb <= test_vectors(i).b;
      wait for period;
      assert (result_tb = result_mod) report "unexpected result model" 
      severity error;
   end loop;
      
   end process;
   
end;
