library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity audiodelay_st is
  generic (delaySize : natural := 2024;
           audioWidth : natural := 24;
           chNrLeft : std_logic_vector(2  downto 0) := "000";
           chNrRight : std_logic_vector(2  downto 0) := "001");  -- Default values
  port (
    -- Audio Interface
    csi_AudioClk12MHz_clk 		  : in  std_logic;        -- 12MHz Clk
    csi_AudioClk12MHz_reset_n : in  std_logic;        -- 12MHz Clk
    
    -- ST Bus --
    ast_source_data           : out std_logic_vector(audioWidth-1 downto 0);
    ast_source_valid          : out std_logic;
    ast_source_channel        : out std_logic_vector(2  downto 0);
    ast_sink_data             : in  std_logic_vector(audioWidth-1 downto 0);
    ast_sink_valid            : in  std_logic;
    ast_sink_channel          : in  std_logic_vector(2  downto 0);
    
    -- Avalon Interface
    csi_clockreset_clk     		 : in    std_logic;   					-- Avalon Clk 50 Mhz
    csi_clockreset_reset_n 		 : in    std_logic;   					-- Avalon Reset
    avs_s1_write           		 : in    std_logic;   					-- Avalon wr
    avs_s1_read            		 : in    std_logic;   					-- Avalon rd
    avs_s1_chipselect      		 : in    std_logic;   					-- Avalon Chip Select
    avs_s1_address         		 : in    std_logic_vector(7 downto 0);  -- Avalon address
    avs_s1_writedata       		 : in    std_logic_vector(15 downto 0);  -- Avalon wr data
    avs_s1_readdata        		 : out   std_logic_vector(15 downto 0)   -- Avalon rd data
    );

end audiodelay_st;

architecture behaviour of audiodelay_st is

  -- Constant Declarations
  constant CI_ADDR_START    : std_logic_vector(7 downto 0) := X"00";
  constant CI_ADDR_DLY      : std_logic_vector(7 downto 0) := X"02";
  constant CI_BYPASS  	     : std_logic                    := '1';
  
  -- Internal signals
  signal bypass_left        : std_logic;
  signal bypass_right       : std_logic;

  subtype ramaddr_type is INTEGER RANGE 0 to delaySize-1;
  constant CI_START_WRITE_ADDR : ramaddr_type := 0;
  constant CI_START_READ_ADDR : ramaddr_type := 1;
  
  signal lramwaddr : ramaddr_type; -- Left ram write address  
  signal lramraddr : ramaddr_type; -- Left ram read address  
  signal lraminput : std_logic_vector(audioWidth-1 downto 0);
  signal lramoutput : std_logic_vector(audioWidth-1 downto 0);
  signal left_delay : std_logic_vector(audioWidth-1 downto 0);
  signal lramwe : std_logic;

  signal rramwaddr : ramaddr_type; -- Right ram write address  
  signal rramraddr : ramaddr_type; -- Right ram read address  
  signal rraminput : std_logic_vector(audioWidth-1 downto 0);
  signal rramoutput : std_logic_vector(audioWidth-1 downto 0);
  signal right_delay : std_logic_vector(audioWidth-1 downto 0);
  signal rramwe : std_logic;
     
begin  

    DelayRAMLeft: entity work.delay_ram
    generic map ( bitWidth  => audioWidth,
                  ramSize => delaySize  )
    port map (
    		    clock => csi_AudioClk12MHz_clk,
		      data => lraminput,
		      write_addr => lramwaddr,
		      read_addr => lramraddr,
		      we => lramwe,
		      q => lramoutput);
		      
    DelayRAMRight: entity work.delay_ram
    generic map ( bitWidth  => audioWidth,
                  ramSize => delaySize  )
    port map (
    		    clock => csi_AudioClk12MHz_clk,
		      data => rraminput,
		      write_addr => rramwaddr,
		      read_addr => rramraddr,
		      we => rramwe,
		      q => rramoutput);      
		               
  ------------------------------------------------------------------------
  -- purpose: Register with Avalon Bus interface
  -- inputs : csi_clockreset_clk, csi_clockreset_reset_n, avalonbus
   ------------------------------------------------------------------------
 accessMem : process (csi_clockreset_clk, csi_clockreset_reset_n)
    variable wrData : std_logic_vector(avs_s1_writedata'high downto 0);
  begin  -- process accessMem
    
    if csi_clockreset_reset_n = '0' then  -- asynchronous reset (active low)
      bypass_left <= '0';
      bypass_right <= '0';
      
    elsif csi_clockreset_clk'event and csi_clockreset_clk = '1' then  -- rising clock edge
          
      if avs_s1_chipselect = '1' then
        if avs_s1_write = '1' then
          case avs_s1_address is
            when CI_ADDR_START => 
                bypass_right <= avs_s1_writedata(0);
                bypass_left <= avs_s1_writedata(1);
            when others  => null;
          end case;
        end if;
        
        if avs_s1_read = '1' then
          case avs_s1_address is
            when CI_ADDR_START =>
              avs_s1_readdata <= (0 => bypass_right, 1 => bypass_left, others => '0');
            when others =>
              avs_s1_readdata <= (others => '0');
          end case;
        end if;
      end if;
      
    end if;
  end process accessMem;

  
  ------------------------------------------------------------------------
  -- Process handling of audio clock, sampling of ST input data
  ------------------------------------------------------------------------
  sample_st_sink : process (csi_AudioClk12MHz_clk, csi_AudioClk12MHz_reset_n)
  begin 
    
    if csi_AudioClk12MHz_reset_n = '0' then        -- asynchronous reset (active low)
      left_delay <= (others => '0');
      right_delay <= (others => '0');
		  lraminput <= (others => '0');
		  rraminput <= (others => '0');
		  lramwaddr <= CI_START_WRITE_ADDR; -- start write
		  rramwaddr <= CI_START_WRITE_ADDR;
		  lramraddr <= CI_START_READ_ADDR;
		  rramraddr <= CI_START_READ_ADDR;
      lramwe <= '0';
		  rramwe <= '0';
       
    elsif falling_edge(csi_AudioClk12MHz_clk) then  -- rising clock edge  
    
  		  rramwe <= '0';
      lramwe <= '0';
  
      -- New sample ready on ST bus
      if ast_sink_valid = '1' then 
              
        -- Read audio channel
        case ast_sink_channel is
        
        when chNrLeft =>
          
          -- Left channel input
          left_delay <= lramoutput;
          lraminput <=  ast_sink_data;
          
          -- Write value to ram
      		  lramwe <= '1';
      		  
      		  if (lramwaddr < delaySize - 1) then
      		    -- Increment write address
            lramwaddr <= lramwaddr + 1;
          else
            lramwaddr <= 0;
          end if; 
          
    		    if (lramraddr < delaySize - 1) then
            -- Increment read address     
            lramraddr <= lramraddr + 1;
          else
            lramraddr <= 0;
          end if;      
          
        when chNrRight =>
          
          -- Right channel input
          right_delay <= rramoutput;
          rraminput <=  ast_sink_data;
          
          -- Write value to ram
      		  rramwe <= '1';
      		  
      		  if (rramwaddr < delaySize - 1) then
      		    -- Increment write address
            rramwaddr <= rramwaddr + 1;
          else
            rramwaddr <= 0;
          end if; 
          
    		    if (rramraddr < delaySize - 1) then
            -- Increment read address     
            rramraddr <= rramraddr + 1;
          else
            rramraddr <= 0;
          end if;           

        when others => 
          null;
        
        end case;
        
      end if;

    end if;
    
  end process sample_st_sink;
  
  ------------------------------------------------------------------------
  -- Process handling of audio clock, sampling of ST input data
  ------------------------------------------------------------------------
  sample_st_source : process (csi_AudioClk12MHz_clk, csi_AudioClk12MHz_reset_n)
  begin 
    
    if csi_AudioClk12MHz_reset_n = '0' then        -- asynchronous reset (active low)
      ast_source_data <= (others => '0');
      ast_source_channel <= (others => '0');
      ast_source_valid <= '0';
       
    elsif rising_edge(csi_AudioClk12MHz_clk) then  -- rising clock edge  

      ast_source_valid <= '0';

      -- New sample to left delay line
      if (lramwe = '1') then 
          -- Left channel output
          if (bypass_left = CI_BYPASS) then
            ast_source_data <= lraminput;
          else  
            ast_source_data <= left_delay; -- Output from delay line
          end if;
          
          ast_source_channel <= chNrLeft;
          ast_source_valid <= '1';
      end if;
  
      -- New sample to right delay line
      if (rramwe = '1') then
            -- Right channel output
          if (bypass_right = CI_BYPASS) then
            ast_source_data <= rraminput;
          else   
            ast_source_data <= right_delay; -- Output from delay line    
          end if;
          
          ast_source_channel <= chNrRight;
          ast_source_valid <= '1';
      end if;
  
    end if;
    
   end process sample_st_source; 

end behaviour;
