library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity audiotransposedfilter is
  generic (filterOrder : natural := 10;
           coefWidth : natural := 8; -- see excel sheet
           audioWidth : natural := 24);  -- Default value
  port (
    -- Audio Interface
    csi_AudioClk12MHz_clk 		: in  std_logic;                      	-- 12MHz Clk
    csi_AudioClk12MHz_reset_n   : in  std_logic;                      	-- 12MHz Clk
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
    avs_s1_readdata        		 : out   std_logic_vector(15 downto 0)   -- Avalon rd data
    );

end audiotransposedfilter;

architecture behaviour of audiotransposedfilter is

  -- Constant Declarations
  constant CI_ADDR_START    : std_logic_vector(7 downto 0) := X"00";
  constant CI_ADDR_STATUS   : std_logic_vector(7 downto 0) := X"40";
  constant CI_UNMUTED 	     : std_logic                     := '0';
  
  -- Internal signals
  signal AudioSync_last     : std_logic;
  signal mute_left          : std_logic;
  signal mute_right         : std_logic;
  
  subtype coeff_type is integer range -128 to 127;
  type coeff_array_type is array (0 to filterOrder) of coeff_type;

  subtype prod_type is signed(audioWidth+coefWidth-1 downto 0);
  type prod_array_type is array (0 to filterOrder) of prod_type;

  subtype sum_type is signed(audioWidth+coefWidth-1 downto 0);
  type sum_array_type is array (0 to filterOrder) of sum_type;

  constant coeff : coeff_array_type := (4, 8, 18, 32, 43, 47, 43, 32, 18, 8, 4);
  signal prod    : prod_array_type;
  signal sum     : sum_array_type;
  
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
  -- Process handling of audio clock, sampling on sync 
  ------------------------------------------------------------------------
sample_buf_pro : process (csi_AudioClk12MHz_clk, csi_AudioClk12MHz_reset_n)
   variable left_sample : std_logic_vector(audioWidth-1 downto 0);
   variable x_n : signed(audioWidth-1 downto 0);
   variable right_sample : std_logic_vector(audioWidth-1 downto 0);
   variable filtered_data_temp : sum_type;
   variable result : sum_type;
begin 
    
    if csi_AudioClk12MHz_reset_n = '0' then        -- asynchronous reset (active low)
      for tap_no in filterOrder downto 0 loop
        sum(tap_no) <= (others => '0');
        prod(tap_no) <= (others => '0');
      end loop;   
      coe_AudioOut_export <= (others => '0');
		  AudioSync_last <= '0';
      
    elsif falling_edge(csi_AudioClk12MHz_clk) then  -- rising clock edge  
    
      -- Left channel
      if coe_AudioSync_export = '1' and AudioSync_last = '0' then 
       
        left_sample :=  coe_AudioIn_export; 
        x_n := shift_right(signed(left_sample), 1); -- Use only 23 bits of audio sample 
        
        -- Pipelined transposed FIR implementation
        -- See slides "FPGA Signal Processing page 7
        for tap_no in filterOrder downto 0 loop
          prod(tap_no) <= x_n * to_signed(coeff(tap_no), coefWidth); -- Stage 0
        end loop;

        sum(filterOrder) <= prod(filterOrder);
        for tap_no in filterOrder-1 downto 1 loop
          sum(tap_no) <= sum(tap_no+1) + prod(tap_no+1); -- Stage 1
        end loop;
        
        result := prod(0) + sum(1); -- Stage 3
        filtered_data_temp := shift_right(result, 8);
          
        if (mute_left = '1') then
          coe_AudioOut_export <= (others => '0');
        else  
          --coe_AudioOut_export <= left_sample;
          coe_AudioOut_export <= std_logic_vector(filtered_data_temp(audioWidth-1 downto 0));     
        end if;
      end if;

      -- Right channel
      if coe_AudioSync_export = '0' and AudioSync_last = '1' then 
        right_sample :=  coe_AudioIn_export;    
        if (mute_right = '1') then
          coe_AudioOut_export <= (others => '0');
        else   
          --coe_AudioOut_export <= right_sample;     
          coe_AudioOut_export <= std_logic_vector(filtered_data_temp(audioWidth-1 downto 0));     
        end if;
      end if;
      
      AudioSync_last <= coe_AudioSync_export;
      
    end if;
    
  end process sample_buf_pro;
      
  
end behaviour;
