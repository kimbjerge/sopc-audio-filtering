-------------------------------------------------------------------------------
-- Title      : Testbench for design "audio_processfilter"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : audio_processfilter_tb.vhd
-- Author     :   <kbe>
-- Company    : 
-- Created    : 2012-02-28
-- Last update: 2012-02-28
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: 
-- Reads audio samples in 24 bit hex format from leftin.txt and rightin.txt
-- files and store the filtered result for leftout.txt and rifhtout.txt files
-------------------------------------------------------------------------------
-- Copyright (c) 2012 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2012-02-28  1.0      kbe	Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use ieee.numeric_std.all;
use work.io_utils.all;

-------------------------------------------------------------------------------

entity audiofilter_tb is

  generic (
            audioWidth : natural := 24;
            leftin_name: string := "leftin.txt";
            rightin_name: string := "rightin.txt";
            leftout_name: string := "leftout.txt";
            rightout_name: string := "rightout.txt"
            );
            
end audiofilter_tb;

-------------------------------------------------------------------------------
architecture behaviour of audiofilter_tb is

  component audiofilter_process
    generic (
      audioWidth : natural
      );    
    port (
      -- Audio Interface
      csi_AudioClk12MHz_clk 		    : in  std_logic;                      	-- 12MHz Clk
      csi_AudioClk12MHz_reset_n   : in  std_logic;                      	-- 12MHz Clk
      coe_AudioIn_export       	  : in  std_logic_vector(audioWidth-1 downto 0);  	-- To Codec
      coe_AudioOut_export      	  : out std_logic_vector(audioWidth-1 downto 0);  	-- From Codec
      coe_AudioSync_export     	  : in  std_logic;                       -- 48KHz Sync
      
      -- Avalon Interface
      csi_clockreset_clk     		   : in  std_logic;   		-- Avalon Clk 50 Mhz
      csi_clockreset_reset_n 		   : in  std_logic;   		-- Avalon Reset
      avs_s1_write           		   : in  std_logic;   		-- Avalon wr
      avs_s1_read            		   : in  std_logic;   		-- Avalon rd
      avs_s1_chipselect      		   : in  std_logic;   		-- Avalon Chip Select
      avs_s1_address         		   : in  std_logic_vector(7 downto 0);    -- Avalon address
      avs_s1_writedata       		   : in  std_logic_vector(15 downto 0);    -- Avalon wr data
      avs_s1_readdata        		   : out std_logic_vector(15 downto 0)     -- Avalon rd data
      );
  end component;
  
  -- component ports
  signal Clock         : std_logic;
  signal Reset         : std_logic;
  signal AudioClk12MHz : std_logic;
  signal AudioOut      : std_logic_vector(audioWidth-1 downto 0);
  signal Audioin       : std_logic_vector(audioWidth-1 downto 0):=(others => '0');
  signal AudioSync     : std_logic;
  
  signal avs_write     : std_logic := '0';
  signal avs_read      : std_logic := '0';
  signal avs_cs        : std_logic := '0';
  signal avs_address   : std_logic_vector(7 downto 0);
  signal avs_writedata : std_logic_vector(15 downto 0);
  signal avs_readdata  : std_logic_vector(15 downto 0);

  -- clock
  signal Clk	  : std_logic := '1';
  signal Clk12Mhz : std_logic := '1';
  signal Clk48KHz : std_logic := '1';
  constant period50M : time := 20 ns;
  constant period12M : time := 80 ns;
  constant period48K : time := 20.833 us;
  

begin  -- behaviour

  -- component instantiation
  DUT: audiofilter_process
    generic map (
      audioWidth => audioWidth
      )    
    port map (
      csi_AudioClk12MHz_clk       => Clk12Mhz,
      csi_AudioClk12MHz_reset_n   => Reset,
      coe_AudioOut_export         => AudioOut,
      coe_AudioIn_export          => Audioin,
      coe_AudioSync_export        => Clk48KHz,
      csi_clockreset_clk			       => Clk,
      csi_clockreset_reset_n      => Reset,
      avs_s1_write                => avs_write,
      avs_s1_read                 => avs_read,
      avs_s1_chipselect           => avs_cs,
      avs_s1_address              => avs_address,
      avs_s1_writedata            => avs_writedata,
      avs_s1_readdata             => avs_readdata
      );

  -- clock generation
  avs_address <= (others => '0');
  Clk <= not Clk after period50M/2;
  Clk12Mhz <= not Clk12Mhz after period12M/2;
  Clk48KHz <= not Clk48KHz after period48K/2;

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
      Audioin <= std_logic_vector(TO_SIGNED(data, 24)); -- convert to audio 24 bit 
      data := TO_INTEGER(signed(AudioOut));
      write(line, data, right, 0, decimal, false);
      writeline(leftoutfile, line);

      wait until Clk48KHz = '0';  -- Right channel
      readline(leftinfile, line); -- read next text line from file
      read(line, data, 16); -- convert hex (16) numbers to integer value
      Audioin <= std_logic_vector(TO_SIGNED(data, 24)); -- convert to audio 24 bit       
      data := TO_INTEGER(signed(AudioOut));
      write(line, data, right, 0, decimal, false);
      writeline(leftoutfile, line);
      
    end loop;

    -- Wait for last sample
    wait until Clk48KHz = '1';  -- Left channel
    data := TO_INTEGER(signed(AudioOut));
    write(line, data, right, 0, decimal, false);
    writeline(leftoutfile, line);
    wait until Clk48KHz = '0';  -- Right channel
    data := TO_INTEGER(signed(AudioOut));
    write(line, data, right, 0, decimal, false);
    writeline(leftoutfile, line);
   
    
    file_close(leftinfile);  
    file_close(rightinfile);  
    file_close(leftoutfile);  
    file_close(rightoutfile); 
     
    wait;
    
  end process WaveGen_Proc;
  

end behaviour;

