library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

entity audio_process_tb_rune is
    generic (audioWidth : natural := 24);
end;

architecture bench of audio_process_tb_rune is

  component audio_process2
    generic (audioWidth : natural := 24);
    port (
      csi_AudioClk12MHz_clk 		  : in  std_logic;
      csi_AudioClk12MHz_reset_n : in  std_logic;
      coe_AudioIn_export       	: in  std_logic_vector(audioWidth-1 downto 0);
      coe_AudioOut_export      	: out std_logic_vector(audioWidth-1 downto 0);
      coe_AudioSync_export     	: in  std_logic;
      csi_clockreset_clk     		 : in    std_logic;
      csi_clockreset_reset_n 		 : in    std_logic;
      avs_s1_write           		 : in    std_logic;
      avs_s1_read            		 : in    std_logic;
      avs_s1_chipselect      		 : in    std_logic;
      avs_s1_address         		 : in    std_logic_vector(7 downto 0);
      avs_s1_writedata       		 : in    std_logic_vector(15 downto 0);
      avs_s1_readdata        		 : out   std_logic_vector(15 downto 0);
      ast_source_valid          : out   std_logic;
      ast_source_data           : out   std_logic_vector(23 downto 0);
      ast_source_channel        : out   std_logic_vector(2  downto 0);
      ast_sink_valid            : in   std_logic;
      ast_sink_data             : in   std_logic_vector(23 downto 0);
      ast_sink_channel          : in   std_logic_vector(2  downto 0)
      );
  end component;

  signal csi_AudioClk12MHz_clk: std_logic;
  signal csi_AudioClk12MHz_reset_n: std_logic;
  signal coe_AudioIn_export: std_logic_vector(audioWidth-1 downto 0);
  signal coe_AudioOut_export: std_logic_vector(audioWidth-1 downto 0);
  signal coe_AudioSync_export: std_logic;
  signal csi_clockreset_clk: std_logic;
  signal csi_clockreset_reset_n: std_logic;
  signal avs_s1_write: std_logic;
  signal avs_s1_read: std_logic;
  signal avs_s1_chipselect: std_logic;
  signal avs_s1_address: std_logic_vector(7 downto 0);
  signal avs_s1_writedata: std_logic_vector(15 downto 0);
  signal avs_s1_readdata: std_logic_vector(15 downto 0);
  signal ast_source_valid: std_logic;
  signal ast_source_data: std_logic_vector(23 downto 0);
  signal ast_source_channel: std_logic_vector(2 downto 0);
  signal ast_sink_valid: std_logic;
  signal ast_sink_data: std_logic_vector(23 downto 0);
  signal ast_sink_channel: std_logic_vector(2 downto 0) ;

  constant clock_period: time := 83.3 ns; --12MHz
  signal stop_the_clock: boolean;
  
  constant clock_period_sync: time := 20.8 us; --48KHz
  constant clock_period_50Mhz: time := 20 ns; --50MHz

begin

  -- Insert values for generic parameters !!
  uut: audio_process2 generic map ( audioWidth                => audioWidth )
                        port map ( csi_AudioClk12MHz_clk     => csi_AudioClk12MHz_clk,
                                   csi_AudioClk12MHz_reset_n => csi_AudioClk12MHz_reset_n,
                                   coe_AudioIn_export        => coe_AudioIn_export,
                                   coe_AudioOut_export       => coe_AudioOut_export,
                                   coe_AudioSync_export      => coe_AudioSync_export,
                                   csi_clockreset_clk        => csi_clockreset_clk,
                                   csi_clockreset_reset_n    => csi_clockreset_reset_n,
                                   avs_s1_write              => avs_s1_write,
                                   avs_s1_read               => avs_s1_read,
                                   avs_s1_chipselect         => avs_s1_chipselect,
                                   avs_s1_address            => avs_s1_address,
                                   avs_s1_writedata          => avs_s1_writedata,
                                   avs_s1_readdata           => avs_s1_readdata,
                                   ast_source_valid          => ast_source_valid,
                                   ast_source_data           => ast_source_data,
                                   ast_source_channel        => ast_source_channel,
                                   ast_sink_valid            => ast_sink_valid,
                                   ast_sink_data             => ast_sink_data,
                                   ast_sink_channel          => ast_sink_channel );
                                   
  ST_FIR_Filter_1: entity work.ST_FIR_Filter
    port map (clk => csi_AudioClk12MHz_clk,
              reset_n => csi_AudioClk12MHz_reset_n,
              ast_sink_data => ast_source_data,
              ast_sink_valid => ast_source_valid,
              ast_sink_channel => ast_source_channel,
              ast_source_data => ast_sink_data,
              ast_source_valid => ast_sink_valid,
              ast_source_channel => ast_sink_channel);

  stimulus: process
  begin
  
    -- Put initialisation code here

    csi_clockreset_reset_n <= '0';
    csi_AudioClk12MHz_reset_n <= '0';
    coe_AudioIn_export <= (others => '0');
    wait for 10 ns;
    csi_clockreset_reset_n <= '1';
    csi_AudioClk12MHz_reset_n <= '1';
    wait for 10 ns;

    -- Put test bench stimulus code here
    
    wait for 15 ns;    
       
    wait until coe_AudioSync_export = '1';
    coe_AudioIn_export <= X"153000";
    wait until coe_AudioSync_export = '1';
    coe_AudioIn_export <= (others => '0');   

    --stop_the_clock <= true;
    wait;
  end process;

  clocking: process --12Mhz
  begin
    while not stop_the_clock loop
      csi_AudioClk12MHz_clk <= '0', '1' after clock_period / 2;
      wait for clock_period;
    end loop;
    wait;
  end process;
  
  clocking_sync: process --47KHz
  begin
    while not stop_the_clock loop
      coe_AudioSync_export <= '0', '1' after clock_period_sync / 2;
      wait for clock_period_sync;
    end loop;
    wait;
  end process;  
  
  clocking_50MHz: process
  begin
    while not stop_the_clock loop
      csi_clockreset_clk <= '0', '1' after clock_period_50MHz / 2;
      wait for clock_period_50MHz;
    end loop;
    wait;
  end process;  

end;
  

configuration cfg_audio_process_tb of audio_process_tb_rune is
  for bench
    for uut: audio_process2
      -- Default configuration
    end for;
  end for;
end cfg_audio_process_tb;

configuration cfg_audio_process_tb_behaviour of audio_process_tb_rune is
  for bench
    for uut: audio_process2
      use entity work.audio_process2(behaviour);
    end for;
  end for;
end cfg_audio_process_tb_behaviour;

  


