#include <stdio.h>
#define _CRT_SECURE_NO_WARNINGS

#include "payloadFunc.h"

// simple test function to verify runtime loading of dll for execution by primary application
void runtimeLoadedFunction(char* inputString, char* fileName) {
	FILE *fp;
	fp = fopen(fileName, "w");
	fprintf(fp, inputString);
	fclose(fp);
}