library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity audio_process_st is
  generic (audioWidth : natural := 24;
           chNrLeft         : std_logic_vector(2  downto 0) := "000";
           chNrRight        : std_logic_vector(2  downto 0) := "001"); 
  port (
    -- Audio Interface
    csi_AudioClk12MHz_clk 		  : in  std_logic;                      	-- 12MHz Clk
    csi_AudioClk12MHz_reset_n : in  std_logic;                      	-- 12MHz Clk
    coe_AudioIn_export       	: in  std_logic_vector(audioWidth-1 downto 0);  	-- To Codec
    coe_AudioOut_export      	: out std_logic_vector(audioWidth-1 downto 0);  	-- From Codec
    coe_AudioSync_export     	: in  std_logic;                       	-- 48KHz Sync
    
    -- Avalon Interface
    csi_clockreset_clk     		 : in    std_logic;   					-- Avalon Clk 50 Mhz
    csi_clockreset_reset_n 		 : in    std_logic;   					-- Avalon Reset
    avs_s1_write           		 : in    std_logic;   					-- Avalon wr
    avs_s1_read            		 : in    std_logic;   					-- Avalon rd
    avs_s1_chipselect      		 : in    std_logic;   					-- Avalon Chip Select
    avs_s1_address         		 : in    std_logic_vector(7 downto 0);  -- Avalon address
    avs_s1_writedata       		 : in    std_logic_vector(15 downto 0);  -- Avalon wr data
    avs_s1_readdata        		 : out   std_logic_vector(15 downto 0);   -- Avalon rd data
    
    -- ST Bus
    ast_source_valid          : out   std_logic;
    ast_source_data           : out   std_logic_vector(23 downto 0);
    ast_source_channel        : out   std_logic_vector(2  downto 0);
    ast_sink_valid            : in   std_logic;
    ast_sink_data             : in   std_logic_vector(23 downto 0);
    ast_sink_channel          : in   std_logic_vector(2  downto 0)
    
    );

end audio_process_st;

architecture behaviour of audio_process_st is

  -- Constant Declarations
  constant CI_ADDR_START    : std_logic_vector(7 downto 0) := X"00";
  constant CI_ADDR_STATUS   : std_logic_vector(7 downto 0) := X"40";
  constant CI_UNMUTED 	     : std_logic                     := '0';
  
  -- Internal signals
  signal AudioSync_last     : std_logic;
  signal mute_left          : std_logic;
  signal mute_right         : std_logic;
  
  signal left_sample     	  : std_logic_vector(audioWidth-1 downto 0);
  signal right_sample     	 : std_logic_vector(audioWidth-1 downto 0);  
  
  signal valid_high         : std_logic := '0';

begin  
  
  ------------------------------------------------------------------------
  -- purpose: Register with Avalon Bus interface
  -- inputs : csi_clockreset_clk, csi_clockreset_reset_n, avalonbus
   ------------------------------------------------------------------------
 accessMem : process (csi_clockreset_clk, csi_clockreset_reset_n)
    variable wrData : std_logic_vector(avs_s1_writedata'high downto 0);
  begin  -- process accessMem
    
    if csi_clockreset_reset_n = '0' then  -- asynchronous reset (active low)
      mute_left <= CI_UNMUTED;
      mute_right <= CI_UNMUTED;
      
    elsif csi_clockreset_clk'event and csi_clockreset_clk = '1' then  -- rising clock edge
          
      if avs_s1_chipselect = '1' then
        if avs_s1_write = '1' then
          case avs_s1_address is
            when CI_ADDR_START => 
                mute_right <= avs_s1_writedata(0);
                mute_left <= avs_s1_writedata(1);
            when others  => null;
          end case;
        end if;
        
        if avs_s1_read = '1' then
          if avs_s1_address = CI_ADDR_START then
            avs_s1_readdata <= (0 => mute_right, 1 => mute_left, others => '0');
          else
            avs_s1_readdata <= (others => '0');
          end if;
        end if;
      end if;
      
    end if;
  end process accessMem;

  
  ------------------------------------------------------------------------
  -- Process handling of audio clock, sampling on sync        -- Output to ST Bus
  ------------------------------------------------------------------------
  sample_buf_pro : process (csi_AudioClk12MHz_clk, csi_AudioClk12MHz_reset_n)
  
  type state_type is (idle, validHigh);
  variable valid_state : state_type;
  
  begin 
    
    if csi_AudioClk12MHz_reset_n = '0' then        -- asynchronous reset (active low)
      
      ast_source_data <= (others => '0');
      left_sample <= (others => '0');
      right_sample <= (others => '0');
      
    elsif rising_edge(csi_AudioClk12MHz_clk) then  -- rising clock edge  
    
      -- Left channel
      if coe_AudioSync_export = '1' and AudioSync_last = '0' then 
        left_sample <=  coe_AudioIn_export; 
        if (mute_left = '1') then
          ast_source_data <= (others => '0');
        else   
          ast_source_data <= left_sample;    
          valid_state := validHigh;
          valid_high <= '1';
          ast_source_channel <= chNrLeft; 
        end if;
      end if;

      -- Right channel
      if coe_AudioSync_export = '0' and AudioSync_last = '1' then 
        right_sample <=  coe_AudioIn_export;    
        if (mute_right = '1') then
          ast_source_data <= (others => '0');
        else   
          ast_source_data <= right_sample;
          valid_state := validHigh;
          ast_source_channel <= chNrRight;  
        end if;
      end if;
      
      case valid_state is
        when idle =>
          ast_source_valid <= '0';
        when validHigh =>
          ast_source_valid <= '1';
          valid_state := idle;
      end case;
      
      AudioSync_last <= coe_AudioSync_export;
      
    end if;
    
  end process sample_buf_pro;
  
  st_bus_data_in : process (csi_AudioClk12MHz_clk, csi_AudioClk12MHz_reset_n)
  begin
  if csi_AudioClk12MHz_reset_n = '0' then        -- asynchronous reset (active low)
      
  coe_AudioOut_export <= (others => '0');
      
  elsif rising_edge(csi_AudioClk12MHz_clk) then  -- rising clock edge
    if ast_sink_valid = '1' then
      coe_AudioOut_export <=  ast_sink_data;
    end if;     
  end if;
    
  end process st_bus_data_in;     
  
end behaviour;