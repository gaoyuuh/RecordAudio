/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Extended Audio File Converter Sample
*/

/*
	This is a simple example program that shows the usage of the ExtendedAudioFile API found in AudioToolbox.framework
	
	Its input is an audio file containing linear pcm audio, and it generates a specified compressed audio file
*/

#if !defined(__COREAUDIO_USE_FLAT_INCLUDES__)
	#include <AudioToolbox/AudioToolbox.h>
#else
	#include "AudioToolbox.h"
	#include "ExtendedAudioFile.h"
#endif

#include "CAStreamBasicDescription.h"
#include "CAXException.h"

const UInt32 kSrcBufSize = 32768;

int ConvertFile (CFURLRef					inputFileURL, 
				CAStreamBasicDescription	&inputFormat,
				CFURLRef					outputFileURL,
				AudioFileTypeID				outputFileType, 
				CAStreamBasicDescription	&outputFormat,
				UInt32                      outputBitRate)
{
	ExtAudioFileRef infile, outfile;

	// first open the input file
	OSStatus err = ExtAudioFileOpenURL (inputFileURL, &infile);
	XThrowIfError (err, "ExtAudioFileOpen");
	
	// if outputBitRate is specified, this can change the sample rate of the output file
	// so we let this "take care of itself"
	if (outputBitRate)
		outputFormat.mSampleRate = 0.;
		
	// create the output file (this will erase an exsiting file)
	err = ExtAudioFileCreateWithURL (outputFileURL, outputFileType, &outputFormat, NULL, kAudioFileFlags_EraseFile, &outfile);
	XThrowIfError (err, "ExtAudioFileCreateNew");
	
	// get and set the client format - it should be lpcm
	CAStreamBasicDescription clientFormat = (inputFormat.mFormatID == kAudioFormatLinearPCM ? inputFormat : outputFormat);
	UInt32 size = sizeof(clientFormat);
	err = ExtAudioFileSetProperty(infile, kExtAudioFileProperty_ClientDataFormat, size, &clientFormat);
	XThrowIfError (err, "ExtAudioFileSetProperty inFile, kExtAudioFileProperty_ClientDataFormat");
	
	size = sizeof(clientFormat);
	err = ExtAudioFileSetProperty(outfile, kExtAudioFileProperty_ClientDataFormat, size, &clientFormat);
	XThrowIfError (err, "ExtAudioFileSetProperty outFile, kExtAudioFileProperty_ClientDataFormat");
	
	if( outputBitRate > 0 ) {
		printf ("Dest bit rate: %d\n", (int)outputBitRate);
		AudioConverterRef outConverter;
		size = sizeof(outConverter);
		err = ExtAudioFileGetProperty(outfile, kExtAudioFileProperty_AudioConverter, &size, &outConverter);
		XThrowIfError (err, "ExtAudioFileGetProperty outFile, kExtAudioFileProperty_AudioConverter");
		
		err = AudioConverterSetProperty(outConverter, kAudioConverterEncodeBitRate, 
										sizeof(outputBitRate), &outputBitRate);
		XThrowIfError (err, "AudioConverterSetProperty, kAudioConverterEncodeBitRate");
		
		// we have changed the converter, so we should do this in case 
		// setting a converter property changes the converter used by ExtAF in some manner
		CFArrayRef config = NULL;
		err = ExtAudioFileSetProperty(outfile, kExtAudioFileProperty_ConverterConfig, sizeof(config), &config);
		XThrowIfError (err, "ExtAudioFileSetProperty outFile, kExtAudioFileProperty_ConverterConfig");
	}
	
	// set up buffers
	char srcBuffer[kSrcBufSize];

	// do the read and write - the conversion is done on and by the write call
	while (1) 
	{	
		AudioBufferList fillBufList;
		fillBufList.mNumberBuffers = 1;
		fillBufList.mBuffers[0].mNumberChannels = inputFormat.mChannelsPerFrame;
		fillBufList.mBuffers[0].mDataByteSize = kSrcBufSize;
		fillBufList.mBuffers[0].mData = srcBuffer;
			
		// client format is always linear PCM - so here we determine how many frames of lpcm
		// we can read/write given our buffer size
		UInt32 numFrames = (kSrcBufSize / clientFormat.mBytesPerFrame);
		
		// printf("test %d\n", numFrames);

		err = ExtAudioFileRead (infile, &numFrames, &fillBufList);
		XThrowIfError (err, "ExtAudioFileRead");	
		if (!numFrames) {
			// this is our termination condition
			break;
		}
		
		err = ExtAudioFileWrite(outfile, numFrames, &fillBufList);	
		XThrowIfError (err, "ExtAudioFileWrite");	
	}
		
	// close
	ExtAudioFileDispose(outfile);
	ExtAudioFileDispose(infile);
	
    return 0;
}

