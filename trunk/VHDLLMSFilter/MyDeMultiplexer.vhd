library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

entity MyDeMultiplexer is
  generic (
           inputWidth   : natural := 24);
  port (   
    -- Common --
    clk                 : in  std_logic;   -- 12MHz
    reset_n             : in  std_logic;     
    
    -- ST Bus Sink --
    ast_sink_data       : in  std_logic_vector(inputWidth-1 downto 0);
    ast_sink_valid      : in  std_logic;
    ast_sink_channel    : in  std_logic;
    
	 -- ST Bus Source --
    ast_source1_valid   : out   std_logic;
    ast_source1_data    : out   std_logic_vector(inputWidth-1 downto 0);
	 
    ast_source2_valid   : out   std_logic;
    ast_source2_data    : out   std_logic_vector(inputWidth-1 downto 0)); 
    
end entity MyDeMultiplexer;

architecture code2 of MyDeMultiplexer is
-- store sampling value
signal data 		  : 	std_logic_vector(inputWidth-1 downto 0);
signal channel 	:	std_logic;
signal valid    :	std_logic;
--
begin

	MultiplexerIn : process(clk)
	begin
    if reset_n = '0' then
		valid <= '0';
    elsif falling_edge(clk) then  --sampling on falling edge
		channel <= ast_sink_channel;
		data <= ast_sink_data;
		valid <= ast_sink_valid;			
    end if;	
	end process;


	MultiplexerOut : process(clk)		
	begin
		if rising_edge(clk) then	-- set output on rising edge
			case channel is
				when '1' =>
					ast_source1_data <= data;
					ast_source1_valid <= valid;
					ast_source2_valid <= '0';					
				when '0' =>
					ast_source2_data <= data;
					ast_source2_valid <= valid;
					ast_source1_valid <= '0';
				when others =>			
					ast_source1_valid <= '0';
					ast_source2_valid <= '0';
			end case;      
		end if;
	end process;
end architecture;