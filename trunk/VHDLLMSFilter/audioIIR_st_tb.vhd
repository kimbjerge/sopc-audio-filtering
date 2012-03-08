-------------------------------------------------------------------------------
-- Title      : Testbench for design "audioIIR_st"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : audioIIR_st_tb.vhd
-- Author     :   <kbe>
-- Company    : 
-- Created    : 2012-02-28
-- Last update: 2012-02-28
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: 
-- Reads audio samples in 24 bit hex format from leftin_name and rightin_name
-- files and store the filtered result for leftout_name and rightout_name files
-------------------------------------------------------------------------------
-- Copyright (c) 2012 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2012-03-06  1.0      kbe	    Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use ieee.numeric_std.all;
use work.io_utils.all;

-------------------------------------------------------------------------------

entity audioIIR_st_tb is

  generic (
            audioWidth : natural := 24; -- 24 bit audio data
            chNrLeft: std_logic_vector(2  downto 0) := "000"; -- Left audio channel number
            chNrRight: std_logic_vector(2  downto 0) := "001"; -- Right audio channel number
            leftin_name: string := "NoiseHex.txt"; -- Contains noise (x = LMS input)
            rightin_name: string := "NoiseSignalHex.txt"; -- Contains noise + sound (d = LMS desigeret)
            leftout_name: string := "leftoutIIR.txt";
            rightout_name: string := "rightoutIIR.txt"
            );
            
end audioIIR_st_tb;

-------------------------------------------------------------------------------
architecture behaviour of audioIIR_st_tb is

  component audio_process_st2
    generic (audioWidth : natural;
             chNrLeft: std_logic_vector(2  downto 0);
             chNrRight: std_logic_vector(2  downto 0)
             ); 
    port (
      csi_AudioClk12MHz_clk 		  : in  std_logic;
      csi_AudioClk12MHz_reset_n : in  std_logic;
      coe_AudioIn_export       	: in  std_logic_vector(audioWidth-1 downto 0);
      coe_AudioOut_export      	: out std_logic_vector(audioWidth-1 downto 0);
      coe_AudioSync_export     	: in  std_logic;
      csi_clockreset_clk     		 : in  std_logic;
      csi_clockreset_reset_n 		 : in  std_logic;
      avs_s1_write           		 : in  std_logic;
      avs_s1_read            		 : in  std_logic;
      avs_s1_chipselect      		 : in  std_logic;
      avs_s1_address         		 : in  std_logic_vector(7 downto 0);
      avs_s1_writedata       		 : in  std_logic_vector(15 downto 0);
      avs_s1_readdata        		 : out std_logic_vector(15 downto 0);
      ast_source_valid          : out std_logic;
      ast_source_data           : out std_logic_vector(audioWidth-1 downto 0);
      ast_source_channel        : out std_logic_vector(2  downto 0);
      ast_sink_valid            : in  std_logic;
      ast_sink_data             : in  std_logic_vector(audioWidth-1 downto 0);
      ast_sink_channel          : in  std_logic_vector(2  downto 0)
      );
  end component;

  component audioIIR_st
    generic (
      audioWidth : natural;
      chNrLeft: std_logic_vector(2  downto 0);
      chNrRight: std_logic_vector(2  downto 0)
      );    
    port (
      -- Audio Interface
      csi_AudioClk12MHz_clk 		    : in  std_logic;                      	-- 12MHz Clk
      csi_AudioClk12MHz_reset_n   : in  std_logic;                      	-- 12MHz Clk

      -- ST Bus --
      ast_source_data           : out std_logic_vector(audioWidth-1 downto 0);
      ast_source_valid          : out std_logic;
      ast_source_channel        : out std_logic_vector(2  downto 0);
      ast_sink_data             : in  std_logic_vector(audioWidth-1 downto 0);
      ast_sink_valid            : in  std_logic;
      ast_sink_channel          : in  std_logic_vector(2  downto 0);
      
      -- Avalon Interface
      csi_clockreset_clk     		   : in  std_logic;   		-- Avalon Clk 50 Mhz
      csi_clockreset_reset_n 		   : in  std_logic;   		-- Avalon Reset
      avs_s1_write           		   : in  std_logic;   		-- Avalon wr
      avs_s1_read            		   : in  std_logic;   		-- Avalon rd
      avs_s1_chipselect      		   : in  std_logic;   		-- Avalon Chip Select
      avs_s1_address         		   : in  std_logic_vector(7 downto 0);    -- Avalon address
      avs_s1_writedata       		   : in  std_logic_vector(31 downto 0);    -- Avalon wr data
      avs_s1_readdata        		   : out std_logic_vector(31 downto 0)     -- Avalon rd data
      );
  end component;
  
  -- Audio data
  signal AudioOut      : std_logic_vector(audioWidth-1 downto 0);
  signal Audioin       : std_logic_vector(audioWidth-1 downto 0):=(others => '0');
  
  -- MM Bus
  signal avs_write     : std_logic := '0';
  signal avs_read      : std_logic := '0';
  signal avs_cs        : std_logic := '0';
  signal avs_address   : std_logic_vector(7 downto 0);
  signal avs_writedata : std_logic_vector(31 downto 0);
  signal avs_readdata  : std_logic_vector(31 downto 0);

  -- ST Bus
  signal ast_input_valid: std_logic;
  signal ast_input_data: std_logic_vector(audioWidth-1 downto 0);
  signal ast_input_channel: std_logic_vector(2 downto 0);
  signal ast_output_valid: std_logic;
  signal ast_output_data: std_logic_vector(audioWidth-1 downto 0);
  signal ast_output_channel: std_logic_vector(2 downto 0);

  -- clock and reset
  signal Reset : std_logic;
  signal Clk	: std_logic := '1';
  signal Clk12Mhz : std_logic := '1';
  signal Clk48KHz : std_logic := '1';
  constant period50M : time := 20 ns;
  constant period12M : time := 80 ns;
  constant period48K : time := 20.833 us;
  
  signal stop_the_clock: boolean := false; 
    
begin  -- behaviour
  
  -- component instantiation for audio to ST bus converter
  UUT: audio_process_st2 
    generic map ( audioWidth => audioWidth,
                  chNrLeft => chNrLeft,
                  chNrRight => chNrRight  )
    port map ( csi_AudioClk12MHz_clk     => Clk12Mhz,
               csi_AudioClk12MHz_reset_n => Reset,
               coe_AudioIn_export        => Audioin,
               coe_AudioOut_export       => AudioOut,
               coe_AudioSync_export      => Clk48KHz,
               csi_clockreset_clk        => Clk,
               csi_clockreset_reset_n    => Reset,
               avs_s1_write              => avs_write,
               avs_s1_read               => avs_read,
               avs_s1_chipselect         => avs_cs,
               avs_s1_address            => avs_address,
               avs_s1_writedata          => avs_writedata(15 downto 0),
               avs_s1_readdata           => avs_readdata(15 downto 0),
               ast_source_valid          => ast_input_valid,
               ast_source_data           => ast_input_data,
               ast_source_channel        => ast_input_channel,
               ast_sink_valid            => ast_output_valid,
               ast_sink_data             => ast_output_data,
               ast_sink_channel          => ast_output_channel);
                                    

  -- component instantiation og optimized LMS filter
  DUT: audioIIR_st
    generic map (
      audioWidth => audioWidth,
      chNrLeft => chNrLeft,
      chNrRight => chNrRight
      )
    port map (
      csi_AudioClk12MHz_clk       => Clk12Mhz,
      csi_AudioClk12MHz_reset_n   => Reset,
      ast_source_data             => ast_output_data,
      ast_source_valid            => ast_output_valid,
      ast_source_channel          => ast_output_channel,
      ast_sink_data               => ast_input_data,
      ast_sink_valid              => ast_input_valid,
      ast_sink_channel            => ast_input_channel,
      csi_clockreset_clk			       => Clk,
      csi_clockreset_reset_n      => Reset,
      avs_s1_write                => avs_write,
      avs_s1_read                 => avs_read,
      avs_s1_chipselect           => avs_cs,
      avs_s1_address              => avs_address,
      avs_s1_writedata            => avs_writedata,
      avs_s1_readdata             => avs_readdata
     );

  -- clear MM signals not used
  avs_address <= (others => '0');
  avs_write <= '0';
  avs_read <= '0';
  avs_cs <= '0';
  avs_writedata <= (others => '0');
  
  -- Processes generating clocks 
  clocking: process --12Mhz
  begin
    while not stop_the_clock loop
      Clk12Mhz <= '0', '1' after period12M / 2;
      wait for period12M;
    end loop;
    wait;
  end process;
  
  clocking_sync: process --48KHz
  begin
    while not stop_the_clock loop
      Clk48KHz <= '0', '1' after period48K / 2;
      wait for period48K;
    end loop;
    wait;
  end process;  
  
  clocking_50MHz: process
  begin
    while not stop_the_clock loop
      Clk <= '0', '1' after period50M / 2;
      wait for period50M;
    end loop;
    wait;
  end process; 
  
  Reset <= '0', '1' after 125 ns;

  -- waveform generation
  WaveGen_Proc: process
    -- files
    variable line: LINE;
    variable data: integer;
    variable val: signed(31 downto 0);
    variable i: integer;
    file leftinfile: TEXT open read_mode is leftin_name;
    file rightinfile: TEXT open read_mode is rightin_name;
    file leftoutfile: TEXT open write_mode is leftout_name;
    file rightoutfile: TEXT open write_mode is rightout_name;
  begin
    
    -- Open simulation files
    file_open(leftinfile, leftin_name);
    file_open(rightinfile, rightin_name);
    file_open(leftoutfile, leftout_name);
    file_open(rightoutfile, rightout_name);
    
    -- signal assignments
    wait until Reset = '1';
    wait until Clk48KHz = '1';
    wait until Clk12Mhz = '1';
    wait until Clk = '1';

    -- Samples in left channel defines loops
    while not endfile(leftinfile) loop

      wait until Clk48KHz = '1';  -- Left channel
      readline(leftinfile, line); -- read next text line from file
      read(line, data, 16); -- convert hex (16) numbers to integer value
      Audioin <= std_logic_vector(TO_SIGNED(data, audioWidth)); -- convert to audio 24 bit 
      data := TO_INTEGER(signed(AudioOut));
      write(line, data, right, 0, decimal, false);
      writeline(leftoutfile, line);

      wait until Clk48KHz = '0';  -- Right channel
      readline(rightinfile, line); -- read next text line from file
      read(line, data, 16); -- convert hex (16) numbers to integer value
      Audioin <= std_logic_vector(TO_SIGNED(data, audioWidth)); -- convert to audio 24 bit       
      data := TO_INTEGER(signed(AudioOut));
      write(line, data, right, 0, decimal, false);
      writeline(rightoutfile, line);
      
    end loop;
   
    -- Read last samples   
    wait for period48K;
    wait for period48K;
     
    file_close(leftinfile);  
    file_close(rightinfile);  
    file_close(leftoutfile);  
    file_close(rightoutfile);
     
    stop_the_clock <= true; 
    
  end process WaveGen_Proc;
  

end behaviour;

