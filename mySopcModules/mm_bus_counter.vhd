library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mm_bus_counter is
  
  port (
    -- Avalon Interface
    csi_clockreset_clk     : in  std_logic;                     -- Avalon Clk
    csi_clockreset_reset_n : in  std_logic;                     -- Avalon Reset
    avs_s1_write           : in  std_logic;                     -- Avalon wr
    avs_s1_read            : in  std_logic;                     -- Avalon rd
    avs_s1_chipselect      : in  std_logic;                     -- Avalon cs
    avs_s1_address         : in  std_logic_vector(7 downto 0);  -- Avalon address
    avs_s1_writedata       : in  std_logic_vector(15 downto 0); -- Avalon wr data
    avs_s1_readdata        : out std_logic_vector(15 downto 0); -- Avalon rd data

	 input_counter : in std_logic);

end mm_bus_counter;

architecture behaviour of mm_bus_counter is

-- Signal Declarations
  signal counter: std_logic_vector(15 downto 0);
  signal enable_counter: std_logic; 
  signal last_count1: std_logic;
  signal last_count2: std_logic;
  signal last_count3: std_logic;

begin

-- Functionality 
  
  process(csi_clockreset_clk, csi_clockreset_reset_n)
  begin
    if (csi_clockreset_reset_n = '0') then
      enable_counter <= '1';       
              
    elsif rising_edge(csi_clockreset_clk) then

		if avs_s1_chipselect = '1' then
        if avs_s1_write = '1' then
          if avs_s1_address = "00000000" then
             enable_counter <= avs_s1_writedata(0);
          end if;
        end if;
        if avs_s1_read = '1' then
          if avs_s1_address = "00000000" then
             avs_s1_readdata <= counter;
          end if;
        end if;
      end if; 
    end if;  
 end process;
  
 process(input_counter, csi_clockreset_reset_n)
  begin
    if (csi_clockreset_reset_n = '0') then
		last_count1 <= '0';
		last_count2 <= '0';
		last_count3 <= '0';
      counter <= (others => '0');
    elsif rising_edge(csi_clockreset_clk) then
	   last_count1 <= input_counter;
		last_count2 <= last_count1;
		last_count3 <= last_count2;
		if (enable_counter = '0') then
		   counter <= (others => '0');
		elsif (last_count3 = '1' and last_count2 = '0') then
			counter <= std_logic_vector(unsigned(counter) + 1);
		end if;
    end if;  
 end process;
  
end behaviour;
