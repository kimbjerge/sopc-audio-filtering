LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY delay_ram IS
	GENERIC (
		bitWidth : natural := 24;
		ramSize : natural := 2048
		);
	PORT (
		clock: IN STD_LOGIC;
		data: IN STD_LOGIC_VECTOR (bitWidth-1 DOWNTO 0);
		write_addr: IN INTEGER RANGE 0 to ramSize-1;
		read_addr: IN INTEGER RANGE 0 to ramSize-1;
		we: IN STD_LOGIC;
		q: OUT STD_LOGIC_VECTOR (bitWidth-1  DOWNTO 0)
	);
END delay_ram;

ARCHITECTURE rtl OF delay_ram IS
	TYPE MEM IS ARRAY(0 TO ramSize-1) OF STD_LOGIC_VECTOR(bitWidth-1 DOWNTO 0);
	SIGNAL ram_block: MEM;
BEGIN

	PROCESS (clock)
	BEGIN
		IF (clock'event AND clock = '1') THEN
			IF (we = '1') THEN
				ram_block(write_addr) <= data;
			END IF;
			q <= ram_block(read_addr);
		END IF;
	END PROCESS;

END rtl;
