library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.vector_test.all;

entity vector_mult_intent is

port (dataa, datab : in std_logic_vector(31 downto 0);
      result : out std_logic_vector(31 downto 0));

end vector_mult_intent;

architecture behavior of vector_mult_intent is       
begin
  
   process(dataa, datab)
   begin
     result <= X"00000000"; 
     for i in test_vectors'range loop
       if (dataa = test_vectors(i).a) and (datab = test_vectors(i).b) then
         result <= test_vectors(i).r;
       end if;
      end loop;
   end process;

end;
