library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

entity UpSampler is
  generic (thisNr       : std_logic_vector(2  downto 0) := "000";
           filterOrder  : natural := 10;
           coefWidth    : natural := 8;
           inputWidth   : natural := 24);
  port (   
    -- Common --
    clk                 : in  std_logic;   -- 12MHz
    reset_n             : in  std_logic;     
    
    -- ST Bus --
    ast_sink_data       : in  std_logic_vector(inputWidth-1 downto 0);
    ast_sink_valid      : in  std_logic;
    ast_sink_channel    : in  std_logic_vector(2  downto 0);
    
    -- sigma dalta converter --
    up_sampler_clk      : in  std_logic;  -- 1,536MHz = 48KHz * 32
    outputPin           : out std_logic);
    
end entity UpSampler;

architecture code of UpSampler is

  subtype coeff_type is integer range -128 to 127;
  type coeff_array_type is array (0 to filterOrder/2) of coeff_type;

  subtype tap_type is signed(inputWidth-1 downto 0);
  type tap_array_type is array (0 to filterOrder) of tap_type;

  subtype prod_type is signed(inputWidth+coefWidth-1 downto 0);
  type prod_array_type is array (0 to filterOrder/2) of prod_type;
  
  signal last_data : signed(inputWidth-1 downto 0);

  constant coeff : coeff_array_type := (100, 0, 0, 0, 0, 0); -- Cut off 1 kHz ->  (4, 8, 18, 32, 43, 47)

  signal tap   : tap_array_type ;
  signal prod  : prod_array_type ;

  -- Build an enumerated type for the state machine
  type state_type is (idle);
  signal filter_state : state_type;
  
  -- Sigma dalta converter --
  
  signal sigmaIn : signed(inputWidth downto 0);
  signal sigmaIntegratorLast : signed(inputWidth downto 0);
  signal sigmaDac : signed(inputWidth downto 0);
  signal outUpSampler : std_logic_vector(inputWidth-1 downto 0); 
   
begin
  
 Filter : process(up_sampler_clk, reset_n)
    variable temp : tap_type;
    variable result : prod_type;
    -- Sigma Delta Converter
    variable sigmaSum : signed(inputWidth downto 0);
    variable sigmaIntegrator : signed(inputWidth downto 0);
    variable sigmaOut : std_logic;    
    
 begin
    if reset_n = '0' then
      for tap_no in filterOrder downto 0 loop
        tap(tap_no) <= (others => '0');
      end loop;
      for tap_no in filterOrder/2 downto 0 loop
        prod(tap_no) <= (others => '0');
      end loop;      
      
      sigmaSum := (others => '0');
      sigmaIntegrator := (others => '0');
      sigmaOut := '0';
      sigmaIn <= (others => '0');
      sigmaIntegratorLast <= (others => '0');
      sigmaDac <= (others => '0');    
      
      
		filter_state <= idle;
      
    elsif rising_edge(up_sampler_clk) then
      
      case filter_state is
		
        when idle =>			 
			    
			  for tap_no in filterOrder downto 1 loop
				tap(tap_no) <= tap(tap_no - 1);
				end loop;
				tap(0) <= last_data;
				
				for tap_no in (filterOrder/2)-1 downto 0 loop
					temp := resize(tap(tap_no), inputWidth) + resize(tap(filterOrder - tap_no), inputWidth);
					prod(tap_no) <= to_signed(coeff(tap_no), coefWidth) * temp;
				end loop; 
				prod(filterOrder/2) <= to_signed(coeff(filterOrder/2), coefWidth) * tap(filterOrder/2);
				
				result := (others => '0');
				for tap_no in (filterOrder/2) downto 0 loop
					result := result + prod(tap_no);      
				end loop; 
				
				outUpSampler <= std_logic_vector(shift_right(result, 8)(inputWidth-1 downto 0));	
				--^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^
				--| | | | | | | | | | | |
				--Upsampler and FIRfilter
				--------------------------------------------------------------------------------------------
        --Sigma delta converter
        -- 
        sigmaIn <= shift_right(result, 8)(inputWidth downto 0);
        sigmaSum := sigmaIn - sigmaDac;
        sigmaIntegrator := sigmaSum + sigmaIntegratorLast;
        sigmaIntegratorLast <= sigmaIntegrator; -- sker i næste clok
        
        if sigmaIntegrator >= 0 then
          sigmaOut := '1';
        else
          sigmaOut := '0';
        end if;
        
        outputPin <= sigmaOut;
        
        if sigmaOut = '1' then
          sigmaDac <= '0' & X"7FFFFF";
        elsif sigmaOut = '0' then
          sigmaDac <= '1' & X"800001";-- X"800001";
        end if;
        
			  		
	    when others =>
				filter_state <= idle;
					
      end case;	
			
    end if;
  end process;
  
  UpdateValue : process(clk, reset_n)
  begin
    if reset_n = '0' then
      last_data <= (others => '0');
    elsif falling_edge(clk) then
      if ast_sink_valid = '1' and ast_sink_channel = thisNr then
			   last_data <= signed(ast_sink_data);
      end if;
    end if;
  end process;
  
end architecture;
