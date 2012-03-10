library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

entity MyDeMultiplexer_tb is
end;

architecture bench of MyDeMultiplexer_tb is

  component MyDeMultiplexer
    port (
      clk                 : in  std_logic;
      reset_n             : in  std_logic;
      ast_sink_data       : in  std_logic_vector(24-1 downto 0);
      ast_sink_valid      : in  std_logic;
      ast_sink_channel    : in  std_logic;
      ast_source1_valid          : out   std_logic;
      ast_source1_data           : out   std_logic_vector(24-1 downto 0);
      ast_source2_valid          : out   std_logic;
      ast_source2_data           : out   std_logic_vector(24-1 downto 0)); 
  end component;

  signal clk: std_logic;
  signal reset_n: std_logic;
  signal ast_sink_data: std_logic_vector(24-1 downto 0);
  signal ast_sink_valid: std_logic;
  signal ast_sink_channel: std_logic;
  signal ast_source1_valid: std_logic;
  signal ast_source1_data: std_logic_vector(24-1 downto 0);
  signal ast_source2_valid: std_logic;
  signal ast_source2_data: std_logic_vector(24-1 downto 0);

  constant clock_period: time := 20 ns;
  signal stop_the_clock: boolean;

begin

  -- Insert values for generic parameters !!
  uut: MyDeMultiplexer
                          port map ( clk               => clk,
                                     reset_n           => reset_n,
                                     ast_sink_data     => ast_sink_data,
                                     ast_sink_valid    => ast_sink_valid,
                                     ast_sink_channel  => ast_sink_channel,
                                     ast_source1_valid => ast_source1_valid,
                                     ast_source1_data  => ast_source1_data,
                                     ast_source2_valid => ast_source2_valid,
                                     ast_source2_data  => ast_source2_data );

  stimulus: process
  begin
  
    -- Put initialisation code here
    ast_sink_data <= X"000000";
    ast_sink_valid <= '0';
    reset_n <= '0';
    wait for 5 ns;
    reset_n <= '1';
    wait for 5 ns;

    wait until clk = '1';    
    ast_sink_data <= X"153000";
    ast_sink_valid <= '1';
    ast_sink_channel <= '1';
    wait until clk = '1';    
    ast_sink_valid <= '0';
    wait for 25 ns;
    wait until clk = '1';
    ast_sink_data <= X"100001";
    ast_sink_valid <= '1';
    ast_sink_channel <= '0';
    wait until clk = '1';    
    ast_sink_valid <= '0';
    wait for 25 ns;  
    wait until clk = '1';    
    ast_sink_data <= X"111111";
    ast_sink_valid <= '1';
    ast_sink_channel <= '1';
    wait until clk = '1';    
    ast_sink_valid <= '0';
    wait for 50 ns;
    wait until clk = '1';    
    ast_sink_data <= X"222222";
    ast_sink_valid <= '1';
    ast_sink_channel <= '0';
    wait until clk = '1';    
    ast_sink_valid <= '0';
    wait for 50 ns;          
    -- Put test bench stimulus code here

    stop_the_clock <= true;
    wait;
  end process;

  clocking: process
  begin
    while not stop_the_clock loop
      clk <= '0', '1' after clock_period / 2;
      wait for clock_period;
    end loop;
    wait;
  end process;

end;

configuration cfg_MyDeMultiplexer_tb of MyDeMultiplexer_tb is
  for bench
    for uut: MyDeMultiplexer
      -- Default configuration
    end for;
  end for;
end cfg_MyDeMultiplexer_tb;

configuration cfg_MyDeMultiplexer_tb_code2 of MyDeMultiplexer_tb is
  for bench
    for uut: MyDeMultiplexer
      use entity work.MyDeMultiplexer(code2);
    end for;
  end for;
end cfg_MyDeMultiplexer_tb_code2;

