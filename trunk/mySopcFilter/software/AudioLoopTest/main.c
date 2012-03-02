/*
 * "Hello World" example.
 *
 * This example prints 'Hello from Nios II' to the STDOUT stream. It runs on
 * the Nios II 'standard', 'full_featured', 'fast', and 'low_cost' example
 * designs. It runs with or without the MicroC/OS-II RTOS and requires a STDOUT
 * device in your system's hardware.
 * The memory footprint of this hosted application is ~69 kbytes by default
 * using the standard reference design.
 *
 * For a reduced footprint version of this template, and an explanation of how
 * to reduce the memory footprint for a given application, see the
 * "small_hello_world" template.
 *
 */

#include <stdio.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "system.h"
#include "alt_types.h"
#include "altera_avalon_pio_regs.h"
#include "sys/alt_timestamp.h"

void initCodec(void){
  int i, test;

  printf("Audio loopback running...\n");
  /* Reset codec interface */
  IOWR(CODECINTERFACE_0_BASE,0x0000,0x0001);
  for(i=0;i<1000;i++);
  printf("Resetting codec interface\n");
  test = IORD(CODECINTERFACE_0_BASE,0x0000);
  printf("Expected 1 = %d\n",test);

  IOWR(CODECINTERFACE_0_BASE,0x0000,0x0000);
  for(i=0;i<1000;i++);
  test = IORD(CODECINTERFACE_0_BASE,0x0000);
  printf("Expected 0 = %d\n",test);

}

#define CMD_LEN 100

#define STR_EXPAND(tok) #tok
#define STR(tok)        STR_EXPAND(tok)
// Moves the cursor to the y,x position specified - counted from top left corner
#define SET_POS(y,x)    "\x1b[" STR(y) ";" STR(x) "H"
// Clears from current position to end of line
#define CLR_LINE()      "\x1b[K"
// Clears the whole screen
#define CLR_SCR()       "\x1b[2J"

// Matrix size
#define MSIZE 4

typedef union {
  unsigned char comp[MSIZE];
  unsigned int vect;
  } vectorType;

typedef vectorType VectorArray[MSIZE];

void setInputMatrices(VectorArray A,VectorArray B);
void displayMatrix(VectorArray input);
void multiMatrixSoft(VectorArray A,VectorArray B, VectorArray P);
void multiMatrixHard(VectorArray A,VectorArray B, VectorArray P);

void setInputMatrices(VectorArray A,VectorArray B)
{
	A[0].vect = 0x04030201;
	B[0].vect = 0x01010101;
	A[1].vect = 0x08070605;
	B[1].vect = 0x02020202;
	A[2].vect = 0x0C0B0A09;
	B[2].vect = 0x03030303;
	A[3].vect = 0x100F0E0D;
	B[3].vect = 0x04040404;
}

void displayMatrix(VectorArray input)
{
	printf("Matrix :\n");
	printf("%2d %2d %2d %2d\n", input[0].comp[0],
			                	input[0].comp[1],
			                	input[0].comp[2],
			                	input[0].comp[3]);
	printf("%2d %2d %2d %2d\n", input[1].comp[0],
			                	input[1].comp[1],
			                	input[1].comp[2],
			                	input[1].comp[3]);
	printf("%2d %2d %2d %2d\n", input[2].comp[0],
			                	input[2].comp[1],
			                	input[2].comp[2],
			                	input[2].comp[3]);
	printf("%2d %2d %2d %2d\n", input[3].comp[0],
			                	input[3].comp[1],
			                	input[3].comp[2],
			                	input[3].comp[3]);

}

void multiMatrixSoft(VectorArray A,VectorArray B, VectorArray P)
{
	int row, col, k;
	for (row = 0; row < MSIZE; row++)
	{
		for (col = 0; col < MSIZE; col++)
		{
			P[row].comp[col] = 0;
			for (k = 0; k < MSIZE; k++)
				P[row].comp[col] += A[row].comp[k] * B[col].comp[k];
		}
	}

}

void multiMatrixHard(VectorArray A,VectorArray B, VectorArray P)
{
	int row, col, k;
	for (row = 0; row < MSIZE; row++)
	{
		for (col = 0; col < MSIZE; col++)
		{
			P[row].comp[col] = ALT_CI_VECTOR_MULT_INST( A[row].vect, B[col].vect);
		}
	}

}


//////////////////////////////////////////////////////////

int main()
{
	char cmd[CMD_LEN];
	char text[CMD_LEN];
	char* msg = "\x1b[1;1HSoPC Demo";
	unsigned char i_value;
	int value;
	FILE *fp;
	VectorArray AInst;
	VectorArray BTinst;
	VectorArray PInst;
	alt_u32 time1;
	alt_u32 time2;

	initCodec();

	if (alt_timestamp_start() < 0)
    {
	  printf ("No timestamp device available\n");
    }

	// Opens LCD display driver
	fp = fopen (LCD_0_NAME, "w");
	if (fp==NULL)
	{
		printf("Could not open LCD driver\n");
	}
	else
		fprintf(fp, "%s", msg);

	// Set LED pattern
	IOWR_ALTERA_AVALON_PIO_DATA(PIO_OUTPUT_0_BASE, 0xAA);
	IOWR_ALTERA_AVALON_PIO_DATA(PIO_OUTPUT_1_BASE, 0x55);

	// Nios II Console welcome text
	printf("Demo SoPC program\n");
	printf("Enter command: ledr <value> | ledg <value> | sw | lcd <text> | mult <value>\n");
	printf("              | hex <value> | counter | mute <value> | unmute \n\n");

	while(1)
	{
		printf("CMD:\> ");
		scanf(" %s", &cmd);

		if (!strcmp(cmd, "audio")) // Bit 0 = left, Bit 1 = right audio channel
		{
			//printf("audio value: %d\n", IORD_ALTERA_AVALON_PIO_DATA(AUDIO_PROCESS_0_BASE));
		}

		if (!strcmp(cmd, "mute")) // Bit 0 = left, Bit 1 = right audio channel
		{
			scanf(" %d", &value);
			//IOWR_ALTERA_AVALON_PIO_DATA(AUDIO_PROCESS_0_BASE, value);
			printf("mute %d\n", value);
		}

		if (!strcmp(cmd, "unmute"))
		{
			//IOWR_ALTERA_AVALON_PIO_DATA(AUDIO_PROCESS_0_BASE, 0);
			printf("unmute\n");
		}

		if (!strcmp(cmd, "counter")) // Counter read
		{
			// Reads from memory mapped Counter block
			printf("Counter value: %d\n", IORD_ALTERA_AVALON_PIO_DATA(MM_BUS_COUNTER_0_BASE));

		}

		if (!strcmp(cmd, "enable")) // Counter enable
		{
			scanf(" %d", &value);
			// Writes to counter block
			IOWR_ALTERA_AVALON_PIO_DATA(MM_BUS_COUNTER_0_BASE, value);
			printf("Counter enabled: %d\n", value);
		}

		if (!strcmp(cmd, "hex")) // HEX command
		{
			scanf(" %d", &value);
			// Writes to memory mapped PIO block
			IOWR_ALTERA_AVALON_PIO_DATA(MM_BUS_SEVEN_SEG_FOUR_DIGIT_0_BASE, value); //
			printf("HEX value:%d\n", value);

		}

		if (!strcmp(cmd, "mult")) // LED command
		{
			setInputMatrices(AInst, BTinst);
			displayMatrix(AInst);
			displayMatrix(BTinst);
			scanf(" %d", &i_value);

			switch (i_value)
			{
			case 1:
				time1 = alt_timestamp();
				multiMatrixSoft(AInst, BTinst, PInst);
				time2 = alt_timestamp();
				printf("SW time: %d\n", time2-time1);
				displayMatrix(PInst);
				break;
			case 2:
				time1 = alt_timestamp();
				multiMatrixHard(AInst, BTinst, PInst);
				time2 = alt_timestamp();
				printf("HW time: %d\n", time2-time1);
				displayMatrix(PInst);
				break;
			default:
				printf("mult: invalid parameter");
				break;
			}

		}

		if (!strcmp(cmd, "ledr")) // LED command
		{
			scanf(" %d", &i_value);
			// Writes to memory mapped PIO block
			IOWR_ALTERA_AVALON_PIO_DATA(PIO_OUTPUT_0_BASE, i_value); //
			printf("LED Red val:%d\n", i_value);
		}

		if (!strcmp(cmd, "ledg")) // LED command
		{
			scanf(" %d", &i_value);
			// Writes to memory mapped PIO block
			IOWR_ALTERA_AVALON_PIO_DATA(PIO_OUTPUT_1_BASE, i_value);
			printf("LED Green val:%d\n", i_value);
		}

		if (!strcmp(cmd, "sw")) // Switch command
		{
			// Reads from memory mapped PIO block
			printf("SW val: %2X\n", IORD_ALTERA_AVALON_PIO_DATA(PIO_INPUT_0_BASE));
		}

		if (!strcmp(cmd, "lcd")) // LCD command
		{
			// Uses SW driver to access LCD block
			scanf(" %s", &text);
			fprintf(fp, CLR_SCR()); // VT100 control command clear screen
			fprintf(fp, SET_POS(1,1));
			fprintf(fp, "%s", text);
		}

		usleep(1000000); // Busy waiting 1 sec.
	}

	fclose (fp);

}
