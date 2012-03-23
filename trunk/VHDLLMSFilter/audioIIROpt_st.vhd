library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity audioIIROpt_st is
  generic (audioWidth : natural := 24;
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
    avs_s1_writedata       		 : in    std_logic_vector(31 downto 0);  -- Avalon wr data
    avs_s1_readdata        		 : out   std_logic_vector(31 downto 0)   -- Avalon rd data
    );

end audioIIROpt_st;

architecture behaviour of audioIIROpt_st is

  -- Constant Declarations
  constant CI_ADDR_START    : std_logic_vector(7 downto 0) := X"00";
  
  -- Addresses for coefficients
  constant CI_ADDR_C0       : std_logic_vector(7 downto 0) := X"04";
  constant CI_ADDR_C1       : std_logic_vector(7 downto 0) := X"08";
  constant CI_ADDR_C2       : std_logic_vector(7 downto 0) := X"0C";
  constant CI_ADDR_C3       : std_logic_vector(7 downto 0) := X"10";
  constant CI_ADDR_C4       : std_logic_vector(7 downto 0) := X"14";
  
  constant CI_BYPASS  	     : std_logic                    := '1';
  
  -- Internal signals
  signal bypass_left        : std_logic;
  signal bypass_right       : std_logic;

  signal left_input : std_logic_vector(audioWidth-1 downto 0);
  signal right_input : std_logic_vector(audioWidth-1 downto 0);
  signal left_IIR : std_logic_vector(audioWidth-1 downto 0);
  --signal right_IIR : std_logic_vector(audioWidth-1 downto 0);
  signal left_valid : std_logic;
  signal right_valid : std_logic;

  -- Biquad coefficients
  subtype coeff_type is signed(audioWidth - 1 downto 0);
  type coeff_array_type is array (0 to 4) of coeff_type;
  signal coeff   : coeff_array_type;  

  -- Default coefficients for IIR filter low pass 1 Khz (20 bit)
  --constant CI_C0            : coeff_type := X"000805"; -- 0.003916 
  --constant CI_C1            : coeff_type := X"00100A"; -- 0.007832 
  --constant CI_C2            : coeff_type := X"000805"; -- 0.003916 
  --constant CI_C3            : coeff_type := X"F17A31"; -- -1.815341
  --constant CI_C4            : coeff_type := X"06A5E6"; -- 0.831006
  -- Default coefficients for IIR filter low pass 1 Khz (23 bit)
  constant CI_C0            : coeff_type := X"004029";
  constant CI_C1            : coeff_type := X"008052";
  constant CI_C2            : coeff_type := X"004029";
  constant CI_C3            : coeff_type := X"8BD176";
  constant CI_C4            : coeff_type := X"352F31";  
  
  -- Biquad taps and results
  subtype tap_type is signed(audioWidth-1 downto 0);
  type tap_array_type is array (0 to 4) of tap_type;
  signal tap : tap_array_type;
  signal result : tap_type;  
  
  -- Biquad pipeline temp products 
  subtype prod_type is signed(2*audioWidth-1 downto 0);
  type prod_array_type is array (0 to 4) of prod_type;
  signal t : prod_array_type;
  signal r1 : prod_type;
  signal r2 : prod_type;

  -- Build an enumerated type for the state machine
  type state_type is (idle, step1, step2, step3);
  signal filter_state : state_type;
  
  subtype index_type is natural range 0 to 255;
       
begin  

  ------------------------------------------------------------------------
  -- purpose: Register with Avalon Bus interface
  -- inputs : csi_clockreset_clk, csi_clockreset_reset_n, avalonbus
   ------------------------------------------------------------------------
 accessMem : process (csi_clockreset_clk, csi_clockreset_reset_n)
    variable wrData : std_logic_vector(avs_s1_writedata'high downto 0);
  begin  -- process accessMem
    
    if csi_clockreset_reset_n = '0' then  -- asynchronous reset (active low)
      coeff(0) <= CI_C0; -- Low pass 1 Khz, 20 bit coeff
      coeff(1) <= CI_C1;
      coeff(2) <= CI_C2;
      coeff(3) <= CI_C3;
      coeff(4) <= CI_C4;
      bypass_left <= '0';
      bypass_right <= '0';
      
    elsif csi_clockreset_clk'event and csi_clockreset_clk = '1' then  -- rising clock edge
          
      if avs_s1_chipselect = '1' then
        if avs_s1_write = '1' then
          case avs_s1_address is
            when CI_ADDR_START => 
                bypass_right <= avs_s1_writedata(0);
                bypass_left <= avs_s1_writedata(1);
            when CI_ADDR_C0 =>
                coeff(0) <= signed(avs_s1_writedata(audioWidth-1 downto 0));
            when CI_ADDR_C1 =>
                coeff(1) <= signed(avs_s1_writedata(audioWidth-1 downto 0));
            when CI_ADDR_C2 =>
                coeff(2) <= signed(avs_s1_writedata(audioWidth-1 downto 0));
            when CI_ADDR_C3 =>
                coeff(3) <= signed(avs_s1_writedata(audioWidth-1 downto 0));
            when CI_ADDR_C4 =>
                coeff(4) <= signed(avs_s1_writedata(audioWidth-1 downto 0));
            when others  => null;
          end case;
        end if;
        
        if avs_s1_read = '1' then
          case avs_s1_address is
            when CI_ADDR_START =>
              avs_s1_readdata <= (0 => bypass_right, 1 => bypass_left, others => '0');
            when CI_ADDR_C0 =>
              avs_s1_readdata <= std_logic_vector(resize(coeff(0), 32));
            when CI_ADDR_C1 =>
              avs_s1_readdata <= std_logic_vector(resize(coeff(1), 32));
            when CI_ADDR_C2 =>
              avs_s1_readdata <= std_logic_vector(resize(coeff(2), 32));
            when CI_ADDR_C3 =>
              avs_s1_readdata <= std_logic_vector(resize(coeff(3), 32));
            when CI_ADDR_C4 =>
              avs_s1_readdata <= std_logic_vector(resize(coeff(4), 32));
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
      left_input <= (others => '0');
      right_input <= (others => '0');
      left_valid <= '0';
      right_valid <= '0';
       
    elsif falling_edge(csi_AudioClk12MHz_clk) then  -- rising clock edge  
    
      left_valid <= '0';
      right_valid <= '0';
      
      -- New sample ready on ST bus
      if ast_sink_valid = '1' then 
              
        -- Read audio channel
        case ast_sink_channel is
        
        when chNrLeft =>
          
          -- Left channel input
          left_input <=  ast_sink_data;
          left_valid <= '1';
          
        when chNrRight =>
          
          -- Right channel input
          right_input <= ast_sink_data;
          right_valid <= '1';

        when others => 
          null;
        
        end case;
        
      end if;

    end if;
    
  end process sample_st_sink;
  
  ------------------------------------------------------------------------
  -- Process handling of IIR filter
  ------------------------------------------------------------------------
  IIRFilterLeft : process (csi_AudioClk12MHz_clk, csi_AudioClk12MHz_reset_n)
    variable tap_no : index_type;
  begin
    
    if csi_AudioClk12MHz_reset_n = '0' then        -- asynchronous reset (active low)
        for index in 4 downto 0 loop
          t(index) <= (others => '0');    
          tap(index) <= (others => '0');    
        end loop;  
        result <= (others => '0');
        left_IIR <= (others => '0');
        tap_no := 0;
        filter_state <= idle;
    
    elsif rising_edge(csi_AudioClk12MHz_clk) then  -- rising clock edge  
        
        -- State maschine executes in 8 clocks (12 MHz)
        -- Optimized of area usage - 1 multiplier and 4 adders
        case filter_state is
		  
          when idle =>
            tap_no := 0;	
          
          when step1 =>	
            t(tap_no) <= coeff(tap_no) * tap(tap_no);
            tap_no := tap_no + 1;
            if (tap_no = 5) then 
  		          filter_state <= step2;
		        end if;
		        
		      when step2 =>
            r1 <= t(0) + t(1) + t(2);
            r2 <= t(3) + t(4);
            filter_state <= step3;
          
          when step3 =>
            result <= shift_right((r1 - r2), audioWidth-1)(audioWidth-1 downto 0);
            filter_state <= idle;
		    
		    end case;
          
        -- For every new sample shift taps 
        if (left_valid = '1') then
            tap(2) <= tap(1);
            tap(1) <= tap(0);
            tap(0) <= signed(left_input);
            tap(4) <= tap(3);
            tap(3) <= result;
            left_IIR <= std_logic_vector(result);
            filter_state <= step1;
        end if;         
               
    end if;
    
  end process IIRFilterLeft;

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
      if (left_valid = '1') then 
          -- Left channel output
          if (bypass_left = CI_BYPASS) then
            ast_source_data <= left_input;
          else  
            ast_source_data <= left_IIR; -- Output from IIR filter
          end if;
          
          ast_source_channel <= chNrLeft;
          ast_source_valid <= '1';
      end if;
  
      -- New sample to right delay line
      if (right_valid = '1') then
            -- Right channel output
          if (bypass_right = CI_BYPASS) then
            ast_source_data <= right_input;
          else   
            ast_source_data <= right_input; -- Output from IIR filter   
          end if;
          
          ast_source_channel <= chNrRight;
          ast_source_valid <= '1';
      end if;
  
    end if;
    
   end process sample_st_source; 

end behaviour;
