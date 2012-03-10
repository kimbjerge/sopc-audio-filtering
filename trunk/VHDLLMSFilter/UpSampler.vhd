library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

entity UpSampler is
  generic (filterOrder  : natural := 26;
           coefWidth    : natural := 8;
           inputWidth   : natural := 24);
  port (   
    -- Common --
    clk                 : in  std_logic;   -- 12MHz
    reset_n             : in  std_logic;     
    
    -- ST Bus --
    ast_sink_data       : in  std_logic_vector(inputWidth-1 downto 0);
    ast_sink_valid      : in  std_logic;
    
    -- sigma dalta converter --
    outputPin           : out std_logic);
    
end entity UpSampler;

architecture code of UpSampler is
  -- From ST Bus to UpSampler

  signal last_data : signed(inputWidth-1 downto 0);
  signal last_data1 : signed(inputWidth-1 downto 0); --double flip flop

  -- Upsampler and FIR filter

  subtype coeff_type is integer range -128 to 127;
  type coeff_array_type is array (0 to filterOrder/2) of coeff_type;

  subtype tap_type is signed(inputWidth-1 downto 0);
  type tap_array_type is array (0 to filterOrder) of tap_type;

  subtype prod_type is signed(inputWidth+coefWidth-1 downto 0);
  type prod_array_type is array (0 to filterOrder/2) of prod_type;

  constant coeff : coeff_array_type := (1, 1, 2, 3, 4, 6, 8, 11, 13, 15, 17, 18, 19, 19); -- Cut off 24 kHz
  
  signal tap   : tap_array_type ;
  signal prod  : prod_array_type ;
  
  -- Sigma dalta converter --
  
  signal sigmaIn : signed(inputWidth+1 downto 0);
  signal sigmaIntegratorLast1 : signed(inputWidth+1 downto 0);
  signal sigmaIntegratorLast2 : signed(inputWidth+1 downto 0);
  signal sigmaDac : signed(inputWidth+1 downto 0);
  signal outUpSampler : std_logic_vector(inputWidth-1 downto 0); 
  
  -- Clk Divider --
  signal ClkDividerOut : std_logic; -- 12MHz / 10 = 1,2MHz 
   
begin
  
 Filter : process(ClkDividerOut, reset_n)
	 -- FIR Filter
    variable temp : tap_type;
    variable result : signed(inputWidth+coefWidth-1 downto 0);
    -- Sigma Delta Converter
    variable sigmaSum : signed(inputWidth+1 downto 0);
    variable sigmaIntegrator1 : signed(inputWidth+1 downto 0);
    variable sigmaIntegrator2 : signed(inputWidth+1 downto 0);
    variable sigmaOut : std_logic;
 begin
    if reset_n = '0' then
	 
      for tap_no in filterOrder downto 0 loop
        tap(tap_no) <= (others => '0');
      end loop;
      for tap_no in filterOrder/2 downto 0 loop
        prod(tap_no) <= (others => '0');
      end loop;      
      
      --sigmaSum := (others => '0');
      --sigmaIntegrator1 := (others => '0');
      --sigmaOut := '0';
      sigmaIn <= (others => '0');
      sigmaIntegratorLast1 <= (others => '0');
		sigmaIntegratorLast2 <= (others => '0');
      sigmaDac <= (others => '0');
		
		last_data <= (others => '0');
      
    elsif rising_edge(ClkDividerOut) then			 
			    
		for tap_no in filterOrder downto 1 loop
			tap(tap_no) <= tap(tap_no - 1);
		end loop;
		
		--double flip flop
		last_data <= last_data1;
		tap(0) <= last_data;
		--
				
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
        sigmaIn <= resize( shift_right(result, 8)(inputWidth-1 downto 0),inputWidth+2);
        sigmaSum := sigmaIn - sigmaDac;
        sigmaIntegrator1 := sigmaSum + sigmaIntegratorLast1;
        sigmaIntegratorLast1 <= sigmaIntegrator1;
		  
		  sigmaIntegrator2 := sigmaIntegrator1 - sigmaDac + sigmaIntegratorLast2;
		  sigmaIntegratorLast2 <= sigmaIntegrator2;
        
        if sigmaIntegrator2 >= 0 then
          sigmaOut := '1';
        else
          sigmaOut := '0';
        end if;
        
        outputPin <= sigmaOut;
        
        if sigmaOut = '1' then
          sigmaDac <= "00" & X"7FFFFF";
        elsif sigmaOut = '0' then
          sigmaDac <= "11" & X"800001";
        end if;
			
    end if;
  end process;
  
  UpdateValue : process(clk)
  begin
    if reset_n = '0' then
		last_data1 <= (others => '0');
    elsif falling_edge(clk) then
      if ast_sink_valid = '1' then
				-- get value from ST Bus
			   last_data1 <= signed(ast_sink_data);
      end if;
    end if;
  end process;
  
  ClkDivider : process(clk)
  variable counterDivider : unsigned(2 downto 0);
  begin
		if reset_n = '0' then
			counterDivider := to_unsigned(0,3);
			ClkDividerOut <= '0';
		elsif rising_edge(clk) then
			if counterDivider = 4 then
				counterDivider := to_unsigned(0,3);
				ClkDividerOut <= not ClkDividerOut; -- clk out = 12MHz / 10 = 1,2MHz	
			else 
				counterDivider := counterDivider + to_unsigned(1,3);			
			end if;
		end if;
  end process;
  
end architecture;
