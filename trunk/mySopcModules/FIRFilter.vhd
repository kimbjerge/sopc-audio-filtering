library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

entity FIRFilter is
  generic (filterOrder : natural := 10;
           coefWidth : natural := 8; -- see excel sheet
           inputWidth : natural := 24);  -- Default value
  port (
    -- Common --
    clk              : in  std_logic;   -- 50MHz
    reset_n          : in  std_logic;
    -- ST Bus --
    ast_sink_data    : in  std_logic_vector(inputWidth-1 downto 0);
    ast_sink_ready   : out std_logic                     := '0';  -- Value at startup
    ast_sink_valid   : in  std_logic;
    ast_sink_error   : in  std_logic_vector(1 downto 0);
    ast_source_data  : out std_logic_vector(inputWidth-1 downto 0) := (others => '0');
    ast_source_ready : in  std_logic;
    ast_source_valid : out std_logic                     := '0';
    ast_source_error : out std_logic_vector(1 downto 0)  := (others => '0')

    );
end entity FIRFilter;

-------------------------------------------------------------------------------
-- RTL based version of FIRFilter 
-- RTL based version
-------------------------------------------------------------------------------
architecture rtl of FIRFilter is
  
  subtype coeff_type is integer range -128 to 127;
  type coeff_array_type is array (0 to filterOrder/2) of coeff_type;

  subtype tap_type is signed(inputWidth-1 downto 0);
  type tap_array_type is array (0 to filterOrder) of tap_type;

  subtype prod_type is signed(inputWidth+coefWidth-1 downto 0);
  type prod_array_type is array (0 to filterOrder/2) of prod_type;

  constant coeff : coeff_array_type := (4, 8, 18, 32, 43, 47); -- Cut off 1 kHz
  --constant coeff : coeff_array_type := (-1, -3, 0, 27, 73, 97);
  signal tap     : tap_array_type;
  signal prod    : prod_array_type;

  signal sink_data_temp : std_logic_vector(inputWidth-1 downto 0);
  signal source_data_temp : prod_type;

  -- Build an enumerated type for the state machine
  type state_type is (idle, step1, step2, step3, step4, wait_low);
  signal filter_state : state_type;
   
begin

  -----------------------------------------------------------------------------
  -- This process performs FIR filtering
  -----------------------------------------------------------------------------
 Filter : process(clk, reset_n)
    variable temp : tap_type;
    variable result : prod_type;
 begin
    if reset_n = '0' then
      for tap_no in filterOrder downto 0 loop
        tap(tap_no) <= (others => '0');
      end loop;
      ast_sink_ready <= '1';
		filter_state <= idle;
      
    elsif rising_edge(clk) then  -- faling clock edge
      
      case filter_state is
		
        when idle =>			 
          if ast_sink_valid = '1' then
				ast_sink_ready <= '0';
				sink_data_temp <= ast_sink_data;
            filter_state <= step4;
			 end if;
			 
		  when step1 =>  
				for tap_no in filterOrder downto 1 loop
					tap(tap_no) <= tap(tap_no - 1);
				end loop;
				tap(0) <= signed(sink_data_temp);
				filter_state <= step2;

			when step2 =>  
				for tap_no in (filterOrder/2)-1 downto 0 loop
					temp := resize(tap(tap_no), inputWidth) + resize(tap(filterOrder - tap_no), inputWidth);
					prod(tap_no) <= to_signed(coeff(tap_no), coefWidth) * temp;
				end loop; 
				prod(filterOrder/2) <= to_signed(coeff(filterOrder/2), coefWidth) * tap(filterOrder/2);
				filter_state <= step3;
   
			when step3 =>  
				result := (others => '0');
				for tap_no in (filterOrder/2) downto 0 loop
					result := result + prod(tap_no);      
				end loop; 
				source_data_temp <= shift_right(result, 8);
				filter_state <= step4;

			when step4 =>  
				ast_source_valid <= '1';
				--ast_source_data <= std_logic_vector(source_data_temp(inputWidth-1 downto 0));
				ast_source_data <= sink_data_temp;
				ast_sink_ready <= '1';
				filter_state <= wait_low;
			
			when wait_low =>
				ast_source_data <= ast_sink_data;
			   if (ast_sink_valid = '0') then
					filter_state <= idle;
				end if;
				
	      when others =>
				filter_state <= idle;
					
      end case;	
			
    end if;
  end process;
  
end architecture;

