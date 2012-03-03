library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

entity ST_FIR_Filter is
  generic (chNrLeft         : std_logic_vector(2  downto 0) := "000";
           chNrRight        : std_logic_vector(2  downto 0) := "001";
           filterOrder  : natural := 10;
           coefWidth    : natural := 8; -- see excel sheet
           inputWidth   : natural := 24);  -- Default value
  port (
    -- Common --
    clk                 : in  std_logic;   -- 12MHz
    reset_n             : in  std_logic;
    -- ST Bus --
    ast_sink_data       : in  std_logic_vector(inputWidth-1 downto 0);
    ast_sink_valid      : in  std_logic;
    ast_sink_channel    : in  std_logic_vector(2  downto 0);
    ast_source_data     : out std_logic_vector(inputWidth-1 downto 0) := (others => '0');
    ast_source_valid    : out std_logic   := '0';
    ast_source_channel  : out std_logic_vector(2  downto 0)

    );
end entity ST_FIR_Filter;


architecture rtl of ST_FIR_Filter is
  
  subtype coeff_type is integer range -128 to 127;
  type coeff_array_type is array (0 to filterOrder/2) of coeff_type;

  subtype tap_type is signed(inputWidth-1 downto 0);
  type tap_array_type is array (0 to filterOrder) of tap_type;

  subtype prod_type is signed(inputWidth+coefWidth-1 downto 0);
  type prod_array_type is array (0 to filterOrder/2) of prod_type;

  constant coeff_left : coeff_array_type := (1, 2, 4, 8, 16, 32); -- Cut off 1 kHz ->  (4, 8, 18, 32, 43, 47)
  constant coeff_right : coeff_array_type := (4, 8, 16, 32, 64, 127); -- filter ??????

  signal tap_left   : tap_array_type := ((others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'));
  signal tap_right  : tap_array_type := ((others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'));
  signal prod_left  : prod_array_type := ((others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'));
  signal prod_right : prod_array_type := ((others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'),(others => '0'));

  signal sink_data_temp_left : std_logic_vector(inputWidth-1 downto 0);
  signal source_data_temp_left : prod_type;
  signal sink_data_temp_right : std_logic_vector(inputWidth-1 downto 0);
  signal source_data_temp_right : prod_type;
  
  signal valid_left: std_logic;
  signal valid_right: std_logic;

  -- Build an enumerated type for the state machine
  type state_type is (idle, step1, step2, step3, step4);
  signal filter_state_left : state_type;  
  signal filter_state_right : state_type;
  
  type state_type2 is (idle, state_valid);
  signal state_ST_out : state_type2;
  
begin

  -----------------------------------------------------------------------------
  -- This process performs FIR filtering
  -----------------------------------------------------------------------------
 FilterLeft : process(clk, reset_n)
    variable temp : tap_type;
    variable result : prod_type;
 begin
    if reset_n = '0' then
      for tap_no in filterOrder downto 0 loop
        tap_left(tap_no) <= (others => '0');
      end loop;
		filter_state_left <= idle;
      
    elsif falling_edge(clk) then  -- faling clock edge
      
      case filter_state_left is
		
        when idle =>			 
          if ast_sink_valid = '1' and ast_sink_channel = chNrLeft then
				    sink_data_temp_left <= ast_sink_data;
            filter_state_left <= step1;
			    end if;
			 
		  when step1 =>  
				for tap_no in filterOrder downto 1 loop
					tap_left(tap_no) <= tap_left(tap_no - 1);
				end loop;
				tap_left(0) <= signed(sink_data_temp_left);
				filter_state_left <= step2;

			when step2 =>  
				for tap_no in (filterOrder/2)-1 downto 0 loop
					temp := resize(tap_left(tap_no), inputWidth) + resize(tap_left(filterOrder - tap_no), inputWidth);
					prod_left(tap_no) <= to_signed(coeff_left(tap_no), coefWidth) * temp;
				end loop; 
				prod_left(filterOrder/2) <= to_signed(coeff_left(filterOrder/2), coefWidth) * tap_left(filterOrder/2);
				filter_state_left <= step3;
   
			when step3 =>  
				result := (others => '0');
				for tap_no in (filterOrder/2) downto 0 loop
					result := result + prod_left(tap_no);      
				end loop; 
				valid_left <= '1';
				source_data_temp_left <= shift_right(result, 8);
				filter_state_left <= step4;

			when step4 =>  
				valid_left <= '0'; --low after one clk 
			  filter_state_left <= idle; 
			  		
	    when others =>
				filter_state_left <= idle;
					
      end case;	
			
    end if;
  end process;
  

  -----------------------------------------------------------------------------
  -- This process performs FIR filtering
  -----------------------------------------------------------------------------
 FilterRight : process(clk, reset_n)
    variable temp : tap_type;
    variable result : prod_type;
 begin
    if reset_n = '0' then
      for tap_no in filterOrder downto 0 loop
        tap_right(tap_no) <= (others => '0');
      end loop;
		filter_state_right <= idle;
      
    elsif falling_edge(clk) then  -- faling clock edge
      
      case filter_state_right is
		
        when idle =>			 
          if ast_sink_valid = '1' and ast_sink_channel = chNrRight then
				    sink_data_temp_right <= ast_sink_data;
            filter_state_right <= step1;
			    end if;
			 
		  when step1 =>  
				for tap_no in filterOrder downto 1 loop
					tap_right(tap_no) <= tap_right(tap_no - 1);
				end loop;
				tap_right(0) <= signed(sink_data_temp_right);
				filter_state_right <= step2;

			when step2 =>  
				for tap_no in (filterOrder/2)-1 downto 0 loop
					temp := resize(tap_right(tap_no), inputWidth) + resize(tap_right(filterOrder - tap_no), inputWidth);
					prod_right(tap_no) <= to_signed(coeff_right(tap_no), coefWidth) * temp;
				end loop; 
				prod_right(filterOrder/2) <= to_signed(coeff_right(filterOrder/2), coefWidth) * tap_right(filterOrder/2);
				filter_state_right <= step3;
   
			when step3 =>  
				result := (others => '0');
				for tap_no in (filterOrder/2) downto 0 loop
					result := result + prod_right(tap_no);      
				end loop; 
				valid_right <= '1';
				source_data_temp_right <= shift_right(result, 8);
				filter_state_right <= step4;

			when step4 =>  
			  valid_right <= '0'; --low after one clk
			  filter_state_right <= idle;
			  		
	    when others =>
				filter_state_right <= idle;
					
      end case;	
			
    end if;
  end process;

  
  sourceValidSignal : process(clk, reset_n)  
  begin
    if rising_edge(clk) then      
      case state_ST_out is
        when idle =>
          if valid_left = '1' then
            ast_source_channel	<= chNrLeft;
            ast_source_data <= std_logic_vector(source_data_temp_left(inputWidth-1 downto 0)); 
            ast_source_valid <= '1'; 
            state_ST_out <= state_valid;       
          elsif valid_right = '1' then
            ast_source_channel	<= chNrRight;
            ast_source_data <= std_logic_vector(source_data_temp_right(inputWidth-1 downto 0));
            ast_source_valid <= '1';
            state_ST_out <= state_valid;
          end if;
        when state_valid =>
          ast_source_valid <= '0';
          state_ST_out <= idle;
      end case;
    end if;
  end process;
  
end architecture; 
