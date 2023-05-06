
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <iostream> // Standard C++ library for console I/O
#include <string> // Standard C++ Library for string manip

#include <Windows.h> // WinAPI Header
#include <TlHelp32.h> //WinAPI Process API
#include <string>
#include <stdio.h>
#include <vector>
#include <iostream>

#include "payload.h"
#include "libpeconv-master/libpeconv/include/peconv.h" // include libPeConv header

void cudaStatus(cudaError_t status)
{
    if (status != cudaSuccess)
    {
        std::cout << "cuda call failed with: " << cudaGetErrorString(status) << std::endl;
        std::exit(-1);
    }
}
// decode input data and write to output, each thread will decode 1 byte of output data
__global__ void decode(const char* input, char* output)
{
	// each thread will decode 1 byte of output data
	int index = blockIdx.x * blockDim.x + threadIdx.x;
	// each thread will decode 2 bytes of input data
	int input_index = index * 2;
	
	// initialize a variable to store the decoded byte
	char decoded = 0;
	// decode 1st nibble
	if (input[input_index] >= '0' && input[input_index] <= '9')
	{
		decoded = (input[input_index] - '0') << 4;
	}
	else if (input[input_index] >= 'a' && input[input_index] <= 'f')
	{
		decoded = (input[input_index] - 'a' + 10) << 4;
	}
	else if (input[input_index] >= 'A' && input[input_index] <= 'F')
	{
		decoded = (input[input_index] - 'A' + 10) << 4;
	}
	// decode 2nd nibble
	if (input[input_index + 1] >= '0' && input[input_index + 1] <= '9')
	{
		decoded |= (input[input_index + 1] - '0');
	}
	else if (input[input_index + 1] >= 'a' && input[input_index + 1] <= 'f')
	{
		decoded |= (input[input_index + 1] - 'a' + 10);
	}
	else if (input[input_index + 1] >= 'A' && input[input_index + 1] <= 'F')
	{
		decoded |= (input[input_index + 1] - 'A' + 10);
	}
	// write decoded byte to output
	output[index] = decoded;
}

// program obfuscation using GPU resources test application
// the objective of this sample is to hide program logic from reverse engineering tools
// by placing the logic in gpu memory and streaming it to the host in small blocks
// the host side of the program will interpret the instructions and execute them
// for this basic test, the program will load hex encoded binary to the gpu and decode it
// the decoded data will then be read back and executed by the host

// uses the "run portable executable from memory technique" to hide the program logic
// https://github.com/codecrack3/Run-PE---Run-Portable-Executable-From-Memory/blob/master/RunPE.cpp

// another approach is to store the program as llvm bitcode, an use use the llvm interpreter to execute it

// use peConv to load the paylod array into an executable and run it
int RunPortableExecutable(BYTE* payload, int payloadSize)
{
	//load the payload as a PE module:
	size_t size = 0;

	// load the DLL, function is a bit misnamed
	BYTE* pe_module = peconv::load_pe_executable(payload, payloadSize, size);

	if (!pe_module) {
		std::cout << "Failed loading PE" << std::endl;
		return -1;
	}
	//find the exported function in the payload
	FARPROC runtimeLoadedFunction_Pos = peconv::get_exported_func(pe_module, "runtimeLoadedFunction");
	if (!runtimeLoadedFunction_Pos) {
		std::cout << "Failed to find runtimeLoadedFunction" << std::endl;
		return -1;
	}
	//cast the found function to the type that it is supposed to have (this is required for the correct call)
	runtimeLoadedFunction = (void (_cdecl *) (const char*, const char*)) runtimeLoadedFunction_Pos;

	//prepare the string that will be passed to the imported function
	const char testString[] = "Hello EC700_A1 from GPU imported function!";

	//call the imported function
	runtimeLoadedFunction(testString, "hello_world.txt");

	//clean up
	memset(pe_module, 0, payloadSize);
	peconv::free_pe_buffer(pe_module, payloadSize);
	return 0;
}

int main()
{

	//// allocate gpu memory for encoded instructions
    char* gpu_encoded_instructions = nullptr;
	const size_t payload_size = strlen(encoded_payload);
	const size_t decoded_size = payload_size / 2;
	cudaStatus(cudaMalloc(&gpu_encoded_instructions, payload_size));
    cudaStatus(cudaMemcpy(gpu_encoded_instructions, encoded_payload, payload_size, cudaMemcpyHostToDevice));
    
    //allocate gpu memory for decoded instructions
    char* gpu_decoded_instructions = nullptr;
    cudaStatus(cudaMalloc(&gpu_decoded_instructions, decoded_size));
	
	// launch gpu kernel to decode the payload, each thread will decode 1 byte of output data
    decode<<<decoded_size, 1 >>>(gpu_encoded_instructions, gpu_decoded_instructions);

	// check for device side errors
	cudaStatus(cudaGetLastError());

	// synchronize host and device
    cudaStatus(cudaDeviceSynchronize());

	// allocate space on host for decoded instructions
    BYTE* executionBuffer = new BYTE[decoded_size];
	// copy decoded instructions from gpu to host
    cudaStatus(cudaMemcpy(executionBuffer, gpu_decoded_instructions, decoded_size, cudaMemcpyDeviceToHost));

	// overwrite decoded gpu memory region with 0s immediately after reading it
	cudaStatus(cudaMemset(gpu_decoded_instructions, 0, decoded_size));
    
	// execute instructions
	int status = RunPortableExecutable(executionBuffer, decoded_size);

	// overwrite execution buffer with 0s immediately after executing it
	memset(executionBuffer, 0, decoded_size);
	delete(executionBuffer);

	// clear encoded gpu memory region before freeing it
	cudaStatus(cudaMemset(gpu_encoded_instructions, 0, payload_size));

	
	cudaStatus(cudaFree(gpu_encoded_instructions));
	cudaStatus(cudaFree(gpu_decoded_instructions));
	return status;
}