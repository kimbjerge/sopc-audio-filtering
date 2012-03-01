library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

entity FirFilter_iis2st_tb is
end;

architecture bench of FirFilter_iis2st_tb is

  component FIRFilter
    generic (
      filterOrder : natural;
      inputWidth : natural);
    port (
      clk              : in  std_logic;
      reset_n          : in  std_logic;
      ast_sink_data    : in  std_logic_vector(23 downto 0);
      ast_sink_ready   : out std_logic;
      ast_sink_valid   : in  std_logic;
      ast_sink_error   : in  std_logic_vector(1 downto 0);
      ast_source_data  : out std_logic_vector(23 downto 0);
      ast_source_ready : in  std_logic;
      ast_source_valid : out std_logic;
      ast_source_error : out std_logic_vector(1 downto 0)
      );
  end component;

  component iis2st
    port (
      clk              : in  std_logic;
      reset_n          : in  std_logic;
      ast_clk          : in  std_logic;
      ast_sink_data    : in  std_logic_vector(23 downto 0);
      ast_sink_ready   : out std_logic;
      ast_sink_valid   : in  std_logic;
      ast_sink_error   : in  std_logic_vector(1 downto 0);
      ast_source_data  : out std_logic_vector(23 downto 0);
      ast_source_ready : in  std_logic;
      ast_source_valid : out std_logic;
      ast_source_error : out std_logic_vector(1 downto 0);
      bitclk           : in  std_logic;
      adcdat           : in  std_logic;
      dacdat           : out std_logic;
      adclrck          : in  std_logic;
      daclrck          : in  std_logic
      );
  end component;

  signal reset_n          : std_logic                     := '0';
  signal ast_clk          : std_logic                     := '0';
  signal ast_sink_data    : std_logic_vector(23 downto 0) := (others => '0');
  signal ast_sink_ready   : std_logic                     := '0';
  signal ast_sink_valid   : std_logic                     := '0';
  signal ast_sink_error   : std_logic_vector(1 downto 0)  := (others => '0');
  signal ast_source_data  : std_logic_vector(23 downto 0);
  signal ast_source_ready : std_logic                     := '1';
  signal ast_source_valid : std_logic;
  signal ast_source_error : std_logic_vector(1 downto 0);
  signal adcdat           : std_logic                     := '0';
  signal adclrck          : std_logic                     := '0';
  signal dacdat           : std_logic                     := '0';
  signal daclrck          : std_logic                     := '0';
  signal bitclk           : std_logic                     := '0';
  signal lefti2svalue     : signed(23 downto 0)           := X"000100";  
  signal righti2svalue    : signed(23 downto 0)           := X"000000";
  
  signal adcvalue         : signed(23 downto 0);
  signal dacvalue         : signed(23 downto 0);

  constant filterOrder : natural := 10;
  constant inputWidth : natural := 24;

  -- clock
  constant bitperiod    : time := 83 ns;    -- 12 Mhz
  constant sampleperiod : time := 20833 ns; -- 48 Khz

  -----------------------------------------------------------------------------
  -- IIS data generation procedure
  --          ___                             ____...______
  -- adclrck:    \________...________________/            
  --                  ____..._____
  -- adcdat: ________/  i2svalue  \_______________...______
  --            _   _   _    _   _   _   _   _   _      _
  -- bitclk   _/ \_/ \_/ \... \_/ \_/ \_/ \_/ \_/ ... _/ \_
  -----------------------------------------------------------------------------

  -- IIS data generation process
  procedure genI2SValue(
    constant val : in signed(23 downto 0);
    signal bclk : in std_logic;
    signal adc : out std_logic) is
  begin    
    --wait until bclk = '1';
    for i in 23 downto 0 loop
      adc <= val(i);
      wait until bclk = '0';
      wait until bclk = '1';
    end loop;
    adc <= '0';  
  end genI2SValue;  
  
  -- Create a IIS data generation process here..
  procedure readI2SValue(
      signal dac : in std_logic;
      signal bclk : in std_logic;
      variable val : out signed(23 downto 0)
    ) is
  begin    
    wait for bitperiod;
    -- Read DAC value from I2S left channel
    for i in 23 downto 0 loop
      wait until bclk = '1';
      val(i) := dac;
      wait until bclk = '0';
    end loop;    
  end readI2SValue;  
  
begin

  iis2st_inst : iis2st
    port map (
      clk              => bitclk,       -- 12 Mhz
      reset_n          => reset_n,
      ast_clk          => ast_clk,      -- 48 Khz
      ast_sink_data    => ast_sink_data,  -- Loop back
      ast_sink_ready   => ast_sink_ready,
      ast_sink_valid   => ast_sink_valid,
      ast_sink_error   => ast_sink_error,
      ast_source_data  => ast_source_data,
      ast_source_ready => ast_source_ready,
      ast_source_valid => ast_source_valid,
      ast_source_error => ast_source_error,
      bitclk           => bitclk,       -- 12 Mhz
      adcdat           => adcdat,
      dacdat           => dacdat,
      adclrck          => adclrck,
      daclrck          => daclrck);

  FirFilter_inst : FIRFilter
    generic map (
      filterOrder => filterOrder,
      inputWidth => inputWidth)
    port map (
      clk              => bitclk,       -- 12 Mhz Clock
      reset_n          => reset_n,
      ast_sink_data    => ast_source_data,
      ast_sink_ready   => ast_source_ready,
      ast_sink_valid   => ast_source_valid,
      ast_sink_error   => ast_source_error,
      ast_source_data  => ast_sink_data,
      ast_source_ready => ast_sink_ready,
      ast_source_valid => ast_sink_valid,
      ast_source_error => ast_sink_error);


  -- clock generation
  bitclk <= not bitclk after bitperiod/2;
  adclrck <= not adclrck after sampleperiod/2;
  daclrck <= not daclrck after sampleperiod/2;
  ast_clk <= not ast_clk after sampleperiod/2;

  -- reset generation
  reset_n         <= '0', '1' after 125 ns; 

  -----------------------------------------------------------------------------
  -- Stimulus process
  -- Does nothing but wait
  -----------------------------------------------------------------------------
  stimulus : process
  variable cnt: natural;
  begin  
    wait until reset_n = '1';
    
    cnt := 0;
    while (cnt < 16) loop
      
      wait until adclrck = '1';
      genI2SValue(righti2svalue, bitclk, adcdat);
      adcvalue <= righti2svalue;
      righti2svalue <= (others => '0');
      
      -- I2S Left channel
      wait until adclrck = '0';
      genI2SValue(lefti2svalue, bitclk, adcdat);
      adcvalue <= lefti2svalue;
      lefti2svalue <= (others => '0'); --lefti2svalue + 1;
      
      cnt := cnt + 1;
    end loop;

    wait;
  end process;
  
  responseMonitor: process
    variable a, b : std_logic;
    variable val : signed(23 downto 0);
  begin 
    wait until reset_n = '1';
    wait until daclrck = '1';
    wait until daclrck = '0';
  
    while reset_n = '1' loop

      -- I2S Right channel
      wait until daclrck = '1';
      readI2SValue(dacdat, bitclk, val);

      assert (val = 0)  
      report "DAC value detected: " & std_logic'image(std_logic(val(0))) severity error;
      dacvalue <= val;  

      -- I2S Left channel
      wait until daclrck = '0';
      readI2SValue(dacdat, bitclk, val);
        
      assert (val /= 0)  
      report "DAC value detected: " & std_logic'image(std_logic(val(0))) severity error;
      dacvalue <= val;  

    end loop;
  end process responseMonitor;

end;  -- Architecture

