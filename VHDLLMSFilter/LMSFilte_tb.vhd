-------------------------------------------------------------------------------
-- Title      : Testbench for design "audio_process"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : audio_process_tb.vhd
-- Author     :   <kbe>
-- Company    : 
-- Created    : 2012-02-28
-- Last update: 2012-02-28
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: 
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
use work.txt_util.all;

-------------------------------------------------------------------------------

entity LMSFilter_tb is

  generic (
            audioWidth : natural := 24;
            input_file: string := "input1024.txt";
            output_file: string := "output1024.txt"
            );
            
end LMSFilter_tb;

-------------------------------------------------------------------------------
architecture behaviour of LMSFilter_tb is

  component audio_process
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
  DUT: audio_process
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
    file Fin: TEXT open read_mode is input_file;
    file Fout: TEXT open write_mode is output_file;
    variable Lin: LINE;
    variable Lout: LINE;
    variable data: string(1 to 24);
  begin
    
    file_open(Fin, input_file, READ_MODE);
    file_open(Fout, output_file, WRITE_MODE);
    
    -- insert signal assignments here
    wait until Reset = '1';
    wait until Clk = '1';
    wait until Clk12Mhz = '1';
    wait until Clk48KHz = '1';

    while not endfile(Fin) loop
      readline(Fin,Lin);
      read(Lin, data);
      Audioin <= to_std_logic_vector(data);         
      wait until Clk48KHz = '1';  -- Left/Right channel
      write(Lout, str(AudioOut));
      writeline(Fout, Lout);
    end loop;
    
    -- Wait to process audio
    for i in 1023 downto 0 loop
      wait until Clk48KHz = '1';  -- Left/Right channel
      write(Lout, str(AudioOut));
      writeline(Fout, Lout);      
    end loop;
    
    file_close(Fout);  
    file_close(Fin);  
    wait;
    
  end process WaveGen_Proc;
  

end behaviour;

