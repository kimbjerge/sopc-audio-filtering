/*
 ============================================================================
 Name        : Int2Hex.c
 Author      : 
 Version     :
 Copyright   : Your copyright notice
 Description : Hello World in C, Ansi-style
 ============================================================================
 */

#include <stdio.h>
#include <stdlib.h>

int main(void) {
	FILE *fp_out, *fp_in;    // File to convert
	int tmp_val;

	puts("Integer to Hex converter");

	fp_in = fopen("Noise.txt", "r");
	fp_out = fopen("NoiseHex.txt", "w");

	while ((fscanf(fp_in, "%d", &tmp_val) != EOF))
	{
		fprintf(fp_out, "%08X\n", tmp_val);
	}

	fclose(fp_in);
	fclose(fp_out);
	return EXIT_SUCCESS;
}
