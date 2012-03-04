library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity audiolmsfilter is
  generic (filterOrder : natural := 10;
           coefWidth : natural := 24; 
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

end audiolmsfilter;

architecture behaviour of audiolmsfilter is

  -- Constant Declarations
  constant CI_ADDR_START    : std_logic_vector(7 downto 0) := X"00";
  constant CI_ADDR_STATUS   : std_logic_vector(7 downto 0) := X"40";
  constant CI_UNMUTED 	     : std_logic                    := '0';
  
  -- Internal signals
  signal AudioSync_last     : std_logic;
  signal mute_left          : std_logic;
  signal mute_right         : std_logic;
  
  subtype coeff_type is signed(coefWidth-1 downto 0);
  type coeff_array_type is array (0 to filterOrder) of coeff_type;

  subtype tap_type is signed(audioWidth-1 downto 0);
  type tap_array_type is array (0 to filterOrder) of tap_type;

  subtype prod_type is signed(audioWidth+coefWidth-1 downto 0);
  type prod_array_type is array (0 to filterOrder) of prod_type;
  
  constant ADPT_STEP : coeff_type := X"000083";  -- Format decimal 131 -  1.15 with 0.004 (float)

  signal coeff   : coeff_array_type;
  --constant const_coeff : coeff_array_type := 
  --(X"000004", X"000008", X"000012", X"000020", X"00002B", X"00002F", X"00002B", X"000020", X"000012", X"000008", X"000004");
  signal tap     : tap_array_type;
  signal wk_s    : tap_array_type;
  signal prod    : prod_array_type;
  signal error   : tap_type;
  
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
   variable noise_sample : std_logic_vector(audioWidth-1 downto 0);
   variable sound_sample : std_logic_vector(audioWidth-1 downto 0);
   variable result : prod_type;
   variable filtered_result : prod_type;
   variable wk_i : signed((2*audioWidth)-1 downto 0);
   --variable wk_si : tap_type;
   variable wk_ii : signed(audioWidth+coefWidth-1 downto 0);
begin 
    
    if csi_AudioClk12MHz_reset_n = '0' then        -- asynchronous reset (active low)
      for tap_no in filterOrder downto 0 loop
        --coeff(tap_no) <= const_coeff(tap_no);
        coeff(tap_no) <= (others => '0');
        tap(tap_no) <= (others => '0');
        prod(tap_no) <= (others => '0');
        wk_s(tap_no) <= (others => '0');
      end loop;   
		  sound_sample := (others => '0');
		  error <= (others => '0');
		  AudioSync_last <= '0';
      coe_AudioOut_export <= (others => '0');
      
    elsif falling_edge(csi_AudioClk12MHz_clk) then  -- rising clock edge  
    
      -- Left channel
      if coe_AudioSync_export = '1' and AudioSync_last = '0' then 
       
        noise_sample :=  coe_AudioIn_export; -- Noise signal

        -- Direct FIR filter pipelined - 2 stages   
        -- First stage shift delayline
        for tap_no in filterOrder downto 1 loop
          tap(tap_no) <= tap(tap_no - 1);
        end loop;
        tap(0) <= shift_right(signed(noise_sample), 1); -- Use only 23 bits of audio sample
           
        -- Second stage performs MAC for FIR filter
        result := (others => '0');
        for tap_no in filterOrder downto 0 loop
          result := (coeff(tap_no) * tap(tap_no)) + result;
        end loop;      
        filtered_result := shift_right(result, coefWidth-1); 
        error <= shift_right(signed(sound_sample), 1) - resize(filtered_result, audioWidth);
        
        -- Third+forth stage performs adjust LMS algorithm of weights, 2 stages pipelining        
        for tap_no in filterOrder downto 0 loop
          wk_i := error * tap(tap_no);
          wk_s(tap_no) <= resize(shift_right(wk_i, coefWidth-1), audioWidth); -- First pipeline (product+shift)
          wk_ii := ADPT_STEP * wk_s(tap_no);
          --wk_si := resize(shift_right(wk_i, coefWidth-1), audioWidth); -- First pipeline (product+shift)
          --wk_ii := ADPT_STEP * wk_si;
          coeff(tap_no) <= coeff(tap_no) + resize(shift_right(wk_ii, coefWidth-1), coefWidth); -- Second pipeline (MAC+shift)
        end loop;
          
        if (mute_left = '1') then
          coe_AudioOut_export <= (others => '0');
        else  
          --coe_AudioOut_export <= std_logic_vector(filtered_result(audioWidth-1 downto 0));
          coe_AudioOut_export <= std_logic_vector(error(audioWidth-1 downto 0));     
        end if;
      end if;

      -- Right channel
      if coe_AudioSync_export = '0' and AudioSync_last = '1' then 
        sound_sample :=  coe_AudioIn_export;    
        if (mute_right = '1') then
          coe_AudioOut_export <= (others => '0');
        else   
          --coe_AudioOut_export <= sound_sample;     
          coe_AudioOut_export <= std_logic_vector(error(audioWidth-1 downto 0));     
        end if;
      end if;
      
      AudioSync_last <= coe_AudioSync_export;
      
    end if;
    
  end process sample_buf_pro;
      
  
end behaviour;
